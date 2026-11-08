// SPDX-License-Identifier: GPL-3.0-only
// Synthetic regression using the real Overlay and TrainerFeatures sources.
// Link without GameBridge.m: this state fixture never schedules game work.
#import "Overlay.h"
#import <Carbon/Carbon.h>
#include <assert.h>

@implementation MTTrainerState
- (instancetype)init {
    if((self=[super init])) {
        NSMutableArray *features=[NSMutableArray new];
        for(NSInteger i=0;i<MTFeatureCount;i++) {
            MTFeatureState *feature=[MTFeatureState new];
            feature.value=MTFeatureInfoAt(i)->initial;
            feature.available=YES;
            [features addObject:feature];
        }
        self.features=features;
        self.status=@"synthetic";
        self.message=@"";
    }
    return self;
}
@end

static NSEvent *key(unsigned short code,NSEventModifierFlags flags,BOOL repeat) {
    return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:flags timestamp:0 windowNumber:0 context:nil
        characters:@"" charactersIgnoringModifiers:@"" isARepeat:repeat keyCode:code];
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        MTOverlayRoot *root=[[MTOverlayRoot alloc]initWithFrame:NSMakeRect(0,0,1000,800)
            version:@"Shortcut synthetic"];
        MTTrainerState *state=[MTTrainerState new];
        state.ready=YES;
        [root updateState:state];
        __block NSInteger selected=-1,featureCalls=0,allOff=0;
        root.featureHandler=^(MTFeature feature) {selected=feature;featureCalls++;};
        root.actionHandler=^(MTTrainerAction action) {if(action==MTTrainerDisableAll)allOff++;};
        NSMutableSet *combinations=[NSMutableSet new];
        assert(MTFeatureCount==27);
        for(NSInteger i=0;i<MTFeatureCount;i++) {
            const MTFeatureInfo *info=MTFeatureInfoAt(i);
            NSString *combination=[NSString stringWithFormat:@"%u/%lu",
                info->key,(unsigned long)info->modifiers];
            assert(![combinations containsObject:combination]);
            [combinations addObject:combination];
            assert(!(info->key==kVK_F9 && info->modifiers==NSEventModifierFlagShift));
            selected=-1;
            NSInteger before=featureCalls;
            // Caps Lock and the hardware Fn marker must not break F-key matching.
            assert([root handleEvent:key(info->key,
                info->modifiers|NSEventModifierFlagFunction|NSEventModifierFlagCapsLock,NO)]);
            assert(selected==i && featureCalls==before+1 && allOff==0);
            selected=-1;
            assert(![root handleEvent:key(info->key,info->modifiers,YES)]);
            assert(selected==-1 && featureCalls==before+1);
        }
        selected=-1;
        NSInteger before=featureCalls;
        assert([root handleEvent:key(kVK_F9,NSEventModifierFlagShift,NO)]);
        assert(allOff==1 && selected==-1 && featureCalls==before);
        assert(![root handleEvent:key(kVK_F9,NSEventModifierFlagShift,YES)]);
        assert(![root handleEvent:key(kVK_F9,
            NSEventModifierFlagShift|NSEventModifierFlagOption,NO)]);
        assert(allOff==1 && featureCalls==before);
        assert(![root handleEvent:key(kVK_F1,NSEventModifierFlagCommand,NO)]);
        assert(![root handleEvent:key(kVK_F1,NSEventModifierFlagControl,NO)]);
        assert(featureCalls==before);
        const MTFeatureInfo *laws=MTFeatureInfoAt(MTFeatureLaws);
        assert(laws->key==kVK_F11 && laws->modifiers==NSEventModifierFlagShift);
        assert([laws->shortcut isEqual:@"⇧F11"]);
        puts("PASS: all 27 catalog shortcuts dispatch exactly once; repeats ignored; Shift-F9 only disables all; Laws uses Shift-F11. No game loaded.");
    }
    return 0;
}
