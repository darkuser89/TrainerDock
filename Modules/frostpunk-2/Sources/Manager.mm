// SPDX-License-Identifier: GPL-3.0-only
#import "Manager.hpp"
#import "Context.hpp"
#import "GameBindings.h"
#import "ReflectionBindings.h"
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <stdexcept>
namespace fp {
namespace {
[[noreturn]]void fail(const char *message){throw std::runtime_error(message);}
void real(Object o){
    Weak weak(o);
    if(!o || weak.get()!=o || (read<uint32_t>(o.address+8)&0x18030))
        fail("Real nondefault gameplay owner required");
}
void controllerCheck(Object controller){
    real(controller);
    id local=invoke(controller,@"IsLocalPlayerController",@{});
    if(![local isKindOfClass:NSNumber.class] || ![local boolValue])
        fail("Cheat manager requires the original local controller");
    Object player=linkedObject(controller,@"Player");real(player);
    if(![className(player) isEqual:@"LocalPlayer"] || linkedObject(player,@"PlayerController")!=controller)
        fail("Original local player/controller backlinks differ");
}
bool managerType(Object manager){
    std::set<uintptr_t> seen;
    Object c=objectClass(manager);
    for(unsigned n=0;c && n<64;n++){
        if(!seen.insert(c.address).second)fail("Cyclic native manager class hierarchy");
        if([name(c) isEqual:@"PXCheatManager"]){
            Object package{read<uintptr_t>(c.address+FP2ObjectOuterOffset)};
            return package && [name(package) isEqual:@"/Script/Frostpunk2"];
        }
        c={read<uintptr_t>(c.address+FP2StructSuperOffset)};
    }
    return false;
}
Object managerFor(Object controller){
    Property field=property(controller,@"CheatManager");
    if(![field.type isEqual:@"ObjectProperty"] || field.offset!=0x3f8 || field.size!=8 || field.count!=1)
        fail("Original controller CheatManager property differs");
    Object manager=linkedObject(controller,@"CheatManager");
    if(!manager)return {};
    real(manager);
    if(!managerType(manager) || !isA(manager,field.objectClass))
        fail("Controller manager has an unexpected native class");
    if(read<uintptr_t>(manager.address+FP2ObjectOuterOffset)!=controller.address)
        fail("Native cheat manager is owned by a different controller");
    return manager;
}
uintptr_t relocation(){
    uintptr_t pe=binding("processEvent");
    if(pe<UINT64_C(0x100be2e78))fail("Original executable relocation unavailable");
    return pe-UINT64_C(0x100be2e78);
}
void signature(uintptr_t address,const uint8_t (&expected)[16]){
    uint8_t bytes[16];
    if(!read(address,bytes,sizeof(bytes)) || memcmp(bytes,expected,sizeof(bytes)))
        fail("Original object creation/property setter instructions differ");
}
Object checked(uintptr_t address){
    if(!address)return {};
    Object o=object(read<int32_t>(address+FP2ObjectInternalIndexOffset));
    if(o.address!=address)fail("Original object pointer is stale");
    return o;
}
Object engineUtility(NSString *type){
    static std::map<std::string,Weak> cached;
    std::string key=type.UTF8String ?: "";
    auto saved=cached.find(key);
    if(saved!=cached.end()){
        Object o=saved->second.get();
        if(o)return o;
        cached.erase(saved);
    }
    Object selected{};NSString *wanted=[@"Default__" stringByAppendingString:type];
    for(Object o:find(type,wanted,32)){
        if(![className(o) isEqual:type] || ![name(o) isEqual:wanted] || !(read<uint32_t>(o.address+8)&0x10))continue;
        Object c=objectClass(o),package=checked(read<uintptr_t>(c.address+FP2ObjectOuterOffset));
        if(![className(c) isEqual:@"Class"] || ![name(c) isEqual:type] || !package || ![name(package) isEqual:@"/Script/Engine"])continue;
        if(selected)fail("Ambiguous original engine utility CDO");
        selected=o;
    }
    if(!selected)fail("Original engine utility CDO unavailable");
    cached.emplace(key,Weak(selected));return selected;
}
struct Parameter { NSString *name,*type;int32_t offset,size;bool result; };
Object typedMethod(Object cdo,NSString *name,uintptr_t originalExec,
                   const uint8_t (&bytes)[16],const Parameter (&expected)[3]){
    Object f=function(cdo,name);
    uint32_t flags=read<uint32_t>(f.address+FP2FunctionFlagsOffset);
    if((flags&0x2400)!=0x2400 || !(read<uint32_t>(cdo.address+8)&0x10))
        fail("Object factory/property setter must be an original static native method");
    if(read<uint16_t>(f.address+FP2FunctionParameterSizeOffset)!=24)
        fail("Original object factory/property setter parameter size differs");
    auto ps=properties(f);
    if(ps.size()!=3)fail("Original typed method parameter count differs");
    for(const Parameter &e:expected){
        const Property *found=nullptr;
        for(const Property &p:ps)if([p.name caseInsensitiveCompare:e.name]==NSOrderedSame){
            if(found)fail("Duplicate typed method parameter");found=&p;
        }
        if(!found || ![found->type isEqual:e.type] || found->offset!=e.offset ||
           found->size!=e.size || found->count!=1 || !(found->flags&0x80) ||
           bool(found->flags&0x400)!=e.result || (found->flags&0x8000000) ||
           (!e.result && (found->flags&0x100)))
            fail("Original typed object method parameter layout differs");
    }
    uintptr_t exec=read<uintptr_t>(f.address+FP2FunctionNativeExecOffset);
    if(exec!=originalExec+relocation())fail("Original typed object method exec differs");
    signature(exec,bytes);return f;
}
Object nativeManagerClass(Object controller){
    Property cheatClass=property(controller,@"CheatClass");
    if(![cheatClass.type isEqual:@"ClassProperty"] || cheatClass.offset!=0x400 || cheatClass.size!=8 || cheatClass.count!=1)
        fail("Original controller CheatClass property differs");
    Object configured=checked(read<uintptr_t>(controller.address+cheatClass.offset));
    // The native singleton is a source of the actual UClass; it does not create
    // a manager and is never treated as an instance receiver.
    const FPGameBinding *binding=nullptr;
    for(const auto &b:FPGameBindings)if(!strcmp(b.name,"class.PXCheatManager")){binding=&b;break;}
    if(!binding)fail("Native PXCheatManager class singleton binding absent");
    uintptr_t getClass=binding->address+relocation();signature(getClass,binding->bytes16);
    using ClassGetter=void *(*)();
    Object native=checked((uintptr_t)((ClassGetter)getClass)());
    if(!native || ![className(native) isEqual:@"Class"] || ![name(native) isEqual:@"PXCheatManager"])
        fail("Native PXCheatManager class singleton differs");
    Object package=checked(read<uintptr_t>(native.address+FP2ObjectOuterOffset));
    if(!package || ![name(package) isEqual:@"/Script/Frostpunk2"])
        fail("Native PXCheatManager class package differs");
    if(configured){
        NSString *type=className(configured);
        if(![type isEqual:@"Class"] && ![type isEqual:@"BlueprintGeneratedClass"])
            fail("Configured CheatClass is not an original UClass");
        Object c=configured;std::set<uintptr_t> seen;
        for(unsigned n=0;c && n<64;n++){
            if(!seen.insert(c.address).second)fail("Cyclic configured manager class hierarchy");
            if(c==native)return configured;
            c=checked(read<uintptr_t>(c.address+FP2StructSuperOffset));
        }
        fail("Controller CheatClass is outside the original PXCheatManager hierarchy");
    }
    return native;
}
Object createAndAttach(Object controller){
    Object gameplay=engineUtility(@"GameplayStatics"),system=engineUtility(@"KismetSystemLibrary");
    static const uint8_t spawnBytes[16]={0xff,0x03,0x01,0xd1,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9,0xfd,0xc3,0x00,0x91};
    static const uint8_t setBytes[16]={0xff,0x43,0x01,0xd1,0xf6,0x57,0x02,0xa9,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9};
    const Parameter spawnLayout[3]={{@"ObjectClass",@"ClassProperty",0,8,false},
        {@"Outer",@"ObjectProperty",8,8,false},{@"ReturnValue",@"ObjectProperty",16,8,true}};
    const Parameter setLayout[3]={{@"Object",@"ObjectProperty",0,8,false},
        {@"PropertyName",@"NameProperty",8,8,false},{@"Value",@"ObjectProperty",16,8,false}};
    Object spawn=typedMethod(gameplay,@"SpawnObject",UINT64_C(0x103680660),spawnBytes,spawnLayout);
    Object set=typedMethod(system,@"SetObjectPropertyByName",UINT64_C(0x1037f5be4),setBytes,setLayout);
    Object klass=nativeManagerClass(controller);
    for(const Property &p:properties(spawn)){
        if([p.type isEqual:@"ClassProperty"]){
            Object propertyClass=checked(read<uintptr_t>(p.address+0x70));
            Object metaClass=checked(read<uintptr_t>(p.address+0x78));
            if(!propertyClass || !metaClass || ![name(propertyClass) isEqual:@"Class"] ||
               ![name(metaClass) isEqual:@"Object"] || !isA(klass,propertyClass))
                fail("Original factory class parameter metaclass differs");
        }else if(!(p.flags&0x400) && (!p.objectClass || !isA(controller,p.objectClass)))
            fail("Original factory outer parameter rejects controller class");
    }
    Property field=property(controller,@"CheatManager");
    if(![field.type isEqual:@"ObjectProperty"] || !field.objectClass || field.offset!=0x3f8 || field.size!=8 || field.count!=1)
        fail("Original controller manager reference differs");
    // FName is copied from the ORIGINAL FProperty. No string-to-name conversion
    // or hardcoded name-table index participates in the typed setter call.
    uint32_t fieldName[2]{};
    if(!read(field.address+FP2FieldNameOffset,fieldName,sizeof(fieldName)) ||
       ![fname(field.address+FP2FieldNameOffset) isEqual:field.name])fail("Original manager property FName differs");
    struct SpawnParameters { uintptr_t objectClass,outer,result; };
    struct SetParameters { uintptr_t object;uint32_t nameIndex,nameNumber;uintptr_t value; };
    static_assert(sizeof(SpawnParameters)==24 && sizeof(SetParameters)==24,"Original typed parameter ABI");
    Weak pcWeak(controller),classWeak(klass),spawnWeak(spawn),setWeak(set),gameplayWeak(gameplay),systemWeak(system);
    controllerCheck(controller);
    if(managerFor(controller))fail("Controller acquired a manager before creation");
    alignas(16) SpawnParameters parameters{klass.address,controller.address,0};
    auto process=(FP2ProcessEvent)fp::binding("processEvent");
    process((void *)gameplay.address,(void *)spawn.address,&parameters);
    Object manager=checked(parameters.result);real(manager);Weak managerWeak(manager);
    if(objectClass(manager)!=klass || !isA(manager,field.objectClass) ||
       read<uintptr_t>(manager.address+FP2ObjectOuterOffset)!=controller.address)
        fail("Original object factory returned a different manager class/owner");
    if(pcWeak.get()!=controller || classWeak.get()!=klass || spawnWeak.get()!=spawn ||
       setWeak.get()!=set || gameplayWeak.get()!=gameplay || systemWeak.get()!=system)
        fail("Original owner or method expired during manager creation");
    controllerCheck(controller);
    if(managerFor(controller))fail("Controller acquired another manager during creation");
    Property fresh=property(controller,@"CheatManager");
    if(fresh.address!=field.address || fresh.offset!=field.offset || fresh.objectClass!=field.objectClass)
        fail("Controller manager property changed during creation");
    alignas(16) SetParameters assignment{controller.address,fieldName[0],fieldName[1],manager.address};
    process((void *)system.address,(void *)set.address,&assignment);
    if(pcWeak.get()!=controller || managerWeak.get()!=manager || managerFor(controller)!=manager)
        fail("Original reflected manager assignment did not read back");
    // The original native getter independently confirms its controller outer.
    id owning=invoke(manager,@"GetPlayerController",@{});
    if(![owning isKindOfClass:NSDictionary.class] || ![owning[@"object"] isKindOfClass:NSNumber.class] ||
       object([owning[@"object"] intValue])!=controller)
        fail("Original manager/controller getter did not read back");
    return manager;
}
}
ManagerResult ensureCheatManager(Object controller){
    ManagerResult result;
    try{
        if(!isBound() || !isGameThread())fail("Original GameThread required");
        controllerCheck(controller);result.controllerWeak=Weak(controller);
        Object manager=managerFor(controller);
        if(manager){
            Weak weak(manager);
            controllerCheck(controller);
            if(result.controllerWeak.get()!=controller || weak.get()!=manager || managerFor(controller)!=manager)
                fail("Native cheat manager owner changed");
            result.manager=manager;result.managerWeak=weak;result.ready=true;
            return result;
        }
        result.initializationAttempted=true;
        manager=createAndAttach(controller);
        if(result.controllerWeak.get()!=controller || managerFor(controller)!=manager)
            fail("Native manager owner changed after initialization");
        result.manager=manager;result.managerWeak=Weak(manager);result.ready=true;
    }catch(const std::exception &e){
        result.reason=[NSString stringWithUTF8String:e.what()] ?: @"Native cheat manager unavailable";
    }
    return result;
}
}
