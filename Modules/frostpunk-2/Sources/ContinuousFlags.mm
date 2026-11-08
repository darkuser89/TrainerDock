// SPDX-License-Identifier: GPL-3.0-only
#import "ContinuousFlags.hpp"
#import "ContinuousFlagBindings.h"
#import "GameBindings.h"
#import "Manager.hpp"
#import "ReflectionBindings.h"
extern "C" {
#import "MemoryAccess.h"
}
#include <array>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <vector>
namespace fp::continuous {
namespace {
enum class Scope { Engine,World };
struct Spec {
    const char *nativeClass,*classAnchor;Scope scope;uint16_t offset;
    NSString *setter;
};
const Spec building={"PXCheatSubsystem","cheatClass",Scope::Engine,0x34,nil};
const Spec district={"PXCheatSubsystem","cheatClass",Scope::Engine,0x32,nil};
const Spec enhancement={"PXCheatSubsystem","cheatClass",Scope::Engine,0x31,nil};
const Spec area={"PXCheatSubsystem","cheatClass",Scope::Engine,0x39,nil};
const Spec research={"PXResearchSubsystem","researchClass",Scope::World,0x3e8,@"SetInstantResearchEnabled"};
const Spec exploration={"PXTerritoryExplorationSubsystem","explorationClass",Scope::World,0x364,@"SetInstantExplorationEnabled"};
const Spec laws={"PXParliamentSubsystem","parliamentClass",Scope::World,0x4f0,@"SetAlwaysPassPolicyCheat"};
[[noreturn]]void fail(const char *message){throw std::runtime_error(message);}
void thread(){if(!isBound() || !isGameThread())fail("Original GameThread required for continuous effects");}
uintptr_t slide(){uintptr_t p=binding("processEvent");if(p<UINT64_C(0x100be2e78))fail("Original image relocation unavailable");return p-UINT64_C(0x100be2e78);}
const FPContinuousBinding &anchor(const char *name){for(const auto &b:FPContinuousBindings)if(!strcmp(name,b.name))return b;fail("Original continuous-effect anchor unavailable");}
void validateAnchors(){
    uintptr_t relocation=slide();
    for(const auto &b:FPContinuousBindings){uint8_t bytes[16];
        if(!read(b.address+relocation,bytes,16) || memcmp(bytes,b.bytes,16))
            fail("Original continuous-effect instructions differ");
    }
}
Object checked(uintptr_t address){if(!address)return {};Object o=object(read<int32_t>(address+FP2ObjectInternalIndexOffset));if(o.address!=address)fail("Stale native subsystem pointer");return o;}
void real(Object o){Weak w(o);if(!o || w.get()!=o || (read<uint32_t>(o.address+8)&0x18030))fail("Live nondefault subsystem owner required");}
Object outer(Object o){return checked(read<uintptr_t>(o.address+FP2ObjectOuterOffset));}
bool derives(Object o,NSString *base){std::set<uintptr_t> seen;Object c=objectClass(o);for(unsigned n=0;c && n<64;n++){if(!seen.insert(c.address).second)fail("Cyclic original subsystem class");if([name(c) isEqual:base])return true;c=checked(read<uintptr_t>(c.address+FP2StructSuperOffset));}return false;}
Object nativeClass(const Spec &s){
    const auto &a=anchor(s.classAnchor);using Getter=void *(*)();
    Object c=checked((uintptr_t)((Getter)(a.address+slide()))());
    if(!c || ![className(c) isEqual:@"Class"] || ![name(c) isEqual:@(s.nativeClass)])fail("Original subsystem class singleton differs");
    Object package=outer(c);
    if(!package || ![name(package) isEqual:@"/Script/Frostpunk2"])fail("Original subsystem class package differs");
    return c;
}
Object member(Object scope,const Spec &s){
    real(scope);Object cls=nativeClass(s);
    using Lookup=void *(*)(void *,void *);
    const auto &a=anchor("subsystemLookup");
    uintptr_t offset=s.scope==Scope::Engine?FPEngineSubsystemCollectionOffset:FPWorldSubsystemCollectionOffset;
    Object result=checked((uintptr_t)((Lookup)(a.address+slide()))((void *)(scope.address+offset),(void *)cls.address));
    real(result);
    if(objectClass(result)!=cls || outer(result)!=scope)fail("Subsystem collection membership or outer differs");
    return result;
}
Object scopeFor(const Context &c,const Spec &s){
    if(!c.ready || c.worldWeak.get()!=c.world || c.controllerWeak.get()!=c.controller ||
       c.cityWeak.get()!=c.city || c.nationWeak.get()!=c.nation)fail("Current local World/city identity is unavailable");
    if(s.scope==Scope::World){real(c.world);return c.world;}
    Object engine=checked(read<uintptr_t>(FPEngineObjectSlot+slide()));real(engine);
    if(!derives(engine,@"Engine"))fail("Original engine slot has an unexpected class");
    Object instance=linkedObject(c.world,@"OwningGameInstance");real(instance);
    if(!derives(instance,@"GameInstance") || outer(instance)!=engine)
        fail("Current World GameInstance is outside the original engine");
    return engine;
}
void setter(Object manager,Object scope,const Spec &s,bool value){
    real(manager);
    Object managerWorld=fp::worldOf(manager);real(managerWorld);
    if(managerWorld!=scope)fail("Native cheat manager belongs to a different subsystem World");
    Object pc=outer(manager);real(pc);
    if(linkedObject(pc,@"CheatManager")!=manager)fail("Controller no longer owns this native manager");
    Object fn=function(manager,s.setter);
    uint32_t flags=read<uint32_t>(fn.address+FP2FunctionFlagsOffset);
    if(!(flags&0x400) || (flags&0x2000) || read<uint16_t>(fn.address+FP2FunctionParameterSizeOffset)!=1)
        fail("Original manager bool setter flags/parameter size differ");
    auto ps=properties(fn);
    if(ps.size()!=1 || ![ps[0].type isEqual:@"BoolProperty"] || ps[0].size!=1 || ps[0].offset!=0 ||
       ps[0].count!=1 || !(ps[0].flags&0x80) || (ps[0].flags&(0x100|0x400|0x8000000)))
        fail("Original manager bool setter parameter differs");
    NSString *key=[@"exec." stringByAppendingString:s.setter];const FPGameBinding *expected=nullptr;
    for(const auto &b:FPGameBindings)if([key isEqual:@(b.name)]){expected=&b;break;}
    uintptr_t exec=read<uintptr_t>(fn.address+FP2FunctionNativeExecOffset);uint8_t bytes[16];
    if(!expected || exec!=expected->address+slide() || !read(exec,bytes,16) || memcmp(bytes,expected->bytes16,16))
        fail("Original manager bool setter exec differs");
    invoke(manager,s.setter,@{ps[0].name:@(value)});
}
// A lease retains only original weak identities. An external value change
// relinquishes the write; release never overwrites such a changed value.
struct WeakScalarLease {
    const Spec *spec=nullptr;Weak owner,scope,manager;bool attached=false,owned=false;uint8_t original=0,written=1;
    Object validate() const {
        Object o=owner.get(),p=scope.get();if(!o || !p)return {};
        if(member(p,*spec)!=o)fail("Native leased subsystem membership changed");
        return o;
    }
    uint8_t value() const {
        Object o=validate();if(!o)fail("Native leased subsystem owner expired");
        uint8_t v=read<uint8_t>(o.address+spec->offset);if(v>1)fail("Native subsystem flag is not a byte bool");return v;
    }
    void store(uint8_t v){
        Object o=validate(),p=scope.get();if(!o || !p)fail("Native flag owner expired before write");
        if(spec->setter){Object m=manager.get();if(!m)fail("Native flag manager expired before setter");setter(m,p,*spec,v!=0);}
        else if(!MTWriteByte((void *)o.address,spec->offset,v))fail("Native data flag write failed");
        if(value()!=v)fail("Native continuous flag readback differs");
    }
    bool release(){
        if(!attached)return true;
        Object o=owner.get(),p=scope.get();
        if(!o || !p){attached=false;owned=false;return true;}
        uint8_t current=value();
        if(owned && current==written)store(original);
        attached=false;owned=false;return true;
    }
    void acquire(const Spec &s,Object p,Object o,Object m){
        if(attached && (scope.get()!=p || owner.get()!=o || spec!=&s))release();
        if(!attached){spec=&s;scope=Weak(p);owner=Weak(o);manager=m?Weak(m):Weak{};original=value();attached=true;owned=false;}
        uint8_t current=value();
        if(owned && current!=written){owned=false;original=current;}
        if(current!=1){original=current;owned=true;written=1;store(written);}
    }
};
std::map<MTFeature,std::vector<WeakScalarLease>> leases;
std::map<MTFeature,NSString *> failedManagerRequests;
NSString *identity=@"";
std::vector<const Spec *> specs(MTFeature f){
    switch(f){
        case MTFeatureConstruction:return {&building,&district,&enhancement};
        case MTFeatureExpansion:return {&area};
        case MTFeatureResearch:return {&research};
        case MTFeatureExpedition:return {&exploration};
        case MTFeatureLaws:return {&laws};
        default:fail("Unknown continuous flag feature");
    }
}
bool releaseFeature(MTFeature f){
    auto found=leases.find(f);if(found==leases.end())return true;
    bool complete=true;
    for(auto &lease:found->second)try{lease.release();}catch(const std::exception &){complete=false;}
    if(complete)leases.erase(found);return complete;
}
}
bool releaseOwnEffects(){
    if(!isBound() || !isGameThread())return false;
    try{validateAnchors();}catch(const std::exception &){return false;}
    bool complete=true;
    std::vector<MTFeature> features;for(auto &entry:leases)features.push_back(entry.first);
    for(MTFeature f:features)if(!releaseFeature(f))complete=false;
    if(complete){identity=@"";failedManagerRequests.clear();}
    return complete;
}
Result apply(const Context &c,MTFeature feature,bool wanted){
    Result result;
    try{
        thread();validateAnchors();auto flags=specs(feature);
        if(![identity isEqual:c.identity ?: @""]){
            if(!releaseOwnEffects())fail("Previous native effects are awaiting safe release");
            identity=[c.identity copy] ?: @"";
        }
        if(!wanted){
            failedManagerRequests.erase(feature);
            if(!releaseFeature(feature))fail("Owned native flag could not yet be restored");
            result.available=c.ready;result.note=@"Eigene Wirkung freigegeben; fremde Zustände bleiben erhalten.";
            return result;
        }
        if(!c.ready)fail("Gültige lokale Stadt und Welt erforderlich");
        Object manager{};
        if(flags[0]->setter){
            // A failed creation is not repeated every frame. A new explicit off/
            // on request, a new owner, or an externally installed manager retries.
            auto failed=failedManagerRequests.find(feature);
            if(failed!=failedManagerRequests.end() && !linkedObject(c.controller,@"CheatManager"))
                fail(failed->second.UTF8String ?: "Native manager creation has not succeeded");
            auto native=ensureCheatManager(c.controller);
            if(!native.ready){failedManagerRequests[feature]=native.reason ?: @"Native manager unavailable";fail(native.reason.UTF8String ?: "Native manager unavailable");}
            manager=native.manager;failedManagerRequests.erase(feature);
        }
        auto &group=leases[feature];
        if(group.empty())group.resize(flags.size());
        if(group.size()!=flags.size())fail("Native continuous lease shape differs");
        try{
            for(size_t i=0;i<flags.size();i++){
                Object scope=scopeFor(c,*flags[i]),owner=member(scope,*flags[i]);
                group[i].acquire(*flags[i],scope,owner,manager);
            }
            for(const auto &lease:group)if(lease.value()!=1)fail("Native continuous flag is not active");
        }catch(const std::exception &){releaseFeature(feature);throw;}
        result.available=true;result.active=true;result.note=@"Originale Laufzeitflags gesetzt und zurückgelesen.";
    }catch(const std::exception &e){
        result.available=false;result.active=false;
        result.note=[NSString stringWithUTF8String:e.what()] ?: @"Native Dauerwirkung nicht verfügbar.";
    }
    return result;
}
}
