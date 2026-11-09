// SPDX-License-Identifier: GPL-3.0-only
// Explicit, session-bound development observations. Never a product source.
#import <Foundation/Foundation.h>
#import <unistd.h>
extern "C" {
#import "GameProfile.h"
}
#import "ProdeusEffects.h"
#import "ProdeusLoop.h"
#include "ProdeusEngine.hpp"
#include <cmath>
#include <cstring>

namespace {
NSString *session;
id observer;
NSMutableOrderedSet<NSString *> *seen;
NSString *const requestName=@"local.trainerdock.prodeus.probe.request";
NSString *const responseName=@"local.trainerdock.prodeus.probe.response";

bool boundedInteger(id value,int minimum,int maximum,int& result){
    if(![value isKindOfClass:NSNumber.class])return false;
    double number=[value doubleValue];
    if(!std::isfinite(number) || std::floor(number)!=number || number<minimum || number>maximum)return false;
    result=(int)number;return true;
}
prodeus::Object player(){
    using namespace prodeus;
    prodeus::Class type=klass("Assembly-CSharp.dll","","PlayerEntity");
    Field instance=field(type,"instance");
    if(!instance || !(api.fieldFlags(instance)&0x10))throw std::runtime_error("Originaler Spielerbesitzer fehlt.");
    Object value=nullptr;api.staticRead(instance,&value);
    if(!value || !alive(value))throw std::runtime_error("Kein lebender ursprünglicher Spielerbesitzer.");
    return value;
}
void setPlayerValue(prodeus::Object owner,const char *setter,int value){
    using namespace prodeus;
    Method original=method(api.objectClass(owner),setter,1);
    uint32_t implementation=0;
    if(!original || (api.methodFlags(original,&implementation)&0x10)
       || typeName(api.parameterType(original,0))!="System.Int32"
       || typeName(api.returnType(original))!="System.Void")
        throw std::runtime_error("Originaler Spielersetzer hat eine andere Signatur.");
    numericCall(original,owner,{(double)value});
}
NSDictionary *execute(NSDictionary *request){
    if(!PRInFrame())return @{ @"error":@"Kein originaler Unity-Spielrückruf." };
    if([request[@"deadline"] doubleValue]<NSDate.date.timeIntervalSince1970)
        return @{ @"error":@"Prüfauftrag ist abgelaufen." };
    try{
        NSString *action=request[@"action"];
        NSDictionary *before=PRValues();
        if([action isEqual:@"values"])
            return @{ @"values":before,@"engineCallback":@YES };
        if(![action isEqual:@"set-player"])
            return @{ @"error":@"Unbekannter Prüfauftrag." };
        int health=0,armor=0;
        if(!boundedInteger(request[@"health"],1,200,health) || !boundedInteger(request[@"armor"],0,200,armor))
            return @{ @"error":@"Gesundheit 1–200 und Rüstung 0–200 als ganze Zahlen angeben." };
        // Re-evaluate the real product's GameInfo/local-owner checks on this
        // original frame immediately before any original setter is called.
        NSDictionary *context=PRInspect();
        if([context[@"kind"] integerValue]!=2 || [before[@"kind"] integerValue]!=2
           || ![context[@"identity"] isEqual:before[@"identity"]])
            return @{ @"error":@"Prüfänderungen sind nur im bestätigten lokalen Einzelspieler erlaubt.",@"values":before };
        prodeus::Root owner(player());
        setPlayerValue(owner.get(),"SetHealth",health);
        setPlayerValue(owner.get(),"SetArmor",armor);
        return @{ @"before":before,@"values":PRValues(),@"engineCallback":@YES };
    }catch(const std::exception& error){return @{ @"error":@(error.what()),@"engineCallback":@YES };}
}
void reply(NSDictionary *request,NSDictionary *result){
    NSMutableDictionary *response=[result mutableCopy];
    response[@"session"]=session;response[@"pid"]=@(getpid());response[@"requestID"]=request[@"requestID"];
    NSData *data=[NSJSONSerialization dataWithJSONObject:response options:0 error:NULL];
    if(!data || data.length>65536)return;
    NSString *payload=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(),^{
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:responseName object:payload userInfo:nil deliverImmediately:YES];
    });
}
}

__attribute__((constructor)) static void startProdeusProbe(){@autoreleasepool{
    if(strcmp(getenv("MHT_PRODEUS_DEVELOPMENT") ?: "","1"))return;
    dispatch_async(dispatch_get_main_queue(),^{
        NSDictionary *environment=NSProcessInfo.processInfo.environment;
        session=environment[@"MHT_SESSION"];
        if(session.length<16 || session.length>256)return;
        NSDictionary *configuration=MTLoadConfiguration(environment[@"MHT_CONFIG"],NULL);
        NSDictionary *profile=MTFindProfile(configuration,environment[@"MHT_PROFILE"]);
        if(!MTCurrentProcessMatches(profile,environment[@"MHT_TARGET"]))return;
        seen=[NSMutableOrderedSet new];
        observer=[NSDistributedNotificationCenter.defaultCenter addObserverForName:requestName object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
            if(![event.object isKindOfClass:NSString.class] || [event.object length]>4096)return;
            NSData *data=[event.object dataUsingEncoding:NSUTF8StringEncoding];
            id parsed=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if(![parsed isKindOfClass:NSDictionary.class])return;
            NSDictionary *request=parsed;
            NSString *identifier=request[@"requestID"],*action=request[@"action"];
            NSNumber *process=request[@"pid"],*deadline=request[@"deadline"];
            if(![request[@"session"] isEqual:session] || ![process isKindOfClass:NSNumber.class] || process.intValue!=getpid()
               || ![identifier isKindOfClass:NSString.class] || ![[NSUUID alloc]initWithUUIDString:identifier]
               || ![action isKindOfClass:NSString.class] || ![@[@"values",@"set-player"] containsObject:action]
               || ![deadline isKindOfClass:NSNumber.class] || !std::isfinite(deadline.doubleValue)
               || deadline.doubleValue<NSDate.date.timeIntervalSince1970 || deadline.doubleValue>NSDate.date.timeIntervalSince1970+10
               || [seen containsObject:identifier])return;
            [seen addObject:identifier];if(seen.count>64)[seen removeObjectAtIndex:0];
            if(!PREnqueue(^{@autoreleasepool{reply(request,execute(request));}}))
                reply(request,@{ @"error":@"Native Prüfwarteschlange ist belegt." });
        }];
    });
}}
