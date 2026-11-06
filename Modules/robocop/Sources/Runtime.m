// SPDX-License-Identifier: GPL-3.0-only
#import "Overlay.h"
#import "MHTRuntimeBridge.h"
#import <os/log.h>
#import <unistd.h>
#import <limits.h>
#import <mach-o/dyld.h>
#import <Carbon/Carbon.h>
#import "GameProfile.h"
#import "SelectionSettings.h"

static os_log_t runtimeLog;
static NSMutableArray<MTOverlayRoot *> *roots;
static NSString *sessionToken;
static NSString *profileID;
static NSDictionary *lastSelection;
static id monitor;
static NSEvent *(^inputMonitorHandler)(NSEvent *);
static uint64_t monitoredContext;
static NSTimer *attachmentTimer;
static NSTimer *gameplayTimer;
static MTGameBridge *gameplay;
static NSDictionary *overlayOptions;
static id settingsObserver;
static NSTimer *inputTimer;
static BOOL inputRequested;
static MTOverlayShortcuts *shortcuts;
static EventHotKeyRef shortcutRefs[MTShortcutCount];
static EventHandlerRef shortcutHandler;
static BOOL shortcutsEnabled;
static id activeObserver, inactiveObserver;
static NSDictionary *lastOverlayKeyEvent;
static EventHotKeyRef gameplayHotkeys[MTFeatureCount+3];
static EventHandlerRef gameplayHotkeyHandler;
static BOOL gameplayHeld[MTFeatureCount+3];
static NSUInteger gameplayRegistrations;
static MTShortcutDeliveryGate *deliveryGate;

static MTOverlayRoot *shortcutRoot(NSWindow *eventWindow, BOOL fallback) {
    MTOverlayRoot *best=nil;
    for (MTOverlayRoot *root in roots) {
        NSWindow *window=root.window;
        if (!window || !window.isVisible || window.isMiniaturized) continue;
        if (window==eventWindow || window.isKeyWindow) return root;
        if (fallback && (!best || window==NSApp.mainWindow
            || root.bounds.size.width*root.bounds.size.height>best.bounds.size.width*best.bounds.size.height)) best=root;
    }
    return best;
}
static OSStatus overlayHotkey(EventHandlerCallRef next, EventRef event, void *context) {
    (void)next; (void)context;
    EventHotKeyID identifier={0};
    if (GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(identifier),NULL,&identifier)!=noErr
        || identifier.signature!=0x4D54524E || identifier.id<1 || identifier.id>MTShortcutCount) return eventNotHandledErr;
    if (!NSApp.isActive) return eventNotHandledErr;
    return [shortcuts nativeShortcut:(MTOverlayShortcut)(identifier.id-1)
        pressed:GetEventKind(event)==kEventHotKeyPressed] ? noErr : eventNotHandledErr;
}
static OSStatus nativeGameplayHotkey(EventHandlerCallRef next,EventRef event,void *context){
    (void)next;(void)context;EventHotKeyID identifier={0};
    if(GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(identifier),NULL,&identifier)!=noErr || identifier.signature!=0x52433137 || identifier.id<1 || identifier.id>MTFeatureCount+3)return eventNotHandledErr;
    NSInteger index=identifier.id-1;
    if(GetEventKind(event)==kEventHotKeyReleased){gameplayHeld[index]=NO;return noErr;}
    if(!NSApp.isActive)return eventNotHandledErr;
    if(gameplayHeld[index])return noErr;gameplayHeld[index]=YES;
    if(![deliveryGate acceptCommand:index native:YES time:NSProcessInfo.processInfo.systemUptime])return noErr;
    MTOverlayRoot *root=shortcutRoot(nil,YES);if(!root)return eventNotHandledErr;
    if(index==0)[root togglePanel:nil];
    else if(index==1)[gameplay performAction:MTTrainerDisableAll];
    else if(index==2){
        NSEvent *escape=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:root.window.windowNumber context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:53];[root handleEvent:escape];
    }else{
        const MTFeatureInfo *info=MTFeatureInfoAt(index-3);
        // Route through the same editor/command handler, rather than creating a second action path.
        NSString *digit=@"";
        NSEvent *key=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:info->modifiers timestamp:0 windowNumber:root.window.windowNumber context:nil characters:digit charactersIgnoringModifiers:digit isARepeat:NO keyCode:info->key];[root handleEvent:key];
    }
    if(NSProcessInfo.processInfo.environment[@"MT_TRAINER_DIAGNOSTICS"])lastOverlayKeyEvent=@{@"native":@YES,@"command":@(index),@"after":@(root.panelVisible),@"handled":@YES};
    return noErr;
}
static void updateGameplayHotkeys(BOOL enabled){
    if(!gameplayHotkeyHandler && enabled){const EventTypeSpec events[]={{kEventClassKeyboard,kEventHotKeyPressed},{kEventClassKeyboard,kEventHotKeyReleased}};InstallApplicationEventHandler(nativeGameplayHotkey,2,events,NULL,&gameplayHotkeyHandler);}
    MTOverlayRoot *root=shortcutRoot(nil,YES);gameplayRegistrations=0;
    for(NSInteger i=0;i<MTFeatureCount+3;i++){
        BOOL wanted=enabled && (i!=2 || root.panelVisible);
        if(!wanted){if(gameplayHotkeys[i])UnregisterEventHotKey(gameplayHotkeys[i]);gameplayHotkeys[i]=NULL;gameplayHeld[i]=NO;continue;}
        if(!gameplayHotkeys[i] && gameplayHotkeyHandler){
            UInt32 code=i==0 ? 22 : i==1 ? 101 : i==2 ? 53 : MTFeatureInfoAt(i-3)->key;
            UInt32 modifiers=i==0 ? cmdKey|shiftKey : i==1 ? shiftKey : i==2 ? 0 : MTFeatureInfoAt(i-3)->modifiers&NSEventModifierFlagControl ? controlKey : 0;
            EventHotKeyID id={0x52433137,(UInt32)i+1};RegisterEventHotKey(code,modifiers,id,GetApplicationEventTarget(),kEventHotKeyNoOptions,&gameplayHotkeys[i]);
        }
        if(gameplayHotkeys[i])gameplayRegistrations++;
    }
}
static NSInteger nativeKeyIndex(NSEvent *event){
    NSUInteger flags=event.modifierFlags&(NSEventModifierFlagCommand|NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption);
    if(gameplayHotkeys[0] && event.keyCode==22 && flags==(NSEventModifierFlagCommand|NSEventModifierFlagShift))return 0;
    if(gameplayHotkeys[1] && event.keyCode==101 && flags==NSEventModifierFlagShift)return 1;
    if(gameplayHotkeys[2] && event.keyCode==53 && flags==0)return 2;
    for(NSInteger i=0;i<MTFeatureCount;i++)if(gameplayHotkeys[i+3] && event.keyCode==MTFeatureInfoAt(i)->key && flags==MTFeatureInfoAt(i)->modifiers)return i+3;
    return -1;
}
static void updateKeyboardShortcuts(void) {
    // Native registrations exist only while this game's application is active.
    // They do not reserve Command+caret while using another app.
    BOOL enabled=NSApp.isActive && shortcutRoot(nil,YES)!=nil;
    updateGameplayHotkeys(enabled);
    if (enabled==shortcutsEnabled) return;
    shortcutsEnabled=enabled; shortcuts.enabled=enabled;
    if (!enabled) {
        for (NSInteger i=0;i<MTShortcutCount;i++) {
            if (shortcutRefs[i]) { UnregisterEventHotKey(shortcutRefs[i]); shortcutRefs[i]=NULL; }
            [shortcuts setRegistered:NO shortcut:i];
        }
        return;
    }
    if (!shortcutHandler) {
        const EventTypeSpec events[]={{kEventClassKeyboard,kEventHotKeyPressed},{kEventClassKeyboard,kEventHotKeyReleased}};
        OSStatus status=InstallApplicationEventHandler(overlayHotkey,2,events,NULL,&shortcutHandler);
        if (status!=noErr) { os_log_error(runtimeLog,"Native shortcut handler unavailable: %d",(int)status); return; }
    }
    for (NSInteger i=0;i<MTShortcutCount;i++) {
        EventHotKeyID identifier={0x4D54524E,(UInt32)i+1};
        OSStatus status=RegisterEventHotKey(10,cmdKey,identifier,GetApplicationEventTarget(),kEventHotKeyNoOptions,&shortcutRefs[i]);
        [shortcuts setRegistered:status==noErr && shortcutRefs[i]!=NULL shortcut:i];
        os_log(runtimeLog,"Native shortcut %ld registration status=%d",(long)i,(int)status);
    }
}
static void updateOverlayInput(void) {
    updateKeyboardShortcuts();
    MTOverlayRoot *root=NSApp.isActive ? shortcutRoot(nil,YES) : nil;
    BOOL wanted=root.wantsMouseInteraction;
    if (inputRequested!=wanted) { inputRequested=wanted; [gameplay setOverlayInteraction:wanted]; }
}

static void postOverlayOptions(void) {
    if (!sessionToken.length) return;
    @try {
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:MTOverlayChangedNotification
            object:MTOverlayMessage(overlayOptions,sessionToken,getpid()) userInfo:nil deliverImmediately:YES];
    } @catch (NSException *exception) {
        os_log(runtimeLog,"Optional overlay settings notification unavailable: %{public}s",exception.name.UTF8String);
    }
}
static void postSelection(MTTrainerState *state) {
    // An initial loading/unsupported poll must not erase a previous selection.
    if (!sessionToken.length || !profileID.length
        || (state.sessionKind!=MTSessionSolo && state.sessionKind!=MTSessionNetwork)) return;
    NSDictionary *selection=MTSelectionFromState(state);
    if ([selection isEqual:lastSelection]) return;
    lastSelection=selection;
    @try {
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:MTSelectionChangedNotification
            object:MTSelectionMessage(selection,sessionToken,profileID,getpid()) userInfo:nil deliverImmediately:YES];
    } @catch (NSException *exception) {
        os_log(runtimeLog,"Optional selection notification unavailable: %{public}s",exception.name.UTF8String);
    }
}

static BOOL supportedProcess(void) {
    NSDictionary *config=MTLoadConfiguration(NSProcessInfo.processInfo.environment[@"MHT_CONFIG"],NULL);
    NSDictionary *profile=MTFindProfile(config,NSProcessInfo.processInfo.environment[@"MHT_PROFILE"]);
    return MTCurrentProcessMatches(profile,NSProcessInfo.processInfo.environment[@"MHT_TARGET"]);
}

static void attachToGameWindow(void) {
    if (!NSApp || ![NSThread isMainThread]) return;
    // Keep only live roots; moving/recreated game windows are discovered again.
    for (MTOverlayRoot *root in roots.copy) {
        if (!root.window || !root.superview || root.window.contentView != root.superview) {
            [root removeFromSuperview]; [roots removeObjectIdenticalTo:root];
        }
    }
    NSWindow *candidate = nil;
    CGFloat largest = 0;
    for (NSWindow *window in NSApp.windows) {
        if (!window.isVisible || window.isMiniaturized || window.attachedSheet
            || [window isKindOfClass:NSPanel.class] || !window.contentView) continue;
        NSSize size = window.contentView.bounds.size;
        CGFloat area = size.width * size.height;
        if (size.width >= 640 && size.height >= 360 && area > largest) { candidate = window; largest = area; }
    }
    if (!candidate) return;
    NSView *content = candidate.contentView;
    for (MTOverlayRoot *root in roots) {
        if (root.superview == content) {
            root.frame = content.bounds;
            return;
        }
    }
    NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
    MTOverlayRoot *root = [[MTOverlayRoot alloc] initWithFrame:content.bounds version:version];
    [root applyOverlayOptions:overlayOptions];
    __weak MTOverlayRoot *weakRoot=root;
    root.optionsChanged=^(NSDictionary *options) {
        overlayOptions=MTNormalizeOverlayOptions(options);
        for (MTOverlayRoot *other in roots) if (other!=weakRoot) [other applyOverlayOptions:overlayOptions];
        updateOverlayInput();
        postOverlayOptions();
    };
    root.actionHandler = ^(MTTrainerAction action) { [gameplay performAction:action]; };
    root.featureHandler = ^(MTFeature feature) { [gameplay performFeature:feature]; };
    root.valueHandler = ^(MTFeature feature, double value) { [gameplay setValue:value forFeature:feature]; };
    [root updateState:gameplay.state];
    [content addSubview:root positioned:NSWindowAbove relativeTo:nil];
    [roots addObject:root];
    updateOverlayInput();
    os_log(runtimeLog, "Overlay attached in game process pid=%{public}d window=%{public}s class=%{public}s",
        getpid(), (candidate.title ?: @"").UTF8String, NSStringFromClass(content.class).UTF8String);
    postOverlayOptions();
}

__attribute__((constructor)) static void startOverlay(void) {
    @autoreleasepool {
        runtimeLog = os_log_create("local.robocop.trainer", "overlay");
        if (!supportedProcess()) { os_log_error(runtimeLog, "Unsupported process; overlay not installed"); return; }
        sessionToken = [NSProcessInfo.processInfo.environment[@"MHT_SESSION"] copy];
        profileID = [NSProcessInfo.processInfo.environment[@"MHT_PROFILE"] copy];
        lastSelection=MTDecodeCheatSelection(MHTNativeSelectionJSON());
        overlayOptions=MTOverlayOptionsForLaunch(MTDecodeOverlayOptions(NSProcessInfo.processInfo.environment[@"MHT_OPTIONS"]));
        os_log(runtimeLog, "Trainer overlay library loaded in pid=%{public}d", getpid());
        dispatch_async(dispatch_get_main_queue(), ^{
            roots = [NSMutableArray new];
            shortcuts=[MTOverlayShortcuts new];deliveryGate=[MTShortcutDeliveryGate new];
            shortcuts.handler=^(MTOverlayShortcut action) {
                MTOverlayRoot *root=NSApp.isActive ? shortcutRoot(nil,YES) : nil;
                if (action==MTShortcutPanel) [root togglePanel:nil];
            };
            activeObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification
                object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) { (void)event; updateOverlayInput(); }];
            inactiveObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidResignActiveNotification
                object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) { (void)event; updateOverlayInput(); }];
            if (sessionToken.length) settingsObserver=[NSDistributedNotificationCenter.defaultCenter
                addObserverForName:MTOverlaySettingsNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *event) {
                    NSDictionary *options=MTOverlayMessageOptions(event.object,sessionToken,getpid());
                    if (!options) return;
                    overlayOptions=options;
                    for (MTOverlayRoot *root in roots) [root applyOverlayOptions:overlayOptions];
                    if(inputMonitorHandler){if(monitor)[NSEvent removeMonitor:monitor];monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown|NSEventMaskLeftMouseDown|NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp handler:inputMonitorHandler];}
                    updateOverlayInput();
                    postOverlayOptions();
                }];
            gameplay = [MTGameBridge new];
            [gameplay restoreSelection:lastSelection];
            MHTStartControl(gameplay, ^NSDictionary *{return overlayOptions;}, ^(NSDictionary *options) {
                overlayOptions=MTNormalizeOverlayOptions(options);
                for (MTOverlayRoot *root in roots) [root applyOverlayOptions:overlayOptions];
                updateOverlayInput();
            });
            gameplay.stateChanged = ^(MTTrainerState *state) {
                for (MTOverlayRoot *root in roots) [root updateState:state];
                // Unreal installs its own local event monitor during startup. Reinstall ours
                // once after the actual gameplay window/weapon context exists, so keys reach
                // the overlay before the engine consumes them. No swizzle or native code hook.
                if(state.ready && state.features[MTFeatureAmmo].available && state.context!=monitoredContext && inputMonitorHandler){
                    monitoredContext=state.context;if(monitor)[NSEvent removeMonitor:monitor];
                    monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown|NSEventMaskLeftMouseDown|NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp handler:inputMonitorHandler];
                }
                postSelection(state);
                // Explicit, bounded verification output; never enabled in normal use.
                NSString *diagnostic=NSProcessInfo.processInfo.environment[@"MT_TRAINER_DIAGNOSTICS"];
                if([diagnostic hasPrefix:@"/private/tmp/"]){
                    NSMutableArray *features=[NSMutableArray new];
                    for(NSInteger i=0;i<MTFeatureCount;i++){MTFeatureState *f=state.features[i];
                        [features addObject:@{@"id":@(i),@"title":MTFeatureInfoAt(i)->title,@"available":@(f.available),@"wanted":@(f.wanted),@"active":@(f.active),@"value":@(f.value),@"note":f.note ?: @""}];}
                    NSDictionary *snapshot=@{@"pid":@(getpid()),@"context":@(state.context),@"ready":@(state.ready),@"mouse":@(state.overlayMouseActive),@"status":state.status ?: @"",@"message":state.message ?: @"",@"features":features,@"measurements":state.diagnosticMeasurements ?: @{},@"overlayKeyEvent":lastOverlayKeyEvent ?: @{},@"appActive":@(NSApp.isActive),@"nativeShortcutRegistered":@(shortcutRefs[0]!=NULL),@"gameplayHotkeysRegistered":@(gameplayRegistrations)};
                    NSData *data=[NSJSONSerialization dataWithJSONObject:snapshot options:NSJSONWritingPrettyPrinted error:NULL];
                    if(data.length<32768)[data writeToFile:diagnostic atomically:YES];
                }
            };
            NSEventMask mask=NSEventMaskKeyDown|NSEventMaskLeftMouseDown|NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp;
            inputMonitorHandler=^NSEvent *(NSEvent *event) {
                if (event.type!=NSEventTypeKeyDown) {
                    // Unreal's native window may consume mouse events before
                    // AppKit dispatches them to the overlay's NSView children.
                    for (MTOverlayRoot *root in roots)
                        if ([root handleMouseEvent:event]) return nil;
                    return event;
                }
                if ([shortcuts ownsLocalEvent:event]) return nil;
                NSInteger nativeIndex=nativeKeyIndex(event);
                if(nativeIndex>=0 && !event.isARepeat && ![deliveryGate acceptCommand:nativeIndex native:NO time:NSProcessInfo.processInfo.systemUptime])return nil;
                // Unreal may deliver keys without an AppKit key-window match after cursor release.
                // Route only inside the active game, including Esc/F9 while loading.
                BOOL isShortcut=MTShortcutForEvent(event)>=0;
                MTOverlayRoot *root=shortcutRoot(event.window,NSApp.isActive);
                BOOL before=root.panelVisible;
                BOOL handled=root && [root handleEvent:event];
                if(NSProcessInfo.processInfo.environment[@"MT_TRAINER_DIAGNOSTICS"] && (isShortcut || event.keyCode==53))
                    lastOverlayKeyEvent=@{@"toggle":@(isShortcut),@"root":@(root!=nil),@"before":@(before),@"after":@(root.panelVisible),@"handled":@(handled),@"repeat":@(event.isARepeat)};
                return handled ? nil : event;
            };
            monitor=[NSEvent addLocalMonitorForEventsMatchingMask:mask handler:inputMonitorHandler];
            attachmentTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) { (void)timer; attachToGameWindow(); }];
            [NSRunLoop.mainRunLoop addTimer:attachmentTimer forMode:NSRunLoopCommonModes];
            gameplayTimer = [NSTimer timerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) { (void)timer; [gameplay poll]; }];
            [NSRunLoop.mainRunLoop addTimer:gameplayTimer forMode:NSRunLoopCommonModes];
            inputTimer=[NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) { (void)timer; updateOverlayInput(); }];
            [NSRunLoop.mainRunLoop addTimer:inputTimer forMode:NSRunLoopCommonModes];
            attachToGameWindow();
        });
    }
}
