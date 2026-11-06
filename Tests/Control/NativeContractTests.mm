// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "NativeAdapter.h"
#import "GameBridge.h"
#import "ControlEngine.h"
#include <stdint.h>
// Synthetic context/queue fixture: never linked into the product runtime.
@interface ControlBridgeFixture : NSObject <MTGameAdapter>
@property(nonatomic) NSUInteger owner,actions;
@end
@implementation ControlBridgeFixture
- (instancetype)init{if((self=[super init]))_owner=1;return self;}
- (void)onGameThread:(dispatch_block_t)work{dispatch_async(dispatch_get_main_queue(),work);}
- (MTGameContext *)captureContext{MTGameContext *c=[MTGameContext new];c.kind=MTSessionSolo;c.identity=[NSString stringWithFormat:@"owner-%lu",(unsigned long)_owner];return c;}
- (void)releaseEffects{}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value{(void)feature;MTFeatureState *s=[MTFeatureState new];s.available=YES;s.wanted=wanted;s.active=wanted;s.value=value;return s;}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value{(void)feature;(void)value;_actions++;return @"fixture";}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return wanted;}
@end
static void settle(){NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:.08];while(limit.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.002]];}
int main(void){@autoreleasepool{
 NSCAssert(!MHTControlEngineIdentity(),@"A test executable must never impersonate Control");
 for(NSUInteger i=0;i<=MHTControlSymbolCount;i++)NSCAssert(!MHTControlAddress((MHTControlSymbol)i),@"No native address without complete store identity");
 NSCAssert(!MHTControlOnEngineFrame()&&!MHTControlServer(),@"No fabricated gameplay thread/context");
 NSCAssert(MTFeatureCount==12,@"Stable requested feature identifiers");
 NSCAssert(MTFeatureInfoAt(MTFeatureMaterials)->implemented,@"Real owned material stacks confirmed before/refill/restore");
 NSCAssert(MTFeatureInfoAt(MTFeatureShield)->implemented&&MTFeatureInfoAt(MTFeatureOneHit)->implemented,@"Confirmed native hostile health models");
 NSCAssert(MTFeatureInfoAt(MTFeatureCrafting)->implemented,@"Native recipe validation confirmed before/after/restore");
 NSCAssert(MTFeatureInfoAt(MTFeatureMoney)->oneShot&&MTFeatureInfoAt(MTFeatureSkillPoints)->oneShot,@"Explicit non-repeating actions");
 uint64_t actual=9,copy=0,value=17;
 NSCAssert(MHTControlRead((uintptr_t)&actual,&copy,8)&&copy==9,@"Readable local data");
 NSCAssert(MHTControlWrite((uintptr_t)&actual,&value,8)&&actual==17,@"Writable non-executable data");
 NSCAssert(!MHTControlWrite(0,&value,8)&&!MHTControlWrite(UINTPTR_MAX-3,&value,8)&&!MHTControlWrite((uintptr_t)&actual,&value,0),@"Invalid ranges must not write");
 NSCAssert(!MHTControlWrite((uintptr_t)&main,&value,4),@"Executable pages must remain untouched");
 MHTNativeAdapter *adapter=[MHTNativeAdapter new];
 NSCAssert([adapter captureContext].kind==MTSessionUnsupported,@"Wrong process rejected");
 for(NSInteger i=0;i<MTFeatureCount;i++){MTFeatureState *f=[adapter applyFeature:(MTFeature)i wanted:YES value:MTFeatureInfoAt((MTFeature)i)->initial];NSCAssert(!f.active&&!f.available,@"No effects without native identity/owner");}
 __block BOOL completed=NO;
 [adapter onGameThread:^{NSCAssert(!MHTControlOnEngineFrame(),@"Unsupported completion must not pretend to be gameplay delivery");completed=YES;}];
 NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:1];while(!completed&&limit.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
 NSCAssert(completed,@"Unsupported poll must complete without freezing the host");
 ControlBridgeFixture *fixture=[ControlBridgeFixture new];MTGameBridge *bridge=[[MTGameBridge alloc]initWithAdapter:fixture];
 [bridge restoreSelection:@{@"features":@{@"0":@{@"wanted":@YES},@"3":@{@"wanted":@YES}}}];[bridge poll];settle();
 NSCAssert(bridge.state.features[MTFeatureHealth].active&&fixture.actions==0,@"Initial selection resumes genuine switches, never one-shots");
 [bridge setWanted:YES forFeature:MTFeatureHealth];[bridge setWanted:YES forFeature:MTFeatureHealth];settle();
 NSCAssert(bridge.state.features[MTFeatureHealth].active,@"Set-on is idempotent");
 [bridge performFeature:MTFeatureMoney];fixture.owner++;settle();
 NSCAssert(fixture.actions==0&&!bridge.state.features[MTFeatureHealth].wanted,@"New owners discard stale actions and continuous requests");
 [bridge setWanted:YES forFeature:MTFeatureHealth];settle();[bridge poll];for(int i=0;i<24;i++)[bridge performFeature:MTFeatureMoney];[bridge performAction:MTTrainerDisableAll];settle();
 NSCAssert(!bridge.state.features[MTFeatureHealth].wanted&&fixture.actions==0,@"Stop takes priority over a full action queue");
 puts("Control identity/thread/data-protection/catalog checks passed");
}return 0;}
