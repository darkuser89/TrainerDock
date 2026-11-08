// SPDX-License-Identifier: GPL-3.0-only
#import "Defluxor.hpp"
#import "PlayerEffects.hpp"
#include <array>
#include <cmath>
namespace {
struct LocalDrone {st::PlayerContext player{};st::Object drone{};bool unlocked=false;};
struct Held {st::Property property{};id original=nil,written=nil;};
std::array<Held,3> held;
st::Weak pawnWeak,controllerWeak,worldWeak,droneWeak;
st::Object pawn{},controller{},world{},drone{};
NSString *identity;
bool owned=false;
st::Object originalWorld(st::Object actor){
 uintptr_t address=st::binding("actorWorld");
 if(!address||!actor)return {};
 st::Weak keep(actor);if(keep.get()!=actor)return {};
 st::Object result{(uintptr_t)((void *(*)(void *))address)((void *)actor.address)};
 return keep.get()==actor?result:st::Object{};
}
st::Object objectResult(id value){
 if(value==NSNull.null)return {};
 if(![value isKindOfClass:NSDictionary.class]||[value count]!=1||![value[@"object"] isKindOfClass:NSNumber.class])throw std::runtime_error("Die native Drohnenreferenz fehlt.");
 double index=[value[@"object"] doubleValue];if(!std::isfinite(index)||index<0||index>INT32_MAX||std::floor(index)!=index)throw std::runtime_error("Ungültige native Drohnenreferenz.");
 return st::object((int32_t)index);
}
LocalDrone localDrone(){
 LocalDrone state;state.player=st::playerContext();if(!state.player.ready)return state;
 state.drone=objectResult(st::invoke(state.player.controller,@"GetDrone",@{}));if(!state.drone)return state;
 st::Weak keep(state.drone);
 if(keep.get()!=state.drone||![st::className(state.drone) hasPrefix:@"BP_Drone_C"]||originalWorld(state.drone)!=state.player.world)throw std::runtime_error("Die lokale Drohnenzuordnung stimmt nicht überein.");
 id unlocked=st::invoke(state.drone,@"IsStrongLightUnlocked",@{});
 if(![unlocked isKindOfClass:NSNumber.class])throw std::runtime_error("Die originale Defluxorfreigabe ist nicht lesbar.");
 state.unlocked=[unlocked boolValue];return state;
}
st::Property field(st::Object d,NSString *name,NSString *type,int32_t offset,int32_t size){
 st::Property p=st::property(d,name);
 if(![p.type isEqual:type]||p.offset!=offset||p.size!=size||p.count!=1
  ||([type isEqual:@"BoolProperty"]&&(p.boolByteOffset!=0||p.boolMask!=255)))throw std::runtime_error("Das ursprüngliche Defluxorfeld stimmt nicht überein.");
 return p;
}
std::array<st::Property,3> schema(st::Object d){
 // The exact original heat graph adds HeatIncreaseSpeed*dt to Battery, clamps
 // to 0..1 and sets DroneIsOverHeating at 1. Battery is heat, not charge.
 return {field(d,@"HeatIncreaseSpeed",@"FloatProperty",0x638,4),field(d,@"Battery",@"FloatProperty",0x528,4),field(d,@"DroneIsOverHeating",@"BoolProperty",0x63c,1)};
}
bool same(id a,id b){return [a isKindOfClass:NSNumber.class]&&[b isKindOfClass:NSNumber.class]&&[a isEqual:b];}
bool alive(){return pawnWeak.get()==pawn&&controllerWeak.get()==controller&&worldWeak.get()==world&&droneWeak.get()==drone&&originalWorld(drone)==world;}
void forget(){for(Held &h:held)h={};owned=false;identity=nil;pawn={};controller={};world={};drone={};pawnWeak={};controllerWeak={};worldWeak={};droneWeak={};}
void release(){
 if(!owned)return;
 if(alive())for(Held &h:held)if(h.written){
  try{if(same(st::readValue(drone,h.property),h.written))st::writeValue(drone,h.property,h.original);}catch(const std::exception &){}
 }
 forget();
}
NSDictionary *state(bool available,bool active,NSString *note){return @{@"available":@(available),@"active":@(active),@"note":note};}
}
void STDefluxorRelease(){if(!st::isBound()||!st::isGameThread())return;try{release();}catch(const std::exception &){forget();}}
NSDictionary *STDefluxorApply(bool wanted){
 // The bridge polls every feature. An inactive effect must not resolve the
 // player, scan metadata or invoke equipment APIs just to report "Aus".
 if(!wanted&&!owned)return state(true,false,@"Aus. Freigabe wird beim Einschalten geprüft.");
 if(!st::isBound()||!st::isGameThread())return state(false,false,@"Die originale Spielzustellung ist noch nicht bereit.");
 try{
  if(!wanted){release();return state(true,false,@"Aus.");}
  LocalDrone current=localDrone();
  if(!current.player.ready||!current.drone||!current.unlocked){release();return state(false,false,!current.player.ready?@"Auf den lokalen Spielstand warten.":@"Der Defluxor ist in diesem Spielstand noch nicht verfügbar.");}
  auto properties=schema(current.drone);
  if(owned&&(!alive()||current.drone!=drone||current.player.pawn!=pawn||current.player.controller!=controller||current.player.world!=world||![current.player.identity isEqual:identity]))release();
  if(!owned){
   pawn=current.player.pawn;controller=current.player.controller;world=current.player.world;drone=current.drone;identity=[current.player.identity copy];
   pawnWeak=st::Weak(pawn);controllerWeak=st::Weak(controller);worldWeak=st::Weak(world);droneWeak=st::Weak(drone);
   for(size_t i=0;i<held.size();i++){held[i].property=properties[i];held[i].original=st::readValue(drone,properties[i]);}
   double rate=[held[0].original doubleValue],heat=[held[1].original doubleValue];
   if(!std::isfinite(rate)||rate<0||rate>1000||!std::isfinite(heat)||heat<0||heat>1)throw std::runtime_error("Die ursprünglichen Defluxorwerte sind ungültig.");
   owned=true;
  }
  const id desired[]={@0.0,@0.0,@NO};
  for(size_t i=0;i<held.size();i++){
   Held &h=held[i];id value=st::readValue(drone,h.property);
   // Preserve later original game changes rather than restoring a stale value.
   if(h.written&&!same(value,h.written))h.original=value;
   if(!st::writeValue(drone,h.property,desired[i]))throw std::runtime_error("Das Spiel hat die Defluxoränderung abgelehnt.");
   h.written=desired[i];
   if(!same(st::readValue(drone,h.property),desired[i]))throw std::runtime_error("Die native Defluxorrücklesung stimmt nicht überein.");
  }
  return state(true,true,@"Defluxorwärme und Überhitzung nativ bestätigt.");
 }catch(const std::exception &){STDefluxorRelease();return state(false,false,@"Die native Defluxorzuordnung ist noch nicht bestätigt.");}
}
NSDictionary *STDefluxorDiagnostics(){
 if(!st::isBound()||!st::isGameThread())return @{@"ready":@NO};
 try{
  LocalDrone c=localDrone();if(!c.player.ready||!c.drone)return @{@"ready":@NO,@"note":@"Noch keine lokale Drohne verfügbar."};
  auto properties=schema(c.drone);
  return @{@"ready":@YES,@"unlocked":@(c.unlocked),@"drone":@(st::read<int32_t>(c.drone.address+0xc)),@"class":st::className(c.drone),@"heatIncreaseSpeed":st::readValue(c.drone,properties[0]),@"heat":st::readValue(c.drone,properties[1]),@"overheating":st::readValue(c.drone,properties[2]),@"owned":@(owned)};
 }catch(const std::exception &){return @{@"ready":@NO,@"note":@"Die native Defluxorzuordnung ist noch nicht bestätigt."};}
}
