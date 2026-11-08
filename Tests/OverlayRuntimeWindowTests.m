// SPDX-License-Identifier: GPL-3.0-only
// Compile the selected trainer's real attachment and input code into a UI fixture.
// No original game process, save, native binding or effect is used.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <unistd.h>
#import "Runtime.m"
#import "TrainerMaterial.h"
#if defined(MHT_RE)
#define TestRoot RE2OverlayRoot
#define TestState RE2TrainerState
#define TestFeatureState RE2FeatureState
#define TestFeature RE2Feature
#define TestNormalizeOverlayOptions RE2NormalizeOverlayOptions
static IMP originalBundleIdentifier;
static NSString *testBundleIdentifier;
static NSString *fixtureBundleIdentifier(NSBundle *bundle,SEL selector) {
    return bundle==NSBundle.mainBundle ? testBundleIdentifier : ((id(*)(id,SEL))originalBundleIdentifier)(bundle,selector);
}
#else
#define TestRoot MTOverlayRoot
#define TestState MTTrainerState
#define TestFeatureState MTFeatureState
#define TestFeature MTFeature
#define TestNormalizeOverlayOptions MTNormalizeOverlayOptions
#endif
static void MHTCheckOverlayHost(void){
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    runtimeLog=os_log_create("local.trainerdock.tests.liesofp","overlay");
    roots=[NSMutableArray new];overlayHosts=[NSMutableArray new];
    overlayOptions=TestNormalizeOverlayOptions(@{@"visible":@YES,@"glassIntensity":@0.5});
    NSWindow *game=[[NSWindow alloc]initWithContentRect:NSMakeRect(100,100,1200,900)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    game.releasedWhenClosed=NO;NSView *original=game.contentView;
    NSArray *views=original.subviews.copy,*constraints=original.constraints.copy;
    [game orderFront:nil];attachToGameWindow();observeWindowGeometry();
    NSCAssert(roots.count==1 && overlayHosts.count==1,@"Real runtime attaches once to the game fixture");
    TestRoot *root=roots.firstObject;MHTOverlayHost *host=overlayHosts.firstObject;
    NSCAssert(root.window==host.panel && host.panel.parentWindow==game,@"Native glass lives in an isolated child panel");
    NSCAssert(shortcutRoot(game,NO)==root,@"Game-window shortcuts resolve the child-panel overlay");
    NSCAssert(!host.panel.canBecomeKeyWindow && (host.panel.collectionBehavior&NSWindowCollectionBehaviorFullScreenAuxiliary),@"Fullscreen auxiliary panel leaves keyboard focus with the game");
    [host.panel.contentView layoutSubtreeIfNeeded];
    __block NSException *failure=nil;dispatch_group_t group=dispatch_group_create();
    dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        @try {for(NSUInteger i=0;i<120;i++){(void)game.isZoomed;
            [NSNotificationCenter.defaultCenter postNotificationName:NSWindowDidResizeNotification object:game];usleep(1000);}}
        @catch(NSException *exception){failure=exception;}
    });
    for(NSUInteger i=0;i<24;i++) {
        [game setFrame:NSMakeRect(100,100,i%2?1440:1000,i%2?1000:720) display:NO];
        [root applyOverlayOptions:@{@"visible":@YES,@"glassIntensity":@(i%3*0.5)}];
        [host synchronize];[host.panel.contentView layoutSubtreeIfNeeded];
        NSCAssert(NSEqualSizes(root.bounds.size,original.bounds.size),@"Overlay follows fullscreen-sized geometry");
        NSCAssert(game.contentView==original && [views isEqual:original.subviews] && [constraints isEqual:original.constraints],@"Engine content and its constraints remain untouched");
        [[NSNotificationCenter defaultCenter]postNotificationName:i%2?NSWindowDidEnterFullScreenNotification:NSWindowDidExitFullScreenNotification object:game];
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
        NSCAssert(roots.count==1 && overlayHosts.count==1 && roots.firstObject==root,@"Geometry/fullscreen notifications do not attach duplicate views");
    }
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
    while(dispatch_group_wait(group,DISPATCH_TIME_NOW) && deadline.timeIntervalSinceNow>0)
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    NSCAssert(!dispatch_group_wait(group,DISPATCH_TIME_NOW) && !failure,@"Unreal-style off-main-thread window queries finish without entering the glass layout engine");
    TestState *state=[TestState new];state.ready=YES;
    for(TestFeatureState *feature in state.features)feature.available=YES;
    [root updateState:state];[root layout];
    __block NSUInteger clicks=0;__block NSInteger selected=-1;
    root.featureHandler=^(TestFeature feature){clicks++;selected=feature;};
    NSView *row=nil;
    for(NSView *view in ((MTTrainerMaterial *)root.panel).contentView.subviews)
        if([view.accessibilityRole isEqual:NSAccessibilityCheckBoxRole]){row=view;break;}
    NSCAssert(row,@"Native feature row remains present");
    NSInteger expected=[[row valueForKey:@"feature"] integerValue];host.mouseInteractionEnabled=YES;
    NSPoint at=[row convertPoint:NSMakePoint(80,10) toView:nil];
    for(NSUInteger i=0;i<2;i++){
        NSEvent *event=[NSEvent mouseEventWithType:i?NSEventTypeLeftMouseUp:NSEventTypeLeftMouseDown location:at modifierFlags:0 timestamp:1+i windowNumber:host.panel.windowNumber context:nil eventNumber:i clickCount:1 pressure:i?0:1];
        [host.panel sendEvent:event];
    }
    NSCAssert(clicks==1 && selected==expected,@"Child-panel click reaches the correct real feature exactly once");
    NSPoint screen=[host.panel convertPointToScreen:at],fromGame=[game convertPointFromScreen:screen];
    NSEvent *originalClick=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:fromGame modifierFlags:0 timestamp:3 windowNumber:game.windowNumber context:nil eventNumber:3 clickCount:1 pressure:1];
    NSCAssert([root handleMouseEvent:originalClick] && clicks==2,@"Game-window mouse coordinates map correctly after resizing");
    NSView *replacement=[[NSView alloc]initWithFrame:original.frame];game.contentView=replacement;
    attachToGameWindow();[host synchronize];
    NSCAssert(roots.count==1 && overlayHosts.count==1 && replacement.subviews.count==0 && replacement.constraints.count==0,@"Recreated game content stays separate from the existing overlay");
    host.mouseInteractionEnabled=NO;NSCAssert(host.panel.ignoresMouseEvents,@"Closing interaction restores click-through");
    for(id observer in windowObservers)[NSNotificationCenter.defaultCenter removeObserver:observer];windowObservers=nil;
    [host close];[overlayHosts removeAllObjects];[roots removeAllObjects];
    NSCAssert(!host.panel.parentWindow && !root.superview,@"Overlay detaches cleanly");
    [game orderOut:nil];[game close];
    puts("PASS: actual runtime attachment, isolated glass, 120 worker window queries, 24 resize/fullscreen notifications, no duplicate roots, mouse mapping and teardown. No game started.");
}

static void MHTCheckRuntimeWindows(void) {
#if __has_include("CrimsonNative.h")
    MTUseCrimsonFeatures();
#endif
#if defined(MHT_RE)
    Method method=class_getInstanceMethod(NSBundle.class,@selector(bundleIdentifier));
    originalBundleIdentifier=method_setImplementation(method,(IMP)fixtureBundleIdentifier);
    for(NSString *identifier in @[@"jp.co.capcom.RE2US",@"jp.co.capcom.RE3US",@"jp.co.capcom.RE4US",@"jp.co.capcom.RE7US",@"jp.co.capcom.VillageUS"]) {
        testBundleIdentifier=identifier;MHTCheckOverlayHost();
    }
    method_setImplementation(method,originalBundleIdentifier);testBundleIdentifier=nil;
#else
    MHTCheckOverlayHost();
#endif
}
#ifndef MHT_OVERLAY_WINDOW_CHECKS_ONLY
int main(void) {@autoreleasepool { MHTCheckRuntimeWindows(); } return 0;}
#endif
