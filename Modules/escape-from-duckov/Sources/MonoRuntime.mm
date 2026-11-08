// SPDX-License-Identifier: GPL-3.0-only
// Public Mono embedding API, no executable patches or foreign trainer runtime.
#import "MonoRuntime.h"
#import "DuckovManagedImage.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <os/log.h>
#include <cstring>
#include "../../_Shared/Managed/MetadataCache.hpp"
#include <tuple>
namespace {
struct MonoAPI {
 void *(*root)();void *(*domain)();void (*domains)(void (*)(void *,void *),void *);
 const char *(*domainName)(void *);void *(*attach)(void *);void *(*loaded)(const char *);
 void *(*open)(char *,uint32_t,int,int *);void *(*load)(void *,const char *,int *);
 void *(*image)(void *);void *(*klass)(void *,const char *,const char *);
 void *(*method)(void *,const char *,int);void *(*invoke)(void *,void *,void **,void **);
 void (*icall)(const char *,const void *);void *(*unbox)(void *);
 char *(*utf8)(void *);void (*free)(void *);
 void *(*objectClass)(void *);const char *(*className)(void *);
} api={};
void *monoHandle,*trainerClass;
BOOL imageChecked=NO,imageValid=NO;
NSString *failure=@"Warte auf die ursprüngliche Mono-Laufzeit.";
NSLock *lock;NSMutableArray<dispatch_block_t> *pending;
thread_local bool gameplay=false;
void ensureQueue(){static dispatch_once_t once;dispatch_once(&once,^{lock=[NSLock new];pending=[NSMutableArray new];});}
void tick() {
 ensureQueue();[lock lock];if(!pending.count){[lock unlock];return;}NSArray<dispatch_block_t> *work=pending.copy;[pending removeAllObjects];[lock unlock];
 gameplay=true;
 @autoreleasepool {for(dispatch_block_t block in work)@try {block();}@catch(NSException *e){os_log_error(OS_LOG_DEFAULT,"TrainerDock Duckov native callback: %{public}@",e.name);}}
 gameplay=false;
}
void chooseDomain(void *domain,void *result) {
 const char *name=api.domainName(domain);
 if(name && (strstr(name,"Unity") || strstr(name,"Child")))*static_cast<void **>(result)=domain;
}
bool bindMono() {
 if(monoHandle)return true;
 if(!DUSupportedImage())return false;
 NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/Frameworks/libmonobdwgc-2.0.dylib"];
 monoHandle=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_NOLOAD);if(!monoHandle)return false;
#define LOAD(field,name) api.field=reinterpret_cast<decltype(api.field)>(dlsym(monoHandle,name));if(!api.field){monoHandle=nullptr;return false;}
 LOAD(root,"mono_get_root_domain");LOAD(domain,"mono_domain_get");LOAD(domains,"mono_domain_foreach");LOAD(domainName,"mono_domain_get_friendly_name");
 LOAD(attach,"mono_thread_attach");LOAD(loaded,"mono_image_loaded");LOAD(open,"mono_image_open_from_data");LOAD(load,"mono_assembly_load_from");LOAD(image,"mono_assembly_get_image");
 LOAD(klass,"mono_class_from_name");LOAD(method,"mono_class_get_method_from_name");LOAD(invoke,"mono_runtime_invoke");LOAD(icall,"mono_add_internal_call");
 LOAD(unbox,"mono_object_unbox");LOAD(utf8,"mono_string_to_utf8");LOAD(free,"mono_free");LOAD(objectClass,"mono_object_get_class");LOAD(className,"mono_class_get_name");
#undef LOAD
 return true;
}
void *invoke(const char *name,int count,void **args=nullptr) {
 if(!trainerClass)return nullptr;
 using Key=std::tuple<void *,std::string,int>;static mht::managed::MetadataCache<Key,void *> cache;
 void *method=cache.get(api.domain ? api.domain() : nullptr,(uintptr_t)api.method,Key{trainerClass,name,count},[&]{return api.method(trainerClass,name,count);});
 if(!method)return nullptr;
 void *exception=nullptr;void *result=api.invoke(method,nullptr,args,&exception);
 if(exception){failure=[NSString stringWithFormat:@"Mono: %s",api.className(api.objectClass(exception))];os_log_error(OS_LOG_DEFAULT,"TrainerDock Duckov %{public}@ in %{public}s",failure,name);return nullptr;}
 return result;
}
bool bootstrap() {
 if(!bindMono() || !api.root())return false;
 // Wait for the game to load its own assembly; never load a substitute copy.
 if(!api.loaded("TeamSoda.Duckov.Core") && !api.loaded("TeamSoda.Duckov.Core.dll"))return false;
 void *domain=api.domain();api.domains(chooseDomain,&domain);if(!domain)domain=api.root();if(!api.attach(domain))return false;
 if(!trainerClass){
  int status=0;void *image=api.open((char *)MHTManagedImage,sizeof(MHTManagedImage),1,&status);if(!image || status)return false;
  void *assembly=api.load(image,"MHTDuckov.Managed.dll",&status);if(!assembly || status)return false;
  trainerClass=api.klass(api.image(assembly),"MHTDuckov","Trainer");if(!trainerClass)return false;
  api.icall("MHTDuckov.Native::Tick",(const void *)&tick);
 }
 void *result=invoke("Bootstrap",0);return result && *static_cast<uint8_t *>(api.unbox(result));
}
NSString *text(void *result) {
 if(!result)return nil;char *raw=api.utf8(result);if(!raw)return nil;NSString *value=[NSString stringWithUTF8String:raw];api.free(raw);return value;
}
NSDictionary *json(void *result) {
 NSString *value=text(result);NSData *data=[value dataUsingEncoding:NSUTF8StringEncoding];id object=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
 return [object isKindOfClass:NSDictionary.class] ? object : @{};
}
}
BOOL DUSupportedImage(void) {
 if(imageChecked)return imageValid;imageChecked=YES;
 const uint8_t expected[]={0x16,0x63,0x0b,0x36,0x4c,0x21,0x38,0x5e,0x94,0xe1,0x84,0x8e,0xeb,0xb8,0xe9,0x56};
 for(uint32_t i=0;i<_dyld_image_count();i++) {
  const auto *header=(const mach_header_64 *)_dyld_get_image_header(i);
  if(!header || header->magic!=MH_MAGIC_64 || header->filetype!=MH_EXECUTE)continue;
  if(header->cputype!=CPU_TYPE_ARM64 || header->sizeofcmds>1024*1024 || header->ncmds>4096)return NO;
  const uint8_t *cursor=(const uint8_t *)(header+1),*end=cursor+header->sizeofcmds;
  for(uint32_t j=0;j<header->ncmds;j++) {
   if(cursor+sizeof(load_command)>end)return NO;const auto *command=(const load_command *)cursor;
   if(command->cmdsize<sizeof(load_command) || command->cmdsize>(uintptr_t)(end-cursor))return NO;
   if(command->cmd==LC_UUID && command->cmdsize==sizeof(uuid_command))imageValid=!memcmp(((const uuid_command *)cursor)->uuid,expected,16);
   cursor+=command->cmdsize;
  }
  return imageValid;
 }
 return NO;
}
BOOL DUEnqueue(dispatch_block_t work) {
 ensureQueue();if(!bootstrap())return NO;
 [lock lock];if(pending.count>=64){[lock unlock];return NO;}[pending addObject:[work copy]];[lock unlock];return YES;
}
NSDictionary *DUInspect(void) {
 if(!gameplay)return @{@"kind":@0,@"identity":@"unavailable",@"note":failure};
 NSDictionary *state=json(invoke("Inspect",0));return state.count ? state : @{@"kind":@0,@"identity":@"unavailable",@"note":failure};
}
NSDictionary *DUEffect(NSInteger feature,BOOL wanted,double value) {
 if(!gameplay)return @{};int32_t f=(int32_t)feature;uint8_t w=wanted;void *args[]={&f,&w,&value};return json(invoke("Effect",3,args));
}
NSString *DUOneShot(NSInteger feature,double value) {
 if(!gameplay)return @"Kein bestätigter Unity-GameThread.";int32_t f=(int32_t)feature;void *args[]={&f,&value};return text(invoke("OneShot",2,args)) ?: failure;
}
void DURelease(void){if(gameplay)invoke("Release",0);}
BOOL DUMouse(BOOL wanted) {
 if(!gameplay)return NO;uint8_t w=wanted;void *args[]={&w};void *result=invoke("Mouse",1,args);return result && *static_cast<uint8_t *>(api.unbox(result));
}
