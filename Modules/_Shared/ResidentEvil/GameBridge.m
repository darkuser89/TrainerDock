// SPDX-License-Identifier: GPL-3.0-only
#import "GameBridge.h"
#import "CheatPreferences.h"
#include <math.h>
@implementation RE2TrainerState
- (instancetype)init {
    if((self=[super init])) {
        _status=@"Nicht verbunden";_message=@"Wartet auf bestätigten lokalen Spielkontext.";
        NSMutableArray *features=[NSMutableArray new];
        for(NSInteger i=0;i<RE2ActiveFeatureCount();i++){RE2FeatureState *f=[RE2FeatureState new];f.value=RE2FeatureInfoAt(i)->initial;f.note=RE2FeatureInfoAt(i)->detail;[features addObject:f];}
        _features=features;
    }return self;
}
@end
@interface RE2GameBridge () {
    id<RE2GameAdapter> _adapter;
    BOOL _wanted[RE2FeatureCapacity],_inFlight,_mouse,_readOnly;
    double _values[RE2FeatureCapacity];
    uint64_t _revision;
    NSString *_identity,*_message;
    RE2SessionKind _mode;
    NSMutableArray<NSDictionary *> *_queue;
    NSDictionary *_pendingRestore;
}
@property(nonatomic,readwrite) RE2TrainerState *state;
@end
@implementation RE2GameBridge
- (instancetype)init { return [self initWithAdapter:RE2CreateGameAdapter()]; }
- (instancetype)initWithAdapter:(id<RE2GameAdapter>)adapter {
    return [self initWithAdapter:adapter readOnly:NO];
}
- (instancetype)initWithAdapter:(id<RE2GameAdapter>)adapter readOnly:(BOOL)readOnly {
    return [self initWithAdapter:adapter readOnly:readOnly restoreSelection:nil];
}
- (instancetype)initWithAdapter:(id<RE2GameAdapter>)adapter readOnly:(BOOL)readOnly restoreSelection:(NSDictionary *)selection {
    if((self=[super init])){_adapter=adapter;_readOnly=readOnly;_state=[RE2TrainerState new];_queue=[NSMutableArray new];_message=_state.message;
        _pendingRestore=readOnly ? nil : RE2NormalizeSelection(selection,RE2CurrentSelectionProfile());
        _state.selectionPending=_pendingRestore!=nil;
        for(NSInteger i=0;i<RE2ActiveFeatureCount();i++)_values[i]=RE2FeatureInfoAt(i)->initial;}
    return self;
}
- (RE2TrainerState *)update:(NSInteger)command value:(NSNumber *)value expected:(uint64_t)expected {
    NSInteger requestedCommand=command;
    RE2GameContext *context=[_adapter captureContext];
    BOOL changed=_mode!=context.kind || ![_identity isEqual:context.identity];
    if(changed){[_adapter releaseEffects];_revision++;_identity=[context.identity copy];_mode=context.kind;if(command!=RE2TrainerDisableAll && command!=50)command=RE2TrainerPoll;}
    if(expected && expected!=_revision && command!=RE2TrainerDisableAll && command!=50)command=RE2TrainerPoll;
    if(_mode==RE2SessionUnsupported)memset(_wanted,0,sizeof(_wanted));
    if(command==RE2TrainerDisableAll)_pendingRestore=nil;
    if(_pendingRestore && (_mode==RE2SessionSolo || _mode==RE2SessionNetwork)){
        NSArray *rows=_pendingRestore[@"features"];
        for(NSInteger i=0;i<RE2ActiveFeatureCount();i++){
            const RE2FeatureInfo *info=RE2FeatureInfoAt(i);_values[i]=[rows[i][@"value"] doubleValue];
            _wanted[i]=info->implemented && !info->oneShot && [rows[i][@"wanted"] boolValue];
        }
        _pendingRestore=nil;_message=@"Gespeicherte Cheat-Auswahl wiederhergestellt.";
    }
    if(command==RE2TrainerDisableAll){[_adapter releaseEffects];memset(_wanted,0,sizeof(_wanted));_message=@"Alle Schalter aus.";}
    if(command==50)_mouse=value.boolValue;
    RE2TrainerState *state=[RE2TrainerState new];state.context=_revision;
    state.selectionPending=_pendingRestore!=nil;
    state.overlayMouseActive=[_adapter setOverlayInteraction:_mouse];
    state.ready=(_mode==RE2SessionSolo || _mode==RE2SessionNetwork) && !_readOnly;
    state.status=_readOnly ? @"Prüfmodus · Funktionen gesperrt" : _mode==RE2SessionSolo ? @"Einzelspieler" : _mode==RE2SessionNetwork ? @"Netzwerk" : _mode==RE2SessionLoading ? @"Ladepause" : @"Nicht unterstützt";
    NSInteger feature=command>=100 && command<100+RE2ActiveFeatureCount() ? command-100 : -1;
    if(state.ready && command>=200 && command<200+RE2ActiveFeatureCount() && value){
        NSInteger i=command-200;const RE2FeatureInfo *info=RE2FeatureInfoAt(i);double n=value.doubleValue;
        if(info->numeric && isfinite(n) && n>=info->minimum && n<=info->maximum && (!info->integer || floor(n)==n))_values[i]=n;
    }
    if(state.ready && feature>=0 && RE2FeatureInfoAt(feature)->implemented){
        if(RE2FeatureInfoAt(feature)->oneShot)_message=[_adapter performOneShot:feature value:_values[feature]];
        else {_wanted[feature]=!_wanted[feature];_message=[NSString stringWithFormat:@"%@: %@",RE2FeatureInfoAt(feature)->title,_wanted[feature] ? @"AN / wartet" : @"AUS"];}
    }
    if(state.ready && command>=300 && command<300+RE2ActiveFeatureCount() && value){
        NSInteger i=command-300;const RE2FeatureInfo *f=RE2FeatureInfoAt(i);
        if(f->implemented && !f->oneShot){_wanted[i]=value.boolValue;_message=[NSString stringWithFormat:@"%@: %@",f->title,_wanted[i] ? @"AN / wartet" : @"AUS"];}
    }
    state.commandAccepted=command==requestedCommand && (requestedCommand<100 || state.ready);
    for(NSInteger i=0;i<RE2ActiveFeatureCount();i++){
        RE2FeatureState *f=state.features[i];f.value=_values[i];f.wanted=_wanted[i];
        if(state.ready){RE2FeatureState *actual=[_adapter applyFeature:i wanted:_wanted[i] value:_values[i]];f.available=actual.available;f.active=_wanted[i] && actual.active;f.note=actual.note ?: context.note;}
        else f.note=_readOnly ? @"Sichtprüfung der echten Spielanbindung. Funktionen sind gesperrt." : _mode==RE2SessionLoading ? @"Auswahl bleibt erhalten; wartet auf gültigen Einzelspieler." : context.note;
    }
    state.updatedAt=NSDate.date.timeIntervalSince1970;
    state.diagnostics=[_adapter respondsToSelector:@selector(diagnostics)] ? [_adapter diagnostics] : @{};
    state.message=_readOnly ? [@"Prüfmodus: keine Trainerfunktionen. " stringByAppendingString:context.note ?: @""] : state.ready ? _message : context.note;return state;
}
- (void)finishCancelled:(NSIndexSet *)indexes {
    for(NSDictionary *r in [_queue objectsAtIndexes:indexes]){void (^reply)(RE2TrainerState *,NSString *)=r[@"reply"];if(reply)reply(nil,@"Command cancelled by state change or disable-all.");}
    [_queue removeObjectsAtIndexes:indexes];
}
- (void)submit:(NSInteger)command value:(NSNumber *)value { [self submit:command value:value deadline:0 completion:nil]; }
- (void)submit:(NSInteger)command value:(NSNumber *)value deadline:(double)deadline completion:(void (^)(RE2TrainerState *,NSString *))completion {
    NSAssert(NSThread.isMainThread,@"UI commands originate on main thread");
    NSMutableDictionary *request=[@{@"command":@(command),@"value":value ?: NSNull.null,@"context":@(_state.context),@"deadline":@(deadline)} mutableCopy];
    if(completion)request[@"reply"]=[completion copy];
    if(_inFlight){
        if(command==50 || command==RE2TrainerDisableAll){
            NSIndexSet *old=[_queue indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry,NSUInteger index,BOOL *stop){(void)index;(void)stop;NSInteger n=[entry[@"command"] integerValue];return command==RE2TrainerDisableAll ? n!=50 : n==50;}];
            [self finishCancelled:old];[_queue insertObject:request atIndex:0];
        }else if((command!=RE2TrainerPoll || completion) && _queue.count<16)[_queue addObject:request];
        else if(completion)completion(nil,@"Die Befehlswarteschlange des Trainers ist ausgelastet.");
        return;
    }
    [self dispatch:request];
}
- (void)dispatch:(NSDictionary *)request {
    _inFlight=YES;
    [_adapter onGameThread:^{@autoreleasepool{
        id value=request[@"value"];double deadline=[request[@"deadline"] doubleValue];BOOL expired=deadline>0 && NSDate.date.timeIntervalSince1970>deadline;
        RE2TrainerState *next=[self update:expired ? RE2TrainerPoll : [request[@"command"] integerValue] value:value==NSNull.null ? nil : value expected:[request[@"context"] unsignedLongLongValue]];
        dispatch_async(dispatch_get_main_queue(),^{
            self.state=next;self->_inFlight=NO;if(self.stateChanged)self.stateChanged(next);
            void (^reply)(RE2TrainerState *,NSString *)=request[@"reply"];
            if(reply)reply(next,expired ? @"Command expired before GameThread execution." : !next.commandAccepted ? @"Command rejected: context changed or game not ready." : nil);
            if(!next.ready){NSIndexSet *old=[self->_queue indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry,NSUInteger index,BOOL *stop){(void)index;(void)stop;NSInteger n=[entry[@"command"] integerValue];return n!=RE2TrainerPoll && n!=50 && n!=RE2TrainerDisableAll;}];[self finishCancelled:old];}
            if(self->_queue.count){NSDictionary *entry=self->_queue.firstObject;[self->_queue removeObjectAtIndex:0];[self dispatch:entry];}
        });
    }}];
}
- (void)controlCommand:(NSDictionary *)request completion:(void (^)(RE2TrainerState *,NSString *))completion {
    NSAssert(NSThread.isMainThread,@"Control requests use the main-thread command queue");
    NSString *action=request[@"action"];NSInteger command=-1;NSNumber *value=nil;
    if([action isEqual:@"state"])command=RE2TrainerPoll;
    else if([action isEqual:@"disable_all"])command=RE2TrainerDisableAll;
    else {
        NSNumber *index=request[@"feature"];double n=[index isKindOfClass:NSNumber.class] ? index.doubleValue : NAN;
        if(!isfinite(n) || floor(n)!=n || n<0 || n>=RE2ActiveFeatureCount()){completion(nil,@"Ungültige Funktionsnummer.");return;}
        NSInteger i=(NSInteger)n;const RE2FeatureInfo *f=RE2FeatureInfoAt(i);
        if(!f->implemented){completion(nil,@"Diese Funktion ist nicht implementiert.");return;}
        if([action isEqual:@"set"] && !f->oneShot){
            value=request[@"wanted"];if(![value isKindOfClass:NSNumber.class] || (value.doubleValue!=0 && value.doubleValue!=1)){completion(nil,@"Der Schaltwert muss ein Wahrheitswert sein.");return;}command=300+i;
        }else if([action isEqual:@"value"] && f->numeric){
            value=request[@"value"];double v=[value isKindOfClass:NSNumber.class] ? value.doubleValue : NAN;
            if(!isfinite(v) || v<f->minimum || v>f->maximum || (f->integer && floor(v)!=v)){completion(nil,@"Der Zahlenwert liegt außerhalb des Funktionsbereichs.");return;}command=200+i;
        }else if([action isEqual:@"run"] && f->oneShot)command=100+i;
    }
    if(command<0){completion(nil,@"Aktion oder Funktionstyp nicht unterstützt. Einmalaktionen müssen ausdrücklich ausgeführt werden.");return;}
    double deadline=[request[@"deadline"] isKindOfClass:NSNumber.class] ? [request[@"deadline"] doubleValue] : NSDate.date.timeIntervalSince1970+4;
    if(!isfinite(deadline) || deadline>NSDate.date.timeIntervalSince1970+10){completion(nil,@"Ungültige Gültigkeitsdauer des Befehls.");return;}
    [self submit:command value:value deadline:deadline completion:completion];
}
- (void)poll {[self submit:RE2TrainerPoll value:nil];}
- (void)performAction:(RE2TrainerAction)action {if(action==RE2TrainerPoll || action==RE2TrainerDisableAll)[self submit:action value:nil];}
- (void)performFeature:(RE2Feature)feature {if(RE2FeatureInfoAt(feature))[self submit:100+feature value:nil];}
- (void)setValue:(double)value forFeature:(RE2Feature)feature {const RE2FeatureInfo *info=RE2FeatureInfoAt(feature);if(info && info->numeric && isfinite(value) && value>=info->minimum && value<=info->maximum && (!info->integer || floor(value)==value))[self submit:200+feature value:@(value)];}
- (void)setOverlayInteraction:(BOOL)enabled {[self submit:50 value:@(enabled)];}
@end
