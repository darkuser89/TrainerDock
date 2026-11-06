// SPDX-License-Identifier: GPL-3.0-only
#import "RE7Engine.h"
#import "MemoryAccess.h"
#import "RE7DiagnosticBindings.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach_vm.h>
#import <os/lock.h>
#import <os/log.h>
#import <pthread.h>
#include <stdatomic.h>
static uintptr_t p7(uintptr_t a){uintptr_t v=0;MTReadMemory((void *)a,&v,8);return v;}
static uint32_t n7(uintptr_t a){uint32_t v=0;MTReadMemory((void *)a,&v,4);return v;}
static MTRE7Engine *pump7;
static void (*original7)(void *);
@interface MTRE7Engine () {
    BOOL _known7,_installed7,_scan7;
    uintptr_t _slide7,_methods7,_types7;
    uint64_t _thread7,_frames7;
    void *_context7;
    os_unfair_lock _lock7;
    NSMutableArray<dispatch_block_t> *_queue7;
    dispatch_block_t _continuous7;
    NSUInteger _cursor7;
    os_log_t _log7;
}
- (void)frame7;
@end
static void late7(void *entry){original7(entry);@autoreleasepool{[pump7 frame7];}}
@implementation MTRE7Engine
+ (instancetype)shared {static MTRE7Engine *e;static dispatch_once_t once;dispatch_once(&once,^{e=[self new];});return e;}
- (instancetype)init {
    if(!(self=[super init]))return nil;
    _lock7=OS_UNFAIR_LOCK_INIT;_queue7=[NSMutableArray new];_log7=os_log_create("local.mactrainer.re2","re7-engine");
    _scan7=[NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"];
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE7US"])return self;
    const struct mach_header_64 *h=NULL;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *candidate=(const void *)_dyld_get_image_header(i);
        if(candidate && candidate->magic==MH_MAGIC_64 && candidate->filetype==MH_EXECUTE){h=candidate;_slide7=_dyld_get_image_vmaddr_slide(i);break;}
    }
    if(!h || h->magic!=MH_MAGIC_64 || h->cputype!=CPU_TYPE_ARM64 || h->filetype!=MH_EXECUTE || h->sizeofcmds>1024*1024 || h->ncmds>4096)return self;
    const uint8_t *cmd=(const void *)(h+1);uint32_t o=0;NSString *uuid=nil;
    for(uint32_t i=0;i<h->ncmds;i++){
        if(o>h->sizeofcmds || h->sizeofcmds-o<8)return self;struct load_command c;memcpy(&c,cmd+o,8);
        if(c.cmdsize<8 || c.cmdsize>h->sizeofcmds-o)return self;
        if(c.cmd==LC_UUID){if(uuid || c.cmdsize!=sizeof(struct uuid_command))return self;struct uuid_command u;memcpy(&u,cmd+o,sizeof(u));uuid=[[NSUUID alloc]initWithUUIDBytes:u.uuid].UUIDString;}
        o+=c.cmdsize;
    }
    if(o!=h->sizeofcmds || ![uuid isEqual:@"4C4C4466-5555-3144-A1F6-0D461A1E2960"]){os_log_error(_log7,"RE7 executable identity mismatch uuid=%{public}s",uuid.UTF8String);return self;}
    const uint32_t hp[]={0xbd401020,0xd65f03c0,0xbd401420,0xd65f03c0};uint32_t actual[4];
    if(!MTReadMemory((void *)(_slide7+0x102708480),actual,sizeof(actual)) || memcmp(hp,actual,sizeof(hp))){os_log_error(_log7,"RE7 native health fingerprint not confirmed");return self;}
    _known7=YES;os_log(_log7,"RE7 exact executable and native health fingerprint confirmed");return self;
}
- (BOOL)identified{return _known7;}
- (BOOL)installed{return _installed7;}
- (BOOL)isRE3{return NO;}
- (uintptr_t)slide{return _slide7;}
- (NSString *)failure{return _known7 ? @"Wartet auf bestätigten RE7-Spielkontext." : @"RE7-Build nicht bestätigt.";}
- (uint32_t)componentType{return 32277;}
- (uint32_t)componentValidMethod{return 224207;}
- (uint32_t)componentGameObjectMethod{return 224206;}
- (uint32_t)gameObjectType{return 34333;}
- (uint32_t)weakGameObjectType{return 2572;}
- (uint32_t)weakConstructor{return 3316;}
- (uint32_t)weakResolver{return 3318;}
- (NSUInteger)weakPayloadOffset{return 0;}
- (uintptr_t)retainAddress{return _slide7+0x104004a04;}
- (uintptr_t)releaseAddress{return _slide7+0x1040050cc;}
- (BOOL)installGameThreadDelivery {
    if(_installed7)return YES;if(!_known7)return NO;uintptr_t t=_slide7+0x1090e0180;
    if(n7(t)!=0x424454 || n7(t+4)!=73 || n7(t+8)!=91400 || n7(t+0x10)!=597628)return NO;
    _methods7=p7(t+0x70);_types7=p7(t+0x60);
    if(_methods7!=t+6581392 || _types7!=t+0x250 || (int32_t)n7(_methods7+15608*12+8)!=-29318172)return NO;
    // Install only after the actual local gameplay objects exist. Startup,
    // title assets and resource loading run with the original callbacks.
    void *manager=(void *)p7(_slide7+0x10b364158);int32_t chapter=(int32_t)n7((uintptr_t)manager+0x54);
    BOOL playable=chapter==2 || (chapter>=4 && chapter<=14) || (chapter>=22 && chapter<=25) || (chapter>=29 && chapter<=32) || chapter==34 || chapter==35 || chapter==37;
    void *root=(void *)p7(_slide7+0x10b3993c8),*go=(void *)p7((uintptr_t)root+0x88);
    if(![self isObject:manager kindOf:11603] || !playable || [self typeOf:go]!=34333)return NO;
    BOOL statusReady=NO,damageReady=NO;uintptr_t component=p7((uintptr_t)go+0x18);
    for(NSUInteger i=0;component && i<512;i++){
        if(![self isObject:(void *)component kindOf:32277] || p7(component+0x10)!=(uintptr_t)go)return NO;
        if([self isObject:(void *)component kindOf:40739])statusReady=YES;
        if([self isObject:(void *)component kindOf:5616])damageReady=YES;
        uintptr_t next=p7(component+0x18);if(next==component)return NO;component=next;
    }
    if(component || !statusReady || !damageReady)return NO;
    uintptr_t app=p7(_slide7+0x108d16d00),slot=app+0x9e30,expected=_slide7+0x1056daa58;char name[32]={0};
    if(!app || !MTReadMemory((void *)p7(app+0x9e40),name,sizeof(name)) || strcmp(name,"LateUpdateBehavior") || p7(slot)!=expected)return NO;
    mach_vm_address_t region=slot;mach_vm_size_t size=0;vm_region_basic_info_data_64_t info={0};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;mach_port_t port=MACH_PORT_NULL;
    kern_return_t status=mach_vm_region(mach_task_self(),&region,&size,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&port);if(port)mach_port_deallocate(mach_task_self(),port);
    if(status || region>slot || slot-region>size || size-(slot-region)<8 || !(info.protection&VM_PROT_WRITE) || (info.protection&VM_PROT_EXECUTE))return NO;
    original7=(void *)expected;pump7=self;
    if(!atomic_compare_exchange_strong_explicit((_Atomic uintptr_t *)slot,&expected,(uintptr_t)late7,memory_order_acq_rel,memory_order_acquire)){pump7=nil;return NO;}
    _installed7=YES;os_log(_log7,"RE7 LateUpdateBehavior delivery installed; writable data callback only");return YES;
}
- (BOOL)isGameThread {uint64_t t=0;pthread_threadid_np(NULL,&t);return _installed7 && _thread7 && t==_thread7;}
- (void *)threadContext{return self.isGameThread ? _context7 : NULL;}
- (void *)method:(uint32_t)i owner:(uint32_t)o {
    if(!_known7 || !_methods7 || i>=597628)return NULL;uint32_t row[3];if(!MTReadMemory((void *)(_methods7+i*12),row,12) || (row[0]&0x7ffff)!=o || !row[2])return NULL;
    uintptr_t a=_slide7+0x1040352ec+(int32_t)row[2];return a>=_slide7+0x100001740 && a<_slide7+0x1086b0000 ? (void *)a : NULL;
}
- (uint32_t)typeOf:(const void *)object {
    uintptr_t t=p7(p7((uintptr_t)object));return _types7 && t>=_types7 && t<_types7+91400*72 && (t-_types7)%72==0 ? (uint32_t)((t-_types7)/72) : UINT32_MAX;
}
- (BOOL)isObject:(void *)object kindOf:(uint32_t)type {
    if(type>=91400)return NO;uint32_t actual=[self typeOf:object],t=actual;
    for(NSUInteger i=0;i<64 && t<91400;i++){if(t==type)return YES;uint32_t parent=(p7(_types7+t*72)>>19)&0x7ffff;if(!parent || parent==t)break;t=parent;}
    // Closed generic lists can use equivalent runtime type definitions. This
    // is the exact assignability helper used by RE7's own getComponent and
    // generated checked casts, with two validated TDB type rows, no VM call.
    if(actual>=91400 || !self.isGameThread)return NO;
    BOOL (*compatible)(const void *,const void *)=(void *)(_slide7+0x104024d70);
    return compatible((void *)(_types7+actual*72),(void *)(_types7+type*72));
}
- (void *)field:(uint32_t)i owner:(uint32_t)o type:(uint32_t)t object:(void *)object size:(NSUInteger)width {
    if(!self.isGameThread || i>=162739 || o>=91400 || !width || width>32 || ![self isObject:object kindOf:o])return NULL;
    uintptr_t db=_slide7+0x1090e0180,fields=p7(db+0x80),impls=p7(db+0x88);uint64_t bits=0;
    if(!fields || !impls || !MTReadMemory((void *)(fields+i*8),&bits,8) || (bits&0x7ffff)!=o || ((bits>>38)&0x7ffff)!=t)return NULL;
    uint32_t impl=(bits>>19)&0x7ffff;if(impl>=n7(db+0x1c))return NULL;
    uint16_t flags=0;uintptr_t entry=impls+impl*12;if(!MTReadMemory((void *)(entry+2),&flags,2) || (flags>>1)&0x50)return NULL;
    uintptr_t vt=p7(_types7+o*72+64);int32_t base=0;
    if(!vt || !MTReadMemory((void *)(vt-8),&base,4) || base<0x10 || base>0x1000)return NULL;
    NSUInteger offset=(n7(entry+4)&0x3ffffff)+(NSUInteger)base;
    uint32_t bytes=n7(_types7+[self typeOf:object]*72+20);
    if(!bytes || offset>bytes || width>bytes-offset)return NULL;
    uint8_t scratch[32];return MTReadMemory((uint8_t *)object+offset,scratch,width) ? (uint8_t *)object+offset : NULL;
}
- (void *)virtualMethod:(uint32_t)i owner:(uint32_t)o object:(void *)object {
    if(!self.isGameThread || ![self isObject:object kindOf:o] || ![self method:i owner:o])return NULL;
    uint32_t impl=n7(_methods7+i*12+4)&0x7ffff;uintptr_t db=_slide7+0x1090e0180;
    if(impl>=n7(db+0x20))return NULL;int16_t slot=-1;
    if(!MTReadMemory((void *)(p7(db+0x78)+impl*12+2),&slot,2) || slot<0 || slot>1023)return NULL;
    uintptr_t vt=p7(p7((uintptr_t)object)-16),fn=p7(vt+(NSUInteger)slot*8);
    return fn>=_slide7+0x100001740 && fn<_slide7+0x1086b0000 ? (void *)fn : NULL;
}
- (void *)singletonAt:(uintptr_t)a {return self.isGameThread && a>=0x108b70000 && a<0x10b548000 ? (void *)p7(_slide7+a) : NULL;}
- (void)enqueue:(dispatch_block_t)work {if(!work)return;os_unfair_lock_lock(&_lock7);if(_queue7.count<32)[_queue7 addObject:[work copy]];os_unfair_lock_unlock(&_lock7);}
- (void)setContinuousWork:(dispatch_block_t)work {if(self.isGameThread)_continuous7=[work copy];}
- (void)frame7 {
    uint64_t t=0;pthread_threadid_np(NULL,&t);if(_thread7 && t!=_thread7)return;_thread7=t;
    _context7=NULL;void *vm=(void *)p7(_slide7+0x108ceaa08);if(!vm)return;
    // The exact getThreadContext routine creates a missing VM context. During
    // resource startup we must never enter that allocation path. Read the
    // native thread index through the same Mach-O TLV descriptor instead, and
    // accept only the already populated VM context slot.
    uintptr_t descriptor=_slide7+0x10b2908b0;
    void *(*tls)(void *)=(void *)p7(descriptor);if(!tls)return;
    void *indexAddress=tls((void *)descriptor);int32_t index=-1;
    if(!indexAddress || !MTReadMemory(indexAddress,&index,4) || index<0 || index>=1024)return;
    uintptr_t contexts=p7((uintptr_t)vm+0x408);if(!contexts)return;
    _context7=(void *)p7(contexts+(NSUInteger)index*8);
    uintptr_t state=p7((uintptr_t)_context7+0x50);if(!_context7 || !state || p7(state+0x18))return;
    if(++_frames7==1){char name[64]={0};pthread_getname_np(pthread_self(),name,sizeof(name));os_log(_log7,"RE7 GameThread delivery confirmed thread=%{public}llu name=%{public}s",t,name);}
    if(_scan7)for(NSUInteger n=0;n<8 && _cursor7<sizeof(RE7ProbeMethods)/sizeof(RE7ProbeMethods[0]);n++,_cursor7++){
        uint32_t i=RE7ProbeMethods[_cursor7][0],o=RE7ProbeMethods[_cursor7][1];void *fn=[self method:i owner:o];os_log(_log7,"RE7Binding index=%{public}u owner=%{public}u encoded=%{public}d",i,o,fn ? (int32_t)((uintptr_t)fn-_slide7-0x1040352ec) : 0);
    }
    NSArray *work;os_unfair_lock_lock(&_lock7);work=[_queue7 copy];[_queue7 removeAllObjects];os_unfair_lock_unlock(&_lock7);for(dispatch_block_t b in work)b();if(_continuous7)_continuous7();
}
@end
