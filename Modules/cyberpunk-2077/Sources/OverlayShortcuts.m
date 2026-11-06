// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayShortcuts.h"

NSInteger MTShortcutForEvent(NSEvent *event) {
    if (event.type!=NSEventTypeKeyDown) return -1;
    NSEventModifierFlags flags=event.modifierFlags;
    if (!(flags&NSEventModifierFlagCommand) || (flags&NSEventModifierFlagControl)) return -1;
    // ISO German caret is a dead key: its characters can be empty or composed.
    // Character matching additionally supports e.g. Shift+6 on an ANSI layout.
    if (!((event.keyCode==10 && !(flags&NSEventModifierFlagShift)) || [event.charactersIgnoringModifiers isEqualToString:@"^"])) return -1;
    return flags&NSEventModifierFlagOption ? MTShortcutMouse : MTShortcutPanel;
}
@implementation MTOverlayShortcuts {
    BOOL _registered[MTShortcutCount], _held[MTShortcutCount];
    NSTimeInterval _handledTimestamp[MTShortcutCount];
    NSUInteger _generation;
}
- (void)setEnabled:(BOOL)enabled {
    _enabled=enabled;
    _generation++;
    if (!enabled) memset(_held,0,sizeof(_held));
}
- (void)setRegistered:(BOOL)registered shortcut:(MTOverlayShortcut)shortcut {
    if (shortcut<0 || shortcut>=MTShortcutCount) return;
    _registered[shortcut]=registered;
    _generation++;
    if (!registered) _held[shortcut]=NO;
}
- (BOOL)ownsLocalEvent:(NSEvent *)event {
    NSInteger shortcut=MTShortcutForEvent(event);
    BOOL owned=_enabled && shortcut>=0 && event.keyCode==10 && !(event.modifierFlags&NSEventModifierFlagShift)
        && _registered[shortcut];
    if(owned && !event.isARepeat){
        // Some engines/targeted accessibility key events expose the AppKit
        // event without delivering the Carbon registration. Wait briefly for
        // native delivery, then use the same timestamp-deduplicated path.
        NSUInteger generation=_generation;NSTimeInterval timestamp=event.timestamp;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,50*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
            if(self->_enabled && self->_generation==generation && self->_registered[shortcut])
                [self deliver:shortcut timestamp:timestamp];
        });
    }
    return owned;
}
- (void)deliver:(MTOverlayShortcut)shortcut timestamp:(NSTimeInterval)timestamp {
    if(timestamp>0 && _handledTimestamp[shortcut]>0 && fabs(timestamp-_handledTimestamp[shortcut])<0.005)return;
    _handledTimestamp[shortcut]=timestamp;
    if(self.handler)self.handler(shortcut);
}
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed {return [self nativeShortcut:shortcut pressed:pressed timestamp:0];}
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed timestamp:(NSTimeInterval)timestamp {
    if (shortcut<0 || shortcut>=MTShortcutCount || !_enabled || !_registered[shortcut]) return NO;
    if (!pressed) { _held[shortcut]=NO; return YES; }
    if (_held[shortcut]) return YES;
    _held[shortcut]=YES;
    [self deliver:shortcut timestamp:timestamp];
    return YES;
}
@end
