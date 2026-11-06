// SPDX-License-Identifier: GPL-3.0-only
// Live native tests on real hostile objects; no fixtures or product linkage.
#import "ControlEngine.h"
#import "ControlCombat.h"
#import "ControlShield.h"
#import "ControlInventory.h"
#include <dlfcn.h>
#include <set>
extern void MTControlDiagnosticFrame(void);
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static uintptr_t component(uintptr_t owner,uintptr_t vt){uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t n=r<uint32_t>(owner+0x68);if(n<=128)for(uint32_t i=0;i<n;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c)==vt&&r<uintptr_t>(c+0x20)==owner)return c;}return 0;}
static MHTControlCombat combat;
static MHTControlShield shields;
static MHTControlInventory inventory;
static MHTControlCombatResult bodyState;
static MHTControlShieldResult shieldState;
static MHTControlInventoryResult itemState;
static uintptr_t owner;
static BOOL bodyEnabled,shieldEnabled,materialEnabled;
static void tick(){
 uintptr_t core=MHTControlCoreImage(),main=MHTControlMainImage();void *server=MHTControlServer();
 uintptr_t session=server?((uintptr_t(*)(void*))(core+0x19c478))(server):0,avatar=session?((uintptr_t(*)(void*))(core+0x2c0c10))((void*)session):0;
 if(owner!=avatar){combat.reset();shields.reset();inventory.discardOwner();owner=avatar;}
 bodyState=combat.update(avatar,bodyEnabled);shieldState=shields.update(avatar,shieldEnabled);
 itemState=inventory.update(avatar,component(avatar,main+0xe0a6e0),materialEnabled,false);
 MTControlDiagnosticFrame();
}
extern "C" NSDictionary *MHTControlNativeDiagnostic(uintptr_t core,uintptr_t main,void *server,uintptr_t avatar){
 (void)core;(void)server;static BOOL installed;if(!installed){installed=YES;MHTControlSetTestObserver(^{tick();});}
 NSDictionary *q=[NSDictionary dictionaryWithContentsOfFile:@"/private/tmp/mht-control/CombatRequest.plist"];
 bodyEnabled=[q[@"oneHit"]boolValue];shieldEnabled=[q[@"shield"]boolValue];materialEnabled=[q[@"materials"]boolValue];
 auto hostile=(bool(*)(void*,const uint64_t*,int))dlsym(RTLD_DEFAULT,"_ZN6bonsai21TargetPickerComponent12isAggressiveERKN1r8GlobalIDEN7content7FactionE");
 uintptr_t fv=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZTVN6bonsai21FactionComponentStateE")+16;int team=r<int>(component(avatar,fv)+0x40);
 uintptr_t shieldModel=0,bodyModel=0;uint64_t shieldID=0,bodyID=0;float shieldBody=0;
 NSMutableArray *live=[NSMutableArray new];std::set<uintptr_t> seen;uintptr_t node=avatar?avatar+0x38:0;
 for(unsigned i=0;node&&i<4096;i++){
  if(!seen.insert(node).second)break;uintptr_t object=node-0x38;node=r<uintptr_t>(node+0x10);
  if(object==avatar||r<uintptr_t>(object)!=r<uintptr_t>(avatar))continue;
  uintptr_t health=component(object,main+0xe094a8),body=r<uintptr_t>(health+0x50),armor=component(object,main+0xdd73e8),shield=r<uintptr_t>(armor+0x38);uint64_t gid=r<uint64_t>(object+0x10);
  if(!health||!armor||!hostile||team<0||team>=12||!hostile(nullptr,&gid,team))continue;
  float b=r<float>(body+0x94),s=r<float>(shield+0x94);int maximum=r<int>(shield+0xb8);
  [live addObject:@{@"gid":@(gid),@"body":@(b),@"shield":@(s),@"shieldMaximum":@(maximum)}];
  if(!shieldModel&&maximum>0&&b==1&&s==1){shieldModel=shield;shieldID=gid;shieldBody=b;}
  if(!bodyModel&&maximum==0&&b==1&&r<int>(body+0xb8)>0){bodyModel=body;bodyID=gid;}
 }
 static NSDictionary *shieldProof,*bodyProof;
 if(!shieldProof&&[q[@"probeShield"]boolValue]&&shieldState.targets>=2&&shieldModel){
  ((void(*)(void*,float,bool))(main+0x605be8))((void*)shieldModel,.9f,false);float accepted=r<float>(shieldModel+0x94);
  auto result=shields.update(avatar,true);
  shieldProof=@{@"gid":@(shieldID),@"before":@1,@"nativeAcceptedDamage":@(accepted),@"afterTrainer":@(r<float>(shieldModel+0x94)),@"bodyBefore":@(shieldBody),@"confirmed":@(result.confirmed)};
 }
 if(!bodyProof&&[q[@"probeBody"]boolValue]&&bodyState.targets>0&&bodyModel){
  ((void(*)(void*,float,bool))(main+0x605be8))((void*)bodyModel,.99f,false);float accepted=r<float>(bodyModel+0x94);
  auto result=combat.update(avatar,true);
  bodyProof=@{@"gid":@(bodyID),@"before":@1,@"nativeAcceptedDamage":@(accepted),@"afterTrainer":@(r<float>(bodyModel+0x94)),@"confirmed":@(result.confirmed)};
 }
 return @{@"oneHitTargets":@(bodyState.targets),@"oneHitConfirmed":@(bodyState.confirmed),@"shieldTargets":@(shieldState.targets),@"shieldConfirmed":@(shieldState.confirmed),@"materials":@(itemState.materialCount),@"materialsActive":@(itemState.materialsActive),@"shieldProof":shieldProof?:@{},@"bodyProof":bodyProof?:@{},@"live":live};
}
