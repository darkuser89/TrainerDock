// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "StrayEngine.hpp"
#import "StrayInput.hpp"
#import "PlayerEffects.hpp"
#import "Defluxor.hpp"
#import "EnemyEffects.hpp"
#include <exception>
@interface MHTNativeAdapter () { st::PlayerContext _context; }
@end
@implementation MHTNativeAdapter
- (instancetype)init {if((self=[super init]))st::bind();return self;}
- (void)onGameThread:(dispatch_block_t)work {
    if(!work)return;
    if(!st::onGameThread(work))dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/5),dispatch_get_main_queue(),^{[self onGameThread:work];});
}
- (MTGameContext *)captureContext {
    MTGameContext *c=[MTGameContext new];c.kind=MTSessionLoading;c.identity=@"";c.note=@"Auf den lokalen Spielstand warten.";
    try{_context=st::playerContext();c.note=_context.note ?: c.note;if(_context.ready){c.kind=MTSessionSolo;c.identity=_context.identity;}}catch(const std::exception &){}return c;
}
- (void)releaseEffects {st::releasePlayerEffects();STEnemyRelease();STDefluxorRelease();}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *s=[MTFeatureState new];s.wanted=wanted;s.value=value;s.note=@"Native Wirkung noch nicht bestätigt.";
    try{NSDictionary *d=feature==MTFeatureDefluxor?STDefluxorApply(wanted):(feature==MTFeatureInvisibleZurks||feature==MTFeatureInvisibleSentinels||feature==MTFeatureSentinelsPeaceful)?STEnemyApply(feature,wanted):st::playerFeature(_context,feature,wanted,value);
        s.available=[d[@"available"] boolValue];s.active=wanted&&[d[@"active"] boolValue];s.note=d[@"note"] ?: s.note;
    }catch(const std::exception &){s.note=@"Die native Spielanbindung hat den Auftrag abgelehnt.";}return s;
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return STSetOverlayInteraction(wanted);}
@end
