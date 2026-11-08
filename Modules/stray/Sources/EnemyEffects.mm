// SPDX-License-Identifier: GPL-3.0-only
#import "EnemyEffects.hpp"
#import "EnemyBindings.h"
#import "PlayerEffects.hpp"
#include <algorithm>
#include <chrono>
#include <cstring>
#include <exception>
#include <vector>
namespace {
using st::Object;using st::Weak;
struct Flag {bool captured=false,original=false,owned=false,written=false;};
struct Lease {Weak actor{},world{},pawn{};Flag see{},hear{},aggressive{},vision{};};
std::vector<Lease> zurks,sentinels;
struct Discovery {Weak world{},pawn{},type{};std::vector<Weak> actors;std::chrono::steady_clock::time_point updated{};bool valid=false;};
Discovery zurkDiscovery,sentinelDiscovery;
Weak currentWorld{},currentPawn{};
bool zurksWanted=false,sentinelsWanted=false,visionWanted=false;
[[noreturn]]void fail(const char *why){throw std::runtime_error(why);}
NSDictionary *state(bool available,bool active,NSString *note){return @{ @"available":@(available),@"active":@(active),@"note":note};}
uintptr_t checkedBinding(const char *name){auto value=st::binding(name);if(!value)fail("Die originale Gegneranbindung fehlt.");return value;}
void verifyOriginal(const st::enemy::Function &function){
 uintptr_t anchor=checkedBinding("processEvent");if(anchor<0x1015f656cULL)fail("Ungültige originale Gegneridentität.");
 uintptr_t at=function.address+(anchor-0x1015f656cULL);uint8_t bytes[16];
 if(function.size>sizeof(bytes)||!st::read(at,bytes,function.size)||memcmp(bytes,function.bytes,function.size))fail("Die originale Gegnerfunktion stimmt nicht überein.");
}
void validateBindings(NSInteger feature){
 if(feature==2){verifyOriginal(st::enemy::CanSwarmSee);verifyOriginal(st::enemy::SetSwarmCanSee);verifyOriginal(st::enemy::CanSwarmHearSound);verifyOriginal(st::enemy::SetSwarmCanHearSound);}
 else verifyOriginal(feature==3?st::enemy::SetVisonLightEnabled:st::enemy::SetAggressive);
}
Object member(Object owner,NSString *name,int32_t expectedOffset){
 auto p=st::property(owner,name);
 if(![p.type isEqual:@"ObjectProperty"]||p.size!=8||p.count!=1||p.offset!=expectedOffset)fail("Die originale Gegner-Besitzerzuordnung stimmt nicht überein.");
 id value=st::readValue(owner,p);if(value==NSNull.null)return {};
 if(![value isKindOfClass:NSDictionary.class]||![value[@"object"] isKindOfClass:NSNumber.class])fail("Ungültiger nativer Gegnerbesitzer.");
 return st::object([value[@"object"] intValue]);
}
Object actorWorld(Object actor){return {(uintptr_t)((void *(*)(void *))checkedBinding("actorWorld"))((void *)actor.address)};}
bool boolResult(Object owner,NSString *method){id result=st::invoke(owner,method,@{});if(![result isKindOfClass:NSNumber.class]||([result doubleValue]!=0&&[result doubleValue]!=1))fail("Ungültige native Gegner-Rückmeldung.");return [result boolValue];}
void setBool(Object owner,NSString *method,NSString *parameter,bool value,NSString *getter){
 st::invoke(owner,method,@{parameter:@(value)});
 if(boolResult(owner,getter)!=value)fail("Die native Gegnerwirkung wurde nicht bestätigt.");
}
void acquire(Flag &flag,bool actual){
 if(!flag.captured||actual!=flag.written){flag.original=actual;flag.captured=true;flag.owned=false;}
}
void hold(Object owner,Flag &flag,NSString *setter,NSString *parameter,NSString *getter){
 bool before=boolResult(owner,getter);acquire(flag,before);
 if(before){setBool(owner,setter,parameter,false,getter);flag.owned=true;}
 flag.written=false;
}
void restore(Object owner,Flag &flag,NSString *setter,NSString *parameter,NSString *getter){
 if(flag.owned&&boolResult(owner,getter)==flag.written)setBool(owner,setter,parameter,flag.original,getter);
 flag={};
}
bool holds(const std::vector<Lease> &leases,NSInteger feature){for(const auto &lease:leases){
 const Flag &flag=feature==3?lease.vision:lease.aggressive;
 if(feature==2?(lease.see.captured||lease.hear.captured||lease.see.owned||lease.hear.owned):(flag.captured||flag.owned))return true;
 }return false;
}
bool live(const Lease &lease,Object &actor){actor=lease.actor.get();Object world=lease.world.get();return actor&&world&&actorWorld(actor)==world;}
void release(std::vector<Lease> &leases,bool swarm){
 for(auto &lease:leases)try{Object actor;if(!live(lease,actor))continue;
  if(swarm){restore(actor,lease.see,@"SetSwarmCanSee",@"_canSee",@"CanSwarmSee");restore(actor,lease.hear,@"SetSwarmCanHearSound",@"_canHearSound",@"CanSwarmHearSound");}
  else {restore(actor,lease.vision,@"SetVisonLightEnabled",@"_enable",@"GetVisionLightEnabled");restore(actor,lease.aggressive,@"SetAggressive",@"_isAggressive",@"IsAggressive");}
 }catch(const std::exception &){}
 leases.clear();
}
std::vector<Object> actors(const st::PlayerContext &context,bool swarm){
 auto &cache=swarm?zurkDiscovery:sentinelDiscovery;
 auto now=std::chrono::steady_clock::now();
 auto eligible=[&](Object actor,Object cls){
  Weak owner(actor);if(!actor||owner.get()!=actor||!st::isA(actor,cls)||actorWorld(actor)!=context.world)return false;
  if(swarm)return member(actor,@"m_cachedPlayerCatPawn",st::enemy::LeaderCachedCat)==context.pawn;
  Object target=member(actor,@"m_lockedTargetActor",st::enemy::SentinelLockedTarget);return !target||target==context.pawn;
 };
 // Only discovery is throttled. Every cached actor keeps its original Weak
 // serial, and world/selected-cat/locked-target ownership is checked anew.
 if(cache.valid&&now-cache.updated<std::chrono::milliseconds(500)&&cache.world.get()==context.world&&cache.pawn.get()==context.pawn){
  Object cls=cache.type.get();std::vector<Object> result;
  if(cls){for(auto &weak:cache.actors)try{Object actor=weak.get();if(actor&&eligible(actor,cls))result.push_back(actor);}catch(const std::exception &){}return result;}
 }
 Object cls{(uintptr_t)((void *(*)())checkedBinding(swarm?"enemyLeaderClass":"enemySentinelClass"))()};
 if(!cls||![st::name(cls) isEqual:swarm?@"ZurgPawnLeader":@"Sentinel"])fail("Die originale Gegnerklasse fehlt.");
 struct Array {uintptr_t *data=nullptr;int32_t count=0,capacity=0;} array;
 auto free=(void(*)(void *))checkedBinding("enemyFree");
 try{
  ((void(*)(const void *,void *,Array *))checkedBinding("enemyAllActors"))((void *)context.world.address,(void *)cls.address,&array);
  if(array.count<0||array.count>4096||array.capacity<array.count||array.capacity>65536||(array.count&&!array.data))fail("Ungültige originale Gegnerliste.");
  std::vector<Object> result;
  for(int32_t i=0;i<array.count;i++)try{
   uintptr_t address=st::read<uintptr_t>((uintptr_t)array.data+(size_t)i*8);Object actor{address};
   if(eligible(actor,cls))result.push_back(actor);
  }catch(const std::exception &){}
  cache.actors.clear();for(auto actor:result)cache.actors.emplace_back(actor);
  cache.world=Weak(context.world);cache.pawn=Weak(context.pawn);cache.type=Weak(cls);cache.updated=now;cache.valid=true;
  if(array.data)free(array.data);return result;
 }catch(...){if(array.data)free(array.data);throw;}
}
void establish(const st::PlayerContext &context){
 if(currentWorld.get()!=context.world||currentPawn.get()!=context.pawn){STEnemyRelease();currentWorld=Weak(context.world);currentPawn=Weak(context.pawn);}
}
void removeMissing(std::vector<Lease> &leases,const std::vector<Object> &present,bool swarm){
 for(auto it=leases.begin();it!=leases.end();){Object actor=it->actor.get();if(std::find(present.begin(),present.end(),actor)==present.end()){
   std::vector<Lease> removed{*it};release(removed,swarm);it=leases.erase(it);
  }else ++it;}
}
Lease &leaseFor(std::vector<Lease> &leases,Object actor,const st::PlayerContext &context){
 for(auto &lease:leases)if(lease.actor.get()==actor)return lease;
 Lease lease;lease.actor=Weak(actor);lease.world=Weak(context.world);lease.pawn=Weak(context.pawn);leases.push_back(lease);return leases.back();
}
}
void STEnemyRelease(){if(!st::isGameThread())return;release(zurks,true);release(sentinels,false);currentWorld={};currentPawn={};zurksWanted=false;sentinelsWanted=false;visionWanted=false;zurkDiscovery={};sentinelDiscovery={};}
NSDictionary *STEnemyApply(NSInteger feature,bool wanted){
 if(feature!=2&&feature!=3&&feature!=4)return state(false,false,@"Keine passende Gegnerfunktion.");
 if(!st::isGameThread())return state(false,false,@"Der originale Spielthread ist noch nicht bereit.");
 try{
  bool swarm=feature==2;auto &leases=swarm?zurks:sentinels;
  if(swarm)zurksWanted=wanted;else if(feature==3)visionWanted=wanted;else sentinelsWanted=wanted;
  // The disabled steady state must not resolve the player or traverse native
  // metadata just to rediscover that no effect is owned.
  if(!wanted&&!holds(leases,feature))return state(true,false,@"Aus.");
  if(!wanted){
   if(swarm)release(leases,true);
   else {
    for(auto &lease:leases)try{Object actor;if(!live(lease,actor))continue;
     if(feature==3)restore(actor,lease.vision,@"SetVisonLightEnabled",@"_enable",@"GetVisionLightEnabled");
     else restore(actor,lease.aggressive,@"SetAggressive",@"_isAggressive",@"IsAggressive");
    }catch(const std::exception &){}
    if(!visionWanted&&!sentinelsWanted)leases.clear();
   }
   return state(true,false,@"Aus.");
  }
  auto context=st::playerContext();if(!context.ready){STEnemyRelease();return state(false,false,@"Auf einen gültigen lokalen Spielstand warten.");}
  establish(context);
  // establish may release the previous owner and clear its desired flags.
  if(swarm)zurksWanted=true;else if(feature==3)visionWanted=true;else sentinelsWanted=true;
  validateBindings(feature);auto list=actors(context,swarm);removeMissing(leases,list,swarm);
  size_t confirmed=0;
  for(Object actor:list){auto &lease=leaseFor(leases,actor,context);
   if(swarm){hold(actor,lease.see,@"SetSwarmCanSee",@"_canSee",@"CanSwarmSee");hold(actor,lease.hear,@"SetSwarmCanHearSound",@"_canHearSound",@"CanSwarmHearSound");if(!boolResult(actor,@"CanSwarmSee")&&!boolResult(actor,@"CanSwarmHearSound"))confirmed++;}
   // Original BTS_Sentinel_Vision ReceiveTickAI enters graph0x1463. Its
   // GetVisionLightEnabled gate skips detection and clears target/visibility
   // when false (graph0x14a0), rather than merely changing rendered light.
   // BTS_Sentinel_UpdateLogic does not re-enable this flag on its tick path.
   else if(feature==3){hold(actor,lease.vision,@"SetVisonLightEnabled",@"_enable",@"GetVisionLightEnabled");if(!boolResult(actor,@"GetVisionLightEnabled"))confirmed++;}
   else {hold(actor,lease.aggressive,@"SetAggressive",@"_isAggressive",@"IsAggressive");if(!boolResult(actor,@"IsAggressive"))confirmed++;}
  }
  bool active=confirmed>0&&confirmed==list.size();
  return state(true,active,active?@"Native Gegnerwirkung bestätigt.":@"Bereit; auf passende Gegner der lokalen Spielwelt warten.");
 }catch(const std::exception &e){return state(false,false,[NSString stringWithUTF8String:e.what()] ?: @"Die native Gegneranbindung wurde nicht bestätigt.");}
}
NSDictionary *STEnemyDiagnostics(){
 if(!st::isGameThread())return @{@"ready":@NO};NSMutableArray *rows=[NSMutableArray new];
 for(int group=0;group<2;group++)for(auto &lease:(group?sentinels:zurks))try{Object actor;if(!live(lease,actor))continue;NSMutableDictionary *row=[@{@"kind":group?@"Wächter":@"Zurk-Schwarm",@"index":@(lease.actor.index),@"serial":@(lease.actor.serial)} mutableCopy];
  if(group){row[@"aggressive"]=@(boolResult(actor,@"IsAggressive"));row[@"visionEnabled"]=@(boolResult(actor,@"GetVisionLightEnabled"));}else {row[@"see"]=@(boolResult(actor,@"CanSwarmSee"));row[@"hear"]=@(boolResult(actor,@"CanSwarmHearSound"));}[rows addObject:row];
 }catch(const std::exception &){}
 return @{@"ready":@YES,@"zurksWanted":@(zurksWanted),@"sentinelsWanted":@(sentinelsWanted),@"visionWanted":@(visionWanted),@"actors":rows};
}
