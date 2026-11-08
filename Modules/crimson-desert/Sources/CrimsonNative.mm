// SPDX-License-Identifier: GPL-3.0-only
// Bindings for the inspected macOS arm64 Steam build 1.0.35 (450) only.
#import "CrimsonNative.h"
extern "C" {
#import "MemoryAccess.h"
}
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <pthread.h>
#include <cstring>
#include <cstdint>
#include <cmath>
#include <mutex>
#include <vector>
#include <map>
#import "CrimsonBuild.h"

namespace {
uintptr_t imageBase;
bool checked, supported;
NSString *buildFailure;
template<typename T> T native(uintptr_t offset) { return reinterpret_cast<T>(imageBase+offset); }
template<typename T> T read(const void *p, size_t offset=0) {
    T value{}; MTReadMemory(static_cast<const uint8_t *>(p)+offset,&value,sizeof(value)); return value;
}
void *context(uintptr_t slot) { return read<void *>(reinterpret_cast<void *>(imageBase+slot)); }
bool loading(void *ctx) {
    void *gameplay=ctx ? read<void *>(ctx,0x20) : nullptr;
    void *processor=gameplay ? read<void *>(gameplay,0x1f70) : nullptr;
    return !processor || native<bool(*)(void *)>(0x3fc0c94)(processor);
}
// Non-trivial return type deliberately uses arm64's x8 indirect-result ABI.
// Native getFocusActor returns an engine scope attacher, not a raw actor pointer.
struct ActorScope {
    void *vtable=nullptr, *actor=nullptr;
    uint8_t valid=0, mode=0, padding[6]{};
    const char *tag=nullptr;
    ~ActorScope() { if(vtable) native<void(*)(void *)>(0x1101b6c)(this); }
    ActorScope() = default;
    ActorScope(const ActorScope&)=delete;
};
static_assert(sizeof(ActorScope)==32,"Native scope ABI includes the debug tag at +0x18");
struct NativeDelegate {
    void *owner;
    void (*invoke)(void *);
    void *helpers;
    uint8_t mode, owned, padding[6];
};
static_assert(sizeof(NativeDelegate)==32,"Native delegate ABI");
std::mutex pendingLock;
NSMutableArray *pending;
bool retryScheduled;
NSDictionary *lastRequest;
struct CursorOwnership {void *input=nullptr;uint8_t phase=0,previous=0;uint64_t position=UINT64_MAX;bool owned=false;} cursor;
void invokeBlock(void *opaque) {
    @autoreleasepool {
        dispatch_block_t block=(__bridge dispatch_block_t)opaque;
        block();
        std::lock_guard<std::mutex> guard(pendingLock);
        [pending removeObjectIdenticalTo:block];
    }
}
// An owned Troc task uses the engine's existing one-shot queue. The original
// singleton and vtable stay untouched; only this private task object is custom.
std::mutex serverPendingLock;
NSMutableArray *serverPending;
alignas(16) uint8_t serverTask[0x90]{};
uintptr_t serverVtable[6]{};
uint32_t invokeServerTask(void *,void *parameter) {
    @autoreleasepool {
        void *bytes=read<void *>(parameter,0x18);
        uintptr_t opaque=bytes ? read<uintptr_t>(bytes,3) : 0;
        dispatch_block_t block=(__bridge dispatch_block_t)reinterpret_cast<void *>(opaque);
        if(!block)return 0;
        BOOL owned;
        {std::lock_guard<std::mutex> guard(serverPendingLock);owned=[serverPending containsObject:block];}
        if(owned && native<bool(*)()>(0xea5a44)())block();
        {std::lock_guard<std::mutex> guard(serverPendingLock);[serverPending removeObjectIdenticalTo:block];}
        return 0;
    }
}
BOOL onServerThread(dispatch_block_t work) {
    void *framework=context(0x8db0f30);
    if(!framework || !native<bool(*)(void *)>(0x7d9010)(framework))return NO;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        MTReadMemory(reinterpret_cast<void *>(imageBase+0x8f8ba88),serverTask,sizeof(serverTask));
        uintptr_t original=read<uintptr_t>(serverTask);
        MTReadMemory(reinterpret_cast<void *>(original),serverVtable,sizeof(serverVtable));
        serverVtable[3]=reinterpret_cast<uintptr_t>(invokeServerTask);
        uintptr_t own=reinterpret_cast<uintptr_t>(serverVtable);memcpy(serverTask,&own,sizeof(own));
        uint32_t runThread=0;memcpy(serverTask+0x88,&runThread,4);
    });
    dispatch_block_t block=[work copy];
    {std::lock_guard<std::mutex> guard(serverPendingLock);if(!serverPending)serverPending=[NSMutableArray new];[serverPending addObject:block];}
    uint8_t packet[3+sizeof(uintptr_t)]{};
    uint16_t id=read<uint16_t>(serverTask,0xc);memcpy(packet,&id,2);packet[2]=0xff;
    uintptr_t pointer=reinterpret_cast<uintptr_t>((__bridge void *)block);memcpy(packet+3,&pointer,sizeof(pointer));
    uint32_t error=native<uint32_t(*)(void *,uint32_t,void *,void *,void *,const void *,uint16_t)>(0x7dc0ac)(framework,0,nullptr,nullptr,serverTask,packet,sizeof(packet));
    if(error){std::lock_guard<std::mutex> guard(serverPendingLock);[serverPending removeObjectIdenticalTo:block];return NO;}
    return YES;
}
NSDictionary *serverSnapshot(uint32_t key) {
    char name[128]{};pthread_getname_np(pthread_self(),name,sizeof(name));
    NSMutableDictionary *out=[@{@"thread":@(name),@"serverThread":@(native<bool(*)()>(0xea5a44)())} mutableCopy];
    if(!native<bool(*)()>(0xea5a44)())return out;
    void *troc=native<void *(*)()>(0xc93470)();
    void *manager=troc ? read<void *>(troc) : nullptr;
    if(!manager)return out;
    ActorScope scope=native<ActorScope(*)(void *,uint32_t)>(0x825b2c)(manager,key);
    if(!scope.valid || !scope.actor)return out;
    out[@"actorKey"]=@(read<uint32_t>(scope.actor,0x100));
    void *component=read<void *>(read<void *>(scope.actor,0x108),0x20);
    void *flags=component ? read<void *>(component,0x428) : nullptr;
    out[@"invincible"]=@(flags && read<uint8_t>(flags,0x18));
    void *status=native<void *(*)(void *)>(0xf4a3a0)(scope.actor);
    void *infos=native<void *(*)(uint16_t)>(0x1b38c48)(2);
    const uintptr_t getters[]={0x1ac8038,0x1ac8010,0x1ac8040,0x1ac8020,0x1ac8018};
    NSArray *names=@[@"health",@"stamina",@"spirit",@"defense",@"attack"];
    uint64_t tick=native<uint64_t(*)()>(0xea8a64)();
    for(unsigned i=0;i<5;i++) {
        uint16_t index=native<uint16_t(*)(void *)>(getters[i])(infos);
        int64_t current=native<int64_t(*)(void *,uint16_t,uint64_t)>(0x1f85b44)(status,index,tick);
        int64_t maximum=native<int64_t(*)(void *,uint16_t)>(0x1f88598)(status,index);
        int64_t minimum=native<int64_t(*)(void *,uint16_t)>(0x1f88804)(status,index);
        out[names[i]]=@{@"index":@(index),@"raw":@(current),@"rawMaximum":@(maximum),@"rawMinimum":@(minimum)};
    }
    return out;
}
NSDictionary *serverObservation;
#include "CrimsonEffects.h"
#include "CrimsonInventory.h"
void retryPending();
void drainPending() {
    void *ctx=context(0x8f72700);
    void *gameplay=ctx ? read<void *>(ctx,0x20) : nullptr;
    void *timer=gameplay ? read<void *>(gameplay,0x1fb0) : nullptr;
    // Constructor and all three native callers agree on this owner and vtable.
    if(!timer || read<uintptr_t>(timer)!=imageBase+0x8679c28) { retryPending(); return; }
    NSArray *blocks;
    { std::lock_guard<std::mutex> guard(pendingLock); blocks=[pending copy]; }
    for(dispatch_block_t block in blocks) {
        // Only unscheduled blocks are marked here. The native timer removes a
        // one-shot BEFORE invoking it and releases its own mutex before calling.
        static NSHashTable *scheduled;
        if(!scheduled) scheduled=[NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory|NSPointerFunctionsObjectPointerPersonality];
        if([scheduled containsObject:block]) continue;
        NativeDelegate delegate{(__bridge void *)block,invokeBlock,nullptr,0,0,{}};
        native<uint64_t(*)(void *,float,const NativeDelegate *,bool)>(0x408d9f0)(timer,0.f,&delegate,true);
        [scheduled addObject:block];
    }
}
void retryPending() {
    if(retryScheduled) return;
    retryScheduled=true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),dispatch_get_main_queue(),^{retryScheduled=false;drainPending();});
}
}

BOOL CDCorrectBuild(void) {
    if(checked) return supported;
    checked=true;
    const mach_header_64 *h=nullptr;
    for(uint32_t i=0;i<_dyld_image_count();i++) {
        const auto *candidate=reinterpret_cast<const mach_header_64 *>(_dyld_get_image_header(i));
        if(candidate && candidate->magic==MH_MAGIC_64 && candidate->filetype==MH_EXECUTE) {h=candidate;break;}
    }
    if(!h || h->magic!=MH_MAGIC_64 || h->cputype!=CPU_TYPE_ARM64 || h->filetype!=MH_EXECUTE) {buildFailure=@"Unexpected main image header";return NO;}
    const uint8_t *pos=reinterpret_cast<const uint8_t *>(h+1);
    const uint8_t *end=pos+h->sizeofcmds;
    bool uuid=false;
    for(uint32_t i=0;i<h->ncmds;i++) {
        if(pos+sizeof(load_command)>end) return NO;
        const auto *c=reinterpret_cast<const load_command *>(pos);
        if(c->cmdsize<sizeof(*c) || pos+c->cmdsize>end) return NO;
        if(c->cmd==LC_UUID && c->cmdsize==sizeof(uuid_command)) {
            uuid=!memcmp(reinterpret_cast<const uuid_command *>(c)->uuid,CDExpectedUUID,16);
        }
        pos+=c->cmdsize;
    }
    if(!uuid) {buildFailure=@"Unexpected executable UUID";return NO;}
    imageBase=reinterpret_cast<uintptr_t>(h);
    for(const auto &entry:CDEntryChecks) {
        uint8_t bytes[sizeof(entry.bytes)];
        if(!MTReadMemory(reinterpret_cast<void *>(imageBase+entry.offset),bytes,sizeof(bytes)) || memcmp(bytes,entry.bytes,sizeof(bytes))) {buildFailure=[NSString stringWithFormat:@"Instruction prefix mismatch at 0x%lx",entry.offset];return NO;}
    }
    supported=true; return YES;
}
void CDOnGameThread(dispatch_block_t work) {
    if(!work || !CDCorrectBuild()) return;
    dispatch_block_t copied=[work copy];
    { std::lock_guard<std::mutex> guard(pendingLock); if(!pending) pending=[NSMutableArray new]; [pending addObject:copied]; }
    dispatch_async(dispatch_get_main_queue(),^{drainPending();});
}
NSDictionary *CDReadPlayer(void) {
    char threadName[128]{}; pthread_getname_np(pthread_self(),threadName,sizeof(threadName));
    NSMutableDictionary *result=[@{@"buildMatched":@(CDCorrectBuild()),@"thread":@(threadName),@"mainThread":@(NSThread.isMainThread)} mutableCopy];
    if(lastRequest) result[@"lastRequest"]=lastRequest;
    @synchronized(NSProcessInfo.processInfo){if(serverObservation)result[@"server"]=serverObservation;if(quantityObservation)result[@"quantityResult"]=quantityObservation;}
    if(!supported) return result;
    // Reject gameplay access unless the native callback is on GameThread.
    if(strcmp(threadName,"GameThread")) {result[@"error"]=@"Nativer Rückruf läuft nicht auf dem Spielthread.";return result;}
    void *ctx=context(0x8f72700);
    if(loading(ctx)) {result[@"loading"]=@YES;return result;}
    void *manager=ctx ? read<void *>(ctx,0x30) : nullptr;
    if(!manager) {result[@"loading"]=@YES;return result;}
    ActorScope scope=native<ActorScope(*)(void *)>(0x3fd062c)(manager);
    if(!scope.valid || !scope.actor) {result[@"loading"]=@YES;return result;}
    if(!native<bool(*)(void *,void *)>(0x3fd338c)(manager,scope.actor)) {result[@"error"]=@"Die ausgewählte Figur gehört nicht zum lokalen Spieler.";return result;}
    result[@"actorKey"]=@(read<uint32_t>(scope.actor,0x100));
    result[@"fieldIndex"]=@(native<uint16_t(*)(void *)>(0xf3fa2c)(scope.actor));
    void *moduleInfo=read<void *>(ctx,8);
    void *input=moduleInfo ? read<void *>(moduleInfo,0x10) : nullptr;
    result[@"cursorVisible"]=@(input && read<uint8_t>(input,0x50));
    void *status=native<void *(*)(void *)>(0xf4a3a0)(scope.actor);
    if(!status) {result[@"loading"]=@YES;return result;}
    void *infos=native<void *(*)(uint16_t)>(0x1b38c48)(2);
    if(!infos) {result[@"loading"]=@YES;return result;}
    const uintptr_t keys[]={0x1ac8038,0x1ac8010,0x1ac8040,0x1ac8020,0x1ac8018};
    NSArray *names=@[@"health",@"stamina",@"spirit",@"defense",@"attack"];
    uint64_t tick=native<uint64_t(*)()>(0xea8a64)();
    for(size_t i=0;i<5;i++) {
        uint16_t key=native<uint16_t(*)(void *)>(keys[i])(infos);
        int64_t value=native<int64_t(*)(void *,uint16_t,uint64_t)>(0x1f85b44)(status,key,tick);
        int64_t maximum=native<int64_t(*)(void *,uint16_t)>(0x1f88598)(status,key);
        int64_t minimum=native<int64_t(*)(void *,uint16_t)>(0x1f88804)(status,key);
        result[names[i]]=@{@"index":@(key),@"rawMinimum":@(minimum),@"raw":@(value),@"rawMaximum":@(maximum),@"value":@(value/1000.),@"maximum":@(maximum/1000.)};
    }
    uint32_t observedKey=read<uint32_t>(scope.actor,0x100);
    onServerThread(^{NSDictionary *observed=serverSnapshot(observedKey);@synchronized(NSProcessInfo.processInfo){serverObservation=observed;}});
    if(getenv("MT_CRIMSON_PROBE_OUTPUT"))result[@"inventoryDiagnostic"]=inventoryDiagnostic(scope.actor);
    ItemBinding selected,wallet;
    if(selectedItem(scope.actor,selected))result[@"selectedItem"]=bindingJSON(selected);
    if(getenv("MT_CRIMSON_PROBE_OUTPUT") && selectionDiagnostic)result[@"selectionDiagnostic"]=selectionDiagnostic;
    if(void *walletObject=walletItem(scope.actor,wallet)){NSMutableDictionary *data=[bindingJSON(wallet) mutableCopy];data[@"stackLimit"]=@(native<int64_t(*)(const void *,bool)>(0x1a72cbc)(walletObject,false));result[@"wallet"]=data;}
    result[@"invincible"]=@(native<bool(*)(void *)>(0xf51fa8)(scope.actor));
    FieldTime time;if(actorTime(scope.actor,time)){result[@"seconds"]=@(native<uint64_t(*)(const FieldTime *)>(0xeef008)(&time));result[@"daySpeed"]=@(read<uint16_t>(&time,0x16));}
    uint8_t speedType=5;void *gameplay=read<void *>(ctx,0x20);
    result[@"speed"]=@(native<float(*)(void *,bool,const uint8_t *)>(0x4004268)(gameplay,false,&speedType));
    result[@"effectiveSpeed"]=@(read<float>(gameplay,0x1958));
    return result;
}

void CDReleaseEffects(void) {
    char name[128]{};pthread_getname_np(pthread_self(),name,sizeof(name));
    if(!CDCorrectBuild() || strcmp(name,"GameThread"))return;
    void *ctx=context(0x8f72700),*manager=ctx ? read<void *>(ctx,0x30) : nullptr;
    if(manager)for(auto &entry:clientEffects) {
        ActorScope actor=native<ActorScope(*)(void *,uint32_t)>(0x3fce6d0)(manager,entry.first);
        if(actor.valid && actor.actor)for(unsigned i=0;i<3;i++)infiniteStat(actor.actor,i,false,entry.second);
    }
    if(ctx){void *gameplay=read<void *>(ctx,0x20);if(gameplay)setSpeed(gameplay,false,1);}
    if(manager && day.owned){ActorScope sender=native<ActorScope(*)(void *)>(0x3fd3a24)(manager);if(sender.valid && sender.actor)setDay(sender.actor,10,false);}
    onServerThread(^{for(auto &entry:serverEffects){for(unsigned feature=0;feature<=6;feature++)applyServerEffect(entry.first,feature,false,0);applyServerEffect(entry.first,9,false,0);}});
}
BOOL CDRequestEffect(unsigned feature,BOOL wanted,double value,uint32_t expectedActorKey) {
    char name[128]{};pthread_getname_np(pthread_self(),name,sizeof(name));
    if(!CDCorrectBuild() || strcmp(name,"GameThread") || feature>12 || !std::isfinite(value) || value<0 || value>10000000)return NO;
    void *ctx=context(0x8f72700);if(loading(ctx))return NO;
    void *manager=read<void *>(ctx,0x30);if(!manager)return NO;
    ActorScope focus=native<ActorScope(*)(void *)>(0x3fd062c)(manager);
    if(!focus.valid || !focus.actor || !native<bool(*)(void *,void *)>(0x3fd338c)(manager,focus.actor))return NO;
    uint32_t key=read<uint32_t>(focus.actor,0x100);if(!key || key!=expectedActorKey)return NO;
    if(feature==8){if(value<0.25 || value>4)return NO;return setSpeed(read<void *>(ctx,0x20),wanted,(float)value);}
    if(feature==10 || feature==11){ActorScope sender=native<ActorScope(*)(void *)>(0x3fd3a24)(manager);return sender.valid && sender.actor && setDay(sender.actor,feature,wanted);}
    if(feature==7 || feature==12) {
        if(!wanted || value<1 || floor(value)!=value)return NO;
        ItemBinding binding;void *item=feature==7 ? selectedItem(focus.actor,binding) : walletItem(focus.actor,binding);
        if(!item)return NO;
        int64_t limit=native<int64_t(*)(const void *,bool)>(0x1a72cbc)(item,false);
        if(feature==7 && value>limit)return NO;
        return onServerThread(^{NSDictionary *result=changeQuantity(key,binding,(int64_t)value);@synchronized(NSProcessInfo.processInfo){quantityObservation=result;}});
    }
    if((feature==1 || feature==3 || feature==5) && wanted && value<1)return NO;
    if(feature==2 || feature==4)infiniteStat(focus.actor,feature/2,wanted,clientEffects[key]);
    return onServerThread(^{bool applied=applyServerEffect(key,feature,wanted,value);NSMutableDictionary *observed=[serverSnapshot(key) mutableCopy];observed[@"effect"]=@{@"feature":@(feature),@"wanted":@(wanted),@"value":@(value),@"applied":@(applied)};@synchronized(NSProcessInfo.processInfo){serverObservation=observed;}});
}

BOOL CDSetPlayerStatRatio(unsigned kind,double ratio,uint32_t expectedActorKey) {
    char threadName[128]{};pthread_getname_np(pthread_self(),threadName,sizeof(threadName));
    if(!CDCorrectBuild() || strcmp(threadName,"GameThread") || kind>2 || !std::isfinite(ratio) || ratio<0 || ratio>1) return NO;
    void *ctx=context(0x8f72700);
    if(loading(ctx)) return NO;
    void *manager=ctx ? read<void *>(ctx,0x30) : nullptr;
    if(!manager) return NO;
    ActorScope focus=native<ActorScope(*)(void *)>(0x3fd062c)(manager);
    if(!focus.valid || !focus.actor || !native<bool(*)(void *,void *)>(0x3fd338c)(manager,focus.actor)) return NO;
    uint32_t actorKey=read<uint32_t>(focus.actor,0x100);
    if(!actorKey || (expectedActorKey && actorKey!=expectedActorKey)) return NO;
    void *status=native<void *(*)(void *)>(0xf4a3a0)(focus.actor);
    void *infos=native<void *(*)(uint16_t)>(0x1b38c48)(2);
    if(!status || !infos) return NO;
    const uintptr_t getters[]={0x1ac8038,0x1ac8010,0x1ac8040};
    uint16_t index=native<uint16_t(*)(void *)>(getters[kind])(infos);
    void *table=read<void *>(infos,0x58);
    void *info=table ? read<void *>(table,index*sizeof(void *)) : nullptr;
    if(!info) return NO;
    // Same immutable StatusInfo::key field used by fill_TrVaryRegenerateStat__.
    uint32_t statusKey=read<uint32_t>(info,8);
    int64_t maximum=native<int64_t(*)(void *,uint16_t)>(0x1f88598)(status,index);
    uint64_t tick=native<uint64_t(*)()>(0xea8a64)();
    int64_t current=native<int64_t(*)(void *,uint16_t,uint64_t)>(0x1f85b44)(status,index,tick);
    if(maximum<=0 || maximum>1000000000000LL || current<0 || current>maximum) return NO;
    int64_t target=static_cast<int64_t>(maximum*ratio);
    int64_t delta=target-current;
    if(!delta) return YES;
    ActorScope sender=native<ActorScope(*)(void *)>(0x3fd3a24)(manager);
    if(!sender.valid || !sender.actor) return NO;
    // Match the game's NormalMovementMethod call: authenticated local self
    // sender, Field server (4), target ActorKey, native StatusKey, fixed-point delta.
    native<void(*)(void *,int,const uint32_t *,const uint32_t *,const int64_t *)>(0x442e5e4)(sender.actor,4,&actorKey,&statusKey,&delta);
    lastRequest=@{@"actorKey":@(actorKey),@"statusKey":@(statusKey),@"delta":@(delta),@"target":@(target)};
    return YES; // queued only; callers must confirm by a subsequent native read.
}

BOOL CDSetOverlayInteraction(BOOL wanted) {
    if(!wanted&&!cursor.owned)return NO;
    char threadName[128]{};pthread_getname_np(pthread_self(),threadName,sizeof(threadName));
    if(!CDCorrectBuild() || strcmp(threadName,"GameThread")) return NO;
    void *ctx=context(0x8f72700);
    void *info=ctx ? read<void *>(ctx,8) : nullptr;
    void *input=info ? read<void *>(info,0x10) : nullptr;
    void *phase=info ? read<void *>(info,0x40) : nullptr;
    if(!input || !phase) return NO;
    uint8_t phaseID=read<uint8_t>(phase,0x32);
    auto set=native<void(*)(void *,bool,uint64_t,bool)>(0x35d9d38);
    if(wanted) {
        if(!cursor.owned) cursor={input,phaseID,read<uint8_t>(input,0x50),read<uint64_t>(input,0x48),true};
        if(cursor.input!=input) return NO;
        // IInputSystem's own cursor mode: calls OSXInputSystem::showCursor,
        // releases native capture and broadcasts InputCursorModeEvent::CHANGE.
        // GameClientModuleInfo updates its UI/gameplay input sessions from it.
        set(input,true,UINT64_MAX,false);
        return read<uint8_t>(input,0x50)==1;
    }
    if(cursor.owned && cursor.input==input && phaseID==cursor.phase && read<uint8_t>(input,0x50)==1)
        set(input,cursor.previous,cursor.position,false);
    // A menu/phase opened in the meantime owns its current cursor mode.
    cursor={};
    return YES;
}
