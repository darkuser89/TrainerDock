// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "MonoRuntime.h"
@implementation MHTNativeAdapter
- (void)onGameThread:(dispatch_block_t)work {
    if(!DUSupportedImage())return;
    // Main-queue retry only; execution is exclusively in the real Unity Update.
    if(!DUEnqueue(work))dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/10),dispatch_get_main_queue(),^{[self onGameThread:work];});
}
- (MTGameContext *)captureContext {
    NSDictionary *native=DUInspect();MTGameContext *context=[MTGameContext new];NSInteger kind=[native[@"kind"] integerValue];
    context.kind=kind>=MTSessionUnsupported && kind<=MTSessionNetwork ? kind : MTSessionUnsupported;
    context.identity=native[@"identity"] ?: @"unavailable";context.note=native[@"note"] ?: @"Keine native Bestätigung.";return context;
}
- (void)releaseEffects{DURelease();}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    NSDictionary *native=DUEffect(feature,wanted,value);MTFeatureState *state=[MTFeatureState new];
    state.available=[native[@"available"] boolValue];state.active=wanted && [native[@"active"] boolValue];state.note=native[@"note"] ?: @"Keine native Rücklesebestätigung.";return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value{return DUOneShot(feature,value);}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return DUMouse(wanted);}
@end
