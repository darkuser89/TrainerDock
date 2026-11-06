// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
// A game may resize its own frame-based NSWindow from its GameThread. Native
// glass owns constraints, so keep it in a separate, main-thread-only window.
@interface MHTOverlayHost : NSObject
@property(nonatomic,readonly) NSWindow *gameWindow;
@property(nonatomic,readonly) NSView *overlay;
@property(nonatomic,readonly) NSPanel *panel;
@property(nonatomic) BOOL mouseInteractionEnabled;
@property(nonatomic,copy) BOOL (^mouseHandler)(NSEvent *event);
- (instancetype)initWithGameWindow:(NSWindow *)window overlay:(NSView *)overlay;
- (void)synchronize;
- (void)close;
@end
NSEvent *MHTOverlayMouseEvent(NSEvent *event,NSWindow *overlayWindow);
