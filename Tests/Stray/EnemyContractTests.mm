// SPDX-License-Identifier: GPL-3.0-only
// Synthetic engine boundary only; never linked into any trainer product.
#import "EnemyEffects.hpp"
#import "EnemyBindings.h"
#import "PlayerEffects.hpp"
#include <cstdlib>
#include <cstring>
#include <map>
#include <vector>
using st::Object;
namespace {
struct Actor {int index=0,serial=1;Object kind{},world{},cat{},target{};bool alive=true,see=true,hear=true,aggressive=true,vision=true;};
std::map<uintptr_t,Actor> fixtures;
std::map<void *,size_t> buffers;
Object leaderClass{0x1000},sentinelClass{0x2000},worldA{0x3000},worldB{0x4000},catA{0x5000},catB{0x6000};
st::PlayerContext context;
bool gameThread=true,badSignature=false,badLayout=false,rejectSet=false;
NSUInteger sets=0,enumerations=0,contextReads=0;
void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
Actor &row(Object object){auto it=fixtures.find(object.address);if(it==fixtures.end()||!it->second.alive)throw std::runtime_error("Expired fixture object");return it->second;}
Object create(uintptr_t address,Object kind={},Object world={},Object cat={},Object target={}){Actor a;a.index=(int)address;a.kind=kind;a.world=world;a.cat=cat;a.target=target;fixtures[address]=a;return {address};}
void *leader(){return (void *)leaderClass.address;}
void *sentinel(){return (void *)sentinelClass.address;}
void *actorWorld(void *object){return (void *)row({(uintptr_t)object}).world.address;}
struct Array {uintptr_t *data;int32_t count,capacity;};
void collect(const void *,void *cls,Array *out){
 enumerations++;std::vector<uintptr_t> found;
 for(auto &[address,a]:fixtures)if(a.alive&&a.kind.address==(uintptr_t)cls)found.push_back(address);
 out->count=out->capacity=(int32_t)found.size();out->data=(uintptr_t *)malloc(found.size()*8);buffers[out->data]=found.size()*8;
 if(found.size())memcpy(out->data,found.data(),found.size()*8);
}
void freeBuffer(void *p){check(buffers.erase(p)==1,"Only original fixture array allocations are released");free(p);}
}
namespace st {
bool isGameThread(){return gameThread;}
PlayerContext playerContext(){contextReads++;return context;}
Weak::Weak(Object o){if(o){auto &r=row(o);index=r.index;serial=r.serial;}}
Object Weak::get()const{auto it=fixtures.find((uintptr_t)index);return it!=fixtures.end()&&it->second.alive&&it->second.serial==serial?Object{(uintptr_t)index}:Object{};}
Object object(int32_t index){Object o{(uintptr_t)index};row(o);return o;}
NSString *name(Object o){if(o==leaderClass)return @"ZurgPawnLeader";if(o==sentinelClass)return @"Sentinel";return @"Fixture";}
bool isA(Object o,Object cls){return row(o).kind==cls;}
uintptr_t binding(const char *key){
 if(!strcmp(key,"processEvent"))return 0x1015f656cULL;
 if(!strcmp(key,"actorWorld"))return (uintptr_t)actorWorld;
 if(!strcmp(key,"enemyLeaderClass"))return (uintptr_t)leader;
 if(!strcmp(key,"enemySentinelClass"))return (uintptr_t)sentinel;
 if(!strcmp(key,"enemyAllActors"))return (uintptr_t)collect;
 if(!strcmp(key,"enemyFree"))return (uintptr_t)freeBuffer;
 return 0;
}
bool read(uintptr_t at,void *out,size_t n){
 for(auto f:{enemy::CanSwarmSee,enemy::SetSwarmCanSee,enemy::CanSwarmHearSound,enemy::SetSwarmCanHearSound,enemy::SetAggressive,enemy::SetVisonLightEnabled})
  if(at==f.address&&n==f.size){memcpy(out,f.bytes,n);if(badSignature)((uint8_t *)out)[0]^=1;return true;}
 for(auto [p,size]:buffers){auto address=(uintptr_t)p;if(at>=address&&at-address<=size&&n<=size-(at-address)){memcpy(out,(void *)at,n);return true;}}
 return false;
}
Property property(Object,NSString *name){Property p;p.name=name;p.type=@"ObjectProperty";p.count=1;p.size=8;
 if([name isEqual:@"m_cachedPlayerCatPawn"])p.offset=(int32_t)enemy::LeaderCachedCat+(badLayout?1:0);
 else if([name isEqual:@"m_lockedTargetActor"])p.offset=(int32_t)enemy::SentinelLockedTarget;
 else throw std::runtime_error("Unexpected fixture field");return p;
}
id readValue(Object o,const Property &p){Object target=[p.name isEqual:@"m_cachedPlayerCatPawn"]?row(o).cat:row(o).target;return target?@{@"object":@(target.address)}:NSNull.null;}
id invoke(Object o,NSString *method,NSDictionary *args){
 auto &r=row(o);
 if([method isEqual:@"CanSwarmSee"])return @(r.see);
 if([method isEqual:@"CanSwarmHearSound"])return @(r.hear);
 if([method isEqual:@"IsAggressive"])return @(r.aggressive);
 if([method isEqual:@"GetVisionLightEnabled"])return @(r.vision);
 sets++;
 if([method isEqual:@"SetSwarmCanSee"]){check(args.count==1&&args[@"_canSee"],"Original sight argument schema");if(!rejectSet)r.see=[args[@"_canSee"] boolValue];}
 else if([method isEqual:@"SetSwarmCanHearSound"]){check(args.count==1&&args[@"_canHearSound"],"Original hearing argument schema");if(!rejectSet)r.hear=[args[@"_canHearSound"] boolValue];}
 else if([method isEqual:@"SetVisonLightEnabled"]){check(args.count==1&&args[@"_enable"],"Original vision-gate argument schema");if(!rejectSet)r.vision=[args[@"_enable"] boolValue];}
 else if([method isEqual:@"SetAggressive"]){check(args.count==1&&args[@"_isAggressive"],"Original aggression argument schema");if(!rejectSet)r.aggressive=[args[@"_isAggressive"] boolValue];}
 else throw std::runtime_error("Unexpected fixture method");return NSNull.null;
}
}
int main(){@autoreleasepool{
 for(Object o:{leaderClass,sentinelClass,worldA,worldB,catA,catB})create(o.address);
 Object local=create(0x7000,leaderClass,worldA,catA),otherCat=create(0x8000,leaderClass,worldA,catB),otherWorld=create(0x9000,leaderClass,worldB,catA);
 Object guard=create(0xa000,sentinelClass,worldA,{},catA),idle=create(0xb000,sentinelClass,worldA),otherTarget=create(0xc000,sentinelClass,worldA,{},catB),farGuard=create(0xd000,sentinelClass,worldB,{},catA);
 for(NSInteger feature:{2,3,4}){NSDictionary *off=STEnemyApply(feature,false);check([off[@"available"] boolValue]&&! [off[@"active"] boolValue],"Off without ownership is immediately available");}
 check(contextReads==0&&enumerations==0&&sets==0,"Disabled enemy features perform no context resolution, discovery or native mutation");
 context.ready=true;context.world=worldA;context.pawn=catA;
 NSDictionary *s=STEnemyApply(2,true);
 check([s[@"active"] boolValue]&&!row(local).see&&!row(local).hear,"Both native senses require confirmed original readbacks");
 check(row(otherCat).see&&row(otherCat).hear&&row(otherWorld).see,"Other cats and worlds are never modified");
 NSUInteger before=sets,scans=enumerations;STEnemyApply(2,true);check(sets==before&&enumerations==scans,"Repeated holding reuses bounded Weak discovery and is idempotent");
 STEnemyApply(2,false);check(row(local).see&&row(local).hear,"Owned sense flags restore their original values");
 row(local).see=false;STEnemyApply(2,true);row(local).see=true;STEnemyApply(2,false);
 check(row(local).see&&row(local).hear,"Intervening external changes survive release");
 row(local).see=false;STEnemyApply(2,true);row(local).see=true;STEnemyApply(2,true);STEnemyApply(2,false);
 check(row(local).see,"A new original value observed while holding becomes the restore baseline");
 s=STEnemyApply(4,true);check([s[@"active"] boolValue]&&!row(guard).aggressive&&!row(idle).aggressive,"Original aggression is disabled without freezing actors");
 check(row(otherTarget).aggressive&&row(farGuard).aggressive,"A different locked target or world remains untouched");
 s=STEnemyApply(3,true);check([s[@"active"] boolValue]&&!row(guard).vision&&!row(idle).vision,"Original proven Blueprint vision gate is disabled");
 check(row(otherTarget).vision&&row(farGuard).vision,"Other vision targets and worlds remain untouched");
 STEnemyApply(4,false);check(row(guard).aggressive&&row(idle).aggressive&&!row(guard).vision,"Releasing aggression preserves independently held vision");
 STEnemyApply(4,true);STEnemyApply(3,false);check(row(guard).vision&&!row(guard).aggressive,"Releasing vision preserves independently held aggression");
 NSUInteger reads=contextReads;before=sets;scans=enumerations;STEnemyApply(3,false);
 check(contextReads==reads&&sets==before&&enumerations==scans,"An inactive sibling flag avoids native lookups while aggression remains owned");
 STEnemyApply(4,false);check(row(guard).aggressive&&row(idle).aggressive,"Original aggression is restored");
 STEnemyApply(2,true);row(local).serial++;STEnemyApply(2,false);check(!row(local).see&&!row(local).hear,"Recycled object indices never receive stale restoration");
 row(local).see=row(local).hear=true;badLayout=true;before=sets;s=STEnemyApply(2,true);check(![s[@"active"] boolValue]&&sets==before,"A mismatched reflected owner field cannot be written");badLayout=false;
 badSignature=true;before=sets;s=STEnemyApply(2,true);check(![s[@"available"] boolValue]&&sets==before,"A modified original instruction rejects all enemy mutation");badSignature=false;
 rejectSet=true;s=STEnemyApply(2,true);check(![s[@"active"] boolValue],"A rejected original setter never reports Active");rejectSet=false;STEnemyRelease();
 STEnemyApply(2,true);context.ready=false;s=STEnemyApply(2,true);check(![s[@"active"] boolValue]&&row(local).see&&row(local).hear,"Loading releases owned actor effects");context.ready=true;
 before=sets;gameThread=false;s=STEnemyApply(2,true);check(![s[@"available"] boolValue]&&sets==before,"No fallback thread may mutate a game actor");gameThread=true;

 check(buffers.empty(),"All original actor-array allocations are freed");STEnemyRelease();
 puts("PASS: genuine setter/readback requirement, idempotency, actor/world/target isolation, owned restoration, external changes, recycled Weak identity, native schema/prologue rejection independent original vision/aggression leases and no disabled-state native lookups. Synthetic only; no game started.");
}}
