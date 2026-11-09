// SPDX-License-Identifier: GPL-3.0-only
// Private, session-bound original gameplay observations; never a product source.
#import <Foundation/Foundation.h>
#import <unistd.h>
extern "C" {
#import "GameProfile.h"
}
#import "HouseFlipperEffects.h"
#import "HouseFlipperLoop.h"
#include "HouseFlipperMono.hpp"
#include <cmath>
#include <cstring>
#include <array>

namespace {
NSString *session;
id observer;
NSMutableOrderedSet<NSString *> *seen;
NSString *const requestName=@"local.trainerdock.house-flipper.probe.request";
NSString *const responseName=@"local.trainerdock.house-flipper.probe.response";

bool is(hf::Object object,hf::Klass expected){
    if(!object || !expected)return false;
    for(hf::Klass k=hf::api.objectClass(object);k;k=hf::api.parent(k))if(k==expected)return true;
    return false;
}
hf::Object reference(hf::Object owner,hf::Klass ownerClass,const char *name,hf::Klass expected){
    hf::Object result=hf::ref(owner,ownerClass,name);
    if(!is(result,expected))throw std::runtime_error("Ursprünglicher Spielerfortschritt ist nicht verfügbar.");
    return result;
}
NSDictionary *categoryDiagnostics(){
    using namespace hf;
    if(!HFInFrame())return @{@"error":@"Kein originaler Unity-Spielrückruf."};
    try{
        Klass managerClass=type("Code.GameManagers","GameManager");
        Root manager(call(typedMethod(managerClass,"get_Instance","Code.GameManagers.GameManager",{},true)));
        if(!manager.get())return @{@"error":@"Originaler Spielmanager fehlt."};
        Root player(reference(manager.get(),managerClass,"player",type("Assets.Code.Player","PlayerController")));
        Root progress(reference(player.get(),api.objectClass(player.get()),"progress",type("","PlayerProgress")));
        Root skills(reference(progress.get(),type("","PlayerProgress"),"skills",type("","Skills")));
        Klass skillClass=api.objectClass(skills.get());
        std::string skillsName=typeName(api.classType(skillClass));
        NSMutableDictionary *rows=[NSMutableDictionary new];
        constexpr std::array<const char *,11> names={"cleaning","demolition","painting","building","design","negotiation","handyman","gardener","farmer","architect","restaurateur"};
        for(const char *name:names){
            NSMutableDictionary *row=[NSMutableDictionary new];rows[@(name)]=row;
            try{
                // Inspect every actual reference without applying the product's
                // availability filter: this is passive diagnosis of that filter.
                Root category(ref(skills.get(),skillClass,name));
                row[@"null"]=@(category.get()==nullptr);
                if(!category.get())continue;
                Klass actual=api.objectClass(category.get());
                std::string actualName=typeName(api.classType(actual));
                row[@"type"]=@(actualName.c_str());
                Field enabled=field(actual,"enabled"),points=field(actual,"numberOfPerksAvailable");
                if(scalarKind(enabled)!=2 || scalarKind(points)!=8 || ((api.flags(enabled)|api.flags(points))&0x10))
                    throw std::runtime_error("Die ursprünglichen Kategoriewerttypen weichen ab.");
                row[@"enabled"]=@(number(category.get(),actual,"enabled")!=0);
                row[@"numberOfPerksAvailable"]=@(number(category.get(),actual,"numberOfPerksAvailable"));
                Root backlink(ref(category.get(),actual,"playerProgress"));
                row[@"backlinkNull"]=@(backlink.get()==nullptr);
                row[@"backlinkMatchesCurrentProgress"]=@(backlink.get()==progress.get());
                if(backlink.get()){
                    std::string backlinkName=typeName(api.classType(api.objectClass(backlink.get())));
                    row[@"backlinkType"]=@(backlinkName.c_str());
                }
            }catch(const std::exception& error){row[@"error"]=@(error.what());}
        }
        return @{@"skillsType":@(skillsName.c_str()),@"categories":rows};
    }catch(const std::exception& error){return @{@"error":@(error.what())};}
}
NSDictionary *execute(NSDictionary *request){
    if(!HFInFrame())return @{@"error":@"Kein originaler Unity-Spielrückruf."};
    if([request[@"deadline"] doubleValue]<NSDate.date.timeIntervalSince1970)
        return @{@"error":@"Prüfauftrag ist abgelaufen."};
    try{
        NSDictionary *before=HFValues();
        NSString *action=request[@"action"];
        if([action isEqual:@"values"])return @{@"values":before,@"categoryDiagnostics":categoryDiagnostics(),@"engineCallback":@YES};
        if(![action isEqual:@"spend-money"])return @{@"error":@"Unbekannter Prüfauftrag."};
        NSNumber *requested=request[@"amount"];
        double amount=[requested isKindOfClass:NSNumber.class]?requested.doubleValue:0;
        if(!std::isfinite(amount) || amount<=0 || amount>1000)
            return @{@"error":@"Prüfzahlung muss größer als null und höchstens 1.000 sein."};
        NSDictionary *context=HFInspect();
        if([before[@"kind"] integerValue]!=2 || [context[@"kind"] integerValue]!=2
           || ![before[@"identity"] isEqual:context[@"identity"]]
           || ![before[@"money"] isKindOfClass:NSNumber.class] || [before[@"money"] doubleValue]<amount)
            return @{@"error":@"Kein bestätigter Spieler mit ausreichendem Guthaben.",@"values":before};
        using namespace hf;
        Klass managerClass=type("Code.GameManagers","GameManager");
        Root manager(call(typedMethod(managerClass,"get_Instance","Code.GameManagers.GameManager",{},true)));
        if(!manager.get())throw std::runtime_error("Originaler Spielmanager fehlt.");
        Root player(reference(manager.get(),managerClass,"player",type("Assets.Code.Player","PlayerController")));
        Root progress(reference(player.get(),api.objectClass(player.get()),"progress",type("","PlayerProgress")));
        Root money(reference(progress.get(),type("","PlayerProgress"),"moneyProgress",type("","MoneyProgress")));
        Method payment=tokenMethod(type("","Money"),0x06004D0A,"System.Boolean",{"System.Single"},false);
        NSDictionary *fresh=HFInspect();
        if([fresh[@"kind"] integerValue]!=2 || ![fresh[@"identity"] isEqual:before[@"identity"]])
            return @{@"error":@"Spielerbesitzer hat vor der Prüfzahlung gewechselt."};
        // Invoke the original affordability/payment method, not a save edit or a
        // fabricated counter decrement. No perk purchase is performed here.
        float paymentAmount=(float)amount;
        bool paid=unboxNumber(call(payment,money.get(),{&paymentAmount}),2)!=0;
        return @{@"before":before,@"values":HFValues(),@"paid":@(paid),@"amount":@(paymentAmount),@"engineCallback":@YES};
    }catch(const std::exception& error){return @{@"error":@(error.what()),@"engineCallback":@YES};}
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

__attribute__((constructor)) static void startHouseFlipperProbe(){@autoreleasepool{
    if(strcmp(getenv("MHT_HOUSE_FLIPPER_DEVELOPMENT") ?: "","1"))return;
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
               || ![action isKindOfClass:NSString.class] || ![@[@"values",@"spend-money"] containsObject:action]
               || ![deadline isKindOfClass:NSNumber.class] || !std::isfinite(deadline.doubleValue)
               || deadline.doubleValue<NSDate.date.timeIntervalSince1970 || deadline.doubleValue>NSDate.date.timeIntervalSince1970+10
               || [seen containsObject:identifier])return;
            [seen addObject:identifier];if(seen.count>64)[seen removeObjectAtIndex:0];
            if(!HFEnqueue(^{@autoreleasepool{reply(request,execute(request));}}))
                reply(request,@{@"error":@"Native Prüfwarteschlange ist belegt."});
        }];
    });
}}
