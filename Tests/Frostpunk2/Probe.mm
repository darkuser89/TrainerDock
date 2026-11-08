// SPDX-License-Identifier: GPL-3.0-only
// Private session-scoped native diagnostics; never a product source.
#import <AppKit/AppKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <objc/message.h>
#include <map>
#include <stdexcept>
#include <cstring>
#include <vector>
#include <unistd.h>
#include "ThreadInputBindings.h"
#include "ReflectionBindings.h"
#include "Unreal.hpp"
#include "GameBindings.h"
#ifdef FP_COMPLETE_CANDIDATE
#include "Backend.hpp"
#include "Manager.hpp"
#include "CommunitySelection.hpp"
#include "Population.hpp"
#endif
namespace {
intptr_t slide;NSString *token;NSMutableSet<NSString *> *consumed;NSTimer *timer;bool busy=false;uint64_t callbacks=0;
bool copy(uintptr_t p,void *out,size_t n){mach_vm_size_t got=0;return p>4096 && n<=2*1024*1024 && mach_vm_read_overwrite(mach_task_self(),p,n,(mach_vm_address_t)out,&got)==KERN_SUCCESS && got==n;}
template<class T>T read(uintptr_t p){T v={};if(!copy(p,&v,sizeof(v)))throw std::runtime_error("Unreadable original memory");return v;}
NSString *fname(uintptr_t at){uint32_t id=read<uint32_t>(at),number=read<uint32_t>(at+4);uintptr_t pool=0x10c74cf80+slide,block=read<uintptr_t>(pool+0xd0+8*(id>>16)),entry=block+2*(id&65535);uint16_t header=read<uint16_t>(entry);size_t length=header>>6;if(length>1023)return @"<invalid-name>";NSString *s=nil;if(header&1){unichar text[1024]={};if(!copy(entry+2,text,length*2))return @"<unreadable>";s=[[NSString alloc]initWithCharacters:text length:length];}else{char text[1024]={};if(!copy(entry+2,text,length))return @"<unreadable>";s=[[NSString alloc]initWithBytes:text length:length encoding:NSUTF8StringEncoding];}return number?[s stringByAppendingFormat:@"_%u",number-1]:s ?: @"<invalid-name>";}
NSString *name(uintptr_t object){return fname(object+0x18);}
uintptr_t object(int index){uintptr_t a=0x10c9f08f8+slide;int count=read<int>(a+0x24);if(index<0 || index>=count || count>2000000)throw std::runtime_error("Original index outside array");uintptr_t chunks=read<uintptr_t>(a+0x10),chunk=read<uintptr_t>(chunks+(index>>16)*8);uintptr_t p=read<uintptr_t>(chunk+(index&65535)*0x14);if(!p || read<int>(p+0xc)!=index)throw std::runtime_error("Original object index differs");return p;}
NSDictionary *describe(uintptr_t p){uintptr_t c=read<uintptr_t>(p+0x10),o=read<uintptr_t>(p+0x20);return @{@"index":@(read<int>(p+0xc)),@"name":name(p),@"class":name(c),@"outer":o?name(o):@"",@"classIndex":@(read<int>(c+0xc)),@"address":[NSString stringWithFormat:@"0x%llx",(unsigned long long)p]};}
NSArray *properties(uintptr_t structure){NSMutableArray *out=[NSMutableArray new];uintptr_t f=read<uintptr_t>(structure+0x50);for(int i=0;f && i<1024;i++,f=read<uintptr_t>(f+0x18)){uintptr_t c=read<uintptr_t>(f+8);[out addObject:@{@"name":fname(f+0x20),@"type":fname(c),@"offset":@(read<int>(f+0x44)),@"size":@(read<int>(f+0x30)),@"count":@(read<int>(f+0x2c)),@"flags":@(read<uint64_t>(f+0x38)),@"address":[NSString stringWithFormat:@"0x%llx",(unsigned long long)f]}];}return out;}
id scalar(uintptr_t p,NSString *t,int size){if([t isEqual:@"FloatProperty"] && size==4)return @(read<float>(p));if([t isEqual:@"DoubleProperty"] && size==8)return @(read<double>(p));if([t isEqual:@"IntProperty"] && size==4)return @(read<int32_t>(p));if([t isEqual:@"Int64Property"] && size==8)return @(read<int64_t>(p));if([t isEqual:@"ByteProperty"] && size==1)return @(read<uint8_t>(p));if([t isEqual:@"ObjectProperty"] && size==8){uintptr_t v=read<uintptr_t>(p);return v?describe(v):NSNull.null;}if([t isEqual:@"NameProperty"] && size==8)return fname(p);return @"<non-scalar>";}
NSDictionary *perform(NSDictionary *a){SEL sel=NSSelectorFromString(@"isGameThread");if(![NSThread respondsToSelector:sel] || !((BOOL(*)(id,SEL))objc_msgSend)(NSThread.class,sel))throw std::runtime_error("Original GameThread not observed");callbacks++;NSString *op=a[@"op"] ?: @"status";
 #ifdef FP_COMPLETE_CANDIDATE
 if([op isEqual:@"paused"]){auto c=fp::backend::context();if(!c.ready)throw std::runtime_error("Local city required");auto lib=fp::utility(@"PXTimeUtils"),fn=fp::function(lib,@"IsPaused");uintptr_t relocation=fp::binding("processEvent")-0x100be2e78ULL;if(fp::read<uintptr_t>(fn.address+0xd8)!=0x106092a40ULL+relocation || (fp::read<uint32_t>(fn.address+0xb0)&0x2400)!=0x2400)throw std::runtime_error("Original pause getter differs");auto args=[NSMutableDictionary new];for(const auto &p:fp::properties(fn))if(!(p.flags&0x400)){if(![p.type isEqual:@"ObjectProperty"])throw std::runtime_error("Original pause input differs");args[p.name]=@{@"object":@(fp::read<int32_t>(c.controller.address+0xc))};}if(args.count!=1)throw std::runtime_error("Original pause argument count differs");id value=fp::invoke(lib,@"IsPaused",args);if(![value isKindOfClass:NSNumber.class])throw std::runtime_error("Original pause return differs");return @{@"paused":value};}
 if([op isEqual:@"context"] || [op isEqual:@"values"]){fp::backend::capture();return fp::backend::diagnostics();}
 if([op isEqual:@"manager"]){auto c=fp::backend::context();if(!c.ready)throw std::runtime_error("Local city required");auto m=fp::ensureCheatManager(c.controller);return @{@"ready":@(m.ready),@"reason":m.reason ?: @"",@"index":m.ready?@(fp::read<int32_t>(m.manager.address+0xc)):@(-1)};}
 if([op isEqual:@"population"]){auto c=fp::backend::context();if(!c.ready)throw std::runtime_error("Local city required");auto type=fp::object([a[@"type"] intValue]);fp::Object member{};for(auto o:fp::listLocalCommunities(c))if(fp::communityType(o)==type)member=o;if(!member)throw std::runtime_error("Community type is not an active local member");int32_t actual=0;bool ok=FPChangeCommunityPopulation(c.controller,c.city,type,[a[@"delta"] intValue],&actual);return @{@"confirmed":@(ok),@"actualDelta":@(actual),@"size":fp::invoke(member,@"GetCommunitySize",@{})};}
 if([op isEqual:@"metadata"]){auto o=fp::object([a[@"index"] intValue]);auto p=fp::property(o,a[@"field"]);NSMutableDictionary *d=[@{@"type":p.type,@"offset":@(p.offset),@"size":@(p.size),@"owner":@(p.ownerClass.address),@"address":@(p.address)} mutableCopy];if([p.type isEqual:@"ArrayProperty"]){uintptr_t inner=fp::read<uintptr_t>(p.address+0x78);d[@"inner"]=@(inner);d[@"innerOwner"]=@(fp::read<uintptr_t>(inner+0x10));d[@"innerType"]=fp::fname(fp::read<uintptr_t>(inner+8));}return d;}
#endif
 if([op isEqual:@"status"])return @{@"gameThread":@YES,@"callbacks":@(callbacks),@"objectCount":@(read<int>(0x10c9f091c+slide))};
 if([op isEqual:@"objects"]){NSString *pattern=a[@"pattern"] ?: @"PXCheat";NSMutableArray *out=[NSMutableArray new];int count=read<int>(0x10c9f091c+slide);if(count<0 || count>2000000)throw std::runtime_error("Invalid original count");std::map<uintptr_t,NSString *> classes;for(int i=0;i<count;i++){@try{try{uintptr_t p=object(i),c=read<uintptr_t>(p+0x10);NSString *cn=classes.count(c)?classes[c]:(classes[c]=name(c));NSString *n=name(p);if([cn rangeOfString:pattern options:NSCaseInsensitiveSearch].location!=NSNotFound || [n rangeOfString:pattern options:NSCaseInsensitiveSearch].location!=NSNotFound){[out addObject:describe(p)];if(out.count>=2000)break;}}catch(...){}}@catch(NSException *){}}return @{@"objects":out,@"scanned":@(count)};}
 uintptr_t p=object([a[@"index"] intValue]);
 if([op isEqual:@"invoke"]){NSString *fn=a[@"function"];bool allowed=false;for(const auto &f:FPGameFunctions)if([fn isEqual:@(f.name)]){allowed=true;break;}if(!allowed || !fp::isBound())throw std::runtime_error("Unapproved or unbound native test function");return @{@"result":fp::invoke(fp::Object{p},fn,a[@"arguments"] ?: @{})};}

 if([op isEqual:@"class"]){NSMutableArray *classes=[NSMutableArray new];uintptr_t c=read<uintptr_t>(p+0x10);if([name(c) isEqual:@"Class"])c=p;for(int depth=0;c && depth<20;depth++,c=read<uintptr_t>(c+0x40)){NSMutableArray *functions=[NSMutableArray new];for(uintptr_t f=read<uintptr_t>(c+0x48);f && functions.count<1024;f=read<uintptr_t>(f+0x28)){NSMutableDictionary *d=[describe(f) mutableCopy];d[@"flags"]=@(read<uint32_t>(f+0xb0));d[@"parameterSize"]=@(read<uint16_t>(f+0xb6));d[@"properties"]=properties(f);[functions addObject:d];}[classes addObject:@{@"class":describe(c),@"properties":properties(c),@"functions":functions}];}return @{@"classes":classes};}
 if([op isEqual:@"fields"]){NSMutableArray *out=[NSMutableArray new];for(uintptr_t c=read<uintptr_t>(p+0x10),depth=0;c && depth<20;depth++,c=read<uintptr_t>(c+0x40)){for(NSDictionary *f in properties(c)){NSMutableDictionary *d=[f mutableCopy];int o=[f[@"offset"] intValue],n=[f[@"size"] intValue];if(o>=0 && o<65536 && n>=0 && n<=1024){@try{try{d[@"value"]=scalar(p+o,f[@"type"],n);}catch(...){d[@"value"]=@"<unreadable>";}}@catch(NSException *){}}[out addObject:d];}}return @{@"object":describe(p),@"fields":out};}
 if([op isEqual:@"memory"]){size_t offset=[a[@"offset"] unsignedIntegerValue],n=[a[@"length"] unsignedIntegerValue];if(offset>4096 || !n || n>1024)throw std::runtime_error("Bounded object memory only");uint8_t bytes[1024];if(!copy(p+offset,bytes,n))throw std::runtime_error("Object data unreadable");NSMutableString *hex=[NSMutableString new];for(size_t i=0;i<n;i++)[hex appendFormat:@"%02x",bytes[i]];return @{@"object":describe(p),@"offset":@(offset),@"hex":hex};}
 if([op isEqual:@"object"])return describe(p);
 throw std::runtime_error("Unknown read-only test action");
}
}
static void stage(NSString *state){[[@{ @"pid":@(getpid()),@"stage":state,@"callbacks":@(callbacks)} description] writeToFile:@"/private/tmp/trainerdock-frostpunk2/Stage.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];}
__attribute__((constructor))static void start(){
 @autoreleasepool{stage(@"constructor");}
 dispatch_async(dispatch_get_main_queue(),^{
 stage(@"main queue");if(strcmp(getenv("MHT_FROSTPUNK_DEVELOPMENT") ?: "","1")){stage(@"development environment missing");return;}
 const mach_header_64 *main=nullptr;uint32_t image=0;
 for(uint32_t i=0;i<_dyld_image_count();i++){const auto *h=(const mach_header_64 *)_dyld_get_image_header(i);if(h && h->magic==MH_MAGIC_64 && h->filetype==MH_EXECUTE){main=h;image=i;break;}}
 if(!main || main->cputype!=CPU_TYPE_ARM64 || main->ncmds>4096 || main->sizeofcmds>1024*1024){stage(@"original main image unavailable");return;}
 bool exact=false;const uint8_t *at=(const uint8_t *)(main+1),*end=at+main->sizeofcmds;
 for(uint32_t i=0;i<main->ncmds;i++){if((size_t)(end-at)<sizeof(load_command)){stage(@"bad load command");return;}const load_command *c=(const load_command *)at;if(c->cmdsize<sizeof(*c) || c->cmdsize>(size_t)(end-at))return;if(c->cmd==LC_UUID && c->cmdsize==sizeof(uuid_command))exact=[[[NSUUID alloc]initWithUUIDBytes:((const uuid_command *)c)->uuid].UUIDString isEqual:@"10F7F2EA-0D13-337E-BF07-ABA47A4549CF"];at+=c->cmdsize;}
 if(!exact){stage(@"original UUID differs");return;}slide=_dyld_get_image_vmaddr_slide(image);
 for(const auto &b:fpThreadBindings){uint8_t bytes[16];if(!copy(b.address+slide,bytes,16) || memcmp(bytes,b.bytes,16)){stage([@"thread binding differs: " stringByAppendingString:@(b.name)]);return;}}
 for(const auto &b:fp2ReflectionBindings){uint8_t bytes[16];if(!copy(b.address+slide,bytes,16) || memcmp(bytes,b.bytes,16)){stage([@"reflection binding differs: " stringByAppendingString:@(b.name)]);return;}}
 token=getenv("MHT_SESSION")?@(getenv("MHT_SESSION")):nil;if(!token.length){stage(@"session missing");return;}consumed=[NSMutableSet new];stage(fp::bind()?@"validated including typed Unreal API; timer scheduled":@"validated raw ABI; typed API unavailable");
 __block NSTimeInterval submitted=0;
 timer=[NSTimer timerWithTimeInterval:.2 repeats:YES block:^(NSTimer *){
 if(busy && NSDate.date.timeIntervalSince1970-submitted<5)return;
 if(busy){busy=false;stage(@"delivery timeout; request remains consumed");}
 if(!read<uintptr_t>(0x10c73d1e0+slide)){stage(@"waiting for actual GameThread");return;}
 NSData *d=[NSData dataWithContentsOfFile:@"/private/tmp/trainerdock-frostpunk2/Request.json"];NSDictionary *r=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil;
 if(![r isKindOfClass:NSDictionary.class] || ![r[@"token"] isEqual:token] || ![r[@"id"] isKindOfClass:NSString.class] || [consumed containsObject:r[@"id"]])return;
 // Retain consumed IDs for this entire private session. At the fixed bound,
 // refuse new requests instead of evicting IDs that could replay mutations.
 if(consumed.count>=4096){stage(@"private session request limit reached");return;}
 [consumed addObject:r[@"id"]];busy=true;submitted=NSDate.date.timeIntervalSince1970;stage(@"queued on original GameThread");NSTimeInterval requestTime=submitted;
 ((void(*)(dispatch_block_t,NSArray *,bool))(0x10087a854+slide))(^ { @autoreleasepool{
 NSMutableDictionary *reply=[@{@"id":r[@"id"]} mutableCopy];@try{try{if(NSDate.date.timeIntervalSince1970-requestTime>4.5)throw std::runtime_error("Expired native test request; no action executed");reply[@"result"]=perform(r[@"action"]);}catch(const std::exception& e){reply[@"error"]=@(e.what());}}@catch(NSException *e){reply[@"error"]=e.reason;}
 [[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil] writeToFile:@"/private/tmp/trainerdock-frostpunk2/Reply.json" atomically:YES];
 dispatch_async(dispatch_get_main_queue(),^{busy=false;stage(@"GameThread reply completed");});}},@[NSDefaultRunLoopMode,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode],false);
 }];[NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
 });}
