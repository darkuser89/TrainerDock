// SPDX-License-Identifier: GPL-3.0-only
// Exercises the real, currently gated material/shield implementations in the
// explicitly authorized Control test process. Never linked into the product.
#import "ControlEngine.h"
#import "ControlInventory.h"
#import "ControlShield.h"
#include <dlfcn.h>
#include <set>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static uintptr_t component(uintptr_t owner,uintptr_t vt){uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t n=r<uint32_t>(owner+0x68);if(n<=128)for(uint32_t i=0;i<n;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c)==vt&&r<uintptr_t>(c+0x20)==owner)return c;}return 0;}
extern "C" NSDictionary *MHTControlNativeDiagnostic(uintptr_t core,uintptr_t main,void *server,uintptr_t avatar){
 (void)core;(void)server;if(!avatar||!MHTControlOnEngineFrame())return @{};
 static MHTControlInventory inventory;static MHTControlShield shields;static uintptr_t owner;
 if(owner!=avatar){inventory.discardOwner();shields.reset();owner=avatar;}
 NSDictionary *request=[NSDictionary dictionaryWithContentsOfFile:@"/private/tmp/mht-control/RemainingRequest.plist"];
 BOOL materials=[request[@"materials"]isKindOfClass:NSNumber.class]&&[request[@"materials"]boolValue];
 BOOL shield=[request[@"shield"]isKindOfClass:NSNumber.class]&&[request[@"shield"]boolValue];
 auto items=inventory.update(avatar,component(avatar,main+0xe0a6e0),materials,false);
 auto state=shields.update(avatar,shield);
 auto aggressive=(bool(*)(void*,const uint64_t*,int))dlsym(RTLD_DEFAULT,"_ZN6bonsai21TargetPickerComponent12isAggressiveERKN1r8GlobalIDEN7content7FactionE");
 uintptr_t fv=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZTVN6bonsai21FactionComponentStateE")+16;
 int faction=r<int>(component(avatar,fv)+0x40);NSMutableArray *targets=[NSMutableArray new];std::set<uintptr_t> seen;
 uintptr_t node=avatar+0x38;for(unsigned i=0;node&&i<4096;i++){
  if(!seen.insert(node).second)break;uintptr_t object=node-0x38;node=r<uintptr_t>(node+0x10);
  if(object==avatar||r<uintptr_t>(object)!=r<uintptr_t>(avatar))continue;
  uintptr_t armor=component(object,main+0xdd73e8),model=r<uintptr_t>(armor+0x38),health=component(object,main+0xe094a8);
  if(!armor||!health)continue;uint64_t gid=r<uint64_t>(object+0x10);
  BOOL hostile=aggressive&&aggressive(nullptr,&gid,faction);
  if(hostile||r<int>(model+0xb8)>0)[targets addObject:@{@"gid":@(gid),@"hostile":@(hostile),@"shieldMax":@(r<int>(model+0xb8)),@"shield":@(r<float>(model+0x94)),@"body":@(r<float>(r<uintptr_t>(health+0x50)+0x94))}];
 }
 return @{@"materialsEnabled":@(materials),@"materialCount":@(items.materialCount),@"materialsActive":@(items.materialsActive),@"shieldEnabled":@(shield),@"shieldTargets":@(state.targets),@"shieldConfirmed":@(state.confirmed),@"targets":targets};
}
