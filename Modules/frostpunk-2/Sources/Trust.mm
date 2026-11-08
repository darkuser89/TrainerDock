// SPDX-License-Identifier: GPL-3.0-only
#import "Trust.hpp"
#import "CommunitySelection.hpp"
#import "GameBindings.h"
#import "ReflectionBindings.h"
#include <cmath>
#include <cstring>
#include <vector>
namespace fp::trust {
namespace {
struct Binding { uintptr_t address;uint8_t bytes[16]; };
// Exact original Steam24037022 UUID10F7F2EA-0D13-337E-BF07-ABA47A4549CF.
// GetTrustConfig returns MainConfig.TrustConfig(+248). The original relation
// getter loads MaximumCommunityTrust(+84) then MinimumCommunityTrust(+88),
// evaluates the optional original curve, clamps to maximum, then to minimum.
// CompareCommunityStandingWithTrait calls this SAME getter before assigning a
// gameplay trait. A min==max lease therefore affects genuine native rule reads.
// The config write itself does not emit standing-change events or rewrite
// cached totals; such behavior is not claimed by this implementation.
const Binding bindings[]={
 {UINT64_C(0x1066cd230),{0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x02,0xaa}},
 {UINT64_C(0x1075915e8),{0xeb,0x2b,0xbd,0x6d,0xe9,0x23,0x01,0x6d,0xfd,0x7b,0x02,0xa9,0xfd,0x83,0x00,0x91}},
 {UINT64_C(0x107591618),{0x38,0x54,0x08,0x94,0x08,0x24,0x41,0xf9,0x0a,0xa5,0x50,0x2d,0x00,0x51,0x40,0xf9}},
 {UINT64_C(0x107591654),{0x00,0x20,0x2a,0x1e,0x00,0x4c,0x2a,0x1e,0x20,0x21,0x20,0x1e,0x00,0x4c,0x29,0x1e}},
 {UINT64_C(0x10759b398),{0xc8,0x62,0x40,0xf9,0x48,0x03,0x00,0xb4,0x01,0x69,0x40,0xf9,0xe0,0x03,0x17,0xaa}},
 {UINT64_C(0x105f9f948),{0xff,0x83,0x01,0xd1,0xf4,0x4f,0x04,0xa9,0xfd,0x7b,0x05,0xa9,0xfd,0x43,0x01,0x91}},
 {UINT64_C(0x103ddc2b4),{0xf8,0x5f,0xbc,0xa9,0xf6,0x57,0x01,0xa9,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9}}
};
[[noreturn]]void fail(const char *message){throw std::runtime_error(message);}
void thread(){if(!isBound() || !isGameThread())fail("Original GameThread required for native relation lease");}
uintptr_t slide(){uintptr_t p=binding("processEvent");if(p<UINT64_C(0x100be2e78))fail("Original image relocation unavailable");return p-UINT64_C(0x100be2e78);}
void verifyBindings(){thread();uintptr_t s=slide();for(const auto &b:bindings){uint8_t bytes[16];if(!read(b.address+s,bytes,16)||memcmp(bytes,b.bytes,16))fail("Original trust config/getter instructions differ");}}
Object checked(uintptr_t p){if(!p)return {};Object o=object(read<int32_t>(p+FP2ObjectInternalIndexOffset));if(o.address!=p)fail("Stale original trust pointer");return o;}
void real(Object o){Weak w(o);if(!o || w.get()!=o || (read<uint32_t>(o.address+8)&0x18030))fail("Live original trust owner required");}
void context(const Context &c){
    if(!c.ready || c.playerWeak.get()!=c.localPlayer || c.controllerWeak.get()!=c.controller ||
       c.worldWeak.get()!=c.world || c.cityWeak.get()!=c.city || c.nationWeak.get()!=c.nation)
        fail("Current local trust context expired");
    if(linkedObject(c.city,@"Nation")!=c.nation)fail("Selected city's nation changed");
}
Object decode(id v){if(![v isKindOfClass:NSDictionary.class] || ![v[@"object"] isKindOfClass:NSNumber.class])fail("Original trust getter returned no object");return object([v[@"object"] intValue]);}
NSDictionary *arg(Object o){real(o);return @{@"object":@(read<int32_t>(o.address+FP2ObjectInternalIndexOffset))};}
Object method(Object cdo,NSString *name,uintptr_t expectedExec,const uint8_t *bytes){
    Object f=function(cdo,name);uint32_t flags=read<uint32_t>(f.address+FP2FunctionFlagsOffset);
    if((flags&0x2400)!=0x2400)fail("Trust utility is not an original static native function");
    uintptr_t exec=read<uintptr_t>(f.address+FP2FunctionNativeExecOffset);uint8_t actual[16];
    if(exec!=expectedExec+slide() || !read(exec,actual,16) || memcmp(actual,bytes,16))
        fail("Original static trust getter exec differs");
    return f;
}
Object config(){
    Object cdo=utility(@"PXGameplayUtils");
    method(cdo,@"GetTrustConfig",bindings[0].address,bindings[0].bytes);
    Object result=decode(invoke(cdo,@"GetTrustConfig",@{}));real(result);
    if(![className(result) isEqual:@"PXTrustConfig"])fail("Original trust config has an unexpected native class");
    return result;
}
Property floatProperty(Object o,NSString *name,int32_t offset){
    Property p=property(o,name);
    if(![p.type isEqual:@"FloatProperty"] || p.offset!=offset || p.size!=4 || p.count!=1)
        fail("Original community trust bound property differs");
    return p;
}
float value(Object o,const Property &p){
    id result=readValue(o,p);
    if(![result isKindOfClass:NSNumber.class] || !std::isfinite([result doubleValue]))fail("Original trust bound is not finite");
    return [result floatValue];
}
uint32_t bits(float value){uint32_t result;memcpy(&result,&value,4);return result;}
Object trustSubsystem(const Context &c){
    using ClassGetter=void *(*)();using Lookup=void *(*)(void *,void *);
    Object cls=checked((uintptr_t)((ClassGetter)(UINT64_C(0x105f9f948)+slide()))());
    if(!cls || ![name(cls) isEqual:@"PXTrustSubsystem"] || ![className(cls) isEqual:@"Class"])
        fail("Original trust subsystem class differs");
    Object owner=checked((uintptr_t)((Lookup)(UINT64_C(0x103ddc2b4)+slide()))((void *)(c.world.address+0x880),(void *)cls.address));real(owner);
    if(objectClass(owner)!=cls || checked(read<uintptr_t>(owner.address+FP2ObjectOuterOffset))!=c.world)
        fail("Trust subsystem is outside the current World's collection");
    return owner;
}
float standing(const Context &c,Object community){
    Object cdo=utility(@"PXTrustUtils");const FPGameBinding *expected=nullptr;
    for(const auto &b:FPGameBindings)if(!strcmp(b.name,"exec.GetCommunityStanding")){expected=&b;break;}
    if(!expected)fail("Original community standing getter binding absent");
    Object fn=method(cdo,@"GetCommunityStanding",expected->address,expected->bytes16);
    NSDictionary *input=@{@"worldcontextobject":arg(c.controller),@"nation":arg(c.nation),@"community":arg(community)};
    NSMutableDictionary *arguments=[NSMutableDictionary new];
    for(const Property &p:properties(fn))if(!(p.flags&0x400)){
        id v=input[p.name.lowercaseString];if(!v)fail("Unexpected native standing argument");arguments[p.name]=v;
    }
    if(arguments.count!=3)fail("Original standing argument count differs");
    id result=invoke(cdo,@"GetCommunityStanding",arguments);
    if(![result isKindOfClass:NSNumber.class] || !std::isfinite([result doubleValue]))fail("Native standing getter returned no finite scalar");
    return [result floatValue];
}
struct BoundLease {
    Weak configWeak,worldWeak;Property minimum{};bool attached=false,owned=false;
    float original=0,written=0;
    bool release(){
        if(!attached)return true;
        Object c=configWeak.get();if(!c){attached=false;owned=false;return true;}
        Property fresh=floatProperty(c,@"MinimumCommunityTrust",0x88);
        if(fresh.address!=minimum.address || fresh.ownerClass!=minimum.ownerClass)fail("Leased trust bound metadata changed");
        // The config is shared beyond a World lifetime. It must still be
        // restored if its old World has expired, provided this is still our
        // exact write. External bit patterns (including NaN) are left untouched.
        uint32_t current=read<uint32_t>(c.address+fresh.offset);
        if(owned && current==bits(written)){
            if(!writeValue(c,fresh,@(original)) || read<uint32_t>(c.address+fresh.offset)!=bits(original))
                fail("Original trust bound restoration did not read back");
        }
        attached=false;owned=false;return true;
    }
    void acquire(Object c,Object world,float target){
        if(attached && (configWeak.get()!=c || worldWeak.get()!=world))release();
        Property p=floatProperty(c,@"MinimumCommunityTrust",0x88);
        float current=value(c,p);
        if(!attached){configWeak=Weak(c);worldWeak=Weak(world);minimum=p;original=current;attached=true;owned=false;}
        if(owned && bits(current)!=bits(written)){owned=false;original=current;}
        if(bits(current)!=bits(target)){
            if(!owned)original=current;
            owned=true;written=target;
            if(!writeValue(c,p,@(target)) || bits(value(c,p))!=bits(target))fail("Original trust floor write did not read back");
        }
    }
} lease;
NSString *identity=@"";
}
bool releaseOwnEffects(){
    if(!isBound() || !isGameThread())return false;
    try{verifyBindings();lease.release();identity=@"";return true;}catch(const std::exception &){return false;}
}
Result apply(const Context &c,bool wanted){
    Result result;
    try{
        verifyBindings();
        if(![identity isEqual:c.identity ?: @""]){if(!releaseOwnEffects())fail("Previous global relation floor awaits safe restoration");identity=[c.identity copy] ?: @"";}
        if(!wanted){if(!releaseOwnEffects())fail("Owned global relation floor could not yet be restored");result.available=c.ready;result.note=@"Eigene globale Beziehungsgrenze freigegeben.";return result;}
        context(c);Object cfg=config(),subsystem=trustSubsystem(c);Weak cfgWeak(cfg),subsystemWeak(subsystem);
        Property maximum=floatProperty(cfg,@"MaximumCommunityTrust",0x84),minimum=floatProperty(cfg,@"MinimumCommunityTrust",0x88);
        float target=value(cfg,maximum),low=value(cfg,minimum);
        bool ourFloor=lease.attached && lease.configWeak.get()==cfg && lease.owned && bits(low)==bits(lease.written);
        if(low>target && !ourFloor)fail("Original community trust bounds are inconsistent");
        auto communities=listLocalCommunities(c);
        if(communities.empty())fail("No existing local community can confirm the global relation floor");
        std::vector<Weak> members;for(Object member:communities)members.emplace_back(member);
        try{
            lease.acquire(cfg,c.world,target);
            context(c);
            for(size_t i=0;i<communities.size();i++){
                if(members[i].get()!=communities[i] || standing(c,communities[i])!=target)
                    fail("An original local community relation differs from the native maximum");
                result.checkedCommunities++;
            }
            auto fresh=listLocalCommunities(c);
            if(fresh!=communities || cfgWeak.get()!=cfg || subsystemWeak.get()!=subsystem || config()!=cfg ||
               value(cfg,maximum)!=target || value(cfg,minimum)!=target)
                fail("Native config/context changed during global relation verification");
        }catch(const std::exception &){lease.release();throw;}
        result.maximum=target;result.available=true;result.active=true;
        result.note=[NSString stringWithFormat:@"Beziehungen global auf nativen Höchstwert begrenzt; %zu Stadtgemeinschaften zurückgelesen.",result.checkedCommunities];
    }catch(const std::exception &e){
        result.available=false;result.active=false;
        result.note=[NSString stringWithUTF8String:e.what()] ?: @"Globale native Beziehungsgrenze nicht verfügbar.";
        try{lease.release();}catch(const std::exception &){result.note=[result.note stringByAppendingString:@" Eigene Grenzwert-Rücknahme steht noch aus."];}
    }
    return result;
}
}
