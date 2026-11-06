// SPDX-License-Identifier: GPL-3.0-only
// Included only in an isolated in-game runtime, never in the launcher process.
#import "MHTProtocol.h"
#import "MHTGlassIntensity.h"
#import <AppKit/AppKit.h>
#import <unistd.h>
#include <math.h>
#if defined(MHT_DI2)
#define MHTBridge DI2GameBridge
#define MHTState DI2TrainerState
#define MHTFeatureState DI2FeatureState
#define MHTInfo DI2FeatureInfo
#define MHTInfoAt DI2FeatureInfoAt
#define MHTCount DI2FeatureCount
#define MHTDisable DI2TrainerDisableAll
#define MHTFeature DI2Feature
#elif defined(MHT_RE)
#define MHTBridge RE2GameBridge
#define MHTState RE2TrainerState
#define MHTFeatureState RE2FeatureState
#define MHTInfo RE2FeatureInfo
#define MHTInfoAt RE2FeatureInfoAt
#define MHTCount RE2ActiveFeatureCount()
#define MHTDisable RE2TrainerDisableAll
#define MHTFeature RE2Feature
#else
#define MHTBridge MTGameBridge
#define MHTState MTTrainerState
#define MHTFeatureState MTFeatureState
#define MHTInfo MTFeatureInfo
#define MHTInfoAt MTFeatureInfoAt
#define MHTCount MTFeatureCount
#define MHTDisable MTTrainerDisableAll
#define MHTFeature MTFeature
#endif

// Translate the common module contract inside the trainer. The launcher has no
// knowledge of a game's private selection format or feature bindings.
static NSString *MHTNativeSelectionJSON(void) {
    NSDictionary *selection=MHTDecodeMessage(NSProcessInfo.processInfo.environment[@"MHT_SELECTION"]);
    NSDictionary *entries=[selection[@"features"] isKindOfClass:NSDictionary.class] ? selection[@"features"] : @{};
    NSDictionary *payload=@{@"features":entries};
#if defined(MHT_RE) || defined(MHT_LOP)
    NSMutableArray *rows=[NSMutableArray new];
    for(NSInteger i=0;i<MHTCount;i++) {
        const MHTInfo *f=MHTInfoAt((MHTFeature)i);
        NSDictionary *source=entries[[NSString stringWithFormat:@"%ld",(long)i]];
        NSMutableDictionary *row=[@{@"wanted":@(!f->oneShot && [source[@"wanted"] boolValue]),@"value":source[@"value"] ?: @(f->initial)} mutableCopy];
#if defined(MHT_RE)
        row[@"binding"]=[NSString stringWithFormat:@"%ld:%hu:%lu:%d:%d",(long)i,f->key,(unsigned long)f->modifiers,f->numeric,f->oneShot];
        [rows addObject:row];
#else
        if(!f->oneShot && f->implemented){row[@"id"]=@(i);[rows addObject:row];}
#endif
    }
#if defined(MHT_RE)
    payload=@{@"schema":@1,@"profile":NSProcessInfo.processInfo.environment[@"MHT_PROFILE"] ?: @"",@"features":rows};
#else
    payload=@{@"schema":@1,@"catalog":@"liesofp-36-v2",@"features":rows};
#endif
#endif
    NSData *data=[NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}

static NSDictionary *MHTSnapshot(MHTState *state) {
    NSMutableArray *rows=[NSMutableArray new];
    for(NSInteger i=0;i<MIN((NSInteger)state.features.count,(NSInteger)MHTCount);i++) {
        MHTFeatureState *f=state.features[i];
        [rows addObject:@{@"id":@(i),@"available":@([f available]),@"wanted":@([f wanted]),
            @"active":@([f active]),@"value":@([f value]),@"note":[f note] ?: @""}];
    }
    BOOL saveable=state.ready || [state.status containsString:@"Netzwerk"];
#if defined(MHT_DI2)
    saveable=state.selectionCanBeSaved;
#elif defined(MHT_RE)
    saveable=saveable && !state.selectionPending;
#endif
    return @{@"selectionWritable":@(saveable),@"ready":@(state.ready),@"context":@(state.context),@"message":state.message ?: @"",
        @"features":rows};
}

static void MHTStartControl(MHTBridge *bridge,NSDictionary *(^readOptions)(void),void (^applyOptions)(NSDictionary *)) {
    NSDictionary *env=NSProcessInfo.processInfo.environment;
    NSString *module=env[@"MHT_MODULE"],*session=env[@"MHT_SESSION"];
    if(!module.length || !session.length)return;
    NSMutableOrderedSet *seen=[NSMutableOrderedSet new];
    void (^publish)(NSString *,NSString *)=^(NSString *request,NSString *error) {
        NSMutableDictionary *state=[MHTSnapshot(bridge.state) mutableCopy];state[@"overlay"]=readOptions() ?: @{};
        MHTPost(MHTStateNotification,@{@"version":@1,@"module":module,@"session":session,@"pid":@(getpid()),
            @"state":state,@"request":request ?: @"",@"error":error ?: @""});
    };
    [NSNotificationCenter.defaultCenter addObserverForName:MHTGlassOptionsDidCommitNotification object:nil
        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification){(void)notification;publish(@"",@"");}];
    // The notification center and runloop retain these for the game session.
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:MHTCommandNotification object:nil
        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *notification) {
        NSDictionary *m=MHTDecodeMessage(notification.object);
        if(!MHTAcceptCommand(m,module,session,getpid(),seen,NSDate.date.timeIntervalSince1970))return;
        NSString *action=m[@"action"],*error=nil;
        MHTState *state=bridge.state;
        if([action isEqual:@"disableAll"]) {[bridge performAction:MHTDisable];publish(m[@"request"],nil);return;}
        if([action isEqual:@"overlay"]) {
            if([m[@"options"] isKindOfClass:NSDictionary.class])applyOptions(m[@"options"]);
            publish(m[@"request"],nil);return;
        }
        double raw=[m[@"feature"] isKindOfClass:NSNumber.class] ? [m[@"feature"] doubleValue] : NAN;
        if(!isfinite(raw) || floor(raw)!=raw || raw<0 || raw>=MHTCount)error=@"Ungültige Funktion.";
        else if(![m[@"context"] isKindOfClass:NSNumber.class] || [m[@"context"] unsignedLongLongValue]!=state.context || !state.ready)
            error=@"Spielkontext hat gewechselt. Aktion verworfen.";
        else {
            NSInteger i=(NSInteger)raw;const MHTInfo *info=MHTInfoAt((MHTFeature)i);
            if(!info->implemented || ![state.features[i] available])error=@"Funktion im aktuellen Spielkontext nicht verfügbar.";
            else if([action isEqual:@"value"] && info->numeric) {
                double value=[m[@"value"] isKindOfClass:NSNumber.class] ? [m[@"value"] doubleValue] : NAN;
                BOOL integer=NO;
#if !defined(MHT_DI2)
                integer=info->integer;
#endif
                if(!isfinite(value) || value<info->minimum || value>info->maximum || (integer && floor(value)!=value))error=@"Wert außerhalb des gültigen Bereichs.";
                else [bridge setValue:value forFeature:(MHTFeature)i];
            } else if([action isEqual:@"run"] && info->oneShot) [bridge performFeature:(MHTFeature)i];
            else if([action isEqual:@"set"] && !info->oneShot && [m[@"wanted"] isKindOfClass:NSNumber.class]
                    && ([m[@"wanted"] doubleValue]==0 || [m[@"wanted"] doubleValue]==1)) {
                // Idempotent set; never blindly toggle after a delayed response.
                #if defined(MHT_RE)
                [bridge controlCommand:@{@"action":@"set",@"feature":@(i),@"wanted":m[@"wanted"],@"deadline":m[@"deadline"]} completion:^(RE2TrainerState *next,NSString *failure){(void)next;publish(m[@"request"],failure);}];
#else
                [bridge setWanted:[m[@"wanted"] boolValue] forFeature:(MHTFeature)i];
#endif
            } else error=@"Unzulässige Aktion für diese Funktion.";
        }
        publish(m[@"request"],error);
    }];
    NSTimer *timer=[NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t){(void)t;publish(nil,nil);}];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    publish(nil,nil);
}
