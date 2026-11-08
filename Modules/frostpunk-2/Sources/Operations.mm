// SPDX-License-Identifier: GPL-3.0-only
#import "Operations.hpp"
#import "ReflectionBindings.h"
#include <array>
#include <cmath>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <tuple>
#include <vector>
namespace fp::operations {
namespace {
struct CodeBinding {const char *name;uintptr_t address;uint8_t bytes[16];};
// Original Steam 24037022 / UUID 10F7F2EA-0D13-337E-BF07-ABA47A4549CF.
static const CodeBinding operationBindings[]={
 {"worldSubsystem",0x103ddc2b4ULL,{0xf8,0x5f,0xbc,0xa9,0xf6,0x57,0x01,0xa9,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9}},
 {"wearSubsystemClass",0x105f8482cULL,{0xff,0x83,0x01,0xd1,0xf4,0x4f,0x04,0xa9,0xfd,0x7b,0x05,0xa9,0xfd,0x43,0x01,0x91}},
 {"wearComponentClass",0x1062d68a0ULL,{0xff,0x83,0x01,0xd1,0xf4,0x4f,0x04,0xa9,0xfd,0x7b,0x05,0xa9,0xfd,0x43,0x01,0x91}},
 {"wearSet",0x10778b94cULL,{0xff,0x03,0x02,0xd1,0xe9,0x23,0x02,0x6d,0xfa,0x67,0x03,0xa9,0xf8,0x5f,0x04,0xa9}},
 {"wearGet",0x1077897b4ULL,{0xff,0x43,0x01,0xd1,0xe9,0x23,0x02,0x6d,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9}},
 {"wearMin",0x107789b04ULL,{0xff,0x43,0x01,0xd1,0xe9,0x23,0x02,0x6d,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9}},
 {"wearMax",0x107789928ULL,{0xff,0x43,0x01,0xd1,0xe9,0x23,0x02,0x6d,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9}},
 {"operationSubsystemClass",0x105b55b28ULL,{0xff,0x83,0x01,0xd1,0xf4,0x4f,0x04,0xa9,0xfd,0x7b,0x05,0xa9,0xfd,0x43,0x01,0x91}},
 {"deconstructionClass",0x105a4fb34ULL,{0xff,0x83,0x01,0xd1,0xf4,0x4f,0x04,0xa9,0xfd,0x7b,0x05,0xa9,0xfd,0x43,0x01,0x91}},
 {"operationTick",0x10733aee0ULL,{0xff,0x43,0x02,0xd1,0xe9,0x23,0x02,0x6d,0xfc,0x6f,0x03,0xa9,0xfa,0x67,0x04,0xa9}},
 {"operationFinish",0x10733a7e0ULL,{0xff,0x03,0x01,0xd1,0xf6,0x57,0x01,0xa9,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9}},
 {"operationPaused",0x107339114ULL,{0x08,0xe0,0x43,0x39,0x68,0x00,0x00,0x34,0x20,0x00,0x80,0x52,0xc0,0x03,0x5f,0xd6}},
 {"operationInactive",0x10733917cULL,{0x08,0x60,0x40,0xf9,0xa8,0x00,0x00,0xb4,0x08,0xe1,0x42,0x39,0x1f,0x01,0x00,0x71}},
 {"operationFinished",0x107339140ULL,{0x08,0xfc,0x40,0xb9,0xc8,0x00,0x00,0x34,0x00,0xb8,0x40,0xbd,0x01,0x10,0x2e,0x1e}},
 {"operationProgress",0x107339164ULL,{0x08,0xfc,0x40,0xb9,0x68,0x00,0x00,0x34,0x00,0xb8,0x40,0xbd,0xc0,0x03,0x5f,0xd6}},
 {"parliamentClass",0x105e7b328ULL,{0xff,0x83,0x01,0xd1,0xf4,0x4f,0x04,0xa9,0xfd,0x7b,0x05,0xa9,0xfd,0x43,0x01,0x91}},
 {"parliamentGet",0x1075deb08ULL,{0xff,0x03,0x01,0xd1,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9,0xfd,0xc3,0x00,0x91}},
 {"parliamentSubsystemGet",0x1075e7510ULL,{0x08,0xb8,0x42,0xb9,0x28,0x01,0x00,0x34,0x09,0x80,0x0a,0x91,0x0a,0x58,0x41,0xf9}},
 {"parliamentSkip",0x1075df800ULL,{0xff,0x03,0x01,0xd1,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9,0xfd,0xc3,0x00,0x91}},
 {"parliamentSkipNative",0x1075f0a10ULL,{0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x00,0xaa}},
 {"wearTick",0x10778b6a0ULL,{0xff,0xc3,0x01,0xd1,0xfc,0x6f,0x01,0xa9,0xfa,0x67,0x02,0xa9,0xf8,0x5f,0x03,0xa9}},
 {"deconstructionStart",0x107713bb8ULL,{0xff,0x43,0x05,0xd1,0xfc,0x6f,0x0f,0xa9,0xfa,0x67,0x10,0xa9,0xf8,0x5f,0x11,0xa9}},
 {"operationCreate",0x10733a0fcULL,{0xfc,0x6f,0xba,0xa9,0xfa,0x67,0x01,0xa9,0xf8,0x5f,0x02,0xa9,0xf6,0x57,0x03,0xa9}},
 {"deconstructionFinished",0x107714434ULL,{0xff,0x03,0x01,0xd1,0xf6,0x57,0x01,0xa9,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9}},
};
[[noreturn]] void reject(const char *message){throw std::runtime_error(message);}
void thread(){if(!isBound() || !isGameThread())reject("Original GameThread required");}
void live(Object o){if(!o || Weak(o).get()!=o || (read<uint32_t>(o.address+8)&0x18030))reject("Live original gameplay object required");}
Object outer(Object o){live(o);return {read<uintptr_t>(o.address+FP2ObjectOuterOffset)};}
bool nativeClass(Object o,NSString *wanted){
    live(o);Object c=objectClass(o);std::set<uintptr_t> seen;
    for(unsigned n=0;c&&n<64;n++){
        if(!seen.insert(c.address).second)reject("Cyclic original class hierarchy");
        if([name(c) isEqual:wanted]){Object package=outer(c);return package&&[name(package) isEqual:@"/Script/Frostpunk2"];}
        c={read<uintptr_t>(c.address+FP2StructSuperOffset)};
    }
    return false;
}
void context(const Context &c){
    thread();if(!c.ready || c.controllerWeak.get()!=c.controller || c.worldWeak.get()!=c.world
        || c.cityWeak.get()!=c.city || c.nationWeak.get()!=c.nation)reject("Local city context changed");
    if(fp::worldOf(c.controller)!=c.world || fp::worldOf(c.city)!=c.world || linkedObject(c.city,@"Nation")!=c.nation)reject("Local city ownership differs");
}
struct API {
    intptr_t slide=0;
    template<class T>T fn(uintptr_t a)const{return reinterpret_cast<T>(a+slide);}
    void validate(){
        thread();uintptr_t anchor=binding("gameThreadCall");if(!anchor)reject("Die ursprüngliche Programmadressierung ist nicht verfügbar.");
        slide=(intptr_t)anchor-(intptr_t)0x10087a854ULL;
        for(const auto &b:operationBindings){uint8_t actual[16];if(!read(b.address+slide,actual,16)||memcmp(actual,b.bytes,16))reject("Original operation binding differs");}
    }
    bool code(uintptr_t p)const{return p>=0x10000e000ULL+slide && p<0x10976e924ULL+slide && (p&3)==0;}
    Object subsystem(const Context &c,uintptr_t getter,NSString *kind)const{
        Object cls{fn<uintptr_t(*)()>(getter)()};
        if(!cls || ![name(cls) isEqual:kind])reject("Original subsystem class differs");
        Object value{fn<uintptr_t(*)(const void *,const void *)>(0x103ddc2b4)((const void *)(c.world.address+0x880),(const void *)cls.address)};
        live(value);if(!isA(value,cls)||outer(value)!=c.world)reject("Subsystem belongs to another World");return value;
    }
    Object component(Object actor,uintptr_t getter,NSString *kind)const{
        live(actor);Object cls{fn<uintptr_t(*)()>(getter)()};
        uintptr_t table=read<uintptr_t>(actor.address),target=read<uintptr_t>(table+0x6f8);
        if(!code(target))reject("Original actor component virtual differs");
        uintptr_t klass=cls.address;
        Object value{((uintptr_t(*)(const void *,const uintptr_t *))target)((const void *)actor.address,&klass)};
        live(value);if(!isA(value,cls)||!nativeClass(value,kind)||read<uintptr_t>(value.address+0x90)!=actor.address
            || outer(value)!=actor)reject("Native component owner differs");
        return value;
    }
};
Object decode(id v){if(v==NSNull.null)return {};if(![v isKindOfClass:NSDictionary.class]||![v[@"object"] isKindOfClass:NSNumber.class])reject("Original getter returned no typed object");return object([v[@"object"] intValue]);}
Object owner(Object component){
    live(component);Object f=function(component,@"GetOwner");uint32_t flags=read<uint32_t>(f.address+FP2FunctionFlagsOffset);
    if(!(flags&0x400)||(flags&0x2000))reject("Component owner getter is not native instance API");
    Object value=decode(invoke(component,@"GetOwner",@{}));live(value);
    if(outer(component)!=value || read<uintptr_t>(component.address+0x90)!=value.address)reject("Component owner backlink differs");return value;
}
void propertyLayout(Object o,NSString *field,NSString *type,int32_t offset,int32_t size){
    Property p=property(o,field);if(![p.type isEqual:type]||p.offset!=offset||p.size!=size||p.count!=1)reject("Original operation property layout differs");
}
bool boolean(Object o,NSString *field){id v=readValue(o,property(o,field));if(![v isKindOfClass:NSNumber.class])reject("Die native Wahrheitswertrücklesung ist nicht verfügbar.");return [v boolValue];}
// Original PXOperationSubsystem.OnLogicTick enumerates this TSparseSet: 16-byte
// entries at +0x290; allocated-element bits inline +0x2a0 or pointer +0x2b0.
// +0x2e8 is an event delegate, not operation membership.
std::vector<Object> registered(Object subsystem){
    live(subsystem);uintptr_t elements=read<uintptr_t>(subsystem.address+0x290),external=read<uintptr_t>(subsystem.address+0x2b0);
    int32_t count=read<int32_t>(subsystem.address+0x298),bits=read<int32_t>(subsystem.address+0x2b8);
    if(count<0||count>65536||bits!=count||(!elements&&count)||(!external&&bits>128))reject("Die ursprüngliche Komponentenliste ist ungültig.");
    uintptr_t bitmap=external?external:subsystem.address+0x2a0;std::vector<Object> out;
    for(int32_t i=0;i<bits;i++)if(read<uint32_t>(bitmap+4*(uint32_t(i)>>5))&(1u<<(i&31))){
        Object value{read<uintptr_t>(elements+16*size_t(i))};live(value);out.push_back(value);
    }
    return out;
}
bool registered(Object subsystem,Object wanted){for(Object o:registered(subsystem))if(o==wanted)return true;return false;}
struct Generator {
    Object generator{},actor{},wear{},subsystem{};
    float value=0,minimum=0,maximum=0;bool broken=false;
};
Generator generator(const Context &c,const API &api){
    context(c);Generator g;g.generator=linkedObject(c.city,@"Generator");live(g.generator);
    if(!nativeClass(g.generator,@"PXGeneratorComponent"))reject("Selected city generator has a different native type");
    g.actor=owner(g.generator);if(fp::worldOf(g.actor)!=c.world)reject("Generator belongs to another World");
    g.wear=api.component(g.actor,0x1062d68a0,@"PXWearComponent");
    propertyLayout(g.wear,@"wear",@"FloatProperty",0xb8,4);propertyLayout(g.wear,@"bIsBroken",@"BoolProperty",0xbd,1);
    g.subsystem=api.subsystem(c,0x105f8482c,@"PXWearSubsystem");
    if(!registered(g.subsystem,g.wear))reject("Generator wear component is not registered in the local subsystem");
    using Get=float(*)(const void *);
    g.value=api.fn<Get>(0x1077897b4)((const void *)g.actor.address);
    g.minimum=api.fn<Get>(0x107789b04)((const void *)g.actor.address);
    g.maximum=api.fn<Get>(0x107789928)((const void *)g.actor.address);g.broken=boolean(g.wear,@"bIsBroken");
    if(!std::isfinite(g.value)||!std::isfinite(g.minimum)||!std::isfinite(g.maximum)||g.minimum!=0 || g.maximum<=0
        || g.value<g.minimum || g.value>g.maximum)reject("Original generator wear limits differ");
    return g;
}
struct WearLease {
    bool owned=false,releasing=false;Context c{};Weak generator{},actor{},wear{},subsystem{};Object generatorObject{},actorObject{},wearObject{},subsystemObject{};
    float baseline=0,last=0;bool broken=false;
} wearLease;
bool releaseWear(){
    if(!wearLease.owned)return true;
    wearLease.releasing=true;
    const WearLease old=wearLease;
    auto done=[](){wearLease=WearLease{};return true;};
    try{
        thread();
        // Expired native owners cannot be written through. A replacement controller
        // does not invalidate this old, independently identified generator lease.
        if(old.c.worldWeak.get()!=old.c.world || old.c.cityWeak.get()!=old.c.city || old.c.nationWeak.get()!=old.c.nation
            || old.generator.get()!=old.generatorObject || old.actor.get()!=old.actorObject
            || old.wear.get()!=old.wearObject || old.subsystem.get()!=old.subsystemObject)return done();
        API api;api.validate();
        if(fp::worldOf(old.c.city)!=old.c.world || fp::worldOf(old.actorObject)!=old.c.world
            || linkedObject(old.c.city,@"Nation")!=old.c.nation || linkedObject(old.c.city,@"Generator")!=old.generatorObject
            || owner(old.generatorObject)!=old.actorObject)return done();
        if(api.component(old.actorObject,0x1062d68a0,@"PXWearComponent")!=old.wearObject
            || api.subsystem(old.c,0x105f8482c,@"PXWearSubsystem")!=old.subsystemObject)return done();
        propertyLayout(old.wearObject,@"wear",@"FloatProperty",0xb8,4);
        propertyLayout(old.wearObject,@"bIsBroken",@"BoolProperty",0xbd,1);
        if(!registered(old.subsystemObject,old.wearObject))return false;
        using Get=float(*)(const void *);
        float value=api.fn<Get>(0x1077897b4)((const void *)old.actorObject.address);
        bool broken=boolean(old.wearObject,@"bIsBroken");
        if(!std::isfinite(value))return false;
        // A prior call may have restored the value before its readback failed.
        if(value==old.baseline && broken==old.broken)return done();
        if(value!=old.last && value!=old.baseline)return done(); // A different engine value is no longer ours.
        float minimum=api.fn<Get>(0x107789b04)((const void *)old.actorObject.address);
        float maximum=api.fn<Get>(0x107789928)((const void *)old.actorObject.address);
        if(!std::isfinite(minimum)||!std::isfinite(maximum)||old.baseline<minimum||old.baseline>maximum)return false;
        api.fn<void(*)(const void *,const void *,float)>(0x10778b94c)((const void *)old.subsystemObject.address,(const void *)old.wearObject.address,old.baseline);
        // Keep the lease on any failed call/readback so Loading polls can retry.
        if(old.wear.get()!=old.wearObject || old.actor.get()!=old.actorObject)return done();
        value=api.fn<Get>(0x1077897b4)((const void *)old.actorObject.address);
        if(value==old.baseline && boolean(old.wearObject,@"bIsBroken")==old.broken)return done();
    }catch(const std::exception &){}
    return false;
}
using Attempt=std::tuple<int32_t,int32_t,int32_t,int32_t>;
std::map<Attempt,Weak> attempted;
Result failure(Result r,const std::exception &e){r.confirmed=false;r.note=[NSString stringWithUTF8String:e.what()]?:@"Originale Operation nicht verfügbar.";return r;}
}
Result generatorWear(const Context &c,bool enabled){
    Result r;if(!enabled){
        if(!isGameThread()){r.note=@"Originaler GameThread für die Rücknahme erforderlich.";return r;}
        r.available=releaseWear();
        r.note=r.available?@"Generator-Verschleißbindung gelöst.":@"Eigene Generator-Verschleißrücknahme noch offen; wird erneut versucht.";
        return r;
    }
    try{
        context(c);API api;api.validate();
        if(wearLease.releasing && !releaseWear())reject("Previous generator wear restoration is pending");
        Generator g=generator(c,api);r.available=true;r.value=g.value;
        if(wearLease.owned&&(wearLease.c.city!=c.city||wearLease.c.world!=c.world||wearLease.wear.get()!=g.wear)){
            if(!releaseWear())reject("Previous generator wear restoration is pending");
            g=generator(c,api);
        }
        if(!wearLease.owned){wearLease.owned=true;wearLease.c=c;wearLease.generator=Weak(g.generator);wearLease.actor=Weak(g.actor);wearLease.wear=Weak(g.wear);wearLease.subsystem=Weak(g.subsystem);
            wearLease.generatorObject=g.generator;wearLease.actorObject=g.actor;wearLease.wearObject=g.wear;wearLease.subsystemObject=g.subsystem;wearLease.baseline=g.value;wearLease.broken=g.broken;wearLease.last=0;}
        context(c);if(g.value!=0){r.invoked=true;api.fn<void(*)(const void *,const void *,float)>(0x10778b94c)((const void *)g.subsystem.address,(const void *)g.wear.address,0);}
        Generator after=generator(c,api);r.value=after.value;r.confirmed=after.wear==g.wear&&after.generator==g.generator&&after.value==0&&!after.broken;
        r.note=r.confirmed?@"Generator-Verschleiß nativ bei null bestätigt.":@"Generator-Verschleiß nicht bestätigt.";
    }catch(const std::exception &e){return failure(r,e);}return r;
}
Result demolish(const Context &c,bool enabled){
    Result r;if(!enabled){r.available=true;r.note=@"Sofortabriss ausgeschaltet.";return r;}
    try{
        context(c);API api;api.validate();Object subsystem=api.subsystem(c,0x105b55b28,@"PXOperationSubsystem");
        Object economy=linkedObject(c.city,@"EconomyHolder"),workforce=linkedObject(c.city,@"WorkforceHolder");live(economy);live(workforce);
        auto operations=registered(subsystem);r.available=true;
        for(auto i=attempted.begin();i!=attempted.end();)if(!i->second.get())i=attempted.erase(i);else++i;
        unsigned completed=0,candidates=0,processed=0;
        for(Object operation:operations){
            if(!nativeClass(operation,@"PXOperationComponent"))reject("Registered operation type differs");
            Weak operationWeak(operation);
            propertyLayout(operation,@"TargetActor",@"ObjectProperty",0xe8,8);
            Object actor=linkedObject(operation,@"TargetActor");live(actor);
            if(fp::worldOf(operation)!=c.world || fp::worldOf(actor)!=c.world)continue;
            Object deconstruction{};try{deconstruction=api.component(actor,0x105a4fb34,@"PXDeconstructionComponent");}catch(const std::exception &){continue;}
            if(linkedObject(deconstruction,@"Operation")!=operation || linkedObject(deconstruction,@"TargetEconomyHolder")!=economy
                || linkedObject(deconstruction,@"TargetWorkforceHolder")!=workforce)continue;
            propertyLayout(deconstruction,@"Operation",@"ObjectProperty",0x270,8);propertyLayout(deconstruction,@"bIsFinished",@"BoolProperty",0x260,1);
            if(boolean(deconstruction,@"bIsFinished"))continue;
            using Flag=bool(*)(const void *);
            if(api.fn<Flag>(0x107339114)((const void *)operation.address)||api.fn<Flag>(0x10733917c)((const void *)operation.address)
                ||api.fn<Flag>(0x107339140)((const void *)operation.address))continue;
            candidates++;
            Attempt key{c.worldWeak.index,c.worldWeak.serial,operationWeak.index,operationWeak.serial};
            if(attempted.count(key))continue;if(attempted.size()>=4096)reject("Native operation replay guard reached its bound");
            Weak deconstructionWeak(deconstruction),subsystemWeak(subsystem);context(c);
            if(operationWeak.get()!=operation || deconstructionWeak.get()!=deconstruction || subsystemWeak.get()!=subsystem || !registered(subsystem,operation))continue;
            attempted.emplace(key,operationWeak);r.invoked=true;processed++;
            api.fn<void(*)(const void *,const void *)>(0x10733a7e0)((const void *)subsystem.address,(const void *)operation.address);
            if(deconstructionWeak.get()==deconstruction && boolean(deconstruction,@"bIsFinished")
                && !linkedObject(deconstruction,@"Operation"))completed++;
            if(processed>=32)break;
        }
        r.value=completed;r.confirmed=completed>0;
        r.note=completed?[NSString stringWithFormat:@"%u örtliche Abrissoperation(en) nativ beendet und zurückgelesen.",completed]
            :(candidates?@"Abrissauftrag bearbeitet; Wirkung noch nicht bestätigt.":@"Wartet auf einen aktiven Abrissauftrag der gewählten Stadt.");
    }catch(const std::exception &e){return failure(r,e);}return r;
}
Result council(const Context &c){
    Result r;try{
        context(c);API api;api.validate();Object subsystem=api.subsystem(c,0x105e7b328,@"PXParliamentSubsystem");
        using Get=uintptr_t(*)(const void *);Object parliament{api.fn<Get>(0x1075deb08)((const void *)c.controller.address)};live(parliament);
        if(!nativeClass(parliament,@"PXParliamentComponent")||linkedObject(parliament,@"City")!=c.city||fp::worldOf(parliament)!=c.world
            ||api.fn<Get>(0x1075e7510)((const void *)subsystem.address)!=parliament.address || !registered(subsystem,parliament))reject("Der aktuelle Rat gehört nicht zur ausgewählten lokalen Stadt.");
        propertyLayout(parliament,@"currentPhase",@"EnumProperty",0x1c0,1);propertyLayout(parliament,@"SessionIndex",@"IntProperty",0x1c4,4);
        uint8_t phase=read<uint8_t>(parliament.address+0x1c0);int32_t session=read<int32_t>(parliament.address+0x1c4);
        if(phase>4||session<0||session==INT32_MAX)reject("Die ursprüngliche Ratsphase oder Sitzung ist ungültig.");r.available=true;r.value=session;
        if(phase!=4){r.note=@"Keine Ratspause aktiv.";return r;}
        Weak parliamentWeak(parliament),subsystemWeak(subsystem);context(c);r.invoked=true;
        api.fn<void(*)(const void *)>(0x1075df800)((const void *)c.controller.address);
        if(parliamentWeak.get()!=parliament||subsystemWeak.get()!=subsystem)return failure(r,std::runtime_error("Council owner changed during native transition"));
        context(c);uint8_t afterPhase=read<uint8_t>(parliament.address+0x1c0);int32_t afterSession=read<int32_t>(parliament.address+0x1c4);
        r.value=afterSession;r.confirmed=afterPhase>=1&&afterPhase<=3&&afterSession==session+1&&linkedObject(parliament,@"City")==c.city;
        r.note=r.confirmed?@"Ratspause nativ beendet und neue Sitzung zurückgelesen.":@"Ratspausenwechsel nicht bestätigt; kein automatischer Wiederholungsversuch.";
    }catch(const std::exception &e){return failure(r,e);}return r;
}
bool release(){if(!isGameThread())return false;return releaseWear();}
bool hasPendingRelease(){return isGameThread() && wearLease.owned && wearLease.releasing;}
}
