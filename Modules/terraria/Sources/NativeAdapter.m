// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "TerrariaBackend.h"
@implementation MHTNativeAdapter
- (void)onGameThread:(dispatch_block_t)work {
    if(!TREnqueue(work))dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/10),dispatch_get_main_queue(),^{[self onGameThread:work];});
}
- (MTGameContext *)captureContext {NSDictionary *s=TRInspect();MTGameContext *c=[MTGameContext new];c.kind=[s[@"kind"] integerValue];c.identity=s[@"identity"];c.note=s[@"note"];return c;}
- (void)releaseEffects { TRRelease(); }
- (MTFeatureState *)applyFeature:(MTFeature)f wanted:(BOOL)w value:(double)v {NSDictionary *s=TREffect(f,w,v);MTFeatureState *r=[MTFeatureState new];r.available=[s[@"available"] boolValue];r.active=[s[@"active"] boolValue];r.note=s[@"note"];return r;}
- (NSString *)performOneShot:(MTFeature)f value:(double)v {(void)f;(void)v;return @"Dieser Trainer hat ausschließlich Dauerschalter.";}
- (BOOL)setOverlayInteraction:(BOOL)wanted { return TRMouse(wanted); }
@end
