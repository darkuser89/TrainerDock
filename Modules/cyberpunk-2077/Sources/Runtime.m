// SPDX-License-Identifier: GPL-3.0-only
#import "Overlay.h"
#import "MHTOverlayHost.h"
#import "MHTRuntimeBridge.h"
#import <os/log.h>
#import <unistd.h>
#import <limits.h>
#import <mach-o/dyld.h>
#import <Carbon/Carbon.h>
#import "GameProfile.h"
#import "SelectionSettings.h"
#import "CyberpunkCursor.h"

static os_log_t runtimeLog;
static NSMutableArray<MTOverlayRoot *> *roots;
static NSMutableArray<MHTOverlayHost *> *overlayHosts;
static NSMutableArray *windowObservers;
static NSString *sessionToken;
static NSString *profileID;
static NSString *lastConnectionNote;
static NSDictionary *lastSelection;
static id monitor;
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
static uint32_t movementInput;
static BOOL flightInput(NSEvent *event){
    BOOL active=gameplay.state.ready && gameplay.state.features[MTFeatureFly].wanted;
    if(!active){movementInput=0;[gameplay setMovementInput:0];return NO;}
    uint32_t bit=0;switch(event.keyCode){case 13:bit=1;break;case 1:bit=2;break;case 0:bit=4;break;case 2:bit=8;break;case 49:bit=16;break;case 8:bit=32;break;default:return NO;}
    if(event.type==NSEventTypeKeyUp)movementInput&=~bit;
    else if(event.type==NSEventTypeKeyDown && !(event.modifierFlags&(NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption)))movementInput|=bit;
    else return NO;
    [gameplay setMovementInput:movementInput];return YES;
}

static MTOverlayRoot *shortcutRoot(NSWindow *eventWindow, BOOL fallback) {
    MTOverlayRoot *best=nil;
    for (MTOverlayRoot *root in roots) {
        NSWindow *window=root.window;
        if (!window || !window.isVisible || window.isMiniaturized) continue;
        if (window==eventWindow || window.parentWindow==eventWindow || window.parentWindow.isKeyWindow) return root;
        if (fallback && (!best || window.parentWindow==NSApp.mainWindow
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
        pressed:GetEventKind(event)==kEventHotKeyPressed timestamp:GetEventTime(event)] ? noErr : eventNotHandledErr;
}
static void updateKeyboardShortcuts(void) {
    // Native registrations exist only while this game's application is active.
    // They do not reserve Command+caret while using another app.
    BOOL enabled=NSApp.isActive && shortcutRoot(nil,YES)!=nil;
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
        UInt32 modifiers=cmdKey|(i==MTShortcutMouse ? optionKey : 0);
        OSStatus status=RegisterEventHotKey(10,modifiers,identifier,GetApplicationEventTarget(),kEventHotKeyNoOptions,&shortcutRefs[i]);
        [shortcuts setRegistered:status==noErr && shortcutRefs[i]!=NULL shortcut:i];
        os_log(runtimeLog,"Native shortcut %ld registration status=%d",(long)i,(int)status);
    }
}
static void updateOverlayInput(void) {
    MTOverlayRoot *root=NSApp.isActive ? shortcutRoot(nil,YES) : nil;
    NSView *view=root.window.parentWindow.contentView;
    BOOL wanted=root.wantsMouseInteraction;
    // Cursor capture belongs to the original GameView, never to the child panel.
    BOOL confirmed=CPUpdateOverlayCursor(view,wanted);updateKeyboardShortcuts();
    for (MHTOverlayHost *host in overlayHosts)
        host.mouseInteractionEnabled=confirmed && host.overlay==root;
    if(inputRequested!=confirmed){inputRequested=confirmed;[gameplay setOverlayInteraction:confirmed];}
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
    // The engine's content tree must never acquire native glass or constraints.
    for (MHTOverlayHost *host in overlayHosts.copy) {
        if (![NSApp.windows containsObject:host.gameWindow] || !host.gameWindow.contentView) {
            [host close]; [roots removeObjectIdenticalTo:(MTOverlayRoot *)host.overlay];
            [overlayHosts removeObjectIdenticalTo:host];
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
    for (MHTOverlayHost *host in overlayHosts) {
        if (host.gameWindow==candidate) { [host synchronize]; return; }
    }
    NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
    MTOverlayRoot *root = [[MTOverlayRoot alloc] initWithFrame:content.bounds version:version];
    root.mouseInteractionSupported=YES;
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
    MHTOverlayHost *host=[[MHTOverlayHost alloc]initWithGameWindow:candidate overlay:root];
    host.mouseHandler=^BOOL(NSEvent *event) {
        MTOverlayRoot *owner=weakRoot; return owner && [owner handleMouseEvent:event];
    };
    [overlayHosts addObject:host];
    [roots addObject:root];
    updateOverlayInput();
    os_log(runtimeLog, "Overlay attached in game process pid=%{public}d window=%{public}s class=%{public}s",
        getpid(), (candidate.title ?: @"").UTF8String, NSStringFromClass(content.class).UTF8String);
    postOverlayOptions();
}

static void observeWindowGeometry(void) {
    windowObservers=[NSMutableArray new];
    __block BOOL pending=NO; // Accessed only in the main-queue blocks below.
    for(NSNotificationName name in @[NSWindowDidResizeNotification,NSWindowDidMoveNotification,
        NSWindowDidChangeScreenNotification,NSWindowDidEnterFullScreenNotification,NSWindowDidExitFullScreenNotification]) {
        id observer=[NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *event){
            if(![event.object isKindOfClass:NSWindow.class] || [event.object isKindOfClass:NSPanel.class])return;
            // Never synchronously wait for AppKit from an engine notification.
            dispatch_async(dispatch_get_main_queue(),^{
                if(pending)return;pending=YES;
                dispatch_async(dispatch_get_main_queue(),^{pending=NO;attachToGameWindow();updateOverlayInput();});
            });
        }];
        [windowObservers addObject:observer];
    }
}

__attribute__((constructor)) static void startOverlay(void) {
    @autoreleasepool {
        runtimeLog = os_log_create("local.mactrainer.template", "overlay");
        if (!supportedProcess()) { os_log_error(runtimeLog, "Unsupported process; overlay not installed"); return; }
        sessionToken = [NSProcessInfo.processInfo.environment[@"MHT_SESSION"] copy];
        profileID = [NSProcessInfo.processInfo.environment[@"MHT_PROFILE"] copy];
        lastSelection=MTDecodeCheatSelection(MHTNativeSelectionJSON());
        overlayOptions=MTOverlayOptionsForLaunch(MTDecodeOverlayOptions(NSProcessInfo.processInfo.environment[@"MHT_OPTIONS"]));
        os_log(runtimeLog, "Trainer overlay library loaded in pid=%{public}d", getpid());
        dispatch_async(dispatch_get_main_queue(), ^{
            roots = [NSMutableArray new];
            overlayHosts = [NSMutableArray new];
            shortcuts=[MTOverlayShortcuts new];
            shortcuts.handler=^(MTOverlayShortcut action) {
                MTOverlayRoot *root=NSApp.isActive ? shortcutRoot(nil,YES) : nil;
                if (action==MTShortcutPanel) [root togglePanel:nil];
                else if (action==MTShortcutMouse) [root toggleMouseInteraction];
            };
            activeObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification
                object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) { (void)event; updateOverlayInput(); }];
            inactiveObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidResignActiveNotification
                object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) { (void)event; movementInput=0;[gameplay setMovementInput:0];updateOverlayInput(); }];
            if (sessionToken.length) settingsObserver=[NSDistributedNotificationCenter.defaultCenter
                addObserverForName:MTOverlaySettingsNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *event) {
                    NSDictionary *options=MTOverlayMessageOptions(event.object,sessionToken,getpid());
                    if (!options) return;
                    overlayOptions=options;
                    for (MTOverlayRoot *root in roots) [root applyOverlayOptions:overlayOptions];
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
                NSString *connection=state.ready ? @"Lokaler Einzelspieler bereit." : state.message;
                if(![lastConnectionNote isEqual:connection]){lastConnectionNote=[connection copy];os_log(runtimeLog,"Spielanbindung: %{public}s",connection.UTF8String);}
                if(!state.ready || !state.features[MTFeatureFly].wanted){movementInput=0;[gameplay setMovementInput:0];}
                for (MTOverlayRoot *root in roots) [root updateState:state];
                postSelection(state);
            };
            NSEventMask mask=NSEventMaskKeyDown|NSEventMaskKeyUp|NSEventMaskLeftMouseDown|NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp|NSEventMaskRightMouseDown|NSEventMaskRightMouseUp|NSEventMaskOtherMouseDown|NSEventMaskOtherMouseUp|NSEventMaskMouseMoved|NSEventMaskRightMouseDragged|NSEventMaskOtherMouseDragged|NSEventMaskScrollWheel;
            monitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
                if(event.type==NSEventTypeKeyUp)return shortcutRoot(event.window,NO) && flightInput(event) ? nil : event;
                if (event.type!=NSEventTypeKeyDown) {
                    // Deliver overlay clicks first, then keep gameplay mouse
                    // input out of the engine while the trainer owns its cursor.
                    for (MTOverlayRoot *root in roots)
                        if ([root handleMouseEvent:event]) return nil;
                    return CPOverlayCursorActive() ? nil : event;
                }
                if ([shortcuts ownsLocalEvent:event]) return nil;
                // UIOnly may deliver command events without a key-window match.
                BOOL isShortcut=MTShortcutForEvent(event)>=0;
                MTOverlayRoot *root=shortcutRoot(event.window,isShortcut && NSApp.isActive);
                BOOL handled=root && [root handleEvent:event];
                if(handled){if(event.keyCode==111){movementInput=0;[gameplay setMovementInput:0];}return nil;}
                if(CPOverlayCursorActive() && !(event.modifierFlags&NSEventModifierFlagCommand))return nil;
                return root && flightInput(event) ? nil : event;
            }];
            attachmentTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) { (void)timer; attachToGameWindow(); }];
            [NSRunLoop.mainRunLoop addTimer:attachmentTimer forMode:NSRunLoopCommonModes];
            gameplayTimer = [NSTimer timerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) { (void)timer; [gameplay poll]; }];
            [NSRunLoop.mainRunLoop addTimer:gameplayTimer forMode:NSRunLoopCommonModes];
            inputTimer=[NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) { (void)timer; updateOverlayInput(); }];
            [NSRunLoop.mainRunLoop addTimer:inputTimer forMode:NSRunLoopCommonModes];
            observeWindowGeometry();attachToGameWindow();
        });
    }
}
