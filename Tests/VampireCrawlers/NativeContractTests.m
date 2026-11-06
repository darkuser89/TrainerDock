// SPDX-License-Identifier: GPL-3.0-only
// Synthetic delivery gates only; never an in-game effect claim.
#import "GameBridge.h"
#import "VampireBackend.h"
#import "UnityLoop.h"
#import "Overlay.h"
#include <math.h>
@interface VCDelayedFixture : NSObject <MTGameAdapter>
@property(nonatomic) NSMutableArray<dispatch_block_t> *pending;
@property(nonatomic) NSUInteger actions;
@end
@implementation VCDelayedFixture
- (instancetype)init {if((self=[super init]))_pending=[NSMutableArray new];return self;}
- (void)onGameThread:(dispatch_block_t)work {[_pending addObject:[work copy]];}
- (MTGameContext *)captureContext {MTGameContext *c=[MTGameContext new];c.kind=MTSessionSolo;c.identity=@"fixture-owner";c.note=@"fixture";return c;}
- (void)releaseEffects {}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {(void)feature;(void)value;MTFeatureState *s=[MTFeatureState new];s.available=YES;s.active=wanted;return s;}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {(void)feature;(void)value;_actions++;return @"fixture";}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return wanted;}
@end
static void check(BOOL condition,const char *message){if(!condition){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static void flush(VCDelayedFixture *f){
    for(int i=0;i<8;i++){
        if(f.pending.count){dispatch_block_t work=f.pending.firstObject;[f.pending removeObjectAtIndex:0];work();}
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.003]];
    }
}
int main(void){@autoreleasepool{
    check(!VCInFrame(),"fixture process has no engine callback");
    check([VCInspect()[@"kind"] integerValue]==MTSessionUnsupported,"off-thread context rejected");
    check(![VCEffect(0,YES,0)[@"active"] boolValue],"off-thread native activation rejected");
    check(VCValues().count==0,"off-thread native reads rejected");
    check([VCOneShot(MTFeatureHealth,10) containsString:@"keine Änderung"],"off-thread editor rejected");
    check(!VCMouse(YES),"off-thread input capture rejected");
    NSInteger shots=0;for(NSInteger i=0;i<MTFeatureCount;i++){const MTFeatureInfo *info=MTFeatureInfoAt(i);check(info && info->implemented,"complete catalog");if(info->oneShot)shots++;if(info->numeric)check(isfinite(info->initial) && info->initial>=info->minimum && info->initial<=info->maximum,"bounded catalog defaults");}
    check(MTFeatureCount==27 && shots==23,"27 features including 23 explicit editors");
    VCDelayedFixture *fixture=[VCDelayedFixture new];MTGameBridge *bridge=[[MTGameBridge alloc]initWithAdapter:fixture];
    [bridge poll];flush(fixture);check(bridge.state.ready,"fixture ready");
    [bridge performFeature:MTFeatureHealth];[bridge performAction:MTTrainerDisableAll];flush(fixture);
    check(fixture.actions==0,"all-off cancels an already dispatched one-shot before delivery");
    [bridge performFeature:MTFeatureHealth];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.05]];flush(fixture);
    check(fixture.actions==0,"expired engine delivery discarded");
    [bridge performFeature:MTFeatureHealth];flush(fixture);check(fixture.actions==1,"fresh explicit editor delivered exactly once");
    [bridge poll];flush(fixture);check(fixture.actions==1,"poll does not repeat editor");
    [NSApplication sharedApplication];
    MTOverlayRoot *overlay=[[MTOverlayRoot alloc]initWithFrame:NSMakeRect(0,0,1280,800) version:@"fixture"];
    [overlay updateState:bridge.state];__block NSInteger pressed=-1;overlay.featureHandler=^(MTFeature f){pressed=f;};
    NSEvent *letter=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"a" charactersIgnoringModifiers:@"a" isARepeat:NO keyCode:0];
    check(![overlay handleEvent:letter] && pressed==-1,"ordinary letter cannot accidentally run an editor with no shortcut");
    NSEvent *function=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:122];
    check([overlay handleEvent:function] && pressed==MTFeatureGodmode,"explicit F1 reaches the correct feature");
    puts("PASS: Vampire Crawlers catalog, native thread gates, in-flight cancellation, delivery deadline and exactly-once edits. Synthetic checks only.");
}return 0;}
