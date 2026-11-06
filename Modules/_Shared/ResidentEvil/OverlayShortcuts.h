// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, RE2OverlayShortcut) { RE2ShortcutPanel, RE2ShortcutCount };
NSInteger RE2ShortcutForEvent(NSEvent *event);

// Shared ownership between the AppKit fallback and macOS hotkey delivery.
// A registered physical shortcut belongs exclusively to the native path.
@interface RE2OverlayShortcuts : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) void (^handler)(RE2OverlayShortcut);
- (void)setRegistered:(BOOL)registered shortcut:(RE2OverlayShortcut)shortcut;
- (BOOL)ownsLocalEvent:(NSEvent *)event;
- (BOOL)nativeShortcut:(RE2OverlayShortcut)shortcut pressed:(BOOL)pressed;
@end
