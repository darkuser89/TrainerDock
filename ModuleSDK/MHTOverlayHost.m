// SPDX-License-Identifier: GPL-3.0-only
#import "MHTOverlayHost.h"
static BOOL primaryMouseEvent(NSEvent *event){return event.type==NSEventTypeLeftMouseDown || event.type==NSEventTypeLeftMouseDragged || event.type==NSEventTypeLeftMouseUp;}
@interface MHTOverlayPanel : NSPanel
@property(nonatomic,copy) BOOL (^mouseHandler)(NSEvent *event);
@end
@implementation MHTOverlayPanel
- (BOOL)canBecomeKeyWindow{return NO;}
- (BOOL)canBecomeMainWindow{return NO;}
- (void)sendEvent:(NSEvent *)event {
    if(!self.ignoresMouseEvents && primaryMouseEvent(event)){
        if(self.mouseHandler)self.mouseHandler(event);
        return;
    }
    [super sendEvent:event];
}
@end
@implementation MHTOverlayHost {
    id _mouseMonitor;
}
- (instancetype)initWithGameWindow:(NSWindow *)window overlay:(NSView *)overlay {
    NSAssert(NSThread.isMainThread,@"Overlay windows belong to the main thread");
    if((self=[super init])){
        _gameWindow=window;_overlay=overlay;
        _panel=[[MHTOverlayPanel alloc]initWithContentRect:NSZeroRect
            styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel
            backing:NSBackingStoreBuffered defer:NO];
        _panel.releasedWhenClosed=NO;_panel.opaque=NO;_panel.backgroundColor=NSColor.clearColor;
        _panel.hasShadow=NO;_panel.ignoresMouseEvents=YES;_panel.hidesOnDeactivate=YES;
        _panel.acceptsMouseMovedEvents=YES;
        _panel.collectionBehavior=NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorIgnoresCycle;
        // Use a distinct content tree. Never add a glass view or constraint to the game.
        NSView *content=[[NSView alloc]initWithFrame:NSZeroRect];_panel.contentView=content;
        overlay.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
        [content addSubview:overlay];
        [_gameWindow addChildWindow:_panel ordered:NSWindowAbove];
        [self synchronize];
    }return self;
}
- (void)setMouseHandler:(BOOL (^)(NSEvent *))handler {
    _mouseHandler=[handler copy];((MHTOverlayPanel *)self.panel).mouseHandler=_mouseHandler;
}
- (void)setMouseInteractionEnabled:(BOOL)enabled {
    NSAssert(NSThread.isMainThread,@"Overlay input belongs to the main thread");
    if(_mouseInteractionEnabled==enabled)return;
    _mouseInteractionEnabled=enabled;self.panel.ignoresMouseEvents=!enabled;
    if(_mouseMonitor){[NSEvent removeMonitor:_mouseMonitor];_mouseMonitor=nil;}
    if(enabled){
        // Register on opening, after Unreal's startup monitors. Panel clicks must
        // reach the trainer before the engine consumes its own mouse events.
        __weak MHTOverlayHost *weakSelf=self;
        _mouseMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp handler:^NSEvent *(NSEvent *event){
            MHTOverlayHost *owner=weakSelf;
            if(!owner || !owner.mouseInteractionEnabled || event.window!=owner.panel)return event;
            if(owner.mouseHandler)owner.mouseHandler(event);
            return nil;
        }];
    }
}
- (void)synchronize {
    NSAssert(NSThread.isMainThread,@"Overlay geometry belongs to the main thread");
    NSView *content=self.gameWindow.contentView;
    if(!content || !self.gameWindow.isVisible || self.gameWindow.isMiniaturized){[self.panel orderOut:nil];return;}
    NSRect inWindow=[content convertRect:content.bounds toView:nil];
    NSRect screen=[self.gameWindow convertRectToScreen:inWindow];
    if(!NSEqualRects(self.panel.frame,screen))[self.panel setFrame:screen display:NO];
    if(!NSEqualRects(self.overlay.frame,self.panel.contentView.bounds))self.overlay.frame=self.panel.contentView.bounds;
    if(NSApp.isActive && !self.panel.isVisible)[self.panel orderFront:nil];
}
- (void)close {
    NSAssert(NSThread.isMainThread,@"Overlay teardown belongs to the main thread");
    self.mouseInteractionEnabled=NO;self.mouseHandler=nil;
    [self.gameWindow removeChildWindow:self.panel];[self.panel orderOut:nil];
    [self.overlay removeFromSuperview];[self.panel close];
}
@end
NSEvent *MHTOverlayMouseEvent(NSEvent *event,NSWindow *overlayWindow) {
    if(!event || !overlayWindow)return nil;
    if(event.window==overlayWindow)return event;
    if(event.window!=overlayWindow.parentWindow || !event.window)return nil;
    if(event.type!=NSEventTypeLeftMouseDown && event.type!=NSEventTypeLeftMouseDragged && event.type!=NSEventTypeLeftMouseUp)return nil;
    NSPoint screen=[event.window convertPointToScreen:event.locationInWindow];
    NSPoint point=[overlayWindow convertPointFromScreen:screen];
    return [NSEvent mouseEventWithType:event.type location:point modifierFlags:event.modifierFlags timestamp:event.timestamp
        windowNumber:overlayWindow.windowNumber context:nil eventNumber:event.eventNumber clickCount:event.clickCount pressure:event.pressure];
}
