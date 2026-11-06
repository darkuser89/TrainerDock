// SPDX-License-Identifier: GPL-3.0-only
// Development-only, read-only engine probe. Never linked into a released module.
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dlfcn.h>
#include <atomic>
#include <vector>
#include <cstring>
#include <cxxabi.h>
static uintptr_t core=0,mainImage=0;
static void *owner=nullptr; static void **original=nullptr; static std::vector<void*> table;
static void (*originalUpdate)(void*,float)=nullptr;
static std::atomic<unsigned long> frames{0};
static bool rd(uintptr_t p,void *v,size_t n){mach_vm_size_t done=0;return p>0x10000 && mach_vm_read_overwrite(mach_task_self(),p,n,(mach_vm_address_t)v,&done)==KERN_SUCCESS && done==n;}
template<class T> static T read(uintptr_t p){T v{};rd(p,&v,sizeof(v));return v;}
static NSString *type(uintptr_t p){uintptr_t vt=read<uintptr_t>(p),ti=read<uintptr_t>(vt-8),nm=read<uintptr_t>(ti+8);char s[256]={};if(!rd(nm,s,255))return @"?";int status=0;char *out=abi::__cxa_demangle(s,nullptr,nullptr,&status);NSString *result=[NSString stringWithUTF8String:out?:s]?:@"?";free(out);return result;}
static NSDictionary *ptr(uintptr_t p){Dl_info d={};dladdr((void*)p,&d);return @{@"address":[NSString stringWithFormat:@"0x%llx",(unsigned long long)p],@"image":d.dli_fname?[@(d.dli_fname) lastPathComponent]:@"heap",@"offset":[NSString stringWithFormat:@"0x%llx",(unsigned long long)(p-(uintptr_t)d.dli_fbase)]};}
static void capture(void *server){@autoreleasepool{
 uintptr_t s=(uintptr_t)server;
 uintptr_t session=((uintptr_t(*)(void*))(core+0x19c478))(server);
 uintptr_t avatar=session?((uintptr_t(*)(void*))(core+0x2c0c10))((void*)session):0;
 NSMutableDictionary *d=[@{@"pid":@(getpid()),@"frames":@(frames.load()),@"mainThread":@(NSThread.isMainThread),@"server":ptr(s),@"serverType":type(s),@"session":ptr(session),@"sessionType":session?type(session):@"none",@"avatar":ptr(avatar),@"avatarType":avatar?type(avatar):@"none"} mutableCopy];
 NSMutableArray *a=[NSMutableArray new];
 if(avatar){
  uint32_t n=read<uint32_t>(avatar+0x68);uintptr_t list=read<uintptr_t>(avatar+0x60);
  if(n<=128)for(uint32_t i=0;i<n;i++){
   uintptr_t c=read<uintptr_t>(list+8*i);NSString *name=type(c);uintptr_t vt=read<uintptr_t>(c);
   NSMutableDictionary *entry=[@{@"type":name,@"component":ptr(c),@"vtable":ptr(vt)} mutableCopy];
   if([name containsString:@"Health"]||[name containsString:@"AbilityResource"]||[name containsString:@"PlayerAssist"]||[name containsString:@"Inventory"]||[name containsString:@"Weapon"]||[name containsString:@"Movement"]){unsigned char bytes[512];if(rd(c,bytes,sizeof(bytes)))entry[@"bytes"]=[[NSData dataWithBytes:bytes length:sizeof(bytes)] base64EncodedStringWithOptions:0];}
   [a addObject:entry];
  }
 }
 d[@"components"]=a;NSData *json=[NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted error:NULL];[json writeToFile:@"/private/tmp/mht-control/Probe.json" options:NSDataWritingAtomic error:NULL];
}}
static void *candidate=nullptr; static NSString *loadedName; static void (*candidateFrame)(uintptr_t,uintptr_t,void*,unsigned long)=nullptr;
static void update(void *server,float dt){originalUpdate(server,dt);auto f=++frames;
 if(f%120==1)capture(server);
 if(f%30==1){@autoreleasepool{
  NSString *name=[[NSString stringWithContentsOfFile:@"/private/tmp/mht-control/Candidate.txt" encoding:NSUTF8StringEncoding error:NULL] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if(!candidate && name.length<80 && [name hasPrefix:@"Candidate-"] && [name hasSuffix:@".dylib"] && [name.lastPathComponent isEqual:name]){
   NSString *path=[@"/private/tmp/mht-control" stringByAppendingPathComponent:name];
   candidate=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL);
   if(candidate){candidateFrame=(void(*)(uintptr_t,uintptr_t,void*,unsigned long))dlsym(candidate,"MHTControlProbeFrame");loadedName=[name copy];}
   NSString *error=candidate?@"loaded":@(dlerror()?:"unknown");
   [@{ @"name":name,@"result":error,@"entry":@(candidateFrame!=nullptr)}.description writeToFile:@"/private/tmp/mht-control/CandidateResult.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  }
 }}
 if(candidateFrame)candidateFrame(core,mainImage,server,f);
 if(candidate && [[NSFileManager defaultManager]fileExistsAtPath:@"/private/tmp/mht-control/Unload"]){
  void(*stop)()=(void(*)())dlsym(candidate,"MHTControlProbeStop");if(stop)stop();candidateFrame=nullptr;dlclose(candidate);candidate=nullptr;
  [[NSFileManager defaultManager]removeItemAtPath:@"/private/tmp/mht-control/Candidate.txt" error:NULL];[[NSFileManager defaultManager]removeItemAtPath:@"/private/tmp/mht-control/Unload" error:NULL];loadedName=nil;
 }
}
static bool executable(uintptr_t p){mach_vm_address_t addr=p;mach_vm_size_t size=0;vm_region_basic_info_data_64_t info={};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;mach_port_t o=0;kern_return_t k=mach_vm_region(mach_task_self(),&addr,&size,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&o);if(o)mach_port_deallocate(mach_task_self(),o);return k==KERN_SUCCESS&&p>=addr&&p<addr+size&&(info.protection&VM_PROT_EXECUTE);}
static void install(){if(owner||!core)return;uintptr_t runner=read<uintptr_t>(core+0xb85dd8);uintptr_t server=read<uintptr_t>(runner+0x10),vt=read<uintptr_t>(server);if(!vt)return;
 NSString *name=type(server);if(![name containsString:@"GameServer"])return;
 size_t count=0;while(count<256&&executable(read<uintptr_t>(vt+8*count)))count++;
 if(count<8||count==256)return;
 table.resize(count+2);if(!rd(vt-16,table.data(),table.size()*8))return;
 original=(void**)vt;originalUpdate=(void(*)(void*,float))table[9];table[9]=(void*)&update;
 void **expected=original;owner=(void*)server;
 if(!__atomic_compare_exchange_n((void***)server,&expected,table.data()+2,false,__ATOMIC_RELEASE,__ATOMIC_RELAXED)){owner=nullptr;return;}
 NSDictionary *d=@{@"installed":@YES,@"serverType":name,@"slots":@(count),@"callback":ptr((uintptr_t)originalUpdate)};[[NSJSONSerialization dataWithJSONObject:d options:0 error:NULL]writeToFile:@"/private/tmp/mht-control/Hook.json" atomically:YES];
}
static NSString *uuid(const mach_header_64 *h){if(!h||h->magic!=MH_MAGIC_64)return @"";const load_command *cmd=(const load_command*)(h+1);for(uint32_t i=0;i<h->ncmds;i++){if(cmd->cmd==LC_UUID){uuid_t u;memcpy(u,((const uuid_command*)cmd)->uuid,16);return [[NSUUID alloc]initWithUUIDBytes:u].UUIDString;}cmd=(const load_command*)((const char*)cmd+cmd->cmdsize);}return @"";}
__attribute__((constructor))static void start(){@autoreleasepool{if(![NSProcessInfo.processInfo.environment[@"MHT_CONTROL_PROBE"]isEqual:@"1"])return;
 for(uint32_t i=0;i<_dyld_image_count();i++){const mach_header_64 *h=(const mach_header_64*)_dyld_get_image_header(i);NSString *u=uuid(h);if([u isEqual:@"CF65DC88-F5CE-38A4-8A2A-21FD5F43F14B"])mainImage=(uintptr_t)h;if([u isEqual:@"741C61A5-962D-33AA-9AC7-06713AFFC389"])core=(uintptr_t)h;}
 if(!mainImage||!core)return;
 dispatch_async(dispatch_get_main_queue(),^{[NSTimer scheduledTimerWithTimeInterval:.5 repeats:YES block:^(NSTimer *t){(void)t;install();}];});
}}
