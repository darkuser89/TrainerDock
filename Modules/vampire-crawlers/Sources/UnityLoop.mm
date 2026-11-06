// SPDX-License-Identifier: GPL-3.0-only
#import "UnityLoop.h"
#include "IL2CPP.hpp"
#import <os/log.h>
#import <mach/mach.h>
#import <mach/mach_vm.h>
#include <mutex>
#include <atomic>
#include <cstring>
#include <pthread.h>
namespace {
std::mutex pendingLock;
NSMutableArray<dispatch_block_t> *pending;
dispatch_block_t frameHandler;
std::atomic_uint64_t frames{0},deliveries{0};
thread_local bool inFrame=false;
pthread_t engineThread;
bool observedThread=false,installed=false,cellStyle=false;
// Kept for this game process; do not call IL2CPP after engine shutdown from a
// C++ static destructor. The OS reclaims the single array root on process exit.
vc::Root *loopArray=nullptr;
os_log_t logger;
NSString *lastFailure=@"Warte auf Unity.";
void tick();
void (*callbackCell)()=tick;
bool readable(const void *source,void *target,size_t count){
    if(!source || !target || !count)return false;
    mach_vm_size_t actual=0;
    return mach_vm_read_overwrite(mach_task_self(),(mach_vm_address_t)source,count,(mach_vm_address_t)target,&actual)==KERN_SUCCESS && actual==count;
}
bool executable(const void *pointer){
    mach_vm_address_t address=(mach_vm_address_t)pointer;mach_vm_size_t size=0;
    vm_region_basic_info_data_64_t info={};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;mach_port_t object=0;
    kern_return_t result=mach_vm_region(mach_task_self(),&address,&size,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&object);
    if(object)mach_port_deallocate(mach_task_self(),object);
    return result==KERN_SUCCESS && address<=(uintptr_t)pointer && (info.protection&VM_PROT_EXECUTE);
}
size_t offset(vc::Class k,const char *name,size_t size){
    vc::Field f=vc::field(k,name);if(!f)throw std::runtime_error("Original PlayerLoop field missing");
    size_t raw=vc::api.fieldOffset(f),header=vc::api.objectHeader();
    if(raw<header || raw-header>=size)throw std::runtime_error("Original PlayerLoop field outside value layout");
    return raw-header;
}
template<class T> T value(const uint8_t *data,size_t at){T v={};memcpy(&v,data+at,sizeof(v));return v;}
void tick(){
    @autoreleasepool{
        if(!observedThread){engineThread=pthread_self();observedThread=true;os_log(logger,"Original Unity PlayerLoop callback reached; cocoa-main=%d",NSThread.isMainThread);}
        if(!pthread_equal(engineThread,pthread_self()))return;
        inFrame=true;frames.fetch_add(1);lastFailure=@"Originaler Unity-Rückruf bestätigt.";
        @try{
            try{
                dispatch_block_t handler;
                NSArray<dispatch_block_t> *work;
                {std::lock_guard<std::mutex> guard(pendingLock);work=pending.copy;[pending removeAllObjects];handler=frameHandler;}
                if(handler)handler();
                for(dispatch_block_t job in work){job();deliveries.fetch_add(1);}
            }catch(const std::exception& e){os_log_error(logger,"Native frame rejected: %{public}s",e.what());}
        }@catch(NSException *exception){os_log_error(logger,"Native frame exception: %{public}@",exception.reason);}
        inFrame=false;
    }
}
}
BOOL VCInFrame(){return inFrame && observedThread && pthread_equal(engineThread,pthread_self());}
void VCSetFrameHandler(dispatch_block_t handler){std::lock_guard<std::mutex> guard(pendingLock);frameHandler=[handler copy];}
BOOL VCEnqueue(dispatch_block_t work){
    if(!work)return NO;
    static dispatch_once_t once;dispatch_once(&once,^{pending=[NSMutableArray new];});
    {std::lock_guard<std::mutex> guard(pendingLock);if(pending.count>=64)return NO;[pending addObject:[work copy]];}
    return YES;
}
BOOL VCEnsureLoop(){
    using namespace vc;
    if(!NSThread.isMainThread)return NO;
    if(!logger)logger=os_log_create("local.mht.vampire-crawlers","UnityLoop");
    try{
        if(!bindAPI() || !api.domainGet())return NO;
        if(!api.currentThread() && !api.attach(api.domainGet()))return NO;
        // This thread-safe original Unity query validates registration affinity.
        using IsMain=bool (*)();auto main=(IsMain)api.icall("UnityEngine.Object::CurrentThreadIsMainThread()");
        const uint8_t unityUUID[16]={0x60,0x5a,0xaf,0x80,0x3a,0x60,0x3d,0xff,0xa1,0x76,0x76,0x4f,0x58,0x7c,0x2b,0x09};
        if(!main || !knownImage((const void *)main,unityUUID) || !main())return NO;
        vc::Class loop=klass("UnityEngine.CoreModule.dll","UnityEngine.LowLevel","PlayerLoop");
        vc::Class entry=klass("UnityEngine.CoreModule.dll","UnityEngine.LowLevel","PlayerLoopSystemInternal");
        Method get=method(loop,"GetCurrentPlayerLoopInternal",0),set=method(loop,"SetPlayerLoopInternal",1);
        if(!get || !set || !entry)return NO;
        uint32_t alignment=0;int size=api.valueSize(entry,&alignment);
        if(size<36 || size>64 || alignment>16 || api.objectHeader()!=16 || api.arrayHeader()!=32)throw std::runtime_error("Original Unity layout differs");
        size_t type=offset(entry,"type",size),delegate=offset(entry,"updateDelegate",size);
        size_t function=offset(entry,"updateFunction",size),condition=offset(entry,"loopConditionFunction",size),children=offset(entry,"numSubSystems",size);
        if(type+8>(size_t)size || delegate+8>(size_t)size || function+8>(size_t)size || condition+8>(size_t)size || children+4>(size_t)size)throw std::runtime_error("PlayerLoop field bounds differ");
        Root original(call(get,nullptr));if(!original.get())return NO;
        size_t count=api.arrayLength(original.get());if(count<16 || count>2048)return NO;
        const uint8_t *data=(const uint8_t *)original.get()+api.arrayHeader();
        if(value<int32_t>(data,children)!=(int32_t)count-1)throw std::runtime_error("Original Unity hierarchy differs");
        unsigned direct=0,cells=0;
        for(size_t i=0;i<count;i++){
            auto p=data+i*size;void *fn=value<void *>(p,function);
            if(fn==(void *)&callbackCell || fn==(void *)tick){installed=true;return YES;}
            int32_t n=value<int32_t>(p,children);
            if(n<0 || (size_t)n>=count-i)throw std::runtime_error("Invalid original Unity hierarchy");
            if(!fn)continue;
            if(executable(fn))direct++;
            else{void *target=nullptr;if(readable(fn,&target,8) && executable(target))cells++;}
        }
        if((direct<3 && cells<3) || (direct && cells))throw std::runtime_error("Native Unity callback representation unconfirmed");
        cellStyle=cells>=3;
        Root next(api.arrayNew(entry,count+1));if(!next.get())return NO;
        auto destination=(uint8_t *)next.get()+api.arrayHeader();memcpy(destination,data,count*size);memset(destination+count*size,0,size);
        for(size_t i=0;i<count;i++)for(size_t member:{type,delegate}){
            Object object=value<Object>(destination+i*size,member);api.barrier(next.get(),(void **)(destination+i*size+member),object);
        }
        int32_t total=(int32_t)count;memcpy(destination+children,&total,4);
        Object marker=api.typeObject(api.classType(loop));api.barrier(next.get(),(void **)(destination+count*size+type),marker);
        void *callback=cellStyle ? (void *)&callbackCell : (void *)tick;memcpy(destination+count*size+function,&callback,8);
        call(set,nullptr,{next.get()});if(!loopArray)loopArray=new Root;*loopArray=std::move(next);installed=true;
        lastFailure=@"Unity-Rückruf registriert; wartet auf Ausführung.";
        os_log(logger,"Registered one native Unity callback; original systems=%lu stride=%d indirect=%d",(unsigned long)count,size,cellStyle);
        return YES;
    }catch(const std::exception& e){
        NSString *message=@(e.what());if(![lastFailure isEqual:message]){lastFailure=message;os_log_error(logger,"Registration deferred: %{public}@",message);}
        return NO;
    }
}
NSDictionary *VCLoopDiagnostics(){return @{@"installed":@(installed),@"frames":@(frames.load()),@"deliveries":@(deliveries.load()),@"indirect":@(cellStyle),@"note":lastFailure ?: @""};}
