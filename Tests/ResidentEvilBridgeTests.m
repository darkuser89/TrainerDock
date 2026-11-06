// SPDX-License-Identifier: GPL-3.0-only
#import "GameBridge.h"
#import "OverlaySettings.h"
#import "TrainerMaterial.h"
#import "CheatPreferences.h"
#import "MHTRuntimeBridge.h"
#import <AppKit/AppKit.h>
#include <math.h>
@implementation RE2GameContext @end
@interface REFixture : NSObject <RE2GameAdapter>
@property(nonatomic) RE2SessionKind mode;
@property(nonatomic) NSUInteger world,actions;
@end
@implementation REFixture
- (instancetype)init{if((self=[super init])){_mode=RE2SessionSolo;_world=1;}return self;}
- (void)onGameThread:(dispatch_block_t)work{dispatch_async(dispatch_get_main_queue(),work);}
- (RE2GameContext *)captureContext{RE2GameContext *c=[RE2GameContext new];c.kind=self.mode;c.identity=[NSString stringWithFormat:@"world-%lu",(unsigned long)self.world];c.note=@"fixture";return c;}
- (void)releaseEffects{}
- (RE2FeatureState *)applyFeature:(RE2Feature)feature wanted:(BOOL)wanted value:(double)value{(void)feature;(void)value;RE2FeatureState *s=[RE2FeatureState new];s.available=YES;s.active=wanted;s.note=@"fixture readback";return s;}
- (NSString *)performOneShot:(RE2Feature)feature value:(double)value{(void)feature;(void)value;self.actions++;return @"fixture action";}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return wanted;}
@end
id<RE2GameAdapter> RE2CreateGameAdapter(void){return [REFixture new];}
static void check(BOOL c,NSString *m){if(!c){fprintf(stderr,"FAIL: %s\n",m.UTF8String);exit(1);}}
static void drain(void){for(int i=0;i<24;i++)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];}
int main(void){@autoreleasepool{
    REFixture *a=[REFixture new];RE2GameBridge *b=[[RE2GameBridge alloc]initWithAdapter:a];[b poll];drain();check(b.state.ready,@"RE fixture solo ready");
    NSString *profile=NSProcessInfo.processInfo.environment[@"MHT_PROFILE"];
    NSDictionary *native=MHTDecodeMessage(MHTNativeSelectionJSON());
    check(RE2NormalizeSelection(native,profile)!=nil && [native[@"features"] count]==(NSUInteger)RE2ActiveFeatureCount(),@"Resident Evil module converts launch selection for its own game catalog");
    MHTStartControl(b,^NSDictionary *{return @{};},^(NSDictionary *options){(void)options;});
    NSInteger oneShot=-1;for(NSInteger i=0;i<RE2ActiveFeatureCount();i++)if(RE2FeatureInfoAt(i)->oneShot)oneShot=i;check(oneShot>=0,@"RE catalog has one-shot");
    NSDictionary *on=@{@"action":@"set",@"feature":@0,@"wanted":@YES};
    void (^reply)(RE2TrainerState *,NSString *)=^(RE2TrainerState *s,NSString *error){(void)s;check(!error,@"RE explicit setter accepted");};
    [b controlCommand:on completion:reply];[b controlCommand:on completion:reply];drain();check(b.state.features[0].active,@"RE repeated set stays on");
    a.mode=RE2SessionLoading;[b poll];drain();check(!b.state.ready && b.state.features[0].wanted && !b.state.features[0].active,@"RE loading preserves choices");
    a.mode=RE2SessionSolo;a.world++;[b poll];drain();check(b.state.features[0].active,@"RE continuous effect resumes");
    NSUInteger before=a.actions;[b poll];[b performFeature:oneShot];a.world++;drain();check(a.actions==before,@"RE stale one-shot rejected");
    a.mode=RE2SessionNetwork;[b poll];drain();check(b.state.ready && b.state.features[0].wanted && b.state.features[0].active,@"RE network preserves choices");
    [b performFeature:oneShot];drain();check(a.actions==before+1,@"RE network accepts explicit one-shot");before=a.actions;
    a.mode=RE2SessionSolo;[b poll];drain();[b controlCommand:on completion:reply];drain();[b poll];for(int i=0;i<24;i++)[b performFeature:oneShot];[b performAction:RE2TrainerDisableAll];a.mode=RE2SessionLoading;drain();check(!b.state.features[0].wanted && a.actions==before,@"RE all-off survives queue and loading");
    check(![RE2NormalizeOverlayOptions(@{@"liquidGlass":@NO})[@"liquidGlass"] boolValue],@"RE glass option retained");
    MTTrainerMaterial *material=[[MTTrainerMaterial alloc]initWithContentView:[NSView new] cornerRadius:12];material.liquidGlassEnabled=NO;check(!material.allowsLiquidGlass,@"RE glass fallback");
    puts("PASS: Resident Evil explicit setters, loading, stale one-shots, network continuity, queue stop and glass fallback.");
}return 0;}
