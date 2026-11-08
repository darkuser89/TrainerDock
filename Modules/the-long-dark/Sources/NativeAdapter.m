// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "LongDarkBackend.h"
#import "UnityLoop.h"
@implementation MHTNativeAdapter
- (instancetype)init {if((self=[super init]))TLDStartBackend();return self;}
- (void)onGameThread:(dispatch_block_t)work {
    if(!TLDEnqueue(work))dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/10),dispatch_get_main_queue(),^{[self onGameThread:work];});
}
- (MTGameContext *)captureContext {
    NSDictionary *native=TLDInspect();MTGameContext *context=[MTGameContext new];
    context.kind=[native[@"kind"] integerValue];context.identity=native[@"identity"] ?: @"unavailable";
    context.note=native[@"note"] ?: @"Warte auf den nativen Unity-Rückruf.";return context;
}
- (void)releaseEffects {TLDRelease();}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    NSDictionary *native=TLDEffect(feature,wanted,value);MTFeatureState *state=[MTFeatureState new];
    state.available=[native[@"available"] boolValue];state.active=wanted && [native[@"active"] boolValue];state.note=native[@"note"];return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {return TLDOneShot(feature,value);}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return TLDMouse(wanted);}
@end
