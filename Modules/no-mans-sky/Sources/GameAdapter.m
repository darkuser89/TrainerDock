// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
#import "NMSAdapter.h"
@implementation MTGameContext
- (instancetype)init{if((self=[super init])){_kind=MTSessionUnsupported;_identity=@"unimplemented";_note=@"Keine native Spielanbindung implementiert.";}return self;}
@end
@implementation MTUnsupportedAdapter
- (void)onGameThread:(dispatch_block_t)work {
    // No verified engine delivery exists. Never pretend the main queue is a GameThread.
    (void)work;
}
- (MTGameContext *)captureContext{return [MTGameContext new];}
- (void)releaseEffects{}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    (void)feature;(void)wanted;(void)value;MTFeatureState *state=[MTFeatureState new];
    state.note=@"Keine native Wirkung implementiert.";return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value{(void)feature;(void)value;return @"Nicht implementiert. Keine Aktion ausgeführt.";}
- (BOOL)setOverlayInteraction:(BOOL)wanted{(void)wanted;return NO;}
@end
id<MTGameAdapter> MTCreateGameAdapter(void){return [MTNMSAdapter new];}
