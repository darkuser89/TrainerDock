// SPDX-License-Identifier: GPL-3.0-only
#import "RE8Engine.h"
#import "MemoryAccess.h"
#import "RE8DiagnosticBindings.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach_vm.h>
#import <os/lock.h>
#import <os/log.h>
#import <pthread.h>
#include <stdatomic.h>
static uintptr_t p8(uintptr_t a){uintptr_t v=0;MTReadMemory((void *)a,&v,8);return v;}
static uint32_t n8(uintptr_t a){uint32_t v=0;MTReadMemory((void *)a,&v,4);return v;}
static MTRE8Engine *pump8;
static void (*original8)(void *);
@interface MTRE8Engine () {
    BOOL _known8,_installed8,_scan8;
    NSString *_installStage8;
    uintptr_t _slide8,_methods8,_types8;
    uint64_t _thread8,_frames8;
    void *_context8;
    os_unfair_lock _lock8;
    NSMutableArray<dispatch_block_t> *_queue8;
    dispatch_block_t _continuous8;
    NSUInteger _cursor8;
    os_log_t _log8;
}
- (void)frame8;
- (BOOL)wait8:(NSString *)stage;
@end
static void late8(void *entry){original8(entry);@autoreleasepool{[pump8 frame8];}}
@implementation MTRE8Engine
+ (instancetype)shared {static MTRE8Engine *e;static dispatch_once_t once;dispatch_once(&once,^{e=[self new];});return e;}
- (instancetype)init {
    if(!(self=[super init]))return nil;
    _lock8=OS_UNFAIR_LOCK_INIT;_queue8=[NSMutableArray new];_log8=os_log_create("local.mactrainer.re2","re8-engine");
    _scan8=[NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"];
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.VillageUS"])return self;
    const struct mach_header_64 *h=NULL;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *candidate=(const void *)_dyld_get_image_header(i);
        if(candidate && candidate->magic==MH_MAGIC_64 && candidate->filetype==MH_EXECUTE){h=candidate;_slide8=_dyld_get_image_vmaddr_slide(i);break;}
    }
    if(!h || h->magic!=MH_MAGIC_64 || h->cputype!=CPU_TYPE_ARM64 || h->filetype!=MH_EXECUTE || h->sizeofcmds>1024*1024 || h->ncmds>4096)return self;
    const uint8_t *cmd=(const void *)(h+1);uint32_t o=0;NSString *uuid=nil;
    for(uint32_t i=0;i<h->ncmds;i++){
        if(o>h->sizeofcmds || h->sizeofcmds-o<8)return self;struct load_command c;memcpy(&c,cmd+o,8);
        if(c.cmdsize<8 || c.cmdsize>h->sizeofcmds-o)return self;
        if(c.cmd==LC_UUID){if(uuid || c.cmdsize!=sizeof(struct uuid_command))return self;struct uuid_command u;memcpy(&u,cmd+o,sizeof(u));uuid=[[NSUUID alloc]initWithUUIDBytes:u.uuid].UUIDString;}
        o+=c.cmdsize;
    }
    if(o!=h->sizeofcmds || ![uuid isEqual:@"4C4C44EB-5555-3144-A1A1-B2C9A3FC8945"]){os_log_error(_log8,"RE8 executable identity mismatch uuid=%{public}s",uuid.UTF8String);return self;}
    const uint32_t hp[]={0xbd401020,0xd65f03c0};uint32_t actual[2];
    if(!MTReadMemory((void *)(_slide8+0x1006b757c),actual,sizeof(actual)) || memcmp(hp,actual,sizeof(hp))){os_log_error(_log8,"RE8 native health fingerprint not confirmed");return self;}
    _known8=YES;os_log(_log8,"RE8 exact executable and native health fingerprint confirmed");return self;
}
- (BOOL)identified{return _known8;}
- (BOOL)installed{return _installed8;}
- (BOOL)isRE3{return NO;}
- (uintptr_t)slide{return _slide8;}
- (NSString *)failure{return _known8 ? @"Wartet auf bestätigten RE8-Spielkontext." : @"RE8-Build nicht bestätigt.";}
- (uint32_t)componentType{return 95136;}
- (uint32_t)componentValidMethod{return 352119;}
- (uint32_t)componentGameObjectMethod{return 352118;}
- (uint32_t)gameObjectType{return 101222;}
- (uint32_t)weakGameObjectType{return 7758;}
- (uint32_t)weakConstructor{return 4606;}
- (uint32_t)weakResolver{return 4608;}
- (NSUInteger)gameObjectComponentsOffset{return 0x20;}
- (NSUInteger)weakPayloadOffset{return 0;}
- (uintptr_t)retainAddress{return _slide8+0x108197374;}
- (uintptr_t)releaseAddress{return _slide8+0x108197a14;}
- (BOOL)wait8:(NSString *)stage {if(![_installStage8 isEqual:stage]){_installStage8=stage;os_log(_log8,"RE8 delivery waiting %{public}@",stage);}return NO;}
- (BOOL)installGameThreadDelivery {
    if(_installed8)return YES;if(!_known8)return NO;uintptr_t t=_slide8+0x10cfc3ba8;
    if(n8(t)!=0x424454 || n8(t+4)!=71 || n8(t+12)!=128863 || n8(t+0x10)!=994668)return [self wait8:@"database identity"];
    _methods8=p8(t+0x70);_types8=p8(t+0x60);
    if(_methods8!=t+9278912 || _types8!=t+0x300 || (int32_t)n8(_methods8+85881*12+8)!=-129067568)return [self wait8:[NSString stringWithFormat:@"database tables methods=%llx types=%llx encoded=%d",(unsigned long long)(_methods8-t),(unsigned long long)(_types8-t),(int32_t)n8(_methods8+85881*12+8)]];
    // Install only after the actual local gameplay objects exist. Startup,
    // title assets and resource loading run with the original callbacks.
    // The native PlayerUtility.getPlayer resolves this cached ObjectDefinition.
    // Only arm delivery once its actual gameplay GameObject has a complete
    // component chain. Gameplay-only agent objects are validated in the adapter.
    void *definition=(void *)p8(_slide8+0x10fd691c8);
    void *go=(void *)p8((uintptr_t)definition+0x10);
    if([self typeOf:definition]==UINT32_MAX || [self typeOf:go]!=101222)return [self wait8:[NSString stringWithFormat:@"player definition=%u gameObject=%u",[self typeOf:definition],[self typeOf:go]]];
    BOOL ready=NO;uintptr_t component=p8((uintptr_t)go+0x20);
    for(NSUInteger i=0;component && i<512;i++){
        if(![self isObject:(void *)component kindOf:95136] || p8(component+0x10)!=(uintptr_t)go)return [self wait8:[NSString stringWithFormat:@"component type=%u localOwner=%d",[self typeOf:(void *)component],p8(component+0x10)==(uintptr_t)go]];
        ready=YES;
        uintptr_t next=p8(component+0x18);if(next==component)return NO;component=next;
    }
    if(component || !ready)return [self wait8:@"complete component chain"];
    uintptr_t app=p8(_slide8+0x10cfb8bc0),slot=app+0x96d8,expected=_slide8+0x1093789f8;char name[32]={0};
    if(!app || !MTReadMemory((void *)p8(app+0x96e8),name,sizeof(name)) || strcmp(name,"LateUpdateBehavior") || p8(slot)!=expected)return [self wait8:@"named native callback"];
    mach_vm_address_t region=slot;mach_vm_size_t size=0;vm_region_basic_info_data_64_t info={0};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;mach_port_t port=MACH_PORT_NULL;
    kern_return_t status=mach_vm_region(mach_task_self(),&region,&size,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&port);if(port)mach_port_deallocate(mach_task_self(),port);
    if(status || region>slot || slot-region>size || size-(slot-region)<8 || !(info.protection&VM_PROT_WRITE) || (info.protection&VM_PROT_EXECUTE))return NO;
    original8=(void *)expected;pump8=self;
    if(!atomic_compare_exchange_strong_explicit((_Atomic uintptr_t *)slot,&expected,(uintptr_t)late8,memory_order_acq_rel,memory_order_acquire)){pump8=nil;return NO;}
    _installed8=YES;os_log(_log8,"RE8 LateUpdateBehavior delivery installed; writable data callback only");return YES;
}
- (BOOL)isGameThread {uint64_t t=0;pthread_threadid_np(NULL,&t);return _installed8 && _thread8 && t==_thread8;}
- (void *)threadContext {uintptr_t state=p8((uintptr_t)_context8+0x50);return self.isGameThread && state && !p8(state+0x18) ? _context8 : NULL;}
- (void *)method:(uint32_t)i owner:(uint32_t)o {
    if(!_known8 || !_methods8 || i>=994668)return NULL;uint32_t row[3];if(!MTReadMemory((void *)(_methods8+i*12),row,12) || (row[0]&0x7ffff)!=o || !row[2])return NULL;
    uintptr_t a=_slide8+0x1081cdfac+(int32_t)row[2];return a>=_slide8+0x100001740 && a<_slide8+0x10bca4000 ? (void *)a : NULL;
}
- (uint32_t)typeOf:(const void *)object {
    uintptr_t t=p8(p8((uintptr_t)object));return _types8 && t>=_types8 && t<_types8+128863*72 && (t-_types8)%72==0 ? (uint32_t)((t-_types8)/72) : UINT32_MAX;
}
- (BOOL)isObject:(void *)object kindOf:(uint32_t)type {
    if(type>=128863)return NO;uint32_t actual=[self typeOf:object],t=actual;
    for(NSUInteger i=0;i<64 && t<128863;i++){if(t==type)return YES;uint32_t parent=(p8(_types8+t*72)>>19)&0x7ffff;if(!parent || parent==t)break;t=parent;}
    // Closed generic lists can use equivalent runtime type definitions. This
    // is the exact assignability helper used by RE8's own getComponent and
    // generated checked casts, with two validated TDB type rows, no VM call.
    if(actual>=128863 || !self.isGameThread)return NO;
    BOOL (*compatible)(const void *,const void *)=(void *)(_slide8+0x1081be804);
    return compatible((void *)(_types8+actual*72),(void *)(_types8+type*72));
}
- (void *)field:(uint32_t)i owner:(uint32_t)o type:(uint32_t)t object:(void *)object size:(NSUInteger)width {
    if(!self.isGameThread || i>=247966 || o>=128863 || !width || width>32 || ![self isObject:object kindOf:o])return NULL;
    uintptr_t db=_slide8+0x10cfc3ba8,fields=p8(db+0x80),impls=p8(db+0x88);uint64_t bits=0;
    if(!fields || !impls || !MTReadMemory((void *)(fields+i*8),&bits,8) || (bits&0x7ffff)!=o || ((bits>>38)&0x7ffff)!=t)return NULL;
    uint32_t impl=(bits>>19)&0x7ffff;if(impl>=n8(db+0x1c))return NULL;
    uint16_t flags=0;uintptr_t entry=impls+impl*12;if(!MTReadMemory((void *)(entry+2),&flags,2) || (flags>>1)&0x50)return NULL;
    uintptr_t vt=p8(_types8+o*72+64);int32_t base=0;
    if(!vt || !MTReadMemory((void *)(vt-8),&base,4) || base<0x10 || base>0x1000)return NULL;
    NSUInteger offset=(n8(entry+4)&0x3ffffff)+(NSUInteger)base;
    uint32_t bytes=n8(_types8+[self typeOf:object]*72+20);
    if(!bytes || offset>bytes || width>bytes-offset)return NULL;
    uint8_t scratch[32];return MTReadMemory((uint8_t *)object+offset,scratch,width) ? (uint8_t *)object+offset : NULL;
}
- (void *)virtualMethod:(uint32_t)i owner:(uint32_t)o object:(void *)object {
    if(!self.isGameThread || ![self isObject:object kindOf:o] || ![self method:i owner:o])return NULL;
    uint32_t impl=n8(_methods8+i*12+4)&0x7ffff;uintptr_t db=_slide8+0x10cfc3ba8;
    if(impl>=n8(db+0x20))return NULL;int16_t slot=-1;
    if(!MTReadMemory((void *)(p8(db+0x78)+impl*12+2),&slot,2) || slot<0 || slot>1023)return NULL;
    uintptr_t vt=p8(p8((uintptr_t)object)-16),fn=p8(vt+(NSUInteger)slot*8);
    return fn>=_slide8+0x100001740 && fn<_slide8+0x10bca4000 ? (void *)fn : NULL;
}
- (void *)singletonAt:(uintptr_t)a {return self.isGameThread && a>=0x10be5c000 && a<0x10ff44000 ? (void *)p8(_slide8+a) : NULL;}
- (void)enqueue:(dispatch_block_t)work {if(!work)return;os_unfair_lock_lock(&_lock8);if(_queue8.count<32)[_queue8 addObject:[work copy]];os_unfair_lock_unlock(&_lock8);}
- (void)setContinuousWork:(dispatch_block_t)work {if(self.isGameThread)_continuous8=[work copy];}
- (void)frame8 {
    uint64_t t=0;pthread_threadid_np(NULL,&t);if(_thread8 && t!=_thread8)return;_thread8=t;
    _context8=NULL;void *vm=(void *)p8(_slide8+0x10cfb8bd0);if(!vm)return;
    // The exact getThreadContext routine creates a missing VM context. During
    // resource startup we must never enter that allocation path. Read the
    // native thread index through the same Mach-O TLV descriptor instead, and
    // accept only the already populated VM context slot.
    uintptr_t descriptor=_slide8+0x10fc2d588;
    void *(*tls)(void *)=(void *)p8(descriptor);if(!tls)return;
    void *indexAddress=tls((void *)descriptor);int32_t index=-1;
    if(!indexAddress || !MTReadMemory(indexAddress,&index,4) || index<0 || index>=1024)return;
    uintptr_t contexts=p8((uintptr_t)vm+0x408);if(!contexts)return;
    _context8=(void *)p8(contexts+(NSUInteger)index*8);
    uintptr_t state=p8((uintptr_t)_context8+0x50);if(!_context8 || !state || p8(state+0x18))return;
    if(++_frames8==1){char name[64]={0};pthread_getname_np(pthread_self(),name,sizeof(name));os_log(_log8,"RE8 GameThread delivery confirmed thread=%{public}llu name=%{public}s",t,name);}
    if(_scan8)for(NSUInteger n=0;n<8 && _cursor8<sizeof(RE8ProbeMethods)/sizeof(RE8ProbeMethods[0]);n++,_cursor8++){
        uint32_t i=RE8ProbeMethods[_cursor8][0],o=RE8ProbeMethods[_cursor8][1];void *fn=[self method:i owner:o];os_log(_log8,"RE8Binding index=%{public}u owner=%{public}u encoded=%{public}d",i,o,fn ? (int32_t)((uintptr_t)fn-_slide8-0x1081cdfac) : 0);
    }
    NSArray *work;os_unfair_lock_lock(&_lock8);work=[_queue8 copy];[_queue8 removeAllObjects];os_unfair_lock_unlock(&_lock8);for(dispatch_block_t b in work)b();if(_continuous8)_continuous8();
}
@end
