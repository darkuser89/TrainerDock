// SPDX-License-Identifier: GPL-3.0-only
// Explicit local development test only; never part of a released module.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach_vm.h>
#import <os/log.h>
#import "MHTProtocol.h"
#import <dlfcn.h>
#include <pthread.h>
static uintptr_t slide;
static IMP displayIMP,timerIMP;
static NSString *token;
static NSDictionary *pending;
static NSObject *guard;
static NSMutableOrderedSet *seen;
static NSUInteger serial;
static double lastPoll;
static NSData *readBytes(uintptr_t address,NSUInteger size){
    if(address<4096 || size>262144)return nil;NSMutableData *result=[NSMutableData dataWithLength:size];mach_vm_size_t read=0;
    kern_return_t kr=mach_vm_read_overwrite(mach_task_self(),address,size,(mach_vm_address_t)result.mutableBytes,&read);return kr==KERN_SUCCESS && read==size ? result : nil;
}
static uint64_t read64(uintptr_t address){NSData *data=readBytes(address,8);uint64_t v=0;if(data)memcpy(&v,data.bytes,8);return v;}
static uint32_t read32(uintptr_t address){NSData *data=readBytes(address,4);uint32_t v=UINT32_MAX;if(data)memcpy(&v,data.bytes,4);return v;}
static NSDictionary *context(void){
    uintptr_t system=read64(slide+0x1060af3c0),pool=read64(slide+0x1078c2548),array=read64(pool+0x40),actor=0,entity=0,component=0;
    uint32_t count=read32(pool+0x38);if(count>0 && count<=32)for(unsigned i=0;i<count;i++){uintptr_t p=read64(array+i*8);if(p && read32(p+0x88)==0){actor=p;entity=read64(p+0x70);component=read64(entity+0x55b0);break;}}
    return @{@"system":@(system),@"pool":@(pool),@"count":@(count),@"actor":@(actor),@"entity":@(entity),@"component":@(component),@"vitals":@(read64(entity+0x55c8)),@"locomotion":@(read64(entity+0x55a8))};
}
static void frame(id object,SEL selector){
    IMP original=[NSStringFromClass([object class]) isEqual:@"FramePacingTimer"] ? timerIMP : displayIMP;
    if(original)((void(*)(id,SEL))original)(object,selector);
    double now=NSProcessInfo.processInfo.systemUptime;if(now-lastPoll<0.1)return;lastPoll=now;
    char thread[64]={0};pthread_getname_np(pthread_self(),thread,sizeof(thread));if(strcmp(thread,"AppMainThread"))return;
    NSDictionary *request=nil;@synchronized(guard){request=pending;pending=nil;}
    if(!request || [request[@"serial"] unsignedIntegerValue]<=serial)return;
    serial=[request[@"serial"] unsignedIntegerValue];NSDictionary *state=context();NSMutableDictionary *reply=[state mutableCopy];reply[@"serial"]=@(serial);reply[@"thread"]=@(thread);reply[@"pid"]=@(getpid());reply[@"slide"]=@(slide);
    NSString *action=request[@"action"];
    if([action isEqual:@"read"]){
        NSString *area=request[@"area"];NSUInteger limit=[area isEqual:@"system"] ? 0x24000 : [area isEqual:@"component"] ? 0x6000 : [area isEqual:@"entity"] ? 0x6000 : [area isEqual:@"actor"] ? 0x100 : [area isEqual:@"vitals"] ? 0x1000 : [area isEqual:@"locomotion"] ? 0x8000 : 0;
        NSUInteger offset=[request[@"offset"] unsignedIntegerValue],size=[request[@"size"] unsignedIntegerValue];uintptr_t base=[state[area] unsignedLongLongValue];
        if(limit && base && size<=8192 && offset<=limit && size<=limit-offset){NSData *bytes=readBytes(base+offset,size);if(bytes)reply[@"bytes"]=[bytes base64EncodedStringWithOptions:0];}
    }
    MHTPost(@"local.mht.ds.native.state.v1",@{@"version":@1,@"module":@"death-stranding",@"session":token,@"pid":@(getpid()),@"state":reply});
    if([action isEqual:@"loadCandidate"]){
        dispatch_async(dispatch_get_main_queue(),^{
            NSString *path=NSProcessInfo.processInfo.environment[@"TD_DS_CANDIDATE"];
            if(![path isEqual:@"/private/tmp/trainerdock-death-stranding/Candidate/Trainer.dylib"])return;
            method_setImplementation(class_getInstanceMethod(NSClassFromString(@"FramePacingCAMetalDisplayLink"),NSSelectorFromString(@"waitForNextFrame")),displayIMP);
            method_setImplementation(class_getInstanceMethod(NSClassFromString(@"FramePacingTimer"),NSSelectorFromString(@"waitForNextFrame")),timerIMP);
            void *library=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL);
            os_log(OS_LOG_DEFAULT,"TRAINERDOCK_DS_PROBE candidate loaded=%d",library!=NULL);
        });
    }
}
__attribute__((constructor)) static void begin(void){@autoreleasepool{
    BOOL matched=NO;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *header=(const void *)_dyld_get_image_header(i);if(header->filetype!=MH_EXECUTE)continue;
        slide=_dyld_get_image_vmaddr_slide(i);const struct load_command *command=(const void *)(header+1);
        for(uint32_t j=0;j<header->ncmds;j++){if(command->cmd==LC_UUID){uuid_t expected;uuid_parse("6823C89C-242D-37B0-ABC4-4D45A67E7C4C",expected);matched=!memcmp(((const struct uuid_command *)command)->uuid,expected,16);}command=(const void *)((const char *)command+command->cmdsize);}
    }
    if(!matched)return;
    token=NSProcessInfo.processInfo.environment[@"MHT_SESSION"];if(token.length<16)return;
    guard=[NSObject new];seen=[NSMutableOrderedSet new];
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.mht.ds.native.command.v1" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
        NSDictionary *q=MHTDecodeMessage(event.object);if(!MHTAcceptCommand(q,@"death-stranding",token,getpid(),seen,NSDate.date.timeIntervalSince1970))return;
        @synchronized(guard){pending=q;}
    }];
    os_log(OS_LOG_DEFAULT,"TRAINERDOCK_DS_PROBE ready pid=%d",getpid());
    dispatch_async(dispatch_get_main_queue(),^{
        for(NSString *name in @[@"FramePacingCAMetalDisplayLink",@"FramePacingTimer"]){
            Method method=class_getInstanceMethod(NSClassFromString(name),NSSelectorFromString(@"waitForNextFrame"));if(!method)continue;
            IMP value=method_getImplementation(method);uintptr_t expected=([name isEqual:@"FramePacingTimer"] ? 0x103d94aa8 : 0x103d94658)+slide;
            if((uintptr_t)value!=expected)continue;
            if([name isEqual:@"FramePacingTimer"])timerIMP=value;else displayIMP=value;method_setImplementation(method,(IMP)frame);
        }
    });
}}
