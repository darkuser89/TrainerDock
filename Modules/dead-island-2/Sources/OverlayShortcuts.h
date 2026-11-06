// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "TrainerFeatures.h"

typedef NS_ENUM(NSInteger, DI2Hotkey) {
    DI2HotkeyCash1000=DI2FeatureCount, DI2HotkeyCash10000, DI2HotkeyDisableAll,
    DI2HotkeyPanel, DI2HotkeyMouse, DI2HotkeyCount
};
@interface DI2HotkeyBinding : NSObject
@property(nonatomic, readonly) unsigned short keyCode;
@property(nonatomic, readonly) NSEventModifierFlags modifiers;
@property(nonatomic, readonly, copy) NSString *label, *originalLabel;
@property(nonatomic, readonly) BOOL available, remapped;
@end

// Read-only macOS snapshot, refreshed at activation; never queried per keystroke.
void DI2ReloadSystemHotkeys(void);
// Pure configuration boundary also used by deterministic tests. Dictionaries
// contain keyCode and AppKit modifier flags; only enabled OS bindings are passed.
void DI2ConfigureHotkeys(NSArray<NSDictionary *> *reserved);
DI2HotkeyBinding *DI2HotkeyAt(NSInteger index);
NSInteger DI2HotkeyForEvent(NSEvent *event);
void DI2BlockHotkey(NSInteger index);
NSString *DI2HotkeyConflictSummary(void);
NSString *DI2HotkeyReadableLabel(NSInteger index);
NSEventModifierFlags DI2HotkeyModifierMask(void);

typedef NS_ENUM(NSInteger, DI2OverlayShortcut) { DI2ShortcutPanel, DI2ShortcutMouse, DI2ShortcutCount };
NSInteger DI2ShortcutForEvent(NSEvent *event);

// Shared ownership between the AppKit fallback and macOS hotkey delivery.
// A registered physical shortcut belongs exclusively to the native path.
@interface DI2OverlayShortcuts : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) void (^handler)(DI2OverlayShortcut);
- (void)setRegistered:(BOOL)registered shortcut:(DI2OverlayShortcut)shortcut;
- (BOOL)ownsLocalEvent:(NSEvent *)event;
- (BOOL)nativeShortcut:(DI2OverlayShortcut)shortcut pressed:(BOOL)pressed;
@end
