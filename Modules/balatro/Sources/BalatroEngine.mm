// SPDX-License-Identifier: GPL-3.0-only
#import "BalatroEngine.h"
#import "BalatroScript.h"
#import "TrainerFeatures.h"
#import <dlfcn.h>
#import <os/lock.h>
#import <os/log.h>
#import <pthread.h>
#include <cmath>
#include <cstring>

// The shipped LuaJIT exports the Lua 5.1 C ABI. Bind only the original loaded image.
struct BAAPI {
 int (*gettop)(lua_State *); void (*settop)(lua_State *,int);
 int (*type)(lua_State *,int); const char *(*tolstring)(lua_State *,int,size_t *);
 double (*tonumber)(lua_State *,int); int (*toboolean)(lua_State *,int);
 void (*getfield)(lua_State *,int,const char *); void (*rawgeti)(lua_State *,int,int);
 void (*pushnumber)(lua_State *,double); void (*pushboolean)(lua_State *,int);
 void (*pushcclosure)(lua_State *,int (*)(lua_State *),int);
 int (*pcall)(lua_State *,int,int,int); int (*loadbuffer)(lua_State *,const char *,size_t,const char *);
 int (*ref)(lua_State *,int);
} static api;
static constexpr int Registry=-10000,Globals=-10002,Table=5,Function=6;
static BOOL enabled,installed;
static int controller=-1;
static lua_State *installedState;
static thread_local lua_State *frameState;
static thread_local BOOL observing;
static os_unfair_lock pendingLock=OS_UNFAIR_LOCK_INIT;
static NSMutableArray<dispatch_block_t> *pending;
static uint64_t frames;
static BOOL (^inputHandler)(NSInteger,double,double,NSString *,NSUInteger);
void BASetInputHandler(BOOL (^handler)(NSInteger,double,double,NSString *,NSUInteger)){inputHandler=[handler copy];}
static pthread_t engineThread;
static void initialize(void) {
 static dispatch_once_t once;dispatch_once(&once,^{pending=[NSMutableArray new];});
}
void BAEnable(void){initialize();enabled=YES;}
void BAEnqueue(dispatch_block_t work) {
 if(!work)return;initialize();os_unfair_lock_lock(&pendingLock);
 if(pending.count<64)[pending addObject:[work copy]];
 os_unfair_lock_unlock(&pendingLock);
}
static int tick(lua_State *L) {
 @autoreleasepool {
  if(!installed || !pthread_equal(engineThread,pthread_self()))return 0;
  frameState=L;frames++;
  os_unfair_lock_lock(&pendingLock);NSArray<dispatch_block_t> *jobs=nil;if(pending.count){jobs=pending.copy;[pending removeAllObjects];}os_unfair_lock_unlock(&pendingLock);
  for(dispatch_block_t job in jobs)job();
  frameState=NULL;
 }
 return 0;
}
static int input(lua_State *L){
 BOOL handled=NO;
 if(inputHandler && NSThread.isMainThread){const char *key=api.tolstring(L,4,NULL);handled=inputHandler((NSInteger)api.tonumber(L,1),api.tonumber(L,2),api.tonumber(L,3),key ? [NSString stringWithUTF8String:key] : @"",(NSUInteger)api.tonumber(L,5));}
 api.pushboolean(L,handled);return 1;
}
static BOOL bindAPI(void) {
 NSString *image=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/Frameworks/Lua.framework/Versions/A/Lua"];
 void *handle=dlopen(image.fileSystemRepresentation,RTLD_NOW|RTLD_NOLOAD);if(!handle)return NO;
 #define BIND(member,symbol) api.member=(decltype(api.member))dlsym(handle,symbol);if(!api.member){dlclose(handle);return NO;}
 BIND(gettop,"lua_gettop") BIND(settop,"lua_settop") BIND(type,"lua_type") BIND(tolstring,"lua_tolstring")
 BIND(tonumber,"lua_tonumber") BIND(toboolean,"lua_toboolean") BIND(getfield,"lua_getfield") BIND(rawgeti,"lua_rawgeti")
 BIND(pushnumber,"lua_pushnumber") BIND(pushboolean,"lua_pushboolean") BIND(pushcclosure,"lua_pushcclosure")
 BIND(pcall,"lua_pcall") BIND(loadbuffer,"luaL_loadbuffer") BIND(ref,"luaL_ref")
 #undef BIND
 dlclose(handle);return YES;
}
void BAObserveLua(lua_State *L) {
 if(!enabled || installed || observing || !L)return;
 observing=YES;
 @autoreleasepool {
  if(bindAPI()){
   int base=api.gettop(L);
   api.getfield(L,Globals,"G");
   if(api.type(L,-1)==Table){
    api.getfield(L,-1,"VERSION");const char *version=api.tolstring(L,-1,NULL);
    BOOL matches=version && !strcmp(version,"1.0.1o-FULL");api.settop(L,base);
    if(matches && !api.loadbuffer(L,BAScript,sizeof(BAScript)-1,"@MHT/balatro.lua")){
     api.pushcclosure(L,tick,0);api.pushcclosure(L,input,0);
     int result=api.pcall(L,2,1,0);
     if(!result && api.type(L,-1)==Table){
      controller=api.ref(L,Registry);installedState=L;engineThread=pthread_self();installed=YES;
      os_log(OS_LOG_DEFAULT,"TrainerDock Balatro: Lua update and scoring callbacks installed on engine thread");
     }else if(result)os_log_error(OS_LOG_DEFAULT,"TrainerDock Balatro: bootstrap rejected: %{public}s",api.tolstring(L,-1,NULL) ?: "unknown");
    }
   }
   api.settop(L,base);
  }
 }
 observing=NO;
}
void BAForgetLua(lua_State *L) {
 if(L==installedState){installed=NO;installedState=NULL;controller=-1;frameState=NULL;}
}
static NSString *luaString(lua_State *L,int index) {
 size_t length=0;const char *s=api.tolstring(L,index,&length);
 return s && length<=4096 ? [[NSString alloc]initWithBytes:s length:length encoding:NSUTF8StringEncoding] : nil;
}
static id invoke(const char *name,NSInteger feature,BOOL wanted,double value,int argc,BOOL dictionary) {
 lua_State *L=frameState;
 if(!L || !installed || !pthread_equal(engineThread,pthread_self()))return nil;
 int base=api.gettop(L);id result=nil;
 api.rawgeti(L,Registry,controller);api.getfield(L,-1,name);
 if(api.type(L,-1)==Function){
  if(argc>0)api.pushnumber(L,(double)feature);
  if(argc==3)api.pushboolean(L,wanted);
  if(argc>1)api.pushnumber(L,value);
  if(!api.pcall(L,argc,1,0)){
   if(dictionary && api.type(L,-1)==Table){
    NSMutableDictionary *d=[NSMutableDictionary new];
    for(NSString *key in @[@"kind",@"identity",@"note",@"available",@"active",@"money",@"chips",@"hands",@"discards",@"lastScore",@"pendingScore",@"inputDt",@"outputDt"]){
     api.getfield(L,-1,key.UTF8String);int type=api.type(L,-1);id v=nil;
     if(type==1)v=@(api.toboolean(L,-1)!=0);
     else if(type==3 && std::isfinite(api.tonumber(L,-1)))v=@(api.tonumber(L,-1));
     else if(type==4)v=luaString(L,-1);
     if(v)d[key]=v;api.settop(L,api.gettop(L)-1);
    }
    d[@"frames"]=@(frames);result=d;
   }else if(!dictionary)result=luaString(L,-1);
  }else os_log_error(OS_LOG_DEFAULT,"TrainerDock Balatro: native Lua command rejected: %{public}s",api.tolstring(L,-1,NULL) ?: "unknown");
 }
 api.settop(L,base);return result;
}
NSDictionary *BAInspect(void){return invoke("inspect",0,NO,0,0,YES) ?: @{@"kind":@0,@"identity":@"no-engine-frame",@"note":@"Keine bestätigte Lua-GameThread-Zustellung."};}
NSDictionary *BAEffect(NSInteger feature,BOOL wanted,double value){return invoke("effect",feature,wanted,value,3,YES) ?: @{@"available":@NO,@"active":@NO,@"note":@"Außerhalb des Spielupdates gesperrt."};}
NSString *BAOneShot(NSInteger feature,double value){return invoke("once",feature,NO,value,2,NO) ?: @"Keine native Bestätigung; Aktion nicht ausgeführt.";}
void BARelease(void){(void)invoke("release",0,NO,0,0,NO);}
BOOL BAMouse(BOOL wanted){return [invoke("mouse",0,wanted,0,3,YES)[@"active"] boolValue];}
