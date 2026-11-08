// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "LiesOfPAdapter.h"
#import <sys/mman.h>
#import <unistd.h>
// Compile the actual runtime attachment code only into the native test process.
// The product Runtime.m object is excluded from that test by the build wrapper.
#import "../../Modules/lies-of-p/Sources/Runtime.m"
#import "TrainerMaterial.h"
static void LOPCheckOverlayHost(void){
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    runtimeLog=os_log_create("local.trainerdock.tests.liesofp","overlay");
    roots=[NSMutableArray new];overlayHosts=[NSMutableArray new];
    overlayOptions=MTNormalizeOverlayOptions(@{@"visible":@YES,@"glassIntensity":@0.5});
    NSWindow *game=[[NSWindow alloc]initWithContentRect:NSMakeRect(100,100,1200,900)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    game.releasedWhenClosed=NO;NSView *original=game.contentView;
    NSArray *views=original.subviews.copy,*constraints=original.constraints.copy;
    [game orderFront:nil];attachToGameWindow();observeWindowGeometry();
    NSCAssert(roots.count==1 && overlayHosts.count==1,@"Real runtime attaches once to the game fixture");
    MTOverlayRoot *root=roots.firstObject;MHTOverlayHost *host=overlayHosts.firstObject;
    NSCAssert(root.window==host.panel && host.panel.parentWindow==game,@"Native glass lives in an isolated child panel");
    NSCAssert(shortcutRoot(game,NO)==root,@"Game-window shortcuts resolve the child-panel overlay");
    NSCAssert(!host.panel.canBecomeKeyWindow && (host.panel.collectionBehavior&NSWindowCollectionBehaviorFullScreenAuxiliary),@"Fullscreen auxiliary panel leaves keyboard focus with the game");
    [host.panel.contentView layoutSubtreeIfNeeded];
    __block NSException *failure=nil;dispatch_group_t group=dispatch_group_create();
    dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        @try {for(NSUInteger i=0;i<120;i++){(void)game.isZoomed;usleep(1000);}}
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
    MTTrainerState *state=[MTTrainerState new];state.ready=YES;
    for(MTFeatureState *feature in state.features)feature.available=YES;
    [root updateState:state];[root layout];
    __block NSUInteger clicks=0;__block MTFeature selected=MTFeatureCount;
    root.featureHandler=^(MTFeature feature){clicks++;selected=feature;};
    NSView *row=nil;
    for(NSView *view in ((MTTrainerMaterial *)root.panel).contentView.subviews)
        if([view.accessibilityRole isEqual:NSAccessibilityCheckBoxRole]){row=view;break;}
    NSCAssert(row,@"Native feature row remains present");host.mouseInteractionEnabled=YES;
    NSPoint at=[row convertPoint:NSMakePoint(80,10) toView:nil];
    for(NSUInteger i=0;i<2;i++){
        NSEvent *event=[NSEvent mouseEventWithType:i?NSEventTypeLeftMouseUp:NSEventTypeLeftMouseDown location:at modifierFlags:0 timestamp:1+i windowNumber:host.panel.windowNumber context:nil eventNumber:i clickCount:1 pressure:i?0:1];
        [host.panel sendEvent:event];
    }
    NSCAssert(clicks==1 && selected==MTFeatureHealth,@"Child-panel click reaches the correct real feature exactly once");
    NSPoint screen=[host.panel convertPointToScreen:at],fromGame=[game convertPointFromScreen:screen];
    NSEvent *originalClick=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:fromGame modifierFlags:0 timestamp:3 windowNumber:game.windowNumber context:nil eventNumber:3 clickCount:1 pressure:1];
    NSCAssert([root handleMouseEvent:originalClick] && clicks==2,@"Game-window mouse coordinates map correctly after resizing");
    host.mouseInteractionEnabled=NO;NSCAssert(host.panel.ignoresMouseEvents,@"Closing interaction restores click-through");
    for(id observer in windowObservers)[NSNotificationCenter.defaultCenter removeObserver:observer];windowObservers=nil;
    [host close];[overlayHosts removeAllObjects];[roots removeAllObjects];
    NSCAssert(!host.panel.parentWindow && !root.superview,@"Overlay detaches cleanly");
    [game orderOut:nil];[game close];
    puts("PASS: actual Lies-of-P runtime attachment, isolated glass, 120 worker window queries, 24 resize/fullscreen notifications, no duplicate roots, mouse mapping and teardown. No game started.");
}

// Invoke the real data-lease implementation on this test's own anonymous page.
// No executable game or original binding is present in this process.
@interface LOPGameAdapter (LeaseContract)
- (BOOL)write:(NSString *)key owner:(uintptr_t)owner base:(uintptr_t)base stat:(uint8_t)stat offset:(size_t)offset bytes:(const void *)bytes length:(size_t)length;
@end
int main(void){@autoreleasepool{
 NSCAssert(MTFeatureCount==36&&MTFeatureHealth==0,@"No master option in native catalog");
 LOPGameAdapter *adapter=[LOPGameAdapter new];NSCAssert([adapter captureContext].kind==MTSessionUnsupported,@"Unrelated executable cannot access native game bindings");
 for(NSInteger i=0;i<MTFeatureCount;i++){
  const MTFeatureInfo *f=MTFeatureInfoAt(i);NSCAssert(![f->title containsString:@"Trainer aktivieren"],@"Removed action cannot be displayed");
  MTFeatureState *s=[adapter applyFeature:i wanted:YES value:f->initial];NSCAssert(!s.available&&!s.active,@"Removing the master preserves real process/context checks");
 }
 __block BOOL done=NO;[adapter onGameThread:^{done=YES;}];NSDate *until=[NSDate dateWithTimeIntervalSinceNow:1];while(!done&&until.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]];NSCAssert(done,@"Unsupported process completes without pretending to be the GameThread");
 [adapter releaseEffects];puts("Lies of P catalog/native context checks passed");
 size_t page=(size_t)sysconf(_SC_PAGESIZE);void *fixture=mmap(NULL,page,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
 NSCAssert(fixture!=MAP_FAILED,@"Anonymous test page");
 float before=5,target=10;memcpy(fixture,&before,4);
 NSCAssert([adapter write:@"fixture/lease" owner:0 base:(uintptr_t)fixture stat:0 offset:0 bytes:&target length:4],@"First lease writes and reads back");
 NSCAssert(mprotect(fixture,page,PROT_READ)==0,@"Only the synthetic page becomes read-only");
 for(int i=0;i<1000;i++)NSCAssert([adapter write:@"fixture/lease" owner:0 base:(uintptr_t)fixture stat:0 offset:0 bytes:&target length:4],@"Unchanged leases only read back; they never require another write");
 NSCAssert(mprotect(fixture,page,PROT_READ|PROT_WRITE)==0,@"Restore synthetic page permissions");
 float foreign=11;memcpy(fixture,&foreign,4);
 NSCAssert(![adapter write:@"fixture/lease" owner:0 base:(uintptr_t)fixture stat:0 offset:0 bytes:&target length:4] && *(float *)fixture==foreign,@"Foreign changes remain rejected and preserved");
 munmap(fixture,page);puts("PASS: 1,000 stable native leases without writes; foreign edits preserved. Synthetic page only; no game started.");
 LOPCheckOverlayHost();
}return 0;}
