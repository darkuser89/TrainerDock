// SPDX-License-Identifier: GPL-3.0-only
#import "CyberpunkEffects.h"
#import "CyberpunkMetadata.h"
#include <stdatomic.h>
static NSData *CPValue(const void *p,NSUInteger n){return [NSData dataWithBytes:p length:n];}
static uintptr_t CPPointer(NSData *v){uintptr_t p=0;if(v.length==16)memcpy(&p,v.bytes,8);return p;}
static BOOL CPTrue(NSData *v){return v.length==1 && *(const uint8_t *)v.bytes;}
@implementation CPEffects {
    CPNativeBridge *_native;
    NSDictionary *_getStats,*_getValue,*_add,*_remove,*_cast;
    NSData *_systemWeak,*_playerWeak,*_statsID;
    NSString *_identity,*_failure;
    BOOL _oneHitWanted,_damageWanted;double _damageMultiplier;
    NSData *_world;
    NSMutableDictionary *_bindings,*_systems,*_inventory,*_progressOptions,*_progressReadback;
    NSString *_timeReason; double _timeValue; BOOL _timeOwned,_clockOwned,_invisibleOwned; NSNumber *_clockLast;
    NSMutableDictionary<NSNumber *,NSMutableDictionary *> *_records;
    NSData *_stateContextWeak,*_scriptInterfaceWeak;
    BOOL _captureInstalled,_superInstalled,_superWanted,_doubleWanted,_frameInstalled,_doubleConfirmed,_jumpOwned;
    uint64_t _superCount,_savedJumpState;
    int32_t _savedJumpCount;
    BOOL _flyWanted,_heightWanted,_flySpeedWanted,_flying,_flightConfirmed,_speedConfirmed,_speedPending;double _flyHeight,_flySpeed,_anchorZ,_lastFrameTime;
    float _flightTarget[4],_motionOrigin[3];_Atomic(uint32_t) _movementInput;
    BOOL _defenseInstalled,_defenseWanted,_defenseVerified;double _defenseFactor;
    uint64_t _defenseCount;float _damageBefore,_damageAfter;
    BOOL _timerCaptureInstalled,_breachWanted,_timerOwned;NSData *_timerWeak;
}
- (instancetype)initWithNative:(CPNativeBridge *)native {
    if((self=[super init])){_native=native;_records=[NSMutableDictionary new];_bindings=[NSMutableDictionary new];_systems=[NSMutableDictionary new];_inventory=[NSMutableDictionary new];_progressOptions=[NSMutableDictionary new];_progressReadback=[NSMutableDictionary new];_timeReason=[@"CyberpunkTrainer_" stringByAppendingString:NSUUID.UUID.UUIDString];}return self;
}
- (NSData *)call:(NSDictionary *)binding context:(uintptr_t)context args:(NSArray *)args size:(NSUInteger)size {
    NSError *error=nil;NSData *result=[_native invoke:binding context:context arguments:args resultSize:size error:&error];
    if(error)_failure=error.localizedDescription;return result;
}
- (BOOL)bindings {
    if(_getValue)return YES;
    _getStats=[_native resolveClass:@"ScriptGameInstance" method:@"GetStatsSystem" parameters:@[@"ScriptGameInstance"] result:@"handle:gameStatsSystem"];
    _getValue=[_native resolveClass:@"gameStatsSystem" method:@"GetStatValue" parameters:@[@"gameStatsObjectID",@"gamedataStatType"] result:@"Float"];
    _add=[_native resolveClass:@"gameStatsSystem" method:@"AddModifier" parameters:@[@"gameStatsObjectID",@"handle:gameStatModifierData_Deprecated"] result:@"Bool"];
    _remove=[_native resolveClass:@"gameStatsSystem" method:@"RemoveModifier" parameters:@[@"gameStatsObjectID",@"handle:gameStatModifierData_Deprecated"] result:@"Bool"];
    _cast=[_native resolveClass:@"$global" method:@"Cast;EntityID;StatsObjectID" parameters:@[@"entEntityID"] result:@"gameStatsObjectID"];
    BOOL ready=_getStats && _getValue && _add && _remove && _cast
        && [_native supportsHandleClass:@"gameStatsSystem" weak:YES]
        && [_native supportsHandleClass:@"gameStatModifierData_Deprecated" weak:NO];
    if(!ready){_getValue=nil;_failure=@"Native Stat-Bindungen fehlen.";}return ready;
}
- (BOOL)bindWorld:(NSData *)world player:(NSData *)player entityID:(uint64_t)entity identity:(NSString *)identity {
    if(!_native.insideEngineCallback || ![self bindings])return NO;
    if([_identity isEqual:identity] && _statsID.length==16)return YES;
    if(![self releaseEffects])return NO;
    [_native destroyValue:_systemWeak type:@"whandle:gameStatsSystem"];
    [_native destroyValue:_playerWeak type:@"whandle:gameObject"];
    for(NSString *cls in _systems)[_native destroyValue:_systems[cls] type:[@"whandle:" stringByAppendingString:cls]];
    [_systems removeAllObjects];
    _systemWeak=nil;_playerWeak=nil;_statsID=nil;_identity=nil;_world=nil;
    NSData *system=[self call:_getStats context:0 args:@[world] size:16];
    @try {
        if(!CPPointer(system) || !CPPointer(player))return NO;
        _statsID=[self call:_cast context:0 args:@[CPValue(&entity,8)] size:16];
        _systemWeak=[_native weakFromStrong:system className:@"gameStatsSystem"];
        _playerWeak=[_native weakFromStrong:player className:@"gameObject"];
        if(_statsID.length!=16 || !_systemWeak || !_playerWeak)return NO;
        _identity=[identity copy];_world=[world copy];return YES;
    } @finally {[_native destroyValue:system type:@"handle:gameStatsSystem"];}
}
- (NSNumber *)stat:(NSString *)name {return [_native enumType:@"gamedataStatType" member:name];}
- (NSNumber *)readStat:(int32_t)stat system:(uintptr_t)system {return [self readStat:stat system:system id:_statsID];}
- (NSNumber *)readStat:(int32_t)stat system:(uintptr_t)system id:(NSData *)statsID {
    NSData *data=[self call:_getValue context:system args:@[statsID,CPValue(&stat,4)] size:4];
    float value=NAN;if(data.length==4)memcpy(&value,data.bytes,4);return isfinite(value) ? @(value) : nil;
}
- (BOOL)removeFeature:(NSNumber *)feature {
    NSMutableDictionary *record=_records[feature];if(!record)return YES;
    NSData *system=[_native lockWeak:_systemWeak];
    @try {
        if(!CPPointer(system)){
            if(![[_native weakIsExpired:_systemWeak] isEqual:@YES])return NO;
        }else if(!CPTrue([self call:_remove context:CPPointer(system) args:@[record[@"id"],record[@"modifier"]] size:1]))return NO;
        if(CPPointer(system)){
            int32_t stat=[record[@"stat"] intValue];NSNumber *after=[self readStat:stat system:CPPointer(system) id:record[@"id"]];
            record[@"removedReadback"]=after ?: @"unavailable";
        }
        [_native destroyValue:record[@"modifier"] type:@"handle:gameStatModifierData_Deprecated"];
        if(record[@"ownerWeak"])[_native destroyValue:record[@"ownerWeak"] type:@"whandle:gameItemData"];
        [_records removeObjectForKey:feature];return YES;
    } @finally {[_native destroyValue:system type:@"handle:gameStatsSystem"];}
}
- (BOOL)releaseEffects {
    if(!_native.insideEngineCallback)return _records.count==0;
    _oneHitWanted=NO;_damageWanted=NO;
    [self clearLocomotion];[_native removeScriptObserver:@"defense"];_defenseInstalled=NO;_defenseWanted=NO;_defenseVerified=NO;
    BOOL timerRemoved=[self clearBreach];[_native removeScriptObserver:@"breachOwner"];_timerCaptureInstalled=NO;_breachWanted=NO;
    if(timerRemoved){[_native destroyValue:_timerWeak type:@"whandle:gameuiHackingMinigameGameController"];_timerWeak=nil;}
    [_native clearProgression];[_progressOptions removeAllObjects];[_progressReadback removeAllObjects];
    [_inventory removeAllObjects];
    BOOL removed=timerRemoved;for(NSNumber *feature in _records.allKeys)if(![self removeFeature:feature])removed=NO;
    if(_timeOwned && ![self clearTime])removed=NO;
    if(_clockOwned && ![self clearClock])removed=NO;
    if(_invisibleOwned && ![self clearInvisible])removed=NO;
    if(!removed)_failure=@"Eigener Stat-Modifikator noch nicht zurückgenommen.";return removed;
}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    if(feature==MTFeatureOneHitKill || feature==MTFeatureDamageMultiplier)return [self damageFeature:feature wanted:wanted value:value];
    if(feature==MTFeatureDefenseMultiplier)return [self defenseFeature:wanted value:value];
    if(feature==MTFeatureBreachTimer)return [self breachFeature:wanted value:value];
    if(feature==MTFeatureSuperJump || feature==MTFeatureDoubleJump || feature==MTFeatureFly || feature==MTFeatureFlyHeight || feature==MTFeatureFlySpeed)
        return [self locomotionFeature:feature wanted:wanted value:value];
    if(feature>=MTFeatureXP && feature<=MTFeatureSkillXPMultiplier)return [self progressionFeature:feature wanted:wanted value:value];
    if(MTFeatureInfoAt(feature)->oneShot){
        state.available=_identity!=nil;state.note=@"Explizite Einmalaktion; Zielwert wird nativ zurückgelesen.";return state;
    }
    if(feature==MTFeatureAmmo || feature==MTFeatureKeepItems || feature==MTFeatureResources || feature==MTFeatureQuickhackComponents)
        return [self inventoryFeature:feature wanted:wanted value:value];
    if(feature==MTFeatureNoReload || feature==MTFeatureAccuracy || feature==MTFeatureRecoil)return [self weaponFeature:feature wanted:wanted value:value];
    if(feature==MTFeatureStealth)return [self invisibleFeature:wanted value:value];
    if(feature==MTFeatureFreezeDaytime)return [self clockFeature:wanted value:value];
    if(feature==MTFeatureGameSpeed)return [self timeFeature:wanted value:value];
    if(feature==MTFeatureRAM || feature==MTFeatureHealingCooldown || feature==MTFeatureGrenadeCooldown || feature==MTFeatureProjectileCooldown)
        return [self poolFeature:feature wanted:wanted value:value];
    return [self applyStatFeature:feature wanted:wanted value:value];
}
- (MTFeatureState *)applyStatFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    NSString *statName=nil;float amount=0;NSString *modeName=@"Additive";
    switch(feature){
        case MTFeatureStamina:statName=@"CanIgnoreStamina";amount=1;break;
        case MTFeatureSpeed:statName=@"MaxSpeed";amount=(float)value;modeName=@"Multiplier";break;
        case MTFeatureCarryWeight:statName=@"CarryCapacity";amount=(float)value;modeName=@"Target";break;
        case MTFeatureCyberwareCapacity:statName=@"HumanityOverallocationPossible";amount=1;break;
        case MTFeatureDamageMultiplier:statName=@"AllDamageDonePercentBonus";amount=(float)value;modeName=@"Percent";break;
        case MTFeatureOneHitKill:statName=@"AllDamageDonePercentBonus";amount=100000;modeName=@"Percent";break;
        default:state.note=@"Native Funktion noch nicht angebunden.";return state;
    }
    if(!_native.insideEngineCallback || !_identity || !isfinite(amount)){state.note=_failure ?: @"Lokale Stat-Bindung fehlt.";return state;}
    NSNumber *key=@(feature);NSMutableDictionary *record=_records[key];
    if(record && (!wanted || [record[@"value"] doubleValue]!=value)){
        if(![self removeFeature:key]){state.note=@"Eigener Stat-Modifikator konnte nicht entfernt werden.";return state;}record=nil;
    }
    if(!wanted){state.available=YES;state.note=@"Eigener Stat-Modifikator aus.";return state;}
    NSNumber *statValue=[self stat:statName],*mode=[_native enumType:@"gameStatModifierType" member:([modeName isEqual:@"Multiplier"] ? modeName : @"Additive")];
    NSData *system=[_native lockWeak:_systemWeak],*player=[_native lockWeak:_playerWeak];
    @try {
        if(!CPPointer(system) || !CPPointer(player) || !statValue || !mode){state.note=@"Stat oder lokaler Besitzer fehlt.";return state;}
        int32_t stat=statValue.intValue;
        if(!record){
            NSNumber *before=[self readStat:stat system:CPPointer(system)];
            if(!before){state.note=@"Ursprungswert nicht lesbar.";return state;}
            if([modeName isEqual:@"Target"])amount-=before.floatValue;
            if([modeName isEqual:@"Percent"])amount=(100+before.floatValue)*(amount-1);
            NSError *error=nil;NSData *modifier=[_native createInstance:@"gameConstantStatModifierData_Deprecated" error:&error];
            if(!modifier){state.note=error.localizedDescription;return state;}
            BOOL retained=NO;
            @try {
                int32_t modifierType=mode.intValue;
                if(![_native writeScalarProperty:@"statType" className:@"gameConstantStatModifierData_Deprecated" object:modifier type:@"gamedataStatType" value:CPValue(&stat,4)]
                   || ![_native writeScalarProperty:@"modifierType" className:@"gameConstantStatModifierData_Deprecated" object:modifier type:@"gameStatModifierType" value:CPValue(&modifierType,4)]
                   || ![_native writeScalarProperty:@"value" className:@"gameConstantStatModifierData_Deprecated" object:modifier type:@"Float" value:CPValue(&amount,4)]){
                    state.note=@"Native Modifikator-Felder nicht bestätigt.";return state;
                }
                if(!CPTrue([self call:_add context:CPPointer(system) args:@[_statsID,modifier] size:1])){state.note=@"Native AddModifier nicht bestätigt.";return state;}
                float expected=[modeName isEqual:@"Multiplier"] ? before.floatValue*amount : before.floatValue+amount;
                record=[@{@"id":[_statsID copy],@"modifier":modifier,@"value":@(value),@"before":before,@"expected":@(expected),@"stat":@(stat)} mutableCopy];
                _records[key]=record;retained=YES;
            } @finally {if(!retained)[_native destroyValue:modifier type:@"handle:gameStatModifierData_Deprecated"];}
        }
        NSNumber *actual=[self readStat:stat system:CPPointer(system)];float expected=[record[@"expected"] floatValue];
        state.available=YES;state.active=actual && fabs(actual.floatValue-expected)<=MAX(.01f,fabsf(expected)*.002f);
        state.note=state.active ? [NSString stringWithFormat:@"Nativ bestätigt: %@ = %.3g · eigene Quelle.",statName,actual.doubleValue] : @"Stat-Modifikator noch nicht nativ zurückgelesen.";
        return state;
    } @finally {[_native destroyValue:system type:@"handle:gameStatsSystem"];[_native destroyValue:player type:@"handle:gameObject"];}
}

- (NSDictionary *)binding:(NSString *)cls method:(NSString *)method params:(NSArray *)params result:(NSString *)result script:(BOOL)script {
    NSString *key=[NSString stringWithFormat:@"%@/%@/%d",cls,method,script];NSDictionary *binding=_bindings[key];
    if(binding)return binding;
    binding=script ? [_native resolveScriptClass:cls method:method parameters:params result:result] : [_native resolveClass:cls method:method parameters:params result:result];
    if(binding)_bindings[key]=binding;return binding;
}
- (NSData *)system:(NSString *)cls getter:(NSString *)getter {
    NSData *weak=_systems[cls];if(weak)return [_native lockWeak:weak];
    NSDictionary *get=[self binding:@"ScriptGameInstance" method:getter params:@[@"ScriptGameInstance"] result:[@"handle:" stringByAppendingString:cls] script:NO];
    if(!get || !_world || ![_native supportsHandleClass:cls weak:YES])return nil;
    NSData *strong=[self call:get context:0 args:@[_world] size:16];
    if(CPPointer(strong))_systems[cls]=[_native weakFromStrong:strong className:cls];return strong;
}
- (NSData *)equipmentData {
    NSString *cls=@"EquipmentSystemPlayerData";NSData *cached=_systems[cls];
    if(cached){
        NSData *data=[_native lockWeak:cached];if(CPPointer(data))return data;
        [_native destroyValue:cached type:@"whandle:EquipmentSystemPlayerData"];[_systems removeObjectForKey:cls];
    }
    NSData *container=[self system:@"gameScriptableSystemsContainer" getter:@"GetScriptableSystemsContainer"],*system=nil,*player=[_native lockWeak:_playerWeak],*data=nil;
    @try {
        NSDictionary *get=[self binding:@"gameScriptableSystemsContainer" method:@"Get" params:@[@"CName"] result:@"handle:gameScriptableSystem" script:NO];
        if(!CPPointer(container) || !CPPointer(player) || !get || ![_native supportsHandleClass:cls weak:YES])return nil;
        uint64_t name=CPNameHash(@"EquipmentSystem");system=[self call:get context:CPPointer(container) args:@[CPValue(&name,8)] size:16];if(!CPPointer(system))return nil;
        data=[self script:@"EquipmentSystem" method:@"GetPlayerData" context:CPPointer(system) params:@[@"handle:gameObject"] args:@[player] result:@"handle:EquipmentSystemPlayerData" size:16];
        if(!CPPointer(data) || ![_native object:data isKindOf:cls]){[_native destroyValue:data type:@"handle:EquipmentSystemPlayerData"];return nil;}
        _systems[cls]=[_native weakFromStrong:data className:cls];
        return data;
    } @finally {[_native destroyValue:container type:@"handle:gameScriptableSystemsContainer"];[_native destroyValue:system type:@"handle:gameScriptableSystem"];[_native destroyValue:player type:@"handle:gameObject"];}
}
- (NSNumber *)hasProjectileLauncher {
    NSData *equipment=[self equipmentData],*transaction=[self system:@"gameTransactionSystem" getter:@"GetTransactionSystem"],*player=[_native lockWeak:_playerWeak],*itemWeak=nil,*itemData=nil;
    @try {
        NSNumber *areaValue=[_native enumType:@"gamedataEquipmentArea" member:@"ArmsCW"];
        NSDictionary *slot=[self binding:@"EquipmentSystemPlayerData" method:@"GetItemInEquipSlot;gamedataEquipmentAreaInt32" params:@[@"gamedataEquipmentArea",@"Int32"] result:@"gameItemID" script:YES];
        NSDictionary *getData=[self binding:@"gameTransactionSystem" method:@"GetItemData" params:@[@"handle:gameObject",@"gameItemID"] result:@"whandle:gameItemData" script:NO];
        if(!CPPointer(equipment) || !CPPointer(transaction) || !CPPointer(player) || !areaValue || !slot || !getData)return nil;
        int32_t area=areaValue.intValue,index=0;
        NSData *item=[self script:@"EquipmentSystemPlayerData" method:@"GetItemInEquipSlot;gamedataEquipmentAreaInt32" context:CPPointer(equipment) params:@[@"gamedataEquipmentArea",@"Int32"] args:@[CPValue(&area,4),CPValue(&index,4)] result:@"gameItemID" size:16];
        uint64_t id=0;if(item.length!=16)return nil;memcpy(&id,item.bytes,8);if(!id)return @NO;
        itemWeak=[self call:getData context:CPPointer(transaction) args:@[player,item] size:16];itemData=[_native lockWeak:itemWeak];
        if(!CPPointer(itemData))return nil;
        NSNumber *launcher=[_native enumType:@"gamedataItemType" member:@"Cyb_Launcher"];
        NSDictionary *getType=[self binding:@"gameItemData" method:@"GetItemType" params:@[] result:@"gamedataItemType" script:NO];
        NSData *type=[self call:getType context:CPPointer(itemData) args:@[] size:4];int32_t actual=-1;if(type.length==4)memcpy(&actual,type.bytes,4);
        return launcher && type.length==4 ? @(actual==launcher.intValue) : nil;
    } @finally {
        [_native destroyValue:equipment type:@"handle:EquipmentSystemPlayerData"];[_native destroyValue:transaction type:@"handle:gameTransactionSystem"];[_native destroyValue:player type:@"handle:gameObject"];
        [_native destroyValue:itemWeak type:@"whandle:gameItemData"];[_native destroyValue:itemData type:@"handle:gameItemData"];
    }
}
- (MTFeatureState *)poolFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    if(!wanted){state.available=YES;state.note=@"Nachfüllen aus.";return state;}
    if(feature==MTFeatureProjectileCooldown){
        NSNumber *equipped=[self hasProjectileLauncher];
        if(!equipped.boolValue){state.available=equipped!=nil;state.note=equipped ? @"Wartet auf einen eingebauten Projektilwerfer." : @"Native Ausrüstungsprüfung noch nicht bestätigt.";return state;}
    }
    NSString *poolName=feature==MTFeatureRAM ? @"Memory" : feature==MTFeatureHealingCooldown ? @"HealingItemsCharges" : feature==MTFeatureGrenadeCooldown ? @"GrenadesCharges" : @"ProjectileLauncherCharges";
    NSNumber *poolValue=[_native enumType:@"gamedataStatPoolType" member:poolName];
    NSData *system=[self system:@"gameStatPoolsSystem" getter:@"GetStatPoolsSystem"],*player=[_native lockWeak:_playerWeak];
    @try {
        NSDictionary *get=[self binding:@"gameStatPoolsSystem" method:@"GetStatPoolValue" params:@[@"gameStatsObjectID",@"gamedataStatPoolType",@"Bool"] result:@"Float" script:NO];
        NSDictionary *set=[self binding:@"gameStatPoolsSystem" method:@"RequestSettingStatPoolValue" params:@[@"gameStatsObjectID",@"gamedataStatPoolType",@"Float",@"whandle:gameObject",@"Bool",@"Bool"] result:@"Void" script:NO];
        if(!CPPointer(system) || !CPPointer(player) || !poolValue || !get || !set){state.note=@"Native Pool-Bindung fehlt.";return state;}
        int32_t pool=poolValue.intValue;uint8_t yes=1;float full=100;
        NSDictionary *active=[self binding:@"gameStatPoolsSystem" method:@"HasActiveStatPool" params:@[@"gameStatsObjectID",@"gamedataStatPoolType"] result:@"Bool" script:NO];
        if(!active || !CPTrue([self call:active context:CPPointer(system) args:@[_statsID,CPValue(&pool,4)] size:1])){state.available=YES;state.note=@"Wartet auf den aktiven Pool der passenden Ausrüstung.";return state;}
        [self call:set context:CPPointer(system) args:@[_statsID,CPValue(&pool,4),CPValue(&full,4),_playerWeak,CPValue(&yes,1),CPValue(&yes,1)] size:1];
        NSData *result=[self call:get context:CPPointer(system) args:@[_statsID,CPValue(&pool,4),CPValue(&yes,1)] size:4];float actual=NAN;if(result.length==4)memcpy(&actual,result.bytes,4);
        state.available=YES;state.active=isfinite(actual) && actual>=99.9f;state.note=[NSString stringWithFormat:@"Nativer %@-Pool: %.3g %%.",poolName,actual];return state;
    } @finally {[_native destroyValue:system type:@"handle:gameStatPoolsSystem"];[_native destroyValue:player type:@"handle:gameObject"];}
}
- (BOOL)clearTime {
    if(!_timeOwned)return YES;
    NSData *system=[_native lockWeak:_systems[@"gameTimeSystem"]];
    @try {
        if(!CPPointer(system)){
            if(![[_native weakIsExpired:_systems[@"gameTimeSystem"]] isEqual:@YES])return NO;
        } else {
            uint64_t reason=CPNameHash(_timeReason),none=0;
            NSDictionary *unset=[self binding:@"gameTimeSystem" method:@"UnsetTimeDilation" params:@[@"CName",@"CName"] result:@"Void" script:NO];
            NSDictionary *has=[self binding:@"gameTimeSystem" method:@"IsTimeDilationActive" params:@[@"CName"] result:@"Bool" script:NO];
            if(!unset || !has)return NO;
            [self call:unset context:CPPointer(system) args:@[CPValue(&reason,8),CPValue(&none,8)] size:1];
            NSData *actual=[self call:has context:CPPointer(system) args:@[CPValue(&reason,8)] size:1];if(actual.length!=1 || CPTrue(actual))return NO;
        }
        _timeOwned=NO;return YES;
    } @finally {[_native destroyValue:system type:@"handle:gameTimeSystem"];}
}
- (MTFeatureState *)timeFeature:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    if(!wanted){state.available=[self clearTime];state.note=state.available ? @"Eigene Zeitquelle entfernt und zurückgelesen." : @"Eigene Zeitquelle noch aktiv.";return state;}
    NSData *system=[self system:@"gameTimeSystem" getter:@"GetTimeSystem"];
    @try {
        NSDictionary *set=[self binding:@"gameTimeSystem" method:@"SetTimeDilation" params:@[@"CName",@"Float",@"Float",@"CName",@"CName",@"handle:tickScriptTimeDilationListener"] result:@"Void" script:NO];
        NSDictionary *get=[self binding:@"gameTimeSystem" method:@"GetActiveTimeDilation" params:@[@"CName",@"Bool"] result:@"Float" script:NO];
        if(!CPPointer(system) || !set || !get || !isfinite(value) || value<.1 || value>3){state.note=@"Native Zeitbindung fehlt.";return state;}
        uint64_t reason=CPNameHash(_timeReason),none=0;uint8_t yes=1;
        if(!_timeOwned || _timeValue!=value){
            float amount=(float)value,duration=-1;uint8_t null[16]={0};
            [self call:set context:CPPointer(system) args:@[CPValue(&reason,8),CPValue(&amount,4),CPValue(&duration,4),CPValue(&none,8),CPValue(&none,8),CPValue(null,16)] size:1];_timeOwned=YES;_timeValue=value;
        }
        NSData *result=[self call:get context:CPPointer(system) args:@[CPValue(&reason,8),CPValue(&yes,1)] size:4];float actual=NAN;if(result.length==4)memcpy(&actual,result.bytes,4);
        state.available=YES;state.active=isfinite(actual) && fabs(actual-value)<.001;state.note=[NSString stringWithFormat:@"Eigene native Zeitquelle: × %.3g.",actual];return state;
    } @finally {[_native destroyValue:system type:@"handle:gameTimeSystem"];}
}

- (NSData *)script:(NSString *)cls method:(NSString *)method context:(uintptr_t)context params:(NSArray *)params args:(NSArray *)args result:(NSString *)result size:(NSUInteger)size {
    NSDictionary *binding=[self binding:cls method:method params:params result:result script:YES];NSError *error=nil;
    NSData *value=[_native invokeScript:binding context:context arguments:args resultSize:size error:&error];
    if(error)_failure=error.localizedDescription;return value;
}
- (NSData *)development {
    NSData *weak=_systems[@"PlayerDevelopmentData"];if(weak)return [_native lockWeak:weak];
    NSData *container=[self system:@"gameScriptableSystemsContainer" getter:@"GetScriptableSystemsContainer"],*system=nil,*player=[_native lockWeak:_playerWeak],*data=nil;
    @try {
        if(!CPPointer(container) || !CPPointer(player))return nil;
        NSDictionary *get=[self binding:@"gameScriptableSystemsContainer" method:@"Get" params:@[@"CName"] result:@"handle:gameScriptableSystem" script:NO];
        if(!get)return nil;uint64_t name=CPNameHash(@"PlayerDevelopmentSystem");
        system=[self call:get context:CPPointer(container) args:@[CPValue(&name,8)] size:16];if(!CPPointer(system))return nil;
        data=[self script:@"PlayerDevelopmentSystem" method:@"GetDevelopmentData" context:CPPointer(system) params:@[@"handle:gameObject"] args:@[player] result:@"handle:PlayerDevelopmentData" size:16];
        if(CPPointer(data))_systems[@"PlayerDevelopmentData"]=[_native weakFromStrong:data className:@"PlayerDevelopmentData"];
        return data;
    } @finally {[_native destroyValue:container type:@"handle:gameScriptableSystemsContainer"];[_native destroyValue:system type:@"handle:gameScriptableSystem"];[_native destroyValue:player type:@"handle:gameObject"];}
}
static uint64_t CPTweakID(NSString *name){
    NSData *data=[name dataUsingEncoding:NSUTF8StringEncoding];if(data.length>255)return 0;
    uint32_t crc=UINT32_MAX;const uint8_t *bytes=data.bytes;
    for(NSUInteger i=0;i<data.length;i++){crc^=bytes[i];for(int b=0;b<8;b++)crc=(crc>>1)^(0xedb88320u & (0-(crc&1)));}
    return ((uint64_t)data.length<<32)|(crc^UINT32_MAX);
}
static NSNumber *CPInteger(NSData *data){int32_t value=0;if(data.length!=4)return nil;memcpy(&value,data.bytes,4);return @(value);}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {
    const MTFeatureInfo *info=MTFeatureInfoAt(feature);
    if(!_native.insideEngineCallback || !_identity || !info || !info->oneShot || !isfinite(value) || (info->numeric && (value<info->minimum || value>info->maximum)))return @"Aktion ohne gültigen lokalen Kontext/Wert verworfen.";
    if(feature==MTFeatureAddHour){
        NSData *system=[self system:@"gameTimeSystem" getter:@"GetTimeSystem"];
        @try {
            NSDictionary *get=[self binding:@"gameTimeSystem" method:@"GetGameTime" params:@[] result:@"GameTime" script:NO];
            NSDictionary *set=[self binding:@"gameTimeSystem" method:@"SetGameTimeBySeconds" params:@[@"Int32"] result:@"Void" script:NO];
            if(!CPPointer(system) || !get || !set)return @"Native Tageszeitbindung fehlt.";
            NSNumber *before=CPInteger([self call:get context:CPPointer(system) args:@[] size:4]);if(!before || before.longLongValue>INT32_MAX-3600)return @"Tageszeit nicht lesbar.";
            int32_t target=before.intValue+3600;
            [self call:set context:CPPointer(system) args:@[CPValue(&target,4)] size:1];
            NSNumber *after=CPInteger([self call:get context:CPPointer(system) args:@[] size:4]);
            return after && abs(after.intValue-target)<=1 ? [NSString stringWithFormat:@"Tageszeit +1 Stunde nativ bestätigt (%@ → %@).",before,after] : @"Zeitaktion noch nicht bestätigt.";
        } @finally {[_native destroyValue:system type:@"handle:gameTimeSystem"];}
    }
    if(feature==MTFeatureMoney){
        NSData *system=[self system:@"gameTransactionSystem" getter:@"GetTransactionSystem"],*player=[_native lockWeak:_playerWeak];
        @try {
            NSDictionary *from=[self binding:@"gameItemID" method:@"FromTDBID" params:@[@"TweakDBID"] result:@"gameItemID" script:NO];
            NSDictionary *quantity=[self binding:@"gameTransactionSystem" method:@"GetItemQuantity" params:@[@"handle:gameObject",@"gameItemID"] result:@"Int32" script:NO];
            NSDictionary *give=[self binding:@"gameTransactionSystem" method:@"GiveItemByTDBID" params:@[@"handle:gameObject",@"TweakDBID",@"Int32"] result:@"Bool" script:NO];
            NSDictionary *remove=[self binding:@"gameTransactionSystem" method:@"RemoveItem" params:@[@"handle:gameObject",@"gameItemID",@"Int32"] result:@"Bool" script:NO];
            if(!CPPointer(system) || !CPPointer(player) || !from || !quantity || !give || !remove)return @"Native Geldbindung fehlt.";
            uint64_t id=CPTweakID(@"Items.money");NSData *item=[self call:from context:0 args:@[CPValue(&id,8)] size:16];if(item.length!=16)return @"Geld-ItemID nicht bestätigt.";
            NSNumber *before=CPInteger([self call:quantity context:CPPointer(system) args:@[player,item] size:4]);if(!before || before.intValue<0)return @"Geldmenge nicht lesbar.";
            int32_t target=(int32_t)llround(value),delta=abs(target-before.intValue);
            if(delta){
                BOOL addition=target>before.intValue;
                NSData *result=[self call:addition ? give : remove context:CPPointer(system) args:@[player,addition ? CPValue(&id,8) : item,CPValue(&delta,4)] size:1];
                if(!CPTrue(result))return @"Native Geldänderung abgelehnt.";
            }
            NSNumber *after=CPInteger([self call:quantity context:CPPointer(system) args:@[player,item] size:4]);
            return after.intValue==target && after ? [NSString stringWithFormat:@"Geld nativ gesetzt und bestätigt: %@ → %@.",before,after] : @"Geldaktion noch nicht bestätigt.";
        } @finally {[_native destroyValue:system type:@"handle:gameTransactionSystem"];[_native destroyValue:player type:@"handle:gameObject"];}
    }
    NSString *member=nil,*enumType=nil,*getter=nil,*setter=nil;
    switch(feature){
        case MTFeatureAttributePoints:member=@"Attribute";break;
        case MTFeaturePerkPoints:member=@"Primary";break;
        case MTFeatureRelicPoints:member=@"Espionage";break;
        case MTFeaturePlayerLevel:member=@"Level";break;
        case MTFeatureStreetCredLevel:member=@"StreetCred";break;
        case MTFeatureHeadhunterLevel:member=@"CoolSkill";break;
        case MTFeatureNetrunnerLevel:member=@"IntelligenceSkill";break;
        case MTFeatureShinobiLevel:member=@"ReflexesSkill";break;
        case MTFeatureSoloLevel:member=@"StrengthSkill";break;
        case MTFeatureEngineerLevel:member=@"TechnicalAbilitySkill";break;
        default:return @"Native Einmalaktion fehlt.";
    }
    BOOL points=feature==MTFeatureAttributePoints || feature==MTFeaturePerkPoints || feature==MTFeatureRelicPoints;
    enumType=points ? @"gamedataDevelopmentPointType" : @"gamedataProficiencyType";
    getter=points ? @"GetDevPoints" : @"GetProficiencyLevel";setter=points ? @"SetDevelopmentsPoint" : @"SetLevel";
    NSNumber *kindValue=[_native enumType:enumType member:member];NSData *development=[self development];
    @try {
        if(!kindValue || !CPPointer(development))return _failure ?: @"Lokale Entwicklungsdaten nicht verfügbar.";
        int32_t kind=kindValue.intValue,target=(int32_t)llround(value);
        NSNumber *before=CPInteger([self script:@"PlayerDevelopmentData" method:getter context:CPPointer(development) params:@[enumType] args:@[CPValue(&kind,4)] result:@"Int32" size:4]);
        if(!before)return _failure ?: @"Entwicklungsdaten nicht lesbar.";
        NSArray *args=@[CPValue(&kind,4),CPValue(&target,4)],*params=@[enumType,@"Int32"];
        if(!points){
            NSNumber *reasonValue=[_native enumType:@"telemetryLevelGainReason" member:@"IsDebug"];
            if(!reasonValue)return @"Native Telemetrie-Enumeration fehlt.";int32_t reason=reasonValue.intValue;uint8_t debug=1;
            params=@[enumType,@"Int32",@"telemetryLevelGainReason",@"Bool"];args=@[CPValue(&kind,4),CPValue(&target,4),CPValue(&reason,4),CPValue(&debug,1)];
        }
        __block NSData *applied=nil;
        [_native withoutProgression:^{applied=[self script:@"PlayerDevelopmentData" method:setter context:CPPointer(development) params:params args:args result:@"Void" size:1];}];
        if(!applied)return _failure ?: @"Native Entwicklungsänderung abgelehnt.";
        NSNumber *after=CPInteger([self script:@"PlayerDevelopmentData" method:getter context:CPPointer(development) params:@[enumType] args:@[CPValue(&kind,4)] result:@"Int32" size:4]);
        return after && after.intValue==target ? [NSString stringWithFormat:@"%@ nativ bestätigt: %@ → %@.",info->title,before,after] : [NSString stringWithFormat:@"%@ nicht bestätigt (vorher %@, nachher %@).",info->title,before,after];
    } @finally {[_native destroyValue:development type:@"handle:PlayerDevelopmentData"];}
}

- (MTFeatureState *)inventoryFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;NSNumber *key=@(feature);
    if(!wanted){[_inventory removeObjectForKey:key];state.available=YES;state.note=@"Inventar-Nachfüllen aus.";return state;}
    NSData *system=[self system:@"gameTransactionSystem" getter:@"GetTransactionSystem"],*player=[_native lockWeak:_playerWeak];
    NSMutableData *array=[NSMutableData dataWithLength:16];NSArray *items=nil;
    @try {
        NSDictionary *from=[self binding:@"gameItemID" method:@"FromTDBID" params:@[@"TweakDBID"] result:@"gameItemID" script:NO];
        NSDictionary *qty=[self binding:@"gameTransactionSystem" method:@"GetItemQuantity" params:@[@"handle:gameObject",@"gameItemID"] result:@"Int32" script:NO];
        NSDictionary *give=[self binding:@"gameTransactionSystem" method:@"GiveItemByTDBID" params:@[@"handle:gameObject",@"TweakDBID",@"Int32"] result:@"Bool" script:NO];
        if(!CPPointer(system) || !CPPointer(player) || !from || !qty || !give){state.note=@"Native Inventarbindung fehlt.";return state;}
        NSMutableDictionary *baseline=_inventory[key];if(!baseline){baseline=[NSMutableDictionary new];_inventory[key]=baseline;}
        BOOL materials=feature==MTFeatureResources || feature==MTFeatureQuickhackComponents;
        if(materials){
            NSArray *names=feature==MTFeatureResources ? @[@"Items.CommonMaterial1",@"Items.UncommonMaterial1",@"Items.RareMaterial1",@"Items.EpicMaterial1",@"Items.LegendaryMaterial1"] : @[@"Items.QuickHackUncommonMaterial1",@"Items.QuickHackRareMaterial1",@"Items.QuickHackEpicMaterial1",@"Items.QuickHackLegendaryMaterial1"];
            for(NSString *name in names){
                uint64_t tdb=CPTweakID(name);NSData *item=[self call:from context:0 args:@[CPValue(&tdb,8)] size:16];
                NSNumber *count=CPInteger([self call:qty context:CPPointer(system) args:@[player,item] size:4]);if(!count || count.intValue<0){state.note=@"Komponenten-Menge nicht lesbar.";return state;}
                NSString *itemKey=[item base64EncodedStringWithOptions:0];int32_t minimum=999;
                int32_t target=MAX(minimum,MAX(count.intValue,[baseline[itemKey][@"quantity"] intValue]));
                baseline[itemKey]=@{@"item":item,@"tdb":CPValue(&tdb,8),@"quantity":@(target)};
            }
        } else {
            NSDictionary *list=[self binding:@"gameTransactionSystem" method:@"GetItemList" params:@[@"handle:gameObject",@"array:whandle:gameItemData"] result:@"Bool" script:NO];
            NSDictionary *idGet=[self binding:@"gameItemData" method:@"GetID" params:@[] result:@"gameItemID" script:NO];
            NSDictionary *getQuantity=[self binding:@"gameItemData" method:@"GetQuantity" params:@[] result:@"Int32" script:NO];
            NSDictionary *hasTag=[self binding:@"gameItemData" method:@"HasTag" params:@[@"CName"] result:@"Bool" script:NO];
            if(!list || !idGet || !getQuantity || !hasTag || !CPTrue([self call:list context:CPPointer(system) args:@[player,array] size:1])){state.note=@"Nativer Inventar-Snapshot fehlt.";return state;}
            items=[_native copyItemWeakArray:array];if(!items){state.note=@"Inventargröße/Weak-Handles nicht gültig.";return state;}
            uint64_t quest=CPNameHash(@"Quest"),money=CPTweakID(@"Items.money");
            for(NSData *weak in items){
                NSData *itemData=[_native lockWeak:weak];
                @try {
                    if(!CPPointer(itemData))continue;
                    if(CPTrue([self call:hasTag context:CPPointer(itemData) args:@[CPValue(&quest,8)] size:1]))continue;
                    NSData *item=[self call:idGet context:CPPointer(itemData) args:@[] size:16];if(item.length!=16)continue;
                    uint64_t tdb=0;memcpy(&tdb,item.bytes,8);if(tdb==money)continue;
                    NSNumber *count=CPInteger([self call:getQuantity context:CPPointer(itemData) args:@[] size:4]);if(!count || count.intValue<=0)continue;
                    NSString *itemKey=[item base64EncodedStringWithOptions:0];
                    if(count.intValue>[baseline[itemKey][@"quantity"] intValue])baseline[itemKey]=@{@"item":item,@"tdb":CPValue(&tdb,8),@"quantity":count};
                } @finally {[_native destroyValue:itemData type:@"handle:gameItemData"];}
            }
        }
        if(!baseline.count){state.available=YES;state.note=@"Warte auf vorhandene verbrauchbare Items.";return state;}
        BOOL confirmed=YES;NSUInteger refills=0;
        for(NSDictionary *entry in baseline.allValues){
            NSNumber *current=CPInteger([self call:qty context:CPPointer(system) args:@[player,entry[@"item"]] size:4]);
            if(!current || current.intValue<0){confirmed=NO;continue;}
            int32_t delta=[entry[@"quantity"] intValue]-current.intValue;
            if(delta>0){
                if([entry[@"blocked"] boolValue]){confirmed=NO;continue;}
                NSDictionary *giveExact=[self binding:@"gameTransactionSystem" method:@"GiveItem" params:@[@"handle:gameObject",@"gameItemID",@"Int32",@"array:CName"] result:@"Bool" script:NO];
                uint8_t empty[16]={0};
                NSData *result=materials ? [self call:give context:CPPointer(system) args:@[player,entry[@"tdb"],CPValue(&delta,4)] size:1] : [self call:giveExact context:CPPointer(system) args:@[player,entry[@"item"],CPValue(&delta,4),CPValue(empty,16)] size:1];
                if(!CPTrue(result)){confirmed=NO;continue;}refills++;
                current=CPInteger([self call:qty context:CPPointer(system) args:@[player,entry[@"item"]] size:4]);
            }
            if(!current || current.intValue<[entry[@"quantity"] intValue]){
                confirmed=NO;NSMutableDictionary *blocked=[entry mutableCopy];blocked[@"blocked"]=@YES;baseline[[entry[@"item"] base64EncodedStringWithOptions:0]]=blocked;
            }
        }
        state.available=YES;state.active=confirmed;state.note=[NSString stringWithFormat:@"%lu native Item-Mengen geprüft; %lu nachgefüllt.",(unsigned long)baseline.count,(unsigned long)refills];return state;
    } @finally {
        for(NSData *weak in items)[_native destroyValue:weak type:@"whandle:gameItemData"];
        [_native destroyValue:array type:@"array:whandle:gameItemData"];
        [_native destroyValue:system type:@"handle:gameTransactionSystem"];[_native destroyValue:player type:@"handle:gameObject"];
    }
}

- (BOOL)modifierKey:(NSNumber *)key id:(NSData *)statsID statName:(NSString *)name amount:(float)amount multiplier:(BOOL)multiplier system:(uintptr_t)system {
    NSNumber *statValue=[self stat:name],*mode=[_native enumType:@"gameStatModifierType" member:multiplier ? @"Multiplier" : @"Additive"];
    if(!statValue || !mode)return NO;int32_t stat=statValue.intValue,modifierType=mode.intValue;
    NSMutableDictionary *record=_records[key];
    if(record && ![record[@"id"] isEqual:statsID]){if(![self removeFeature:key])return NO;record=nil;}
    if(!record){
        NSNumber *before=[self readStat:stat system:system id:statsID];if(!before)return NO;
        NSData *modifier=[_native createInstance:@"gameConstantStatModifierData_Deprecated" error:NULL];BOOL retained=NO;
        @try {
            if(!modifier || ![_native writeScalarProperty:@"statType" className:@"gameConstantStatModifierData_Deprecated" object:modifier type:@"gamedataStatType" value:CPValue(&stat,4)]
               || ![_native writeScalarProperty:@"modifierType" className:@"gameConstantStatModifierData_Deprecated" object:modifier type:@"gameStatModifierType" value:CPValue(&modifierType,4)]
               || ![_native writeScalarProperty:@"value" className:@"gameConstantStatModifierData_Deprecated" object:modifier type:@"Float" value:CPValue(&amount,4)]
               || !CPTrue([self call:_add context:system args:@[statsID,modifier] size:1]))return NO;
            float expected=multiplier ? before.floatValue*amount : before.floatValue+amount;
            record=[@{@"id":statsID,@"stat":@(stat),@"modifier":modifier,@"before":before,@"expected":@(expected)} mutableCopy];_records[key]=record;retained=YES;
        } @finally {if(!retained)[_native destroyValue:modifier type:@"handle:gameStatModifierData_Deprecated"];}
    }
    NSNumber *actual=[self readStat:stat system:system id:statsID];float expected=[record[@"expected"] floatValue];
    return actual && fabs(actual.floatValue-expected)<=MAX(.01f,fabsf(expected)*.002f);
}
- (MTFeatureState *)weaponFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    NSArray *names=feature==MTFeatureNoReload ? @[@"MagazineAutoRefill"] : feature==MTFeatureAccuracy ? @[@"SpreadDefaultX",@"SpreadDefaultY",@"SpreadMinX",@"SpreadMinY",@"SpreadMaxX",@"SpreadMaxY",@"SpreadAdsDefaultX",@"SpreadAdsDefaultY",@"SpreadAdsMinX",@"SpreadAdsMinY",@"SpreadAdsMaxX",@"SpreadAdsMaxY"] : @[@"RecoilKickMin",@"RecoilKickMax",@"RecoilKickMinADS",@"RecoilKickMaxADS",@"RecoilMaxLength",@"RecoilMaxLengthADS"];
    if(!wanted){
        BOOL done=YES;for(NSUInteger i=0;i<names.count;i++)if(![self removeFeature:@(1000+feature*32+i)])done=NO;
        state.available=done;state.note=done ? @"Eigene Waffen-Modifikatoren entfernt." : @"Eigene Waffenquelle noch gebunden.";return state;
    }
    NSData *transaction=[self system:@"gameTransactionSystem" getter:@"GetTransactionSystem"],*player=[_native lockWeak:_playerWeak],*weapon=nil,*itemWeak=nil,*itemData=nil,*stats=[_native lockWeak:_systemWeak];
    @try {
        NSDictionary *slot=[self binding:@"gameTransactionSystem" method:@"GetItemInSlot" params:@[@"handle:gameObject",@"TweakDBID"] result:@"handle:gameItemObject" script:NO];
        NSDictionary *getID=[self binding:@"gameItemObject" method:@"GetItemID" params:@[] result:@"gameItemID" script:NO];
        NSDictionary *getData=[self binding:@"gameTransactionSystem" method:@"GetItemData" params:@[@"handle:gameObject",@"gameItemID"] result:@"whandle:gameItemData" script:NO];
        NSDictionary *getStatsID=[self binding:@"gameItemData" method:@"GetStatsObjectID" params:@[] result:@"gameStatsObjectID" script:NO];
        if(!CPPointer(transaction) || !CPPointer(player) || !CPPointer(stats) || !slot || !getID || !getData || !getStatsID){state.note=@"Native Waffenbindung fehlt.";return state;}
        uint64_t slotID=CPTweakID(@"AttachmentSlots.WeaponRight");weapon=[self call:slot context:CPPointer(transaction) args:@[player,CPValue(&slotID,8)] size:16];
        if(!CPPointer(weapon)){for(NSUInteger i=0;i<names.count;i++)[self removeFeature:@(1000+feature*32+i)];state.available=YES;state.note=@"Warte auf tatsächlich gezogene rechte Waffe.";return state;}
        NSData *id=[self call:getID context:CPPointer(weapon) args:@[] size:16];if(id.length!=16)return state;
        itemWeak=[self call:getData context:CPPointer(transaction) args:@[player,id] size:16];itemData=[_native lockWeak:itemWeak];
        if(!CPPointer(itemData)){state.note=@"Aktuelle Waffe nicht im lokalen Inventar bestätigt.";return state;}
        NSData *statsID=[self call:getStatsID context:CPPointer(itemData) args:@[] size:16];if(statsID.length!=16)return state;
        BOOL confirmed=YES,changed=NO;
        for(NSUInteger i=0;i<names.count;i++){
            NSNumber *key=@(1000+feature*32+i);
            if(![self modifierKey:key id:statsID statName:names[i] amount:feature==MTFeatureNoReload ? 1 : 0 multiplier:feature!=MTFeatureNoReload system:CPPointer(stats)])confirmed=NO;
            NSMutableDictionary *record=_records[key];if(record && !record[@"ownerWeak"])record[@"ownerWeak"]=[_native weakFromStrong:itemData className:@"gameItemData"];changed|=fabs([record[@"before"] doubleValue]-[record[@"expected"] doubleValue])>.001;
        }
        state.available=YES;state.active=confirmed && changed;state.note=state.active ? @"Native Stats der tatsächlich ausgerüsteten Waffe bestätigt." : @"Warte auf wirksame Waffen-Stats/Rückleseprüfung.";return state;
    } @finally {
        [_native destroyValue:stats type:@"handle:gameStatsSystem"];[_native destroyValue:transaction type:@"handle:gameTransactionSystem"];[_native destroyValue:player type:@"handle:gameObject"];
        [_native destroyValue:weapon type:@"handle:gameItemObject"];[_native destroyValue:itemWeak type:@"whandle:gameItemData"];[_native destroyValue:itemData type:@"handle:gameItemData"];
    }
}

- (BOOL)clearClock {
    if(!_clockOwned)return YES;
    NSData *system=[_native lockWeak:_systems[@"gameTimeSystem"]];
    @try {
        if(CPPointer(system)){
            NSDictionary *set=[self binding:@"gameTimeSystem" method:@"SetPausedState" params:@[@"Bool",@"CName"] result:@"Void" script:NO];
            if(!set)return NO;uint8_t off=0;uint64_t reason=CPNameHash([_timeReason stringByAppendingString:@"_clock"]);
            if(![self call:set context:CPPointer(system) args:@[CPValue(&off,1),CPValue(&reason,8)] size:1])return NO;
        }else if(![[_native weakIsExpired:_systems[@"gameTimeSystem"]] isEqual:@YES])return NO;
        _clockOwned=NO;_clockLast=nil;return YES;
    } @finally {[_native destroyValue:system type:@"handle:gameTimeSystem"];}
}
- (MTFeatureState *)clockFeature:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    if(!wanted){state.available=[self clearClock];state.note=@"Eigene Tageszeit-Pause aus.";return state;}
    NSData *system=[self system:@"gameTimeSystem" getter:@"GetTimeSystem"];
    @try {
        NSDictionary *set=[self binding:@"gameTimeSystem" method:@"SetPausedState" params:@[@"Bool",@"CName"] result:@"Void" script:NO];
        NSDictionary *get=[self binding:@"gameTimeSystem" method:@"GetGameTime" params:@[] result:@"GameTime" script:NO];
        NSDictionary *paused=[self binding:@"gameTimeSystem" method:@"IsPausedState" params:@[] result:@"Bool" script:NO];
        if(!CPPointer(system) || !set || !get || !paused){state.note=@"Native Tageszeit-Pausenbindung fehlt.";return state;}
        if(!_clockOwned){
            uint8_t on=1;uint64_t reason=CPNameHash([_timeReason stringByAppendingString:@"_clock"]);
            if(![self call:set context:CPPointer(system) args:@[CPValue(&on,1),CPValue(&reason,8)] size:1])return state;_clockOwned=YES;
        }
        NSNumber *actual=CPInteger([self call:get context:CPPointer(system) args:@[] size:4]);
        state.available=YES;state.active=actual && [_clockLast isEqual:actual] && CPTrue([self call:paused context:CPPointer(system) args:@[] size:1]);
        state.note=[NSString stringWithFormat:@"Native Tageszeit: %@; eigene Pausenquelle.",actual];_clockLast=actual;return state;
    } @finally {[_native destroyValue:system type:@"handle:gameTimeSystem"];}
}

- (NSDictionary *)progressionSettings {
    return @{@"levelFactor":_progressOptions[@(MTFeatureXPMultiplier)] ?: @1,@"credFactor":_progressOptions[@(MTFeatureStreetCredMultiplier)] ?: @1,@"skillFactor":_progressOptions[@(MTFeatureSkillXPMultiplier)] ?: @1,
             @"levelMax":@(_progressOptions[@(MTFeatureXP)]!=nil),@"credMax":@(_progressOptions[@(MTFeatureStreetCred)]!=nil),@"skillMax":@(_progressOptions[@(MTFeatureSkillXP)]!=nil)};
}
- (MTFeatureState *)progressionFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    if(wanted)_progressOptions[@(feature)]=@(MTFeatureInfoAt(feature)->numeric ? value : 1);else {[_progressOptions removeObjectForKey:@(feature)];[_progressReadback removeObjectForKey:@(feature)];}
    if(!_progressOptions.count){[_native clearProgression];state.available=YES;state.note=@"Eigene XP-Regeln aus.";return state;}
    NSData *development=[self development];
    @try {
        NSDictionary *binding=[self binding:@"PlayerDevelopmentData" method:@"AddExperience" params:@[@"Int32",@"gamedataProficiencyType",@"telemetryLevelGainReason",@"Bool"] result:@"Void" script:YES];
        if(!CPPointer(development) || !binding || ![_native configureProgressionOwner:development binding:binding settings:[self progressionSettings]]){state.note=@"Lokale XP-Zustellung nicht bestätigt.";return state;}
        state.available=YES;if(!wanted){state.note=@"Eigene XP-Regel aus.";return state;}
        int group=feature==MTFeatureStreetCred || feature==MTFeatureStreetCredMultiplier ? 1 : feature==MTFeatureSkillXP || feature==MTFeatureSkillXPMultiplier ? 2 : 0;
        NSDictionary *observation=[_native progressionObservation];
        BOOL maximum=feature==MTFeatureXP || feature==MTFeatureStreetCred || feature==MTFeatureSkillXP;
        state.active=[observation[@"counts"][group] unsignedLongLongValue]>0 && (maximum ? [observation[@"maximum"][group] boolValue] : [observation[@"verified"][group] boolValue]);
        state.note=state.active ? [NSString stringWithFormat:@"XP nativ bestätigt: %@ → %@; eigene Regel.",observation[@"before"][group],observation[@"after"][group]] : @"Eigene Regel gebunden; wartet auf eine bestätigte XP-Vergabe.";return state;
    } @finally {[_native destroyValue:development type:@"handle:PlayerDevelopmentData"];}
}

- (BOOL)clearInvisible {
    if(!_invisibleOwned)return YES;
    NSData *player=[_native lockWeak:_playerWeak];
    @try {
        if(CPPointer(player)){
            uint8_t off=0;
            if(![self script:@"PlayerPuppet" method:@"SetInvisible" context:CPPointer(player) params:@[@"Bool"] args:@[CPValue(&off,1)] result:@"Void" size:1])return NO;
            NSData *actual=[self script:@"PlayerPuppet" method:@"IsInvisible" context:CPPointer(player) params:@[] args:@[] result:@"Bool" size:1];
            if(actual.length!=1 || CPTrue(actual))return NO;
        }else if(![[_native weakIsExpired:_playerWeak] isEqual:@YES])return NO;
        _invisibleOwned=NO;return YES;
    } @finally {[_native destroyValue:player type:@"handle:gameObject"];}
}
- (MTFeatureState *)invisibleFeature:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    if(!wanted){state.available=[self clearInvisible];state.note=state.available ? @"Eigene Unsichtbarkeit zurückgenommen und bestätigt." : @"Eigene Unsichtbarkeit noch gebunden.";return state;}
    NSData *player=[_native lockWeak:_playerWeak];
    @try {
        if(!CPPointer(player)){state.note=@"Kein lokaler Spieler.";return state;}
        NSData *actual=[self script:@"PlayerPuppet" method:@"IsInvisible" context:CPPointer(player) params:@[] args:@[] result:@"Bool" size:1];
        if(actual.length!=1){state.note=@"Native Sichtbarkeitsbindung fehlt.";return state;}
        if(!CPTrue(actual)){
            if(_invisibleOwned){_invisibleOwned=NO;state.note=@"Spiel hat den Sichtbarkeitszustand übernommen.";return state;}
            uint8_t on=1;
            if(![self script:@"PlayerPuppet" method:@"SetInvisible" context:CPPointer(player) params:@[@"Bool"] args:@[CPValue(&on,1)] result:@"Void" size:1])return state;
            _invisibleOwned=YES;actual=[self script:@"PlayerPuppet" method:@"IsInvisible" context:CPPointer(player) params:@[] args:@[] result:@"Bool" size:1];
        }
        state.available=YES;state.active=CPTrue(actual);state.note=state.active ? @"Native Unsichtbarkeit für die Gegnererkennung bestätigt." : @"Unsichtbarkeit noch nicht bestätigt.";return state;
    } @finally {[_native destroyValue:player type:@"handle:gameObject"];}
}

- (BOOL)captureLocomotion:(NSArray<NSData *> *)arguments {
    if(arguments.count!=2 || ![_native object:arguments[0] isKindOf:@"gamestateMachineStateContextScript"] || ![_native object:arguments[1] isKindOf:@"gamestateMachineGameScriptInterface"])return NO;
    NSData *owner=[_native readProperty:@"owner" className:@"gamestateMachineGameScriptInterface" object:arguments[1] type:@"whandle:gameObject"];
    @try {
        if(![owner isEqual:_playerWeak])return NO;
        NSData *state=[_native weakFromStrong:arguments[0] className:@"gamestateMachineStateContextScript"],*interface=[_native weakFromStrong:arguments[1] className:@"gamestateMachineGameScriptInterface"];
        if(!state || !interface){[_native destroyValue:state type:@"whandle:gamestateMachineStateContextScript"];[_native destroyValue:interface type:@"whandle:gamestateMachineGameScriptInterface"];return NO;}
        [_native destroyValue:_stateContextWeak type:@"whandle:gamestateMachineStateContextScript"];[_native destroyValue:_scriptInterfaceWeak type:@"whandle:gamestateMachineGameScriptInterface"];
        _stateContextWeak=state;_scriptInterfaceWeak=interface;return YES;
    } @finally {[_native destroyValue:owner type:@"whandle:gameObject"];}
}
- (BOOL)installLocomotionCapture {
    if(_captureInstalled)return YES;
    NSDictionary *binding=[self binding:@"LocomotionTransition" method:@"SetLocomotionParameters" params:@[@"handle:gamestateMachineStateContextScript",@"handle:gamestateMachineGameScriptInterface"] result:@"handle:gamestateMachineparameterTypeActionLocomotionParameters" script:YES];
    if(!binding)return NO;__weak CPEffects *weak=self;
    _captureInstalled=[_native setScriptObserver:@"localLocomotion" binding:binding methodName:@"SetLocomotionParameters;StateContextStateGameScriptInterface" handler:^(uintptr_t context,NSArray *args,NSData *result){(void)context;(void)result;[weak captureLocomotion:args];}];return _captureInstalled;
}
- (BOOL)installSuperJump {
    if(_superInstalled)return YES;
    NSDictionary *binding=[self binding:@"JumpEvents" method:@"ModifyJumpSpeed" params:@[@"handle:gamestateMachineStateContextScript",@"handle:gamestateMachineGameScriptInterface"] result:@"Void" script:YES];
    if(!binding)return NO;__weak CPEffects *weak=self;
    _superInstalled=[_native setScriptObserver:@"superJump" binding:binding methodName:@"ModifyJumpSpeed;StateContextStateGameScriptInterface" handler:^(uintptr_t context,NSArray *args,NSData *result){
        (void)context;(void)result;CPEffects *owner=weak;if(!owner || !owner->_superWanted || ![owner captureLocomotion:args])return;
        uint64_t name=CPNameHash(@"impulse");uint8_t no=0,yes=1;
        NSDictionary *get=[owner binding:@"gamestateMachineStateContextScript" method:@"GetVectorParameter" params:@[@"CName",@"Bool"] result:@"Vector4" script:NO];
        NSDictionary *set=[owner binding:@"gamestateMachineStateContextScript" method:@"SetTemporaryVectorParameter" params:@[@"CName",@"Vector4",@"Bool"] result:@"Void" script:NO];
        if(!get || !set)return;
        NSData *before=[owner call:get context:CPPointer(args[0]) args:@[CPValue(&name,8),CPValue(&no,1)] size:16];float impulse[4]={0};if(before.length!=16)return;memcpy(impulse,before.bytes,16);
        impulse[2]+=6;
        [owner call:set context:CPPointer(args[0]) args:@[CPValue(&name,8),CPValue(impulse,16),CPValue(&yes,1)] size:1];
        NSData *after=[owner call:get context:CPPointer(args[0]) args:@[CPValue(&name,8),CPValue(&no,1)] size:16];
        if(after.length==16 && !memcmp(after.bytes,impulse,16))owner->_superCount++;
    }];return _superInstalled;
}
- (BOOL)refreshFrameWork {
    BOOL wanted=_doubleWanted || _flyWanted;
    if(!wanted){[_native clearFrameWork];_frameInstalled=NO;return YES;}
    if(_frameInstalled)return YES;
    NSData *player=[_native lockWeak:_playerWeak];
    @try {__weak CPEffects *weak=self;_frameInstalled=[_native setFrameWork:^{[weak frameTick];} world:_world player:player];return _frameInstalled;}
    @finally {[_native destroyValue:player type:@"handle:gameObject"];}
}
- (void)restoreJumpCounter {
    if(!_jumpOwned)return;
    NSData *state=[_native lockWeak:_stateContextWeak];
    @try {
        if(CPPointer(state)){
            NSDictionary *get=[self binding:@"gamestateMachineStateContextScript" method:@"GetIntParameter" params:@[@"CName",@"Bool"] result:@"Int32" script:NO];
            NSDictionary *current=[self binding:@"gamestateMachineStateContextScript" method:@"GetStateMachineCurrentState" params:@[@"CName"] result:@"CName" script:NO];
            NSDictionary *set=[self binding:@"gamestateMachineStateContextScript" method:@"SetPermanentIntParameter" params:@[@"CName",@"Int32",@"Bool"] result:@"Void" script:NO];
            uint64_t name=CPNameHash(@"currentNumberOfJumps"),machine=CPNameHash(@"Locomotion"),actualState=0;uint8_t yes=1;
            NSData *stateName=[self call:current context:CPPointer(state) args:@[CPValue(&machine,8)] size:8];if(stateName.length==8)memcpy(&actualState,stateName.bytes,8);
            NSNumber *actual=CPInteger([self call:get context:CPPointer(state) args:@[CPValue(&name,8),CPValue(&yes,1)] size:4]);
            if(actual && actual.intValue==0 && actualState && actualState==_savedJumpState)[self call:set context:CPPointer(state) args:@[CPValue(&name,8),CPValue(&_savedJumpCount,4),CPValue(&yes,1)] size:1];
        }
    } @finally {[_native destroyValue:state type:@"handle:gamestateMachineStateContextScript"];_jumpOwned=NO;}
}
- (void)clearLocomotion {
    [_native clearFrameWork];_frameInstalled=NO;[self restoreJumpCounter];[_native removeScriptObserver:@"localLocomotion"];[_native removeScriptObserver:@"superJump"];
    [_native destroyValue:_stateContextWeak type:@"whandle:gamestateMachineStateContextScript"];[_native destroyValue:_scriptInterfaceWeak type:@"whandle:gamestateMachineGameScriptInterface"];
    _stateContextWeak=nil;_scriptInterfaceWeak=nil;_captureInstalled=NO;_superInstalled=NO;_superWanted=NO;_doubleWanted=NO;_flyWanted=NO;_heightWanted=NO;_flySpeedWanted=NO;_flying=NO;_flightConfirmed=NO;_speedConfirmed=NO;_speedPending=NO;_doubleConfirmed=NO;_superCount=0;_movementInput=0;
}
- (void)setMovementInput:(uint32_t)input {_movementInput=input&63;}
- (void)frameTick {
    if(_doubleWanted){
        NSData *state=[_native lockWeak:_stateContextWeak],*stats=[_native lockWeak:_systemWeak];
        @try {
            NSNumber *flag=[self stat:@"HasDoubleJump"],*enabled=flag && CPPointer(stats) ? [self readStat:flag.intValue system:CPPointer(stats)] : nil;
            if(CPPointer(state) && enabled.floatValue>=1){
                uint64_t name=CPNameHash(@"currentNumberOfJumps"),machine=CPNameHash(@"Locomotion");uint8_t yes=1;
                NSDictionary *get=[self binding:@"gamestateMachineStateContextScript" method:@"GetIntParameter" params:@[@"CName",@"Bool"] result:@"Int32" script:NO];
                NSDictionary *set=[self binding:@"gamestateMachineStateContextScript" method:@"SetPermanentIntParameter" params:@[@"CName",@"Int32",@"Bool"] result:@"Void" script:NO];
                NSDictionary *current=[self binding:@"gamestateMachineStateContextScript" method:@"GetStateMachineCurrentState" params:@[@"CName"] result:@"CName" script:NO];
                NSNumber *before=CPInteger([self call:get context:CPPointer(state) args:@[CPValue(&name,8),CPValue(&yes,1)] size:4]);
                if(before.intValue>=1 && before.intValue<64){
                    NSData *currentState=[self call:current context:CPPointer(state) args:@[CPValue(&machine,8)] size:8];if(currentState.length==8)memcpy(&_savedJumpState,currentState.bytes,8);
                    _savedJumpCount=before.intValue;int32_t zero=0;
                    [self call:set context:CPPointer(state) args:@[CPValue(&name,8),CPValue(&zero,4),CPValue(&yes,1)] size:1];_jumpOwned=YES;
                    NSNumber *after=CPInteger([self call:get context:CPPointer(state) args:@[CPValue(&name,8),CPValue(&yes,1)] size:4]);_doubleConfirmed=after && after.intValue==0;
                }
            }
        } @finally {[_native destroyValue:state type:@"handle:gamestateMachineStateContextScript"];[_native destroyValue:stats type:@"handle:gameStatsSystem"];}
    }
    if(_flyWanted)[self flightTick];
}
- (void)flightTick {
    NSData *player=[_native lockWeak:_playerWeak],*facility=[self system:@"gameTeleportationFacility" getter:@"GetTeleportationFacility"];
    @try {
        NSDictionary *get=[self binding:@"PlayerPuppet" method:@"GetWorldPosition" params:@[] result:@"Vector4" script:NO];
        NSDictionary *orientation=[self binding:@"PlayerPuppet" method:@"GetWorldOrientation" params:@[] result:@"Quaternion" script:NO];
        NSDictionary *euler=[self binding:@"Quaternion" method:@"ToEulerAngles" params:@[@"Quaternion"] result:@"EulerAngles" script:NO];
        NSDictionary *forward=[self binding:@"Quaternion" method:@"GetForward" params:@[@"Quaternion"] result:@"Vector4" script:NO];
        NSDictionary *right=[self binding:@"Quaternion" method:@"GetRight" params:@[@"Quaternion"] result:@"Vector4" script:NO];
        NSDictionary *teleport=[self binding:@"gameTeleportationFacility" method:@"Teleport" params:@[@"handle:gameObject",@"Vector4",@"EulerAngles"] result:@"Void" script:NO];
        if(!CPPointer(player) || !CPPointer(facility) || !get || !orientation || !euler || !forward || !right || !teleport)return;
        NSData *position=[self call:get context:CPPointer(player) args:@[] size:16],*rotation=[self call:orientation context:CPPointer(player) args:@[] size:16];
        if(position.length!=16 || rotation.length!=16)return;
        float actual[4]={0};memcpy(actual,position.bytes,16);for(int i=0;i<3;i++)if(!isfinite(actual[i]))return;
        double now=NSProcessInfo.processInfo.systemUptime;
        if(!_flying){memcpy(_flightTarget,actual,16);_anchorZ=actual[2];_flightTarget[2]+=_heightWanted ? _flyHeight : 1;_flying=YES;_lastFrameTime=now;}
        else if(fabs(actual[2]-_flightTarget[2])<.25 && hypot(actual[0]-_flightTarget[0],actual[1]-_flightTarget[1])<.5){
            _flightConfirmed=YES;
            if(_speedPending){
                double planned2=0,progress=0,error2=0;
                for(int i=0;i<3;i++){double step=_flightTarget[i]-_motionOrigin[i];planned2+=step*step;progress+=(actual[i]-_motionOrigin[i])*step;double error=actual[i]-_flightTarget[i];error2+=error*error;}
                if(planned2>.0001 && progress>=planned2*.75 && sqrt(error2)<=MAX(.025,sqrt(planned2)*.25))_speedConfirmed=YES;
            }
        }
        _speedPending=NO;
        double dt=MIN(.05,MAX(0,now-_lastFrameTime));_lastFrameTime=now;
        NSData *forwardValue=[self call:forward context:0 args:@[rotation] size:16],*rightValue=[self call:right context:0 args:@[rotation] size:16],*angles=[self call:euler context:0 args:@[rotation] size:12];
        if(forwardValue.length!=16 || rightValue.length!=16 || angles.length!=12)return;
        float f[4]={0},r[4]={0};memcpy(f,forwardValue.bytes,16);memcpy(r,rightValue.bytes,16);
        uint32_t input=_movementInput;double scale=6*(_flySpeedWanted ? _flySpeed : 1)*dt;
        int fb=((input&1)!=0)-((input&2)!=0),lr=((input&8)!=0)-((input&4)!=0),vertical=((input&16)!=0)-((input&32)!=0);
        if(_flySpeedWanted && (fb || lr || vertical) && scale>.01){memcpy(_motionOrigin,actual,sizeof(_motionOrigin));_speedPending=YES;}
        double length=hypot(fb,lr);if(length<1)length=1;
        _flightTarget[0]+=(float)((f[0]*fb+r[0]*lr)*scale/length);_flightTarget[1]+=(float)((f[1]*fb+r[1]*lr)*scale/length);_flightTarget[2]+=(float)(vertical*scale);
        [self call:teleport context:CPPointer(facility) args:@[player,CPValue(_flightTarget,16),angles] size:1];
    } @finally {[_native destroyValue:player type:@"handle:gameObject"];[_native destroyValue:facility type:@"handle:gameTeleportationFacility"];}
}
- (MTFeatureState *)locomotionFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    if(feature==MTFeatureSuperJump){
        _superWanted=wanted;if(!wanted){[_native removeScriptObserver:@"superJump"];_superInstalled=NO;_superCount=0;state.available=YES;state.note=@"Eigene Sprungimpulse aus.";return state;}
        state.available=[self installSuperJump];state.active=state.available && _superCount>0;state.note=state.active ? @"Zusätzlicher nativer Sprungimpuls bestätigt." : @"Wartet auf einen lokalen Sprung.";return state;
    }
    if(feature==MTFeatureDoubleJump){
        _doubleWanted=wanted;if(!wanted){[self restoreJumpCounter];_doubleConfirmed=NO;}else if(![self installLocomotionCapture]){state.note=@"Native PSM-Bindung fehlt.";return state;}
        [self refreshFrameWork];state.available=YES;state.active=wanted && _doubleConfirmed;state.note=state.active ? @"Nativer Doppelsprung-Zähler zurückgesetzt und bestätigt." : wanted ? @"Wartet auf lokale PSM und verstärkte Sehnen." : @"Eigener Doppelsprung-Reset aus.";return state;
    }
    if(feature==MTFeatureFly){
        _flyWanted=wanted;if(!wanted){_flying=NO;_flightConfirmed=NO;_speedConfirmed=NO;_speedPending=NO;_movementInput=0;}
    }else if(feature==MTFeatureFlyHeight){
        if(wanted && (!_heightWanted || _flyHeight!=value) && _flying){_flightTarget[2]=(float)(_anchorZ+value);_flightConfirmed=NO;}
        _heightWanted=wanted;_flyHeight=value;
    }else {if(_flySpeedWanted!=wanted || _flySpeed!=value){_speedConfirmed=NO;_speedPending=NO;}_flySpeedWanted=wanted;_flySpeed=value;}
    [self refreshFrameWork];state.available=YES;state.active=wanted && _flyWanted && _flightConfirmed && (feature!=MTFeatureFlySpeed || _speedConfirmed);
    state.note=state.active ? @"Native Flugposition zurückgelesen; WASD, Leertaste und C." : wanted ? (feature==MTFeatureFlySpeed ? @"Wartet auf eine bestätigte Bewegung mit aktivem Flugtempo." : @"Wartet auf aktiven Flugmodus und native Positionsbestätigung.") : @"Eigene Flugsteuerung aus.";return state;
}

- (void)scaleIncomingHit:(NSData *)hit {
    if(!_defenseWanted || !isfinite(_defenseFactor) || _defenseFactor<1 || _defenseFactor>1000)return;
    NSData *target=[_native readProperty:@"target" className:@"gameeventsHitEvent" object:hit type:@"whandle:gameObject"],*computed=nil;
    @try {
        if(![target isEqual:_playerWeak])return;
        NSData *projection=[_native readProperty:@"projectionPipeline" className:@"gameeventsHitEvent" object:hit type:@"Bool"];
        if(projection.length!=1 || CPTrue(projection))return;
        computed=[_native readProperty:@"attackComputed" className:@"gameeventsHitEvent" object:hit type:@"handle:gameAttackComputed"];
        if(!CPPointer(computed) || ![_native object:computed isKindOf:@"gameAttackComputed"])return;
        NSDictionary *get=[self binding:@"gameAttackComputed" method:@"GetAttackValue" params:@[@"gamedataDamageType"] result:@"Float" script:NO];
        NSDictionary *multiply=[self binding:@"gameAttackComputed" method:@"MultAttackValue" params:@[@"Float",@"gamedataDamageType"] result:@"Void" script:NO];
        if(!get || !multiply)return;float factor=(float)(1/_defenseFactor);BOOL changed=NO,verified=YES;
        for(NSString *name in @[@"Physical",@"Thermal",@"Electric",@"Chemical"]){
            NSNumber *kind=[_native enumType:@"gamedataDamageType" member:name];if(!kind){verified=NO;continue;}int32_t type=kind.intValue;
            NSData *data=[self call:get context:CPPointer(computed) args:@[CPValue(&type,4)] size:4];float before=NAN;if(data.length==4)memcpy(&before,data.bytes,4);
            if(!isfinite(before) || before<0){verified=NO;continue;}if(before==0)continue;
            [self call:multiply context:CPPointer(computed) args:@[CPValue(&factor,4),CPValue(&type,4)] size:1];
            data=[self call:get context:CPPointer(computed) args:@[CPValue(&type,4)] size:4];float after=NAN;if(data.length==4)memcpy(&after,data.bytes,4);
            verified&=isfinite(after) && fabs(after-before*factor)<=MAX(.01f,fabsf(before*factor)*.002f);changed=YES;_damageBefore=before;_damageAfter=after;
        }
        if(changed){_defenseCount++;_defenseVerified=verified;}
    } @finally {[_native destroyValue:target type:@"whandle:gameObject"];[_native destroyValue:computed type:@"handle:gameAttackComputed"];}
}
- (MTFeatureState *)defenseFeature:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;
    if(_defenseFactor!=value)_defenseVerified=NO;_defenseFactor=value;_defenseWanted=wanted;
    if(!wanted){[_native removeScriptObserver:@"defense"];_defenseInstalled=NO;_defenseVerified=NO;state.available=YES;state.note=@"Eigene Schadensskalierung aus.";return state;}
    if(!_defenseInstalled){
        NSDictionary *binding=[self binding:@"gameDamageSystem" method:@"ProcessPlayerIncomingDamageMultiplier" params:@[@"handle:gameeventsHitEvent"] result:@"Void" script:YES];
        __weak CPEffects *weak=self;
        if(binding)_defenseInstalled=[_native setScriptObserver:@"defense" binding:binding methodName:@"ProcessPlayerIncomingDamageMultiplier;gameHitEvent" handler:^(uintptr_t context,NSArray *arguments,NSData *result){(void)context;(void)result;if(arguments.count==1)[weak scaleIncomingHit:arguments[0]];}];
    }
    state.available=_defenseInstalled;state.active=state.available && _defenseVerified;
    state.note=state.active ? [NSString stringWithFormat:@"Eingehender Schaden nativ bestätigt: %.3g → %.3g.",_damageBefore,_damageAfter] : @"Wartet auf einen bestätigten lokalen Schadenstreffer.";return state;
}
- (BOOL)installBreachCapture {
    if(_timerCaptureInstalled)return YES;
    NSDictionary *binding=[self binding:@"gameuiHackingMinigameGameController" method:@"ScaleTimer" params:@[@"handle:PlayerPuppet",@"handle:entEntity",@"Float",@"Float",@"Bool"] result:@"Void" script:YES];
    if(!binding)return NO;NSMutableDictionary *prefix=[binding mutableCopy];prefix[@"observedPrefix"]=@1;__weak CPEffects *weak=self;
    _timerCaptureInstalled=[_native setScriptObserver:@"breachOwner" binding:prefix methodName:@"ScaleTimer;PlayerPuppetEntityFloatFloatBool" handler:^(uintptr_t context,NSArray *arguments,NSData *result){
        (void)result;CPEffects *owner=weak;if(!owner || arguments.count!=1)return;NSData *player=[owner->_native lockWeak:owner->_playerWeak];
        @try {
            if(![player isEqual:arguments[0]])return;
            NSData *timer=[owner->_native weakForCallbackObject:context className:@"gameuiHackingMinigameGameController"];if(!timer)return;
            if([timer isEqual:owner->_timerWeak]){[owner->_native destroyValue:timer type:@"whandle:gameuiHackingMinigameGameController"];return;}
            if(![owner clearBreach]){[owner->_native destroyValue:timer type:@"whandle:gameuiHackingMinigameGameController"];return;}[owner->_native destroyValue:owner->_timerWeak type:@"whandle:gameuiHackingMinigameGameController"];owner->_timerWeak=timer;
        } @finally {[owner->_native destroyValue:player type:@"handle:gameObject"];}
    }];return _timerCaptureInstalled;
}
- (BOOL)clearBreach {
    if(!_timerOwned)return YES;NSData *timer=[_native lockWeak:_timerWeak];
    @try {
        if(CPPointer(timer)){
            NSNumber *paused=[_native hackingTimerPaused:timer];if(!paused)return NO;
            if(paused.boolValue){
                NSDictionary *resume=[self binding:@"gameuiHackingMinigameGameController" method:@"ResumeTheTimer" params:@[] result:@"Void" script:NO];
                if(!resume || ![self call:resume context:CPPointer(timer) args:@[] size:1])return NO;
                paused=[_native hackingTimerPaused:timer];if(!paused || paused.boolValue)return NO;
            }
        }else if(![[_native weakIsExpired:_timerWeak] isEqual:@YES])return NO;
        _timerOwned=NO;return YES;
    } @finally {[_native destroyValue:timer type:@"handle:gameuiHackingMinigameGameController"];}
}
- (MTFeatureState *)breachFeature:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.wanted=wanted;state.value=value;_breachWanted=wanted;
    BOOL bound=[self installBreachCapture];
    if(!wanted){state.available=[self clearBreach];state.note=@"Eigene Breach-Timer-Pause aus.";return state;}
    NSData *timer=[_native lockWeak:_timerWeak];
    @try {
        if(!bound || !CPPointer(timer)){state.available=bound;state.note=@"Wartet auf den lokalen Breach-Controller.";return state;}
        NSNumber *before=[_native hackingTimerPaused:timer];if(!before){state.note=@"Nativer Breach-Pausenzustand nicht lesbar.";return state;}
        if(!before.boolValue){
            NSDictionary *pause=[self binding:@"gameuiHackingMinigameGameController" method:@"PauseTheTimer" params:@[] result:@"Void" script:NO];
            if(!pause || ![self call:pause context:CPPointer(timer) args:@[] size:1])return state;_timerOwned=YES;
        }
        NSNumber *after=[_native hackingTimerPaused:timer];state.available=YES;state.active=after.boolValue;state.note=state.active ? @"Native Breach-Timer-Pause bestätigt." : @"Breach-Pause noch nicht bestätigt.";return state;
    } @finally {[_native destroyValue:timer type:@"handle:gameuiHackingMinigameGameController"];}
}


- (MTFeatureState *)damageFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    if(feature==MTFeatureOneHitKill)_oneHitWanted=wanted;else {_damageWanted=wanted;_damageMultiplier=value;}
    double factor=(_oneHitWanted ? 100000 : 1)*(_damageWanted ? _damageMultiplier : 1);
    MTFeatureState *state=[self applyStatFeature:MTFeatureDamageMultiplier wanted:_oneHitWanted || _damageWanted value:factor];
    state.wanted=wanted;state.value=value;state.active=wanted && state.active;
    if(!wanted)state.note=@"Eigener Schadensschalter aus.";return state;
}
@end









