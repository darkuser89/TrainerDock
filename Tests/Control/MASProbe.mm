// SPDX-License-Identifier: GPL-3.0-only
// Explicit session-scoped native checks. Never linked into any product module.
#import "ControlEngine.h"
extern "C" {
#import "MHTProtocol.h"
}
#include <dlfcn.h>
#include <set>
#include <atomic>
#include <cmath>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static NSString *token;
static NSDictionary *lastAction;
static uintptr_t component(uintptr_t owner,uintptr_t vt){uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t n=r<uint32_t>(owner+0x68);if(n<=128)for(uint32_t i=0;i<n;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c)==vt&&r<uintptr_t>(c+0x20)==owner)return c;}return 0;}
static uintptr_t avatar(){void *server=MHTControlServer();uintptr_t session=server?((uintptr_t(*)(void*))MHTControlAddress(MHTControlSession))(server):0;return session?((uintptr_t(*)(void*))MHTControlAddress(MHTControlAvatar))((void*)session):0;}
static uintptr_t resolve(uint64_t gid){uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE"),map=r<uintptr_t>(global);auto get=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");return map&&get?(uintptr_t)get((void*)map,&gid):0;}
static NSMutableArray *items(uintptr_t inv){NSMutableArray *out=[NSMutableArray new];uintptr_t list=r<uintptr_t>(inv+0x38);uint32_t n=r<uint32_t>(inv+0x40);if(n>4096)return out;for(uint32_t i=0;i<n;i++){uint64_t gid=r<uint64_t>(list+16*i);uintptr_t object=resolve(gid),stack=component(object,MHTControlAddress(MHTControlStackVT)),loot=component(object,MHTControlAddress(MHTControlLootVT));if(!loot)continue;
 [out addObject:@{@"gid":@(gid),@"stack":@(stack),@"amount":@(r<int>(stack+0x38)),@"template":@(r<uint64_t>(loot+0x38))}];}return out;}
static int team(uintptr_t a){uintptr_t vt=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZTVN6bonsai21FactionComponentStateE"),f=vt?component(a,vt+16):0;return f?r<int>(f+0x40):-1;}
static bool hostile(uintptr_t a,uint64_t gid){auto fn=(bool(*)(void*,const uint64_t*,int))dlsym(RTLD_DEFAULT,"_ZN6bonsai21TargetPickerComponent12isAggressiveERKN1r8GlobalIDEN7content7FactionE");int faction=team(a);return fn&&faction>=0&&faction<12&&fn(nullptr,&gid,faction);}
static void snapshot(){@autoreleasepool{
 NSMutableDictionary *s=[@{@"identity":@(MHTControlEngineIdentity()),@"nativeThread":@(MHTControlOnEngineFrame()),@"label":MHTControlBuildLabel()}mutableCopy];
 uintptr_t a=MHTControlOnEngineFrame()?avatar():0;s[@"avatar"]=@(a);s[@"owner"]=@(r<uint64_t>(a+0x10));
 if(a){uintptr_t h=component(a,MHTControlAddress(MHTControlHealthVT)),model=r<uintptr_t>(h+0x50),resource=component(a,MHTControlAddress(MHTControlResourceVT)),inv=component(a,MHTControlAddress(MHTControlInventoryVT)),player=component(a,MHTControlAddress(MHTControlPlayerVT)),move=component(a,MHTControlAddress(MHTControlMovementVT)),cfg=r<uintptr_t>(move+0x30);
  [s addEntriesFromDictionary:@{@"healthComponent":@(h),@"health":@(r<float>(model+0x94)),@"maximumHealth":@(r<int>(model+0xb8)),@"invulnerable":@(r<uint8_t>(model+0xbc)),@"energy":@(r<float>(resource+0x38)),@"energyUnlimited":@(r<uint8_t>(resource+0x139)),@"ammo":@(r<float>(inv+0x2b8)),@"ammoUnlimited":@(r<uint8_t>(inv+0x2ac)),@"money":@(r<uint64_t>(player+0x38)),@"skill":@(r<int>(player+0x40)),@"simulationRate":@(MHTControlSimulationRate()),@"movementConfiguration":@(cfg),@"movementLimits":@[@(r<float>(cfg+0x1c)),@(r<float>(cfg+0x3c)),@(r<float>(cfg+0x58)),@(r<float>(cfg+0x70)),@(r<float>(cfg+0xf8))],@"items":items(inv)}];
  struct P{float x,y,z;};auto pos=(P(*)(void*))dlsym(RTLD_DEFAULT,"_ZNK1r15GameObjectState11getPositionEv");if(pos){P p=pos((void*)a);s[@"position"]=@[@(p.x),@(p.y),@(p.z)];}
  uintptr_t db=r<uintptr_t>(MHTControlAddress(MHTControlDatabase)),recipes=r<uintptr_t>(db+0x628),ids=r<uintptr_t>(db+0x630);uint32_t n=r<uint32_t>(db+0x624);s[@"recipeCount"]=@(n);
  static uint64_t recipeID;static uintptr_t previousDB;if(previousDB!=db){previousDB=db;recipeID=0;}
  if(n&&n<=512&&recipes&&ids){if(!recipeID){for(uint32_t i=0;i<n;i++)if(r<int>(recipes+i*0x110+0x108)>(int64_t)r<uint64_t>(player+0x38)){recipeID=r<uint64_t>(ids+8*i);break;}if(!recipeID)recipeID=r<uint64_t>(ids);}
   struct Resource{uint64_t id;uintptr_t cached;uint32_t generation;uint8_t lock,padding[3];};Resource ref{recipeID,0,0,0,{}};
   uintptr_t query=MHTControlMainImage()+([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.remedygames.control-ue"]?0x58e868:0x4cc9f0);
   bool canQuery=![MHTControlBuildLabel() hasSuffix:@"1.371"];
   bool allowed=canQuery?((bool(*)(Resource*,void*))query)(&ref,nullptr):false;
   if(!canQuery)for(uint32_t i=0;i<n;i++)if(r<uint64_t>(ids+8*i)==recipeID){ref.cached=recipes+i*0x110;break;}
   s[@"recipe"] = @{@"id":@(recipeID),@"nativeQueryAvailable":@(canQuery),@"nativeAllowed":@(allowed),@"resolved":@(ref.cached),@"cost":@(r<int>(ref.cached+0x108)),@"ingredients":@(r<uint32_t>(ref.cached+0xe8))};
  }
  NSMutableArray *targets=[NSMutableArray new],*shields=[NSMutableArray new];std::set<uintptr_t> seen;uintptr_t node=a+0x38;for(unsigned i=0;node&&i<4096;i++){if(!seen.insert(node).second)break;uintptr_t object=node-0x38;node=r<uintptr_t>(node+0x10);if(object==a||r<uintptr_t>(object)!=r<uintptr_t>(a))continue;uint64_t gid=r<uint64_t>(object+0x10);uintptr_t body=component(object,MHTControlAddress(MHTControlHealthVT));if(!body||!hostile(a,gid))continue;uintptr_t bm=r<uintptr_t>(body+0x50),armor=component(object,MHTControlAddress(MHTControlArmorVT)),sm=r<uintptr_t>(armor+0x38);
   NSDictionary *target=@{@"gid":@(gid),@"body":@(r<float>(bm+0x94)),@"maximumBody":@(r<int>(bm+0xb8)),@"shield":@(r<float>(sm+0x94)),@"maximumShield":@(r<int>(sm+0xb8))};if(targets.count<40)[targets addObject:target];if(armor&&r<int>(sm+0xb8)>0&&shields.count<40)[shields addObject:target];}
  s[@"targets"]=targets;s[@"shields"]=shields;
 }
 s[@"lastAction"]=lastAction?:@{};MHTPost(@"local.mht.control.native-test.v1",@{@"version":@1,@"module":@"control",@"session":token,@"pid":@(getpid()),@"state":s});
}}
static void action(NSDictionary *q){
 if(!MHTControlOnEngineFrame()||!MHTControlEngineIdentity()||[q[@"deadline"]doubleValue]<=NSDate.date.timeIntervalSince1970)return;uintptr_t a=avatar();uint64_t owner=r<uint64_t>(a+0x10);if(!owner||owner!=[q[@"owner"]unsignedLongLongValue])return;
 NSString *kind=q[@"action"];NSMutableDictionary *out=[@{@"action":kind?:@"",@"request":q[@"request"]?:@""}mutableCopy];
 if([kind isEqual:@"addMoney"]){uintptr_t p=component(a,MHTControlAddress(MHTControlPlayerVT));uint64_t old=r<uint64_t>(p+0x38),next=old+10;if(p&&old<999999980){BOOL ok=MHTControlWrite(p+0x38,&next,8);out[@"before"]=@(old);out[@"accepted"]=@(ok?r<uint64_t>(p+0x38):old);}}
 else if([kind isEqual:@"consumeMaterial"]){uintptr_t inv=component(a,MHTControlAddress(MHTControlInventoryVT));uint64_t gid=[q[@"gid"]unsignedLongLongValue];for(NSDictionary *item in items(inv))if([item[@"gid"]unsignedLongLongValue]==gid&&[item[@"stack"]unsignedLongLongValue]){uintptr_t stack=[item[@"stack"]unsignedLongLongValue];int old=r<int>(stack+0x38),next=old-1;if(old>0){MHTControlWrite(stack+0x38,&next,4);out[@"before"]=@(old);out[@"accepted"]=@(r<int>(stack+0x38));}break;}}
 else if([kind isEqual:@"damageBody"]||[kind isEqual:@"damageShield"]){uint64_t gid=[q[@"gid"]unsignedLongLongValue];uintptr_t object=resolve(gid);if(object&&hostile(a,gid)){
  uintptr_t comp=component(object,MHTControlAddress([kind isEqual:@"damageBody"]?MHTControlHealthVT:MHTControlArmorVT)),model=r<uintptr_t>(comp+([kind isEqual:@"damageBody"]?0x50:0x38));float old=r<float>(model+0x94);int max=r<int>(model+0xb8);
  if(comp&&max>0&&max<100000000&&std::isfinite(old)&&old>.1f&&old<=1){((void(*)(void*,float,bool))MHTControlAddress(MHTControlHealthNormalized))((void*)model,old-.01f,false);out[@"gid"]=@(gid);out[@"before"]=@(old);out[@"accepted"]=@(r<float>(model+0x94));}
 }}
 lastAction=out;snapshot();
}
__attribute__((constructor))static void start(){dispatch_async(dispatch_get_main_queue(),^{token=[NSProcessInfo.processInfo.environment[@"MHT_SESSION"]copy];if(!token.length)return;NSMutableOrderedSet *seen=[NSMutableOrderedSet new];
 [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.mht.control.native-test.command.v1" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){NSDictionary *q=MHTDecodeMessage(event.object);if(!MHTAcceptCommand(q,@"control",token,getpid(),seen,NSDate.date.timeIntervalSince1970))return;MHTControlSchedule(^{action(q);});}];
 static std::atomic<bool> pending{false};[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){(void)timer;if(pending.exchange(true))return;MHTControlSchedule(^{snapshot();pending=false;});}];
});}
