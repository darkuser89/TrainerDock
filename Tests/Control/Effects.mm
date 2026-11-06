// SPDX-License-Identifier: GPL-3.0-only
// Actual native effect candidate, exercised only by the session-bound Control probe.
#import <Foundation/Foundation.h>
#import "ProbeRequest.h"
#import <AppKit/AppKit.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <dlfcn.h>
#include <cxxabi.h>
#include <map>
#include <vector>
#include <cmath>
static bool rd(uintptr_t p,void *v,size_t n){mach_vm_size_t done=0;return p>0x10000&&mach_vm_read_overwrite(mach_task_self(),p,n,(mach_vm_address_t)v,&done)==0&&done==n;}
template<class T>static T r(uintptr_t p){T v{};rd(p,&v,sizeof(v));return v;}
static bool wr(uintptr_t p,const void *v,size_t n){mach_vm_address_t a=p;mach_vm_size_t size=0;vm_region_basic_info_data_64_t info={};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;mach_port_t o=0;auto k=mach_vm_region(mach_task_self(),&a,&size,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&o);if(o)mach_port_deallocate(mach_task_self(),o);if(k||p<a||p+n>a+size||!(info.protection&VM_PROT_WRITE))return false;memcpy((void*)p,v,n);return true;}
static NSString *type(uintptr_t p){uintptr_t vt=r<uintptr_t>(p),ti=r<uintptr_t>(vt-8),nm=r<uintptr_t>(ti+8);char s[256]={};if(!rd(nm,s,255))return @"?";int status=0;char *out=abi::__cxa_demangle(s,nullptr,nullptr,&status);NSString *result=[NSString stringWithUTF8String:out?:s]?:@"?";free(out);return result;}
static uintptr_t image=0,avatar=0,health=0,resource=0,inventory=0,player=0,assist=0,movement=0;
struct Patch {uintptr_t address;std::vector<uint8_t> before,last;};static std::map<NSString*,Patch> patches;
static float minAmmo=INFINITY; static NSMutableDictionary *wanted,*out; static NSDictionary *healthCheck;static unsigned long serial=0;static bool healthOwned=false;
static void restore(NSString *key){auto it=patches.find(key);if(it==patches.end())return;auto &p=it->second;std::vector<uint8_t>b(p.last.size());if(rd(p.address,b.data(),b.size())&&b==p.last)wr(p.address,p.before.data(),p.before.size());patches.erase(it);}
template<class T>static bool patch(NSString *key,uintptr_t address,T value){auto it=patches.find(key);if(it==patches.end()){Patch p{address,std::vector<uint8_t>(sizeof(T)),std::vector<uint8_t>(sizeof(T))};if(!rd(address,p.before.data(),sizeof(T)))return false;patches[key]=p;}auto &p=patches[key];if(p.address!=address||!wr(address,&value,sizeof(T)))return false;memcpy(p.last.data(),&value,sizeof(T));T actual{};return rd(address,&actual,sizeof(T))&&memcmp(&actual,&value,sizeof(T))==0;}
static void release(){if(healthOwned&&health){((void(*)(void*,bool,uint32_t))(image+0x4c0ef8))((void*)health,false,0x40000000);healthOwned=false;}while(!patches.empty())restore(patches.begin()->first);}
extern "C" void MHTControlProbeStop(){release();wanted=nil;out=nil;}
extern "C" void MHTControlProbeFrame(uintptr_t core,uintptr_t main,void *server,unsigned long frame){@autoreleasepool{
 image=main;uintptr_t session=((uintptr_t(*)(void*))(core+0x19c478))(server);uintptr_t a=session?((uintptr_t(*)(void*))(core+0x2c0c10))((void*)session):0;
 if(a!=avatar){patches.clear();healthOwned=false;avatar=a;health=resource=inventory=player=assist=movement=0;wanted=[NSMutableDictionary new];}
 if(!avatar)return;
 uintptr_t list=r<uintptr_t>(avatar+0x60);uint32_t count=r<uint32_t>(avatar+0x68);if(count>128)return;
 for(uint32_t i=0;i<count;i++){uintptr_t c=r<uintptr_t>(list+i*8);if(r<uintptr_t>(c+0x20)!=avatar)continue;NSString *n=type(c);if([n isEqual:@"GameHealthComponentState"])health=c;if([n isEqual:@"AbilityResourceComponentState"])resource=c;if([n isEqual:@"GameInventoryComponentState"])inventory=c;if([n isEqual:@"PlayerPropertiesComponentState"])player=c;if([n isEqual:@"PlayerAssistModeComponentState"])assist=c;if([n isEqual:@"MovementSystemComponentState"])movement=c;}
 if(frame%30==7){NSData *d=[NSData dataWithContentsOfFile:@"/private/tmp/mht-control/EffectRequest.json"];NSDictionary *q=MTControlReadProbeRequest(d);
  if([q[@"serial"]unsignedLongValue]>serial){serial=[q[@"serial"]unsignedLongValue];wanted=[q[@"wanted"]mutableCopy]?:[NSMutableDictionary new];minAmmo=INFINITY;
   if([q[@"healthCheck"]boolValue]&&health){uintptr_t h=r<uintptr_t>(health+0x50);float before=r<float>(h+0x94);((void(*)(void*,float,bool))(image+0x605be8))((void*)h,.75f,false);float after=r<float>(h+0x94);((void(*)(void*,float,bool))(image+0x605be8))((void*)h,before,false);healthCheck=@{@"before":@(before),@"after":@(after),@"restored":@(r<float>(h+0x94))};}
   if(q[@"money"]&&player){uint64_t n=[q[@"money"]unsignedLongLongValue];if(n<=999999999)patch(@"money",player+0x38,n);}
   if(q[@"skill"]&&player){int n=[q[@"skill"]intValue];if(n>=0&&n<=9999)patch(@"skill",player+0x40,n);}
  }
 }
 BOOL h=[wanted[@"health"]boolValue];if(health){if(h){if(!(r<uint32_t>(health+0x5c)&0x40000000)){((void(*)(void*,bool,uint32_t))(image+0x4c0ef8))((void*)health,true,0x40000000);healthOwned=true;}}else if(healthOwned){((void(*)(void*,bool,uint32_t))(image+0x4c0ef8))((void*)health,false,0x40000000);healthOwned=false;}}
 if([wanted[@"ammo"]boolValue]&&inventory)patch<uint8_t>(@"ammo",inventory+0x2ac,1);else restore(@"ammo");
 if([wanted[@"energy"]boolValue]&&resource)patch<float>(@"energy",resource+0x38,1);else restore(@"energy");
 if([wanted[@"kill"]boolValue]&&assist)patch<uint8_t>(@"kill",assist+0xb0,1);else restore(@"kill");
 if([wanted[@"speed"]boolValue]&&movement)patch<float>(@"speed",movement+0x2b4,12);else restore(@"speed");
 uintptr_t times=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r4Time12sm_instancesE");uintptr_t clock=r<uintptr_t>(times+8);if([wanted[@"slow"]boolValue]&&[type(clock)isEqual:@"r::TimeImpl"])patch<float>(@"slow",clock+0x44,.5);else restore(@"slow");
 minAmmo=fminf(minAmmo,r<float>(inventory+0x2b8));
 if(frame%30==8){out=[@{@"serial":@(serial),@"frame":@(frame),@"pid":@(getpid()),@"onMain":@(NSThread.isMainThread),@"avatar":@(avatar),@"healthMask":@(r<uint32_t>(health+0x5c)),@"healthInvulnerable":@(r<uint8_t>(health+0xdc)),@"healthNormalized":@(r<float>(health+0x38)),@"healthNativeInvulnerable":@(r<uint8_t>(r<uintptr_t>(health+0x50)+0xbc)),@"ammoInfinite":@(r<uint8_t>(inventory+0x2ac)),@"ammo":@(r<float>(inventory+0x2b8)),@"energy":@(r<float>(resource+0x38)),@"oneHit":@(r<uint8_t>(assist+0xb0)),@"speed":@(r<float>(movement+0x2b4)),@"money":@(r<uint64_t>(player+0x38)),@"skill":@(r<int>(player+0x40)),@"clockType":type(clock),@"clockScale":@(r<float>(clock+0x44)),@"patchCount":@(patches.size()),@"minAmmo":@(minAmmo),@"healthCheck":healthCheck?:@{}}mutableCopy];NSMutableArray *active=[NSMutableArray new];for(uintptr_t off:{0x48,0x58}){uintptr_t p=r<uintptr_t>(inventory+off);uint32_t n=r<uint32_t>(inventory+off+8);if(n>256)continue;std::vector<uint8_t>b(n*96);if(rd(p,b.data(),b.size()))[active addObject:@{@"offset":@(off),@"data":[[NSData dataWithBytes:b.data() length:b.size()]base64EncodedStringWithOptions:0]}];}out[@"activeItems"]=active;
 uintptr_t items=r<uintptr_t>(inventory+0x38);uint32_t n=r<uint32_t>(inventory+0x40);if(n<256){std::vector<uint8_t>b(n*16);if(rd(items,b.data(),b.size())){out[@"items"]=[[NSData dataWithBytes:b.data() length:b.size()]base64EncodedStringWithOptions:0];
 uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE");void *map=(void*)r<uintptr_t>(global);auto resolve=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");NSMutableArray *definitions=[NSMutableArray new];
 if(map&&resolve)for(uint32_t i=0;i<n;i++){uint64_t gid;memcpy(&gid,b.data()+i*16,8);uintptr_t p=(uintptr_t)resolve(map,&gid);unsigned char raw[512]={};NSMutableDictionary *d=[@{@"index":@(i),@"gid":@(gid),@"pointer":@(p),@"type":type(p)}mutableCopy];if(rd(p,raw,sizeof(raw)))d[@"data"]=[[NSData dataWithBytes:raw length:sizeof(raw)]base64EncodedStringWithOptions:0];NSMutableArray *components=[NSMutableArray new];uintptr_t cp=r<uintptr_t>(p+0x60);uint32_t cn=r<uint32_t>(p+0x68);if(cn<=128)for(uint32_t j=0;j<cn;j++){uintptr_t c=r<uintptr_t>(cp+8*j);unsigned char cb[256]={};NSMutableDictionary *cc=[@{@"type":type(c),@"address":@(c)}mutableCopy];if(rd(c,cb,sizeof(cb)))cc[@"data"]=[[NSData dataWithBytes:cb length:sizeof(cb)]base64EncodedStringWithOptions:0];[components addObject:cc];}d[@"components"]=components;[definitions addObject:d];}out[@"itemDefinitions"]=definitions;
 }}
 [[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:@"/private/tmp/mht-control/Effect.json" options:NSDataWritingAtomic error:NULL];}
}}
