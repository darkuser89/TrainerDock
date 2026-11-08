// SPDX-License-Identifier: GPL-3.0-only
// Session-bound development probe; never linked into the product.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
extern "C" {
#import "GameProfile.h"
}
#import "UnityLoop.h"
#include "IL2CPP.hpp"
namespace {
NSString *token; id observer; NSTimer *timer; bool first=false; void *candidate;
NSDictionary *describe(const char *name){
 using namespace tld; tld::Class k=klass("Assembly-CSharp.dll","",name); if(!k)return @{@"name":@(name),@"missing":@YES};
 NSMutableArray *fields=[NSMutableArray new],*methods=[NSMutableArray new];
 for(tld::Class c=k;c;c=api.parent(c)){
  void *it=nullptr;
  while(Field f=api.fields(c,&it)){
   tld::Class t=api.typeClass(api.fieldType(f));uint32_t a=0;
   [fields addObject:@{@"name":@(api.fieldName(f)),@"type":@(typeName(api.fieldType(f)).c_str()),@"flags":@(api.fieldFlags(f)),@"offset":@(api.fieldOffset(f)),@"size":@(t && api.valueType(t) ? api.valueSize(t,&a) : 8)}];
  }
  if(c!=k)break;
  it=nullptr;while(Method m=api.methods(c,&it)){
   NSMutableArray *args=[NSMutableArray new]; for(uint32_t i=0;i<api.parameterCount(m);i++)[args addObject:@(typeName(api.parameterType(m,i)).c_str())];
   uint32_t impl=0;[methods addObject:@{@"name":@(api.methodName(m)),@"args":args,@"returns":@(typeName(api.returnType(m)).c_str()),@"flags":@(api.methodFlags(m,&impl))}];
  }
 }
 return @{@"name":@(name),@"fields":fields,@"methods":methods};
}
void report(NSString *action){
 NSMutableDictionary *result=[@{@"loop":TLDLoopDiagnostics(),@"action":action} mutableCopy];
 try{
  if([action isEqual:@"inspect"]){
   NSMutableArray *classes=[NSMutableArray new];
   for(const char *name:{"GameManager","PlayerManager","PlayerMovement","Condition","Encumber","Fatigue","Freezing","Hunger","Thirst","Infection","InfectionRisk","SprainedAnkle","SprainedWrist","SprainPain","TimeOfDay","Weather","WeatherSet","WeatherStage","UniStormWeatherSystem","GearItem","GunItem","Inventory","Panel_Crafting","BlueprintItem","BlueprintData","SkillsManager","PlayerSkills","Skill","BaseAi","SpawnRegion","AuroraManager","vp_FPSController","vp_FPSPlayer","InputManager","GameModeConfig","ExperienceModeManager","uConsole","ConsoleManager","SaveGameSystem"})[classes addObject:describe(name)];
   result[@"classes"]=classes;
  }else if([action isEqual:@"load"]){
   if(!candidate)candidate=dlopen("/private/tmp/trainerdock-the-long-dark/Trainer.dylib",RTLD_NOW|RTLD_LOCAL);
   result[@"loaded"]=@(candidate!=nullptr); if(!candidate)result[@"error"]=@(dlerror() ?: "unknown");
  }else if(candidate){
   auto query=(NSDictionary *(*)(NSString *))dlsym(candidate,"TLDTestQuery");
   if(query)result[@"result"]=query(action);
  }
 }catch(const std::exception& e){result[@"error"]=@(e.what());}
 NSData *data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
 [data writeToFile:@"/private/tmp/trainerdock-the-long-dark/Reply.json" atomically:YES];
}
}
__attribute__((constructor)) static void begin(){
 // Foundation/bundle identity must be resolved after dyld initialization.
 dispatch_async(dispatch_get_main_queue(),^{@autoreleasepool{
  if(strcmp(getenv("MHT_TLD_DEVELOPMENT") ?: "","1"))return;
  token=getenv("MHT_SESSION") ? @(getenv("MHT_SESSION")) : nil;if(!token.length)return;
  NSDictionary *config=MTLoadConfiguration(@(getenv("MHT_CONFIG")),nil),*profile=MTFindProfile(config,@"steam-arm64-2.60");
  if(!MTCurrentProcessMatches(profile,@(getenv("MHT_TARGET"))) || !MTInspectGame(NSBundle.mainBundle.bundlePath,profile,nil))return;
  observer=[NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.trainerdock.the-long-dark.probe" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){
   if(![n.object isKindOfClass:NSString.class] || [n.object length]>4096)return;
   NSDictionary *r=[NSJSONSerialization JSONObjectWithData:[n.object dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
   if(![r isKindOfClass:NSDictionary.class] || ![r[@"token"] isEqual:token] || ![r[@"action"] isKindOfClass:NSString.class])return;
   TLDEnqueue(^{report(r[@"action"]);});
  }];
  timer=[NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t){(void)t;TLDEnsureLoop();if(!first && [TLDLoopDiagnostics()[@"frames"] unsignedLongLongValue]){first=true;TLDEnqueue(^{report(@"inspect");});}}];
 }});
}
