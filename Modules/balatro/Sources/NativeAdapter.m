// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "BalatroEngine.h"
@implementation MHTNativeAdapter
- (void)onGameThread:(dispatch_block_t)work {BAEnqueue(work);}
- (MTGameContext *)captureContext {
 NSDictionary *native=BAInspect();MTGameContext *c=[MTGameContext new];
 c.kind=[native[@"kind"] integerValue];c.identity=native[@"identity"];c.note=native[@"note"];return c;
}
- (void)releaseEffects {BARelease();}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
 NSDictionary *native=BAEffect(feature,wanted,value);MTFeatureState *s=[MTFeatureState new];
 s.available=[native[@"available"] boolValue];s.active=[native[@"active"] boolValue];s.note=native[@"note"];return s;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {return BAOneShot(feature,value);}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return BAMouse(wanted);}
@end
