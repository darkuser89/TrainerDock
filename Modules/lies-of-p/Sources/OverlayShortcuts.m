// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayShortcuts.h"
#import <Carbon/Carbon.h>
#include <limits.h>

static NSArray *systemShortcuts;
static NSMutableSet<NSString *> *blockedShortcuts;
static BOOL systemShortcutsLoaded;
static const NSEventModifierFlags relevantModifiers=NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagShift|NSEventModifierFlagOption;
static UInt32 carbonModifiers(NSEventModifierFlags flags) {
    return ((flags&NSEventModifierFlagCommand)?cmdKey:0)|((flags&NSEventModifierFlagControl)?controlKey:0)|
        ((flags&NSEventModifierFlagShift)?shiftKey:0)|((flags&NSEventModifierFlagOption)?optionKey:0);
}
static NSString *shortcutIdentity(unsigned short key,NSEventModifierFlags flags) {
    return [NSString stringWithFormat:@"%u/%u",key,(unsigned)carbonModifiers(flags)];
}
BOOL MTSystemShortcutMatches(NSArray *entries,unsigned short key,NSEventModifierFlags modifiers) {
    if(!entries)return YES; // An unreadable system configuration never grants a shortcut.
    UInt32 wanted=carbonModifiers(modifiers),mask=cmdKey|controlKey|shiftKey|optionKey;
    for(NSDictionary *entry in entries){
        if(![entry isKindOfClass:NSDictionary.class] || ![entry[(__bridge NSString *)kHISymbolicHotKeyEnabled] boolValue])continue;
        NSNumber *code=entry[(__bridge NSString *)kHISymbolicHotKeyCode],*flags=entry[(__bridge NSString *)kHISymbolicHotKeyModifiers];
        if([code isKindOfClass:NSNumber.class] && [flags isKindOfClass:NSNumber.class] && code.unsignedIntegerValue==key && (flags.unsignedIntValue&mask)==wanted)return YES;
    }return NO;
}
BOOL MTRefreshSystemShortcuts(void) {
    CFArrayRef entries=NULL;
    OSStatus result=CopySymbolicHotKeys(&entries);
    systemShortcuts=result==noErr && entries ? [(__bridge NSArray *)entries copy] : nil;
    if(entries)CFRelease(entries);
    systemShortcutsLoaded=YES;blockedShortcuts=[NSMutableSet new];
    return systemShortcuts!=nil;
}
BOOL MTTrainerShortcutAvailable(unsigned short key,NSEventModifierFlags modifiers) {
    NSEventModifierFlags flags=modifiers&relevantModifiers;
    if(flags!=MTTrainerModifiers && flags!=NSEventModifierFlagCommand)return NO;
    if(!systemShortcutsLoaded)MTRefreshSystemShortcuts();
    return !MTSystemShortcutMatches(systemShortcuts,key,modifiers) && ![blockedShortcuts containsObject:shortcutIdentity(key,modifiers)];
}
void MTBlockTrainerShortcut(unsigned short key,NSEventModifierFlags modifiers) {
    if(!blockedShortcuts)blockedShortcuts=[NSMutableSet new];
    [blockedShortcuts addObject:shortcutIdentity(key,modifiers)];
}
unsigned short MTShortcutKeyCode(MTOverlayShortcut shortcut) {
    static const unsigned short keys[MTShortcutCount]={10,51}; // German caret, Backspace.
    return shortcut>=0 && shortcut<MTShortcutCount ? keys[shortcut] : USHRT_MAX;
}
NSEventModifierFlags MTShortcutModifiersFor(MTOverlayShortcut shortcut) {
    return shortcut==MTShortcutPanel ? NSEventModifierFlagCommand : MTTrainerModifiers;
}

NSInteger MTShortcutForEvent(NSEvent *event) {
    if (event.type!=NSEventTypeKeyDown) return -1;
    if(!MTTrainerShortcutAvailable(event.keyCode,event.modifierFlags))return -1;
    NSEventModifierFlags flags=event.modifierFlags&relevantModifiers;
    // Keep the explicitly requested Command-caret binding. No Shift+6 alias:
    // Command-Shift-6 can already belong to macOS screen capture.
    if(flags==NSEventModifierFlagCommand && (event.keyCode==10 || [event.charactersIgnoringModifiers isEqual:@"^"]))return MTShortcutPanel;
    for(NSInteger i=MTShortcutStop;i<MTShortcutCount;i++)if(flags==MTShortcutModifiersFor(i) && event.keyCode==MTShortcutKeyCode(i))return i;
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
    return _enabled && shortcut>=0 && _registered[shortcut] && event.keyCode==MTShortcutKeyCode(shortcut);
}
- (BOOL)nativeShortcut:(MTOverlayShortcut)shortcut pressed:(BOOL)pressed {
    if (shortcut<0 || shortcut>=MTShortcutCount || !_enabled || !_registered[shortcut]) return NO;
    if(!MTTrainerShortcutAvailable(MTShortcutKeyCode(shortcut),MTShortcutModifiersFor(shortcut)))return NO;
    if (!pressed) { _held[shortcut]=NO; return YES; }
    if (_held[shortcut]) return YES;
    _held[shortcut]=YES;
    if (self.handler) self.handler(shortcut);
    return YES;
}
@end
