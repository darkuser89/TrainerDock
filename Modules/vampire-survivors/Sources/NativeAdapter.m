// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "MonoRuntime.h"
@implementation MHTNativeAdapter
- (void)onGameThread:(dispatch_block_t)work {
    if(!VSSupportedImage()){dispatch_async(dispatch_get_main_queue(),work);return;}
    // Main-queue retry only; execution is exclusively in the real Unity Update.
    if(!VSEnqueue(work))dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/10),dispatch_get_main_queue(),^{[self onGameThread:work];});
}
- (MTGameContext *)captureContext {
    NSDictionary *native=VSInspect();MTGameContext *context=[MTGameContext new];NSInteger kind=[native[@"kind"] integerValue];
    context.kind=kind>=MTSessionUnsupported && kind<=MTSessionNetwork ? kind : MTSessionUnsupported;
    context.identity=native[@"identity"] ?: @"unavailable";context.note=native[@"note"] ?: @"Keine native Bestätigung.";return context;
}
- (void)releaseEffects{VSRelease();}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    NSDictionary *native=VSEffect(feature,wanted,value);MTFeatureState *state=[MTFeatureState new];
    state.available=[native[@"available"] boolValue];state.active=wanted && [native[@"active"] boolValue];state.note=native[@"note"] ?: @"Keine native Rücklesebestätigung.";return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value{return VSOneShot(feature,value);}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return VSMouse(wanted);}
@end
