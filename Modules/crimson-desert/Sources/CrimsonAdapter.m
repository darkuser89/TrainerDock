// SPDX-License-Identifier: GPL-3.0-only
#import "CrimsonAdapter.h"
#import "CrimsonNative.h"
#include <math.h>
@implementation CDCrimsonAdapter {
    NSDictionary *_snapshot;
    NSDictionary *(^_reader)(void);
    BOOL(^_requester)(unsigned,BOOL,double,uint32_t);
    dispatch_block_t _releaser;
    BOOL(^_cursor)(BOOL);
    BOOL _valid;
    NSMutableSet<NSNumber *> *_requested;
    NSMutableDictionary<NSNumber *,NSDictionary *> *_actions;
}
- (instancetype)init {return [self initWithReader:^{return CDReadPlayer();}
    requester:^BOOL(unsigned feature,BOOL wanted,double value,uint32_t key){return CDRequestEffect(feature,wanted,value,key);}
    releaser:^{CDReleaseEffects();} cursor:^BOOL(BOOL wanted){return CDSetOverlayInteraction(wanted);}];}
- (instancetype)initWithReader:(NSDictionary *(^)(void))reader requester:(BOOL(^)(unsigned,BOOL,double,uint32_t))requester releaser:(dispatch_block_t)releaser cursor:(BOOL(^)(BOOL))cursor {
    if((self=[super init])) {_reader=[reader copy];_requester=[requester copy];_releaser=[releaser copy];_cursor=[cursor copy];_requested=[NSMutableSet new];_actions=[NSMutableDictionary new];}return self;
}
- (void)onGameThread:(dispatch_block_t)work {CDOnGameThread(work);}
- (MTGameContext *)captureContext {
    _valid=NO;_snapshot=_reader();MTGameContext *context=[MTGameContext new];
    if(![_snapshot[@"buildMatched"] boolValue] || _snapshot[@"error"] || ![_snapshot[@"thread"] isEqual:@"GameThread"]) {
        context.note=_snapshot[@"error"] ?: @"Dieser Spiel-Build ist nicht freigegeben.";return context;
    }
    if([_snapshot[@"loading"] boolValue] || !_snapshot[@"actorKey"]) {
        context.kind=MTSessionLoading;context.identity=@"loading";context.note=@"Warte auf eine gültige lokale Spielfigur …";return context;
    }
    context.kind=MTSessionSolo;_valid=YES;
    context.identity=[NSString stringWithFormat:@"%d/%@/%@",NSProcessInfo.processInfo.processIdentifier,_snapshot[@"fieldIndex"],_snapshot[@"actorKey"]];
    context.note=[NSString stringWithFormat:@"Crimson Desert · Build 450 · Leben %@/%@ · Ausdauer %@/%@ · Geist %@/%@",_snapshot[@"health"][@"value"],_snapshot[@"health"][@"maximum"],_snapshot[@"stamina"][@"value"],_snapshot[@"stamina"][@"maximum"],_snapshot[@"spirit"][@"value"],_snapshot[@"spirit"][@"maximum"]];return context;
}
- (void)releaseEffects {_releaser();[_requested removeAllObjects];[_actions removeAllObjects];}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];const MTFeatureInfo *info=MTFeatureInfoAt(feature);
    if(!info || !_valid)return state;
    state.available=YES;
    if(info->oneShot) {
        NSString *bindingKey=feature==7 ? @"selectedItem" : feature==12 ? @"wallet" : nil;
        NSDictionary *binding=bindingKey ? _snapshot[bindingKey] : nil;
        state.available=!bindingKey || binding!=nil;
        state.note=feature==11 ? @"Einmalig eine Spielstunde weiterstellen." : binding ? [NSString stringWithFormat:@"Aktueller Stapel: %@ · Ziel: %.0f",binding[@"count"],value] : feature==7 ? @"Inventar öffnen und einen Gegenstand auswählen." : @"Kein eindeutiger Geldstapel gefunden.";
        NSDictionary *pending=_actions[@(feature)];
        if(pending && [pending[@"actorKey"] isEqual:_snapshot[@"actorKey"]]) {
            if(feature==11)state.note=[_snapshot[@"seconds"] unsignedLongLongValue]>=[pending[@"seconds"] unsignedLongLongValue] ? @"Stundensprung zurückgelesen." : @"Warte auf Stundensprung …";
            else {
                NSDictionary *result=_snapshot[@"quantityResult"];
                if([result[@"actorKey"] isEqual:pending[@"actorKey"]] && [result[@"itemNo"] isEqual:pending[@"itemNo"]] && [result[@"requested"] isEqual:pending[@"requested"]])
                    state.note=[result[@"success"] boolValue] ? [NSString stringWithFormat:@"Menge %@ → %@ · nativ bestätigt",result[@"before"],result[@"after"]] : result[@"reason"] ?: [NSString stringWithFormat:@"Änderung abgelehnt (Spielcode %@).",result[@"nativeError"] ?: @"–"];
                else state.note=@"Inventartransaktion angefordert; warte auf Rücklesen …";
            }
        }
        return state;
    }
    if(wanted) {
        if(_requester((unsigned)feature,YES,value,[_snapshot[@"actorKey"] unsignedIntValue]))[_requested addObject:@(feature)];
    } else {
        if([_requested containsObject:@(feature)] && _requester((unsigned)feature,NO,value,[_snapshot[@"actorKey"] unsignedIntValue]))[_requested removeObject:@(feature)];
        state.note=@"Aus";return state;
    }
    NSDictionary *server=_snapshot[@"server"];
    BOOL owned=[server[@"actorKey"] isEqual:_snapshot[@"actorKey"]] && [server[@"serverThread"] boolValue];
    NSString *statKey=feature<=5 ? @[@"health",@"stamina",@"spirit"][feature/2] : feature==6 ? @"defense" : @"attack";
    NSDictionary *stat=server[statKey],*client=_snapshot[statKey];
    if(feature==8)state.active=_snapshot[@"effectiveSpeed"] && fabs([_snapshot[@"effectiveSpeed"] doubleValue]-value)<0.001;
    else if(feature==10)state.active=_snapshot[@"daySpeed"] && [_snapshot[@"daySpeed"] unsignedIntValue]==0;
    else if(owned && stat && client) {
        if(feature==0 || feature==2 || feature==4)state.active=[stat[@"rawMaximum"] longLongValue]>0 && [stat[@"rawMinimum"] longLongValue]==[stat[@"rawMaximum"] longLongValue] && [client[@"rawMinimum"] longLongValue]==[client[@"rawMaximum"] longLongValue];
        else {
            NSString *field=feature<=5 ? @"rawMaximum" : @"raw";int64_t target=llround((feature==9 ? 10000 : value)*1000);
            state.active=[stat[field] longLongValue]==target && [client[field] longLongValue]==target;
        }
    }
    // A pre-existing native value alone must not confirm a rejected request.
    state.active=state.active && [_requested containsObject:@(feature)];
    state.note=state.active ? @"Client und Spielzustand zurückgelesen." : @"Angefordert; warte auf Rückleseprüfung …";
    return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {
    const MTFeatureInfo *info=MTFeatureInfoAt(feature);
    if(!info || !info->oneShot || !_valid)return @"Aktion verworfen: kein gültiger Spieler-Kontext.";
    NSDictionary *binding=feature==7 ? _snapshot[@"selectedItem"] : feature==12 ? _snapshot[@"wallet"] : nil;
    if(feature!=11 && !binding)return @"Aktion verworfen: Zielstapel nicht eindeutig ausgewählt.";
    if(!_requester((unsigned)feature,YES,value,[_snapshot[@"actorKey"] unsignedIntValue]))return @"Aktion abgelehnt: Ziel, Stapellimit oder Kontext ungültig.";
    _actions[@(feature)]=feature==11 ? @{@"actorKey":_snapshot[@"actorKey"],@"seconds":@([_snapshot[@"seconds"] unsignedLongLongValue]+3600)} : @{@"actorKey":_snapshot[@"actorKey"],@"itemNo":binding[@"itemNo"],@"requested":@(value)};
    return @"Einmalaktion angefordert; die Zeile zeigt das bestätigte Ergebnis.";
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return _cursor(wanted);}
@end
