// SPDX-License-Identifier: GPL-3.0-only
#import "GameEffects.hpp"
#import "Context.hpp"
#import "GameBindings.h"
#import "ReflectionBindings.h"
#include <cmath>
#include <cstring>
#include <limits>

namespace fp::effects {
namespace {
constexpr uint32_t Native=0x400,Static=0x2000,ClassDefaultObject=0x10;
[[noreturn]] void reject(const char *message){throw std::runtime_error(message);}
void requireThread(){if(!isBound() || !isGameThread())reject("Original Unreal GameThread required");}
bool isDefault(Object o){return (read<uint32_t>(o.address+8)&ClassDefaultObject)!=0;}
void live(Object o){Weak w(o);if(!o || w.get()!=o || isDefault(o))reject("Live gameplay object required");}
void sameWorld(Object context,Object city){
    live(context);live(city);
    Object contextWorld=fp::worldOf(context),cityWorld=fp::worldOf(city);
    live(contextWorld);live(cityWorld);
    if(contextWorld!=cityWorld)reject("Selected city belongs to a different World");
}
id objectArgument(Object o){
    live(o);
    return @{@"object":@(read<int32_t>(o.address+FP2ObjectInternalIndexOffset))};
}
void asset(Object o,const char *nativeClass){
    live(o);
    if(![className(o) isEqual:@(nativeClass)])reject("Native asset class differs");
    Object package{read<uintptr_t>(o.address+FP2ObjectOuterOffset)};
    NSString *path=[NSString stringWithFormat:@"%@.%@",name(package),name(o)];
    for(const auto &a:FPGameAssets)
        if(!strcmp(a.nativeClass,nativeClass) && [path isEqual:@(a.objectPath)])return;
    reject("Asset is outside the verified resource/statistic identities");
}
Object library(NSString *nativeClass){
    Object result=utility(nativeClass);
    if(![className(result) isEqual:nativeClass] || !isDefault(result))
        reject("Native function library CDO is unavailable");
    return result;
}
Object method(Object owner,NSString *functionName,bool mustBeStatic){
    Object f=function(owner,functionName);
    uint32_t flags=read<uint32_t>(f.address+FP2FunctionFlagsOffset);
    if(!(flags&Native) || bool(flags&Static)!=mustBeStatic)
        reject("Original function static/native flags differ");
    if(isDefault(owner)!=mustBeStatic)
        reject("A nonstatic function cannot use a class default object");
    const FPGameBinding *expected=nullptr;
    NSString *key=[@"exec." stringByAppendingString:functionName];
    for(const auto &b:FPGameBindings)if([key isEqual:@(b.name)]){expected=&b;break;}
    if(!expected)reject("Original native exec binding is absent");
    uintptr_t processEvent=binding("processEvent");
    if(processEvent<UINT64_C(0x100be2e78))reject("Original image relocation unavailable");
    uintptr_t slide=processEvent-UINT64_C(0x100be2e78);
    uintptr_t exec=read<uintptr_t>(f.address+FP2FunctionNativeExecOffset);
    uint8_t bytes[16];
    if(exec!=expected->address+slide || !read(exec,bytes,sizeof(bytes)) ||
       memcmp(bytes,expected->bytes16,sizeof(bytes)))reject("Original native exec differs");
    return f;
}
NSDictionary *originalArguments(Object f,NSDictionary *arguments){
    NSMutableDictionary *result=[NSMutableDictionary new];
    for(const Property &p:properties(f)){
        if(p.flags&0x400)continue;
        NSString *matched=nil;
        for(NSString *key in arguments)
            if([key caseInsensitiveCompare:p.name]==NSOrderedSame){
                if(matched)reject("Ambiguous native argument spelling");
                matched=key;
            }
        if(!matched)reject("Original native argument is missing");
        result[p.name]=arguments[matched];
    }
    if(result.count!=arguments.count)reject("Unexpected native argument");
    return result;
}
id call(Object owner,NSString *functionName,NSDictionary *arguments,bool isStatic=true){
    Object f=method(owner,functionName,isStatic);
    return invoke(owner,functionName,originalArguments(f,arguments));
}
double number(id value,bool integral){
    if(![value isKindOfClass:NSNumber.class])reject("Native scalar return required");
    double n=[value doubleValue];
    if(!std::isfinite(n) || (integral && (std::floor(n)!=n || n<INT32_MIN || n>INT32_MAX)))
        reject("Original scalar return is outside its native type");
    return n;
}
double stockpile(Object lib,Object city,Object resource){
    return number(call(lib,@"GetCityStockpileOfResource",
        @{@"City":objectArgument(city),@"Resource":objectArgument(resource)}),true);
}
double statisticValue(Object lib,Object city,Object statistic){
    return number(call(lib,@"GetCurrentStatisticValue",
        @{@"City":objectArgument(city),@"Statistic":objectArgument(statistic)}),false);
}
void unchanged(const Weak &context,const Weak &city,const Weak &target,
               Object originalContext,Object originalCity,Object originalTarget){
    if(context.get()!=originalContext || city.get()!=originalCity || target.get()!=originalTarget)
        reject("Gameplay owner changed during native operation");
    sameWorld(originalContext,originalCity);
}
ScalarResult failure(ScalarResult result,const std::exception &e){
    result.available=false;result.writeReadbackConfirmed=false;
    result.reason=[NSString stringWithUTF8String:e.what()] ?: @"Native effect failed";
    return result;
}
}
ScalarResult getStockpile(Object context,Object city,Object resource){
    ScalarResult result;
    try{
        requireThread();sameWorld(context,city);asset(resource,"PXResource");
        result.value=stockpile(library(@"PXStockpileUtils"),city,resource);
        result.available=true;
    }catch(const std::exception &e){return failure(result,e);}
    return result;
}
ScalarResult setStockpileAbsolute(Object context,Object city,Object resource,int32_t value){
    ScalarResult result;
    try{
        requireThread();sameWorld(context,city);asset(resource,"PXResource");
        if(value<0)reject("Requested stockpile must be nonnegative");
        Weak contextWeak(context),cityWeak(city),resourceWeak(resource);
        Object lib=library(@"PXStockpileUtils");
        result.value=stockpile(lib,city,resource);result.available=true;
        Object fn=method(lib,@"TryChangeCityStockpile",true);
        int64_t delta=int64_t(value)-int64_t(result.value);
        if(delta<INT32_MIN || delta>INT32_MAX)reject("Stockpile delta exceeds native int32");
        if(!delta){result.writeReadbackConfirmed=true;return result;}
        unchanged(contextWeak,cityWeak,resourceWeak,context,city,resource);
        NSDictionary *arguments=originalArguments(fn,
            @{@"WorldContextObject":objectArgument(context),@"City":objectArgument(city),
              @"Resource":objectArgument(resource),@"Amount":@(delta)});
        result.invoked=true;
        id accepted=invoke(lib,@"TryChangeCityStockpile",arguments);
        if(![accepted isKindOfClass:NSNumber.class])reject("Native stockpile result is not bool");
        unchanged(contextWeak,cityWeak,resourceWeak,context,city,resource);
        result.value=stockpile(lib,city,resource);
        result.writeReadbackConfirmed=[accepted boolValue] && result.value==double(value);
        if(!result.writeReadbackConfirmed)result.reason=@"Native stockpile change was rejected or limited";
    }catch(const std::exception &e){return failure(result,e);}
    return result;
}
ScalarResult getStatistic(Object context,Object city,Object statistic){
    ScalarResult result;
    try{
        requireThread();sameWorld(context,city);asset(statistic,"PXStatistic");
        result.value=statisticValue(library(@"PXStatisticUtils"),city,statistic);
        result.available=true;
    }catch(const std::exception &e){return failure(result,e);}
    return result;
}
ScalarResult setStatisticAbsolute(Object context,Object city,Object statistic,int32_t value,Object manager){
    ScalarResult result;
    try{
        requireThread();sameWorld(context,city);asset(statistic,"PXStatistic");
        if(value<0)reject("Requested statistic must be nonnegative");
        Object lib=library(@"PXStatisticUtils");
        result.value=statisticValue(lib,city,statistic);result.available=true;
        live(manager);
        sameWorld(context,manager);
        Weak contextWeak(context),cityWeak(city),statisticWeak(statistic),managerWeak(manager);
        Object fn=method(manager,@"SetStatisticValuesInstantly",false);
        Object declaringClass{read<uintptr_t>(fn.address+FP2ObjectOuterOffset)};
        if(![name(declaringClass) isEqual:@"PXCheatManager"])
            reject("Original PXCheatManager setter ownership differs");
        if(result.value==double(value)){result.writeReadbackConfirmed=true;return result;}
        NSDictionary *arguments=originalArguments(fn,
            @{@"City":objectArgument(city),@"Statistic":objectArgument(statistic),@"Value":@(value)});
        unchanged(contextWeak,cityWeak,statisticWeak,context,city,statistic);
        result.invoked=true;
        invoke(manager,@"SetStatisticValuesInstantly",arguments);
        if(managerWeak.get()!=manager)reject("Native cheat manager expired during operation");
        unchanged(contextWeak,cityWeak,statisticWeak,context,city,statistic);
        result.value=statisticValue(lib,city,statistic);
        result.writeReadbackConfirmed=result.value==double(value);
        if(!result.writeReadbackConfirmed)result.reason=@"Native statistic readback differs from requested value";
    }catch(const std::exception &e){return failure(result,e);}
    return result;
}
}
