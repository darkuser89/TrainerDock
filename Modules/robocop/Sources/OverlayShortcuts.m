// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayShortcuts.h"

NSInteger MTShortcutForEvent(NSEvent *event) {
    if (event.type!=NSEventTypeKeyDown) return -1;
    NSEventModifierFlags flags=event.modifierFlags;
    // ISO caret is a dead key. On ANSI layouts caret can require Shift+6.
    // Both routes open the same panel and request the same native mouse lease.
    if (!(flags&NSEventModifierFlagCommand) || (flags&(NSEventModifierFlagControl|NSEventModifierFlagOption)))return -1;
    if(event.keyCode==10 && !(flags&NSEventModifierFlagShift))return MTShortcutPanel;
    if(event.keyCode==22 && (flags&NSEventModifierFlagShift))return MTShortcutPanel;
    if([event.characters isEqualToString:@"^"])return MTShortcutPanel;
    return -1;
}
@implementation MTOverlayShortcuts {
    BOOL _registered[MTShortcutCount], _held[MTShortcutCount];
}
- (void)setEnabled:(BOOL)enabled {
    _enabled=enabled;
    if (!enabled) memset(_held,0,sizeof(_held));
}
- (void)setRegistered:(BOOL)registered shortcut:(MTOverlayShortcut)shortcut {
    if (shortcut<0 || shortcut>=MTShortcutCount) return;
    _registered[shortcut]=registered;
    if (!registered) _held[shortcut]=NO;
}
- (BOOL)ownsLocalEvent:(NSEvent *)event {
    NSInteger shortcut=MTShortcutForEvent(event);
    return _enabled && shortcut>=0 && event.keyCode==10 && !(event.modifierFlags&NSEventModifierFlagShift)
        && _registered[shortcut];
}
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed {
    if (shortcut<0 || shortcut>=MTShortcutCount || !_enabled || !_registered[shortcut]) return NO;
    if (!pressed) { _held[shortcut]=NO; return YES; }
    if (_held[shortcut]) return YES;
    _held[shortcut]=YES;
    if (self.handler) self.handler(shortcut);
    return YES;
}
@end

@implementation MTShortcutDeliveryGate {
    NSTimeInterval _nativeTimes[32],_localTimes[32];
}
- (BOOL)acceptCommand:(NSInteger)command native:(BOOL)native time:(NSTimeInterval)time {
    if(command<0 || command>=32 || time<=0)return NO;
    NSTimeInterval opposite=native ? _localTimes[command] : _nativeTimes[command];
    if(opposite>0 && time>=opposite && time-opposite<0.15)return NO;
    if(native)_nativeTimes[command]=time;else _localTimes[command]=time;
    return YES;
}
@end
