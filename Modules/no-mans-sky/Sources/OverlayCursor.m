// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayCursor.h"
#import "MHTOverlayHost.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
@implementation MHTNMSCursorView
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])){
        self.hidden=YES;
        self.wantsLayer=YES;
        self.layer.actions=@{@"position":NSNull.null,@"bounds":NSNull.null,@"contents":NSNull.null};
        self.accessibilityElement=NO;
    }return self;
}
- (NSView *)hitTest:(NSPoint)point {(void)point;return nil;}
- (BOOL)isFlipped {return YES;}
- (BOOL)isOpaque {return NO;}
- (NSPoint)pointerHotspot {return NSMakePoint(2,2);}
- (NSSize)pointerSize {return NSMakeSize(20,27);}
- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    // Point geometry stays sharp on every backing scale. White outline and black
    // fill remain visible over both the game scene and translucent trainer glass.
    NSBezierPath *arrow=[NSBezierPath bezierPath];
    [arrow moveToPoint:NSMakePoint(2,2)];[arrow lineToPoint:NSMakePoint(2,21)];
    [arrow lineToPoint:NSMakePoint(7,16.5)];[arrow lineToPoint:NSMakePoint(11,25)];
    [arrow lineToPoint:NSMakePoint(14.5,23.3)];[arrow lineToPoint:NSMakePoint(10.5,15)];
    [arrow lineToPoint:NSMakePoint(17,15)];[arrow closePath];
    arrow.lineWidth=2;arrow.lineJoinStyle=NSLineJoinStyleRound;
    [NSColor.whiteColor setStroke];[arrow stroke];[NSColor.blackColor setFill];[arrow fill];
}
- (void)updateAtScreenPoint:(NSPoint)screen enabled:(BOOL)enabled {
    NSView *parent=self.superview;NSWindow *window=self.window;
    if(!enabled || !window.isVisible || !parent){self.hidden=YES;return;}
    NSPoint point=[parent convertPoint:[window convertPointFromScreen:screen] fromView:nil];
    if(!NSPointInRect(point,parent.bounds)){self.hidden=YES;return;}
    NSPoint hot=self.pointerHotspot;NSSize size=self.pointerSize;
    NSRect frame=NSMakeRect(point.x-hot.x,point.y-(size.height-hot.y),size.width,size.height);
    // The panel's content view has AppKit's normal bottom-left coordinate system.
    NSPoint backing=[parent convertPointToBacking:frame.origin];
    backing.x=round(backing.x);backing.y=round(backing.y);
    frame.origin=[parent convertPointFromBacking:backing];
    [CATransaction begin];[CATransaction setDisableActions:YES];
    if(!NSEqualRects(self.frame,frame))self.frame=frame;
    self.hidden=NO;[CATransaction commit];
}
@end
@interface MHTNMSCursorController : NSObject
@property(nonatomic,weak) MHTOverlayHost *host;
@property(nonatomic) MHTNMSCursorView *view;
@property(nonatomic) NSTimer *timer;
- (void)setEnabled:(BOOL)enabled;
@end
@implementation MHTNMSCursorController
- (void)setEnabled:(BOOL)enabled {
    if(!enabled){[_timer invalidate];_timer=nil;_view.hidden=YES;return;}
    if(!_view){
        _view=[[MHTNMSCursorView alloc]initWithFrame:NSZeroRect];
        [_host.panel.contentView addSubview:_view positioned:NSWindowAbove relativeTo:nil];
    }
    [_view updateAtScreenPoint:NSEvent.mouseLocation enabled:YES];
    if(!_timer){
        __weak MHTNMSCursorController *weakSelf=self;
        _timer=[NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer *timer){
            MHTNMSCursorController *owner=weakSelf;
            if(!owner || !owner.host.overlay.window){[timer invalidate];return;}
            [owner.view updateAtScreenPoint:NSEvent.mouseLocation enabled:NSApp.isActive && owner.host.mouseInteractionEnabled];
        }];
        [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
    }
}
- (void)dealloc {[_timer invalidate];}
@end
void MHTNMSUpdateCursor(MHTOverlayHost *host,BOOL enabled){
    NSCAssert(NSThread.isMainThread,@"Overlay cursor belongs to AppKit's main thread");
    static char key;
    MHTNMSCursorController *controller=objc_getAssociatedObject(host,&key);
    if(!controller && enabled){controller=[MHTNMSCursorController new];controller.host=host;objc_setAssociatedObject(host,&key,controller,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
    [controller setEnabled:enabled];
}
