// SPDX-License-Identifier: GPL-3.0-only
// Real product identity and bridge boundary tests; no game is started.
#include "HouseFlipperMono.hpp"
#import "HouseFlipperLoop.h"
extern "C" {
#import "GameBridge.h"
#import "SelectionSettings.h"
}
#include <mach-o/loader.h>
#include <cstdio>
#include <cstdlib>
static void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
@interface HFContractAdapter : NSObject <MTGameAdapter>
@property(nonatomic) NSMutableArray<dispatch_block_t> *pending;
@property(nonatomic) MTSessionKind mode;
@property(nonatomic,copy) NSString *owner;
@property(nonatomic) NSUInteger releases,applications,shots;
@property(nonatomic) BOOL active;
@end
@implementation HFContractAdapter
- (instancetype)init {if((self=[super init])){_pending=[NSMutableArray new];_owner=@"owner-A";_mode=MTSessionSolo;}return self;}
- (void)onGameThread:(dispatch_block_t)work {[_pending addObject:[work copy]];}
- (MTGameContext *)captureContext {MTGameContext *c=[MTGameContext new];c.kind=_mode;c.identity=_owner;c.note=@"Synthetischer Originalkontext";return c;}
- (void)releaseEffects {_releases++;_active=NO;}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {(void)feature;(void)value;_applications++;_active|=wanted;MTFeatureState *state=[MTFeatureState new];state.available=YES;state.active=wanted;return state;}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {(void)feature;(void)value;_shots++;return @"Keine Einmalaktion angeboten";}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return wanted;}
@end
static void flush(HFContractAdapter *adapter){
 for(unsigned n=0;n<40;n++){
  if(adapter.pending.count){dispatch_block_t work=adapter.pending.firstObject;[adapter.pending removeObjectAtIndex:0];work();}
  [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];
 }
 check(adapter.pending.count==0,"scoped bridge work settles");
}
static void bridgeChecks(){
 check(MTFeatureCount==2,"two stable native functions are offered");
 for(NSInteger i=0;i<MTFeatureCount;i++){const MTFeatureInfo *info=MTFeatureInfoAt((MTFeature)i);check(info&&info->implemented&&!info->oneShot,"both options are implemented continuous effects");}
 HFContractAdapter *adapter=[HFContractAdapter new];MTGameBridge *bridge=[[MTGameBridge alloc]initWithAdapter:adapter];
 [bridge poll];flush(adapter);check(bridge.state.ready,"local original context enables the trainer");
 [bridge setWanted:YES forFeature:MTFeaturePerkPoints];flush(adapter);
 check(bridge.state.features[MTFeaturePerkPoints].active&&!bridge.state.features[MTFeatureMoney].wanted,"perk points work directly without a master or money switch");
 [bridge setWanted:YES forFeature:MTFeaturePerkPoints];flush(adapter);check(bridge.state.features[MTFeaturePerkPoints].wanted,"repeated set does not invert an enabled option");
 NSUInteger released=adapter.releases;adapter.mode=MTSessionLoading;[bridge poll];flush(adapter);
 check(!bridge.state.ready&&bridge.state.features[MTFeaturePerkPoints].wanted&&!bridge.state.features[MTFeaturePerkPoints].active&&adapter.releases>released,"loading releases actual effects while preserving the requested selection");
 adapter.mode=MTSessionSolo;adapter.owner=@"owner-B";[bridge poll];flush(adapter);check(bridge.state.features[MTFeaturePerkPoints].active,"continuous choice resumes only after a new valid owner is read");
 [bridge setWanted:YES forFeature:MTFeatureMoney];adapter.owner=@"owner-C";flush(adapter);
 check(!bridge.state.features[MTFeatureMoney].wanted,"a queued activation cannot cross an ownership change");
 adapter.mode=MTSessionNetwork;[bridge poll];flush(adapter);
 check(bridge.state.ready&&bridge.state.features[MTFeaturePerkPoints].active,"internet/network labels do not create a forbidden blanket network lock");
 [bridge poll];for(unsigned n=0;n<24;n++)[bridge setWanted:YES forFeature:MTFeatureMoney];
 [bridge performAction:MTTrainerDisableAll];adapter.mode=MTSessionLoading;flush(adapter);
 for(MTFeatureState *feature in bridge.state.features)check(!feature.wanted&&!feature.active,"all-off survives a full queue and loading");
 check(!adapter.active&&adapter.shots==0,"all-off releases the fixture and polling never invents one-shots");
 [bridge setOverlayInteraction:YES];flush(adapter);check(bridge.state.overlayMouseActive,"mouse controls remain independent of a loading gameplay context");
 NSDictionary *normalized=MTNormalizeCheatSelection(@{@"features":@{@"0":@{@"wanted":@YES,@"value":@0},@"1":@{@"wanted":@YES,@"value":@0},@"99":@{@"wanted":@YES}}});
 check([normalized[@"features"] count]==2,"selection normalization admits only this module's stable feature IDs");
}
static void identityChecks(){
 uint8_t main[16]={0x6d,0x82,0xba,0x8c,0x38,0xa6,0x3a,0x10,0x8c,0xde,0xbd,0xd3,0x68,0xb8,0xf4,0xcf};
 uint8_t unity[16]={0xb4,0xf0,0xac,0x68,0x1a,0xb0,0x3b,0x92,0x8c,0x74,0xe3,0x10,0x5b,0x2d,0x53,0xc0};
 uint8_t mono[16]={0xe7,0x42,0x0b,0xc7,0xa2,0x6b,0x33,0xfa,0xb5,0xcd,0x41,0xca,0xd7,0xd4,0x61,0x4c};
 check(hf::runtimeImagesMatch("steam-x86_64-25247477",main,unity,mono),"only the inspected Intel image tuple is supported");
 check(!hf::runtimeImagesMatch("steam-x86_64-other",main,unity,mono)&&!hf::runtimeImagesMatch(nullptr,main,unity,mono),"unknown profiles cannot inherit a native binding");
 for(uint8_t *image:{main,unity,mono}){image[15]^=1;check(!hf::runtimeImagesMatch("steam-x86_64-25247477",main,unity,mono),"each executable/Unity/Mono image UUID is required independently");image[15]^=1;}
 check(hf::runtimeMainImageMatches(MH_EXECUTE,"/Games/HouseFlipper.app/Contents/MacOS/House Flipper Game","/Games/HouseFlipper.app/Contents/MacOS/House Flipper Game"),"exact executable path is accepted");
 check(!hf::runtimeMainImageMatches(MH_DYLIB,"/Games/Game","/Games/Game")&&!hf::runtimeMainImageMatches(MH_EXECUTE,"/Other/Game","/Games/Game")&&!hf::runtimeMainImageMatches(MH_EXECUTE,"Game","Game"),"libraries, other installations and relative paths are rejected");
 check(!HFInFrame()&&!HFSupportedImages(),"an unrelated synthetic process is never treated as the original game");
}
int main(){@autoreleasepool{identityChecks();bridgeChecks();puts("PASS: House Flipper exact Intel identity, independent toggles, loading/owner transitions, queue cancellation, network continuity and selection boundaries. Synthetic tests; no game launched.");}return 0;}
