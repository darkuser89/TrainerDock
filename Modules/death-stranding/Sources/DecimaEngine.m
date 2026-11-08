// SPDX-License-Identifier: GPL-3.0-only
#import "DecimaEngine.h"
#import "MemoryAccess.h"
#import "DecimaBindings.h"
#include <math.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <os/lock.h>
#include <pthread.h>
#include <stdatomic.h>
static intptr_t imageSlide;
static atomic_bool bound;
static IMP originalDisplay,originalTimer;
static pthread_t engineThread;
static atomic_bool hasEngineThread;
static atomic_bool applicationActive;
static os_unfair_lock queueLock=OS_UNFAIR_LOCK_INIT;
static NSMutableArray<dispatch_block_t> *queue;
static dispatch_block_t maintenance;
uintptr_t MHTDSAddress(uintptr_t original){return original+(uintptr_t)imageSlide;}
BOOL MHTDSBuildMatches(void){
    BOOL found=NO;uuid_t expected;uuid_parse("6823C89C-242D-37B0-ABC4-4D45A67E7C4C",expected);
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *header=(const void *)_dyld_get_image_header(i);if(header->filetype!=MH_EXECUTE)continue;
        if(header->magic!=MH_MAGIC_64 || header->cputype!=CPU_TYPE_ARM64 || header->sizeofcmds>1024*1024)return NO;
        const uint8_t *cursor=(const void *)(header+1),*end=cursor+header->sizeofcmds;
        for(uint32_t j=0;j<header->ncmds;j++){
            if(cursor+sizeof(struct load_command)>end)return NO;const struct load_command *command=(const void *)cursor;
            if(command->cmdsize<sizeof(*command) || cursor+command->cmdsize>end)return NO;
            if(command->cmd==LC_UUID){if(command->cmdsize!=sizeof(struct uuid_command) || found)return NO;found=!memcmp(((const struct uuid_command *)command)->uuid,expected,16);}
            cursor+=command->cmdsize;
        }
        if(found)imageSlide=_dyld_get_image_vmaddr_slide(i);
        return found;
    }return NO;
}
BOOL MHTDSIsEngineThread(void){return hasEngineThread && pthread_equal(engineThread,pthread_self());}
static void onFrame(void){
    char name[64]={0};pthread_getname_np(pthread_self(),name,sizeof(name));if(strcmp(name,"AppMainThread"))return;
    if(!hasEngineThread){engineThread=pthread_self();hasEngineThread=YES;}if(!MHTDSIsEngineThread())return;
    os_unfair_lock_lock(&queueLock);NSArray<dispatch_block_t> *batch=[queue copy];dispatch_block_t upkeep=maintenance;[queue removeAllObjects];os_unfair_lock_unlock(&queueLock);
    @autoreleasepool{for(dispatch_block_t work in batch)work();if(upkeep)upkeep();}
}
static void displayFrame(id object,SEL selector){((void(*)(id,SEL))originalDisplay)(object,selector);onFrame();}
static void timerFrame(id object,SEL selector){((void(*)(id,SEL))originalTimer)(object,selector);onFrame();}
BOOL MHTDSAttachEngine(void){
    NSCAssert(NSThread.isMainThread,@"Objective-C hook installation belongs on AppKit's main thread");
    if(bound)return YES;if(!MHTDSBuildMatches())return NO;
    Method display=class_getInstanceMethod(NSClassFromString(@"FramePacingCAMetalDisplayLink"),NSSelectorFromString(@"waitForNextFrame"));
    Method timer=class_getInstanceMethod(NSClassFromString(@"FramePacingTimer"),NSSelectorFromString(@"waitForNextFrame"));
    if(!display || !timer || (uintptr_t)method_getImplementation(display)!=MHTDSAddress(0x103d94658) || (uintptr_t)method_getImplementation(timer)!=MHTDSAddress(0x103d94aa8))return NO;
    for(NSUInteger i=0;i<sizeof(nativeBindings)/sizeof(*nativeBindings);i++){uint8_t bytes[16];if(!MTReadMemory((void *)MHTDSAddress(nativeBindings[i].address),bytes,sizeof(bytes)) || memcmp(bytes,nativeBindings[i].bytes,sizeof(bytes)))return NO;}
    queue=[NSMutableArray new];originalDisplay=method_getImplementation(display);originalTimer=method_getImplementation(timer);
    method_setImplementation(display,(IMP)displayFrame);method_setImplementation(timer,(IMP)timerFrame);bound=YES;return YES;
}
void MHTDSSchedule(dispatch_block_t work){
    if(!bound || !work)return;if(MHTDSIsEngineThread()){work();return;}
    os_unfair_lock_lock(&queueLock);if(queue.count<64)[queue addObject:[work copy]];os_unfair_lock_unlock(&queueLock);
}
static uintptr_t pointer(uintptr_t address){uintptr_t value=0;MTReadMemory((void *)address,&value,sizeof(value));return value;}
BOOL MHTDSCaptureOwner(MHTDSOwner *out){
    if(!out || !bound || !MHTDSIsEngineThread())return NO;MHTDSOwner owner={0};
    owner.system=pointer(MHTDSAddress(0x1060af3c0));owner.pool=pointer(MHTDSAddress(0x1078c2548));
    int32_t count=0;if(!owner.system || !owner.pool || !MTReadMemory((void *)(owner.pool+0x38),&count,sizeof(count)) || count<1 || count>32)return NO;
    uintptr_t entries=pointer(owner.pool+0x40);if(!entries)return NO;
    for(int32_t i=0;i<count;i++){
        uintptr_t actor=pointer(entries+(size_t)i*8);uint32_t kind=UINT32_MAX;
        if(!actor || !MTReadMemory((void *)(actor+0x88),&kind,sizeof(kind)) || kind!=0)continue;
        if(owner.actor)return NO; // Ambiguous ownership is never guessed.
        owner.actor=actor;owner.entity=pointer(actor+0x70);
    }
    if(!owner.entity)return NO;
    owner.component=pointer(owner.entity+0x55b0);owner.vitals=pointer(owner.entity+0x55c8);owner.parameters=pointer(owner.entity+0x55a8);
    if(!owner.component || !owner.vitals || !owner.parameters)return NO;
    if(pointer(owner.vitals)!=MHTDSAddress(0x105718918)
       || pointer(owner.parameters)!=MHTDSAddress(0x105718e10)
       || pointer(owner.vitals+0x98)!=owner.parameters)return NO;
    uintptr_t vtable=pointer(owner.entity);
    if(vtable<MHTDSAddress(0x10563c000) || vtable>=MHTDSAddress(0x105864000))return NO;
    *out=owner;return YES;
}
void MHTDSSetMaintenance(dispatch_block_t work){os_unfair_lock_lock(&queueLock);maintenance=[work copy];os_unfair_lock_unlock(&queueLock);}
static BOOL sameOwner(MHTDSOwner owner){MHTDSOwner current={0};return MHTDSCaptureOwner(&current) && !memcmp(&current,&owner,sizeof(owner));}
static BOOL scalar(uintptr_t address,float *value){return MTReadMemory((void *)address,value,4) && isfinite(*value);}
BOOL MHTDSReadVitals(MHTDSOwner owner,MHTDSVitals *out){
    if(!out || !sameOwner(owner))return NO;MHTDSVitals v={0};
    if(!scalar(owner.vitals+0xc0,&v.blood) || !scalar(owner.vitals+0xc4,&v.maximumBlood) ||
       !scalar(owner.vitals+0xdc,&v.consciousness) || !scalar(owner.vitals+0xe0,&v.maximumConsciousness) ||
       !scalar(owner.vitals+0x110,&v.stamina) || !scalar(owner.vitals+0x108,&v.maximumStamina) || !scalar(owner.vitals+0x130,&v.fatigue) ||
       !scalar(owner.vitals+0x140,&v.standReserve) || !scalar(owner.vitals+0x144,&v.maximumStandReserve) ||
       !scalar(owner.component+0x4810,&v.battery) || !scalar(owner.component+0x4814,&v.maximumBattery) ||
       !scalar(owner.vitals+0x32c,&v.shoes) || !scalar(owner.vitals+0x330,&v.maximumShoes))return NO;
    float extra=0,currentExtra=0;if(!scalar(owner.vitals+0x334,&extra) || !scalar(owner.vitals+0x33c,&currentExtra))return NO;v.maximumShoes+=extra;v.shoes+=currentExtra;
    // PlayerSystem+0x203ac is only a request (-1 means none). Its +0xfcf8
    // serialization snapshot is also stale after live changes. Current stress
    // and its presentation are the pair in this player's parameter component.
    v.bbStress=v.maximumBBStress=v.displayBBStress=-1;
    scalar(owner.parameters+0x42c4,&v.bbStress);
    scalar(owner.parameters+0xfb0,&v.maximumBBStress);
    scalar(owner.parameters+0x42c8,&v.displayBBStress);
    if(!MTReadMemory((void *)(owner.system+0x1b7c),&v.crystals,4) || !MTReadMemory((void *)(owner.system+0x1b80),&v.maximumCrystals,4))return NO;
    if(v.maximumBlood<=0 || v.maximumBlood>1000000 || v.maximumConsciousness<=0 || v.maximumConsciousness>1000000 || v.maximumStamina<=0 || v.maximumStamina>1000000)return NO;
    *out=v;return YES;
}
BOOL MHTDSSetBlood(MHTDSOwner owner,float amount){
    MHTDSVitals v;if(!isfinite(amount) || !MHTDSReadVitals(owner,&v) || amount<1 || amount>v.maximumBlood)return NO;
    ((void(*)(void *,float,int,int))MHTDSAddress(0x102dde1dc))((void *)owner.vitals,amount,0,0);return YES;
}
BOOL MHTDSFillConsciousness(MHTDSOwner owner){
    if(!sameOwner(owner))return NO;((void(*)(void *))MHTDSAddress(0x102dde9c4))((void *)owner.vitals);return YES;
}
BOOL MHTDSAddStamina(MHTDSOwner owner,float amount){
    MHTDSVitals v;if(!isfinite(amount) || !MHTDSReadVitals(owner,&v) || fabsf(amount)>v.maximumStamina)return NO;
    ((void(*)(void *,float,int))MHTDSAddress(0x102ddef58))((void *)owner.vitals,amount,0);return YES;
}
BOOL MHTDSSetFatigue(MHTDSOwner owner,float amount){
    if(!sameOwner(owner) || !isfinite(amount) || amount<0 || amount>10000)return NO;
    ((void(*)(void *,float))MHTDSAddress(0x102ddf0e0))((void *)owner.vitals,amount);return YES;
}
BOOL MHTDSRecoverBattery(MHTDSOwner owner){if(!sameOwner(owner))return NO;((void(*)(void))MHTDSAddress(0x102ef95c4))();return YES;}
BOOL MHTDSRecoverShoes(MHTDSOwner owner){
    if(!sameOwner(owner) || !pointer(owner.vitals+0x368))return NO;((void(*)(float))MHTDSAddress(0x102ef96f0))(1.0f);return YES;
}
BOOL MHTDSSetCrystals(MHTDSOwner owner,int32_t amount){
    MHTDSVitals v;if(!MHTDSReadVitals(owner,&v) || amount<0 || amount>v.maximumCrystals)return NO;
    ((void(*)(int32_t))MHTDSAddress(0x102ef7b50))(amount);return YES;
}
BOOL MHTDSResourceFull(float current,float maximum){return isfinite(current) && isfinite(maximum) && maximum>0 && current>=maximum-0.01f;}
BOOL MHTDSAddStandReserve(MHTDSOwner owner,float amount){
    MHTDSVitals v;
    if(!isfinite(amount) || !MHTDSReadVitals(owner,&v) || v.maximumStandReserve<=0
       || v.maximumStandReserve>1000000 || fabsf(amount)>v.maximumStandReserve)return NO;
    // Original LifeComponent reserve accumulator, also used by river drain.
    // Positive refill leaves the engine's cause flags untouched (reason = 0).
    ((void(*)(void *,float,uint32_t))MHTDSAddress(0x102deb180))((void *)owner.vitals,amount,0);
    return YES;
}
BOOL MHTDSSetBBStressRate(MHTDSOwner owner,float rate){
    MHTDSVitals v;if(!isfinite(rate) || rate<0 || rate>1 || !MHTDSReadVitals(owner,&v)
        || v.maximumBBStress<=0 || v.maximumBBStress>1000000 || v.bbStress<0
        || v.bbStress>v.maximumBBStress || v.displayBBStress<0 || v.displayBBStress>v.maximumBBStress)return NO;
    ((void(*)(float))MHTDSAddress(0x102ef97a4))(rate);return YES;
}
void MHTDSClearBBRequest(uintptr_t system){
    if(!system || !bound || !MHTDSIsEngineThread() || pointer(MHTDSAddress(0x1060af3c0))!=system)return;
    float pending=-1;
    // Retire only our still-pending zero request; do not restore old stress or
    // overwrite a different script's later requested value.
    if(scalar(system+0x203ac,&pending) && pending==0)MTWriteFloat((void *)system,0x203ac,-1);
}
// Original DSTimeScaleController request ABI, verified at its callers and RTTI.
_Static_assert(offsetof(MHTDSTimeRequest,retained)==0x2c,"time request retained");
_Static_assert(offsetof(MHTDSTimeRequest,curves)==0x30,"time request curves");
_Static_assert(offsetof(MHTDSTimeRequest,name)==0x50,"time request name");
_Static_assert(offsetof(MHTDSTimeRequest,priority)==0x58 && sizeof(MHTDSTimeRequest)==0x60,"time request ABI");
static const uint32_t timePriority=0x5444;
BOOL MHTDSPrepareTimeRequest(float value,MHTDSTimeRequest *request){
    if(!request || !isfinite(value) || value<0.25f || value>3.0f)return NO;
    *request=(MHTDSTimeRequest){.scales={value,value,value},.duration=3600,.endingScales={1,1,1},
        .retained=1,.name=-1,.identifier=-1,.priority=timePriority};return YES;
}
static BOOL timeController(uintptr_t system,uintptr_t *out){
    if(!bound || !MHTDSIsEngineThread() || !system || pointer(MHTDSAddress(0x1060af3c0))!=system)return NO;
    uintptr_t controller=system+0x20860;int32_t count=-1,capacity=-1;
    if(!MTReadMemory((void *)controller,&count,4) || !MTReadMemory((void *)(controller+4),&capacity,4)
       || count<0 || count>256 || capacity<count || capacity>4096 || (count && !pointer(controller+8)))return NO;
    *out=controller;return YES;
}
BOOL MHTDSReadTime(MHTDSOwner owner,float scales[3]){
    uintptr_t controller=0;if(!scales || !sameOwner(owner) || !timeController(owner.system,&controller))return NO;
    pthread_mutex_t *lock=(void *)(controller+0x98);if(pthread_mutex_lock(lock))return NO;
    BOOL ok=YES;for(unsigned i=0;i<3;i++)ok=scalar(controller+0x18+i*4,&scales[i]) && scales[i]>0 && scales[i]<=3 && ok;
    pthread_mutex_unlock(lock);return ok;
}
static BOOL ownsTimeRequest(MHTDSTimeControl control,uintptr_t controller){
    int32_t count=0;uintptr_t entries=pointer(controller+8);
    if(!control.owned || !MTReadMemory((void *)controller,&count,4) || count<1 || count>256 || !entries)return NO;
    for(int32_t i=0;i<count;i++){
        MHTDSTimeRequest record={0};uintptr_t address=entries+(size_t)i*0x78;
        if(!MTReadMemory((void *)address,&record,sizeof(record)))return NO;
        if(record.identifier!=control.identifier)continue;
        // Match our complete request signature before retiring an ID that the
        // engine may reuse after a reset. Never erase another system's request.
        return record.priority==timePriority && record.name==-1 && record.retained==1 && record.duration==3600
            && record.scales[0]==control.value && record.scales[1]==control.value && record.scales[2]==control.value
            && !record.curves[0] && !record.curves[1] && !record.curves[2] && !record.sound;
    }return NO;
}
void MHTDSClearTime(MHTDSTimeControl *control){
    if(!control)return;uintptr_t controller=0;
    if(control->owned && timeController(control->system,&controller)){
        pthread_mutex_t *lock=(void *)(controller+0x98);BOOL ours=NO;
        if(pthread_mutex_lock(lock))return;ours=ownsTimeRequest(*control,controller);pthread_mutex_unlock(lock);
        if(ours)((void(*)(void *,int32_t))MHTDSAddress(0x102ee7ea8))((void *)control->system,control->identifier);
    }*control=(MHTDSTimeControl){0};
}
BOOL MHTDSSetTime(MHTDSOwner owner,float value,MHTDSTimeControl *control){
    MHTDSTimeRequest request;uintptr_t controller=0;
    if(!control || !MHTDSPrepareTimeRequest(value,&request) || !sameOwner(owner) || !timeController(owner.system,&controller))return NO;
    pthread_mutex_t *lock=(void *)(controller+0x98);BOOL ours=NO;
    if(pthread_mutex_lock(lock))return NO;ours=control->system==owner.system && ownsTimeRequest(*control,controller);pthread_mutex_unlock(lock);
    if(ours && control->value==value)return YES;
    MHTDSClearTime(control);
    if(control->owned)return NO;
    int32_t count=0;if(!MTReadMemory((void *)controller,&count,4) || count>=256)return NO;
    int32_t identifier=((int32_t(*)(void *,const MHTDSTimeRequest *))MHTDSAddress(0x102ee7754))((void *)controller,&request);
    *control=(MHTDSTimeControl){owner.system,identifier,value,YES};
    if(pthread_mutex_lock(lock))return NO;ours=ownsTimeRequest(*control,controller);pthread_mutex_unlock(lock);
    return ours;
}
BOOL MHTDSReadCapacity(MHTDSOwner owner,float bases[2],float effective[2]){
    if(!bases || !effective || !sameOwner(owner))return NO;
    // Per-player common-parameter copies; original loading calculator reads
    // these two bases and publishes its final limits at ParamComponent+0x600.
    for(unsigned i=0;i<2;i++)if(!scalar(owner.parameters+0xc54+i*4,&bases[i]) || bases[i]<0.1f || bases[i]>20000
        || !scalar(owner.parameters+0x600+i*4,&effective[i]) || effective[i]<0.1f || effective[i]>100000)return NO;
    return YES;
}
void MHTDSClearCapacity(MHTDSCapacityControl *control){
    if(!control || !control->owned)return;MHTDSOwner current={0};
    // During loading retain the pending restoration; never dereference an old
    // player. A genuinely new owner gets its own unmodified parameter block.
    if(!MHTDSCaptureOwner(&current))return;
    if(memcmp(&current,&control->owner,sizeof(current))){*control=(MHTDSCapacityControl){0};return;}
    float bases[2],effective[2];if(!MHTDSReadCapacity(current,bases,effective))return;
    BOOL changed=NO;for(unsigned i=0;i<2;i++)if(bases[i]==control->written[i]){bases[i]=control->previous[i];changed=YES;}
    if(changed && !MTWriteMemory((void *)(current.parameters+0xc54),bases,sizeof(bases)))return;
    *control=(MHTDSCapacityControl){0};
}
BOOL MHTDSSetCapacity(MHTDSOwner owner,float value,MHTDSCapacityControl *control){
    float bases[2],effective[2];if(!control || !isfinite(value) || value<1 || value>9999 || floorf(value)!=value
        || !MHTDSReadCapacity(owner,bases,effective))return NO;
    if(control->owned && memcmp(&control->owner,&owner,sizeof(owner)))MHTDSClearCapacity(control);
    if(!control->owned){*control=(MHTDSCapacityControl){.owner=owner,.previous={bases[0],bases[1]},.owned=YES};}
    else for(unsigned i=0;i<2;i++)if(bases[i]!=control->written[i])control->previous[i]=bases[i];
    float wanted[2]={value,value};
    if(!MTWriteMemory((void *)(owner.parameters+0xc54),wanted,sizeof(wanted)))return NO;
    memcpy(control->written,wanted,sizeof(wanted));return MHTDSReadCapacity(owner,bases,effective) && bases[0]==value && bases[1]==value;
}
void MHTDSSetApplicationActive(BOOL active){applicationActive=active;}
BOOL MHTDSOverlayInteraction(BOOL wanted){
    static uintptr_t ownedMouse;
    static uint8_t beforeVisible,beforeClamped;
    if(!bound || !MHTDSIsEngineThread())return NO;
    uintptr_t mouse=pointer(MHTDSAddress(0x10638fc40));uint8_t visible=0,clamped=0;
    if(!mouse || pointer(mouse)!=MHTDSAddress(0x105795270)
       || !MTReadMemory((void *)(mouse+0x151),&visible,1)
       || !MTReadMemory((void *)(mouse+0x1c4),&clamped,1) || visible>1 || clamped>1){ownedMouse=0;return NO;}
    void(*show)(void *,BOOL)=(void *)MHTDSAddress(0x103de10b8);
    void(*clamp)(void *,BOOL)=(void *)MHTDSAddress(0x103de1150);
    if(wanted && applicationActive){
        if(ownedMouse!=mouse){ownedMouse=mouse;beforeVisible=visible;beforeClamped=clamped;}
        show((void *)mouse,YES);clamp((void *)mouse,NO);
        return MTReadMemory((void *)(mouse+0x151),&visible,1) && visible==1
            && MTReadMemory((void *)(mouse+0x1c4),&clamped,1) && clamped==0;
    }
    // Return only the state still owned by us; never capture another app's mouse.
    if(ownedMouse==mouse && applicationActive && visible==1 && clamped==0){
        show((void *)mouse,beforeVisible);clamp((void *)mouse,beforeClamped);
    }
    ownedMouse=0;return NO;
}
