// SPDX-License-Identifier: GPL-3.0-only
// Explicit local development checks; never linked into the shipped trainer.
#import <AppKit/AppKit.h>
#import "VampireBackend.h"
#import "UnityLoop.h"
#import "TrainerFeatures.h"
#include "IL2CPP.hpp"
#include <cmath>
namespace {
id observer;
NSString *session;
const char *keys[]={"","","","","TownCoins","DungeonCoins","EXP","Health","Armor","Might","Amount","Area","Growth","Greed","Luck","Recovery","Mana","DealCount","Magnet","Duration","RevivalCharge","RevivalStacks","CardSkips","Rerolls","Banishes","Curse","Charm"};
void report(NSString *action,NSDictionary *result){
    NSMutableDictionary *root=[result mutableCopy];root[@"action"]=action;root[@"loop"]=VCLoopDiagnostics();
    NSData *data=[NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:@"/private/tmp/mht-vampire-crawlers/CandidateResult.json" atomically:YES];
}
void editBatch(){
    VCRelease();NSDictionary *before=VCValues();NSMutableArray *rows=[NSMutableArray new];
    for(NSInteger i=4;i<MTFeatureCount;i++){
        NSNumber *baseline=before[@(keys[i])];const MTFeatureInfo *info=MTFeatureInfoAt((MTFeature)i);
        if(!baseline){[rows addObject:@{@"feature":@(i),@"pass":@NO,@"reason":@"No live baseline"}];continue;}
        double original=baseline.doubleValue,trial=original+(i==MTFeatureHealth ? -1 : 1);
        if(trial>info->maximum)trial=original-1;
        if(i==MTFeatureExperience && [before[@"MaxXP"] doubleValue]-[before[@"CurrentXP"] doubleValue]<3){
            [rows addObject:@{@"feature":@(i),@"pass":@NO,@"reason":@"Too close to level-up for reversible test"}];continue;
        }
        if(original<info->minimum || original>info->maximum || trial<info->minimum || trial>info->maximum){
            [rows addObject:@{@"feature":@(i),@"pass":@NO,@"reason":@"Baseline outside editor range"}];continue;
        }
        NSString *set=VCOneShot(i,trial);NSDictionary *changed=VCValues();
        BOOL written=changed[@(keys[i])] && std::fabs([changed[@(keys[i])] doubleValue]-trial)<0.0001;
        NSString *restore=VCOneShot(i,original);
        if(i==MTFeatureHand && before[@"handLimits"]){
            // The real hand editor deliberately adjusts this run's native stat
            // bounds. This reversible development trial restores those as well.
            auto players=vc::findObjects(vc::klass("Pancake.dll","Nosebleed.Pancake.Models","PlayerModel"));
            if(players.size()==1){
                vc::Object stats=vc::call(vc::method(vc::api.objectClass(players.front()),"get_PlayerStats",0),players.front());
                vc::Object hand=vc::reference(stats,"DealCount");
                vc::invokeNumber(hand,"SetMin",[before[@"handLimits"][@"min"] doubleValue]);
                vc::invokeNumber(hand,"SetMax",[before[@"handLimits"][@"max"] doubleValue]);
                vc::boolean(hand,"_uncapped",[before[@"handLimits"][@"uncapped"] boolValue]);
                vc::invokeNumber(hand,"SetValue",original);
            }
        }
        NSDictionary *restored=VCValues();
        BOOL undone=restored[@(keys[i])] && std::fabs([restored[@(keys[i])] doubleValue]-original)<0.0001;
        [rows addObject:@{@"feature":@(i),@"title":info->title,@"baseline":@(original),@"trial":@(trial),@"written":@(written),@"restored":@(undone),@"pass":@(written && undone),@"set":set,@"restore":restore,
            @"boundsRestored":@(i!=MTFeatureHand || [before[@"handLimits"] isEqual:restored[@"handLimits"]])}];
        if(!undone)break; // Do not compound an un-restored trial.
    }
    report(@"edit-batch",@{@"before":before,@"after":VCValues(),@"rows":rows});
}
void toggleBatch(){
    VCRelease();NSDictionary *before=VCValues();NSMutableArray *rows=[NSMutableArray new];
    for(NSInteger i=0;i<3;i++){
        NSDictionary *effect=VCEffect(i,YES,0),*changed=VCValues();
        VCEffect(i,NO,0);NSDictionary *after=VCValues();
        NSString *key=i==0 ? @"Invulnerable" : i==1 ? @"cardReadback" : @"enemyReadback";
        [rows addObject:@{@"feature":@(i),@"effect":effect,@"changed":changed[key] ?: NSNull.null,
            @"restored":@([before[key] isEqual:after[key]]),@"pass":@([effect[@"active"] boolValue] && [before[key] isEqual:after[key]])}];
    }
    report(@"toggle-batch",@{@"before":before,@"after":VCValues(),@"rows":rows});
}
void xpTest(){
    VCRelease();NSDictionary *before=VCValues();
    if(!before[@"EXP"] || [before[@"MaxXP"] doubleValue]-[before[@"CurrentXP"] doubleValue]<4){report(@"xp",@{@"pass":@NO,@"reason":@"No reversible XP range"});return;}
    auto players=vc::findObjects(vc::klass("Pancake.dll","Nosebleed.Pancake.Models","PlayerModel"));
    if(players.size()!=1){report(@"xp",@{@"pass":@NO,@"reason":@"No unique local owner"});return;}
    VCEffect(3,YES,2);
    vc::numericCall(vc::method(vc::api.objectClass(players.front()),"AddXp",2),players.front(),{1,0});
    // The production frame handler consumes this actual gain in the next tick.
    VCEnqueue(^{
        NSDictionary *changed=VCValues();VCEffect(3,NO,2);
        NSString *restore=VCOneShot(MTFeatureExperience,[before[@"EXP"] doubleValue]);NSDictionary *after=VCValues();
        report(@"xp",@{@"before":before,@"changed":changed,@"after":after,@"restore":restore,
            @"pass":@([changed[@"EXP"] doubleValue]==[before[@"EXP"] doubleValue]+2 && [after[@"EXP"] isEqual:before[@"EXP"]] && [after[@"Level"] isEqual:before[@"Level"]])});
    });
}
void action(NSString *name){
    try{
        if([name isEqual:@"edit-batch"]){editBatch();return;}
        if([name isEqual:@"toggle-batch"]){toggleBatch();return;}
        if([name isEqual:@"xp"]){xpTest();return;}
        if([name isEqual:@"combat-on"]){
            NSMutableArray *effects=[NSMutableArray new];for(NSInteger i=0;i<4;i++)[effects addObject:VCEffect(i,YES,i==3 ? 2 : 0)];
            report(name,@{@"effects":effects,@"values":VCValues()});return;
        }
        if([name isEqual:@"off"]){VCRelease();VCMouse(NO);}
        if([name isEqual:@"mouse-on"] || [name isEqual:@"mouse-off"]){BOOL active=VCMouse([name isEqual:@"mouse-on"]);report(name,@{@"active":@(active),@"context":VCInspect(),@"values":VCValues()});return;}
        report(name,@{@"context":VCInspect(),@"values":VCValues()});
    }catch(const std::exception& e){VCRelease();report(name,@{@"error":@(e.what())});}
}
}
__attribute__((constructor)) static void checks(){@autoreleasepool{
    if(strcmp(getenv("MHT_VC_DEVELOPMENT") ?: "","1"))return;
    session=getenv("MHT_SESSION") ? @(getenv("MHT_SESSION")) : nil;if(!session.length)return;
    dispatch_async(dispatch_get_main_queue(),^{
        observer=[NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.mht.vampire-crawlers.candidate" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
            if(![event.object isKindOfClass:NSString.class] || [event.object length]>4096)return;
            id message=[NSJSONSerialization JSONObjectWithData:[event.object dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if(![message isKindOfClass:NSDictionary.class] || ![message[@"token"] isEqual:session] || ![message[@"action"] isKindOfClass:NSString.class])return;
            VCEnqueue(^{action(message[@"action"]);});
        }];
    });
}}
