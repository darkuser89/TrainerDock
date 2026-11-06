// SPDX-License-Identifier: GPL-3.0-only
#import "Overlay.h"
#import "MHTRuntimeBridge.h"
#import "MHTOverlayHost.h"
#import <os/log.h>
#import <unistd.h>
#import <limits.h>
#import <mach-o/dyld.h>
#import <Carbon/Carbon.h>
#import "GameEdition.h"
#import "SelectionSettings.h"

static os_log_t runtimeLog;
static NSMutableArray<DI2OverlayRoot *> *roots;
static NSMutableArray<MHTOverlayHost *> *overlayHosts;
static NSString *sessionToken, *selectionProfile;
static NSDictionary *lastSelection;
static id monitor;
static NSTimer *attachmentTimer;
static NSTimer *gameplayTimer;
static DI2GameBridge *gameplay;
static NSDictionary *overlayOptions;
static id settingsObserver;
static NSTimer *inputTimer;
static BOOL inputRequested;
static DI2OverlayShortcuts *shortcuts;
static EventHotKeyRef shortcutRefs[DI2ShortcutCount];
static EventHandlerRef shortcutHandler;
static BOOL shortcutsEnabled;
static id activeObserver, inactiveObserver;

static DI2OverlayRoot *shortcutRoot(NSWindow *eventWindow, BOOL fallback) {
    DI2OverlayRoot *best=nil;
    for (DI2OverlayRoot *root in roots) {
        NSWindow *window=root.window;
        if (!window || !window.isVisible || window.isMiniaturized) continue;
        if (window==eventWindow || window.parentWindow==eventWindow || window.parentWindow.isKeyWindow) return root;
        if (fallback && (!best || window==NSApp.mainWindow
            || root.bounds.size.width*root.bounds.size.height>best.bounds.size.width*best.bounds.size.height)) best=root;
    }
    return best;
}
static OSStatus overlayHotkey(EventHandlerCallRef next, EventRef event, void *context) {
    (void)next; (void)context;
    EventHotKeyID identifier={0};
    if (GetEventParameter(event,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(identifier),NULL,&identifier)!=noErr
        || identifier.signature!=0x44325452 || identifier.id<1 || identifier.id>DI2ShortcutCount) return eventNotHandledErr;
    if (!NSApp.isActive) return eventNotHandledErr;
    return [shortcuts nativeShortcut:(DI2OverlayShortcut)(identifier.id-1)
        pressed:GetEventKind(event)==kEventHotKeyPressed] ? noErr : eventNotHandledErr;
}
static void updateKeyboardShortcuts(void) {
    // Native registrations exist only while this game's application is active.
    // They do not reserve Command+caret while using another app.
    BOOL enabled=NSApp.isActive && shortcutRoot(nil,YES)!=nil;
    if (enabled==shortcutsEnabled) return;
    shortcutsEnabled=enabled; shortcuts.enabled=enabled;
    if (!enabled) {
        for (NSInteger i=0;i<DI2ShortcutCount;i++) {
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
    for (NSInteger i=0;i<DI2ShortcutCount;i++) {
        EventHotKeyID identifier={0x44325452,(UInt32)i+1};
        NSInteger index=i==DI2ShortcutPanel ? DI2HotkeyPanel : DI2HotkeyMouse;
        DI2HotkeyBinding *binding=DI2HotkeyAt(index);
        if(!binding.available)continue;
        NSEventModifierFlags flags=binding.modifiers;
        UInt32 modifiers=(flags&NSEventModifierFlagCommand ? cmdKey : 0)|(flags&NSEventModifierFlagOption ? optionKey : 0)
            |(flags&NSEventModifierFlagShift ? shiftKey : 0)|(flags&NSEventModifierFlagControl ? controlKey : 0);
        OSStatus status=RegisterEventHotKey(binding.keyCode,modifiers,identifier,GetApplicationEventTarget(),kEventHotKeyNoOptions,&shortcutRefs[i]);
        if(status==eventHotKeyExistsErr) {
            DI2BlockHotkey(index);
            for(DI2OverlayRoot *root in roots)[root refreshHotkeyLabels];
        }
        [shortcuts setRegistered:status==noErr && shortcutRefs[i]!=NULL shortcut:i];
        os_log(runtimeLog,"Native shortcut %ld registration status=%d",(long)i,(int)status);
    }
}
static void refreshKeyboardShortcuts(void) {
    // Release prior native registrations before applying a fresh OS snapshot.
    for(NSInteger i=0;i<DI2ShortcutCount;i++) {
        if(shortcutRefs[i]) { UnregisterEventHotKey(shortcutRefs[i]);shortcutRefs[i]=NULL; }
        [shortcuts setRegistered:NO shortcut:i];
    }
    shortcutsEnabled=NO;shortcuts.enabled=NO;
    DI2ReloadSystemHotkeys();
    for(DI2OverlayRoot *root in roots)[root refreshHotkeyLabels];
    updateKeyboardShortcuts();
}
static void updateOverlayInput(void) {
    for(MHTOverlayHost *host in overlayHosts){
        [host synchronize];
        host.mouseInteractionEnabled=NSApp.isActive && host.gameWindow.isKeyWindow
            && [(DI2OverlayRoot *)host.overlay wantsMouseInteraction];
    }
    updateKeyboardShortcuts();
    BOOL wanted=NO;
    for (DI2OverlayRoot *root in roots) if (NSApp.isActive && root.window.parentWindow.isKeyWindow && root.wantsMouseInteraction) { wanted=YES; break; }
    if (inputRequested!=wanted) { inputRequested=wanted; [gameplay setOverlayInteraction:wanted]; }
}

static void postOverlayOptions(void) {
    if (!sessionToken.length) return;
    @try {
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:DI2OverlayChangedNotification
            object:DI2OverlayMessage(overlayOptions,sessionToken,getpid()) userInfo:nil deliverImmediately:YES];
    } @catch (NSException *exception) {
        os_log(runtimeLog,"Optional overlay settings notification unavailable: %{public}s",exception.name.UTF8String);
    }
}

static void postSelection(DI2TrainerState *state) {
    if (!sessionToken.length || !selectionProfile.length || !state.selectionCanBeSaved) return;
    NSDictionary *selection=DI2SelectionFromState(state);
    if ([selection isEqual:lastSelection]) return;
    lastSelection=selection;
    @try {
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:DI2SelectionChangedNotification
            object:DI2SelectionMessage(selection,sessionToken,selectionProfile,getpid()) userInfo:nil deliverImmediately:YES];
    } @catch (NSException *exception) {
        lastSelection=nil; // Retry on the next poll if optional IPC failed.
        os_log(runtimeLog,"Optional selection notification unavailable: %{public}s",exception.name.UTF8String);
    }
}

static BOOL supportedProcess(void) {
    NSString *identifier = NSBundle.mainBundle.bundleIdentifier;
#ifdef DI2_OVERLAY_TEST
    return [identifier isEqualToString:@"local.deadisland2.trainer-test"];
#else
    if (![identifier isEqualToString:DI2EditionBundleID(DI2EditionMAS)]
        && ![identifier isEqualToString:DI2EditionBundleID(DI2EditionSteam)]) return NO;
    NSString *target = NSProcessInfo.processInfo.environment[@"MHT_TARGET"];
    if (!target.length) return NO;
    uint32_t size = PATH_MAX;
    char executable[PATH_MAX], actual[PATH_MAX], expected[PATH_MAX];
    if (_NSGetExecutablePath(executable, &size) || !realpath(executable, actual)
        || !realpath(target.fileSystemRepresentation, expected)) return NO;
    return strcmp(actual, expected) == 0 && strcmp(strrchr(actual, '/') + 1, "DeadIsland2") == 0;
#endif
}

static void attachToGameWindow(void) {
    if (!NSApp || ![NSThread isMainThread]) return;
    // Recreate independent overlay windows after engine window/content replacement.
    for(MHTOverlayHost *host in overlayHosts.copy){
        if(![NSApp.windows containsObject:host.gameWindow] || !host.gameWindow.contentView){
            [host close];[roots removeObjectIdenticalTo:(DI2OverlayRoot *)host.overlay];[overlayHosts removeObjectIdenticalTo:host];
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
    for(MHTOverlayHost *host in overlayHosts)if(host.gameWindow==candidate){[host synchronize];return;}
    DI2GameEdition edition=DI2EditionForKey(NSProcessInfo.processInfo.environment[@"MHT_PROFILE"]);
    if (edition==DI2EditionUnknown) edition=[NSBundle.mainBundle.infoDictionary[@"CFBundleIdentifier"] isEqual:DI2EditionBundleID(DI2EditionMAS)] ? DI2EditionMAS : DI2EditionSteam;
    NSString *version=[NSString stringWithFormat:@"%@ %@",DI2EditionTitle(edition),[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?"];
    DI2OverlayRoot *root = [[DI2OverlayRoot alloc] initWithFrame:content.bounds version:version];
    [root applyOverlayOptions:overlayOptions];
    __weak DI2OverlayRoot *weakRoot=root;
    root.optionsChanged=^(NSDictionary *options) {
        overlayOptions=DI2NormalizeOverlayOptions(options);
        for (DI2OverlayRoot *other in roots) if (other!=weakRoot) [other applyOverlayOptions:overlayOptions];
        updateOverlayInput();
        postOverlayOptions();
    };
    root.actionHandler = ^(DI2TrainerAction action) { [gameplay performAction:action]; };
    root.featureHandler = ^(DI2Feature feature) { [gameplay performFeature:feature]; };
    root.valueHandler = ^(DI2Feature feature, double value) { [gameplay setValue:value forFeature:feature]; };
    [root updateState:gameplay.state];
    MHTOverlayHost *host=[[MHTOverlayHost alloc]initWithGameWindow:candidate overlay:root];
    host.mouseHandler=^BOOL(NSEvent *event){return [weakRoot handleMouseEvent:event];};
    [overlayHosts addObject:host];
    [roots addObject:root];
    updateOverlayInput();
    os_log(runtimeLog, "Overlay attached in game process pid=%{public}d window=%{public}s class=%{public}s",
        getpid(), (candidate.title ?: @"").UTF8String, NSStringFromClass(content.class).UTF8String);
    postOverlayOptions();
}

__attribute__((constructor)) static void startOverlay(void) {
    @autoreleasepool {
        runtimeLog = os_log_create("local.deadisland2.trainer", "overlay");
        if (!supportedProcess()) { os_log_error(runtimeLog, "Unsupported process; overlay not installed"); return; }
        sessionToken = [NSProcessInfo.processInfo.environment[@"MHT_SESSION"] copy];
        selectionProfile=[NSProcessInfo.processInfo.environment[@"MHT_PROFILE"] copy];
        overlayOptions=DI2InitialOverlayOptions(DI2DecodeOverlayOptions(NSProcessInfo.processInfo.environment[@"MHT_OPTIONS"]));
        os_log(runtimeLog, "Trainer overlay library loaded in pid=%{public}d", getpid());
        dispatch_async(dispatch_get_main_queue(), ^{
            roots = [NSMutableArray new];overlayHosts=[NSMutableArray new];
            shortcuts=[DI2OverlayShortcuts new];
            shortcuts.handler=^(DI2OverlayShortcut action) {
                DI2OverlayRoot *root=NSApp.isActive ? shortcutRoot(nil,YES) : nil;
                if (action==DI2ShortcutPanel) [root togglePanel:nil];
                else if (action==DI2ShortcutMouse) [root toggleMouseInteraction];
            };
            activeObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification
                object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) { (void)event; refreshKeyboardShortcuts(); }];
            inactiveObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidResignActiveNotification
                object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) { (void)event; updateKeyboardShortcuts(); }];
            if (sessionToken.length) settingsObserver=[NSDistributedNotificationCenter.defaultCenter
                addObserverForName:DI2OverlaySettingsNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *event) {
                    NSDictionary *options=DI2OverlayMessageOptions(event.object,sessionToken,getpid());
                    if (!options) return;
                    overlayOptions=options;
                    for (DI2OverlayRoot *root in roots) [root applyOverlayOptions:overlayOptions];
                    updateOverlayInput();
                    postOverlayOptions();
                }];
            gameplay = [DI2GameBridge new];
            [gameplay restoreSelection:DI2DecodeCheatSelection(MHTNativeSelectionJSON())];
            MHTStartControl(gameplay, ^NSDictionary *{return overlayOptions;}, ^(NSDictionary *options) {
                overlayOptions=DI2NormalizeOverlayOptions(options);
                for (DI2OverlayRoot *root in roots) [root applyOverlayOptions:overlayOptions];
                updateOverlayInput();
            });
            gameplay.stateChanged = ^(DI2TrainerState *state) {
                for (DI2OverlayRoot *root in roots) [root updateState:state];
                postSelection(state);
            };
            NSEventMask mask=NSEventMaskKeyDown|NSEventMaskLeftMouseDown|NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp;
            monitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
                if (event.type!=NSEventTypeKeyDown) {
                    // Unreal's native window may consume mouse events before
                    // AppKit dispatches them to the overlay's NSView children.
                    for (DI2OverlayRoot *root in roots)
                        if ([root handleMouseEvent:event]) return nil;
                    return event;
                }
                if ([shortcuts ownsLocalEvent:event]) return nil;
                // UIOnly may deliver command events without a key-window match.
                BOOL isShortcut=DI2ShortcutForEvent(event)>=0;
                DI2OverlayRoot *root=shortcutRoot(event.window,isShortcut && NSApp.isActive);
                BOOL handled=root && [root handleEvent:event];
                return handled ? nil : event;
            }];
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
