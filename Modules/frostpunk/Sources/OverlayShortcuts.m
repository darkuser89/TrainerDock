// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayShortcuts.h"
unsigned short MTShortcutPhysicalKeyAt(NSUInteger index) {return index==0 ? 10 : 50;}
static NSInteger keyIndex(unsigned short key) {return key==10 ? 0 : key==50 ? 1 : -1;}

NSInteger MTShortcutForEvent(NSEvent *event) {
    if (event.type!=NSEventTypeKeyDown) return -1;
    NSEventModifierFlags flags=event.modifierFlags;
    // Only Command+caret opens the overlay and requests its mouse automatically.
    // The German ISO caret is a dead key, so characters are unreliable.
    if (!(flags&NSEventModifierFlagCommand)
        || (flags&(NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift))
        || keyIndex(event.keyCode)<0) return -1;
    return MTShortcutPanel;
}
@implementation MTOverlayShortcuts {
    BOOL _registered[MTShortcutCount][MTShortcutPhysicalKeyCount], _held[MTShortcutCount];
}
- (void)setEnabled:(BOOL)enabled {
    _enabled=enabled;
    if (!enabled) memset(_held,0,sizeof(_held));
}
- (void)setRegistered:(BOOL)registered shortcut:(MTOverlayShortcut)shortcut {
    if (shortcut<0 || shortcut>=MTShortcutCount) return;
    for(NSUInteger i=0;i<MTShortcutPhysicalKeyCount;i++)_registered[shortcut][i]=registered;
    if (!registered) _held[shortcut]=NO;
}
- (void)setRegistered:(BOOL)registered keyCode:(unsigned short)key shortcut:(MTOverlayShortcut)shortcut {
    NSInteger index=keyIndex(key);
    if(shortcut<0 || shortcut>=MTShortcutCount || index<0)return;
    _registered[shortcut][index]=registered;
    if(!_registered[shortcut][0] && !_registered[shortcut][1])_held[shortcut]=NO;
}
- (BOOL)ownsLocalEvent:(NSEvent *)event {
    NSInteger shortcut=MTShortcutForEvent(event);
    NSInteger index=keyIndex(event.keyCode);
    return _enabled && shortcut>=0 && index>=0 && !(event.modifierFlags&NSEventModifierFlagShift)
        && _registered[shortcut][index];
}
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed {
    if (shortcut<0 || shortcut>=MTShortcutCount || !_enabled || (!_registered[shortcut][0] && !_registered[shortcut][1])) return NO;
    if (!pressed) { _held[shortcut]=NO; return YES; }
    if (_held[shortcut]) return YES;
    _held[shortcut]=YES;
    if (self.handler) self.handler(shortcut);
    return YES;
}
@end
