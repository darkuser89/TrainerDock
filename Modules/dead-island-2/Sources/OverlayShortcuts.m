// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayShortcuts.h"
#import <Carbon/Carbon.h>

@interface DI2HotkeyBinding ()
@property(nonatomic) unsigned short keyCode;
@property(nonatomic) NSEventModifierFlags modifiers;
@property(nonatomic, copy) NSString *label, *originalLabel;
@property(nonatomic) BOOL available, remapped;
@end
@implementation DI2HotkeyBinding
@end
static NSArray<DI2HotkeyBinding *> *bindings;
static NSSet<NSString *> *systemBindings;
static BOOL snapshotUnavailable;
NSEventModifierFlags DI2HotkeyModifierMask(void) {
    return NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift|NSEventModifierFlagCommand;
}
static NSString *signature(unsigned short code,NSEventModifierFlags modifiers) {
    return [NSString stringWithFormat:@"%hu:%lu",code,(unsigned long)(modifiers&DI2HotkeyModifierMask())];
}
static NSString *keyName(unsigned short code) {
    const unsigned short codes[]={122,120,99,118,96,97,98,100,101,109,103,111};
    for(NSUInteger i=0;i<12;i++)if(code==codes[i])return [NSString stringWithFormat:@"F%lu",(unsigned long)i+1];
    const unsigned short digits[]={18,19,20,21,23,22,26,28,25,29};
    for(NSUInteger i=0;i<10;i++)if(code==digits[i])return [NSString stringWithFormat:@"%lu",(unsigned long)(i+1)%10];
    return code==10 ? @"^" : @"?";
}
static NSString *label(unsigned short code,NSEventModifierFlags flags) {
    return [NSString stringWithFormat:@"%@%@%@%@%@",flags&NSEventModifierFlagControl ? @"⌃" : @"",
        flags&NSEventModifierFlagOption ? @"⌥" : @"",flags&NSEventModifierFlagShift ? @"⇧" : @"",
        flags&NSEventModifierFlagCommand ? @"⌘" : @"",keyName(code)];
}
void DI2ConfigureHotkeys(NSArray<NSDictionary *> *reserved) {
    snapshotUnavailable=NO;
    NSMutableSet *blocked=[NSMutableSet new];
    for(NSDictionary *entry in reserved) {
        if([entry[@"keyCode"] isKindOfClass:NSNumber.class] && [entry[@"modifiers"] isKindOfClass:NSNumber.class])
            [blocked addObject:signature([entry[@"keyCode"] unsignedShortValue],[entry[@"modifiers"] unsignedIntegerValue])];
    }
    // These hardware/Accessibility shortcuts are not all returned as symbolic
    // hotkeys. Keep display, keyboard, sound and Accessibility chords free too.
    for(NSNumber *code in @[@122,@120,@99,@118,@96,@97,@109,@103,@111])
        [blocked addObject:signature(code.unsignedShortValue,NSEventModifierFlagOption)];
    systemBindings=[blocked copy];
    NSMutableArray<DI2HotkeyBinding *> *result=[NSMutableArray new];NSMutableSet *used=[NSMutableSet new];
    for(NSInteger i=0;i<DI2HotkeyCount;i++) {
        DI2HotkeyBinding *item=[DI2HotkeyBinding new];
        if(i<DI2FeatureCount) {
            const DI2FeatureInfo *info=DI2FeatureInfoAt(i);item.keyCode=info->key;
            item.modifiers=(info->modifiers&1 ? NSEventModifierFlagShift : 0)|(info->modifiers&2 ? NSEventModifierFlagOption : 0);
        } else {
            item.keyCode=i==DI2HotkeyCash1000 ? 118 : i==DI2HotkeyCash10000 ? 96 : i==DI2HotkeyDisableAll ? 111 : 10;
            item.modifiers=i==DI2HotkeyPanel ? NSEventModifierFlagCommand : i==DI2HotkeyMouse ? NSEventModifierFlagCommand|NSEventModifierFlagOption : 0;
        }
        item.originalLabel=label(item.keyCode,item.modifiers);item.label=item.originalLabel;
        item.available=![blocked containsObject:signature(item.keyCode,item.modifiers)];
        if(item.available)[used addObject:signature(item.keyCode,item.modifiers)];
        [result addObject:item];
    }
    // Preserve every non-conflicting original first; replacements cannot steal
    // another trainer key. Prioritize opening the panel and the all-off action.
    NSMutableArray<NSNumber *> *order=[NSMutableArray arrayWithArray:@[@(DI2HotkeyPanel),@(DI2HotkeyMouse),@(DI2HotkeyDisableAll),@(DI2HotkeyCash1000),@(DI2HotkeyCash10000)]];
    // Prefer the original plain-F action over a shifted variant of that key.
    for(NSUInteger shifted=0;shifted<2;shifted++)for(NSInteger i=0;i<DI2FeatureCount;i++)
        if((result[i].modifiers!=0)==(shifted!=0))[order addObject:@(i)];
    for(NSNumber *index in order) {
        DI2HotkeyBinding *item=result[index.integerValue];if(item.available)continue;
        item.remapped=YES;
        NSMutableArray<NSDictionary *> *candidates=[NSMutableArray new];
        for(NSNumber *flags in @[@(NSEventModifierFlagControl),@(NSEventModifierFlagShift),@(NSEventModifierFlagOption)])
            [candidates addObject:@{@"keyCode":@(item.keyCode),@"modifiers":flags}];
        const unsigned short digits[]={18,19,20,21,23,22,26,28,25,29};
        for(NSNumber *flags in @[@(NSEventModifierFlagOption),@(NSEventModifierFlagControl)])
            for(NSUInteger j=0;j<10;j++)[candidates addObject:@{@"keyCode":@(digits[j]),@"modifiers":flags}];
        for(NSDictionary *choice in candidates) {
            unsigned short code=[choice[@"keyCode"] unsignedShortValue];
            NSEventModifierFlags flags=[choice[@"modifiers"] unsignedIntegerValue];
            NSString *candidate=signature(code,flags);
            if([blocked containsObject:candidate] || [used containsObject:candidate])continue;
            item.keyCode=code;item.modifiers=flags;item.available=YES;item.label=label(code,flags);
            [used addObject:candidate];break;
        }
        if(!item.available)item.label=@"—";
    }
    bindings=[result copy];
}
void DI2ReloadSystemHotkeys(void) {
    NSCAssert(NSThread.isMainThread,@"macOS hotkey snapshot must be read on main thread");
    CFArrayRef copy=NULL;NSMutableArray *reserved=[NSMutableArray new];
    BOOL unavailable=CopySymbolicHotKeys(&copy)!=noErr || !copy;
    if(!unavailable) {
        NSArray *entries=CFBridgingRelease(copy);
        for(NSDictionary *entry in entries) {
            if(![entry[(__bridge NSString *)kHISymbolicHotKeyEnabled] boolValue])continue;
            NSNumber *code=entry[(__bridge NSString *)kHISymbolicHotKeyCode];
            UInt32 carbon=[entry[(__bridge NSString *)kHISymbolicHotKeyModifiers] unsignedIntValue];
            NSEventModifierFlags flags=(carbon&cmdKey ? NSEventModifierFlagCommand : 0)
                |(carbon&shiftKey ? NSEventModifierFlagShift : 0)|(carbon&optionKey ? NSEventModifierFlagOption : 0)
                |(carbon&controlKey ? NSEventModifierFlagControl : 0);
            if(code)[reserved addObject:@{@"keyCode":code,@"modifiers":@(flags)}];
        }
    } else {
        if(copy)CFRelease(copy);
        // Conservative fallback if the system snapshot is unavailable.
        for(NSNumber *code in @[@103,@111])for(NSNumber *flags in @[@0,@(NSEventModifierFlagShift)])
            [reserved addObject:@{@"keyCode":code,@"modifiers":flags}];
    }
    DI2ConfigureHotkeys(reserved);
    snapshotUnavailable=unavailable;
}
DI2HotkeyBinding *DI2HotkeyAt(NSInteger index) {
    if(!bindings)DI2ReloadSystemHotkeys();
    return index>=0 && index<DI2HotkeyCount ? bindings[index] : nil;
}
void DI2BlockHotkey(NSInteger index) {
    DI2HotkeyBinding *item=DI2HotkeyAt(index);item.available=NO;item.label=@"—";item.remapped=YES;
}
NSString *DI2HotkeyReadableLabel(NSInteger index) {
    DI2HotkeyBinding *item=DI2HotkeyAt(index);
    if(!item.available)return @"Keine Taste";
    NSMutableArray *parts=[NSMutableArray new];
    if(item.modifiers&NSEventModifierFlagControl)[parts addObject:@"Control"];
    if(item.modifiers&NSEventModifierFlagOption)[parts addObject:@"Option"];
    if(item.modifiers&NSEventModifierFlagShift)[parts addObject:@"Umschalt"];
    if(item.modifiers&NSEventModifierFlagCommand)[parts addObject:@"Command"];
    [parts addObject:keyName(item.keyCode)];return [parts componentsJoinedByString:@" + "];
}
NSInteger DI2HotkeyForEvent(NSEvent *event) {
    if(event.type!=NSEventTypeKeyDown)return -1;
    if(!bindings)DI2ReloadSystemHotkeys();
    NSEventModifierFlags flags=event.modifierFlags&DI2HotkeyModifierMask();
    for(NSInteger i=0;i<DI2HotkeyCount;i++) {
        DI2HotkeyBinding *item=bindings[i];
        if(item.available && event.keyCode==item.keyCode && flags==item.modifiers)return i;
    }
    // Preserve the ANSI caret fallback only when that actual physical chord
    // is neither reserved by macOS nor already assigned to another trainer key.
    if([event.charactersIgnoringModifiers isEqual:@"^"] && (flags&NSEventModifierFlagCommand)
        && !(flags&NSEventModifierFlagControl)
        && ![systemBindings containsObject:signature(event.keyCode,flags)]) {
        NSInteger i=flags&NSEventModifierFlagOption ? DI2HotkeyMouse : DI2HotkeyPanel;
        DI2HotkeyBinding *item=bindings[i];
        if(item.available && !item.remapped && (flags&~NSEventModifierFlagShift)==item.modifiers)return i;
    }
    return -1;
}
NSString *DI2HotkeyConflictSummary(void) {
    if(!bindings)DI2ReloadSystemHotkeys();NSMutableArray *changes=[NSMutableArray new];
    for(DI2HotkeyBinding *item in bindings)if(item.remapped)
        [changes addObject:[NSString stringWithFormat:@"%@ → %@",item.originalLabel,item.label]];
    NSString *summary=changes.count ? [@"Umgelegt: " stringByAppendingString:[changes componentsJoinedByString:@" · "]] : @"Keine Überschneidung mit aktivierten macOS-Systemkürzeln erkannt.";
    return snapshotUnavailable ? [@"macOS-Belegung nicht lesbar; konservative Ersatzprüfung. " stringByAppendingString:summary] : summary;
}
NSInteger DI2ShortcutForEvent(NSEvent *event) {
    NSInteger hotkey=DI2HotkeyForEvent(event);
    return hotkey==DI2HotkeyPanel ? DI2ShortcutPanel : hotkey==DI2HotkeyMouse ? DI2ShortcutMouse : -1;
}
@implementation DI2OverlayShortcuts {
    BOOL _registered[DI2ShortcutCount], _held[DI2ShortcutCount];
}
- (void)setEnabled:(BOOL)enabled {
    _enabled=enabled;
    if (!enabled) memset(_held,0,sizeof(_held));
}
- (void)setRegistered:(BOOL)registered shortcut:(DI2OverlayShortcut)shortcut {
    if (shortcut<0 || shortcut>=DI2ShortcutCount) return;
    _registered[shortcut]=registered;
    if (!registered) _held[shortcut]=NO;
}
- (BOOL)ownsLocalEvent:(NSEvent *)event {
    NSInteger shortcut=DI2ShortcutForEvent(event);
    DI2HotkeyBinding *binding=DI2HotkeyAt(shortcut==DI2ShortcutPanel ? DI2HotkeyPanel : DI2HotkeyMouse);
    return _enabled && shortcut>=0 && binding.available && event.keyCode==binding.keyCode
        && (event.modifierFlags&DI2HotkeyModifierMask())==binding.modifiers && _registered[shortcut];
}
- (BOOL)nativeShortcut:(DI2OverlayShortcut)shortcut pressed:(BOOL)pressed {
    if (shortcut<0 || shortcut>=DI2ShortcutCount || !_enabled || !_registered[shortcut]) return NO;
    if(!DI2HotkeyAt(shortcut==DI2ShortcutPanel ? DI2HotkeyPanel : DI2HotkeyMouse).available)return NO;
    if (!pressed) { _held[shortcut]=NO; return YES; }
    if (_held[shortcut]) return YES;
    _held[shortcut]=YES;
    if (self.handler) self.handler(shortcut);
    return YES;
}
@end
