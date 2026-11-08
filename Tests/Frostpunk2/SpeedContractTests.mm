// SPDX-License-Identifier: GPL-3.0-only
// Synthetic reflection/memory fixtures. Link with the actual product Speed.mm;
// no game, game binary, or native ProcessEvent is loaded.
#import "Speed.hpp"
#include <cassert>
#include <cmath>
#include <cstring>
#include <map>

namespace {
constexpr uintptr_t libraryAddress=1000,classAddress=2000,packageAddress=3000;
constexpr uintptr_t getterAddress=4000,setterAddress=5000;
std::map<uintptr_t,double> dilation{{100,1},{200,1}};
bool gameThread=true,failSet=false,failReadAfterSet=false;
int failedReads=0;
double clampMaximum=4;
fp::Context context(uintptr_t address=100){fp::Context c;c.ready=true;c.world={address};return c;}
void reset(double initial=1) {
    failSet=false;failedReads=0;failReadAfterSet=false;clampMaximum=4;gameThread=true;
    FPReleaseSpeed();dilation={{100,initial},{200,1}};
}
}

namespace fp {
bool isGameThread(){return gameThread;}
Weak::Weak(Object o){index=static_cast<int32_t>(o.address);serial=index?1:0;}
Object Weak::get()const{return serial?Object{static_cast<uintptr_t>(index)}:Object{};}
bool read(uintptr_t p,void *out,size_t size) {
    uint32_t scalar=0;uintptr_t pointer=0;
    if(p==libraryAddress+8 && size==4)scalar=0x10;
    else if((p==getterAddress+0xb0 || p==setterAddress+0xb0) && size==4)scalar=0x2400;
    else if((p==100+0xc || p==200+0xc) && size==4)scalar=static_cast<uint32_t>(p-0xc);
    else if(p==classAddress+0x20 && size==8){pointer=packageAddress;std::memcpy(out,&pointer,8);return true;}
    else return false;
    std::memcpy(out,&scalar,4);return true;
}
std::vector<Object> find(NSString *,NSString *,size_t){return {{libraryAddress}};}
NSString *className(Object){return @"GameplayStatics";}
NSString *name(Object o){return o.address==packageAddress?@"/Script/Engine":@"Default__GameplayStatics";}
Object objectClass(Object){return {classAddress};}
Object function(Object,NSString *n){return {[n isEqual:@"GetGlobalTimeDilation"]?getterAddress:setterAddress};}
id invoke(Object,NSString *n,NSDictionary *arguments) {
    uintptr_t address=[arguments[@"WorldContextObject"][@"object"] unsignedLongLongValue];
    assert(dilation.count(address));
    if([n isEqual:@"GetGlobalTimeDilation"]){
        if(failedReads){failedReads--;throw std::runtime_error("Synthetic getter failure");}
        return @(dilation.at(address));
    }
    assert([n isEqual:@"SetGlobalTimeDilation"]);
    if(failSet)throw std::runtime_error("Synthetic setter failure");
    dilation[address]=std::min(clampMaximum,[arguments[@"TimeDilation"] doubleValue]);
    if(failReadAfterSet){failReadAfterSet=false;failedReads=1;}
    return NSNull.null;
}
}

int main(){@autoreleasepool{
    auto c=context();
    // Foreign changes become the baseline before the next desired write.
    reset();assert(FPApplySpeed(c,true,2).active);dilation[100]=3;
    assert(FPApplySpeed(c,true,2.5).active);FPReleaseSpeed();assert(dilation[100]==3);

    // A failed setter must retain the original baseline for a later retry.
    reset();assert(FPApplySpeed(c,true,2).active);failSet=true;
    FPReleaseSpeed();assert(dilation[100]==2);failSet=false;
    FPReleaseSpeed();assert(dilation[100]==1);

    // Native clamping during restoration is also a retryable failure.
    reset(3);assert(FPApplySpeed(c,true,2).active);clampMaximum=1.5;
    FPReleaseSpeed();assert(dilation[100]==1.5);clampMaximum=4;
    FPReleaseSpeed();assert(dilation[100]==3);

    // A post-write getter failure does not forget the submitted native value.
    reset();failReadAfterSet=true;assert(!FPApplySpeed(c,true,2).active);
    assert(dilation[100]==2);FPReleaseSpeed();assert(dilation[100]==1);

    // Even a nearby foreign float must survive release unchanged.
    reset();assert(FPApplySpeed(c,true,2).active);
    dilation[100]=static_cast<float>(2.000001);double foreign=dilation[100];
    FPReleaseSpeed();assert(dilation[100]==foreign);

    // Do not replace an unresolved old-world lease with a new-world lease.
    reset();assert(FPApplySpeed(c,true,2).active);failSet=true;
    assert(!FPApplySpeed(context(200),true,2.5).active);assert(dilation[200]==1);
    failSet=false;assert(FPApplySpeed(context(200),true,2.5).active);
    assert(dilation[100]==1);FPReleaseSpeed();assert(dilation[200]==1);

    // Turning off must release even if the submitted numeric value is invalid.
    reset();assert(FPApplySpeed(c,true,2).active);
    assert(!FPApplySpeed(c,false,NAN).active);assert(dilation[100]==1);
}}
