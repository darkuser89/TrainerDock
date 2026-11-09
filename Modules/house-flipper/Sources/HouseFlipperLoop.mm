// SPDX-License-Identifier: GPL-3.0-only
#import "HouseFlipperLoop.h"
#include "HouseFlipperMono.hpp"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <uuid/uuid.h>
#include <pthread.h>
#include <atomic>
#include <mutex>
#include <cstring>
extern "C" void *HFPlayerForInput(void);
namespace {
constexpr const char *profile="steam-x86_64-25247477";
constexpr const char *mainUUID="6D82BA8C-38A6-3A10-8CDE-BDD368B8F4CF",*unityUUID="B4F0AC68-1AB0-3B92-8C74-E3105B2D53C0",*monoUUID="E7420BC7-A26B-33FA-B5CD-41CAD7D4614C";
bool matchesUUID(const uint8_t *value,const char *expected){uuid_t uuid;return value&&!uuid_parse(expected,uuid)&&!memcmp(value,uuid,16);}
bool loadedUUID(const char *suffix,const char *expected){for(uint32_t index=0;index<_dyld_image_count();index++){
 const char *name=_dyld_get_image_name(index);const auto *header=(const mach_header_64 *)_dyld_get_image_header(index);if(!name||!header||header->magic!=MH_MAGIC_64)continue;
 if(!strcmp(suffix,"/Contents/MacOS/House Flipper Game")&&header->filetype!=MH_EXECUTE)continue;
 size_t n=strlen(name),s=strlen(suffix);if(n<s||strcmp(name+n-s,suffix))continue;if(header->cputype!=CPU_TYPE_X86_64)return false;
 const uint8_t *p=(const uint8_t *)(header+1),*end=p+header->sizeofcmds;
 for(uint32_t c=0;c<header->ncmds;c++){if(p+sizeof(load_command)>end)return false;const auto *command=(const load_command *)p;if(command->cmdsize<sizeof(load_command)||command->cmdsize>(size_t)(end-p))return false;if(command->cmd==LC_UUID)return command->cmdsize==sizeof(uuid_command)&&matchesUUID(((const uuid_command *)command)->uuid,expected);p+=command->cmdsize;}return false;
 }return false;}
struct State {std::mutex bootstrap,queueLock,noteLock,handlerLock;NSMutableArray *pending=[NSMutableArray new];hf::Root callback,inputOwner;dispatch_block_t handler;std::atomic<bool>bound{false},observed{false},invalidated{false};std::atomic<uint64_t>frames{0};pthread_t thread={};int32_t domainID=0;NSString *note=@"Warte auf den ursprünglichen Unity-Rückruf.";bool mouse=false,held=false,oldVisible=false,oldBlocked=false;int32_t oldLock=0;};
State&state(){static auto *s=new State;return *s;}thread_local bool inFrame=false;
void note(NSString *value){std::lock_guard<std::mutex>guard(state().noteLock);state().note=[value copy];}
NSString *note(){std::lock_guard<std::mutex>guard(state().noteLock);return state().note;}
void safe(dispatch_block_t work){if(!work)return;@try{try{work();}catch(const std::exception&e){note(@(e.what()));}}@catch(NSException*e){note(e.reason ?: @"Der ursprüngliche Rückruf wurde abgebrochen.");}}
void invalidate(){auto&s=state();s.invalidated=true;s.observed=false;note(@"Die ursprüngliche Mono-Domain wurde beendet. Spiel regulär neu starten.");NSArray *jobs;{std::lock_guard<std::mutex>g(s.queueLock);jobs=s.pending.copy;[s.pending removeAllObjects];}for(NSDictionary *job in jobs){dispatch_block_t rejected=job[@"rejected"];if(rejected)dispatch_async(dispatch_get_main_queue(),rejected);}}
void tick(){auto&s=state();@autoreleasepool{
 if(s.invalidated||hf::api.domainGet()!=hf::domain())return;
 if(!s.observed){s.thread=pthread_self();s.observed=true;}if(!pthread_equal(s.thread,pthread_self()))return;
 inFrame=true;s.frames++;dispatch_block_t handler;{std::lock_guard<std::mutex>g(s.handlerLock);handler=s.handler;}safe(handler);if(s.mouse)safe(^{HFMouse(YES);});
 NSArray *jobs=nil;{std::lock_guard<std::mutex>g(s.queueLock);if(s.pending.count){jobs=s.pending.copy;[s.pending removeAllObjects];}}for(NSDictionary*job in jobs)safe(job[@"work"]);inFrame=false;
}}
struct DomainScan{void *selected=nullptr;unsigned count=0;};
void assembly(void *value,void *found){void *image=hf::api.assemblyImage(value);const char *guid=image?hf::api.guid(image):nullptr;if(guid&&!strcasecmp(guid,"67e7164a-b528-41e2-95db-3865ad4627f4"))*(bool*)found=true;}
void scanDomain(void *value,void *scan){bool found=false;hf::api.domainAssemblies(value,assembly,&found);if(found){auto*r=(DomainScan*)scan;r->selected=value;r->count++;}}
bool bootstrap(){auto&s=state();std::lock_guard<std::mutex>g(s.bootstrap);if(s.invalidated)return false;if(s.bound){if(hf::api.domainByID(s.domainID)!=hf::domain()){invalidate();return false;}return true;}if(!hf::bind())return false;
 DomainScan scan;hf::api.domains(scanDomain,&scan);if(scan.count!=1)return false;hf::setDomain(scan.selected);s.domainID=hf::api.domainID(scan.selected);if(!hf::api.attach(scan.selected))return false;
 for(auto spec:{std::pair{"Assembly-CSharp","67e7164a-b528-41e2-95db-3865ad4627f4"},std::pair{"Assembly-CSharp-firstpass","1bed00e6-eb0b-48ca-9a44-3aec8f32337b"},std::pair{"UnityEngine.CoreModule","4f29e6de-8ee1-4359-882d-520faba32535"},std::pair{"mscorlib","eae584ce-26bc-4022-9c1b-1aa476bfa589"}}){void*i=hf::image(spec.first);if(!i)return false;const char*guid=hf::api.guid(i);if(!guid||strcasecmp(guid,spec.second))throw std::runtime_error("Die ursprüngliche Programmbausteinkennung weicht ab.");}
 auto action=hf::type("UnityEngine.Events","UnityAction","UnityEngine.CoreModule");hf::typedMethod(action,"Invoke","System.Void",{},false);
 auto marshal=hf::type("System.Runtime.InteropServices","Marshal","mscorlib");auto convert=hf::typedMethod(marshal,"GetDelegateForFunctionPointer","System.Delegate",{"System.IntPtr","System.Type"},true);
 hf::Root reflected(hf::api.typeObject(hf::domain(),hf::api.classType(action)));void*pointer=(void*)&tick;hf::Root callback(hf::call(convert,nullptr,{&pointer,reflected.get()}));if(!callback.get())return false;
 auto app=hf::type("UnityEngine","Application","UnityEngine.CoreModule");hf::call(hf::typedMethod(app,"add_onBeforeRender","System.Void",{"UnityEngine.Events.UnityAction"},true),nullptr,{callback.get()});s.callback=std::move(callback);s.bound=true;note(@"Originaler Unity-Rückruf registriert; warte auf seine Ausführung.");return true;
}
}
namespace hf {
bool runtimeImagesMatch(const char *id,const uint8_t *main,const uint8_t *unity,const uint8_t *mono){return id&&!strcmp(id,profile)&&matchesUUID(main,mainUUID)&&matchesUUID(unity,unityUUID)&&matchesUUID(mono,monoUUID);}
bool runtimeMainImageMatches(uint32_t fileType,const char *loaded,const char *target){return fileType==MH_EXECUTE&&loaded&&target&&loaded[0]=='/'&&target[0]=='/'&&!strcmp(loaded,target);}
}
BOOL HFSupportedImages(void){return loadedUUID("/Contents/MacOS/House Flipper Game",mainUUID)&&loadedUUID("/Contents/Frameworks/UnityPlayer.dylib",unityUUID)&&loadedUUID("/Contents/Frameworks/libmonobdwgc-2.0.dylib",monoUUID);}
BOOL HFEnsureLoop(void){try{return bootstrap();}catch(const std::exception&e){note(@(e.what()));return NO;}}
BOOL HFEnqueue(dispatch_block_t work){return HFEnqueueChecked(work,nil);}
BOOL HFEnqueueChecked(dispatch_block_t work,dispatch_block_t rejected){if(!work||!HFEnsureLoop())return NO;auto&s=state();std::lock_guard<std::mutex>g(s.queueLock);if(s.invalidated||s.pending.count>=64)return NO;NSMutableDictionary*job=[@{@"work":[work copy]}mutableCopy];if(rejected)job[@"rejected"]=[rejected copy];[s.pending addObject:job];return YES;}
BOOL HFInFrame(void){auto&s=state();return inFrame&&!s.invalidated&&s.observed&&pthread_equal(s.thread,pthread_self());}
void HFSetFrameHandler(dispatch_block_t handler){auto&s=state();std::lock_guard<std::mutex>g(s.handlerLock);s.handler=[handler copy];}
BOOL HFMouse(BOOL wanted){if(!HFInFrame())return NO;auto&s=state();if(!wanted)s.mouse=false;if(!wanted&&!s.held)return NO;try{
 auto cursor=hf::type("UnityEngine","Cursor","UnityEngine.CoreModule");auto getVisible=hf::typedMethod(cursor,"get_visible","System.Boolean",{},true),setVisible=hf::typedMethod(cursor,"set_visible","System.Void",{"System.Boolean"},true);auto getLock=hf::typedMethod(cursor,"get_lockState","UnityEngine.CursorLockMode",{},true),setLock=hf::typedMethod(cursor,"set_lockState","System.Void",{"UnityEngine.CursorLockMode"},true);
 hf::Object player=HFPlayerForInput();hf::Root owner(player?hf::ref(player,hf::api.objectClass(player),"fpsController"):nullptr,true);auto component=owner.get();
 if(s.held&&s.inputOwner.get()!=component){s.oldBlocked=component&&hf::number(component,hf::api.objectClass(component),"isMouseRotationBlocked");s.inputOwner.reset(component,true);}
 auto k=component?hf::api.objectClass(component):nullptr;if(component&&k!=hf::type("UnityStandardAssets.Characters.FirstPerson","FirstPersonController","Assembly-CSharp-firstpass"))throw std::runtime_error("Der ursprüngliche Mausbesitzer weicht ab.");hf::Field blocked=component?hf::field(k,"isMouseRotationBlocked"):nullptr;if(blocked&&hf::scalarKind(blocked)!=2)throw std::runtime_error("Die ursprüngliche Maussperre hat einen anderen Typ.");
 if(wanted){if(!s.held){s.oldVisible=hf::unboxNumber(hf::call(getVisible),2);s.oldLock=(int32_t)hf::unboxNumber(hf::call(getLock));s.oldBlocked=component&&hf::number(component,k,"isMouseRotationBlocked");s.inputOwner.reset(component,true);s.held=true;}
  if(component&&!hf::number(component,k,"isMouseRotationBlocked"))hf::write(component,k,blocked,hf::numeric(blocked,1));uint8_t yes=1;int32_t unlocked=0;if(!hf::unboxNumber(hf::call(getVisible),2))hf::call(setVisible,nullptr,{&yes});if(hf::unboxNumber(hf::call(getLock))!=0)hf::call(setLock,nullptr,{&unlocked});s.mouse=true;return hf::unboxNumber(hf::call(getVisible),2)&&hf::unboxNumber(hf::call(getLock))==0&&(!component||hf::number(component,k,"isMouseRotationBlocked"));
 }
 if(component&&hf::number(component,k,"isMouseRotationBlocked"))hf::write(component,k,blocked,hf::numeric(blocked,s.oldBlocked));uint8_t visible=s.oldVisible;int32_t mode=s.oldLock;if(hf::unboxNumber(hf::call(getVisible),2))hf::call(setVisible,nullptr,{&visible});if(hf::unboxNumber(hf::call(getLock))==0)hf::call(setLock,nullptr,{&mode});s.mouse=false;s.held=false;s.inputOwner.reset();
 }catch(const std::exception&e){note(@(e.what()));}return NO;}
NSDictionary *HFLoopDiagnostics(void){auto&s=state();NSUInteger pending;{std::lock_guard<std::mutex>g(s.queueLock);pending=s.pending.count;}return @{@"nativeCallback":@(s.bound.load()),@"callbackObserved":@(s.observed.load()),@"frames":@(s.frames.load()),@"inFrame":@(HFInFrame()),@"pending":@(pending),@"invalidated":@(s.invalidated.load()),@"nativeNote":note() ?: @""};}
