// SPDX-License-Identifier: GPL-3.0-only
// Explicit development entry point. Never linked into the distributed module.
#import <Foundation/Foundation.h>
#import <os/log.h>
#import <dlfcn.h>
#import "GameProfile.h"
#import "UnityLoop.h"
#include "IL2CPP.hpp"
namespace {
id observer;NSTimer *timer;os_log_t logger;bool initialSnapshot=false;void *trainer;
NSString *token;
NSDictionary *describe(const char *space,const char *name){
    vc::Class type=vc::klass("Pancake.dll",space,name);
    if(!type)return @{@"name":@(name),@"present":@NO};
    NSMutableArray *parents=[NSMutableArray new],*fields=[NSMutableArray new],*methods=[NSMutableArray new];
    for(vc::Class k=type;k && parents.count<16;k=vc::api.parent(k)){
        [parents addObject:@(vc::typeName(vc::api.classType(k)).c_str())];
        void *iterator=nullptr;
        while(vc::Field f=vc::api.fields(k,&iterator)){
            NSMutableDictionary *entry=[@{@"name":@(vc::api.fieldName(f)),@"type":@(vc::typeName(vc::api.fieldType(f)).c_str()),@"flags":@(vc::api.fieldFlags(f)),@"offset":@(vc::api.fieldOffset(f))} mutableCopy];
            if(!strcmp(vc::api.fieldName(f),"_instance") && (vc::api.fieldFlags(f)&0x10)){
                vc::Object instance=nullptr;vc::api.staticRead(f,&instance);
                entry[@"instance"]=@((uintptr_t)instance);
                if(instance)entry[@"instanceType"]=@(vc::typeName(vc::api.classType(vc::api.objectClass(instance))).c_str());
            }
            [fields addObject:entry];
        }
        iterator=nullptr;
        while(vc::Method m=vc::api.methods(k,&iterator)){
            NSMutableArray *parameters=[NSMutableArray new];uint32_t count=vc::api.parameterCount(m);if(count>64)continue;
            for(uint32_t i=0;i<count;i++)[parameters addObject:@(vc::typeName(vc::api.parameterType(m,i)).c_str())];
            [methods addObject:@{@"name":@(vc::api.methodName(m)),@"parameters":parameters,@"return":@(vc::typeName(vc::api.returnType(m)).c_str())}];
        }
    }
    NSMutableDictionary *result=[@{@"name":@(name),@"present":@YES,@"parents":parents,@"fields":fields,@"methods":methods} mutableCopy];
    try{
        auto active=vc::findObjects(type),assets=vc::findObjects(type,true);
        result[@"sceneCount"]=@(active.size());result[@"loadedCount"]=@(assets.size());
    }catch(const std::exception& e){result[@"findError"]=@(e.what());}
    return result;
}
void snapshot(){
    NSMutableArray *classes=[NSMutableArray new];
    for(auto pair:{std::pair{"Nosebleed.Pancake.Models","PlayerModel"},
        {"Nosebleed.Pancake.GameLogic","PlayerStats"},{"Nosebleed.Pancake.GameLogic","SimpleStat"},
        {"Nosebleed.Pancake.MetaProgression","ProgressionData"},{"Nosebleed.SaveLoadSystem.Pancake","SaveLoadManager"},
        {"Nosebleed.Pancake","GameStateManager"},{"Nosebleed.Pancake.Models","EnemyModel"},
        {"Nosebleed.Pancake.Models","GuardianEncounterModel"},{"Nosebleed.Pancake.Models","CardModel"},
        {"Nosebleed.Pancake.InputSystem","InputManager"},{"Util.Variables","LongAsset"},{"Util.Variables","IntAsset"}})
        [classes addObject:describe(pair.first,pair.second)];
    NSDictionary *report=@{@"loop":VCLoopDiagnostics(),@"classes":classes};
    NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:@"/private/tmp/mht-vampire-crawlers/NativeSnapshot.json" atomically:YES];
    os_log(logger,"Native class snapshot written; classes=%lu",(unsigned long)classes.count);
}
}
__attribute__((constructor)) static void beginProbe(){@autoreleasepool{
    if(strcmp(getenv("MHT_VC_DEVELOPMENT") ?: "","1"))return;
    NSString *config=getenv("MHT_CONFIG") ? @(getenv("MHT_CONFIG")) : nil;
    NSDictionary *root=MTLoadConfiguration(config,nil),*profile=MTFindProfile(root,@"steam-arm64-1.6.1");
    NSString *target=getenv("MHT_TARGET") ? @(getenv("MHT_TARGET")) : nil;
    if(!MTCurrentProcessMatches(profile,target) || !MTInspectGame(NSBundle.mainBundle.bundlePath,profile,nil))return;
    token=getenv("MHT_SESSION") ? @(getenv("MHT_SESSION")) : nil;if(!token.length)return;
    logger=os_log_create("local.mht.vampire-crawlers","development");
    dispatch_async(dispatch_get_main_queue(),^{
        timer=[NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t){
            (void)t;VCEnsureLoop();
            if(!initialSnapshot && [VCLoopDiagnostics()[@"frames"] unsignedLongLongValue]>0){initialSnapshot=true;VCEnqueue(^{try{snapshot();}catch(const std::exception& e){os_log_error(logger,"Read-only snapshot rejected: %{public}s",e.what());}});}
        }];
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
        observer=[NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.mht.vampire-crawlers.development" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
            if(![event.object isKindOfClass:NSString.class] || [event.object length]>4096)return;
            id request=[NSJSONSerialization JSONObjectWithData:[event.object dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if(![request isKindOfClass:NSDictionary.class] || ![request[@"token"] isEqual:token])return;
            if([request[@"action"] isEqual:@"inspect"]){VCEnqueue(^{try{snapshot();}catch(const std::exception& e){os_log_error(logger,"Read-only snapshot rejected: %{public}s",e.what());}});return;}
            if([request[@"action"] isEqual:@"load-trainer"] && !trainer){
                // The final candidate is built once after this read-only binding
                // check, then loaded into the same game process without a restart.
                trainer=dlopen("/private/tmp/mht-vampire-crawlers/Trainer.dylib",RTLD_NOW|RTLD_LOCAL);
                os_log(logger,"Trainer candidate loaded=%d reason=%{public}s",trainer!=nullptr,trainer ? "none" : (dlerror() ?: "unknown"));
            }
        }];
    });
}}
