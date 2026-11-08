// SPDX-License-Identifier: GPL-3.0-only
#import "Speed.hpp"
#include <cmath>
namespace {
fp::Weak world,utility;
bool held=false;
double original=1,last=1;
fp::Object library(){using namespace fp;Object cached=utility.get();if(cached)return cached;Object found{};for(Object o:find(@"GameplayStatics",@"Default__GameplayStatics",16)){if(![className(o) isEqual:@"GameplayStatics"] || ![name(o) isEqual:@"Default__GameplayStatics"] || !(read<uint32_t>(o.address+8)&0x10))continue;Object c=objectClass(o);uintptr_t outer=read<uintptr_t>(c.address+0x20);if(!outer || ![name(Object{outer}) isEqual:@"/Script/Engine"])continue;if(found)throw std::runtime_error("Ambiguous original GameplayStatics");found=o;}if(!found)throw std::runtime_error("Original GameplayStatics unavailable");utility=Weak(found);return found;}
NSDictionary *arg(fp::Object w){return @{@"object":@(fp::read<int32_t>(w.address+0xc))};}
double get(fp::Object w){using namespace fp;Object lib=library(),f=function(lib,@"GetGlobalTimeDilation");if((read<uint32_t>(f.address+0xb0)&0x2400)!=0x2400)throw std::runtime_error("Time getter is not native/static");id result=invoke(lib,@"GetGlobalTimeDilation",@{@"WorldContextObject":arg(w)});if(![result isKindOfClass:NSNumber.class] || !std::isfinite([result doubleValue]))throw std::runtime_error("Original time getter returned invalid value");return [result doubleValue];}
// Keep a successfully submitted native float owned even if readback then fails.
bool setOwned(fp::Object w,double value) {
    using namespace fp;
    Object lib=library(),f=function(lib,@"SetGlobalTimeDilation");
    if((read<uint32_t>(f.address+0xb0)&0x2400)!=0x2400)
        throw std::runtime_error("Time setter is not native/static");
    const double target=static_cast<float>(value);
    invoke(lib,@"SetGlobalTimeDilation",@{@"WorldContextObject":arg(w),@"TimeDilation":@(target)});
    last=target;
    const double observed=get(w);
    last=observed; // Includes a native clamp; only our observed result is owned.
    return observed==target;
}

void forgetLease(){held=false;world={};}
bool releaseLease() {
    if(!held)return true;
    try {
        auto w=world.get();
        if(!w){forgetLease();return true;}
        // Preserve a value changed by the game or another owner exactly.
        if(get(w)!=last){forgetLease();return true;}
        if(!setOwned(w,original))return false;
        forgetLease();return true;
    }catch(...){return false;} // Keep the owner and baseline for the next retry.
}
}
void FPReleaseSpeed(){if(fp::isGameThread())releaseLease();}

FPSpeedResult FPApplySpeed(const fp::Context &c,bool wanted,double value) {
    FPSpeedResult result;
    if(!fp::isGameThread() || !c.ready)return result;
    try {
        if(held && world.get()!=c.world && !releaseLease())
            throw std::runtime_error("Vorheriges Engine-Tempo wartet auf bestätigte Rücknahme.");
        if(!wanted) {
            if(!releaseLease())throw std::runtime_error("Engine-Tempo-Rücknahme noch nicht bestätigt; wird erneut versucht.");
            result.value=get(c.world);result.available=true;return result;
        }
        if(!std::isfinite(value) || value<.25 || value>4)
            throw std::runtime_error("Tempo außerhalb 0,25 bis 4");
        const double current=get(c.world);
        if(!held) {
            original=current;last=current;world=fp::Weak(c.world);held=true;
        }else if(current!=last) {
            // A new desired write leases the foreign value as its new baseline.
            original=current;last=current;
        }
        if(!setOwned(c.world,value)) {
            const bool restored=releaseLease();
            throw std::runtime_error(restored ? "Engine-Tempo nicht zurückgelesen."
                : "Engine-Tempo nicht zurückgelesen; Rücknahme wird erneut versucht.");
        }
        result.available=true;result.active=true;result.value=last;
        result.note=@"Originales Engine-Tempo zurückgelesen.";
    }catch(const std::exception &e){result.note=@(e.what());}
    return result;
}
