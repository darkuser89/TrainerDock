// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <cxxabi.h>
#include <cstdint>
static bool rd(uintptr_t p,void *v,size_t n){mach_vm_size_t done=0;return p>0x10000&&mach_vm_read_overwrite(mach_task_self(),p,n,(mach_vm_address_t)v,&done)==0&&done==n;}
template<class T>static T r(uintptr_t p){T v{};rd(p,&v,sizeof(v));return v;}
static NSString *type(uintptr_t p){uintptr_t vt=r<uintptr_t>(p),ti=r<uintptr_t>(vt-8),nm=r<uintptr_t>(ti+8);char s[256]={};if(!rd(nm,s,255))return @"?";int status=0;char *out=abi::__cxa_demangle(s,nullptr,nullptr,&status);NSString *result=[NSString stringWithUTF8String:out?:s]?:@"?";free(out);return result;}
static NSDictionary *dump(uintptr_t p,size_t n){NSMutableDictionary *d=[@{@"address":@(p),@"type":type(p),@"vtable":@(r<uintptr_t>(p))}mutableCopy];unsigned char b[2048]={};if(n<=sizeof(b)&&rd(p,b,n))d[@"data"]=[[NSData dataWithBytes:b length:n]base64EncodedStringWithOptions:0];return d;}
extern "C" void MHTControlProbeFrame(uintptr_t core,uintptr_t main,void *server,unsigned long f){(void)main;if(f%120!=7)return;@autoreleasepool{
 uintptr_t session=((uintptr_t(*)(void*))(core+0x19c478))(server);
 uintptr_t avatar=session?((uintptr_t(*)(void*))(core+0x2c0c10))((void*)session):0;
 NSMutableArray *a=[NSMutableArray new];uint32_t count=r<uint32_t>(avatar+0x68);uintptr_t list=r<uintptr_t>(avatar+0x60);
 if(avatar&&count<=128)for(uint32_t i=0;i<count;i++){
  uintptr_t c=r<uintptr_t>(list+i*8);NSString *name=type(c);
  if(![@[@"GameHealthComponentState",@"GameDamageReceiverComponentState",@"AbilityResourceComponentState",@"PlayerPropertiesComponentState",@"PlayerAssistModeComponentState",@"GameInventoryComponentState",@"MovementSystemComponentState",@"coregame::MovementModelComponentState",@"ArmorComponentState"]containsObject:name])continue;
  [a addObject:@{@"state":dump(c,2048),@"instance":dump(r<uintptr_t>(c+0x18),1024),@"definition":dump(r<uintptr_t>(c+0x28),1024)}];
 }
 NSDictionary *d=@{@"pid":@(getpid()),@"frame":@(f),@"mainThread":@(NSThread.isMainThread),@"avatar":@(avatar),@"components":a};
 [[NSJSONSerialization dataWithJSONObject:d options:0 error:NULL]writeToFile:@"/private/tmp/mht-control/Inspect.json" options:NSDataWritingAtomic error:NULL];
}}
