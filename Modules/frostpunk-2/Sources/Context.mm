// SPDX-License-Identifier: GPL-3.0-only
#import "Context.hpp"
#import "ReflectionBindings.h"
#include <map>
#include <set>
#include <string>
#include <stdexcept>
namespace fp {
namespace {
Weak cachedPlayer;std::map<std::string,Weak> utilities;
[[noreturn]]void reject(const char *s){throw std::runtime_error(s);}
void thread(){if(!isGameThread())reject("Original GameThread required for context");}
Object decode(id value){if(value==NSNull.null)return {};if(![value isKindOfClass:NSDictionary.class] || ![value[@"object"] isKindOfClass:NSNumber.class])reject("Original getter did not return an object");return object([value[@"object"] intValue]);}
NSDictionary *arg(Object o){if(!o)reject("Missing native context argument");return @{@"object":@(read<int32_t>(o.address+FP2ObjectInternalIndexOffset))};}
void real(Object o){if(!o)reject("Gameplay owner not ready");if(read<uint32_t>(o.address+8)&0x18030)reject("Default/archetype/destroyed object is not a gameplay owner");if([name(o) hasPrefix:@"Default__"])reject("Default object is not a gameplay owner");}
Object outer(Object o){uintptr_t p=read<uintptr_t>(o.address+FP2ObjectOuterOffset);if(!p)return {};return object(read<int32_t>(p+FP2ObjectInternalIndexOffset));}
Object get(Object o,NSString *fn){return decode(invoke(o,fn,@{}));}
struct ContextBinding {uintptr_t address;uint8_t bytes[16];};
// Original AActor::GetWorld, vtable 0x10b531e00 slot 50 (+0x190):
// GetTypedOuter<ULevel>() then ldr x0,[level,#0xc8], not Level.Outer.
// FArrayProperty's original constructor places Inner at +0x78.
static const ContextBinding worldBindings[]={
 {0x10315e200ULL,{0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0x08,0x08,0x40,0xb9}},
 {0x10315e2b0ULL,{0x47,0x02,0x1b,0x94,0xe1,0x03,0x00,0xaa,0xe0,0x03,0x13,0xaa,0x9b,0x8a,0x6a,0x97}},
 {0x10315e2c4ULL,{0x00,0x64,0x40,0xf9,0xfd,0x7b,0x41,0xa9,0xf4,0x4f,0xc2,0xa8,0xc0,0x03,0x5f,0xd6}},
 {0x100b69688ULL,{0x7f,0x3e,0x00,0xf9,0x7f,0xc2,0x01,0x39,0xe8,0xed,0x04,0xb0,0x00,0xa9,0x45,0xfd}},
};
void verifyWorldBindings(){
 thread();uintptr_t anchor=binding("processEvent");if(!anchor)reject("Original World binding unavailable");
 intptr_t slide=(intptr_t)anchor-(intptr_t)0x100be2e78ULL;
 for(const auto &b:worldBindings){uint8_t actual[16];if(!read(b.address+slide,actual,16)||memcmp(actual,b.bytes,16))reject("Original streamed-World instructions differ");}
}
Object owningWorld(Object level){
 real(level);if(![className(level) isEqual:@"Level"])reject("Original level class differs");
 Property p=property(level,@"OwningWorld");
 if(![p.type isEqual:@"ObjectProperty"]||p.offset!=0xc8||p.size!=8||p.count!=1)reject("Original Level.OwningWorld metadata differs");
 Object world=decode(readValue(level,p));real(world);
 if(![className(world) isEqual:@"World"])reject("Level owner is not an original World");return world;
}
void levelMembership(Object world,Object level){
 real(world);real(level);Weak worldLease(world),levelLease(level);
 Object persistent=linkedObject(world,@"PersistentLevel");real(persistent);
 if(owningWorld(persistent)!=world)reject("Persistent level's owning World differs");
 Property p=property(world,@"Levels");
 if(![p.type isEqual:@"ArrayProperty"]||p.offset!=0x188||p.size!=16||p.count!=1)reject("Original World.Levels metadata differs");
 uintptr_t inner=read<uintptr_t>(p.address+0x78),kind=inner?read<uintptr_t>(inner+8):0;
 if(!kind||![fname(kind) isEqual:@"ObjectProperty"]||read<int32_t>(inner+0x30)!=8||read<int32_t>(inner+0x2c)!=1)reject("World.Levels does not contain original level pointers");
 Object cls{read<uintptr_t>(inner+0x70)};
 if(![name(cls) isEqual:@"Level"]||![className(cls) isEqual:@"Class"]||!isA(level,cls)||!isA(persistent,cls))reject("World.Levels element class differs");
 struct Array {uintptr_t data;int32_t count,capacity;};static_assert(sizeof(Array)==16);
 Array before=read<Array>(world.address+p.offset);
 if(before.count<1||before.count>4096||before.capacity<before.count||before.capacity>65536||!before.data||(before.data&7))reject("Original World.Levels exceeds bounds");
 std::vector<uintptr_t> members((size_t)before.count),fresh((size_t)before.count);
 if(!read(before.data,members.data(),members.size()*8))reject("Original World.Levels unreadable");
 size_t levelCount=0,persistentCount=0;for(uintptr_t entry:members){levelCount+=entry==level.address;persistentCount+=entry==persistent.address;}
 if(levelCount!=1||persistentCount!=1)reject("Gameplay level is not uniquely registered in its owning World");
 Array after=read<Array>(world.address+p.offset);
 if(memcmp(&before,&after,sizeof(before))||!read(before.data,fresh.data(),fresh.size()*8)||fresh!=members||worldLease.get()!=world||levelLease.get()!=level||owningWorld(level)!=world)
  reject("Original level membership changed");
}
Object worldForActor(Object actor,Object *levelOut=nullptr){
 verifyWorldBindings();real(actor);Weak actorLease(actor);
 Object level=get(actor,@"GetLevel"),world=owningWorld(level);levelMembership(world,level);
 if(actorLease.get()!=actor||get(actor,@"GetLevel")!=level)reject("Actor level changed");
 if(levelOut)*levelOut=level;return world;
}
Object staticGet(NSString *type,NSString *fn,NSDictionary *args){Object cdo=utility(type),f=function(cdo,fn);uint32_t flags=read<uint32_t>(f.address+FP2FunctionFlagsOffset);if((flags&(0x2000|0x400))!=(0x2000|0x400))reject("Context utility is not an original native static function");return decode(invoke(cdo,fn,args));}
Object activeController(Object player){real(player);if(![className(player) isEqual:@"LocalPlayer"])reject("Controller is not owned by the original local player");Object pc=linkedObject(player,@"PlayerController");real(pc);id local=invoke(pc,@"IsLocalPlayerController",@{});if(![local isKindOfClass:NSNumber.class]||![local boolValue])reject("Controller is not the original local controller");if(linkedObject(pc,@"Player")!=player)reject("Local player/controller references differ");return pc;}
Object player(){Object p=cachedPlayer.get();if(p){try{activeController(p);return p;}catch(const std::runtime_error &){cachedPlayer=Weak{};}}
    // Candidate discovery is used only to locate the authoritative UPlayer
    // backlink. Every candidate is checked, and ambiguity fails closed.
    Object selected{};for(Object pc:find(@"PlayerController",nil,1024)){try{real(pc);id local=invoke(pc,@"IsLocalPlayerController",@{});if(![local isKindOfClass:NSNumber.class]||![local boolValue])continue;Object q=linkedObject(pc,@"Player");if(activeController(q)!=pc)continue;if(selected&&selected!=q)reject("More than one local player is active");selected=q;}catch(const std::runtime_error &e){if(!strcmp(e.what(),"More than one local player is active"))throw;}}
    if(!selected)reject("Original local player is not ready");cachedPlayer=Weak(selected);return selected;}
NSString *part(const Weak &w){return [NSString stringWithFormat:@"%d:%d",w.index,w.serial];}
}
Object worldOf(Object o){
 verifyWorldBindings();std::set<uintptr_t> seen;
 for(unsigned depth=0;o&&depth<32;depth++){
  real(o);if(!seen.insert(o.address).second)reject("Cyclic gameplay World ownership");
  NSString *type=className(o);
  if([type isEqual:@"World"]){Object persistent=linkedObject(o,@"PersistentLevel");if(owningWorld(persistent)!=o)reject("World persistent level belongs to a different World");levelMembership(o,persistent);return o;}
  if([type isEqual:@"Level"]){Object world=owningWorld(o);levelMembership(world,o);return world;}
  o=outer(o);
 }
 reject("Original gameplay owning World unavailable");
}
Object linkedObject(Object owner,NSString *field){thread();return decode(readValue(owner,property(owner,field)));}
Object utility(NSString *type){thread();std::string key=type.UTF8String ?: "";if(key.empty())reject("Utility class missing");auto i=utilities.find(key);if(i!=utilities.end()){Object o=i->second.get();if(o)return o;utilities.erase(i);}Object found{};NSString *expected=[@"Default__" stringByAppendingString:type];for(Object o:find(type,expected,16)){if(![className(o) isEqual:type]||![name(o) isEqual:expected]||!(read<uint32_t>(o.address+8)&0x10))continue;Object c=objectClass(o);if(![className(c) isEqual:@"Class"]||![name(c) isEqual:type])continue;Object package=outer(c);if(!package||![name(package) isEqual:@"/Script/Frostpunk2"])continue;if(found)reject("Ambiguous original utility CDO");found=o;}if(!found)reject("Original utility CDO not ready");utilities.emplace(key,Weak(found));return found;}
Context captureContext(){Context c;if(!isGameThread()){c.note=@"Originaler GameThread nicht verfügbar.";return c;}try{c.localPlayer=player();c.controller=activeController(c.localPlayer);c.world=worldForActor(c.controller,&c.level);c.city=staticGet(@"PXSelectionUtils",@"GetCurrentCity",@{@"WorldContextObject":arg(c.controller)});real(c.city);if(![className(c.city) isEqual:@"PXCityComponent"])reject("Selected city has unexpected original class");c.nation=linkedObject(c.city,@"Nation");real(c.nation);if(![className(c.nation) isEqual:@"PXNationComponent"])reject("City nation has unexpected original class");Object playerNation=staticGet(@"PXNationUtils",@"GetPlayerNation",@{@"WorldContextObject":arg(c.controller)});if(playerNation!=c.nation)reject("Selected city does not belong to the local player's nation");Object cityOwner=get(c.city,@"GetOwner"),nationOwner=get(c.nation,@"GetOwner");if(cityOwner!=outer(c.city)||nationOwner!=outer(c.nation))reject("Component ownership changed");if(worldForActor(cityOwner)!=c.world||worldForActor(nationOwner)!=c.world)reject("Controller, city and nation belong to different worlds");if(activeController(c.localPlayer)!=c.controller)reject("Local controller changed during context capture");c.playerWeak=Weak(c.localPlayer);c.controllerWeak=Weak(c.controller);c.worldWeak=Weak(c.world);c.cityWeak=Weak(c.city);c.nationWeak=Weak(c.nation);c.identity=[NSString stringWithFormat:@"%@/%@/%@/%@/%@",part(c.playerWeak),part(c.controllerWeak),part(c.worldWeak),part(c.cityWeak),part(c.nationWeak)];c.ready=true;c.note=@"Lokale Stadt und Nation nativ zugeordnet.";}catch(const std::exception &e){c.ready=false;c.identity=@"";c.note=[NSString stringWithUTF8String:e.what()] ?: @"Spielkontext nicht verfügbar.";}return c;}
}
