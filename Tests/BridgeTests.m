// SPDX-License-Identifier: GPL-3.0-only
// Synthetic engine fixture, linked only into tests. Never shipped in TrainerDock.app.
#import "GameBridge.h"
#import "OverlaySettings.h"
#import "TrainerMaterial.h"
#import "MHTRuntimeBridge.h"
#import <AppKit/AppKit.h>
#include <math.h>
#if defined(MHT_LOP)
#import "SelectionSettings.h"
#endif
@implementation MTGameContext @end
@interface Fixture : NSObject <MTGameAdapter>
@property(nonatomic) MTSessionKind mode;
@property(nonatomic) NSUInteger world,actions,releases;
@property(nonatomic) BOOL suppressFirst;
@end
@implementation Fixture
- (instancetype)init{if((self=[super init])){_mode=MTSessionSolo;_world=1;}return self;}
- (void)onGameThread:(dispatch_block_t)work{dispatch_async(dispatch_get_main_queue(),work);}
- (MTGameContext *)captureContext {MTGameContext *c=[MTGameContext new];c.kind=self.mode;c.identity=[NSString stringWithFormat:@"world-%lu",(unsigned long)self.world];c.note=@"fixture";return c;}
- (void)releaseEffects{self.releases++;}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value{(void)value;MTFeatureState *s=[MTFeatureState new];s.available=YES;s.active=wanted&&!(self.suppressFirst&&feature==0);s.note=@"fixture readback";return s;}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value{(void)feature;(void)value;self.actions++;return @"fixture action";}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return wanted;}
@end
id<MTGameAdapter> MTCreateGameAdapter(void){return [Fixture new];}
static void check(BOOL condition,NSString *message){if(!condition){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
static void drain(void){for(int i=0;i<24;i++)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.002]];}
int main(void){@autoreleasepool{
#if defined(TEST_CRIMSON)
    MTUseCrimsonFeatures();
#endif
    Fixture *adapter=[Fixture new];MTGameBridge *bridge=[[MTGameBridge alloc]initWithAdapter:adapter];
    NSDictionary *native=MHTDecodeMessage(MHTNativeSelectionJSON());
#if defined(MHT_LOP)
    check([native[@"catalog"] isEqual:@"liesofp-36-v2"] && [native[@"features"] isKindOfClass:NSArray.class],@"Lies of P converts common launch selection inside its module");
#else
    check([native[@"features"] isKindOfClass:NSDictionary.class],@"Module consumes common launch selection");
#endif
    MHTStartControl(bridge,^NSDictionary *{return @{};},^(NSDictionary *options){(void)options;});
    [bridge poll];drain();check(bridge.state.ready,@"Solo context ready");
#if defined(MHT_LOP)
    check(MTFeatureCount==36 && MTFeatureHealth==0,@"Lies of P has no master entry");
    [bridge setWanted:YES forFeature:MTFeatureHealth];drain();
    check(bridge.state.features[MTFeatureHealth].active,@"First real option activates directly");
    [bridge setWanted:NO forFeature:MTFeatureHealth];drain();adapter.suppressFirst=YES;
    [bridge setWanted:YES forFeature:MTFeatureStamina];drain();
    check(bridge.state.features[MTFeatureStamina].active&&!bridge.state.features[MTFeatureHealth].wanted,@"Other options do not arm the first switch");
    NSUInteger directActions=adapter.actions;[bridge performFeature:MTFeatureSaveCoordinates];drain();
    check(adapter.actions==directActions+1,@"One-shot works while the first feature is inactive");
    [bridge performAction:MTTrainerDisableAll];drain();adapter.suppressFirst=NO;
    NSDictionary *legacy=MTNormalizeSelection(@{@"schema":@1,@"catalog":@"liesofp-37-v1",@"features":@[
        @{@"id":@0,@"wanted":@YES,@"value":@0},@{@"id":@1,@"wanted":@NO,@"value":@0},
        @{@"id":@2,@"wanted":@YES,@"value":@0},@{@"id":@17,@"wanted":@YES,@"value":@3} ]});
    check([legacy[@"catalog"] isEqual:@"liesofp-36-v2"],@"Legacy native selection is explicitly migrated");
    NSMutableDictionary *mapped=[NSMutableDictionary new];for(NSDictionary *row in legacy[@"features"])mapped[row[@"id"]]=row;
    check(![mapped[@(MTFeatureHealth)][@"wanted"] boolValue]&&[mapped[@(MTFeatureStamina)][@"wanted"] boolValue]
        &&[mapped[@(MTFeaturePlayerMultiplier)][@"value"] doubleValue]==3,@"Dropping the old master preserves the intended feature and numeric bindings");
#endif
    NSInteger continuous=-1,oneShot=-1,numeric=-1;
    for(NSInteger i=0;i<MTFeatureCount;i++){const MTFeatureInfo *f=MTFeatureInfoAt(i);if(f->implemented && !f->oneShot)continuous=i;if(f->implemented && f->oneShot)oneShot=i;if(f->implemented && f->numeric)numeric=i;}
    check(continuous>=0,@"Fixture has a continuous feature; numeric features are optional");
    [bridge setWanted:YES forFeature:continuous];[bridge setWanted:YES forFeature:continuous];drain();
    check(bridge.state.features[continuous].wanted && bridge.state.features[continuous].active,@"Repeated set-on is idempotent");
    [bridge setWanted:NO forFeature:continuous];[bridge setWanted:NO forFeature:continuous];drain();
    check(!bridge.state.features[continuous].wanted,@"Repeated set-off is idempotent");
    [bridge setWanted:YES forFeature:continuous];drain();
    adapter.mode=MTSessionLoading;[bridge poll];drain();
    check(!bridge.state.ready && bridge.state.features[continuous].wanted && !bridge.state.features[continuous].active,@"Loading preserves selection and releases effects");
    adapter.mode=MTSessionSolo;adapter.world++;[bridge poll];drain();
    check(bridge.state.features[continuous].active,@"Continuous effects resume after loading");
    NSUInteger before=adapter.actions;[bridge poll];if(oneShot>=0)[bridge performFeature:oneShot];adapter.world++;drain();
    check(adapter.actions==before,@"One-shot discarded after owner/world changes");
    adapter.mode=MTSessionNetwork;[bridge poll];drain();
    check(bridge.state.ready && bridge.state.features[continuous].wanted && bridge.state.features[continuous].active,@"Network context preserves selection and effects");
    if(oneShot>=0){[bridge performFeature:oneShot];drain();check(adapter.actions==before+1,@"Network accepts an explicit one-shot");}before=adapter.actions;
    adapter.mode=MTSessionSolo;[bridge poll];drain();check(bridge.state.features[continuous].active,@"Mode changes preserve continuous choices");
    if(numeric>=0){[bridge setValue:NAN forFeature:numeric];drain();check(isfinite(bridge.state.features[numeric].value),@"Invalid numeric values rejected");}
    [bridge setWanted:YES forFeature:continuous];drain();[bridge poll];for(int i=0;i<24;i++){if(oneShot>=0)[bridge performFeature:oneShot];else [bridge setWanted:YES forFeature:continuous];}[bridge performAction:MTTrainerDisableAll];adapter.mode=MTSessionLoading;drain();
    check(!bridge.state.features[continuous].wanted && adapter.actions==before,@"All-off survives a full queue and loading");
    NSDictionary *options=MTNormalizeOverlayOptions(@{@"liquidGlass":@NO});
#if MT_GLASS_ALWAYS_ON
    check([options[@"liquidGlass"] boolValue],@"Liquid Glass remains enabled for this module");
#else
    check(![options[@"liquidGlass"] boolValue],@"Glass-off survives option normalization");
#endif
    MTTrainerMaterial *material=[[MTTrainerMaterial alloc]initWithContentView:[NSView new] cornerRadius:12];material.liquidGlassEnabled=NO;check(!material.allowsLiquidGlass && material.materialMode!=MTTrainerMaterialLiquidGlass,@"Glass-off selects native fallback");
    material.liquidGlassEnabled=YES;[material refreshAppearance];
    puts("PASS: idempotent setters, loading, owner changes, network continuity, queue stop, numeric validation and glass fallback.");
}return 0;}
