// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
#import "LiesOfPAdapter.h"
@implementation MTGameContext
- (instancetype)init { if((self=[super init])) { _identity=@"unsupported";_note=@"Keine geprüfte Spielanbindung vorhanden."; }return self; }
@end
@implementation MTUnsupportedAdapter
- (void)onGameThread:(dispatch_block_t)work { dispatch_async(dispatch_get_main_queue(),work); }
- (MTGameContext *)captureContext { return [MTGameContext new]; }
- (void)releaseEffects {}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    (void)feature;(void)wanted;(void)value;MTFeatureState *state=[MTFeatureState new];state.note=@"Spieladapter implementieren und prüfen.";return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value { (void)feature;(void)value;return @"Nicht unterstützt."; }
- (BOOL)setOverlayInteraction:(BOOL)wanted { (void)wanted;return NO; }
@end
id<MTGameAdapter> MTCreateGameAdapter(void) {
    return [LOPGameAdapter new];
}
