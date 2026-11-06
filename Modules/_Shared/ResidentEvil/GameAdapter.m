// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
#import "RE2Adapter.h"
#import "RE3Adapter.h"
#import "RE4Adapter.h"
#import "RE7Adapter.h"
#import "RE8Adapter.h"
@implementation RE2GameContext
- (instancetype)init { if((self=[super init])) { _identity=@"unsupported";_note=@"Keine geprüfte Spielanbindung vorhanden."; }return self; }
@end
@implementation RE2UnsupportedAdapter
- (void)onGameThread:(dispatch_block_t)work { dispatch_async(dispatch_get_main_queue(),work); }
- (RE2GameContext *)captureContext { return [RE2GameContext new]; }
- (void)releaseEffects {}
- (RE2FeatureState *)applyFeature:(RE2Feature)feature wanted:(BOOL)wanted value:(double)value {
    (void)feature;(void)wanted;(void)value;RE2FeatureState *state=[RE2FeatureState new];state.note=@"Spieladapter implementieren und prüfen.";return state;
}
- (NSString *)performOneShot:(RE2Feature)feature value:(double)value { (void)feature;(void)value;return @"Nicht unterstützt."; }
- (BOOL)setOverlayInteraction:(BOOL)wanted { (void)wanted;return NO; }
@end
id<RE2GameAdapter> RE2CreateGameAdapter(void) {
    if([NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.VillageUS"])return [RE8NativeAdapter new];
    if([NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE7US"])return [RE7NativeAdapter new];
    // Exact per-game adapter dispatch.
    if([NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE4US"])return [RE4NativeAdapter new];
    return [NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE3US"] ? [RE3NativeAdapter new] : [RE2NativeAdapter new];
}
