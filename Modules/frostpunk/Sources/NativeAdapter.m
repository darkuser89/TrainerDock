// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "FrostpunkEngine.h"
@implementation MHTNativeAdapter
- (void)onGameThread:(dispatch_block_t)work { FPOnGameThread(work); }
- (MTGameContext *)captureContext {
    NSDictionary *native=FPInspect();
    MTGameContext *context=[MTGameContext new];
    context.kind=[native[@"kind"] integerValue];
    context.identity=native[@"identity"];
    context.note=native[@"note"];
    return context;
}
- (void)releaseEffects { FPReleaseEffects(); }
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    NSDictionary *native=FPEffect(feature,wanted,value);
    MTFeatureState *state=[MTFeatureState new];
    state.available=[native[@"available"] boolValue];
    state.active=[native[@"active"] boolValue];
    state.note=native[@"note"];
    return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value { return FPOneShot(feature,value); }
- (BOOL)setOverlayInteraction:(BOOL)wanted { return FPSetMouse(wanted); }
@end
