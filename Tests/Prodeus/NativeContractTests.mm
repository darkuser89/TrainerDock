// SPDX-License-Identifier: GPL-3.0-only
// Exercises product identity/resolvers and bridge boundaries without a game.
#include "ProdeusEngine.hpp"
#import "ProdeusLoop.h"
extern "C" {
#import "GameBridge.h"
#import "SelectionSettings.h"
}
#include <mach-o/loader.h>
#include <cstring>
#include <cstdio>
#include <cstdlib>
using namespace prodeus;
static void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
@interface PRContractAdapter : NSObject <MTGameAdapter>
@property(nonatomic) NSMutableArray<dispatch_block_t> *pending;
@property(nonatomic) MTSessionKind mode;
@property(nonatomic,copy) NSString *owner;
@property(nonatomic) NSUInteger shots,releases,applications,activeEffects;
@end
@implementation PRContractAdapter
- (instancetype)init {if((self=[super init])){_pending=[NSMutableArray new];_owner=@"owner-A";_mode=MTSessionSolo;}return self;}
- (void)onGameThread:(dispatch_block_t)work {[_pending addObject:[work copy]];}
- (MTGameContext *)captureContext {MTGameContext *c=[MTGameContext new];c.kind=_mode;c.identity=_owner;c.note=@"Synthetische Sitzung";return c;}
- (void)releaseEffects {_releases++;_activeEffects=0;}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {(void)feature;(void)value;_applications++;if(wanted)_activeEffects++;MTFeatureState *s=[MTFeatureState new];s.available=YES;s.active=wanted;return s;}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {(void)feature;(void)value;_shots++;return @"Einmalaktion bestätigt";}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return wanted;}
@end
static void flush(PRContractAdapter *adapter){
 for(unsigned n=0;n<40;n++){
  if(adapter.pending.count){dispatch_block_t work=adapter.pending.firstObject;[adapter.pending removeObjectAtIndex:0];work();}
  [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.002]];
 }
 check(adapter.pending.count==0,"all scoped bridge work settles");
}
static void bridgeChecks(){
 check(MTFeatureCount==13,"the requested thirteen functions have stable catalog IDs");
 NSUInteger shots=0;for(NSInteger i=0;i<MTFeatureCount;i++){const MTFeatureInfo *info=MTFeatureInfoAt((MTFeature)i);check(info&&info->implemented,"every offered function is implemented");shots+=info->oneShot;}
 check(shots==7,"keys and permanent movement/map grants are explicit one-shot actions");
 PRContractAdapter *adapter=[PRContractAdapter new];MTGameBridge *bridge=[[MTGameBridge alloc]initWithAdapter:adapter];
 [bridge poll];flush(adapter);check(bridge.state.ready&&bridge.state.sessionKind==MTSessionSolo,"a confirmed local singleplayer context enables commands");
 [bridge setWanted:YES forFeature:MTFeatureHealth];flush(adapter);check(bridge.state.features[MTFeatureHealth].active,"activation follows adapter readback");
 NSUInteger applies=adapter.applications,releases=adapter.releases;
 [bridge performFeature:MTFeatureRedKey];adapter.mode=MTSessionNetwork;flush(adapter);
 check(!bridge.state.ready&&adapter.shots==0&&adapter.applications==applies,"a queued one-shot cannot cross into multiplayer or apply another effect");
 check(adapter.releases>releases&&adapter.activeEffects==0&&!bridge.state.features[MTFeatureHealth].wanted,"entering multiplayer releases effects and clears activation wishes");
 [bridge setWanted:YES forFeature:MTFeatureArmor];[bridge performFeature:MTFeatureGreenKey];flush(adapter);
 check(adapter.shots==0&&adapter.applications==applies,"multiplayer rejects both new toggles and explicit grants");
 [bridge setOverlayInteraction:YES];flush(adapter);check(bridge.state.overlayMouseActive,"cursor controls remain independent of gameplay authorization");
 adapter.mode=MTSessionLoading;adapter.owner=@"loading";[bridge poll];flush(adapter);check(!bridge.state.ready&&adapter.shots==0,"loading never becomes a gameplay context");
 adapter.mode=MTSessionSolo;adapter.owner=@"owner-B";[bridge poll];flush(adapter);
 check(bridge.state.ready&&!bridge.state.features[MTFeatureHealth].active,"new solo owner starts without old active effects");
 [bridge performFeature:MTFeatureRedKey];flush(adapter);check(adapter.shots==1,"fresh singleplayer grant executes once");
 [bridge poll];[bridge poll];flush(adapter);check(adapter.shots==1,"context polls never repeat a one-shot");
 [bridge performFeature:MTFeatureBlueKey];adapter.owner=@"owner-C";flush(adapter);check(adapter.shots==1,"an already queued grant is discarded after player ownership changes");
 [bridge setWanted:YES forFeature:MTFeatureArmor];flush(adapter);[bridge performAction:MTTrainerDisableAll];flush(adapter);
 check(adapter.activeEffects==0&&!bridge.state.features[MTFeatureArmor].wanted,"all-off releases owned effects and activation wishes");
}
static void identityChecks(){
 uint8_t main[16]={0xde,0xf4,0xdd,0x2f,0x81,0x42,0x39,0xd2,0x8b,0xd8,0xbe,0xb6,0x4b,0xac,0xc7,0x20};
 uint8_t game[16]={0x5f,0xfa,0xe0,0xa3,0x1b,0x5d,0x3b,0xcb,0x86,0x7c,0x26,0xb8,0x65,0x33,0x56,0x3d};
 uint8_t unity[16]={0xa4,0x9a,0x37,0x98,0x54,0xd7,0x3b,0x95,0x87,0x1d,0xc6,0x36,0xe6,0x92,0x9c,0x03};
 check(runtimeImagesMatch("steam-arm64-1.0.2",main,game,unity),"only the inspected three-image arm64 tuple is supported");
 check(!runtimeImagesMatch("steam-arm64-1.0.3",main,game,unity)&&!runtimeImagesMatch(nullptr,main,game,unity),"unknown or missing profiles never inherit native bindings");
 for(uint8_t *image:{main,game,unity}){image[15]^=1;check(!runtimeImagesMatch("steam-arm64-1.0.2",main,game,unity),"each image UUID is required independently");image[15]^=1;}
 check(runtimeMainImageMatches(MH_EXECUTE,"/Games/Prodeus.app/Contents/MacOS/Prodeus","/Games/Prodeus.app/Contents/MacOS/Prodeus"),"exact executable path is accepted");
 check(!runtimeMainImageMatches(MH_DYLIB,"/Games/Prodeus","/Games/Prodeus")&&!runtimeMainImageMatches(MH_EXECUTE,"/Other/Prodeus","/Games/Prodeus")&&!runtimeMainImageMatches(MH_EXECUTE,"Prodeus","Prodeus"),"libraries, another installation and relative paths are rejected");
 check(!PRInFrame()&&!PREnsureLoop(),"unrelated test process never supplies a game thread or Unity binding");
}
static void metadataChecks(){
 static unsigned classQueries,methodQueries,fieldQueries;static bool loaded=true,duplicate=false;
 api.domainGet=[](){return (void *)1;};
 api.assemblies=[](void *,size_t *n)->const void **{static const void *a[]={(void *)2};*n=1;return a;};
 api.assemblyImage=[](const void *){return (void *)3;};api.imageName=[](void *){return "Original.dll";};
 api.classFromName=[](void *,const char *,const char *)->prodeus::Class{classQueries++;return loaded?(void *)4:nullptr;};
 api.parent=[](prodeus::Class)->prodeus::Class{return nullptr;};
 api.methods=[](prodeus::Class,void **iterator)->Method{methodQueries++;uintptr_t n=(uintptr_t)*iterator;*iterator=(void *)(n+1);return n<(duplicate?2u:1u)?(void *)(8+n):nullptr;};
 api.methodName=[](Method){return "Run";};api.parameterCount=[](Method){return 0u;};
 api.findField=[](prodeus::Class,const char *)->Field{fieldQueries++;return loaded?(void *)12:nullptr;};
 for(unsigned n=0;n<20000;n++){check(klass("Original.dll","Native","Player")== (void *)4,"native class identity is preserved");check(method((void *)4,"Run",0)==(void *)8,"native method identity is preserved");check(field((void *)4,"value")== (void *)12,"native field identity is preserved");}
 check(classQueries==1&&methodQueries==2&&fieldQueries==1,"20,000 unchanged metadata lookups only resolve each immutable descriptor once");
 loaded=false;check(!klass("Original.dll","Native","Late")&&!field((void *)4,"late"),"late-loaded metadata can be missing");loaded=true;
 check(klass("Original.dll","Native","Late")&&field((void *)4,"late"),"missing metadata is retried instead of permanently cached");
 api.domainGet=[](){return (void *)20;};duplicate=true;bool rejected=false;try{method((void *)4,"Run",0);}catch(const std::runtime_error&){rejected=true;}
 check(rejected,"a new domain invalidates cached methods and rejects ambiguous overloads");
 duplicate=false;check(method((void *)4,"Run",0)==(void *)8,"a failed overload lookup is retried");
 api={};
}
int main(){@autoreleasepool{identityChecks();metadataChecks();bridgeChecks();puts("PASS: Prodeus exact native identity, metadata call counts/domain rebinding, singleplayer-only bridge, loading/owner transition, exactly-once grants and all-off. Synthetic tests; no game launched.");}return 0;}
