// SPDX-License-Identifier: GPL-3.0-only
// Reproduce Unreal's off-main-thread isZoomed query without starting a game.
#import "Overlay.h"
#import "MHTOverlayHost.h"
#include <math.h>
static void check(BOOL value,const char *message){if(!value){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(void){@autoreleasepool {
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    NSWindow *game=[[NSWindow alloc]initWithContentRect:NSMakeRect(200,200,800,600) styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    game.releasedWhenClosed=NO;NSView *original=game.contentView;
    NSArray *before=original.subviews.copy;NSArray *constraints=original.constraints.copy;
    [game orderFront:nil];
    DI2OverlayRoot *root=[[DI2OverlayRoot alloc]initWithFrame:original.bounds version:@"Synthetic host"];
    [root applyOverlayOptions:@{@"liquidGlass":@YES,@"visible":@YES}];
    MHTOverlayHost *host=[[MHTOverlayHost alloc]initWithGameWindow:game overlay:root];
    [host.panel.contentView layoutSubtreeIfNeeded];
    check(root.window==host.panel && host.panel.parentWindow==game,"overlay must own a separate child window");
    check(game.contentView==original && [original.subviews isEqual:before] && [original.constraints isEqual:constraints],"game content tree must remain untouched");
    check(!host.panel.canBecomeKeyWindow && host.panel.ignoresMouseEvents,"game retains focus and receives original mouse events");
    __block NSException *failure=nil;dispatch_group_t group=dispatch_group_create();
    dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        @try{(void)game.isZoomed;}@catch(NSException *exception){failure=exception;}
    });
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
    while(dispatch_group_wait(group,DISPATCH_TIME_NOW)!=0 && deadline.timeIntervalSinceNow>0)
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    check(dispatch_group_wait(group,DISPATCH_TIME_NOW)==0,"engine window query must complete");
    if(failure)fprintf(stderr,"Unexpected exception: %s\n",failure.reason.UTF8String);
    check(!failure,"native glass must not activate the game window's main-thread layout engine");
    NSEvent *click=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:NSMakePoint(40,60) modifierFlags:0 timestamp:1 windowNumber:game.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
    NSEvent *mapped=MHTOverlayMouseEvent(click,host.panel);
    check(mapped && mapped.window==host.panel,"mouse event must be mapped into the overlay window");
    NSPoint expected=[game convertPointToScreen:click.locationInWindow],actual=[host.panel convertPointToScreen:mapped.locationInWindow];
    check(fabs(expected.x-actual.x)<0.5 && fabs(expected.y-actual.y)<0.5,"screen-space mouse position must be preserved");
    // Test actual row activation via the panel's delivery path, not just coordinate conversion.
    DI2TrainerState *state=[DI2TrainerState new];state.ready=YES;
    for(DI2FeatureState *feature in state.features)feature.available=YES;
    [root updateState:state];
    __block NSUInteger calls=0;__block DI2Feature selected=DI2FeatureCount;
    root.featureHandler=^(DI2Feature feature){calls++;selected=feature;};
    host.mouseHandler=^BOOL(NSEvent *event){return [root handleMouseEvent:event];};
    host.mouseInteractionEnabled=YES;
    check(!host.panel.ignoresMouseEvents && !host.panel.canBecomeKeyWindow,"interactive panel receives clicks without taking keyboard focus");
    NSView *firstRow=nil;
    for(NSView *view in root.panelContent.subviews)if([view.accessibilityRole isEqual:NSAccessibilityCheckBoxRole]){firstRow=view;break;}
    check(firstRow!=nil,"native feature row exists");
    NSPoint rowPoint=[firstRow convertPoint:NSMakePoint(80,10) toView:nil];
    NSEvent *rowClick=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:rowPoint modifierFlags:0 timestamp:2 windowNumber:host.panel.windowNumber context:nil eventNumber:2 clickCount:1 pressure:1];
    [host.panel sendEvent:rowClick];
    check(calls==1 && selected==DI2FeatureGod,"panel click activates the selected native trainer row exactly once");
    NSEvent *rowRelease=[NSEvent mouseEventWithType:NSEventTypeLeftMouseUp location:rowPoint modifierFlags:0 timestamp:3 windowNumber:host.panel.windowNumber context:nil eventNumber:3 clickCount:1 pressure:0];
    [host.panel sendEvent:rowRelease];
    [NSApp sendEvent:rowClick];[NSApp sendEvent:rowRelease];
    check(calls==2,"application monitor and panel fallback never duplicate a click");
    __block double adjusted=0;__block DI2Feature adjustedFeature=DI2FeatureCount;
    root.valueHandler=^(DI2Feature feature,double value){adjustedFeature=feature;adjusted=value;};
    NSView *numericRow=nil;
    for(NSView *view in root.panelContent.subviews)
        if([view.accessibilityRole isEqual:NSAccessibilityCheckBoxRole] && [[view valueForKey:@"feature"] integerValue]==DI2FeaturePlayerSpeed){numericRow=view;break;}
    check(numericRow!=nil,"numeric trainer row exists");
    NSPoint plus=[numericRow convertPoint:NSMakePoint(numericRow.bounds.size.width-36,10) toView:nil];
    NSEvent *plusClick=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:plus modifierFlags:0 timestamp:4 windowNumber:host.panel.windowNumber context:nil eventNumber:4 clickCount:1 pressure:1];
    [host.panel sendEvent:plusClick];
    check(adjustedFeature==DI2FeaturePlayerSpeed && fabs(adjusted-2.25)<0.001,"mouse plus control changes the correct numeric value");
    NSPoint header=[root.panelContent convertPoint:NSMakePoint(40,12) toView:nil];
    double oldX=[root.overlayOptions[@"x"] doubleValue];
    for(NSUInteger i=0;i<3;i++){
        NSEventType type=i==0 ? NSEventTypeLeftMouseDown : i==1 ? NSEventTypeLeftMouseDragged : NSEventTypeLeftMouseUp;
        NSPoint location=NSMakePoint(header.x+(i ? 20 : 0),header.y);
        NSEvent *drag=[NSEvent mouseEventWithType:type location:location modifierFlags:0 timestamp:5+i windowNumber:host.panel.windowNumber context:nil eventNumber:5+i clickCount:1 pressure:i==2 ? 0 : 1];
        [host.panel sendEvent:drag];
    }
    check([root.overlayOptions[@"position"] isEqual:@"free"] && [root.overlayOptions[@"x"] doubleValue]>oldX,"mouse drag moves the trainer header");
    host.mouseInteractionEnabled=NO;
    check(host.panel.ignoresMouseEvents,"closing trainer input restores click-through to the game");
    [game setFrame:NSMakeRect(250,220,960,640) display:NO];[host synchronize];
    check(NSEqualSizes(root.bounds.size,game.contentView.bounds.size),"overlay follows manual engine window resizing");
    [root applyOverlayOptions:@{@"liquidGlass":@NO,@"visible":@NO}];
    check([original.subviews isEqual:before] && [original.constraints isEqual:constraints],"glass changes must stay isolated");
    [host close];check(!host.panel.parentWindow && !root.superview,"child window teardown detaches cleanly");
    [game orderOut:nil];[game close];
    puts("PASS: isolated layout, off-thread query, real row clicks, numeric mouse control, header drag, no duplicate activation, input release and resize/teardown. No game started.");
}return 0;}
