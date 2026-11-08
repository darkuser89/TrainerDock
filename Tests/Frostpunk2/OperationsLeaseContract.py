#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Compile the unchanged product rollback body against synthetic fault fixtures."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
source=(ROOT/'Modules/frostpunk-2/Sources/Operations.mm').read_text()
assert 'Object worldOf(' not in source and 'fp::worldOf(' in source
body=source[source.index('struct WearLease {'):source.index('using Attempt=')]
wrappers=source[source.index('bool release(){'):source.rindex('\n}')]
prefix=r'''
#import <Foundation/Foundation.h>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <stdexcept>
#include <type_traits>
struct Object {uintptr_t address=0; bool operator==(Object o)const{return address==o.address;} bool operator!=(Object o)const{return !(*this==o);} };
static bool expired=false,failRead=false,apply=false,postReadFailure=false,afterSet=false,registeredNow=true,gameThread=true;
static unsigned setters=0;static float wear=0;static bool isBroken=false;
struct Weak {Object o{};Object get()const{return expired?Object{}:o;}};
struct Context {bool ready=false;Object world{},city{},nation{};Weak worldWeak{},cityWeak{},nationWeak{};};
namespace fp {Object worldOf(Object){return {1};}}
static void thread(){if(!gameThread)throw std::runtime_error("wrong thread");}
static bool isGameThread(){return gameThread;}
static Object linkedObject(Object,NSString *p){return [p isEqual:@"Nation"]?Object{3}:Object{4};}
static Object owner(Object){return {5};}
static void propertyLayout(Object,NSString *,NSString *,int,int){}
static bool registered(Object,Object){return registeredNow;}
static bool boolean(Object,NSString *){return isBroken;}
static float getWear(const void *){if(failRead || (postReadFailure&&afterSet))throw std::runtime_error("read failed");return wear;}
static float minimum(const void *){return 0;}
static float maximum(const void *){return 100;}
static void setWear(const void *,const void *,float v){setters++;afterSet=true;if(apply){wear=v;isBroken=true;}}
struct API {
 void validate(){if(failRead)throw std::runtime_error("metadata unavailable");}
 template<class T>T fn(uintptr_t a)const{if constexpr(std::is_same<T,float(*)(const void *)>::value){if(a==0x1077897b4)return &getWear;if(a==0x107789b04)return &minimum;assert(a==0x107789928);return &maximum;}else{assert(a==0x10778b94c);return &setWear;}}
 Object component(Object,uintptr_t,NSString *)const{return {6};}
 Object subsystem(const Context &,uintptr_t,NSString *)const{return {7};}
};
'''
suffix=r'''
static void reset(){expired=failRead=apply=postReadFailure=afterSet=false;registeredNow=gameThread=true;setters=0;wear=0;isBroken=false;wearLease=WearLease{};wearLease.owned=true;wearLease.c.world={1};wearLease.c.city={2};wearLease.c.nation={3};wearLease.c.worldWeak.o={1};wearLease.c.cityWeak.o={2};wearLease.c.nationWeak.o={3};wearLease.generatorObject={4};wearLease.actorObject={5};wearLease.wearObject={6};wearLease.subsystemObject={7};wearLease.generator.o={4};wearLease.actor.o={5};wearLease.wear.o={6};wearLease.subsystem.o={7};wearLease.baseline=50;wearLease.last=0;wearLease.broken=true;}
int main(){@autoreleasepool{
 reset();assert(!release());assert(hasPendingRelease()&&wearLease.owned&&setters==1);apply=true;assert(release());assert(!hasPendingRelease()&&!wearLease.owned&&wear==50&&isBroken&&setters==2);
 reset();failRead=true;assert(!release());assert(hasPendingRelease()&&wearLease.owned&&setters==0);failRead=false;apply=true;assert(release());assert(setters==1);
 reset();apply=true;postReadFailure=true;assert(!release());assert(hasPendingRelease()&&wear==50&&setters==1);postReadFailure=false;assert(release());assert(setters==1); // Confirm earlier success without replaying setter.
 reset();expired=true;assert(release());assert(!wearLease.owned&&setters==0);
 reset();wear=13;assert(release());assert(wear==13&&setters==0); // Foreign value preserved.
 reset();registeredNow=false;assert(!release());assert(hasPendingRelease()&&setters==0);registeredNow=true;apply=true;assert(release());
 reset();gameThread=false;assert(!release());assert(wearLease.owned&&setters==0);gameThread=true;apply=true;assert(release());
 puts("PASS: actual product rollback retains failed leases, retries after Loading, verifies Broken/value, avoids duplicate restored writes, preserves foreign values and rejects wrong threads. Synthetic only.");
}return 0;}
'''
with tempfile.TemporaryDirectory(prefix='trainerdock-operation-lease-') as tmp:
 p=Path(tmp);test=p/'check.mm';test.write_text(prefix+body+wrappers+suffix)
 subprocess.run(['xcrun','clang++','-std=c++17','-fobjc-arc','-fblocks','-Wall','-Wextra','-Werror','-framework','Foundation',str(test),'-o',str(p/'check')],check=True)
 subprocess.run([str(p/'check')],check=True)
