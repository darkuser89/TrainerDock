// SPDX-License-Identifier: GPL-3.0-only
#import "GameBridge.h"
#import "SelectionSettings.h"
#include <math.h>
@interface MTTrainerState ()
@property(nonatomic,copy) NSDictionary *selectionToSave;
@end
@implementation MTTrainerState
- (instancetype)init {
    if((self=[super init])) {
        _status=@"Nicht verbunden";_message=@"Lies of P · wartet auf geprüften Spielkontext.";
        NSMutableArray *features=[NSMutableArray new];
        for(NSInteger i=0;i<MTFeatureCount;i++){MTFeatureState *f=[MTFeatureState new];f.value=MTFeatureInfoAt(i)->initial;f.note=MTFeatureInfoAt(i)->detail;[features addObject:f];}
        _features=features;
    }return self;
}
@end
@interface MTGameBridge () {
    id<MTGameAdapter> _adapter;
    BOOL _wanted[MTFeatureCount],_inFlight,_mouse;
    double _values[MTFeatureCount];
    uint64_t _revision;
    NSString *_identity,*_message;
    MTSessionKind _mode;
    NSMutableArray<NSDictionary *> *_queue;
}
@property(nonatomic,readwrite) MTTrainerState *state;
@end
@implementation MTGameBridge
- (instancetype)init { return [self initWithAdapter:MTCreateGameAdapter()]; }
- (instancetype)initWithAdapter:(id<MTGameAdapter>)adapter {
    return [self initWithAdapter:adapter selection:nil];
}
- (instancetype)initWithAdapter:(id<MTGameAdapter>)adapter selection:(id)selection {
    if((self=[super init])){_adapter=adapter;_state=[MTTrainerState new];_queue=[NSMutableArray new];_message=_state.message;
        for(NSInteger i=0;i<MTFeatureCount;i++)_values[i]=MTFeatureInfoAt(i)->initial;
        for(NSDictionary *entry in MTNormalizeSelection(selection)[@"features"]){
            NSInteger i=[entry[@"id"] integerValue];_wanted[i]=[entry[@"wanted"] boolValue];_values[i]=[entry[@"value"] doubleValue];
            _state.features[i].wanted=_wanted[i];_state.features[i].value=_values[i];
        }
    }
    return self;
}
- (MTTrainerState *)update:(NSInteger)command value:(NSNumber *)value expected:(uint64_t)expected {
    MTGameContext *context=[_adapter captureContext];
    BOOL saveSelection=NO;
    BOOL changed=_mode!=context.kind || ![_identity isEqual:context.identity];
    if(changed){[_adapter releaseEffects];_revision++;_identity=[context.identity copy];_mode=context.kind;if(command!=MTTrainerDisableAll && command!=50)command=MTTrainerPoll;}
    if(expected && expected!=_revision && command!=MTTrainerDisableAll && command!=50)command=MTTrainerPoll;
    if(_mode==MTSessionUnsupported){
        memset(_wanted,0,sizeof(_wanted));
    }
    if(command==MTTrainerDisableAll){[_adapter releaseEffects];memset(_wanted,0,sizeof(_wanted));_message=@"Alle Schalter aus.";saveSelection=YES;}
    if(command==50)_mouse=value.boolValue;
    MTTrainerState *state=[MTTrainerState new];state.context=_revision;
    state.overlayMouseActive=[_adapter setOverlayInteraction:_mouse];
    state.ready=(_mode==MTSessionSolo || _mode==MTSessionNetwork);
    state.status=_mode==MTSessionSolo ? @"Einzelspieler" : _mode==MTSessionNetwork ? @"Netzwerk" : _mode==MTSessionLoading ? @"Ladepause" : @"Nicht unterstützt";
    NSInteger feature=command>=100 && command<100+MTFeatureCount ? command-100 : -1;
    if(state.ready && command>=200 && command<200+MTFeatureCount && value){
        NSInteger i=command-200;const MTFeatureInfo *info=MTFeatureInfoAt(i);double n=value.doubleValue;
        if(info->numeric && isfinite(n) && n>=info->minimum && n<=info->maximum && (!info->integer || floor(n)==n)){
            saveSelection|=!info->oneShot && _values[i]!=n;_values[i]=n;
        }
    }
    if(state.ready && command>=300 && command<300+MTFeatureCount && value){
        NSInteger i=command-300;const MTFeatureInfo *info=MTFeatureInfoAt(i);
        if(info->implemented && !info->oneShot){_wanted[i]=value.boolValue;saveSelection=YES;}
    }
    if(state.ready && feature>=0 && MTFeatureInfoAt(feature)->implemented){
        const MTFeatureInfo *info=MTFeatureInfoAt(feature);
        if(!info->oneShot){_wanted[feature]=!_wanted[feature];saveSelection=YES;_message=[NSString stringWithFormat:@"%@: %@",info->title,_wanted[feature] ? @"AN / wartet" : @"AUS"];}
    }
    for(NSInteger i=0;i<MTFeatureCount;i++){
        MTFeatureState *f=state.features[i];f.value=_values[i];f.wanted=_wanted[i];
        if(state.ready){MTFeatureState *actual=[_adapter applyFeature:i wanted:_wanted[i] value:_values[i]];f.available=actual.available;f.active=_wanted[i] && actual.active;f.note=actual.note ?: context.note;}
        else f.note=_mode==MTSessionLoading ? @"Auswahl bleibt erhalten; wartet auf gültigen Einzelspieler." : context.note;
    }
    if(state.ready && feature>=0 && MTFeatureInfoAt(feature)->implemented && MTFeatureInfoAt(feature)->oneShot){
        // The validated context is sufficient; no unrelated switch gates actions.
        _message=[_adapter performOneShot:feature value:_values[feature]];
    }
    state.message=state.ready ? _message : context.note;
    if(saveSelection)state.selectionToSave=MTSelectionForFeatures(state.features);
    return state;
}
- (void)submit:(NSInteger)command value:(NSNumber *)value {
    NSAssert(NSThread.isMainThread,@"UI commands originate on main thread");
    NSDictionary *request=@{@"command":@(command),@"value":value ?: NSNull.null,@"context":@(_state.context)};
    if(_inFlight){
        if(command==50 || command==MTTrainerDisableAll){
            NSIndexSet *old=[_queue indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry,NSUInteger index,BOOL *stop){(void)index;(void)stop;NSInteger n=[entry[@"command"] integerValue];return command==MTTrainerDisableAll ? n!=50 : n==50;}];
            [_queue removeObjectsAtIndexes:old];[_queue insertObject:request atIndex:0];
        }else if(command!=MTTrainerPoll && _queue.count<16)[_queue addObject:request];
        return;
    }
    [self dispatch:request];
}
- (void)dispatch:(NSDictionary *)request {
    _inFlight=YES;
    [_adapter onGameThread:^{@autoreleasepool{
        id value=request[@"value"];
        MTTrainerState *next=[self update:[request[@"command"] integerValue] value:value==NSNull.null ? nil : value expected:[request[@"context"] unsignedLongLongValue]];
        dispatch_async(dispatch_get_main_queue(),^{
            self.state=next;self->_inFlight=NO;if(self.stateChanged)self.stateChanged(next);
            if(next.selectionToSave && self.selectionChanged)self.selectionChanged(next.selectionToSave);
            if(!next.ready){NSIndexSet *old=[self->_queue indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry,NSUInteger index,BOOL *stop){(void)index;(void)stop;NSInteger n=[entry[@"command"] integerValue];return n!=50 && n!=MTTrainerDisableAll;}];[self->_queue removeObjectsAtIndexes:old];}
            if(self->_queue.count){NSDictionary *entry=self->_queue.firstObject;[self->_queue removeObjectAtIndex:0];[self dispatch:entry];}
        });
    }}];
}
- (void)poll {[self submit:MTTrainerPoll value:nil];}
- (void)performAction:(MTTrainerAction)action {if(action==MTTrainerPoll || action==MTTrainerDisableAll)[self submit:action value:nil];}
- (void)setWanted:(BOOL)wanted forFeature:(MTFeature)feature {const MTFeatureInfo *info=MTFeatureInfoAt(feature);if(info && info->implemented && !info->oneShot)[self submit:300+feature value:@(wanted)];}
- (void)performFeature:(MTFeature)feature {if(MTFeatureInfoAt(feature))[self submit:100+feature value:nil];}
- (void)setValue:(double)value forFeature:(MTFeature)feature {const MTFeatureInfo *info=MTFeatureInfoAt(feature);if(info && info->numeric && isfinite(value) && value>=info->minimum && value<=info->maximum && (!info->integer || floor(value)==value))[self submit:200+feature value:@(value)];}
- (void)setOverlayInteraction:(BOOL)enabled {[self submit:50 value:@(enabled)];}
@end
