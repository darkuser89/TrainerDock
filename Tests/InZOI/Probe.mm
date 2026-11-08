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
namespace {
intptr_t slide;NSString *token;NSMutableSet<NSString *> *consumed;NSTimer *timer;bool busy=false;uint64_t callbacks=0;
bool copy(uintptr_t p,void *out,size_t n){mach_vm_size_t got=0;return p>4096 && n<=2*1024*1024 && mach_vm_read_overwrite(mach_task_self(),p,n,(mach_vm_address_t)out,&got)==KERN_SUCCESS && got==n;}
template<class T>T read(uintptr_t p){T v={};if(!copy(p,&v,sizeof(v)))throw std::runtime_error("Unreadable original memory");return v;}
NSString *fname(uintptr_t at){uint32_t id=read<uint32_t>(at),number=read<uint32_t>(at+4);uintptr_t pool=0x112fc4700+slide,block=read<uintptr_t>(pool+0xd0+8*(id>>16)),entry=block+2*(id&65535);uint16_t header=read<uint16_t>(entry);size_t length=header>>6;if(length>1023)return @"<invalid-name>";NSString *s=nil;if(header&1){unichar text[1024]={};if(!copy(entry+2,text,length*2))return @"<unreadable>";s=[[NSString alloc]initWithCharacters:text length:length];}else{char text[1024]={};if(!copy(entry+2,text,length))return @"<unreadable>";s=[[NSString alloc]initWithBytes:text length:length encoding:NSUTF8StringEncoding];}return number?[s stringByAppendingFormat:@"_%u",number-1]:s ?: @"<invalid-name>";}
NSString *name(uintptr_t object){return fname(object+0x18);}
uintptr_t object(int index){uintptr_t a=0x112dc21d0+slide;int count=read<int>(a+0x24);if(index<0 || index>=count || count>2000000)throw std::runtime_error("Original index outside array");uintptr_t chunks=read<uintptr_t>(a+0x10),chunk=read<uintptr_t>(chunks+(index>>16)*8);uintptr_t p=read<uintptr_t>(chunk+(index&65535)*0x18);if(!p || read<int>(p+0xc)!=index)throw std::runtime_error("Original object index differs");return p;}
NSDictionary *describe(uintptr_t p){uintptr_t c=read<uintptr_t>(p+0x10),o=read<uintptr_t>(p+0x20);return @{@"index":@(read<int>(p+0xc)),@"name":name(p),@"class":name(c),@"outer":o?name(o):@"",@"classIndex":@(read<int>(c+0xc)),@"address":[NSString stringWithFormat:@"0x%llx",(unsigned long long)p]};}
NSArray *properties(uintptr_t structure){NSMutableArray *out=[NSMutableArray new];uintptr_t f=read<uintptr_t>(structure+0x50);for(int i=0;f && i<1024;i++,f=read<uintptr_t>(f+0x18)){uintptr_t c=read<uintptr_t>(f+8);[out addObject:@{@"name":fname(f+0x20),@"type":fname(c),@"offset":@(read<int>(f+0x44)),@"size":@(read<int>(f+0x30)),@"count":@(read<int>(f+0x2c)),@"flags":@(read<uint64_t>(f+0x38)),@"address":[NSString stringWithFormat:@"0x%llx",(unsigned long long)f]}];}return out;}
id scalar(uintptr_t p,NSString *t,int size){if([t isEqual:@"FloatProperty"] && size==4)return @(read<float>(p));if([t isEqual:@"DoubleProperty"] && size==8)return @(read<double>(p));if([t isEqual:@"IntProperty"] && size==4)return @(read<int32_t>(p));if([t isEqual:@"Int64Property"] && size==8)return @(read<int64_t>(p));if([t isEqual:@"ByteProperty"] && size==1)return @(read<uint8_t>(p));if([t isEqual:@"ObjectProperty"] && size==8){uintptr_t v=read<uintptr_t>(p);return v?describe(v):NSNull.null;}if([t isEqual:@"NameProperty"] && size==8)return fname(p);return @"<non-scalar>";}
NSDictionary *perform(NSDictionary *a){SEL sel=NSSelectorFromString(@"isGameThread");if(![NSThread respondsToSelector:sel] || !((BOOL(*)(id,SEL))objc_msgSend)(NSThread.class,sel))throw std::runtime_error("Original GameThread not observed");callbacks++;NSString *op=a[@"op"] ?: @"status";
 if([op isEqual:@"status"])return @{@"gameThread":@YES,@"callbacks":@(callbacks),@"objectCount":@(read<int>(0x112dc21f4+slide))};
 if([op isEqual:@"objects"]){NSString *pattern=a[@"pattern"] ?: @"B2";NSMutableArray *out=[NSMutableArray new];int count=read<int>(0x112dc21f4+slide);if(count<0 || count>2000000)throw std::runtime_error("Invalid original count");std::map<uintptr_t,NSString *> classes;for(int i=0;i<count;i++){@try{try{uintptr_t p=object(i),c=read<uintptr_t>(p+0x10);NSString *cn=classes.count(c)?classes[c]:(classes[c]=name(c));NSString *n=name(p);if([cn rangeOfString:pattern options:NSCaseInsensitiveSearch].location!=NSNotFound || [n rangeOfString:pattern options:NSCaseInsensitiveSearch].location!=NSNotFound){[out addObject:describe(p)];if(out.count>=2000)break;}}catch(...){}}@catch(NSException *){}}return @{@"objects":out,@"scanned":@(count)};}
 if([op isEqual:@"read"]){uintptr_t p=strtoull([a[@"address"] UTF8String],nullptr,0);size_t n=[a[@"length"] unsignedIntegerValue];if(!n||n>4096)throw std::runtime_error("Read exceeds diagnostic bound");uint8_t b[4096];if(!copy(p,b,n))throw std::runtime_error("Unreadable original range");NSMutableString *h=[NSMutableString new];for(size_t i=0;i<n;i++)[h appendFormat:@"%02x",b[i]];return @{@"hex":h};}
 uintptr_t p=object([a[@"index"] intValue]);
 if([op isEqual:@"class"]){NSMutableArray *classes=[NSMutableArray new];uintptr_t c=read<uintptr_t>(p+0x10);if([name(c) isEqual:@"Class"] || [name(c) isEqual:@"ScriptStruct"])c=p;for(int depth=0;c && depth<20;depth++,c=read<uintptr_t>(c+0x40)){NSMutableArray *functions=[NSMutableArray new];for(uintptr_t f=read<uintptr_t>(c+0x48);f && functions.count<1024;f=read<uintptr_t>(f+0x28)){NSMutableDictionary *d=[describe(f) mutableCopy];d[@"flags"]=@(read<uint32_t>(f+0xb0));d[@"parameterSize"]=@(read<uint16_t>(f+0xb6));d[@"properties"]=properties(f);[functions addObject:d];}[classes addObject:@{@"class":describe(c),@"properties":properties(c),@"functions":functions}];}return @{@"classes":classes};}
 if([op isEqual:@"fields"]){NSMutableArray *out=[NSMutableArray new];for(uintptr_t c=read<uintptr_t>(p+0x10),depth=0;c && depth<20;depth++,c=read<uintptr_t>(c+0x40)){for(NSDictionary *f in properties(c)){NSMutableDictionary *d=[f mutableCopy];int o=[f[@"offset"] intValue],n=[f[@"size"] intValue];if(o>=0 && o<65536 && n>=0 && n<=1024){@try{try{d[@"value"]=scalar(p+o,f[@"type"],n);}catch(...){d[@"value"]=@"<unreadable>";}}@catch(NSException *){}}[out addObject:d];}}return @{@"object":describe(p),@"fields":out};}
 if([op isEqual:@"memory"]){size_t offset=[a[@"offset"] unsignedIntegerValue],n=[a[@"length"] unsignedIntegerValue];if(offset>4096 || !n || n>1024)throw std::runtime_error("Bounded object memory only");uint8_t bytes[1024];if(!copy(p+offset,bytes,n))throw std::runtime_error("Object data unreadable");NSMutableString *hex=[NSMutableString new];for(size_t i=0;i<n;i++)[hex appendFormat:@"%02x",bytes[i]];return @{@"object":describe(p),@"offset":@(offset),@"hex":hex};}
 if([op isEqual:@"object"])return describe(p);
 throw std::runtime_error("Unknown read-only test action");
}
}
static void stage(NSString *state){[@{@"pid":@(getpid()),@"stage":state,@"callbacks":@(callbacks)}.description writeToFile:@"/private/tmp/trainerdock-inzoi/Stage.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];}
__attribute__((constructor))static void start(){dispatch_async(dispatch_get_main_queue(),^{
 const mach_header_64 *h=nullptr;uint32_t image=0;
 for(uint32_t i=0;i<_dyld_image_count();i++){const auto *q=(const mach_header_64 *)_dyld_get_image_header(i);if(q&&q->magic==MH_MAGIC_64&&q->filetype==MH_EXECUTE){h=q;image=i;break;}}
 if(!h||h->cputype!=CPU_TYPE_ARM64||h->sizeofcmds>1024*1024||h->ncmds>4096)return;
 bool exact=false;const uint8_t *p=(const uint8_t *)(h+1),*end=p+h->sizeofcmds;
 for(uint32_t i=0;i<h->ncmds;i++){if(p+sizeof(load_command)>end)return;const auto *c=(const load_command *)p;if(c->cmdsize<sizeof(*c)||c->cmdsize>(size_t)(end-p))return;if(c->cmd==LC_UUID&&c->cmdsize==sizeof(uuid_command))exact=[[[NSUUID alloc]initWithUUIDBytes:((const uuid_command *)c)->uuid].UUIDString isEqual:@"B1AA1CC2-C72B-3D8A-AC90-1E8C9155E519"];p+=c->cmdsize;}
 if(!exact)return;slide=_dyld_get_image_vmaddr_slide(image);
 // Original GameThreadCall(block,bool,NSArray*), not Frostpunk's differing ABI.
 uint8_t b[16];const uint8_t expected[]={0xf8,0x5f,0xbc,0xa9,0xf6,0x57,0x01,0xa9,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9};
 if(!copy(0x100e38370+slide,b,16)||memcmp(b,expected,16))return;
 token=getenv("MHT_SESSION")?@(getenv("MHT_SESSION")):nil;if(!token.length)return;consumed=[NSMutableSet new];stage(@"ready");
 timer=[NSTimer timerWithTimeInterval:.2 repeats:YES block:^(NSTimer *){
 if(busy||!read<uintptr_t>(0x112fb8928+slide))return;
 NSData *d=[NSData dataWithContentsOfFile:@"/private/tmp/trainerdock-inzoi/Request.json"];NSDictionary *r=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]:nil;
 if(![r isKindOfClass:NSDictionary.class]||![r[@"token"] isEqual:token]||![r[@"id"] isKindOfClass:NSString.class]||[consumed containsObject:r[@"id"]]||consumed.count>=4096)return;
 [consumed addObject:r[@"id"]];busy=true;NSTimeInterval submitted=NSDate.date.timeIntervalSince1970;
 ((void(*)(dispatch_block_t,bool,NSArray *))(0x100e38370+slide))(^ { @autoreleasepool {
 NSMutableDictionary *reply=[@{@"id":r[@"id"]} mutableCopy];@try{try{if(NSDate.date.timeIntervalSince1970-submitted>10)throw std::runtime_error("Expired diagnostic request");reply[@"result"]=perform(r[@"action"]);}catch(const std::exception &e){reply[@"error"]=@(e.what());}}@catch(NSException *e){reply[@"error"]=e.reason;}
 [[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil] writeToFile:@"/private/tmp/trainerdock-inzoi/Reply.json" atomically:YES];dispatch_async(dispatch_get_main_queue(),^{busy=false;stage(@"reply completed");});
 }},false,@[NSDefaultRunLoopMode,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode]);
 }];[NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
 });}
