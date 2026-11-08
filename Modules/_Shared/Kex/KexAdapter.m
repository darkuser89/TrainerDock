// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "KexEngine.h"
@implementation MHTNativeAdapter
- (void)onGameThread:(dispatch_block_t)work {KEXEnqueue(work);}
- (MTGameContext *)captureContext {NSDictionary *n=KEXInspect();MTGameContext *c=[MTGameContext new];c.kind=[n[@"kind"] integerValue];c.identity=n[@"identity"];c.note=n[@"note"];return c;}
- (void)releaseEffects {KEXRelease();}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {(void)value;NSDictionary *n=KEXEffect(feature,wanted);MTFeatureState *s=[MTFeatureState new];s.available=[n[@"available"] boolValue];s.active=[n[@"active"] boolValue];s.note=n[@"note"];return s;}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {(void)feature;(void)value;return @"Keine Einmalaktion vorhanden.";}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return KEXMouse(wanted);}
@end
