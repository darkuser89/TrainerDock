// SPDX-License-Identifier: GPL-3.0-only
#import "GameBridge.h"
#import "SelectionSettings.h"
#import "GameAccess.h"
#import "ExtraFeatures.h"
#import "OverlayInput.h"
#import <objc/message.h>
#import <os/log.h>
#include <math.h>
#include <limits.h>

@implementation DI2TrainerState
- (instancetype)init {
    if ((self=[super init])) {
        _status=@"Einzelspieler laden …"; _message=@"Alle Schalter sind aus.";
        NSMutableArray *features=[NSMutableArray new];
        for (NSInteger i=0;i<DI2FeatureCount;i++) {
            DI2FeatureState *item=[DI2FeatureState new]; item.value=DI2FeatureInfoAt(i)->initial;
            item.note=DI2FeatureInfoAt(i)->detail; [features addObject:item];
        }
        _features=features;
    }
    return self;
}
@end

typedef struct {
    DI2WeakObject weak;
    BOOL applied;
    float original[4];
    uint8_t flags[4];
} DI2Effect;
typedef NS_ENUM(NSInteger, DI2SessionMode) {
    DI2SessionLoading, DI2SessionSolo, DI2SessionNetwork
};
static const size_t spreadOffsets[]={0xc0,0xd8};
static const size_t recoilOffsets[]={0xc8,0xe0,0xf8,0x110};

@interface DI2GameBridge () {
    DI2GameAPI _api;
    BOOL _supported, _inFlight;
    NSMutableArray<NSDictionary *> *_commands;
    DI2Effect _effects[DI2FeatureCount];
    DI2WeakObject _player, _world, _xpOwner;
    BOOL _wanted[DI2FeatureCount];
    BOOL _durabilityWasActive;
    double _values[DI2FeatureCount];
    int32_t _lastXP;
    uint64_t _reason, _context;
    DI2SessionMode _sessionMode;
    NSString *_lastMessage;
    os_log_t _log;
    DI2ExtraFeatures *_extra;
    DI2OverlayInput *_overlayInput;
    BOOL _overlayInteraction;
#ifdef DI2_TRAINER_TESTING
    BOOL _testing;
#endif
}
@property(nonatomic, readwrite) DI2TrainerState *state;
@end

@implementation DI2GameBridge
#ifdef DI2_TRAINER_TESTING
- (instancetype)initWithTestAPI:(DI2GameAPI)api {
    if ((self=[self init])) { _api=api; _supported=YES; _testing=YES; } return self;
}
- (DI2TrainerState *)testUpdate:(DI2TrainerAction)action { return [self update:action value:nil context:0]; }
- (DI2TrainerState *)testFeature:(DI2Feature)feature { return [self update:100+feature value:nil context:0]; }
- (DI2TrainerState *)testValue:(double)value feature:(DI2Feature)feature { return [self update:200+feature value:@(value) context:0]; }
#endif
- (instancetype)init {
    if ((self=[super init])) {
        _supported=DI2LoadGameAPI(&_api); _state=[DI2TrainerState new];
        _commands=[NSMutableArray new]; _lastMessage=_state.message;
        for (NSInteger i=0;i<DI2FeatureCount;i++) _values[i]=DI2FeatureInfoAt(i)->initial;
        _log=os_log_create("local.deadisland2.trainer","gameplay");
        if (!_supported) _state.status=@"Spiel-Build nicht unterstützt";
        os_log(_log,"Native game ABI supported=%d",_supported);
    } return self;
}
- (void)restoreSelection:(NSDictionary *)selection {
    NSAssert(NSThread.isMainThread,@"Restore before the first game-thread poll");
    NSAssert(!_inFlight && !_context && !_commands.count,@"Restore only at session startup");
    if (_inFlight || _context || _commands.count) return;
    NSDictionary *entries=DI2NormalizeCheatSelection(selection)[@"features"];
    BOOL changed=NO;
    for (NSInteger i=0;i<DI2FeatureCount;i++) {
        NSDictionary *entry=entries[[NSString stringWithFormat:@"%ld",(long)i]];
        _wanted[i]=[entry[@"wanted"] boolValue]; _values[i]=[entry[@"value"] doubleValue];
        changed|=_wanted[i] || _values[i]!=DI2FeatureInfoAt(i)->initial;
        _state.features[i].wanted=_wanted[i]; _state.features[i].value=_values[i];
    }
    if (changed) { _lastMessage=@"Gespeicherte Auswahl wird nach dem Laden aktiviert."; _state.message=_lastMessage; }
}
- (BOOL)object:(void *)object isA:(void *)class {
    void *actual=NULL;
    return object && !((uintptr_t)object&7) && class
        && DI2ReadMemory((char *)object+0x10,&actual,8) && actual
        && _api.valid(object,false) && _api.classIsChildOf(actual,class);
}
- (void *)readPointer:(void *)object offset:(size_t)offset {
    void *result=NULL; if (object) DI2ReadMemory((char *)object+offset,&result,8); return result;
}
- (void *)component:(void *)owner class:(void *(*)(void))class {
    if (!owner || !class) return NULL;
    void *type=class(), *result=_api.component(owner,type);
    return [self object:result isA:type] ? result : NULL;
}
- (BOOL)readFloat:(void *)object offset:(size_t)offset result:(float *)result {
    return object && DI2ReadMemory((char *)object+offset,result,4) && isfinite(*result);
}
- (void *)handler:(void *)handler class:(void *(*)(void))class modules:(void *)modules {
    if (!modules || !class || ![self object:handler isA:class()]) return NULL;
    // URangedWeaponModuleBase stores its owning modules as a weak object at +0x98.
    // Its native getters dereference this owner, so class checking alone is unsafe.
    DI2WeakObject owner={0};
    if (!DI2ReadMemory((char *)handler+0x98,&owner,sizeof(owner))) return NULL;
    return _api.weakGet(&owner)==modules ? handler : NULL;
}
- (BOOL)writeFlag:(void *)object offset:(size_t)offset {
    uint8_t actual=0;
    return DI2WriteByte(object,offset,1) && DI2ReadMemory((char *)object+offset,&actual,1) && actual==1;
}
- (void)ensureReason {
    if (!_reason) {
        static const uint16_t name[]={'D','I','2','T','r','a','i','n','e','r','.','R','u','n','t','i','m','e',0};
        _api.name(&_reason,name,1);
    }
}
- (void)restore:(DI2Feature)kind {
    DI2Effect *effect=&_effects[kind]; if (!effect->applied) return;
    void *object=_api.weakGet(&effect->weak);
    if (object) switch (kind) {
        case DI2FeatureGod: _api.removeGod(object,_reason); break;
        case DI2FeatureDurability: _api.removeDurability(object,_reason); break;
        case DI2FeatureStamina: DI2WriteByte(object,0x19c,effect->flags[0]); break;
        case DI2FeatureAmmo: DI2WriteByte(object,0xe0,effect->flags[0]); break;
        case DI2FeatureNoReload: DI2WriteByte(object,0xe1,effect->flags[0]); break;
        case DI2FeaturePlayerSpeed: DI2WriteFloat(object,0xc8,effect->original[0]); break;
        case DI2FeatureGameSpeed: _api.setGameSpeed(object,effect->original[0]); break;
        case DI2FeatureDefenseMultiplier: _api.setIncomingDamage(object,effect->original[0]); break;
        case DI2FeatureInfiniteFury: _api.setInfiniteFury(object,effect->flags[0]!=0); break;
        case DI2FeatureDamageMultiplier: case DI2FeatureForceMultiplier: _api.setAttribute(object,effect->original[0]); break;
        case DI2FeatureAccuracy: case DI2FeatureNoRecoil: {
            const size_t *offsets=kind==DI2FeatureAccuracy ? spreadOffsets : recoilOffsets;
            NSUInteger count=kind==DI2FeatureAccuracy ? 2 : 4;
            for (NSUInteger i=0;i<count;i++) {
                DI2WriteFloat(object,offsets[i]+4,effect->original[i]);
                DI2WriteByte(object,offsets[i],effect->flags[i]);
            } break;
        }
        default: break;
    }
    memset(effect,0,sizeof(*effect));
}
- (void)releaseEffects {
    [_extra reset];
    for (NSInteger i=0;i<DI2FeatureCount;i++) [self restore:i];
    memset(&_xpOwner,0,sizeof(_xpOwner)); _lastXP=0;
    _durabilityWasActive=NO;
}
- (void)disableAll {
    [self releaseEffects];
    memset(_wanted,0,sizeof(_wanted));
}
- (BOOL)effect:(DI2Feature)kind object:(void *)object wanted:(BOOL)wanted factor:(double)factor {
    DI2Effect *effect=&_effects[kind];
    if (effect->applied && (_api.weakGet(&effect->weak)!=object || !wanted)) [self restore:kind];
    if (!wanted || !object) return NO;
    if (!effect->applied) {
        BOOL captured=YES;
        switch (kind) {
            case DI2FeatureStamina: captured=DI2ReadMemory((char *)object+0x19c,effect->flags,1); break;
            case DI2FeatureAmmo: case DI2FeatureNoReload:
                captured=DI2ReadMemory((char *)object+(kind==DI2FeatureAmmo ? 0xe0 : 0xe1),effect->flags,1); break;
            case DI2FeaturePlayerSpeed: captured=[self readFloat:object offset:0xc8 result:effect->original]; break;
            case DI2FeatureGameSpeed: effect->original[0]=_api.getGameSpeed(object); captured=isfinite(effect->original[0]); break;
            case DI2FeatureDefenseMultiplier: captured=[self readFloat:object offset:0xf0 result:effect->original]; break;
            case DI2FeatureInfiniteFury: captured=DI2ReadMemory((char *)object+0x214,effect->flags,1); break;
            case DI2FeatureDamageMultiplier: case DI2FeatureForceMultiplier:
                effect->original[0]=_api.getAttribute(object); captured=isfinite(effect->original[0]) && effect->original[0]>0; break;
            case DI2FeatureAccuracy: case DI2FeatureNoRecoil: {
                const size_t *offsets=kind==DI2FeatureAccuracy ? spreadOffsets : recoilOffsets;
                NSUInteger count=kind==DI2FeatureAccuracy ? 2 : 4;
                for (NSUInteger i=0;i<count;i++) captured=captured
                    && DI2ReadMemory((char *)object+offsets[i],&effect->flags[i],1)
                    && effect->flags[i]<=1 && [self readFloat:object offset:offsets[i]+4 result:&effect->original[i]];
                break;
            }
            default: break;
        }
        if (!captured) return NO;
        _api.weakAssign(&effect->weak,object); if (_api.weakGet(&effect->weak)!=object) return NO;
        effect->applied=YES;
        if (kind==DI2FeatureGod) { [self ensureReason]; _api.addGod(object,_reason); _api.fillHealth(object,1); }
        if (kind==DI2FeatureDurability) { [self ensureReason]; _api.addDurability(object,_reason); _api.repair(object); }
    }
    BOOL changed=YES;
    switch (kind) {
        case DI2FeatureStamina: {
            changed=DI2WriteByte(object,0x19c,1); float maximum=_api.maxStamina(object);
            if (isfinite(maximum) && maximum>0) _api.setStamina(object,maximum); break;
        }
        case DI2FeatureAmmo: changed=[self writeFlag:object offset:0xe0]; break;
        case DI2FeatureNoReload: {
            int32_t maximum=_api.capacity(object);
            changed=maximum>0 && maximum<10000 && [self writeFlag:object offset:0xe1];
            if (changed && _api.ammo(object)<maximum) _api.setAmmo(object,maximum);
            changed=changed && _api.ammo(object)==maximum; break;
        }
        case DI2FeaturePlayerSpeed: changed=DI2WriteFloat(object,0xc8,(float)(effect->original[0]*factor)); break;
        case DI2FeatureGameSpeed: _api.setGameSpeed(object,(float)factor); break;
        case DI2FeatureDefenseMultiplier: _api.setIncomingDamage(object,(float)(effect->original[0]/factor)); break;
        case DI2FeatureInfiniteFury: _api.setInfiniteFury(object,true); break;
        case DI2FeatureDamageMultiplier: case DI2FeatureForceMultiplier: {
            float target=(float)MIN(1e9,(double)effect->original[0]*factor);
            _api.setAttribute(object,target);
            changed=_api.getAttribute(object)==target; break;
        }
        case DI2FeatureAccuracy: case DI2FeatureNoRecoil: {
            const size_t *offsets=kind==DI2FeatureAccuracy ? spreadOffsets : recoilOffsets;
            NSUInteger count=kind==DI2FeatureAccuracy ? 2 : 4;
            for (NSUInteger i=0;i<count;i++) {
                // FAttributeValueProxy::GetValue returns +4 directly when its +0 flag is false.
                BOOL valueOK=DI2WriteFloat(object,offsets[i]+4,0);
                BOOL flagOK=DI2WriteByte(object,offsets[i],0);
                uint8_t flag=1; float value=NAN;
                BOOL verified=DI2ReadMemory((char *)object+offsets[i],&flag,1)
                    && [self readFloat:object offset:offsets[i]+4 result:&value] && flag==0 && value==0;
                changed=flagOK && valueOK && verified && changed;
            } break;
        }
        default: break;
    }
    if (!changed) [self restore:kind]; return changed;
}
- (DI2TrainerState *)update:(NSInteger)command value:(NSNumber *)parameter context:(uint64_t)expected {
    if (!_extra) _extra=[[DI2ExtraFeatures alloc]initWithAPI:_api];
    DI2TrainerState *state=[DI2TrainerState new];
    for (NSInteger i=0;i<DI2FeatureCount;i++) state.features[i].value=_values[i];
    void *world=[self readPointer:_api.world offset:0];
    if (!_overlayInput) _overlayInput=[[DI2OverlayInput alloc]initWithAPI:_api];
    if (command==50 && parameter) _overlayInteraction=parameter.boolValue;
    state.overlayMouseActive=[_overlayInput updateWorld:world wanted:_overlayInteraction];
    void *player=world ? _api.playerCharacter(world,0) : NULL;
    if (![self object:player isA:_api.playerClass()]) player=NULL;
    BOOL solo=player && _api.standalone(player);
    DI2SessionMode mode=player ? (solo ? DI2SessionSolo : DI2SessionNetwork) : DI2SessionLoading;
    BOOL changed=mode!=_sessionMode || _api.weakGet(&_player)!=player || _api.weakGet(&_world)!=world;
    if (changed) {
        // Travel replaces worlds/pawns. Release native owners and baselines, but
        // retain the user's choices until the explicit all-off command.
        [self releaseEffects]; _context++; _sessionMode=mode;
        _api.weakAssign(&_player,player); _api.weakAssign(&_world,world);
        if (command!=DI2TrainerDisableAll) command=DI2TrainerPoll;
        if (solo) _lastMessage=@"Einzelspieler geladen · gewählte Schalter werden erneut angewendet.";
    }
    if (expected && expected!=_context && command!=DI2TrainerDisableAll) command=DI2TrainerPoll;
    if (command==DI2TrainerDisableAll) { [self disableAll]; _lastMessage=@"Alle Laufzeitschalter aus."; }
    state.context=_context;
    state.selectionCanBeSaved=player!=NULL || command==DI2TrainerDisableAll;
    state.status=player ? (solo ? @"Einzelspieler" : @"Netzwerk") : @"Einzelspieler laden …";
    if (!player) {
        for (NSInteger i=0;i<DI2FeatureCount;i++) {
            state.features[i].wanted=_wanted[i];
            if (_wanted[i]) state.features[i].note=@"Ladepause · wird im Einzelspieler erneut angewendet.";
        }
        state.message=command==DI2TrainerDisableAll ? _lastMessage : @"Ladepause · Schalterauswahl bleibt erhalten.";
        return state;
    }
    state.ready=YES;
    void *controller=_api.playerController ? _api.playerController(world,0) : NULL;
    void *inventory=_api.inventory(player);
    if (![self object:inventory isA:_api.inventoryClass()]) inventory=NULL;
    void *cashArchetype=[self readPointer:inventory offset:0x318];
    if (cashArchetype) state.cash=@(_api.count(inventory,cashArchetype));
    void *health=[self component:player class:_api.healthClass];
    void *stamina=[self component:player class:_api.staminaClass];
    void *slot=[self readPointer:player offset:0x15a8];
    // ADIPlayerCharacter::PreInitializeComponents constructs UPhysicalSlot at
    // +0x15a8. UPaperDollSlot is a separate inventory object and must be rejected.
    if (![self object:slot isA:_api.physicalSlotClass()] || [self readPointer:slot offset:0x20]!=player) slot=NULL;
    void *equippable=[self readPointer:slot offset:0x70];
    if (![self object:equippable isA:_api.equippableClass()]) equippable=NULL;
    // The game's main-hand change handler uses the component's Owner at +0xd0.
    // A UObject Outer is not an owner fallback: it can reference a different actor.
    void *item=[self readPointer:equippable offset:0xd0];
    BOOL ownedWeapon=(_api.meleeClass && [self object:item isA:_api.meleeClass()]) || [self object:item isA:_api.rangedClass()];
    if (!ownedWeapon) item=NULL;
    BOOL melee=item && _api.meleeClass && [self object:item isA:_api.meleeClass()];
    void *modules=[self object:item isA:_api.rangedClass()] ? [self component:item class:_api.modulesClass] : NULL;
    if ([self readPointer:modules offset:0xd0]!=item) modules=NULL;
    void *ammo=modules ? _api.ammoHandler(modules) : NULL;
    ammo=[self handler:ammo class:_api.clipClass modules:modules];
    void *spread=modules && _api.spreadHandler ? _api.spreadHandler(modules) : NULL;
    spread=[self handler:spread class:_api.spreadClass modules:modules];
    void *recoil=modules && _api.recoilHandler ? _api.recoilHandler(modules) : NULL;
    recoil=[self handler:recoil class:_api.recoilClass modules:modules];
    void *attributes=melee ? [self component:item class:_api.meleeAttributesClass] : NULL;
    if ([self readPointer:attributes offset:0xd0]!=item) attributes=NULL;
    void *damage=attributes && _api.damageAttribute ? _api.damageAttribute(attributes) : NULL;
    void *force=attributes && _api.forceAttribute ? _api.forceAttribute(attributes) : NULL;
    if (!_api.attributeClass || ![self object:damage isA:_api.attributeClass()]) damage=NULL;
    if (!_api.attributeClass || ![self object:force isA:_api.attributeClass()]) force=NULL;
    void *damageable=[self component:player class:_api.damageableClass];
    void *fury=[self component:controller class:_api.furyClass] ?: [self component:player class:_api.furyClass];
    float maxFury=0; uint8_t furyReady=0;
    if (fury) DI2ReadMemory((char *)fury+0x1e8,&furyReady,1);
    if (![self readFloat:fury offset:0x158 result:&maxFury] || maxFury<=0
        || !_api.weakGet((DI2WeakObject *)((char *)fury+0x15c))) fury=NULL;
    void *throwing=[self component:player class:_api.throwClass] ?: [self component:controller class:_api.throwClass];
    void *throwOwner=[self readPointer:throwing offset:0xd0];
    if (throwOwner!=player && (!controller || throwOwner!=controller)) throwing=NULL;
    void *progression=[self component:controller class:_api.progressionClass] ?: [self component:player class:_api.progressionClass];
    if (progression && !_api.weakGet((DI2WeakObject *)((char *)progression+0x158))) progression=NULL;
    void *levels=[self readPointer:progression offset:0x120];
    if (!_api.levelsClass || ![self object:levels isA:_api.levelsClass()]) levels=NULL;
    BOOL available[DI2FeatureCount]={0};
    available[DI2FeatureGod]=available[DI2FeatureHealth]=health!=NULL;
    available[DI2FeatureStamina]=stamina!=NULL; available[DI2FeatureDurability]=melee;
    available[DI2FeaturePlayerSpeed]=YES; available[DI2FeatureGameSpeed]=_api.setGameSpeed!=NULL;
    available[DI2FeatureSuperForce]=available[DI2FeatureForceMultiplier]=force!=NULL;
    available[DI2FeatureOneHit]=available[DI2FeatureDamageMultiplier]=damage!=NULL;
    available[DI2FeatureDefenseMultiplier]=damageable!=NULL;
    available[DI2FeatureMoney]=state.cash && _api.removeCash;
    available[DI2FeatureAmmo]=available[DI2FeatureNoReload]=ammo!=NULL;
    available[DI2FeatureAccuracy]=spread!=NULL; available[DI2FeatureNoRecoil]=recoil!=NULL;
    available[DI2FeatureCurveball]=throwing!=NULL;
    available[DI2FeatureFullFury]=fury && furyReady; available[DI2FeatureInfiniteFury]=fury!=NULL;
    available[DI2FeatureMaxXP]=progression && levels;
    available[DI2FeatureXPMultiplier]=progression!=NULL;
    NSInteger feature=command>=100 && command<100+DI2FeatureCount ? command-100 : -1;
    if (command>=200 && command<200+DI2FeatureCount && parameter) {
        NSInteger target=command-200; const DI2FeatureInfo *info=DI2FeatureInfoAt(target);
        double value=parameter.doubleValue;
        if (info->numeric && isfinite(value) && value>=info->minimum && value<=info->maximum) {
            _values[target]=value; state.features[target].value=value;
            _lastMessage=[NSString stringWithFormat:@"%@: %.2f",info->title,value];
        }
    }
    if (command==DI2TrainerHealth) feature=DI2FeatureGod;
    if (command==DI2TrainerStamina) feature=DI2FeatureStamina;
    if (command==DI2TrainerAmmo) feature=DI2FeatureAmmo;
    if(command>=300 && command<300+DI2FeatureCount && parameter){
        NSInteger i=command-300;const DI2FeatureInfo *info=DI2FeatureInfoAt(i);
        if(info->implemented && !info->oneShot && _wanted[i]!=parameter.boolValue)feature=i;
    }
    if (feature>=0) {
        const DI2FeatureInfo *info=DI2FeatureInfoAt(feature);
        if (!info->implemented) _lastMessage=info->detail;
        else if (!info->oneShot) {
            _wanted[feature]=!_wanted[feature];
            if (feature==DI2FeatureXPMultiplier) { _api.weakAssign(&_xpOwner,progression); _lastXP=progression ? _api.getXP(progression) : 0; }
            _lastMessage=[NSString stringWithFormat:@"%@: %@",info->title,_wanted[feature] ? (available[feature] ? @"AN" : @"wartet auf passende Ausrüstung/Freischaltung") : @"AUS"];
        } else if (!available[feature]) _lastMessage=@"Aktion wartet auf Inventar oder freigeschaltete Fähigkeit.";
    }
    if (state.cash && (command==DI2TrainerCash1000 || command==DI2TrainerCash10000 || feature==DI2FeatureMoney)) {
        int32_t before=state.cash.intValue;
        int64_t delta=command==DI2TrainerCash1000 ? 1000 : command==DI2TrainerCash10000 ? 10000 : (int64_t)_values[DI2FeatureMoney]-before;
        if (delta>0) _api.addCash(inventory,(int32_t)MIN(delta,INT_MAX-before));
        if (delta<0 && _api.removeCash) _api.removeCash(inventory,(int32_t)MIN(-delta,before));
        int32_t after=_api.count(inventory,cashArchetype); state.cash=@(after);
        _lastMessage=[NSString stringWithFormat:@"Geld: %d → %d · vom Spiel gespeichert",before,after];
        os_log(_log,"Cash delta=%lld before=%d after=%d",(long long)delta,before,after);
    }
    if (feature==DI2FeatureFullFury && available[DI2FeatureFullFury]) {
        float before=_api.getFury(fury), missing=maxFury-before;
        if (isfinite(missing) && missing>0) _api.addFury(fury,missing,NULL);
        float after=_api.getFury(fury);
        _lastMessage=[NSString stringWithFormat:@"Wut: %.1f → %.1f / %.1f",before,after,maxFury];
    }
    if (feature==DI2FeatureMaxXP && progression && levels) {
        int maximum=_api.maxLevel(progression), before=_api.getXP(progression);
        if (maximum>0 && maximum<=1000 && before>=0) {
            int target=_api.xpForLevel(levels,maximum);
            int64_t delta=(int64_t)target-before;
            if (delta>0 && delta<=(int64_t)INT_MAX-before) { [self ensureReason]; _api.addXP(progression,(int32_t)delta,_reason); }
        }
        _lastMessage=[NSString stringWithFormat:@"EP: %d → %d · Stufe %d · dauerhaft",before,_api.getXP(progression),_api.getLevel(progression)];
    }
    BOOL active[DI2FeatureCount]={0};
    active[DI2FeatureGod]=[self effect:DI2FeatureGod object:health wanted:_wanted[DI2FeatureGod] factor:1];
    active[DI2FeatureHealth]=_wanted[DI2FeatureHealth] && health;
    if (active[DI2FeatureHealth]) _api.fillHealth(health,1);
    active[DI2FeatureStamina]=[self effect:DI2FeatureStamina object:stamina wanted:_wanted[DI2FeatureStamina] factor:1];
    active[DI2FeatureDurability]=[self effect:DI2FeatureDurability object:melee ? item : NULL wanted:_wanted[DI2FeatureDurability] factor:1];
    if (_wanted[DI2FeatureDurability] && melee) {
        // The native hit path checks the registered reasons and returns zero.
        // Only display green after reading that result, not merely after a call.
        float loss=_api.durabilityLoss ? _api.durabilityLoss(item) : NAN;
        float current=0, maximum=0;
        BOOL measured=[self readFloat:item offset:0xc20 result:&current]
            && [self readFloat:item offset:0x1320 result:&maximum];
        active[DI2FeatureDurability]=active[DI2FeatureDurability] && isfinite(loss) && loss==0;
        NSString *note;
        if (!isfinite(loss)) note=@"Nahkampfwaffe erkannt · Haltbarkeitsschutz noch nicht bestätigt.";
        else if (measured) note=[NSString stringWithFormat:@"Haltbarkeit %.1f / %.1f · Abzug pro Treffer %.3f%@",current,maximum,loss,active[DI2FeatureDurability] ? @" · Schutz bestätigt" : @" · Schutz nicht bestätigt"];
        else note=[NSString stringWithFormat:@"Nahkampfwaffe erkannt · Abzug pro Treffer %.3f",loss];
        state.features[DI2FeatureDurability].note=note;
        if (feature==DI2FeatureDurability || active[DI2FeatureDurability]!=_durabilityWasActive) {
            _lastMessage=note;
            os_log(_log,"Durability heldMelee=1 active=%d loss=%.3f current=%.1f maximum=%.1f",active[DI2FeatureDurability],loss,current,maximum);
        }
    } else if (_wanted[DI2FeatureDurability]) state.features[DI2FeatureDurability].note=@"Wartet auf eine Nahkampfwaffe im physischen Haupthand-Slot.";
    _durabilityWasActive=active[DI2FeatureDurability];
    active[DI2FeatureAmmo]=[self effect:DI2FeatureAmmo object:ammo wanted:_wanted[DI2FeatureAmmo] factor:1];
    active[DI2FeatureNoReload]=[self effect:DI2FeatureNoReload object:ammo wanted:_wanted[DI2FeatureNoReload] factor:1];
    active[DI2FeaturePlayerSpeed]=[self effect:DI2FeaturePlayerSpeed object:player wanted:_wanted[DI2FeaturePlayerSpeed] factor:_values[DI2FeaturePlayerSpeed]];
    active[DI2FeatureGameSpeed]=[self effect:DI2FeatureGameSpeed object:world wanted:_wanted[DI2FeatureGameSpeed] factor:_values[DI2FeatureGameSpeed]];
    active[DI2FeatureDefenseMultiplier]=[self effect:DI2FeatureDefenseMultiplier object:damageable wanted:_wanted[DI2FeatureDefenseMultiplier] factor:_values[DI2FeatureDefenseMultiplier]];
    active[DI2FeatureInfiniteFury]=[self effect:DI2FeatureInfiniteFury object:fury wanted:_wanted[DI2FeatureInfiniteFury] factor:1];
    active[DI2FeatureAccuracy]=[self effect:DI2FeatureAccuracy object:spread wanted:_wanted[DI2FeatureAccuracy] factor:1];
    active[DI2FeatureNoRecoil]=[self effect:DI2FeatureNoRecoil object:recoil wanted:_wanted[DI2FeatureNoRecoil] factor:1];
    BOOL damageApplied=[self effect:DI2FeatureDamageMultiplier object:damage wanted:_wanted[DI2FeatureDamageMultiplier] || _wanted[DI2FeatureOneHit] factor:_wanted[DI2FeatureOneHit] ? 100000 : _values[DI2FeatureDamageMultiplier]];
    BOOL forceApplied=[self effect:DI2FeatureForceMultiplier object:force wanted:_wanted[DI2FeatureForceMultiplier] || _wanted[DI2FeatureSuperForce] factor:_wanted[DI2FeatureSuperForce] ? 100000 : _values[DI2FeatureForceMultiplier]];
    active[DI2FeatureDamageMultiplier]=damageApplied && _wanted[DI2FeatureDamageMultiplier]; active[DI2FeatureOneHit]=damageApplied && _wanted[DI2FeatureOneHit];
    active[DI2FeatureForceMultiplier]=forceApplied && _wanted[DI2FeatureForceMultiplier]; active[DI2FeatureSuperForce]=forceApplied && _wanted[DI2FeatureSuperForce];
    active[DI2FeatureCurveball]=throwing && _wanted[DI2FeatureCurveball];
    if (active[DI2FeatureCurveball]) _api.resetCurveballs(throwing);
    if (progression) {
        int32_t now=_api.getXP(progression);
        if (_wanted[DI2FeatureXPMultiplier] && _api.weakGet(&_xpOwner)==progression && feature!=DI2FeatureMaxXP) {
            int64_t gain=(int64_t)now-_lastXP;
            if (gain>0 && now>=0) {
                int64_t bonus=(int64_t)MIN((double)INT_MAX-now,floor(gain*(_values[DI2FeatureXPMultiplier]-1)));
                if (bonus>0) { [self ensureReason]; _api.addXP(progression,(int32_t)bonus,_reason); }
            }
        }
        _lastXP=_api.getXP(progression); _api.weakAssign(&_xpOwner,progression);
        active[DI2FeatureXPMultiplier]=_wanted[DI2FeatureXPMultiplier];
    } else { memset(&_xpOwner,0,sizeof(_xpOwner)); _lastXP=0; }
    [_extra updatePlayer:player controller:controller inventory:inventory wanted:_wanted values:_values
        available:available active:active states:state.features];
    const DI2Feature extraKinds[]={DI2FeatureStealth,DI2FeatureMovementSpeed,DI2FeatureConsumables,DI2FeatureItems,DI2FeatureCrafting};
    for (NSUInteger i=0;i<sizeof(extraKinds)/sizeof(extraKinds[0]);i++) {
        DI2Feature kind=extraKinds[i];
        if (feature==kind && _wanted[kind]) _lastMessage=active[kind]
            ? [NSString stringWithFormat:@"%@: AN · Laufzeitzustand bestätigt",DI2FeatureInfoAt(kind)->title] : state.features[kind].note;
    }
    for (NSInteger i=0;i<DI2FeatureCount;i++) {
        DI2FeatureState *itemState=state.features[i]; itemState.available=available[i]; itemState.active=active[i]; itemState.wanted=_wanted[i];
    }
    const DI2Feature weaponFeatures[]={DI2FeatureAmmo,DI2FeatureNoReload,DI2FeatureAccuracy,DI2FeatureNoRecoil,
        DI2FeatureDamageMultiplier,DI2FeatureOneHit,DI2FeatureForceMultiplier,DI2FeatureSuperForce,DI2FeatureCurveball};
    for (NSUInteger i=0;i<sizeof(weaponFeatures)/sizeof(weaponFeatures[0]);i++) {
        DI2Feature kind=weaponFeatures[i];
        if (_wanted[kind] && !active[kind]) {
            state.features[kind].note=available[kind]
                ? @"Passende Anbindung erkannt, Änderung aber noch nicht bestätigt. Der Schalter bleibt orange."
                : @"Wartet auf passende lokale Ausrüstung mit gültigem Besitzer. Veraltete oder fremde Module werden nicht verändert.";
            if (feature==kind) _lastMessage=state.features[kind].note;
        }
    }
    state.healthAvailable=health!=NULL; state.staminaAvailable=stamina!=NULL; state.ammoAvailable=ammo!=NULL;
    state.healthEnabled=active[DI2FeatureGod]; state.staminaEnabled=active[DI2FeatureStamina]; state.ammoEnabled=_wanted[DI2FeatureAmmo];
    if (stamina) { state.staminaValue=@(_api.stamina(stamina)); state.staminaMaximum=@(_api.maxStamina(stamina)); }
    if (ammo) state.ammoValue=@(_api.ammo(ammo));
    state.message=_lastMessage; return state;
}
- (void)poll { [self performAction:DI2TrainerPoll]; }
- (void)setOverlayInteraction:(BOOL)enabled { [self submit:@{@"command":@50,@"value":@(enabled),@"context":@0}]; }
- (void)performAction:(DI2TrainerAction)action { [self submit:@{@"command":@(action),@"context":@(_state.context)}]; }
- (void)setWanted:(BOOL)wanted forFeature:(DI2Feature)feature {const DI2FeatureInfo *info=DI2FeatureInfoAt(feature);if(info && info->implemented && !info->oneShot)[self submit:@{@"command":@(300+feature),@"value":@(wanted),@"context":@(_state.context)}];}
- (void)performFeature:(DI2Feature)feature {
    if (DI2FeatureInfoAt(feature)) [self submit:@{@"command":@(100+feature),@"context":@(_state.context)}];
}
- (void)setValue:(double)value forFeature:(DI2Feature)feature {
    const DI2FeatureInfo *info=DI2FeatureInfoAt(feature);
    if (info && info->numeric && isfinite(value) && value>=info->minimum && value<=info->maximum)
        [self submit:@{@"command":@(200+feature),@"value":@(value),@"context":@(_state.context)}];
}
- (void)submit:(NSDictionary *)request {
    NSAssert(NSThread.isMainThread,@"Commands originate on main thread");
    if (!_supported) return;
    if (_inFlight) {
        NSInteger command=[request[@"command"] integerValue];
        if (command==50 || command==DI2TrainerDisableAll) {
            // UI release and explicit stop survive a full queue and loading.
            NSIndexSet *old=[_commands indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry,NSUInteger index,BOOL *stop) {
                (void)index; (void)stop; NSInteger queued=[entry[@"command"] integerValue];
                return command==DI2TrainerDisableAll ? queued!=50 : queued==command;
            }];
            [_commands removeObjectsAtIndexes:old]; [_commands insertObject:request atIndex:0];
        } else if ([request[@"command"] integerValue]!=DI2TrainerPoll && _commands.count<16) [_commands addObject:request];
        return;
    }
    SEL selector=NSSelectorFromString(@"gameThread");
#ifdef DI2_TRAINER_TESTING
    if (!_testing)
#endif
    if (![NSThread respondsToSelector:selector] || !((id (*)(id,SEL))objc_msgSend)(NSThread.class,selector)) return;
    _inFlight=YES;
    _api.gameThreadCall(^{ @autoreleasepool {
        DI2TrainerState *next=[self update:[request[@"command"] integerValue] value:request[@"value"] context:[request[@"context"] unsignedLongLongValue]];
        dispatch_async(dispatch_get_main_queue(),^{
            self.state=next; self->_inFlight=NO;
            if (self.stateChanged) self.stateChanged(next);
            if (!next.ready) {
                NSIndexSet *cheats=[self->_commands indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry,NSUInteger index,BOOL *stop) {
                    (void)index; (void)stop; NSInteger command=[entry[@"command"] integerValue];
                    return command!=50 && command!=DI2TrainerDisableAll;
                }];
                [self->_commands removeObjectsAtIndexes:cheats];
            }
            if (self->_commands.count) { NSDictionary *queued=self->_commands.firstObject; [self->_commands removeObjectAtIndex:0]; [self submit:queued]; }
        });
    } },@[NSDefaultRunLoopMode],false);
}
@end
