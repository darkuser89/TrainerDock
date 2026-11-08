// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "DecimaEngine.h"
#include <math.h>
@interface MHTNativeAdapter () {
    BOOL _bound,_wanted[MTFeatureCount],_mouseWanted;
    MHTDSOwner _owner;
    MHTDSTimeControl _time;
    float _timeValue;
    MHTDSCapacityControl _capacity;
    float _capacityValue;
    uintptr_t _bbRequestSystem;
}
@end
@implementation MHTNativeAdapter
- (instancetype)init{
    if((self=[super init])){_bound=MHTDSAttachEngine();__weak MHTNativeAdapter *weak=self;MHTDSSetMaintenance(^{[weak maintain];});}return self;
}
- (void)onGameThread:(dispatch_block_t)work{MHTDSSchedule(work);}
- (MTGameContext *)captureContext{
    MTGameContext *context=[MTGameContext new];
    if(!_bound){context.note=@"Keine bestätigte Engine-Zustellung für diesen Build.";return context;}
    MHTDSOwner owner={0};MHTDSVitals vitals={0};
    if(!MHTDSCaptureOwner(&owner) || !MHTDSReadVitals(owner,&vitals)){context.kind=MTSessionLoading;context.identity=@"loading";context.note=@"Warte auf einen eindeutig zugeordneten lokalen Spieler.";return context;}
    context.kind=MTSessionSolo;
    context.identity=[NSString stringWithFormat:@"%lx:%lx:%lx:%lx:%lx:%lx",(unsigned long)owner.pool,(unsigned long)owner.actor,(unsigned long)owner.entity,(unsigned long)owner.component,(unsigned long)owner.vitals,(unsigned long)owner.parameters];
    context.note=@"Lokaler Spieler bestätigt.";return context;
}
- (void)releaseEffects{MHTDSClearTime(&_time);MHTDSClearCapacity(&_capacity);MHTDSClearBBRequest(_bbRequestSystem);_bbRequestSystem=0;memset(_wanted,0,sizeof(_wanted));memset(&_owner,0,sizeof(_owner));}
- (BOOL)refill:(MTFeature)feature owner:(MHTDSOwner)owner values:(MHTDSVitals)v{
    switch(feature){
        case MTFeatureHealth:return v.blood>=v.maximumBlood || MHTDSSetBlood(owner,v.maximumBlood);
        case MTFeatureConsciousness:return v.consciousness>=v.maximumConsciousness || MHTDSFillConsciousness(owner);
        case MTFeatureStamina:return v.stamina>=v.maximumStamina || MHTDSAddStamina(owner,v.maximumStamina-v.stamina);
        case MTFeatureFatigue:return fabsf(v.fatigue)<0.001f || MHTDSSetFatigue(owner,0);
        case MTFeatureEquipmentDurability:return v.shoes>=v.maximumShoes || MHTDSRecoverShoes(owner);
        case MTFeatureEquipmentBattery:return v.battery>=v.maximumBattery || MHTDSRecoverBattery(owner);
        case MTFeatureBalance:return v.standReserve>=v.maximumStandReserve || MHTDSAddStandReserve(owner,v.maximumStandReserve-v.standReserve);
        case MTFeatureGameSpeed:return MHTDSSetTime(owner,_timeValue,&_time);
        case MTFeatureCapacity:return MHTDSSetCapacity(owner,_capacityValue,&_capacity);
        case MTFeatureBBStress:{BOOL ok=MHTDSSetBBStressRate(owner,0);if(ok)_bbRequestSystem=owner.system;return ok;}
        default:return NO;
    }
}
- (void)maintain{
    if(_mouseWanted)MHTDSOverlayInteraction(YES);
    BOOL any=NO;for(NSInteger i=0;i<MTFeatureCount;i++)any|=_wanted[i];if(!any)return;
    MHTDSOwner current={0};MHTDSVitals v={0};if(!MHTDSCaptureOwner(&current) || memcmp(&current,&_owner,sizeof(current)) || !MHTDSReadVitals(current,&v)){[self releaseEffects];return;}
    for(NSInteger i=0;i<MTFeatureCount;i++)if(_wanted[i])[self refill:i owner:current values:v];
}
- (BOOL)setOverlayInteraction:(BOOL)wanted{_mouseWanted=wanted;return MHTDSOverlayInteraction(wanted);}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value{
    MTFeatureState *state=[MTFeatureState new];const MTFeatureInfo *info=MTFeatureInfoAt(feature);state.note=info ? info->detail : @"Unbekannte Funktion.";
    if(!info || !info->implemented)return state;
    MHTDSOwner owner={0};MHTDSVitals v={0};if(!MHTDSCaptureOwner(&owner) || !MHTDSReadVitals(owner,&v))return state;
    if(memcmp(&_owner,&owner,sizeof(owner))){[self releaseEffects];_owner=owner;}
    state.available=YES;if(info->oneShot)return state;
    if(feature==MTFeatureEquipmentDurability && (v.maximumShoes<=0 || v.shoes<0))state.available=NO;
    if(feature==MTFeatureEquipmentBattery && (v.maximumBattery<=0 || v.battery<0))state.available=NO;
    if(feature==MTFeatureBalance && (v.maximumStandReserve<=0 || v.maximumStandReserve>1000000 || v.standReserve<0))state.available=NO;
    if(feature==MTFeatureBBStress){
        state.available=v.maximumBBStress>0 && v.maximumBBStress<=1000000 && v.bbStress>=0 && v.bbStress<=v.maximumBBStress
            && v.displayBBStress>=0 && v.displayBBStress<=v.maximumBBStress;
        if(!wanted || !state.available){MHTDSClearBBRequest(_bbRequestSystem);_bbRequestSystem=0;}
    }
    if(feature==MTFeatureGameSpeed){
        float scales[3];MHTDSTimeRequest request;
        state.available=MHTDSReadTime(owner,scales) && MHTDSPrepareTimeRequest((float)value,&request);
        if(state.available)_timeValue=(float)value;
        if(!wanted || !state.available)MHTDSClearTime(&_time);
    }
    if(feature==MTFeatureCapacity){
        float bases[2],effective[2];state.available=isfinite(value) && value>=1 && value<=9999 && floor(value)==value
            && MHTDSReadCapacity(owner,bases,effective);
        if(state.available)_capacityValue=(float)value;
        if(!wanted || !state.available)MHTDSClearCapacity(&_capacity);
    }
    _wanted[feature]=wanted && state.available;
    if(!wanted || !state.available)return state;
    if(![self refill:feature owner:owner values:v] || !MHTDSReadVitals(owner,&v))return state;
    switch(feature){
        case MTFeatureHealth:state.active=MHTDSResourceFull(v.blood,v.maximumBlood);break;
        case MTFeatureConsciousness:state.active=MHTDSResourceFull(v.consciousness,v.maximumConsciousness);break;
        case MTFeatureStamina:state.active=MHTDSResourceFull(v.stamina,v.maximumStamina);break;
        case MTFeatureFatigue:state.active=fabsf(v.fatigue)<0.01f;break;
        case MTFeatureEquipmentBattery:state.active=MHTDSResourceFull(v.battery,v.maximumBattery);break;
        case MTFeatureEquipmentDurability:state.active=MHTDSResourceFull(v.shoes,v.maximumShoes);break;
        case MTFeatureBalance:state.active=MHTDSResourceFull(v.standReserve,v.maximumStandReserve);break;
        case MTFeatureGameSpeed:{float scales[3];state.active=MHTDSReadTime(owner,scales)
            && fabsf(scales[0]-_timeValue)<0.001f && fabsf(scales[1]-_timeValue)<0.001f && fabsf(scales[2]-_timeValue)<0.001f;break;}
        case MTFeatureCapacity:{float bases[2],effective[2];state.active=MHTDSReadCapacity(owner,bases,effective)
            && bases[0]==_capacityValue && bases[1]==_capacityValue && effective[1]>=_capacityValue-0.01f;break;}
        case MTFeatureBBStress:state.active=fabsf(v.bbStress)<0.01f && fabsf(v.displayBBStress)<0.01f;break;
        default:break;
    }return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value{
    MHTDSOwner owner={0};MHTDSVitals v={0};
    if(feature!=MTFeatureCrystals || !isfinite(value) || floor(value)!=value || value<0 || value>99999 || !MHTDSCaptureOwner(&owner) || !MHTDSSetCrystals(owner,(int32_t)value) || !MHTDSReadVitals(owner,&v) || v.crystals!=(int32_t)value)return @"Native Aktion nicht bestätigt; nichts als erfolgreich gemeldet.";
    return [NSString stringWithFormat:@"Chirale Kristalle: %d",v.crystals];
}
@end
