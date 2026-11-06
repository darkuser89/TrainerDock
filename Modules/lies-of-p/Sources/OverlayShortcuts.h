// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>

enum { MTTrainerModifiers = NSEventModifierFlagControl | NSEventModifierFlagShift };
typedef NS_ENUM(NSInteger, MTOverlayShortcut) { MTShortcutPanel, MTShortcutStop, MTShortcutCount };
NSInteger MTShortcutForEvent(NSEvent *event);
unsigned short MTShortcutKeyCode(MTOverlayShortcut shortcut);
NSEventModifierFlags MTShortcutModifiersFor(MTOverlayShortcut shortcut);
BOOL MTRefreshSystemShortcuts(void);
BOOL MTTrainerShortcutAvailable(unsigned short key, NSEventModifierFlags modifiers);
void MTBlockTrainerShortcut(unsigned short key, NSEventModifierFlags modifiers);
BOOL MTSystemShortcutMatches(NSArray *entries, unsigned short key, NSEventModifierFlags modifiers);

// Shared ownership between the AppKit fallback and macOS hotkey delivery.
// A registered physical shortcut belongs exclusively to the native path.
@interface MTOverlayShortcuts : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) void (^handler)(MTOverlayShortcut);
- (void)setRegistered:(BOOL)registered shortcut:(MTOverlayShortcut)shortcut;
- (BOOL)ownsLocalEvent:(NSEvent *)event;
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed;
@end
