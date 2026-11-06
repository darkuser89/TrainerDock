// SPDX-License-Identifier: GPL-3.0-only
#import "RE2Engine.h"
#import "RE4Engine.h"
#import "RE7Engine.h"
#import "RE8Engine.h"
#import "RE2Bindings.h"
#import "MemoryAccess.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach_vm.h>
#import <os/lock.h>
#import <os/log.h>
#import <pthread.h>
#include <stdatomic.h>
#import "RE2DiagnosticBindings.h"
#import "RE3DiagnosticBindings.h"

MTRE2EngineEvidence MTRE2Evidence={0};
static MTRE2Engine *pumpOwner;
static os_log_t engineLog;
static void (*originalLateUpdate)(void *);
static uint64_t pointerAt(uintptr_t address) {uint64_t value=0;MTReadMemory((void *)address,&value,sizeof(value));return value;}
static uint32_t wordAt(uintptr_t address) {uint32_t value=0;MTReadMemory((void *)address,&value,sizeof(value));return value;}
static BOOL bytesEqual(uintptr_t address,const void *expected,size_t size) {
    uint8_t buffer[64];return size<=sizeof(buffer) && MTReadMemory((void *)address,buffer,size) && !memcmp(buffer,expected,size);
}
static BOOL exchangeDataPointer(uintptr_t address,uintptr_t expected,uintptr_t value) {
    if(address%sizeof(uintptr_t))return NO;
    mach_vm_address_t region=address;mach_vm_size_t size=0;
    vm_region_basic_info_data_64_t info={0};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;mach_port_t port=MACH_PORT_NULL;
    kern_return_t result=mach_vm_region(mach_task_self(),&region,&size,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&port);
    if(port)mach_port_deallocate(mach_task_self(),port);
    if(result || region>address || sizeof(uintptr_t)>size-(address-region) || !(info.protection&VM_PROT_WRITE) || (info.protection&VM_PROT_EXECUTE))return NO;
    return atomic_compare_exchange_strong_explicit((_Atomic uintptr_t *)address,&expected,value,memory_order_acq_rel,memory_order_acquire);
}
@interface MTRE2Engine () {
    os_unfair_lock _queueLock;
    NSMutableArray<dispatch_block_t> *_pending;
    uintptr_t _methods, _types;
    uint64_t _threadID;
    void *_context;
    uintptr_t _loggedCondition;
    BOOL _bindingScan,_re3;
    NSUInteger _bindingCursor,_graphCursor;
    dispatch_block_t _continuousWork;
    uintptr_t _globalCursor;
    uintptr_t _componentScanCondition;
}
@property(nonatomic,readwrite) BOOL identified, installed;
@property(nonatomic,readwrite) uintptr_t slide;
@property(nonatomic,readwrite) NSString *failure;
- (void)frame;
@end
static void lateUpdate(void *entry) {
    originalLateUpdate(entry);
    @autoreleasepool{[pumpOwner frame];}
}
void MTRE2PrepareEngineVerification(void) {
    if(![NSProcessInfo.processInfo.environment[@"RE2_NATIVE_STARTUP"] isEqual:@"1"])return;
    dispatch_async(dispatch_get_main_queue(),^{[MTRE2Engine.shared installGameThreadDelivery];});
}
@implementation MTRE2Engine
+ (instancetype)shared {if([NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.VillageUS"])return MTRE8Engine.shared;if([NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE7US"])return MTRE7Engine.shared;if([NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE4US"])return MTRE4Engine.shared;static MTRE2Engine *engine;static dispatch_once_t once;dispatch_once(&once,^{engine=[self new];});return engine;}
- (instancetype)init {
    if(!(self=[super init]))return nil;
    engineLog=os_log_create("local.mactrainer.re2","engine");
    _queueLock=OS_UNFAIR_LOCK_INIT;_pending=[NSMutableArray new];_failure=@"Nicht im bestätigten RE2-Prozess.";
    _bindingScan=[NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"];
    _re3=[NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE3US"];
    if(!_re3 && ![NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE2US"])return self;
    const struct mach_header_64 *header=NULL;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *h=(const void *)_dyld_get_image_header(i);
        if(h && h->magic==MH_MAGIC_64 && h->cputype==CPU_TYPE_ARM64 && h->filetype==MH_EXECUTE){header=h;_slide=_dyld_get_image_vmaddr_slide(i);break;}
    }
    if(!header || header->sizeofcmds>1024*1024 || header->ncmds>4096)return self;
    const uint8_t *commands=(const void *)(header+1);uint32_t offset=0;NSString *uuid=nil;
    for(uint32_t i=0;i<header->ncmds;i++){
        if(offset>header->sizeofcmds || header->sizeofcmds-offset<8)return self;
        struct load_command c;memcpy(&c,commands+offset,sizeof(c));
        if(c.cmdsize<8 || c.cmdsize>header->sizeofcmds-offset)return self;
        if(c.cmd==LC_UUID){if(uuid || c.cmdsize!=sizeof(struct uuid_command))return self;struct uuid_command u;memcpy(&u,commands+offset,sizeof(u));uuid=[[NSUUID alloc]initWithUUIDBytes:u.uuid].UUIDString;}
        offset+=c.cmdsize;
    }
    if(offset!=header->sizeofcmds || ![uuid isEqual:(_re3 ? @"4C4C4461-5555-3144-A174-EA43301DB10B" : @"4C4C44ED-5555-3144-A15E-9285028AFD15")])return self;
    _failure=@"RE2-Laufzeit noch nicht initialisiert.";
    // Cross-check two independently observed native getter/setter pairs.
    const uint32_t health[]={_re3 ? 0xb9405420 : 0xb9405820,0xd65f03c0,_re3 ? 0xb9005422 : 0xb9005822,0xd65f03c0};
    const uint32_t invincible[]={0x39414420,0xd65f03c0,0x39014422,0xd65f03c0};
    if(!bytesEqual(_slide+(_re3 ? 0x101298eac : 0x101ff2438),health,sizeof(health)) || !bytesEqual(_slide+(_re3 ? 0x101298f2c : 0x101ff24bc),invincible,sizeof(invincible))){_failure=@"Native RE2-Fingerabdrücke weichen ab.";return self;}
    _identified=YES;
    return self;
}
- (BOOL)isRE3 {return _re3;}
- (uint32_t)componentValidMethod{return RE2Method_Component_get_Valid;}
- (uint32_t)componentGameObjectMethod{return RE2Method_Component_get_GameObject;}
- (NSUInteger)gameObjectComponentsOffset{return 0x18;}
- (NSUInteger)weakPayloadOffset{return 16;}
- (uint32_t)componentType {return _re3 ? 34621 : 31491;}
- (uint32_t)gameObjectType {return _re3 ? 36843 : 33484;}
- (uint32_t)weakGameObjectType {return _re3 ? 2740 : 2519;}
- (uint32_t)weakConstructor {return _re3 ? 7060 : 9732;}
- (uint32_t)weakResolver {return _re3 ? 7062 : 9734;}
- (uintptr_t)retainAddress {return _slide+(_re3 ? 0x104322b30 : 0x1039b17c4);}
- (uintptr_t)releaseAddress {return _slide+(_re3 ? 0x1043231f8 : 0x1039b1e8c);}
- (BOOL)installGameThreadDelivery {
    if(_installed)return YES;if(!_identified)return NO;
    uintptr_t tdb=_slide+(_re3 ? 0x1092f8060 : 0x108da47c8);
    if(wordAt(tdb)!=0x424454 || wordAt(tdb+4)!=74 || wordAt(tdb+8)!=(_re3 ? 112924 : 102046) || wordAt(tdb+0x14)!=(_re3 ? 819986 : 730907))return NO;
    _methods=pointerAt(tdb+0x78);_types=pointerAt(tdb+0x68);
    if(_methods!=tdb+(_re3 ? 0x89db10 : 0x7c93b0) || _types!=tdb+0x250)return NO;
    if((int32_t)wordAt(_methods+(_re3 ? 50237 : 51240)*12+8)!=(_re3 ? -51098276 : -27201084))return NO;
    uintptr_t application=pointerAt(_slide+(_re3 ? 0x1092f33c8 : 0x108a23248));
    if(!application)return NO;
    // Mac layout verified in this exact build: stride 0xD0, description +0x18.
    // Do not infer this from the Windows TDB74 layout.
    char description[32]={0};uintptr_t name=pointerAt(application+(_re3 ? 0xa330 : 0xa0b0));
    if(!MTReadMemory((void *)name,description,sizeof(description)) || strcmp(description,"LateUpdateBehavior"))return NO;
    uintptr_t original=_slide+(_re3 ? 0x105b0e544 : 0x105132248);
    if(pointerAt(application+(_re3 ? 0xa320 : 0xa0a0))!=original){_failure=@"Gameplay-Callback bereits verändert.";return NO;}
    originalLateUpdate=(void(*)(void *))original;pumpOwner=self;
    if(!exchangeDataPointer(application+(_re3 ? 0xa320 : 0xa0a0),original,(uintptr_t)lateUpdate)){pumpOwner=nil;_failure=@"Gameplay-Datenzeiger konnte nicht atomar übernommen werden.";return NO;}
    _installed=YES;_failure=@"Wartet auf bestätigten Gameplay-Callback.";
    os_log(engineLog,"%{public}s LateUpdateBehavior data callback installed; no code-page patch",_re3 ? "RE3" : "RE2");return YES;
}
- (BOOL)isGameThread {uint64_t thread=0;pthread_threadid_np(NULL,&thread);return _installed && _threadID && thread==_threadID;}
- (void *)threadContext {return [self isGameThread] ? _context : NULL;}
- (void *)method:(uint32_t)index owner:(uint32_t)owner {
    if(!_identified || !_methods || index>=(_re3 ? 819986 : 730907))return NULL;
    uint32_t descriptor[3];if(!MTReadMemory((void *)(_methods+index*12),descriptor,sizeof(descriptor)) || (descriptor[0]&0x7ffff)!=owner)return NULL;
    int32_t encoded=(int32_t)descriptor[2];if(!encoded)return NULL;
    uintptr_t address=_slide+(_re3 ? 0x104354150 : 0x1039e3274)+encoded;
    return address>=_slide+(_re3 ? 0x100001780 : 0x100001710) && address<_slide+(_re3 ? 0x1088bb480 : 0x107effe5c) ? (void *)address : NULL;
}
- (void *)singletonAt:(uintptr_t)slot {
    if(![self isGameThread] || slot<(_re3 ? 0x1092e8000 : 0x108a18000) || slot>=(_re3 ? 0x10ba84000 : 0x10b33c000))return NULL;
    return (void *)pointerAt(_slide+slot);
}
- (uint32_t)typeOf:(const void *)object {
    uintptr_t info=pointerAt((uintptr_t)object);
    if(!info || info%sizeof(void *))return UINT32_MAX;
    uintptr_t type=pointerAt(info);
    if(type<_types || type>=_types+(_re3 ? 112924 : 102046)*80 || (type-_types)%80)return UINT32_MAX;
    return (uint32_t)((type-_types)/80);
}
- (BOOL)isObject:(void *)object kindOf:(uint32_t)type {
    uint32_t current=[self typeOf:object];
    for(NSUInteger n=0;n<64 && current<(_re3 ? 112924 : 102046);n++){
        if(current==type)return YES;
        uint32_t parent=(uint32_t)((pointerAt(_types+current*80)>>19)&0x7ffff);
        if(!parent || parent==current)return NO;current=parent;
    }return NO;
}
- (void)enqueue:(dispatch_block_t)work {
    if(!work)return;
    os_unfair_lock_lock(&_queueLock);if(_pending.count<32)[_pending addObject:[work copy]];os_unfair_lock_unlock(&_queueLock);
}
- (void)setContinuousWork:(dispatch_block_t)work {if(self.isGameThread)_continuousWork=[work copy];}
- (void)frame {
    uint64_t thread=0;pthread_threadid_np(NULL,&thread);
    if(_threadID && thread!=_threadID){MTRE2Evidence.error=1;return;}
    _threadID=thread;
    uintptr_t vm=pointerAt(_slide+(_re3 ? 0x1092f33c0 : 0x108a23240));
    if(!vm){MTRE2Evidence.error=2;return;}
    void *(*getContext)(void *,int32_t)=(void *)(_slide+(_re3 ? 0x104331394 : 0x1039c0504));
    _context=getContext((void *)vm,-1);
    if(!_context || !pointerAt((uintptr_t)_context+0x50)){MTRE2Evidence.error=3;return;}
    if(pointerAt(pointerAt((uintptr_t)_context+0x50)+0x18)){MTRE2Evidence.error=4;return;}
    MTRE2Evidence.frames++;MTRE2Evidence.gameThreadID=thread;MTRE2Evidence.context=(uintptr_t)_context;
    pthread_getname_np(pthread_self(),MTRE2Evidence.threadName,sizeof(MTRE2Evidence.threadName));
    if(MTRE2Evidence.frames==1)os_log(engineLog,"GameThread delivery confirmed: thread=%{public}llu name=%{public}s",(unsigned long long)thread,MTRE2Evidence.threadName);
    MTRE2Evidence.playerManager=pointerAt(_slide+(_re3 ? 0x10b88e5e0 : 0x10b190e18));
    void *(*getCondition)(void *,void *)=[self method:_re3 ? 471109 : 422746 owner:_re3 ? 26965 : 20583];
    if(getCondition && MTRE2Evidence.playerManager){
        void *condition=getCondition(_context,(void *)MTRE2Evidence.playerManager);
        MTRE2Evidence.playerCondition=(uintptr_t)condition;
        if(condition){
            MTRE2Evidence.hitPoints=pointerAt((uintptr_t)condition+(_re3 ? 0x250 : 0x1f0));
            if([self typeOf:(void *)MTRE2Evidence.hitPoints]==(_re3 ? 15590 : 26336)){
                MTRE2Evidence.health=wordAt(MTRE2Evidence.hitPoints+(_re3 ? 0x54 : 0x58));
                MTRE2Evidence.maxHealth=wordAt(MTRE2Evidence.hitPoints+(_re3 ? 0x58 : 0x54));
                if(_loggedCondition!=(uintptr_t)condition){
                    _loggedCondition=(uintptr_t)condition;
                    os_log(engineLog,"Player read confirmed on GameThread: health=%{public}u max=%{public}u",MTRE2Evidence.health,MTRE2Evidence.maxHealth);
                }
            }
        }else _loggedCondition=0;
    }
    MTRE2Evidence.error=0;
    if(_bindingScan && _re3){
        for(NSUInteger n=0;n<8 && _bindingCursor<sizeof(RE3ProbeMethods)/sizeof(RE3ProbeMethods[0]);n++,_bindingCursor++){
            uint32_t index=RE3ProbeMethods[_bindingCursor][0],owner=RE3ProbeMethods[_bindingCursor][1];
            void *fn=[self method:index owner:owner];int32_t encoded=fn ? (int32_t)((uintptr_t)fn-_slide-0x104354150) : 0;
            os_log(engineLog,"RE3Binding index=%{public}u owner=%{public}u encoded=%{public}d",index,owner,encoded);
        }
    }
    if(_bindingScan && !_re3){
        // Bounded metadata-only work: eight descriptors and one small object
        // graph node per frame. No process suspension or callable scan input.
        for(NSUInteger n=0;n<8 && _bindingCursor<sizeof(RE2DiagnosticMethods)/sizeof(RE2DiagnosticMethods[0]);n++, _bindingCursor++){
            uint32_t index=RE2DiagnosticMethods[_bindingCursor][0],owner=RE2DiagnosticMethods[_bindingCursor][1];
            void *fn=[self method:index owner:owner];
            int32_t encoded=fn ? (int32_t)((uintptr_t)fn-_slide-0x1039e3274) : 0;
            os_log(engineLog,"Binding index=%{public}u owner=%{public}u encoded=%{public}d",index,owner,encoded);
        }
        uintptr_t condition=MTRE2Evidence.playerCondition;
        if(condition && condition!=_componentScanCondition){
            void *(*getGO)(void *,void *)=[self method:5729 owner:31491];
            void *(*getComponents)(void *,void *)=[self method:226025 owner:33484];
            void *go=getGO ? getGO(_context,(void *)condition) : NULL;
            void *components=go && getComponents ? getComponents(_context,go) : NULL;
            uint32_t length=wordAt((uintptr_t)components+0x1c);
            if([self typeOf:components]==20243 && length>0 && length<=128){
                _componentScanCondition=condition;
                for(uint32_t n=0;n<length;n++){uintptr_t component=pointerAt((uintptr_t)components+0x20+n*8);os_log(engineLog,"Player component type=%{public}u",[self typeOf:(void *)component]);}
            }
        }
        uintptr_t equipment=pointerAt(condition+0xf0),gun=pointerAt(equipment+0xe8);
        if(condition && gun && _graphCursor<7){
            uintptr_t manager=pointerAt(_slide+0x10b185e98),inventory=pointerAt(manager+0x50),slot=pointerAt(inventory+0x98),stock=pointerAt(slot+0x10);
            uintptr_t nodes[]={condition,equipment,gun,manager,inventory,slot,stock};
            uintptr_t object=nodes[_graphCursor];uint32_t type=[self typeOf:(void *)object];
            os_log(engineLog,"Graph root=%{public}lu type=%{public}u",(unsigned long)_graphCursor,type);
            if(type!=UINT32_MAX)for(size_t offset=0x10;offset<0x200;offset+=8){
                uintptr_t child=pointerAt(object+offset);uint32_t childType=[self typeOf:(void *)child];
                if(childType!=UINT32_MAX)os_log(engineLog,"Graph root=%{public}lu field=%{public}lu childType=%{public}u",(unsigned long)_graphCursor,(unsigned long)offset,childType);
            }
            _graphCursor++;
        }
        if(condition && _globalCursor<0x50000){
            for(NSUInteger n=0;n<192 && _globalCursor<0x50000;n++,_globalCursor+=8){
                uintptr_t slot=0x10b150000+_globalCursor,object=pointerAt(_slide+slot);uint32_t type=[self typeOf:(void *)object];
                if(type==10375 || type==7343 || type==7103 || type==21843)os_log(engineLog,"Singleton type=%{public}u slot=%{public}llx",type,(unsigned long long)slot);
            }
        }
    }
    NSArray<dispatch_block_t> *work;
    os_unfair_lock_lock(&_queueLock);work=[_pending copy];[_pending removeAllObjects];os_unfair_lock_unlock(&_queueLock);
    for(dispatch_block_t block in work)block();
    if(_continuousWork)_continuousWork();
}
@end
