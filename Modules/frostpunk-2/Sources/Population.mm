// SPDX-License-Identifier: GPL-3.0-only
#import "Population.hpp"
#include <array>
#include <climits>
#include <cstddef>
#include <cstring>
#include <stdexcept>
namespace {
struct CodeBinding {const char *name;uintptr_t address;uint8_t bytes[16];};
// Exact Steam 24037022 / UUID 10F7F2EA-0D13-337E-BF07-ABA47A4549CF.
// UHT descriptor 0x10bc2a048 registers this 72-byte, 8-aligned native struct
// and the original factory; its returned vtable is 0x10bc2b260 before sliding.
static const CodeBinding populationBindings[]={
 {"paramsOpsFactory",0x105a441f4ULL,{0xfd,0x7b,0xbf,0xa9,0xfd,0x03,0x00,0x91,0x00,0x02,0x80,0x52,0x8a,0xae,0x43,0x94}},
 {"paramsConstruct",0x105a4478cULL,{0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x01,0xaa}},
 {"paramsDestruct",0x105a4482cULL,{0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x01,0xaa}},
 {"paramsOpsDelete",0x105a44778ULL,{0x4c,0xad,0x43,0x14,0x00,0x00,0x80,0xd2,0x01,0x01,0x80,0xd2,0x81,0x00,0xc4,0xf2}},
 {"textDefault",0x10081f5e4ULL,{0xef,0x1d,0x00,0x14,0x6b,0xff,0xff,0x17,0xff,0xc3,0x00,0xd1,0xf4,0x4f,0x01,0xa9}},
 {"textDefaultBody",0x100826da0ULL,{0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0xf3,0x03,0x00,0xaa}},
 {"changeCommunitySize",0x10717ad00ULL,{0xff,0x03,0x03,0xd1,0xfc,0x6f,0x06,0xa9,0xfa,0x67,0x07,0xa9,0xf8,0x5f,0x08,0xa9}},
 {"getCommunitySize",0x10717a37cULL,{0xff,0x43,0x01,0xd1,0xf6,0x57,0x02,0xa9,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9}},
 {"cityClass",0x1068f0cc4ULL,{0xff,0x83,0x01,0xd1,0xf4,0x4f,0x04,0xa9,0xfd,0x7b,0x05,0xa9,0xfd,0x43,0x01,0x91}},
 {"communityTypeClass",0x105f51ab0ULL,{0xff,0x83,0x01,0xd1,0xf4,0x4f,0x04,0xa9,0xfd,0x7b,0x05,0xa9,0xfd,0x43,0x01,0x91}},
 {"changeExistingCommunitySize",0x10716e5c4ULL,{0xff,0xc3,0x04,0xd1,0xfc,0x6f,0x0d,0xa9,0xfa,0x67,0x0e,0xa9,0xf8,0x5f,0x0f,0xa9}},
};
struct alignas(8) NativeParameters {
    uint8_t changeType;uint8_t reserved0[7];
    uintptr_t city,communityType;
    uint8_t reason[16]; // Original-constructed FText, never zero-initialized by us.
    bool silent,deathPenalty,allowKilling;uint8_t reserved1;
    int32_t minimumRemaining;
    uintptr_t districts;int32_t districtCount,districtCapacity;
    uint8_t killType;uint8_t reserved2[7];
};
static_assert(sizeof(NativeParameters)==72 && alignof(NativeParameters)==8);
static_assert(offsetof(NativeParameters,reason)==24 && offsetof(NativeParameters,silent)==40);
static_assert(offsetof(NativeParameters,minimumRemaining)==44 && offsetof(NativeParameters,districts)==48);
static_assert(offsetof(NativeParameters,killType)==64);
struct API {
    using Factory=void *(*)();using Lifetime=void(*)(void *,void *);using Delete=void(*)(void *);
    using Change=int32_t(*)(const void *,int32_t,NativeParameters *);
    using Count=int32_t(*)(const void *,const void *,const void *);using Class=uintptr_t(*)();
    intptr_t slide=0;Factory factory=nullptr;Lifetime construct=nullptr,destruct=nullptr;
    Delete destroyOps=nullptr;Change change=nullptr;Count count=nullptr;Class cityClass=nullptr,typeClass=nullptr;
    bool resolve() {
        uintptr_t thread=fp::binding("gameThreadCall");if(!thread)return false;
        slide=(intptr_t)thread-(intptr_t)0x10087a854ULL;
        for(const auto &b:populationBindings) {
            uint8_t actual[16];if(!fp::read(b.address+slide,actual,sizeof(actual)) || std::memcmp(actual,b.bytes,16))return false;
        }
        factory=(Factory)(0x105a441f4ULL+slide);construct=(Lifetime)(0x105a4478cULL+slide);
        destruct=(Lifetime)(0x105a4482cULL+slide);destroyOps=(Delete)(0x105a44778ULL+slide);
        change=(Change)(0x10717ad00ULL+slide);count=(Count)(0x10717a37cULL+slide);
        cityClass=(Class)(0x1068f0cc4ULL+slide);typeClass=(Class)(0x105f51ab0ULL+slide);
        return true;
    }
};
class Parameters {
    const API &api;void *ops=nullptr;bool constructed=false;
public:
    NativeParameters value; // Original placement constructor initializes every field.
    explicit Parameters(const API &native):api(native) {
        ops=api.factory();if(!ops)throw std::runtime_error("Original struct ops allocation failed");
        uintptr_t table=0;uint32_t size=0,alignment=0;
        if(!fp::read((uintptr_t)ops,&table,8) || !fp::read((uintptr_t)ops+8,&size,4)
            || !fp::read((uintptr_t)ops+12,&alignment,4) || table!=0x10bc2b260ULL+api.slide || size!=72 || alignment!=8) {
            api.destroyOps(ops);ops=nullptr;throw std::runtime_error("Original population ops differ");
        }
        api.construct(ops,&value);constructed=true;
    }
    ~Parameters(){if(constructed)api.destruct(ops,&value);if(ops)api.destroyOps(ops);}
    Parameters(const Parameters &)=delete;Parameters &operator=(const Parameters &)=delete;
};
}
bool FPChangeCommunityPopulation(fp::Object world,fp::Object city,fp::Object type,int32_t delta,int32_t *actualDelta) {
    if(actualDelta)*actualDelta=0;
    if(!fp::isBound() || !fp::isGameThread() || !world || !city || !type || (int64_t)delta < -100000 || (int64_t)delta > 100000)return false;
    try {
        API api;if(!api.resolve())return false;
        fp::Weak worldLease(world),cityLease(city),typeLease(type);
        if(!fp::isA(city,{api.cityClass()}) || !fp::isA(type,{api.typeClass()}))return false;
        auto current=[&]{return worldLease.get()==world && cityLease.get()==city && typeLease.get()==type;};
        if(!current())return false;
        int32_t before=api.count((const void *)world.address,(const void *)city.address,(const void *)type.address);
        int64_t target=(int64_t)before+delta;
        if(before<=0 || target<1 || target>INT_MAX)return false;
        if(delta==0)return current(); // Native readback already confirms unchanged size.
        Parameters parameters(api);
        // This is the exact native debug-change path used by the original game's
        // own caller at 0x10749d858. Signed changes retain at least one member.
        parameters.value.changeType=3;parameters.value.city=city.address;parameters.value.communityType=type.address;
        parameters.value.silent=true;parameters.value.deathPenalty=false;parameters.value.allowKilling=false;
        parameters.value.minimumRemaining=1;parameters.value.killType=0;
        if(!current() || api.count((const void *)world.address,(const void *)city.address,(const void *)type.address)!=before)return false;
        // The original ABI passes this nontrivial 72-byte value indirectly in x2.
        // Its original callers own and destroy their temporary after the call;
        // this original-constructed temporary has the same single-owner lifetime.
        int32_t applied=api.change((const void *)world.address,delta,&parameters.value);
        if(!current())return false;
        int32_t after=api.count((const void *)world.address,(const void *)city.address,(const void *)type.address);
        if(after<0)return false;
        int32_t observed=after-before;
        if(actualDelta)*actualDelta=observed; // Readback wins even for a partial effect.
        return after>=1 && after==target && observed==delta && applied==observed;
    }catch(const std::exception &){return false;}
}

bool FPAddCommunityPopulation(fp::Object world,fp::Object city,fp::Object type,int32_t amount,int32_t *actualDelta) {
    if(amount<=0){if(actualDelta)*actualDelta=0;return false;}
    return FPChangeCommunityPopulation(world,city,type,amount,actualDelta);
}
