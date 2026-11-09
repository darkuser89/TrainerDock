// SPDX-License-Identifier: GPL-3.0-only
#import "DredgeNative.h"
#include "DredgeMono.hpp"
#include "DredgeBuild.h"
#include "../../_Shared/Managed/MetadataCache.hpp"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <uuid/uuid.h>
#include <dlfcn.h>
#include <pthread.h>
#include <atomic>
#include <mutex>
#include <tuple>
#include <memory>
#include <cmath>
#include <cstring>
namespace {
bool imageUUID(const char *suffix,const char *expected){
 uuid_t wanted;if(uuid_parse(expected,wanted))return false;
 for(uint32_t i=0;i<_dyld_image_count();i++){
  const char *name=_dyld_get_image_name(i);const auto *h=(const mach_header_64 *)_dyld_get_image_header(i);if(!name||!h||h->magic!=MH_MAGIC_64)continue;
  size_t n=strlen(name),s=strlen(suffix);if(n<s||strcmp(name+n-s,suffix))continue;
  if(h->cputype!=DR_CPU_TYPE)return false;
  const uint8_t *p=(const uint8_t *)(h+1),*end=p+h->sizeofcmds;
  for(uint32_t c=0;c<h->ncmds;c++){if(p+sizeof(load_command)>end)return false;const auto *cmd=(const load_command *)p;if(cmd->cmdsize<sizeof(load_command)||cmd->cmdsize>(size_t)(end-p))return false;
   if(cmd->cmd==LC_UUID)return cmd->cmdsize==sizeof(uuid_command)&&!memcmp(((const uuid_command *)cmd)->uuid,wanted,16);p+=cmd->cmdsize;}
  return false;
 }return false;
}
BOOL nativeImages(){return imageUUID("/Contents/MacOS/DREDGE",DR_EXECUTABLE_UUID)&&imageUUID("/Contents/Frameworks/UnityPlayer.dylib",DR_UNITY_UUID)&&imageUUID("/Contents/Frameworks/libmonobdwgc-2.0.dylib",DR_MONO_UUID);}
}
namespace dr {
API api={};
static std::atomic<void *> gameDomain{nullptr};
void *domain(){return gameDomain.load() ?: (api.domainGet ? api.domainGet() : nullptr);}
bool bind(){if(api.root)return true;if(!nativeImages())return false;API a={};
#define LOAD(member,name) a.member=reinterpret_cast<decltype(a.member)>(dlsym(RTLD_DEFAULT,name));if(!a.member)return false;
 LOAD(root,"mono_get_root_domain");LOAD(domainGet,"mono_domain_get");LOAD(domainID,"mono_domain_get_id");LOAD(domainByID,"mono_domain_get_by_id");LOAD(domains,"mono_domain_foreach");LOAD(domainAssemblies,"mono_domain_assembly_foreach");LOAD(assemblyImage,"mono_assembly_get_image");LOAD(attach,"mono_thread_attach");LOAD(loaded,"mono_image_loaded");LOAD(guid,"mono_image_get_guid");LOAD(klass,"mono_class_from_name");LOAD(objectClass,"mono_object_get_class");LOAD(parent,"mono_class_get_parent");LOAD(method,"mono_class_get_method_from_name");LOAD(methods,"mono_class_get_methods");LOAD(methodName,"mono_method_get_name");LOAD(signature,"mono_method_signature");LOAD(params,"mono_signature_get_params");LOAD(paramCount,"mono_signature_get_param_count");LOAD(returnType,"mono_signature_get_return_type");LOAD(methodFlags,"mono_method_get_flags");LOAD(invoke,"mono_runtime_invoke");LOAD(unbox,"mono_object_unbox");LOAD(classType,"mono_class_get_type");LOAD(typeObject,"mono_type_get_object");LOAD(field,"mono_class_get_field_from_name");LOAD(fieldType,"mono_field_get_type");LOAD(kind,"mono_type_get_type");LOAD(typeName,"mono_type_get_name");LOAD(flags,"mono_field_get_flags");LOAD(vtable,"mono_class_vtable");LOAD(read,"mono_field_get_value");LOAD(write,"mono_field_set_value");LOAD(readStatic,"mono_field_static_get_value");LOAD(writeStatic,"mono_field_static_set_value");LOAD(arrayLength,"mono_array_length");LOAD(arrayAddress,"mono_array_addr_with_size");LOAD(strong,"mono_gchandle_new");LOAD(weak,"mono_gchandle_new_weakref");LOAD(target,"mono_gchandle_get_target");LOAD(freeHandle,"mono_gchandle_free");LOAD(utf8,"mono_string_to_utf8");LOAD(free,"mono_free");LOAD(classFromType,"mono_class_from_mono_type");LOAD(isEnum,"mono_class_is_enum");LOAD(enumBase,"mono_class_enum_basetype");LOAD(valueSize,"mono_class_value_size");
#undef LOAD
 Dl_info provider={};if(!dladdr((void *)a.root,&provider)||!provider.dli_fname||!strstr(provider.dli_fname,"/DREDGE.app/Contents/Frameworks/libmonobdwgc-2.0.dylib"))return false;
 if(!a.root())return false;api=a;return true;
}
void *image(const char *name){for(const char *suffix:{"",".dll",".exe"}){std::string n=std::string(name)+suffix;if(void *i=api.loaded(n.c_str()))return i;}return nullptr;}
Klass type(const char *space,const char *name,const char *imageName){using Key=std::tuple<std::string,std::string,std::string>;static mht::managed::MetadataCache<Key,Klass,256> cache;return cache.get(domain(),(uintptr_t)api.klass,Key{imageName,space,name},[&]()->Klass{void *i=image(imageName);Klass k=i?api.klass(i,space,name):nullptr;if(!k)throw std::runtime_error(std::string("Ursprünglicher Typ fehlt: ")+space+"."+name);return k;});}
Field field(Klass k,const char *name){using Key=std::pair<Klass,std::string>;static mht::managed::MetadataCache<Key,Field> cache;return cache.get(domain(),(uintptr_t)api.field,Key{k,name},[&]()->Field{for(;k;k=api.parent(k))if(Field f=api.field(k,name))return f;throw std::runtime_error(std::string("Ursprüngliches Feld fehlt: ")+name);});}
Method method(Klass k,const char *name,int count){using Key=std::tuple<Klass,std::string,int>;static mht::managed::MetadataCache<Key,Method> cache;return cache.get(domain(),(uintptr_t)api.method,Key{k,name,count},[&]()->Method{for(;k;k=api.parent(k))if(Method m=api.method(k,name,count)){if(api.paramCount(api.signature(m))!=(uint32_t)count)throw std::runtime_error("Die ursprüngliche Aufrufsignatur weicht ab.");return m;}throw std::runtime_error(std::string("Ursprüngliche Methode fehlt: ")+name);});}
std::string typeName(void *t){if(!t)return {};static mht::managed::MetadataCache<void *,std::shared_ptr<std::string>> cache;auto result=cache.get(domain(),(uintptr_t)api.typeName,t,[&]()->std::shared_ptr<std::string>{char *name=api.typeName(t);if(!name)return {};auto value=std::make_shared<std::string>(name);api.free(name);return value;});return result?*result:std::string{};}
Method typedMethod(Klass k,const char *name,const char *result,std::initializer_list<const char *> parameters,bool isStatic){
 using Key=std::tuple<Klass,std::string,std::string,std::string,bool>;static mht::managed::MetadataCache<Key,Method,512>cache;
 std::string parameterKey;for(const char *parameter:parameters){parameterKey+=parameter;parameterKey+='\n';}
 return cache.get(domain(),(uintptr_t)api.methods,Key{k,name,result,parameterKey,isStatic},[&]()->Method{
  for(Klass owner=k;owner;owner=api.parent(owner)){void *iterator=nullptr;
   while(Method m=api.methods(owner,&iterator)){
    const char *methodName=api.methodName(m);if(!methodName||strcmp(methodName,name))continue;
    void *s=api.signature(m);uint32_t impl=0;
    if(api.paramCount(s)!=parameters.size()||typeName(api.returnType(s))!=result||bool(api.methodFlags(m,&impl)&16)!=isStatic)continue;
    void *iter=nullptr;bool matches=true;for(const char *parameter:parameters)if(typeName(api.params(s,&iter))!=parameter){matches=false;break;}
    if(matches)return m;
   }
  }throw std::runtime_error(std::string("Die ursprüngliche vollständige Methodensignatur fehlt: ")+name);
 });
}
Object call(Method m,Object o,std::vector<void *> args){if(!m||api.paramCount(api.signature(m))!=args.size())throw std::runtime_error("Die ursprüngliche Argumentanzahl weicht ab.");uint32_t impl=0;if(bool(api.methodFlags(m,&impl)&16)==bool(o))throw std::runtime_error("Der ursprüngliche Methodenbesitzer weicht ab.");Object exception=nullptr;Object result=api.invoke(m,o,args.empty()?nullptr:args.data(),&exception);if(exception)throw std::runtime_error("Der ursprüngliche Mono-Aufruf wurde abgelehnt.");return result;}
std::string text(Object o){if(!o)return {};char *s=api.utf8(o);std::string r=s?s:"";if(s)api.free(s);return r;}
int scalarKind(Field f){auto t=api.fieldType(f);Klass k=api.classFromType(t);if(k&&api.isEnum(k))t=api.enumBase(k);return api.kind(t);}
size_t size(Field f){int k=scalarKind(f);switch(k){case 2:case 4:case 5:return 1;case 3:case 6:case 7:return 2;case 8:case 9:case 12:return 4;case 10:case 11:case 13:return 8;case 17:{Klass c=api.classFromType(api.fieldType(f));uint32_t alignment=0;int n=api.valueSize(c,&alignment);if(n>0&&n<=256)return (size_t)n;break;}}throw std::runtime_error("Nicht unterstützte native Wertanbindung.");}
std::vector<uint8_t> read(Object o,Klass k,Field f){std::vector<uint8_t>b(size(f));if(api.flags(f)&16){void *v=api.vtable(domain(),k);if(!v)throw std::runtime_error("Die ursprüngliche statische Tabelle fehlt.");api.readStatic(v,f,b.data());}else if(o)api.read(o,f,b.data());else throw std::runtime_error("Der ursprüngliche Besitzer fehlt.");return b;}
void write(Object o,Klass k,Field f,const std::vector<uint8_t>& b){if(b.size()!=size(f))throw std::runtime_error("Die native Wertgröße weicht ab.");if(api.flags(f)&16){void *v=api.vtable(domain(),k);if(!v)throw std::runtime_error("Die ursprüngliche statische Tabelle fehlt.");api.writeStatic(v,f,(void *)b.data());}else if(o)api.write(o,f,(void *)b.data());else throw std::runtime_error("Der ursprüngliche Besitzer fehlt.");}
Object ref(Object o,Klass k,const char *name){Field f=field(k,name);int kind=api.kind(api.fieldType(f));if(kind!=14&&kind!=18&&kind!=20&&kind!=21&&kind!=28&&kind!=29)throw std::runtime_error("Eine ursprüngliche Objektreferenz wurde erwartet.");Object value=nullptr;if(api.flags(f)&16){void *v=api.vtable(domain(),k);if(v)api.readStatic(v,f,&value);}else if(o)api.read(o,f,&value);return value;}
double number(Object o,Klass k,const char *name){Field f=field(k,name);auto b=read(o,k,f);switch(scalarKind(f)){case 2:return b[0]!=0;case 4:return *(int8_t *)b.data();case 5:return b[0];case 6:{int16_t n;memcpy(&n,b.data(),2);return n;}case 7:{uint16_t n;memcpy(&n,b.data(),2);return n;}case 8:{int32_t n;memcpy(&n,b.data(),4);return n;}case 9:{uint32_t n;memcpy(&n,b.data(),4);return n;}case 12:{float n;memcpy(&n,b.data(),4);return n;}case 13:{double n;memcpy(&n,b.data(),8);return n;}default:throw std::runtime_error("Nicht unterstützte Zahlenwertabfrage.");}}
std::vector<uint8_t> numeric(Field f,double value){if(!std::isfinite(value))throw std::runtime_error("Ein endlicher Zahlenwert ist erforderlich.");std::vector<uint8_t>b(size(f));switch(scalarKind(f)){case 2:b[0]=value!=0;break;case 8:{if(value<INT32_MIN||value>INT32_MAX||floor(value)!=value)throw std::runtime_error("Die Ganzzahl liegt außerhalb des gültigen Bereichs.");int32_t n=(int32_t)value;memcpy(b.data(),&n,4);break;}case 9:{if(value<0||value>UINT32_MAX||floor(value)!=value)throw std::runtime_error("Die Ganzzahl liegt außerhalb des gültigen Bereichs.");uint32_t n=(uint32_t)value;memcpy(b.data(),&n,4);break;}case 12:{if(value>FLT_MAX||value<-FLT_MAX)throw std::runtime_error("Die Fließkommazahl liegt außerhalb des gültigen Bereichs.");float n=(float)value;memcpy(b.data(),&n,4);break;}case 13:memcpy(b.data(),&value,8);break;default:throw std::runtime_error("Nicht unterstützte Zahlenwertänderung.");}return b;}
double unboxNumber(Object o,int kind){if(!o)throw std::runtime_error("Kein ursprünglicher Rückgabewert.");void *p=api.unbox(o);if(!p)throw std::runtime_error("Kein ursprünglicher Zahlenwert.");if(kind==2)return *(uint8_t *)p!=0;if(kind==12){float n;memcpy(&n,p,4);return n;}if(kind==13){double n;memcpy(&n,p,8);return n;}int32_t n;memcpy(&n,p,4);return n;}
}
namespace {
struct NativeState {std::mutex bootstrap,queueLock;NSMutableArray<NSDictionary *> *pending=[NSMutableArray new];dr::Root callback;dispatch_block_t handler;std::atomic<bool> bound{false},observed{false},invalidated{false};int32_t domainID=0;std::mutex noteLock;pthread_t thread={};std::atomic<uint64_t> frames{0};NSString *failure=@"Warte auf den ursprünglichen Unity-Rückruf.";bool mouse=false,mouseHeld=false,oldVisible=false;int32_t oldLock=0,oldLayer=0;bool layerHeld=false;dr::Root inputOwner,gameOwner;};
NativeState& state(){static auto *s=new NativeState;return *s;}thread_local bool inFrame=false;
void setNote(NSString *note){auto &s=state();std::lock_guard<std::mutex>lock(s.noteLock);s.failure=[note copy];}
NSString *note(){auto &s=state();std::lock_guard<std::mutex>lock(s.noteLock);return s.failure;}
void invalidateDomain(){auto &s=state();s.invalidated=true;s.observed=false;setNote(@"Die ursprüngliche Mono-Domain wurde beendet. Spiel regulär neu starten.");NSArray *jobs;{std::lock_guard<std::mutex>lock(s.queueLock);jobs=s.pending.copy;[s.pending removeAllObjects];}for(NSDictionary *job in jobs){dispatch_block_t rejected=job[@"rejected"];if(rejected)dispatch_async(dispatch_get_main_queue(),rejected);}}

void runSafely(dispatch_block_t work){if(!work)return;@try{try{work();}catch(const std::exception&e){setNote(@(e.what()));}}@catch(NSException *e){setNote(e.reason ?: @"Der ursprüngliche Rückruf wurde abgebrochen.");}}
void tick(){auto &s=state();@autoreleasepool{
 if(s.invalidated)return;
 if(dr::api.domainGet()!=dr::domain()){setNote(@"Der ursprüngliche Unity-Domain-Rückruf weicht ab.");return;}
 if(!s.observed){s.thread=pthread_self();s.observed=true;}if(!pthread_equal(s.thread,pthread_self()))return;
 inFrame=true;s.frames++;runSafely(s.handler);if(s.mouse)DRMouse(YES);
 // A failed effect must not strand a queued disable/release command.
 NSArray<NSDictionary *> *jobs=nil;{std::lock_guard<std::mutex>lock(s.queueLock);if(s.pending.count){jobs=s.pending.copy;[s.pending removeAllObjects];}}
 for(NSDictionary *job in jobs)runSafely(job[@"work"]);inFrame=false;
}}
struct DomainScan {void *selected=nullptr;NSUInteger count=0;};
void findAssembly(void *assembly,void *result){void *image=dr::api.assemblyImage(assembly);const char *guid=image?dr::api.guid(image):nullptr;if(guid&&!strcasecmp(guid,DR_ASSEMBLY_MVID))*(bool *)result=true;}
void findDomain(void *domain,void *result){bool found=false;dr::api.domainAssemblies(domain,findAssembly,&found);if(found){auto *scan=(DomainScan *)result;scan->selected=domain;scan->count++;}}
bool bootstrap(){auto &s=state();std::lock_guard<std::mutex>lock(s.bootstrap);if(s.invalidated)return false;if(s.bound){if(dr::api.domainByID(s.domainID)!=dr::domain()){invalidateDomain();return false;}return true;}if(!dr::bind())return false;
 DomainScan scan;dr::api.domains(findDomain,&scan);if(scan.count!=1)return false;dr::gameDomain=scan.selected;s.domainID=dr::api.domainID(scan.selected);if(!dr::api.attach(dr::domain()))return false;
 for(auto spec:{std::pair{"Assembly-CSharp",DR_ASSEMBLY_MVID},std::pair{"UnityEngine.CoreModule","0f53f448-e779-4ef3-be38-7fd7af52f619"},std::pair{"mscorlib","1fe4b731-1082-47d3-a7e5-7fad336611b9"}}){void *i=dr::image(spec.first);if(!i)return false;const char *guid=dr::api.guid(i);if(!guid||strcasecmp(guid,spec.second))throw std::runtime_error("Die ursprüngliche Programmbausteinkennung weicht ab.");}
 auto action=dr::type("UnityEngine.Events","UnityAction","UnityEngine.CoreModule");dr::typedMethod(action,"Invoke","System.Void",{},false);
 auto marshal=dr::type("System.Runtime.InteropServices","Marshal","mscorlib");auto delegateMethod=dr::typedMethod(marshal,"GetDelegateForFunctionPointer","System.Delegate",{"System.IntPtr","System.Type"},true);
 dr::Root reflected(dr::api.typeObject(dr::domain(),dr::api.classType(action)));void *pointer=(void *)&tick;
 dr::Root callback(dr::call(delegateMethod,nullptr,{&pointer,reflected.get()}));if(!callback.get())return false;
 auto app=dr::type("UnityEngine","Application","UnityEngine.CoreModule");auto add=dr::typedMethod(app,"add_onBeforeRender","System.Void",{"UnityEngine.Events.UnityAction"},true);
 dr::call(add,nullptr,{callback.get()});s.callback=std::move(callback);s.bound=true;setNote(@"Originaler Unity-Rückruf registriert; warte auf seine Ausführung.");return true;
}
}
BOOL DRSupportedImage(void){return nativeImages();}
BOOL DREnqueue(dispatch_block_t work){return DREnqueueChecked(work,nil);}
BOOL DREnqueueChecked(dispatch_block_t work,dispatch_block_t rejected){
 if(!work)return NO;try{if(!bootstrap())return NO;}catch(const std::exception&e){setNote(@(e.what()));return NO;}
 auto &s=state();std::lock_guard<std::mutex>lock(s.queueLock);if(s.pending.count>=64||s.invalidated)return NO;
 NSMutableDictionary *job=[@{@"work":[work copy]} mutableCopy];if(rejected)job[@"rejected"]=[rejected copy];[s.pending addObject:job];return YES;
}
BOOL DRInFrame(void){auto &s=state();return inFrame&&!s.invalidated&&s.observed&&pthread_equal(s.thread,pthread_self());}
void DRSetFrameHandler(dispatch_block_t handler){if(DRInFrame())state().handler=[handler copy];}
BOOL DRMouse(BOOL wanted){
 if(!DRInFrame())return NO;auto &s=state();if(!wanted&&!s.mouseHeld){s.mouse=false;return NO;}
 try{
  auto cursor=dr::type("UnityEngine","Cursor","UnityEngine.CoreModule");
  auto getVisible=dr::typedMethod(cursor,"get_visible","System.Boolean",{},true),setVisible=dr::typedMethod(cursor,"set_visible","System.Void",{"System.Boolean"},true);
  auto getLock=dr::typedMethod(cursor,"get_lockState","UnityEngine.CursorLockMode",{},true),setLock=dr::typedMethod(cursor,"set_lockState","System.Void",{"UnityEngine.CursorLockMode"},true);
  auto managerClass=dr::type("","GameManager");dr::Object manager=dr::ref(nullptr,managerClass,"Instance");
  dr::Object input=manager?dr::ref(manager,dr::api.objectClass(manager),"_dredgeInputManager"):nullptr;
  if(s.mouseHeld && (s.gameOwner.get()!=manager || s.inputOwner.get()!=input)){s.mouseHeld=false;s.layerHeld=false;s.gameOwner.reset();s.inputOwner.reset();}
  if(wanted){
   if(!s.mouseHeld){
    s.oldVisible=dr::unboxNumber(dr::call(getVisible),2);s.oldLock=(int32_t)dr::unboxNumber(dr::call(getLock));
    s.gameOwner.reset(manager,true);s.inputOwner.reset(input,true);s.mouseHeld=true;
    if(input){auto k=dr::api.objectClass(input);s.oldLayer=(int32_t)dr::number(input,k,"activeActionLayer");
     if(s.oldLayer!=1){dr::call(dr::typedMethod(k,"DisableGameInput","System.Void",{},false),input);s.layerHeld=dr::number(input,k,"activeActionLayer")==1&&dr::number(input,k,"cachedActionLayer")==s.oldLayer;}
    }
   }
   if(input&&s.layerHeld&&dr::number(input,dr::api.objectClass(input),"activeActionLayer")!=1)s.layerHeld=false;
   uint8_t yes=1;int32_t unlocked=0;
   if(!dr::unboxNumber(dr::call(getVisible),2))dr::call(setVisible,nullptr,{&yes});
   if(dr::unboxNumber(dr::call(getLock))!=0)dr::call(setLock,nullptr,{&unlocked});
   s.mouse=true;return dr::unboxNumber(dr::call(getVisible),2)&&dr::unboxNumber(dr::call(getLock))==0;
  }
  if(s.mouseHeld){
   if(input){auto k=dr::api.objectClass(input);
    if(s.layerHeld&&dr::number(input,k,"activeActionLayer")==1&&dr::number(input,k,"cachedActionLayer")==s.oldLayer)
     dr::call(dr::typedMethod(k,"ResumeGameInput","System.Void",{},false),input);
    // The original policy respects a new menu, current input device and settings.
    dr::call(dr::typedMethod(k,"RefreshCursorLockState","System.Void",{},false),input);
   }else{
    uint8_t visible=s.oldVisible;int32_t mode=s.oldLock;
    if(dr::unboxNumber(dr::call(getVisible),2))dr::call(setVisible,nullptr,{&visible});
    if(dr::unboxNumber(dr::call(getLock))==0)dr::call(setLock,nullptr,{&mode});
   }
  }
  s.mouseHeld=false;s.layerHeld=false;s.mouse=false;s.inputOwner.reset();s.gameOwner.reset();
 }catch(const std::exception&e){setNote(@(e.what()));}
 return NO;
}
NSDictionary *DRNativeObservation(void){auto &s=state();NSUInteger count;{std::lock_guard<std::mutex>lock(s.queueLock);count=s.pending.count;}return @{@"nativeCallback":@(s.bound.load()),@"callbackObserved":@(s.observed.load()),@"frames":@(s.frames.load()),@"inFrame":@(DRInFrame()),@"pending":@(count),@"invalidated":@(s.invalidated.load()),@"nativeNote":note() ?: @""};}
