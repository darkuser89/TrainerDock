// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "GodotABI.h"
#import <os/log.h>
@implementation MHTNativeAdapter
- (void)onGameThread:(dispatch_block_t)work {
    static BOOL reported=NO;if(!reported){reported=YES;os_log(OS_LOG_DEFAULT,"TrainerDock Dome: adapter dispatch requested");}
    if(!DKSupportedImage())return;
    // Godot Callable.call_deferred dispatches through its MessageQueue. No main-
    // queue replacement executes gameplay work; retry only while Godot starts.
    if(!DKEnqueue(work))dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/10),dispatch_get_main_queue(),^{[self onGameThread:work];});
}
- (MTGameContext *)captureContext {
    NSDictionary *native=DKInspect();MTGameContext *context=[MTGameContext new];
    NSInteger kind=[native[@"kind"] integerValue];context.kind=kind>=MTSessionUnsupported && kind<=MTSessionNetwork ? kind : MTSessionUnsupported;
    context.identity=native[@"identity"] ?: @"unavailable";context.note=native[@"note"] ?: @"Keine native Bestätigung.";return context;
}
- (void)releaseEffects{DKRelease();}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    NSDictionary *native=DKEffect(feature,wanted,value);MTFeatureState *state=[MTFeatureState new];
    state.available=[native[@"available"] boolValue];state.active=wanted && [native[@"active"] boolValue];state.note=native[@"note"] ?: @"Keine native Rücklesebestätigung.";return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value{return DKOneShot(feature,value);}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return DKMouse(wanted);}
@end
