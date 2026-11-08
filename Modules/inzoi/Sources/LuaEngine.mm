// SPDX-License-Identifier: GPL-3.0-only
#import "LuaEngine.hpp"
#import <AppKit/AppKit.h>
#import "RuntimeMod.h"
#import "MissionData.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach_vm.h>
#import <dlfcn.h>
#import <objc/message.h>
#include <atomic>
#include <mutex>
#include <deque>
#include <map>
#include <set>
#include <stdexcept>
#include <cmath>
#include <cstring>
#include <string>
#include <pthread.h>
struct lua_State;
using LuaFunction=int(*)(lua_State *);
using LuaContinuation=int(*)(lua_State *,int,intptr_t);
extern "C" int lua_pcallk(lua_State *,int,int,int,intptr_t,LuaContinuation) __attribute__((weak_import));
extern "C" void lua_close(lua_State *) __attribute__((weak_import));
namespace {
struct API {
 int(*gettop)(lua_State *);void(*settop)(lua_State *,int);
 int(*getglobal)(lua_State *,const char *);int(*getfield)(lua_State *,int,const char *);
 int(*type)(lua_State *,int);const char *(*tolstring)(lua_State *,int,size_t *);
 double(*tonumberx)(lua_State *,int,int *);long long(*tointegerx)(lua_State *,int,int *);
 int(*toboolean)(lua_State *,int);LuaFunction(*tocfunction)(lua_State *,int);
 const char *(*getupvalue)(lua_State *,int,int);const void *(*topointer)(lua_State *,int);
 void(*pushnil)(lua_State *);void(*pushboolean)(lua_State *,int);void(*pushnumber)(lua_State *,double);
 const char *(*pushlstring)(lua_State *,const char *,size_t);void(*createtable)(lua_State *,int,int);
 void(*setfield)(lua_State *,int,const char *);void(*rawseti)(lua_State *,int,long long);
 int(*rawgeti)(lua_State *,int,long long);int(*next)(lua_State *,int);
 int(*loadbuffer)(lua_State *,const char *,size_t,const char *,const char *);
 int(*reference)(lua_State *,int);void(*unreference)(lua_State *,int,int);
} api{};
std::atomic<bool> enabled{false};std::mutex pendingMutex;
std::deque<dispatch_block_t> pending;
thread_local lua_State *current=nullptr;thread_local bool inside=false;thread_local unsigned protectedDepth=0;
thread_local unsigned currentEnvironment=0;
std::atomic<lua_State *> presentation{nullptr};
std::atomic<uint64_t> presentationThread{0};
void(*gameThreadCall)(dispatch_block_t,bool,NSArray *)=nullptr;
struct State {int reference=-2;uint64_t thread=0;};
std::map<lua_State *,State> states;
std::mutex statesMutex;
uintptr_t originalPrint=0;
#ifdef IZ_PRIVATE_PROBE
std::atomic<uint64_t> observedCalls{0},observedB2{0};std::mutex diagnosticMutex;std::set<std::string> observedTags;
#endif

bool copy(uintptr_t p,void *out,size_t n){mach_vm_size_t got=0;return p>4096&&n<=1048576&&mach_vm_read_overwrite(mach_task_self(),p,n,(mach_vm_address_t)out,&got)==KERN_SUCCESS&&got==n;}
[[noreturn]]void reject(const char *s){throw std::runtime_error(s);}
NSString *errorText(lua_State *L){size_t n=0;const char *s=api.tolstring(L,-1,&n);return s&&n<=65536?[[NSString alloc]initWithBytes:s length:n encoding:NSUTF8StringEncoding]:@"Fehler in der nativen Spielanbindung.";}
void require(){if(!current||!enabled.load())reject("Der originale Simulationsthread ist nicht verfügbar.");}
int absolute(lua_State *L,int index){return index<0?api.gettop(L)+index+1:index;}
id value(lua_State *L,int index,int depth,std::set<const void *> &seen){
 if(depth>12)reject("Die Rückmeldung des Spiels ist zu tief verschachtelt.");
 switch(api.type(L,index)){
 case 0:return NSNull.null;
 case 1:return @(api.toboolean(L,index)!=0);
 case 3:{int ok=0;double d=api.tonumberx(L,index,&ok);if(!ok||!std::isfinite(d))return NSNull.null;return @(d);}
 case 4:{size_t n=0;const char *s=api.tolstring(L,index,&n);if(!s||n>2097152)reject("Der ursprüngliche Text überschreitet die Grenze.");return [[NSString alloc]initWithBytes:s length:n encoding:NSUTF8StringEncoding] ?: @"";}
 case 5:{int at=absolute(L,index);const void *identity=api.topointer(L,at);if(!seen.insert(identity).second)reject("Zyklische Spielrückmeldung.");NSMutableDictionary *d=[NSMutableDictionary new];NSMutableDictionary<NSNumber *,id> *array=[NSMutableDictionary new];bool sequential=true;size_t count=0;api.pushnil(L);
  while(api.next(L,at)){if(++count>2048)reject("Zu viele Einträge in der Spielrückmeldung.");int kind=api.type(L,-2);id key=nil;if(kind==4){size_t n=0;const char *s=api.tolstring(L,-2,&n);if(n>1024)reject("Zu langer Feldname.");key=[[NSString alloc]initWithBytes:s length:n encoding:NSUTF8StringEncoding];sequential=false;}else if(kind==3){int ok=0;long long n=api.tointegerx(L,-2,&ok);if(!ok||n<1||n>2048)sequential=false;key=[NSString stringWithFormat:@"%lld",n];if(ok&&n>=1&&n<=2048)array[@(n)]=value(L,-1,depth+1,seen);}else reject("Nicht serialisierbarer Feldschlüssel.");
   if(key)d[key]=value(L,-1,depth+1,seen);api.settop(L,api.gettop(L)-1);
  }seen.erase(identity);if(sequential&&count){NSMutableArray *a=[NSMutableArray new];for(NSUInteger i=1;i<=count;i++){id v=array[@(i)];if(!v)return d;[a addObject:v];}return a;}return d;
 }
 default:reject("Die native Rückmeldung enthält keinen unterstützten Wert.");
 }
}
id take(lua_State *L){std::set<const void *> seen;return value(L,-1,0,seen);}
void push(lua_State *L,id object,int depth=0){
 if(depth>8)reject("Zu tiefer Trainerauftrag.");
 if(!object||object==NSNull.null){api.pushnil(L);return;}
 if([object isKindOfClass:NSString.class]){NSData *d=[object dataUsingEncoding:NSUTF8StringEncoding];api.pushlstring(L,(const char *)d.bytes,d.length);return;}
 if([object isKindOfClass:NSNumber.class]){if(CFGetTypeID((__bridge CFTypeRef)object)==CFBooleanGetTypeID())api.pushboolean(L,[object boolValue]);else api.pushnumber(L,[object doubleValue]);return;}
 if([object isKindOfClass:NSArray.class]){api.createtable(L,(int)[object count],0);NSUInteger i=0;for(id v in object){push(L,v,depth+1);api.rawseti(L,-2,(long long)++i);}return;}
 if([object isKindOfClass:NSDictionary.class]){api.createtable(L,0,(int)[object count]);for(NSString *k in object){if(![k isKindOfClass:NSString.class])reject("Ungültiger Trainerauftrag.");push(L,object[k],depth+1);api.setfield(L,-2,k.UTF8String);}return;}
 reject("Nicht unterstützter Trainerauftrag.");
}
unsigned originalEnvironment(lua_State *L){
 int top=api.gettop(L);unsigned environment=0;
 api.getglobal(L,"print");if((uintptr_t)api.tocfunction(L,-1)==originalPrint&&api.getupvalue(L,-1,1)){
  size_t n=0;const char *s=api.tolstring(L,-1,&n);if(s&&n==2&&s[0]=='B'&&(s[1]=='1'||s[1]=='2'))environment=(unsigned)(s[1]-'0');
#ifdef IZ_PRIVATE_PROBE
 if(s&&n<64){std::lock_guard<std::mutex> lock(diagnosticMutex);observedTags.insert(std::string(s,n));}
#endif
 }api.settop(L,top);return environment;
}
void program(lua_State *L){
 uint64_t tid=0;pthread_threadid_np(nullptr,&tid);auto it=states.find(L);
 if(it!=states.end()&&it->second.thread!=tid)reject("Der Besitzerthread der Simulation hat gewechselt.");
 states[L]={-2,tid};api.getglobal(L,"__TrainerDockInZOI");
 if(api.type(L,-1)!=5)reject("Der native Trainer ist noch nicht geladen.");
}
static int observePCall(lua_State *L,int nargs,int nresults,int errfunc,intptr_t ctx,LuaContinuation continuation){
 protectedDepth++;int result=lua_pcallk(L,nargs,nresults,errfunc,ctx,continuation);protectedDepth--;
 if(result||protectedDepth||inside||!enabled.load(std::memory_order_acquire))return result;
 inside=true;
#ifdef IZ_PRIVATE_PROBE
 observedCalls++;
#endif
 @autoreleasepool { @try {try{
  unsigned environment=originalEnvironment(L);
  if(environment==1){uint64_t tid=0;pthread_threadid_np(nullptr,&tid);presentationThread.store(tid);presentation.store(L,std::memory_order_release);}
  if(environment==2){
#ifdef IZ_PRIVATE_PROBE
 observedB2++;
#endif
   current=L;currentEnvironment=2;
   std::deque<dispatch_block_t> work;{std::lock_guard<std::mutex> lock(pendingMutex);work.swap(pending);}
   for(auto &block:work)block();
   current=nullptr;currentEnvironment=0;
  }
 }catch(const std::exception &){current=nullptr;currentEnvironment=0;}}@catch(NSException *){current=nullptr;currentEnvironment=0;}}
 inside=false;return result;
}
static void observeClose(lua_State *L){
 // No Lua API calls on a VM after close; a reused address starts a fresh lease.
 lua_State *expected=L;presentation.compare_exchange_strong(expected,nullptr);
 {std::lock_guard<std::mutex> lock(statesMutex);states.erase(L);}lua_close(L);
}
}
void IZEnableLuaEngine(){
 if(enabled.load()||!lua_pcallk||!lua_close)return;
 const mach_header_64 *h=nullptr;uint32_t image=0;
 for(uint32_t i=0;i<_dyld_image_count();i++){auto q=(const mach_header_64 *)_dyld_get_image_header(i);if(q&&q->magic==MH_MAGIC_64&&q->filetype==MH_EXECUTE){h=q;image=i;break;}}
 if(!h||h->cputype!=CPU_TYPE_ARM64||h->sizeofcmds>1048576||h->ncmds>4096)return;
 bool exact=false;const uint8_t *p=(const uint8_t *)(h+1),*end=p+h->sizeofcmds;
 for(uint32_t i=0;i<h->ncmds;i++){if(p+sizeof(load_command)>end)return;auto c=(const load_command *)p;if(c->cmdsize<sizeof(*c)||c->cmdsize>(size_t)(end-p))return;if(c->cmd==LC_UUID&&c->cmdsize==sizeof(uuid_command))exact=[[[NSUUID alloc]initWithUUIDBytes:((const uuid_command *)c)->uuid].UUIDString isEqual:@"B1AA1CC2-C72B-3D8A-AC90-1E8C9155E519"];p+=c->cmdsize;}
 if(!exact)return;originalPrint=0x106175824+_dyld_get_image_vmaddr_slide(image);
 uint8_t bytes[16],expected[]={0xf8,0x5f,0xbc,0xa9,0xf6,0x57,0x01,0xa9,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9};
 if(!copy(originalPrint,bytes,16)||memcmp(bytes,expected,16))return;
 uintptr_t dispatchAddress=0x100e38370+_dyld_get_image_vmaddr_slide(image);
 if(!copy(dispatchAddress,bytes,16)||memcmp(bytes,expected,16))return;
 gameThreadCall=(decltype(gameThreadCall))dispatchAddress;
 NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/MacOS/libLua.dylib"];
 void *library=dlopen(path.fileSystemRepresentation,RTLD_LAZY|RTLD_NOLOAD);if(!library)return;
 #define BIND(field,name) api.field=(decltype(api.field))dlsym(library,name);if(!api.field)return;
 BIND(gettop,"lua_gettop") BIND(settop,"lua_settop") BIND(getglobal,"lua_getglobal") BIND(getfield,"lua_getfield") BIND(type,"lua_type") BIND(tolstring,"lua_tolstring") BIND(tonumberx,"lua_tonumberx") BIND(tointegerx,"lua_tointegerx") BIND(toboolean,"lua_toboolean") BIND(tocfunction,"lua_tocfunction") BIND(getupvalue,"lua_getupvalue") BIND(topointer,"lua_topointer") BIND(pushnil,"lua_pushnil") BIND(pushboolean,"lua_pushboolean") BIND(pushnumber,"lua_pushnumber") BIND(pushlstring,"lua_pushlstring") BIND(createtable,"lua_createtable") BIND(setfield,"lua_setfield") BIND(rawseti,"lua_rawseti") BIND(rawgeti,"lua_rawgeti") BIND(next,"lua_next") BIND(loadbuffer,"luaL_loadbufferx") BIND(reference,"luaL_ref") BIND(unreference,"luaL_unref")
 #undef BIND
 enabled.store(true,std::memory_order_release);IZStartRuntimeMod();
}
void IZOnSimulationThread(dispatch_block_t work){if(!work)return;if(current&&currentEnvironment==2){work();return;}std::lock_guard<std::mutex> lock(pendingMutex);if(pending.size()<128)pending.push_back([work copy]);}
void IZOnPresentationThread(dispatch_block_t work){
 if(!work)return;
 if(current&&currentEnvironment==1){work();return;}
 if(!gameThreadCall){work();return;}
 gameThreadCall(^{@autoreleasepool{
  lua_State *previous=current;unsigned previousEnvironment=currentEnvironment;bool wasInside=inside;
  uint64_t tid=0;pthread_threadid_np(nullptr,&tid);SEL selector=NSSelectorFromString(@"isGameThread");
  lua_State *L=presentation.load(std::memory_order_acquire);
  bool owns=[NSThread respondsToSelector:selector]&&((BOOL(*)(id,SEL))objc_msgSend)(NSThread.class,selector)&&tid==presentationThread.load();
  current=owns?L:nullptr;currentEnvironment=owns&&L?1:0;inside=true;
  @try{work();}@finally{current=previous;currentEnvironment=previousEnvironment;inside=wasInside;}
 }},false,@[NSDefaultRunLoopMode,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode]);
}
bool IZIsSimulationThread(){return current!=nullptr&&currentEnvironment==2;}
id IZCall(NSString *method,NSArray *arguments){
 require();if(currentEnvironment!=2)reject("Der originale Simulationsthread ist nicht verfügbar.");lua_State *L=current;int top=api.gettop(L);
 if([method isEqual:@"missionDefinition"]){if(arguments.count!=1)reject("Ungültiger Missionsauftrag.");return IZMissionDefinition(arguments.firstObject);}
 try{std::lock_guard<std::mutex> lock(statesMutex);program(L);api.getfield(L,-1,method.UTF8String);if(api.type(L,-1)!=6)reject("Die angeforderte Trainerfunktion fehlt.");for(id a in arguments)push(L,a);if(lua_pcallk(L,(int)arguments.count,1,0,0,nullptr))throw std::runtime_error(errorText(L).UTF8String);id r=take(L);api.settop(L,top);return r;}
 catch(...){api.settop(L,top);throw;}
}
id IZPresentationCommand(NSString *command){
 require();if(currentEnvironment!=1)reject("Der originale Darstellungsthread ist nicht verfügbar.");
 lua_State *L=current;int top=api.gettop(L);
 static const char script[]="local command=...;local ok,message,data=inzoi.cli.execute(command);return {ok=ok,data=data}";
 try{
  if(api.loadbuffer(L,script,sizeof(script)-1,"TrainerDock/presentation","t"))throw std::runtime_error(errorText(L).UTF8String);
  push(L,command);
  if(lua_pcallk(L,1,1,0,0,nullptr))throw std::runtime_error(errorText(L).UTF8String);
  id result=take(L);api.settop(L,top);return result;
 }catch(...){api.settop(L,top);throw;}
}
#ifdef IZ_PRIVATE_PROBE
NSDictionary *IZTestEngineStatus(){NSMutableArray *tags=[NSMutableArray new];{std::lock_guard<std::mutex> lock(diagnosticMutex);for(const auto &tag:observedTags)[tags addObject:@(tag.c_str())];}size_t n=0;{std::lock_guard<std::mutex> lock(pendingMutex);n=pending.size();}return @{@"enabled":@(enabled.load()),@"calls":@(observedCalls.load()),@"b2":@(observedB2.load()),@"tags":tags,@"pending":@(n)};}
id IZTestEvaluate(NSString *script){require();lua_State *L=current;int top=api.gettop(L);try{NSData *d=[script dataUsingEncoding:NSUTF8StringEncoding];if(!d.length||d.length>524288)reject("Diagnostic script exceeds bound");if(api.loadbuffer(L,(const char *)d.bytes,d.length,"TrainerDock/private-test","t")||lua_pcallk(L,0,1,0,0,nullptr))throw std::runtime_error(errorText(L).UTF8String);id r=take(L);api.settop(L,top);return r;}catch(...){api.settop(L,top);throw;}}
#endif
__attribute__((used,section("__DATA,__interpose")))static const struct {const void *replacement,*original;} luaInterpositions[]={
 {(const void *)observePCall,(const void *)lua_pcallk},{(const void *)observeClose,(const void *)lua_close}
};
