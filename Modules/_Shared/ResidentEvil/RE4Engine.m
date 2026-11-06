// SPDX-License-Identifier: GPL-3.0-only
#import "RE4Engine.h"
#import "MemoryAccess.h"
#import "RE4DiagnosticBindings.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach_vm.h>
#import <os/lock.h>
#import <os/log.h>
#import <pthread.h>
#include <stdatomic.h>
static uintptr_t p4(uintptr_t a){uintptr_t v=0;MTReadMemory((void *)a,&v,8);return v;}
static uint32_t n4(uintptr_t a){uint32_t v=0;MTReadMemory((void *)a,&v,4);return v;}
static MTRE4Engine *pump4;
static void (*original4)(void *);
@interface MTRE4Engine () {
    BOOL _known4,_installed4,_scan4;
    uintptr_t _slide4,_methods4,_types4;
    uint64_t _thread4,_frames4;
    void *_context4;
    os_unfair_lock _lock4;
    NSMutableArray<dispatch_block_t> *_queue4;
    dispatch_block_t _continuous4;
    NSUInteger _cursor4;
    os_log_t _log4;
}
- (void)frame4;
@end
static void late4(void *entry){original4(entry);@autoreleasepool{[pump4 frame4];}}
@implementation MTRE4Engine
+ (instancetype)shared {static MTRE4Engine *e;static dispatch_once_t once;dispatch_once(&once,^{e=[self new];});return e;}
- (instancetype)init {
    if(!(self=[super init]))return nil;
    _lock4=OS_UNFAIR_LOCK_INIT;_queue4=[NSMutableArray new];_log4=os_log_create("local.mactrainer.re2","re4-engine");
    _scan4=[NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"];
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE4US"])return self;
    const struct mach_header_64 *h=NULL;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *candidate=(const void *)_dyld_get_image_header(i);
        if(candidate && candidate->magic==MH_MAGIC_64 && candidate->filetype==MH_EXECUTE){h=candidate;_slide4=_dyld_get_image_vmaddr_slide(i);break;}
    }
    if(!h || h->magic!=MH_MAGIC_64 || h->cputype!=CPU_TYPE_ARM64 || h->filetype!=MH_EXECUTE || h->sizeofcmds>1024*1024 || h->ncmds>4096)return self;
    const uint8_t *cmd=(const void *)(h+1);uint32_t o=0;NSString *uuid=nil;
    for(uint32_t i=0;i<h->ncmds;i++){
        if(o>h->sizeofcmds || h->sizeofcmds-o<8)return self;struct load_command c;memcpy(&c,cmd+o,8);
        if(c.cmdsize<8 || c.cmdsize>h->sizeofcmds-o)return self;
        if(c.cmd==LC_UUID){if(uuid || c.cmdsize!=sizeof(struct uuid_command))return self;struct uuid_command u;memcpy(&u,cmd+o,sizeof(u));uuid=[[NSUUID alloc]initWithUUIDBytes:u.uuid].UUIDString;}
        o+=c.cmdsize;
    }
    if(o!=h->sizeofcmds || ![uuid isEqual:@"4C4C44CF-5555-3144-A161-D64EFB82E79F"]){os_log_error(_log4,"RE4 executable identity mismatch uuid=%{public}s",uuid.UTF8String);return self;}
    const uint32_t hp[]={0xb9401020,0xd65f03c0,0xb9001022,0xd65f03c0,0xb9401420,0xd65f03c0};uint32_t actual[6];
    if(!MTReadMemory((void *)(_slide4+0x104301470),actual,sizeof(actual)) || memcmp(hp,actual,sizeof(hp))){os_log_error(_log4,"RE4 native health fingerprint not confirmed");return self;}
    _known4=YES;os_log(_log4,"RE4 exact executable and native health fingerprint confirmed");return self;
}
- (BOOL)identified{return _known4;}
- (BOOL)installed{return _installed4;}
- (BOOL)isRE3{return NO;}
- (uintptr_t)slide{return _slide4;}
- (NSString *)failure{return _known4 ? @"Wartet auf bestätigten RE4-Spielkontext." : @"RE4-Build nicht bestätigt.";}
- (uint32_t)componentType{return 56355;}
- (uint32_t)componentValidMethod{return 1247;}
- (uint32_t)componentGameObjectMethod{return 1246;}
- (uint32_t)gameObjectType{return 59886;}
- (uint32_t)weakGameObjectType{return 4471;}
- (uint32_t)weakConstructor{return 4900;}
- (uint32_t)weakResolver{return 4902;}
- (NSUInteger)weakPayloadOffset{return 0;}
- (uintptr_t)retainAddress{return _slide4+0x1082c2ea0;}
- (uintptr_t)releaseAddress{return _slide4+0x1082c355c;}
- (BOOL)installGameThreadDelivery {
    if(_installed4)return YES;if(!_known4)return NO;uintptr_t t=_slide4+0x10d3aade8;
    if(n4(t)!=0x424454 || n4(t+4)!=73 || n4(t+8)!=171431 || n4(t+0x10)!=1187687)return NO;
    _methods4=p4(t+0x70);_types4=p4(t+0x60);
    if(_methods4!=t+0xbc5950 || _types4!=t+0x250 || (int32_t)n4(_methods4+23097*12+8)!=-67048628)return NO;
    uintptr_t app=p4(_slide4+0x10cbd1d20),slot=app+0x9af0,expected=_slide4+0x10968d660;char name[32]={0};
    if(!app || !MTReadMemory((void *)p4(app+0x9b00),name,sizeof(name)) || strcmp(name,"LateUpdateBehavior") || p4(slot)!=expected)return NO;
    mach_vm_address_t region=slot;mach_vm_size_t size=0;vm_region_basic_info_data_64_t info={0};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;mach_port_t port=MACH_PORT_NULL;
    kern_return_t status=mach_vm_region(mach_task_self(),&region,&size,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&port);if(port)mach_port_deallocate(mach_task_self(),port);
    if(status || region>slot || slot-region>size || size-(slot-region)<8 || !(info.protection&VM_PROT_WRITE) || (info.protection&VM_PROT_EXECUTE))return NO;
    original4=(void *)expected;pump4=self;
    if(!atomic_compare_exchange_strong_explicit((_Atomic uintptr_t *)slot,&expected,(uintptr_t)late4,memory_order_acq_rel,memory_order_acquire)){pump4=nil;return NO;}
    _installed4=YES;os_log(_log4,"RE4 LateUpdateBehavior delivery installed; writable data callback only");return YES;
}
- (BOOL)isGameThread {uint64_t t=0;pthread_threadid_np(NULL,&t);return _installed4 && _thread4 && t==_thread4;}
- (void *)threadContext{return self.isGameThread ? _context4 : NULL;}
- (void *)method:(uint32_t)i owner:(uint32_t)o {
    if(!_known4 || !_methods4 || i>=1187687)return NULL;uint32_t row[3];if(!MTReadMemory((void *)(_methods4+i*12),row,12) || (row[0]&0x7ffff)!=o || !row[2])return NULL;
    uintptr_t a=_slide4+0x1082f2924+(int32_t)row[2];return a>=_slide4+0x100001740 && a<_slide4+0x10c35c000 ? (void *)a : NULL;
}
- (uint32_t)typeOf:(const void *)object {
    uintptr_t t=p4(p4((uintptr_t)object));return _types4 && t>=_types4 && t<_types4+171431*72 && (t-_types4)%72==0 ? (uint32_t)((t-_types4)/72) : UINT32_MAX;
}
- (BOOL)isObject:(void *)object kindOf:(uint32_t)type {
    uint32_t t=[self typeOf:object];for(NSUInteger i=0;i<64 && t<171431;i++){if(t==type)return YES;uint32_t parent=(p4(_types4+t*72)>>19)&0x7ffff;if(!parent || parent==t)return NO;t=parent;}return NO;
}
- (void *)field:(uint32_t)i owner:(uint32_t)o type:(uint32_t)t object:(void *)object size:(NSUInteger)width {
    if(!self.isGameThread || i>=244996 || o>=171431 || !width || width>32 || ![self isObject:object kindOf:o])return NULL;
    uintptr_t db=_slide4+0x10d3aade8,fields=p4(db+0x80),impls=p4(db+0x88);uint64_t bits=0;
    if(!fields || !impls || !MTReadMemory((void *)(fields+i*8),&bits,8) || (bits&0x7ffff)!=o || ((bits>>38)&0x7ffff)!=t)return NULL;
    uint32_t impl=(bits>>19)&0x7ffff;if(impl>=n4(db+0x1c))return NULL;
    uint16_t flags=0;uintptr_t entry=impls+impl*12;if(!MTReadMemory((void *)(entry+2),&flags,2) || (flags>>1)&0x50)return NULL;
    uintptr_t vt=p4(_types4+o*72+64);int32_t base=0;
    if(!vt || !MTReadMemory((void *)(vt-8),&base,4) || base<0x10 || base>0x1000)return NULL;
    NSUInteger offset=(n4(entry+4)&0x3ffffff)+(NSUInteger)base;
    uint32_t bytes=n4(_types4+[self typeOf:object]*72+20);
    if(!bytes || offset>bytes || width>bytes-offset)return NULL;
    uint8_t scratch[32];return MTReadMemory((uint8_t *)object+offset,scratch,width) ? (uint8_t *)object+offset : NULL;
}
- (void *)virtualMethod:(uint32_t)i owner:(uint32_t)o object:(void *)object {
    if(!self.isGameThread || ![self isObject:object kindOf:o] || ![self method:i owner:o])return NULL;
    uint32_t impl=n4(_methods4+i*12+4)&0x7ffff;uintptr_t db=_slide4+0x10d3aade8;
    if(impl>=n4(db+0x20))return NULL;int16_t slot=-1;
    if(!MTReadMemory((void *)(p4(db+0x78)+impl*12+2),&slot,2) || slot<0 || slot>1023)return NULL;
    uintptr_t vt=p4(p4((uintptr_t)object)-16),fn=p4(vt+(NSUInteger)slot*8);
    return fn>=_slide4+0x100001740 && fn<_slide4+0x10c35c000 ? (void *)fn : NULL;
}
- (void *)singletonAt:(uintptr_t)a {return self.isGameThread && a>=0x10ca58000 && a<0x1112a8000 ? (void *)p4(_slide4+a) : NULL;}
- (void)enqueue:(dispatch_block_t)work {if(!work)return;os_unfair_lock_lock(&_lock4);if(_queue4.count<32)[_queue4 addObject:[work copy]];os_unfair_lock_unlock(&_lock4);}
- (void)setContinuousWork:(dispatch_block_t)work {if(self.isGameThread)_continuous4=[work copy];}
- (void)frame4 {
    uint64_t t=0;pthread_threadid_np(NULL,&t);if(_thread4 && t!=_thread4)return;_thread4=t;
    void *vm=(void *)p4(_slide4+0x10cbd1d18);if(!vm)return;
    void *(*getContext)(void *,int32_t)=(void *)(_slide4+0x1082d1120);_context4=getContext(vm,-1);
    uintptr_t state=p4((uintptr_t)_context4+0x50);if(!_context4 || !state || p4(state+0x18))return;
    if(++_frames4==1){char name[64]={0};pthread_getname_np(pthread_self(),name,sizeof(name));os_log(_log4,"RE4 GameThread delivery confirmed thread=%{public}llu name=%{public}s",t,name);}
    if(_scan4)for(NSUInteger n=0;n<8 && _cursor4<sizeof(RE4ProbeMethods)/sizeof(RE4ProbeMethods[0]);n++,_cursor4++){
        uint32_t i=RE4ProbeMethods[_cursor4][0],o=RE4ProbeMethods[_cursor4][1];void *fn=[self method:i owner:o];os_log(_log4,"RE4Binding index=%{public}u owner=%{public}u encoded=%{public}d",i,o,fn ? (int32_t)((uintptr_t)fn-_slide4-0x1082f2924) : 0);
    }
    NSArray *work;os_unfair_lock_lock(&_lock4);work=[_queue4 copy];[_queue4 removeAllObjects];os_unfair_lock_unlock(&_lock4);for(dispatch_block_t b in work)b();if(_continuous4)_continuous4();
}
@end
