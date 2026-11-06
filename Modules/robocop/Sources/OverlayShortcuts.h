// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, MTOverlayShortcut) { MTShortcutPanel, MTShortcutCount };
NSInteger MTShortcutForEvent(NSEvent *event);

// Shared ownership between the AppKit fallback and macOS hotkey delivery.
// A registered physical shortcut belongs exclusively to the native path.
@interface MTOverlayShortcuts : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) void (^handler)(MTOverlayShortcut);
- (void)setRegistered:(BOOL)registered shortcut:(MTOverlayShortcut)shortcut;
- (BOOL)ownsLocalEvent:(NSEvent *)event;
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed;
@end

// Carbon and AppKit may report the same physical key. Synthetic/local-only
// events must still dispatch when no Carbon delivery occurred.
@interface MTShortcutDeliveryGate : NSObject
- (BOOL)acceptCommand:(NSInteger)command native:(BOOL)native time:(NSTimeInterval)time;
@end
