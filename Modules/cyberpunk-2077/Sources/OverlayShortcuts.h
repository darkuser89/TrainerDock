// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, MTOverlayShortcut) { MTShortcutPanel, MTShortcutMouse, MTShortcutCount };
NSInteger MTShortcutForEvent(NSEvent *event);

// Deduplicate native delivery and the delayed AppKit fallback by event time.
@interface MTOverlayShortcuts : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) void (^handler)(MTOverlayShortcut);
- (void)setRegistered:(BOOL)registered shortcut:(MTOverlayShortcut)shortcut;
- (BOOL)ownsLocalEvent:(NSEvent *)event;
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed;
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed timestamp:(NSTimeInterval)timestamp;
@end
