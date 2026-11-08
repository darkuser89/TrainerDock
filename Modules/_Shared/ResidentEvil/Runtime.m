// SPDX-License-Identifier: GPL-3.0-only
#import "Overlay.h"
#import "MHTOverlayHost.h"
#import "MHTRuntimeBridge.h"
#import "CheatPreferences.h"
#import "LocalControl.h"
#import <os/log.h>
#import <unistd.h>
#import <limits.h>
#import <mach-o/dyld.h>
#import <Carbon/Carbon.h>
#import "GameProfile.h"
#import "RE2Engine.h"

static os_log_t runtimeLog;
static NSMutableArray<RE2OverlayRoot *> *roots;
static NSMutableArray<MHTOverlayHost *> *overlayHosts;
static NSMutableArray *windowObservers;
static NSString *sessionToken;
static id monitor;
static NSTimer *attachmentTimer;
static NSTimer *gameplayTimer;
static RE2GameBridge *gameplay;
static NSDictionary *overlayOptions;
static id settingsObserver;
static NSTimer *inputTimer;
static BOOL inputRequested;
static RE2OverlayShortcuts *shortcuts;
static BOOL shortcutsEnabled;
static id activeObserver, inactiveObserver;
static NSDictionary *lastSelection;
static MTLocalControl *localControl;

static RE2OverlayRoot *shortcutRoot(NSWindow *eventWindow, BOOL fallback) {
    RE2OverlayRoot *best=nil;
    for (RE2OverlayRoot *root in roots) {
        NSWindow *window=root.window;
        if (!window || !window.isVisible || window.isMiniaturized) continue;
        if (window==eventWindow || window.parentWindow==eventWindow || window.parentWindow.isKeyWindow) return root;
        if (fallback && (!best || window.parentWindow==NSApp.mainWindow
            || root.bounds.size.width*root.bounds.size.height>best.bounds.size.width*best.bounds.size.height)) best=root;
    }
    return best;
}
static void updateKeyboardShortcuts(void) {
    // One AppKit path owns these keys. Synthetic/local events need not produce
    // a Carbon hotkey event; swallowing them on registration lost toggles.
    BOOL enabled=NSApp.isActive && shortcutRoot(nil,YES)!=nil;
    if(enabled==shortcutsEnabled)return;
    shortcutsEnabled=enabled;shortcuts.enabled=enabled;
}
static void updateOverlayInput(void) {
    updateKeyboardShortcuts();
    RE2OverlayRoot *root=NSApp.isActive ? shortcutRoot(nil,YES) : nil;
    BOOL wanted=root.wantsMouseInteraction;
    for (MHTOverlayHost *host in overlayHosts)
        host.mouseInteractionEnabled=wanted && host.overlay==root;
    if (inputRequested!=wanted) { inputRequested=wanted; [gameplay setOverlayInteraction:wanted]; }
}

static void postOverlayOptions(void) {
    if (!sessionToken.length) return;
    @try {
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:RE2OverlayChangedNotification
            object:RE2OverlayMessage(overlayOptions,sessionToken,getpid()) userInfo:nil deliverImmediately:YES];
    } @catch (NSException *exception) {
        os_log(runtimeLog,"Optional overlay settings notification unavailable: %{public}s",exception.name.UTF8String);
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
            [host close]; [roots removeObjectIdenticalTo:(RE2OverlayRoot *)host.overlay];
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
    RE2OverlayRoot *root = [[RE2OverlayRoot alloc] initWithFrame:content.bounds version:version];
    [root applyOverlayOptions:overlayOptions];
    __weak RE2OverlayRoot *weakRoot=root;
    root.optionsChanged=^(NSDictionary *options) {
        overlayOptions=RE2NormalizeOverlayOptions(options);
        for (RE2OverlayRoot *other in roots) if (other!=weakRoot) [other applyOverlayOptions:overlayOptions];
        updateOverlayInput();
        postOverlayOptions();
    };
    root.actionHandler = ^(RE2TrainerAction action) { [gameplay performAction:action]; };
    root.featureHandler = ^(RE2Feature feature) { [gameplay performFeature:feature]; };
    root.valueHandler = ^(RE2Feature feature, double value) { [gameplay setValue:value forFeature:feature]; };
    [root updateState:gameplay.state];
    MHTOverlayHost *host=[[MHTOverlayHost alloc]initWithGameWindow:candidate overlay:root];
    host.mouseHandler=^BOOL(NSEvent *event) {
        RE2OverlayRoot *owner=weakRoot; return owner && [owner handleMouseEvent:event];
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

static void startOverlayImplementation(BOOL development) {
    @autoreleasepool {
        runtimeLog = os_log_create("local.mactrainer.re2", "overlay");
        BOOL inspection=[NSProcessInfo.processInfo.environment[@"RE2_OVERLAY_CHECK"] isEqual:@"1"];
        BOOL authorizedStartup=[NSProcessInfo.processInfo.environment[@"RE2_NATIVE_STARTUP"] isEqual:@"1"];
        if([NSProcessInfo.processInfo.environment[@"RE2_NATIVE_TEST"] isEqual:@"1"] && !inspection){
            MTRE2Engine *engine=MTRE2Engine.shared;
            if(!engine.identified)return;
            dispatch_async(dispatch_get_main_queue(),^{
                attachmentTimer=[NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer){
                    if([engine installGameThreadDelivery]){[timer invalidate];os_log(runtimeLog,"RE2 native gameplay callback installed; no cheat selected.");}
                }];
                [NSRunLoop.mainRunLoop addTimer:attachmentTimer forMode:NSRunLoopCommonModes];
            });
            return;
        }
        if (!((development || (inspection && authorizedStartup)) ? MTRE2Engine.shared.identified : supportedProcess())) { os_log_error(runtimeLog, "Unsupported process; overlay not installed"); return; }
        sessionToken = [NSProcessInfo.processInfo.environment[@"MHT_SESSION"] copy];
        overlayOptions=RE2OverlayOptionsForLaunch(RE2DecodeOverlayOptions(NSProcessInfo.processInfo.environment[@"MHT_OPTIONS"]));
        os_log(runtimeLog, "Trainer overlay library loaded in pid=%{public}d inspection=%{public}d", getpid(),inspection);
        dispatch_async(dispatch_get_main_queue(), ^{
            roots = [NSMutableArray new];
            overlayHosts = [NSMutableArray new];
            shortcuts=[RE2OverlayShortcuts new];
            shortcuts.handler=^(RE2OverlayShortcut action) {
                RE2OverlayRoot *root=NSApp.isActive ? shortcutRoot(nil,YES) : nil;
                if (action==RE2ShortcutPanel) [root togglePanel:nil];
            };
            activeObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification
                object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) { (void)event; updateOverlayInput(); }];
            inactiveObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidResignActiveNotification
                object:NSApp queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) { (void)event; updateOverlayInput(); }];
            if (sessionToken.length) settingsObserver=[NSDistributedNotificationCenter.defaultCenter
                addObserverForName:RE2OverlaySettingsNotification object:nil queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *event) {
                    NSDictionary *options=RE2OverlayMessageOptions(event.object,sessionToken,getpid());
                    if (!options) return;
                    overlayOptions=options;
                    for (RE2OverlayRoot *root in roots) [root applyOverlayOptions:overlayOptions];
                    updateOverlayInput();
                    postOverlayOptions();
                }];
            NSString *profile=NSProcessInfo.processInfo.environment[@"MHT_PROFILE"];
            NSDictionary *saved=RE2DecodeSelection(MHTNativeSelectionJSON(),profile);
            gameplay = [[RE2GameBridge alloc]initWithAdapter:RE2CreateGameAdapter() readOnly:inspection restoreSelection:saved];
            MHTStartControl(gameplay, ^NSDictionary *{return overlayOptions;}, ^(NSDictionary *options) {
                overlayOptions=RE2NormalizeOverlayOptions(options);
                for (RE2OverlayRoot *root in roots) [root applyOverlayOptions:overlayOptions];
                updateOverlayInput();
            });
            gameplay.stateChanged = ^(RE2TrainerState *state) {
                for (RE2OverlayRoot *root in roots) [root updateState:state];
                // Never publish startup's temporary all-off state over a saved
                // selection waiting for its first confirmed gameplay context.
                if(!inspection && !state.selectionPending && sessionToken.length){
                    NSDictionary *selection=RE2SelectionFromState(state,profile);
                    if(selection && ![selection isEqual:lastSelection]){
                        lastSelection=selection;
                        @try{[NSDistributedNotificationCenter.defaultCenter postNotificationName:RE2SelectionChangedNotification object:RE2SelectionMessage(selection,sessionToken,getpid()) userInfo:nil deliverImmediately:YES];}
                        @catch(NSException *exception){os_log(runtimeLog,"Selection notification unavailable: %{public}s",exception.name.UTF8String);}
                    }
                }
            };
            NSDictionary *config=MTLoadConfiguration(NSProcessInfo.processInfo.environment[@"MHT_CONFIG"],NULL);
            localControl=[[MTLocalControl alloc]initWithMetadata:@{@"profile":profile ?: @"",@"session":sessionToken ?: @"",@"pid":@(getpid()),@"build":config[@"app"][@"build"] ?: @"?",@"game":RE2GameShortName()} handler:^(NSDictionary *request,MTControlReply reply){
                [gameplay controlCommand:request completion:^(RE2TrainerState *state,NSString *error){
                    NSMutableDictionary *snapshot=[MTControlSnapshot(state) mutableCopy];BOOL visible=NO;for(RE2OverlayRoot *r in roots)visible|=r.panelVisible;snapshot[@"overlayVisible"]=@(visible);
                    reply(error ? @{@"ok":@NO,@"error":error,@"state":snapshot} : @{@"ok":@YES,@"state":snapshot});
                }];
            }];
            if(localControl)os_log(runtimeLog,"Local session control interface ready; overlay visibility independent");
            NSEventMask mask=NSEventMaskKeyDown|NSEventMaskLeftMouseDown|NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp;
            monitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event) {
                if (event.type!=NSEventTypeKeyDown) {
                    // Unreal's native window may consume mouse events before
                    // AppKit dispatches them to the overlay's NSView children.
                    for (RE2OverlayRoot *root in roots)
                        if ([root handleMouseEvent:event]) return nil;
                    return event;
                }
                if ([shortcuts ownsLocalEvent:event]) return nil;
                // UIOnly may deliver command events without a key-window match.
                BOOL isShortcut=RE2ShortcutForEvent(event)>=0;
                RE2OverlayRoot *root=shortcutRoot(event.window,isShortcut && NSApp.isActive);
                BOOL handled=root && [root handleEvent:event];
                return handled ? nil : event;
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

void RE2InstallDevelopmentTrainer(void){if(![NSProcessInfo.processInfo.environment[@"RE2_NATIVE_STARTUP"] isEqual:@"1"])return;static dispatch_once_t once;dispatch_once(&once,^{startOverlayImplementation(YES);});}
__attribute__((constructor)) static void startOverlay(void){startOverlayImplementation(NO);}
