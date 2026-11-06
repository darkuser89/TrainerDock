// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayShortcuts.h"

NSInteger RE2ShortcutForEvent(NSEvent *event) {
    if (event.type!=NSEventTypeKeyDown) return -1;
    NSEventModifierFlags flags=event.modifierFlags;
    // Only the user's chosen Command+caret key; no Option/Shift variants.
    // The ISO German caret is a dead key, so characters are unreliable.
    if (!(flags&NSEventModifierFlagCommand)
        || (flags&(NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift))
        || event.keyCode!=10) return -1;
    return RE2ShortcutPanel;
}
@implementation RE2OverlayShortcuts {
    BOOL _registered[RE2ShortcutCount], _held[RE2ShortcutCount];
}
- (void)setEnabled:(BOOL)enabled {
    _enabled=enabled;
    if (!enabled) memset(_held,0,sizeof(_held));
}
- (void)setRegistered:(BOOL)registered shortcut:(RE2OverlayShortcut)shortcut {
    if (shortcut<0 || shortcut>=RE2ShortcutCount) return;
    _registered[shortcut]=registered;
    if (!registered) _held[shortcut]=NO;
}
- (BOOL)ownsLocalEvent:(NSEvent *)event {
    NSInteger shortcut=RE2ShortcutForEvent(event);
    return _enabled && shortcut>=0 && event.keyCode==10 && !(event.modifierFlags&NSEventModifierFlagShift)
        && _registered[shortcut];
}
- (BOOL)nativeShortcut:(RE2OverlayShortcut)shortcut pressed:(BOOL)pressed {
    if (shortcut<0 || shortcut>=RE2ShortcutCount || !_enabled || !_registered[shortcut]) return NO;
    if (!pressed) { _held[shortcut]=NO; return YES; }
    if (_held[shortcut]) return YES;
    _held[shortcut]=YES;
    if (self.handler) self.handler(shortcut);
    return YES;
}
@end
