// SPDX-License-Identifier: GPL-3.0-only
#import "CommunitySelection.hpp"
#import "ReflectionBindings.h"
#include <cstring>
#include <set>
#include <stdexcept>
namespace fp {
namespace {
struct Binding { uintptr_t address; uint8_t bytes[16]; };
// Exact original UUID 10F7F2EA-0D13-337E-BF07-ABA47A4549CF / Steam 24037022.
// FArrayProperty constructor writes ArrayFlags byte+0x70, Inner pointer+0x78.
// Original holder GetTotalCommunitiesSize reads data+0xb0/count+0xb8,
// indexing pointers at stride 8; GetCommunityType returns component+0xb0.
static const Binding bindings[]={
 {0x100b69688ULL,{0x7f,0x3e,0x00,0xf9,0x7f,0xc2,0x01,0x39,0xe8,0xed,0x04,0xb0,0x00,0xa9,0x45,0xfd}},
 {0x100b69718ULL,{0x38,0xf5,0xff,0x97,0xc4,0xe3,0x05,0x90,0x84,0xe0,0x05,0x91,0x80,0x00,0x01,0x91}},
 {0x1071772fcULL,{0x09,0xb8,0x80,0xb9,0x29,0x01,0x00,0x34,0x0a,0x58,0x40,0xf9,0x28,0x05,0x00,0xd1}},
 {0x106734c08ULL,{0x28,0x10,0x40,0xf9,0x1f,0x01,0x00,0xf1,0x08,0x05,0x88,0x9a,0x28,0x10,0x00,0xf9}},
 // The faction card uses the World's PXUtopiaToolPanelsSubsystem, not the
 // ParliamentSeatSubsystem selection exposed by PXSelectionUtils.
 {0x1063114fcULL,{0xff,0xc3,0x00,0xd1,0xf4,0x4f,0x01,0xa9,0xfd,0x7b,0x02,0xa9,0xfd,0x83,0x00,0x91}},
 {0x106b58c90ULL,{0xff,0x03,0x01,0xd1,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9,0xfd,0xc3,0x00,0x91}},
 {0x105ad6030ULL,{0xff,0x83,0x01,0xd1,0xf4,0x4f,0x04,0xa9,0xfd,0x7b,0x05,0xa9,0xfd,0x43,0x01,0x91}},
 {0x106bfa24cULL,{0x00,0x8c,0x40,0xf9,0xc0,0x03,0x5f,0xd6,0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9}},
};
struct Array {uintptr_t data;int32_t count,capacity;};
static_assert(sizeof(Array)==16 && offsetof(Array,count)==8 && offsetof(Array,capacity)==12);
[[noreturn]]void reject(const char *message){throw std::runtime_error(message);}
void requireThread(){if(!isBound()||!isGameThread())reject("Community resolution requires the original GameThread");}
void verifyBindings(){
    requireThread();
    uintptr_t anchor=binding("processEvent");if(!anchor)reject("Die ursprüngliche Metadatenanbindung ist nicht verfügbar.");
    intptr_t slide=(intptr_t)anchor-(intptr_t)0x100be2e78ULL;
    for(const auto &b:bindings){uint8_t actual[16];if(!read(b.address+slide,actual,16)||memcmp(actual,b.bytes,16))reject("Original community metadata binding differs");}
}
void real(Object o,NSString *type){
    if(!o || ![className(o) isEqual:type] || (read<uint32_t>(o.address+8)&0x18030) || [name(o) hasPrefix:@"Default__"])
        reject("Expected a live original community object");
}
void context(const Context &c){
    requireThread();if(!c.ready || c.playerWeak.get()!=c.localPlayer || c.controllerWeak.get()!=c.controller || c.worldWeak.get()!=c.world || c.cityWeak.get()!=c.city || c.nationWeak.get()!=c.nation)
        reject("Local city context expired");
    real(c.city,@"PXCityComponent");real(c.nation,@"PXNationComponent");
    if(linkedObject(c.city,@"Nation")!=c.nation)reject("City nation changed");
}
Object decode(id result){
    if(result==NSNull.null)return {};
    if(![result isKindOfClass:NSDictionary.class] || ![result[@"object"] isKindOfClass:NSNumber.class])reject("Original getter returned an unsupported value");
    return object([result[@"object"] intValue]);
}
NSDictionary *argument(Object o){return @{@"object":@(read<int32_t>(o.address+FP2ObjectInternalIndexOffset))};}
Object pointerObject(uintptr_t p){
    if(!p)reject("Null original community array member");
    Object o=object(read<int32_t>(p+FP2ObjectInternalIndexOffset));if(o.address!=p)reject("Community array member index changed");return o;
}
bool enabled(Object o){id result=invoke(o,@"IsComponentEnabled",@{});if(![result isKindOfClass:NSNumber.class])reject("Original component enabled getter has unexpected type");return [result boolValue];}
}
Object communityType(Object community){
    verifyBindings();real(community,@"PXCommunityComponent");
    Weak lease(community);Object type=decode(invoke(community,@"GetCommunityType",@{}));
    real(type,@"PXCommunityType");
    if(linkedObject(community,@"Type")!=type || lease.get()!=community)reject("Community type changed");
    return type;
}
std::vector<Object> listLocalCommunities(const Context &c){
    verifyBindings();context(c);
    Object holder=linkedObject(c.city,@"CommunitiesHolder");real(holder,@"PXCommunitiesHolderComponent");Weak holderLease(holder);
    if(decode(invoke(holder,@"GetParentCity",@{}))!=c.city)reject("Communities holder belongs to another city");
    Property p=property(holder,@"Communities");
    if(![p.type isEqual:@"ArrayProperty"] || p.count!=1 || p.size!=16 || p.offset!=176)
        reject("Original communities array metadata differs");
    uintptr_t inner=read<uintptr_t>(p.address+0x78),innerClass=inner?read<uintptr_t>(inner+FP2FieldClassOffset):0;
    if(!innerClass || ![fname(innerClass) isEqual:@"ObjectProperty"] || read<int32_t>(inner+FP2PropertyElementSizeOffset)!=8 || read<int32_t>(inner+FP2PropertyArrayDimOffset)!=1)
        reject("Communities array does not contain original object pointers");
    Object expected=pointerObject(read<uintptr_t>(inner+0x70));
    if(![name(expected) isEqual:@"PXCommunityComponent"] || ![className(expected) isEqual:@"Class"])
        reject("Community array element class differs");
    // FFieldVariant owner for an inner property is the containing FArrayProperty,
    // without the UObject tag. This prevents using an unrelated inner descriptor.
    if(read<uintptr_t>(inner+FP2FieldOwnerOffset)!=p.address)reject("Der Elementtyp der Liste gehört zu einem anderen Besitzer.");
    Array before=read<Array>(holder.address+p.offset);
    if(before.count<0 || before.capacity<before.count || before.capacity>4096 || before.count>256 || (before.count&&(!before.data||(before.data&7))))
        reject("Original community array exceeds bounds");
    std::vector<uintptr_t> pointers((size_t)before.count);
    if(before.count&&!read(before.data,pointers.data(),pointers.size()*8))reject("Original community array unreadable");
    std::vector<Object> result;std::set<uintptr_t> seen,types;
    for(uintptr_t address:pointers){
        Object o=pointerObject(address);real(o,@"PXCommunityComponent");
        if(!isA(o,expected) || !seen.insert(address).second)reject("Duplicate or mistyped community array member");
        if(linkedObject(o,@"ParentCity")!=c.city || linkedObject(o,@"ParentHolder")!=holder)
            reject("Community membership belongs to another city");
        Object type=communityType(o);
        id size=invoke(o,@"GetCommunitySize",@{});
        if(![size isKindOfClass:NSNumber.class] || [size longLongValue]<0 || [size longLongValue]>INT32_MAX)
            reject("Ungültige ursprüngliche Bevölkerungsgröße.");
        if(enabled(o)&&[size intValue]>0){if(!types.insert(type.address).second)reject("Ambiguous active community type in city");result.push_back(o);}
    }
    Array after=read<Array>(holder.address+p.offset);
    std::vector<uintptr_t> finalPointers(pointers.size());
    if(before.count && (!read(before.data,finalPointers.data(),finalPointers.size()*8) || finalPointers!=pointers))
        reject("Community membership changed while resolving selection");
    if(memcmp(&before,&after,sizeof(before)) || holderLease.get()!=holder || linkedObject(c.city,@"CommunitiesHolder")!=holder || read<uintptr_t>(p.address+0x78)!=inner)
        reject("Community array changed while resolving membership");
    context(c);return result;
}
Object selectedCommunity(const Context &c){
    verifyBindings();context(c);
    Object utils=utility(@"PXUtopiaToolPanelsUtils"),fn=function(utils,@"GetCurrentCommunity");
    if((read<uint32_t>(fn.address+FP2FunctionFlagsOffset)&0x2400)!=0x2400 ||
       read<uint16_t>(fn.address+FP2FunctionParameterSizeOffset)!=16 ||
       read<uint16_t>(fn.address+FP2FunctionReturnOffsetOffset)!=8)
        reject("Original faction-card getter native/static layout differs");
    uintptr_t slide=binding("processEvent")-UINT64_C(0x100be2e78);
    if(read<uintptr_t>(fn.address+FP2FunctionNativeExecOffset)!=UINT64_C(0x1063114fc)+slide)
        reject("Original faction-card getter exec differs");
    auto ps=properties(fn);NSString *input=nil;bool hasReturn=false;
    if(ps.size()!=2)reject("Original faction-card getter parameter count differs");
    for(const Property &p:ps){
        if(![p.type isEqual:@"ObjectProperty"] || p.size!=8 || p.count!=1 || !(p.flags&0x80) ||
           (p.flags&0x8000000))reject("Original faction-card getter object parameter differs");
        if(p.flags&0x400){
            if(hasReturn || p.offset!=8 || ![p.name isEqual:@"ReturnValue"] ||
               ![name(p.objectClass) isEqual:@"PXCommunityComponent"])
                reject("Original faction-card getter return type differs");
            hasReturn=true;
        }else{
            if(input || p.offset!=0 || (p.flags&0x100) ||
               [p.name caseInsensitiveCompare:@"worldContextObject"]!=NSOrderedSame)
                reject("Original faction-card getter input differs");
            input=p.name;
        }
    }
    if(!input || !hasReturn)reject("Die geprüften Parameter der Fraktionskartenauswahl sind nicht verfügbar.");
    Weak utilityLease(utils),functionLease(fn);
    NSDictionary *arguments=@{input:argument(c.controller)};
    Object selected=decode(invoke(utils,@"GetCurrentCommunity",arguments));
    if(!selected)return {};
    real(selected,@"PXCommunityComponent");Weak selectionLease(selected);
    bool local=false;
    for(Object o:listLocalCommunities(c))if(o==selected)local=true;
    if(!local)reject("Faction-card selection is outside the current active city");
    // Closing the card deliberately retains the game's last selection. It is
    // usable only while the same live component remains in this local city.
    if(selectionLease.get()!=selected || utilityLease.get()!=utils || functionLease.get()!=fn ||
       decode(invoke(utils,@"GetCurrentCommunity",arguments))!=selected)
        reject("Original faction-card selection changed");
    context(c);return selected;
}
}
