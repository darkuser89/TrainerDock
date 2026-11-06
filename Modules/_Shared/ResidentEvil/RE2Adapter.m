// SPDX-License-Identifier: GPL-3.0-only
#import "RE2Adapter.h"
#import "RE2Engine.h"
#import "RE2Bindings.h"
#import "RE2Ownership.h"
#import "MemoryAccess.h"
#include <math.h>
#import <os/log.h>

static uintptr_t pointer(void *object,size_t offset){uintptr_t value=0;MTReadMemory((uint8_t *)object+offset,&value,sizeof(value));return value;}
static uint32_t integer(void *object,size_t offset){uint32_t value=0;MTReadMemory((uint8_t *)object+offset,&value,sizeof(value));return value;}
// Native PlaySpeed and effective MotionSpeed must be changed together. Scaling
// the current effective value by the input ratio preserves water/script factors.
static BOOL RE2WriteLocalSpeed(MTRE2Engine *engine,void *controller,float target,float reference){
    if(!engine.isGameThread || !engine.threadContext || !isfinite(target) || target<=0 || target>30 || !isfinite(reference) || reference<=0 || reference>32)return NO;
    float (*getPlay)(void *,void *)=[engine method:191873 owner:23201];
    void (*setPlay)(void *,void *,float)=[engine method:191874 owner:23201];
    float (*getMotion)(void *,void *)=[engine method:191875 owner:23201];
    void (*setMotion)(void *,void *,float)=[engine method:191876 owner:23201];
    if(!getPlay || !setPlay || !getMotion || !setMotion)return NO;
    void *ctx=engine.threadContext;float before=getPlay(ctx,controller),motion=getMotion(ctx,controller);
    if(!isfinite(before) || before<=0 || before>32 || !isfinite(motion) || motion<0 || motion>100)return NO;
    float effective=motion*(target/reference);if(!isfinite(effective) || effective>100)return NO;
    setPlay(ctx,controller,target);setMotion(ctx,controller,effective);
    BOOL ok=fabsf(getPlay(ctx,controller)-target)<0.0001f && fabsf(getMotion(ctx,controller)-effective)<0.0001f;
    if(!ok){setPlay(ctx,controller,before);setMotion(ctx,controller,motion);}
    return ok;
}
@interface RE2Value : NSObject
@property(nonatomic) RE2Owner *owner;
@property(nonatomic) void *object;
@property(nonatomic) size_t offset,size;
@property(nonatomic) NSData *before,*written;
@property(nonatomic) BOOL global;
@property(nonatomic) BOOL failed;
@property(nonatomic) void *stockSlot;
@property(nonatomic,copy) BOOL (^bindingGuard)(void);
@property(nonatomic,copy) NSData *(^reader)(void);
@property(nonatomic,copy) void (^writer)(NSData *);
@end
@implementation RE2Value
@end
@implementation RE2NativeAdapter {
    MTRE2Engine *_engine;
    RE2Owner *_playerOwner;
    void *_condition,*_health,*_equipment,*_gun,*_record,*_inventory;
    NSMutableDictionary<NSNumber *,NSMutableArray<RE2Value *> *> *_effects;
    NSString *_loggedIdentity;
    os_log_t _log;
    NSMutableDictionary<NSNumber *,NSNumber *> *_desired;
    BOOL _continuousInstalled,_mouseOwned;
    void *_mouseDevice;
    uint8_t _mouseBefore[3];
    RE2Owner *_countDownOwner;
    uint64_t _countDownGuid[2];
    RE2Owner *_speedOwner;
    void *_boardManager;
    int32_t _boardsID;
    BOOL _boardsChecked;
    uint32_t _boardCursor;
    float _speedObserved,_speedBaseline,_speedWritten,_speedEffectiveWritten;
    BOOL _speedOutstanding,_speedHasBaseline,_speedEffectiveOutstanding,_speedMethodsLogged;
    CFAbsoluteTime _speedTelemetryAt;
    uint32_t _speedTelemetryCalls,_speedTelemetryRestores;
    NSMutableDictionary<NSValue *,RE2Owner *> *_highlightOwners;
    NSUInteger _highlightConfirmed;
    NSString *_highlightStage;
    NSString *_enemyBindingStage;
    NSString *_portableStage;
    NSMutableDictionary *_portableProbe;
    NSMutableDictionary<NSNumber *,NSString *> *_enemyCounts;
    CFAbsoluteTime _saveCountVerifyAt;
    void *_saveCountVerifyRecord;
    NSString *_saveCountVerifyIdentity;
}
- (instancetype)init {if((self=[super init])){_engine=MTRE2Engine.shared;_effects=[NSMutableDictionary new];_desired=[NSMutableDictionary new];_log=os_log_create("local.mactrainer.re2","effects");}return self;}
- (void)onGameThread:(dispatch_block_t)work {
    if([_engine installGameThreadDelivery])[_engine enqueue:work];
    else dispatch_async(dispatch_get_main_queue(),work);
}
- (void *)objectGetter:(uint32_t)index owner:(uint32_t)owner object:(void *)object {
    void *(*fn)(void *,void *)=[_engine method:index owner:owner];
    return fn && object && _engine.threadContext ? fn(_engine.threadContext,object) : NULL;
}
- (void *)registeredEnemyController:(void *)registration {
    if(!_engine.isGameThread || [_engine typeOf:registration]!=RE2Type_EnemyRegistration)return NULL;
    void *controller=[self objectGetter:RE2Method_EnemyRegistration_get_Controller owner:RE2Type_EnemyRegistration object:registration];
    return [_engine isObject:controller kindOf:12402] ? controller : NULL;
}
- (void)portableStage:(NSString *)stage {
    if(_portableProbe)_portableProbe[@"stage"]=stage;
    if(![_portableStage isEqual:stage]){_portableStage=[stage copy];os_log(_log,"Portable safe binding %{public}@",stage);}
}
- (void *)component:(uint32_t)type onGameObject:(void *)go {
    if([_engine typeOf:go]!=33484)return NULL;
    void *array=[self objectGetter:226025 owner:33484 object:go];
    if([_engine typeOf:array]!=20243)return NULL;
    uint32_t count=integer(array,0x1c);if(count>128)return NULL;
    for(uint32_t i=0;i<count;i++){void *part=(void *)pointer(array,0x20+i*8);if([_engine typeOf:part]==type)return part;}
    return NULL;
}
- (void *)openedPortableSafe {
    if(!_engine.isGameThread || !_engine.threadContext){[self portableStage:@"no game-thread context"];return NULL;}
    void *gui=[_engine singletonAt:0x10b15bc38];
    if(_portableProbe)_portableProbe[@"guiType"]=@([_engine typeOf:gui]);
    if([_engine typeOf:gui]!=7343){[self portableStage:@"GUI master not resolved"];return NULL;}
    uint64_t boxed[4]={0};
    if(!MTReadMemory((uint8_t *)gui+0x408,boxed+2,16) || !(boxed[2]|boxed[3])){[self portableStage:@"inventory UI reference missing"];return NULL;}
    void *(*resolve)(void *,void *)=[_engine method:RE2Method_WeakGO_get_Target owner:RE2Type_WeakGO];
    void *go=resolve ? resolve(_engine.threadContext,boxed) : NULL;
    void *inventory=[self component:26435 onGameObject:go];
    if(!inventory){[self portableStage:@"inventory UI not resolved"];return NULL;}
    void *detail=[self objectGetter:109769 owner:26435 object:inventory];
    if(_portableProbe)_portableProbe[@"detailType"]=@([_engine typeOf:detail]);
    if([_engine typeOf:detail]!=765){[self portableStage:@"detail not resolved"];return NULL;}
    BOOL (*puzzleMode)(void *,void *)=[_engine method:109192 owner:765];
    if(!puzzleMode || !puzzleMode(_engine.threadContext,detail)){[self portableStage:@"no active item puzzle"];return NULL;}
    void *model=[self objectGetter:109171 owner:765 object:detail];
    if(_portableProbe)_portableProbe[@"modelType"]=@([_engine typeOf:model]);
    if([_engine typeOf:model]!=19820){[self portableStage:@"item model not resolved"];return NULL;}
    for(NSNumber *getter in @[@109141,@109139]){
        void *modelGO=[self objectGetter:getter.unsignedIntValue owner:19820 object:model];
        void *safe=[self component:9088 onGameObject:modelGO];
        RE2Owner *owner=safe ? [RE2Owner ownerForComponent:safe engine:_engine] : nil;
        if(owner.valid){[self portableStage:@"current portable safe bound"];return safe;}
    }
    [self portableStage:@"portable component not on current model"];return NULL;
}
- (BOOL)solvePortableSafe:(void *)safe owner:(RE2Owner *)owner {
    if(!_engine.isGameThread || !_engine.threadContext || [_engine typeOf:safe]!=9088 || !owner.valid || owner.component!=safe || [self openedPortableSafe]!=safe){[self portableStage:@"no current valid portable-safe owner"];return NO;}
    void *ctx=_engine.threadContext;
    void *answers=[self objectGetter:454672 owner:9088 object:safe];
    void *input=[self objectGetter:454674 owner:9088 object:safe];
    int32_t (*count)(void *,void *)=[_engine method:6331 owner:12274];
    int32_t (*at)(void *,void *,int32_t)=[_engine method:6337 owner:12274];
    void (*clear)(void *,void *)=[_engine method:454693 owner:9088];
    // Exact TDB74: ResizeUserInput returns void and takes no explicit arguments.
    void (*resize)(void *,void *)=[_engine method:454694 owner:9088];
    void (*setInput)(void *,void *,int32_t)=[_engine method:454695 owner:9088];
    BOOL (*incorrect)(void *,void *)=[_engine method:454696 owner:9088];
    BOOL (*finished)(void *,void *)=[_engine method:454686 owner:9088];
    uint8_t demo=1,updating=0;
    if(!count || !at || !clear || !setInput || !incorrect || !finished){[self portableStage:@"required native method missing"];return NO;}
    uint32_t answersType=[_engine typeOf:answers],inputType=[_engine typeOf:input];
    if(_portableProbe){_portableProbe[@"answerType"]=@(answersType);_portableProbe[@"inputType"]=@(inputType);}
    if(answersType!=12274 || inputType!=12274){[self portableStage:@"unexpected answer/input list type"];return NO;}
    int32_t answerCount=count(ctx,answers),inputCount=count(ctx,input);
    BOOL flags=MTReadMemory((uint8_t *)safe+0xc0,&demo,1) && MTReadMemory((uint8_t *)safe+0x52,&updating,1);
    BOOL complete=finished(ctx,safe);
    if(_portableProbe){_portableProbe[@"answerCount"]=@(answerCount);_portableProbe[@"inputCount"]=@(inputCount);_portableProbe[@"flagsReadable"]=@(flags);_portableProbe[@"demo"]=@(demo);_portableProbe[@"updating"]=@(updating);_portableProbe[@"complete"]=@(complete);_portableProbe[@"userInputCount"]=@(integer(safe,0xb8));}
    if(answerCount!=8 || (inputCount!=0 && inputCount!=8)){[self portableStage:@"unexpected answer/input list count"];return NO;}
    if(inputCount==0 && !resize){[self portableStage:@"native input initialization unavailable"];return NO;}
    if(!flags || demo || updating!=1 || complete){[self portableStage:@"puzzle not accepting input"];return NO;}
    int32_t solution[8];uint32_t seen=0;
    for(int i=0;i<8;i++){solution[i]=at(ctx,answers,i);if(solution[i]<0 || solution[i]>7 || (seen&(1u<<solution[i]))){[self portableStage:@"answer sequence is not a permutation of eight buttons"];return NO;}seen|=1u<<solution[i];}
    if(!owner.valid || [self openedPortableSafe]!=safe)return NO;
    // Exact Mac native ClearUserInput resets count and answering/incorrect flags.
    // SetUserInput writes the slot at UserInputCount-1; CheckInput returns
    // TRUE for an INCORRECT prefix. WaitPuzzle reads IsSatisfy at +0xbf.
    clear(ctx,safe);
    if(integer(safe,0xb8)!=0)return NO;
    // A newly opened safe may have an empty UserInput list. Let the game
    // allocate its eight slots; never index an empty list or fake its Count.
    if([self objectGetter:454674 owner:9088 object:safe]!=input)return NO;
    int32_t preparedCount=count(ctx,input);
    if(preparedCount==0 && resize){resize(ctx,safe);preparedCount=count(ctx,input);}
    if(_portableProbe)_portableProbe[@"preparedInputCount"]=@(preparedCount);
    if(!owner.valid || [self openedPortableSafe]!=safe || [self objectGetter:454674 owner:9088 object:safe]!=input || preparedCount!=8 || integer(safe,0xb8)!=0){[self portableStage:@"native input initialization failed"];return NO;}
    for(int i=0;i<8;i++){
        if(!owner.valid || [self openedPortableSafe]!=safe)return NO;
        if(!MTWriteInt(safe,0xb8,i+1)){clear(ctx,safe);return NO;}
        setInput(ctx,safe,solution[i]);
        if(incorrect(ctx,safe) || integer(safe,0xb8)!=(uint32_t)(i+1) || [self objectGetter:454674 owner:9088 object:safe]!=input || count(ctx,input)!=8 || at(ctx,input,i)!=solution[i]){if(_portableProbe)_portableProbe[@"failedStep"]=@(i+1);[self portableStage:@"native input verification failed"];clear(ctx,safe);return NO;}
    }
    for(int i=0;i<8;i++)if(at(ctx,input,i)!=solution[i]){clear(ctx,safe);return NO;}
    if(!owner.valid || [self openedPortableSafe]!=safe || incorrect(ctx,safe))return NO;
    BOOL result=MTWriteByte(safe,0xbf,1) && finished(ctx,safe);
    [self portableStage:result ? @"completed" : @"completion readback failed"];
    os_log(_log,"Portable safe solve count=%{public}u nativeIncorrect=%{public}d finished=%{public}d",integer(safe,0xb8),incorrect(ctx,safe),result);
    // The inventory's normal WaitPuzzle -> EndPuzzle path supplies the reward.
    // Never call EndPuzzle twice or alter inventory/save files directly.
    return result;
}
- (void *)saveCountFlow {
    if(!_engine.isGameThread || !_engine.threadContext)return NULL;
    void *(*getInstance)(void *)=[_engine method:RE2Method_MainFlow_get_Instance owner:RE2Type_MainFlowSingleton];
    void *flow=getInstance ? getInstance(_engine.threadContext) : NULL;
    return [_engine typeOf:flow]==RE2Type_MainFlow ? flow : NULL;
}
- (BOOL)resetCurrentSaveCount:(void *)record {
    if(!_engine.isGameThread || !_engine.threadContext || [_engine typeOf:record]!=RE2Type_Record || [_engine singletonAt:0x10b18a2b0]!=record)return NO;
    int32_t (*get)(void *,void *)=[_engine method:RE2Method_Record_get_CurrentSaveCount owner:RE2Type_Record];
    void (*set)(void *,void *,int32_t)=[_engine method:RE2Method_Record_set_CurrentSaveCount owner:RE2Type_Record];
    int32_t (*getTimes)(void *,void *)=[_engine method:RE2Method_MainFlow_get_SaveTimes owner:RE2Type_MainFlow];
    void (*setTimes)(void *,void *,int32_t)=[_engine method:RE2Method_MainFlow_set_SaveTimes owner:RE2Type_MainFlow];
    void *flow=[self saveCountFlow];
    if(!get || !set || !getTimes || !setTimes || !flow)return NO;
    void *ctx=_engine.threadContext;int32_t before=get(ctx,record),timesBefore=getTimes(ctx,flow);
    if(before<0 || before>10000000 || timesBefore<0 || timesBefore>10000000 || [self saveCountFlow]!=flow)return NO;
    setTimes(ctx,flow,0);set(ctx,record,0);
    int32_t after=get(ctx,record),timesAfter=getTimes(ctx,flow);BOOL confirmed=after==0 && timesAfter==0;
    if(!confirmed){setTimes(ctx,flow,timesBefore);set(ctx,record,before);}
    os_log(_log,"RE2 save count native before=%{public}d after=%{public}d headerBefore=%{public}d headerAfter=%{public}d readback=%{public}d flowGetterVA=%{public}llx flowSetterVA=%{public}llx",before,after,timesBefore,timesAfter,confirmed,(unsigned long long)((uintptr_t)getTimes-_engine.slide),(unsigned long long)((uintptr_t)setTimes-_engine.slide));
    if(confirmed){_saveCountVerifyAt=CFAbsoluteTimeGetCurrent()+2;_saveCountVerifyRecord=record;_saveCountVerifyIdentity=[_playerOwner.identity copy];}
    return confirmed;
}
- (void *)validatedMainWeapon:(void *)equipment condition:(void *)condition {
    void *weapon=[self objectGetter:RE2Method_Equipment_get_MainWeapon owner:RE2Type_Equipment object:equipment];
    return weapon && (pointer(weapon,0xd0)!=(uintptr_t)equipment || pointer(equipment,0xd8)!=(uintptr_t)condition) ? NULL : weapon;
}
- (BOOL)continuousContextValid {
    if(!_engine.isGameThread || !_engine.threadContext || !_playerOwner.valid)return NO;
    BOOL (*loading)(void *)=[_engine method:351452 owner:18897];
    if(!loading || loading(_engine.threadContext))return NO;
    void *manager=[_engine singletonAt:0x10b190e18];
    void *condition=[self objectGetter:RE2Method_Player_get_CurrentPlayerCondition owner:RE2Type_Player object:manager];
    if(!condition || condition!=_condition)return NO;
    void *equipment=[self objectGetter:RE2Method_Condition_get_Equipment owner:RE2Type_Condition object:condition];
    return equipment==_equipment && [self validatedMainWeapon:equipment condition:condition]==_gun;
}
- (RE2GameContext *)captureContext {
    RE2GameContext *state=[RE2GameContext new];
    if(!_engine.isGameThread){state.note=_engine.failure;return state;}
    if(!_continuousInstalled){__weak RE2NativeAdapter *weakSelf=self;[_engine setContinuousWork:^{[weakSelf continuousFrame];}];_continuousInstalled=YES;}
    void *manager=[_engine singletonAt:0x10b190e18];
    BOOL (*loading)(void *)=[_engine method:351452 owner:18897];
    if(!loading || loading(_engine.threadContext)){
        _playerOwner=nil;state.kind=RE2SessionLoading;state.identity=@"loading";state.note=@"Engine-Ladevorgang; Effekte werden gelöst.";return state;
    }
    void *condition=[self objectGetter:RE2Method_Player_get_CurrentPlayerCondition owner:RE2Type_Player object:manager];
    if(!condition){_playerOwner=nil;state.kind=RE2SessionLoading;state.identity=@"loading";state.note=@"Wartet auf die lokale Spielfigur.";return state;}
    RE2Owner *owner=[RE2Owner ownerForComponent:condition engine:_engine];
    if(!owner.valid){_playerOwner=nil;state.kind=RE2SessionLoading;state.identity=@"loading";state.note=@"Lokaler Besitzer noch nicht bestätigt.";return state;}
    _condition=condition;_health=[self objectGetter:RE2Method_Condition_get_HitPointController owner:RE2Type_Condition object:condition];
    _equipment=[self objectGetter:RE2Method_Condition_get_Equipment owner:RE2Type_Condition object:condition];
    _gun=[self validatedMainWeapon:_equipment condition:condition];
    _record=[_engine singletonAt:0x10b18a2b0];_inventory=[_engine singletonAt:0x10b185e98];
    // Native RE2's local campaign character is the supported gameplay context.
    // Generic engine networking and RE.Net telemetry are not multiplayer evidence.
    RE2Owner *weaponOwner=_gun ? [RE2Owner ownerForComponent:_gun engine:_engine] : nil;
    state.kind=RE2SessionSolo;state.identity=[owner.identity stringByAppendingFormat:@"/%@",weaponOwner.identity ?: @"no-weapon"];
    state.note=@"RE2 · lokale Spielfigur und GameThread bestätigt.";_playerOwner=owner;
    if(![_loggedIdentity isEqual:state.identity]){_loggedIdentity=[state.identity copy];os_log(_log,"Local player context bound; equipped weapon validated=%{public}d",_gun!=NULL);}
    return state;
}
- (BOOL)write:(RE2Value *)value bytes:(NSData *)bytes {
    if((!value.global && !value.owner.valid) || (value.bindingGuard && !value.bindingGuard()))return NO;
    if(value.stockSlot && pointer((void *)pointer(value.stockSlot,0x10),0x10)!=(uintptr_t)value.object)return NO;
    if(value.reader && value.writer){value.writer(bytes);return [value.reader() isEqual:bytes];}
    BOOL result=NO;
    if(value.size==1){uint8_t n;[bytes getBytes:&n length:1];result=MTWriteByte(value.object,value.offset,n);}
    else if(value.size==4){uint32_t n;[bytes getBytes:&n length:4];result=MTWriteInt(value.object,value.offset,(int32_t)n);}
    else if(value.size==8){uint64_t n;[bytes getBytes:&n length:8];result=MTWriteUInt64(value.object,value.offset,n);}
    uint8_t readback[8]={0};return result && MTReadMemory((uint8_t *)value.object+value.offset,readback,value.size) && !memcmp(readback,bytes.bytes,value.size);
}
- (void)releaseFeature:(RE2Feature)feature {
    if(feature==RE2FeatureSpeed)_speedObserved=0;
    // FloatIconBehavior.lateUpdate clears RequestDraw each frame and runs its
    // native close animation without a fresh request. Never close all game icons.
    if(feature==RE2FeatureHighlight){
        if(_highlightOwners.count || _highlightConfirmed)os_log(_log,"Native highlights stopped; drawing owners released");
        [_highlightOwners removeAllObjects];_highlightConfirmed=0;
    }
    for(RE2Value *value in _effects[@(feature)]){
        BOOL shared=NO;
        for(NSNumber *key in _effects)if(key.integerValue!=feature)for(RE2Value *other in _effects[key]){
            if(other.object==value.object && other.offset==value.offset && other.size==value.size && [other.written isEqual:value.written] && (other.global || other.owner.valid) && (!other.bindingGuard || other.bindingGuard())){shared=YES;break;}
        }
        if(shared)continue;
        uint8_t current[8];
        // Restore only our still-present write; preserve subsequent game/mod changes.
        BOOL binding=(value.global || value.owner.valid) && (!value.bindingGuard || value.bindingGuard()) && (!value.stockSlot || pointer((void *)pointer(value.stockSlot,0x10),0x10)==(uintptr_t)value.object);
        BOOL owned=binding && (value.reader ? [value.reader() isEqual:value.written] : MTReadMemory((uint8_t *)value.object+value.offset,current,value.size) && !memcmp(current,value.written.bytes,value.size));
        if(owned){
            BOOL restored=[self write:value bytes:value.before];if(feature==RE2FeatureSpeed && restored){_speedTelemetryRestores++;_speedOutstanding=NO;_speedEffectiveOutstanding=NO;}os_log(_log,"Effect restore feature=%{public}ld readback=%{public}d",(long)feature,restored);
        }
    }
    [_effects removeObjectForKey:@(feature)];
}
- (void)releaseEffects {[_desired removeAllObjects];[self releaseFeature:RE2FeatureHighlight];for(NSNumber *feature in _effects.allKeys.copy)[self releaseFeature:feature.integerValue];}
- (void)continuousFrame {
    if(_mouseOwned)[self setOverlayInteraction:YES];
    if(_saveCountVerifyAt && CFAbsoluteTimeGetCurrent()>=_saveCountVerifyAt){
        _saveCountVerifyAt=0;
        if(_playerOwner.valid && [_playerOwner.identity isEqual:_saveCountVerifyIdentity] && _record==_saveCountVerifyRecord && [_engine singletonAt:0x10b18a2b0]==_record && [_engine typeOf:_record]==RE2Type_Record){
            int32_t (*get)(void *,void *)=[_engine method:RE2Method_Record_get_CurrentSaveCount owner:RE2Type_Record];
            int32_t (*getTimes)(void *,void *)=[_engine method:RE2Method_MainFlow_get_SaveTimes owner:RE2Type_MainFlow];void *flow=[self saveCountFlow];
            if(get && getTimes && flow && _engine.threadContext){int32_t after=get(_engine.threadContext,_record),times=getTimes(_engine.threadContext,flow);os_log(_log,"RE2 save count delayed value=%{public}d header=%{public}d zero=%{public}d",after,times,after==0 && times==0);}
        }
        _saveCountVerifyRecord=NULL;_saveCountVerifyIdentity=nil;
    }
    if(_speedOutstanding && !_desired[@(RE2FeatureSpeed)])[self restorePendingLocalSpeed];
    if(!_desired.count)return;
    // Use the same native weapon binding as captureContext. A cached raw slot
    // can differ while the equipped weapon is valid; treating that as loading
    // used to restore/reapply every poll and made the player stutter.
    if(![self continuousContextValid]){[self releaseEffects];return;}
    for(NSNumber *feature in _desired.allKeys.copy)[self applyFeature:feature.integerValue wanted:YES value:_desired[feature].doubleValue];
}
- (void *)countDownComponent {
    void *gui=[_engine singletonAt:0x10b15bc38];uint64_t guid[2]={0};
    if([_engine typeOf:gui]!=7343 || !MTReadMemory((uint8_t *)gui+0x278,guid,16) || !(guid[0]|guid[1]))return NULL;
    if(_countDownOwner.valid && !memcmp(guid,_countDownGuid,16))return _countDownOwner.component;
    [self releaseFeature:RE2FeatureCountdown];_countDownOwner=nil;
    uint64_t boxed[4]={0,0,guid[0],guid[1]};
    void *(*resolve)(void *,void *)=[_engine method:RE2Method_WeakGO_get_Target owner:RE2Type_WeakGO];
    void *go=resolve ? resolve(_engine.threadContext,boxed) : NULL;
    if([_engine typeOf:go]!=33484 || !pointer(go,0x18))return NULL;
    void *array=[self objectGetter:226025 owner:33484 object:go];
    if([_engine typeOf:array]!=20243)return NULL;
    uint32_t length=integer(array,0x1c);if(length>128)return NULL;
    for(uint32_t i=0;i<length;i++){
        void *component=(void *)pointer(array,0x20+i*8);
        if([_engine typeOf:component]!=390)continue;
        RE2Owner *owner=[RE2Owner ownerForComponent:component engine:_engine];
        if(owner.valid){_countDownOwner=owner;memcpy(_countDownGuid,guid,16);os_log(_log,"Native countdown component bound");return component;}
    }return NULL;
}
- (void *)localMotionController {
    if(_speedOwner.valid && [self objectGetter:191902 owner:31594 object:_speedOwner.component]==_condition)return _speedOwner.component;
    [self releaseFeature:RE2FeatureSpeed];_speedOwner=nil;
    void *go=[self objectGetter:RE2Method_Component_get_GameObject owner:RE2Type_Component object:_condition];
    void *array=[self objectGetter:226025 owner:33484 object:go];
    if([_engine typeOf:array]!=20243)return NULL;
    uint32_t length=integer(array,0x1c);if(length>128)return NULL;
    for(uint32_t i=0;i<length;i++){
        void *component=(void *)pointer(array,0x20+i*8);
        if([_engine typeOf:component]!=31594 || [self objectGetter:191902 owner:31594 object:component]!=_condition)continue;
        RE2Owner *owner=[RE2Owner ownerForComponent:component engine:_engine];
        if(owner.valid){_speedOwner=owner;return component;}
    }return NULL;
}
- (float)speedReference:(float)input effective:(float)effective {
    // A transition can reset the input before resetting the already scaled
    // motion output. Recognize that specific owned output instead of doubling it.
    return _speedEffectiveOutstanding && fabsf(input-_speedBaseline)<0.0001f && fabsf(input-_speedWritten)>=0.0001f && fabsf(effective-_speedEffectiveWritten)<0.0001f ? _speedWritten : input;
}
- (BOOL)writeLocalSpeed:(float)target controller:(void *)controller {
    float (*play)(void *,void *)=[_engine method:191873 owner:23201];
    float (*motion)(void *,void *)=[_engine method:191875 owner:23201];
    if(!_engine.isGameThread || !_engine.threadContext || !play || !motion)return NO;
    float input=play(_engine.threadContext,controller),effective=motion(_engine.threadContext,controller);
    return RE2WriteLocalSpeed(_engine,controller,target,[self speedReference:input effective:effective]);
}
- (BOOL)applyLocalSpeedFactor:(float)factor controller:(void *)controller owner:(RE2Owner *)owner {
    if(!_engine.isGameThread || !owner.valid || owner.component!=controller || [_engine typeOf:controller]!=31594 || !isfinite(factor) || factor<1 || factor>3)return NO;
    float (*getPlay)(void *,void *)=[_engine method:191873 owner:23201];
    if(!getPlay || !_engine.threadContext)return NO;
    if(!_speedMethodsLogged){_speedMethodsLogged=YES;for(NSNumber *n in @[@191873,@191874,@191875,@191876]){void *f=[_engine method:n.unsignedIntValue owner:23201];os_log(_log,"Local speed method=%{public}u VA=%{public}llx",n.unsignedIntValue,(unsigned long long)(f ? (uintptr_t)f-_engine.slide : 0));}}
    float current=getPlay(_engine.threadContext,controller),baseline=current;
    NSData *old=[self baselineForNativeObject:controller tag:191873 feature:RE2FeatureSpeed];
    if(old.length==4)[old getBytes:&baseline length:4];
    else if(_speedHasBaseline && fabsf(current-_speedWritten)<0.0001f)baseline=_speedBaseline;
    if(!isfinite(baseline) || baseline<=0 || baseline>10)return NO;
    float target=baseline*factor;if(!isfinite(target) || target>30)return NO;
    MTRE2Engine *engine=_engine;
    float (*getMotion)(void *,void *)=[engine method:191875 owner:23201];
    if(!getMotion || ![engine method:191874 owner:23201] || ![engine method:191876 owner:23201] || !isfinite(current) || current<=0)return NO;
    float motionBefore=getMotion(engine.threadContext,controller);
    float effective=motionBefore*(target/[self speedReference:current effective:motionBefore]);if(!isfinite(effective) || effective<0 || effective>100)return NO;
    __weak RE2NativeAdapter *weakSelf=self;
    BOOL applied=[self applyNativeBytes:[NSData dataWithBytes:&target length:4] object:controller tag:191873 owner:owner feature:RE2FeatureSpeed guard:^BOOL{return owner.valid && owner.component==controller;} read:^NSData *{float v=getPlay(engine.threadContext,controller);return [NSData dataWithBytes:&v length:4];} write:^(NSData *bytes){float v;[bytes getBytes:&v length:4];[weakSelf writeLocalSpeed:v controller:controller];}];
    applied=applied && fabsf(getMotion(engine.threadContext,controller)-effective)<0.0001f;
    // A replaced controller may inherit our multiplier. Its ledger must retain
    // the clean baseline, never adopt the carried write as a new original.
    for(RE2Value *entry in _effects[@(RE2FeatureSpeed)])if(entry.object==controller)entry.before=[NSData dataWithBytes:&baseline length:4];
    if(applied){_speedBaseline=baseline;_speedWritten=target;_speedEffectiveWritten=effective;_speedOutstanding=YES;_speedEffectiveOutstanding=YES;_speedHasBaseline=YES;
        if(_speedObserved!=target){_speedObserved=target;float (*motion)(void *,void *)=[_engine method:191875 owner:23201];os_log(_log,"Local speed stable baseline=%{public}f factor=%{public}f input=%{public}f effective=%{public}f",baseline,factor,getPlay(engine.threadContext,controller),motion ? motion(engine.threadContext,controller) : -1);}}
    if(applied){
        CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();_speedTelemetryCalls++;
        if(!_speedTelemetryAt)_speedTelemetryAt=now;
        if(now-_speedTelemetryAt>=2){os_log(_log,"Local speed interval input=%{public}f effective=%{public}f applications=%{public}u restores=%{public}u",getPlay(engine.threadContext,controller),getMotion(engine.threadContext,controller),_speedTelemetryCalls,_speedTelemetryRestores);_speedTelemetryAt=now;_speedTelemetryCalls=0;_speedTelemetryRestores=0;}
    }
    return applied;
}
- (void)restorePendingLocalSpeed {
    if(!_speedHasBaseline || !_engine.isGameThread)return;
    void *controller=[self localMotionController];if(!controller || !_speedOwner.valid)return;
    float (*getPlay)(void *,void *)=[_engine method:191873 owner:23201];if(!getPlay || !_engine.threadContext)return;
    float current=getPlay(_engine.threadContext,controller);
    float (*motion)(void *,void *)=[_engine method:191875 owner:23201];if(!motion)return;
    BOOL ownsInput=fabsf(current-_speedWritten)<0.0001f;
    BOOL ownsOutput=_speedEffectiveOutstanding && fabsf(current-_speedBaseline)<0.0001f && fabsf(motion(_engine.threadContext,controller)-_speedEffectiveWritten)<0.0001f;
    if(!ownsInput && !ownsOutput){_speedOutstanding=NO;_speedEffectiveOutstanding=NO;return;}
    _speedOutstanding=YES;
    BOOL restored=[self writeLocalSpeed:_speedBaseline controller:controller];
    if(restored){_speedTelemetryRestores++;_speedOutstanding=NO;_speedEffectiveOutstanding=NO;os_log(_log,"Local speed pending restore input=%{public}f readback=1",getPlay(_engine.threadContext,controller));}
}
- (int32_t)confirmedBoardID {
    void *manager=[_engine singletonAt:0x10b188068];
    if(manager!=_boardManager){_boardManager=manager;_boardsChecked=NO;_boardsID=-1;_boardCursor=0;}
    if(_boardsChecked)return _boardsID;
    void *(*getName)(void *,void *,int32_t)=[_engine method:434720 owner:9216];
    if([_engine typeOf:manager]!=9216 || !getName)return -1;
    // Iterate only existing native item definitions, at most eight names per
    // lookup pass. The exact Dictionary<Item.ID,ItemElement> has Entry stride 24,
    // key +8, value +16, entries +0x18, count +0x3c (TDB field owners 27575/19631).
    void *table=[self objectGetter:434815 owner:9216 object:manager];
    void *entries=(void *)pointer(table,0x18);uint32_t count=integer(table,0x3c);
    if([_engine typeOf:table]!=27575 || [_engine typeOf:entries]!=17861 || !count || count>512 || count>integer(entries,0x1c))return -1;
    for(NSUInteger n=0;n<8 && _boardCursor<count;n++,_boardCursor++){
        uint8_t *entry=(uint8_t *)entries+0x20+_boardCursor*24;
        void *definition=(void *)pointer(entry,0x10);
        if([_engine typeOf:definition]!=23759)continue;
        int32_t itemID=(int32_t)integer(entry,8);if(itemID<0)continue;
        void *string=getName(_engine.threadContext,manager,itemID);
        uint32_t length=integer(string,0x10);unichar characters[128];
        if([_engine typeOf:string]!=41649 || !length || length>128 || !MTReadMemory((uint8_t *)string+0x14,characters,length*2))continue;
        NSString *name=[[NSString alloc]initWithCharacters:characters length:length];
        if([name rangeOfString:@"Holzbrett" options:NSCaseInsensitiveSearch].location!=NSNotFound || [name rangeOfString:@"Wooden Board" options:NSCaseInsensitiveSearch].location!=NSNotFound){
            _boardsID=itemID;_boardsChecked=YES;
            os_log(_log,"Board item identity id=%{public}d name=%{public}s confirmed=1",itemID,name.UTF8String);break;
        }
    }
    if(_boardCursor>=count)_boardsChecked=YES;
    return _boardsID;
}
- (NSData *)baselineForObject:(void *)object offset:(size_t)offset feature:(RE2Feature)feature {
    for(RE2Value *entry in _effects[@(feature)])if(entry.object==object && entry.offset==offset)return entry.before;
    return nil;
}
- (BOOL)applyBytes:(NSData *)bytes object:(void *)object offset:(size_t)offset owner:(RE2Owner *)owner global:(BOOL)global feature:(RE2Feature)feature {
    return [self applyBytes:bytes object:object offset:offset owner:owner global:global feature:feature guard:nil];
}
- (BOOL)applyBytes:(NSData *)bytes object:(void *)object offset:(size_t)offset owner:(RE2Owner *)owner global:(BOOL)global feature:(RE2Feature)feature guard:(BOOL (^)(void))guard {
    return [self applyValueBytes:bytes object:object offset:offset owner:owner global:global feature:feature guard:guard read:nil write:nil];
}
- (NSData *)baselineForNativeObject:(void *)object tag:(uint32_t)tag feature:(RE2Feature)feature {
    return [self baselineForObject:object offset:(UINT64_C(1)<<63)|tag feature:feature];
}
- (BOOL)applyNativeBytes:(NSData *)bytes object:(void *)object tag:(uint32_t)tag owner:(RE2Owner *)owner feature:(RE2Feature)feature guard:(BOOL (^)(void))guard read:(NSData *(^)(void))read write:(void (^)(NSData *))write {
    if(!read || !write)return NO;
    return [self applyValueBytes:bytes object:object offset:(UINT64_C(1)<<63)|tag owner:owner global:NO feature:feature guard:guard read:read write:write];
}
- (BOOL)applyValueBytes:(NSData *)bytes object:(void *)object offset:(size_t)offset owner:(RE2Owner *)owner global:(BOOL)global feature:(RE2Feature)feature guard:(BOOL (^)(void))guard read:(NSData *(^)(void))read write:(void (^)(NSData *))write {
    if(guard && !guard())return NO;
    if(!object || (bytes.length!=1 && bytes.length!=4 && bytes.length!=8) || (!global && (!owner.valid || [_engine typeOf:object]==UINT32_MAX)))return NO;
    NSMutableArray<RE2Value *> *entries=_effects[@(feature)];if(!entries){entries=[NSMutableArray new];_effects[@(feature)]=entries;}
    RE2Value *value=nil;
    for(RE2Value *entry in entries)if(entry.object==object && entry.offset==offset){value=entry;break;}
    if(!value){
        uint8_t baseline[8];
        if(read){NSData *old=read();if(old.length!=bytes.length)return NO;[old getBytes:baseline length:bytes.length];}
        else if(!MTReadMemory((uint8_t *)object+offset,baseline,bytes.length))return NO;
        // Multiple selected effects can request the same enemy HP=1. Keep the
        // first original and restore it only after the last such effect leaves.
        for(NSNumber *key in _effects)if(key.integerValue!=feature)for(RE2Value *other in _effects[key]){
            if(other.object==object && other.offset==offset && other.size==bytes.length && [other.written isEqual:bytes] && (other.global || other.owner.valid) && (!other.bindingGuard || other.bindingGuard())){[other.before getBytes:baseline length:bytes.length];break;}
        }
        value=[RE2Value new];value.object=object;value.offset=offset;value.size=bytes.length;value.before=[NSData dataWithBytes:baseline length:bytes.length];value.owner=owner;value.global=global;value.reader=read;value.writer=write;
        if(!global)[owner retainPayload:object];[entries addObject:value];
        uint64_t oldBits=0,newBits=0;memcpy(&oldBits,baseline,bytes.length);memcpy(&newBits,bytes.bytes,bytes.length);
        os_log(_log,"Native value feature=%{public}ld offset=%{public}lu beforeBits=%{public}llx requestedBits=%{public}llx",(long)feature,(unsigned long)offset,(unsigned long long)oldBits,(unsigned long long)newBits);
    }
    value.bindingGuard=guard;BOOL changed=![value.written isEqual:bytes];value.written=bytes;BOOL confirmed=[self write:value bytes:bytes];
    if(changed || value.failed!=!confirmed)os_log(_log,"Effect apply feature=%{public}ld readback=%{public}d",(long)feature,confirmed);
    value.failed=!confirmed;return confirmed;
}
- (BOOL)highlightWaiting:(NSString *)stage {
    if(![_highlightStage isEqual:stage]){_highlightStage=[stage copy];os_log(_log,"Native highlight binding %{public}s",stage.UTF8String);}
    return NO;
}
- (BOOL)drawNativeHighlights {
    void *ctx=_engine.threadContext,*gui=[_engine singletonAt:0x10b15bc38];
    void *(*getManager)(void *)=[_engine method:11686 owner:2754];
    BOOL (*enabled)(void *,void *)=[_engine method:21424 owner:26820];
    void (*draw)(void *,void *)=[_engine method:20064 owner:38631];
    if(!ctx || [_engine typeOf:gui]!=7343 || !getManager || !enabled || !draw)return [self highlightWaiting:@"native methods unavailable"];
    const uint32_t menus[]={115375,115377,115379,115381};
    for(NSUInteger i=0;i<4;i++){BOOL (*menu)(void *,void *)=[_engine method:menus[i] owner:7343];if(!menu || menu(ctx,gui))return [self highlightWaiting:[NSString stringWithFormat:@"menu %u",menus[i]]];}
    void *manager=getManager(ctx);
    if([_engine typeOf:manager]!=21843)return [self highlightWaiting:[NSString stringWithFormat:@"manager type %u",[_engine typeOf:manager]]];
    // The per-frame _TrgWks list is distance filtered and later cleared.
    // LockObj.RegisteredKeys retains the loaded, enabled interaction triggers.
    void *registry=(void *)pointer(manager,0x78);
    if([_engine typeOf:registry]!=38697)return [self highlightWaiting:@"registry unavailable"];
    void *list=(void *)pointer(registry,0x18),*items=(void *)pointer(list,0x10);
    uint32_t count=integer(list,0x18),capacity=integer(items,0x1c);
    if([_engine typeOf:list]!=89437 || [_engine typeOf:items]!=37615 || count>2048 || count>capacity)return [self highlightWaiting:[NSString stringWithFormat:@"list type %u array type %u count %u capacity %u",[_engine typeOf:list],[_engine typeOf:items],count,capacity]];
    if(!_highlightOwners)_highlightOwners=[NSMutableDictionary new];
    [self highlightWaiting:@"registered keys bound"];
    NSMutableSet<NSValue *> *current=[NSMutableSet new];NSMutableSet<NSValue *> *drawnObjects=[NSMutableSet new];
    NSUInteger requested=0,confirmed=0;
    for(uint32_t i=0;i<count && requested<32;i++){
        void *work=(void *)pointer(items,0x20+i*8),*trigger=(void *)pointer(work,0x10);
        if([_engine typeOf:work]!=34427 || ![_engine isObject:trigger kindOf:38631] || !enabled(ctx,trigger) || integer(trigger,0xc4)==12)continue;
        void *go=[self objectGetter:21427 owner:26820 object:trigger];
        if([_engine typeOf:go]!=33484)continue;
        NSValue *key=[NSValue valueWithPointer:trigger];RE2Owner *owner=_highlightOwners[key];
        if(!owner.valid || owner.gameObject!=go){owner=[RE2Owner ownerForGameObject:go engine:_engine];if(!owner.valid)continue;[owner retainPayload:trigger];_highlightOwners[key]=owner;}
        [current addObject:key];
        void *iconGO=[self objectGetter:12231 owner:21745 object:trigger];
        NSValue *iconKey=[NSValue valueWithPointer:iconGO];
        if([_engine typeOf:iconGO]!=33484 || !pointer(iconGO,0x18) || [drawnObjects containsObject:iconKey])continue;
        [drawnObjects addObject:iconKey];draw(ctx,trigger);requested++;
        // Exact native GUI dictionary<GameObject,FloatIconBehavior>, Entry 24.
        // Confirm our requested object's native RequestDraw, never a UI-only flag.
        void *dictionary=(void *)pointer(gui,0x198),*entries=(void *)pointer(dictionary,0x18);
        uint32_t n=integer(dictionary,0x3c);
        if([_engine typeOf:dictionary]!=6149 || [_engine typeOf:entries]!=37684 || n>256 || n>integer(entries,0x1c))continue;
        for(uint32_t j=0;j<n;j++){
            uint8_t *entry=(uint8_t *)entries+0x20+j*24;
            void *icon=(void *)pointer(entry,0x10);uint8_t request=0;
            if(pointer(entry,8)==(uintptr_t)iconGO && [_engine typeOf:icon]==15917 && MTReadMemory((uint8_t *)icon+0xea,&request,1) && request==1){confirmed++;break;}
        }
    }
    for(NSValue *key in _highlightOwners.allKeys.copy)if(![current containsObject:key])[_highlightOwners removeObjectForKey:key];
    if(_highlightConfirmed!=confirmed){_highlightConfirmed=confirmed;os_log(_log,"Native highlights registered=%{public}u requested=%{public}lu confirmed=%{public}lu",count,(unsigned long)requested,(unsigned long)confirmed);}
    return confirmed>0;
}
- (RE2FeatureState *)applyFeature:(RE2Feature)feature wanted:(BOOL)wanted value:(double)number {
    RE2FeatureState *state=[RE2FeatureState new];state.note=@"Native Anbindung für diese Funktion wird noch geprüft.";
    if(!_engine.isGameThread || !_playerOwner.valid)return state;
    if(!wanted){[_desired removeObjectForKey:@(feature)];[self releaseFeature:feature];if(feature==RE2FeatureSpeed){[self restorePendingLocalSpeed];if(!_speedOutstanding)_speedHasBaseline=NO;}state.available=RE2FeatureInfoAt(feature)->implemented;state.note=state.available ? @"Aus." : @"Native Zuordnung noch nicht abgeschlossen.";return state;}
    _desired[@(feature)]=@(number);
    uint8_t yes=1;uint32_t zero=0;float factor=(float)number;BOOL applied=NO;
    if(feature==RE2FeatureHealth && [_engine typeOf:_health]==RE2Type_HP){
        RE2Owner *owner=[RE2Owner ownerForComponent:_health engine:_engine];
        applied=[self applyBytes:[NSData dataWithBytes:&yes length:1] object:_health offset:0x51 owner:owner global:NO feature:feature];
    }else if(feature==RE2FeatureHighlight){
        applied=[self drawNativeHighlights];
    }else if((feature==RE2FeatureAmmo || feature==RE2FeatureNoReload || feature==RE2FeatureRibbons || feature==RE2FeatureKnife || feature==RE2FeatureBoards) && (feature==RE2FeatureRibbons || feature==RE2FeatureKnife || feature==RE2FeatureBoards || _gun)){
        void *inv=(void *)pointer(_inventory,0x50);
        RE2Owner *owner=[RE2Owner ownerForComponent:inv engine:_engine];
        if([_engine typeOf:inv]!=18476 || !owner.valid || pointer(inv,0x80)!=(uintptr_t)_condition)return state;
        void *(*getSlot)(void *,void *,int32_t)=[_engine method:142013 owner:RE2Type_Inventory];
        int32_t (*maxCount)(void *,void *)=[_engine method:140443 owner:35166];
        int32_t (*bulletId)(void *,void *)=[_engine method:142036 owner:RE2Type_Inventory];
        int32_t (*weaponType)(void *,void *)=[_engine method:140433 owner:35166];
        int32_t (*weaponCategory)(void *,int32_t)=[_engine method:142105 owner:42536];
        if(!getSlot || !maxCount || !bulletId || !weaponType || !weaponCategory)return state;
        // Native GimmickTypeWriter.reduceInkRibbonNum consumes item 0x20.
        int32_t ammo=feature==RE2FeatureRibbons ? 0x20 : feature==RE2FeatureBoards ? [self confirmedBoardID] : bulletId(_engine.threadContext,_inventory),total=0;NSUInteger count=0;applied=YES;
        for(int32_t i=0;i<20;i++){
            void *slot=feature==RE2FeatureNoReload ? (void *)pointer(inv,0x98) : getSlot(_engine.threadContext,_inventory,i);
            if([_engine typeOf:slot]!=35166){if(feature==RE2FeatureNoReload)break;continue;}
            void *stock=(void *)pointer(slot,0x10),*item=(void *)pointer(stock,0x10);
            if([_engine typeOf:stock]!=39529 || [_engine typeOf:item]!=6498){if(feature==RE2FeatureNoReload)break;continue;}
            if(feature==RE2FeatureKnife){
                // Native getSubWeaponRemainingBullet selects knife category 9,
                // not raw weapon ID 9 (the exact table maps IDs 46..48 here).
                // getSubWeaponVital divides this same Count by get_MaxNumber.
                uint32_t remaining=integer(item,0x20);
                if(weaponCategory(_engine.threadContext,weaponType(_engine.threadContext,slot))!=9 || !remaining || remaining>1000000)continue;
            }else if(feature!=RE2FeatureNoReload && (ammo<=0 || integer(item,0x10)!=(uint32_t)ammo))continue;
            int32_t limit=maxCount(_engine.threadContext,slot);if(limit<1 || limit>(feature==RE2FeatureKnife ? 1000000 : 1000)){applied=NO;break;}
            if(feature==RE2FeatureNoReload){
                uint32_t before=integer(item,0x20);
                for(RE2Value *entry in _effects[@(feature)])if(entry.object==item && entry.offset==0x20){[entry.before getBytes:&before length:4];break;}
                if(before>1000){applied=NO;break;}limit=MAX(MAX(limit,2),(int32_t)before);
            }
            applied&=[self applyBytes:[NSData dataWithBytes:&limit length:4] object:item offset:0x20 owner:owner global:NO feature:feature];count++;
            for(RE2Value *entry in _effects[@(feature)])if(entry.object==item && entry.offset==0x20){entry.stockSlot=slot;[entry.owner retainPayload:slot];break;}
            total+=limit;
            if(feature==RE2FeatureNoReload)break;
        }
        applied&=count>0;
        if(feature==RE2FeatureRibbons && applied){
            RE2Owner *managerOwner=[RE2Owner ownerForComponent:_inventory engine:_engine];
            applied=[self applyBytes:[NSData dataWithBytes:&total length:4] object:_inventory offset:0xe4 owner:managerOwner global:NO feature:feature];
        }
    }else if(feature==RE2FeatureSpeed && isfinite(factor) && factor>=1 && factor<=3){
        void *controller=[self localMotionController];
        applied=[self applyLocalSpeedFactor:factor controller:controller owner:_speedOwner];
    }else if(feature==RE2FeatureCountdown){
        void *timer=[self countDownComponent];float current=0;
        if(timer && MTReadMemory((uint8_t *)timer+0x128,&current,4) && isfinite(current) && current>1 && current<3600000){
            NSArray<RE2Value *> *old=_effects[@(feature)];float frozen=current;
            if(old.count)[old[0].before getBytes:&frozen length:4];
            applied=[self applyBytes:[NSData dataWithBytes:&frozen length:4] object:timer offset:0x128 owner:_countDownOwner global:NO feature:feature];
        }
    }else if(feature==RE2FeatureOneHit || feature==RE2FeatureTyrant){
        void *manager=[_engine singletonAt:0x10b187168];
        void *list=[_engine typeOf:manager]==10375 ? [self objectGetter:131235 owner:10375 object:manager] : NULL;
        void *items=(void *)pointer(list,0x10);uint32_t count=integer(list,0x18),capacity=integer(items,0x1c);
        NSString *stage=[NSString stringWithFormat:@"manager=%u list=%u array=%u count=%u capacity=%u",[_engine typeOf:manager],[_engine typeOf:list],[_engine typeOf:items],count,capacity];
        if(![_enemyBindingStage isEqual:stage]){_enemyBindingStage=stage;os_log(_log,"RE2 enemy binding %{public}@",stage);}
        if([_engine typeOf:manager]!=10375 || [_engine typeOf:list]!=21657)return state;
        if([_engine typeOf:items]!=RE2Type_EnemyArray || count>512 || capacity>4096 || count>capacity)return state;
        uint32_t one=1;NSUInteger targets=0,registrations=0,controllers=0,hitpoints=0,alive=0,owners=0;applied=YES;
        for(uint32_t i=0;i<count;i++){
            // EnemyList stores registration wrappers, not EnemyController.
            // Resolve through RE2's own getter, which handles inactive contexts.
            void *registration=(void *)pointer(items,0x20+i*8);
            if([_engine typeOf:registration]!=RE2Type_EnemyRegistration)continue;registrations++;
            void *enemy=[self registeredEnemyController:registration];
            if(!enemy)continue;controllers++;
            if(feature==RE2FeatureTyrant){
                void *think=[self objectGetter:133258 owner:12402 object:enemy];
                if([_engine typeOf:think]!=37527)continue;
                float sleep=0;
                if(!MTReadMemory((uint8_t *)think+0x308,&sleep,4) || !isfinite(sleep) || sleep<0 || sleep>36000)continue;
                if(sleep>0){
                    RE2Owner *owner=[RE2Owner ownerForComponent:think engine:_engine];if(!owner.valid)continue;
                    float frozen=sleep;
                    for(RE2Value *entry in _effects[@(feature)])if(entry.object==think && entry.offset==0x308){[entry.before getBytes:&frozen length:4];break;}
                    applied&=[self applyBytes:[NSData dataWithBytes:&frozen length:4] object:think offset:0x308 owner:owner global:NO feature:feature];targets++;continue;
                }
            }
            void *hp=[self objectGetter:133246 owner:12402 object:enemy];
            if(![_engine isObject:hp kindOf:RE2Type_HP] || hp==_health)continue;hitpoints++;
            uint32_t health=integer(hp,0x58);if(!health || health>10000000)continue;alive++;
            if(health==1){
                // Still acquire a shared baseline when the other HP effect
                // already owns this write; an independent native HP=1 needs none.
                BOOL owned=NO,selfOwned=NO;for(NSNumber *key in _effects)for(RE2Value *entry in _effects[key])if(entry.object==hp && entry.offset==0x58){owned=YES;if(key.integerValue==feature)selfOwned=YES;}
                if(selfOwned || !owned){targets++;continue;}
            }
            RE2Owner *owner=[RE2Owner ownerForComponent:hp engine:_engine];if(!owner.valid)continue;owners++;
            applied&=[self applyBytes:[NSData dataWithBytes:&one length:4] object:hp offset:0x58 owner:owner global:NO feature:feature];targets++;
        }
        if(!_enemyCounts)_enemyCounts=[NSMutableDictionary new];
        NSString *counts=[NSString stringWithFormat:@"feature=%ld registrations=%lu controllers=%lu hp=%lu alive=%lu owners=%lu targets=%lu",(long)feature,(unsigned long)registrations,(unsigned long)controllers,(unsigned long)hitpoints,(unsigned long)alive,(unsigned long)owners,(unsigned long)targets];
        if(![_enemyCounts[@(feature)] isEqual:counts]){_enemyCounts[@(feature)]=counts;os_log(_log,"RE2 enemy targets %{public}@",counts);}
        applied&=targets>0;
    }else if(feature==RE2FeatureAccuracy && _gun){
        void *reticle=[self objectGetter:202541 owner:RE2Type_Gun object:_gun];
        RE2Owner *owner=[RE2Owner ownerForComponent:_gun engine:_engine];
        if([_engine typeOf:reticle]==13796 && owner.valid){
            applied=YES;
            // Accelerate focus gain, remove shot/movement focus penalties;
            // preserve the native focus interval and its nonzero denominator.
            const size_t fields[]={0x10,0x18,0x1c,0x20};
            for(NSUInteger i=0;i<4;i++){float n=i==0 ? 10000.0f : 0.0f;applied&=[self applyBytes:[NSData dataWithBytes:&n length:4] object:reticle offset:fields[i] owner:owner global:NO feature:feature];}
        }
    }else if(feature==RE2FeatureRecoil && _gun){
        void *recoil=[self objectGetter:RE2Method_Gun_get_RecoilParam owner:RE2Type_Gun object:_gun];
        RE2Owner *owner=[RE2Owner ownerForComponent:_gun engine:_engine];
        if(recoil && owner.valid){applied=YES;for(size_t offset=0x10;offset<=0x1c;offset+=4)applied&=[self applyBytes:[NSData dataWithBytes:&zero length:4] object:recoil offset:offset owner:owner global:NO feature:feature];}
    }else if(feature==RE2FeatureSlowMotion && isfinite(factor) && factor>=0.1f && factor<=1){
        void *gui=[_engine singletonAt:0x10b15bc38];
        if([_engine typeOf:gui]==7343){
            const uint32_t gates[]={115375,115377,115379,115381};
            for(NSUInteger i=0;i<4;i++){BOOL (*get)(void *,void *)=[_engine method:gates[i] owner:7343];if(get && get(_engine.threadContext,gui)){[self releaseFeature:feature];state.available=YES;state.note=@"Zeitlupe pausiert im Spielmenü.";return state;}}
        }
        void *app=[_engine singletonAt:0x108a23248];
        NSMutableArray<RE2Value *> *old=_effects[@(feature)];float baseline=1;
        if(old.count)[old[0].before getBytes:&baseline length:4];else if(!MTReadMemory((uint8_t *)app+0x248,&baseline,4))return state;
        float result=baseline*factor;
        if(isfinite(result))applied=[self applyBytes:[NSData dataWithBytes:&result length:4] object:app offset:0x248 owner:nil global:YES feature:feature];
    }
    if(!applied)[self releaseFeature:feature];
    state.available=applied;state.active=applied;state.note=applied ? @"Im Spiel angewandt und zurückgelesen." : feature==RE2FeatureHighlight ? @"Wartet auf native Objektmarkierungen außerhalb von Menüs." : feature==RE2FeatureCountdown ? @"Wartet auf einen laufenden Countdown." : feature==RE2FeatureRibbons ? @"Wartet auf Farbbänder im lokalen Inventar." : feature==RE2FeatureKnife ? @"Wartet auf ein intaktes Messer im lokalen Inventar." : feature==RE2FeatureBoards ? @"Wartet auf bestätigte Holzbretter im lokalen Inventar." : feature==RE2FeatureTyrant ? @"Wartet auf den patrouillierenden Tyrant." : feature==RE2FeatureOneHit ? @"Wartet auf lebende Gegner." : @"Für den aktuellen Besitzer noch nicht verfügbar.";return state;
}
- (NSString *)performOneShot:(RE2Feature)feature value:(double)value {
    (void)value;if(!_engine.isGameThread || !_playerOwner.valid)return @"Kein bestätigter lokaler Spielkontext.";
    void *ctx=_engine.threadContext;
    if(feature==RE2FeaturePortableSafe){
        _portableProbe=[@{@"capturedAt":@(NSDate.date.timeIntervalSince1970),@"source":@"explicit mini-safe action"} mutableCopy];
        void *safe=[self openedPortableSafe];RE2Owner *owner=safe ? [RE2Owner ownerForComponent:safe engine:_engine] : nil;
        BOOL solved=safe && [self solvePortableSafe:safe owner:owner];_portableProbe[@"solved"]=@(solved);
        return solved ? @"Mini-Tresor gelöst; das Spiel führt den normalen Abschluss aus." : @"Kein bereitstehender Mini-Tresor bestätigt. Öffne das Rätsel mit den acht Tasten und versuche es erneut.";
    }
    if(feature==RE2FeatureGameTime){
        void *clock=[_engine singletonAt:0x10b155fb8];
        uint64_t (*get)(void *,void *)=[_engine method:416994 owner:7103];
        void (*set)(void *,void *,uint64_t)=[_engine method:417008 owner:7103];
        if([_engine typeOf:clock]!=7103 || !pointer(clock,0x58) || !get || !set)return @"Spieluhr nicht bestätigt.";
        uint64_t before=get(ctx,clock);void *data=(void *)pointer(clock,0x58);
        uint64_t original[]={pointer(data,0x18),pointer(data,0x20),pointer(data,0x28),pointer(data,0x30)};
        void (*setters[4])(void *,void *,uint64_t)={set,[_engine method:417010 owner:7103],[_engine method:417012 owner:7103],[_engine method:417014 owner:7103]};
        for(NSUInteger i=0;i<4;i++)if(!setters[i])return @"Spieluhr-Setter unvollständig.";
        for(NSUInteger i=0;i<4;i++)setters[i](ctx,clock,0);
        uint64_t after=get(ctx,clock);
        if(after)for(NSUInteger i=0;i<4;i++)setters[i](ctx,clock,original[i]);
        os_log(_log,"One-shot time before=%{public}llu after=%{public}llu",(unsigned long long)before,(unsigned long long)after);
        return after==0 ? @"Spielzeit auf 0 gesetzt und zurückgelesen." : @"Spielzeitänderung nicht bestätigt.";
    }
    if(feature==RE2FeatureBackpack){
        int32_t (*current)(void *,void *)=[_engine method:RE2Method_Inventory_get_InventoryItemSlotCurrentSize owner:RE2Type_Inventory];
        int32_t (*maximum)(void *,void *)=[_engine method:RE2Method_Inventory_get_InventoryItemSlotMaxSize owner:RE2Type_Inventory];
        void (*set)(void *,void *,int32_t)=[_engine method:RE2Method_Inventory_set_InventoryItemSlotCurrentSize owner:RE2Type_Inventory];
        void *local=[self objectGetter:RE2Method_Condition_get_Inventory owner:RE2Type_Condition object:_condition];
        if([_engine typeOf:_inventory]!=RE2Type_Inventory || !local || (uintptr_t)local!=pointer(_inventory,0x50) || !current || !maximum || !set)return @"Lokales Inventar nicht bestätigt.";
        int32_t before=current(ctx,_inventory),limit=maximum(ctx,_inventory);
        if(before<8 || before>20 || limit!=20)return @"Inventargrenzen weichen ab.";
        set(ctx,_inventory,limit);int32_t after=current(ctx,_inventory);
        os_log(_log,"One-shot feature=%{public}ld before=%{public}d after=%{public}d readback=%{public}d",(long)feature,before,after,after==limit);
        return after==limit ? @"Rucksack auf 20 Plätze erweitert und zurückgelesen." : @"Rucksackänderung nicht bestätigt.";
    }
    void *object=NULL;size_t offset=0;
    if([_engine typeOf:_record]!=RE2Type_Record)return @"Statistikbesitzer fehlt.";
    if(feature==RE2FeatureSaveCount)return [self resetCurrentSaveCount:_record] ? @"Anzahl Speicherungen nativ auf 0 zurückgesetzt. Bereits gespeicherte Slots behalten ihre bisherigen Angaben." : @"Zurücksetzen des tatsächlichen Speicherzählers nicht bestätigt.";
    if(feature==RE2FeatureSteps){
        int32_t (*get)(void *,void *)=[_engine method:RE2Method_Record_get_NumberOfSteps owner:RE2Type_Record];
        void (*set)(void *,void *,int32_t)=[_engine method:RE2Method_Record_set_NumberOfSteps owner:RE2Type_Record];
        if(!get || !set)return @"Schrittezähler nicht gebunden.";
        int32_t before=get(ctx,_record);if(before<0 || before>1000000000)return @"Schrittezähler außerhalb des gültigen Bereichs.";
        set(ctx,_record,0);int32_t after=get(ctx,_record);
        os_log(_log,"One-shot feature=%{public}ld before=%{public}d after=%{public}d readback=%{public}d",(long)feature,before,after,after==0);
        return after==0 ? @"Schritte auf 0 gesetzt und zurückgelesen." : @"Schrittänderung nicht bestätigt.";
    }
    if(feature==RE2FeatureItemBoxCount){object=(void *)pointer(_record,0x60);offset=0x28;}
    else if(feature==RE2FeatureHealingCount){object=(void *)pointer(_record,0x60);offset=0x20;}
    if(object){uint32_t before=integer(object,offset);BOOL confirmed=MTWriteInt(object,offset,0) && integer(object,offset)==0;os_log(_log,"One-shot feature=%{public}ld before=%{public}u after=%{public}u readback=%{public}d",(long)feature,before,integer(object,offset),confirmed);if(confirmed)return @"Wert auf 0 gesetzt und zurückgelesen.";}
    return @"Die native Schreibanbindung ist noch nicht bestätigt.";
}
- (NSDictionary *)diagnostics {
    NSMutableDictionary *d=[@{@"nativeGameThread":@(_engine.isGameThread),@"pendingSpeedRestore":@(_speedOutstanding)} mutableCopy];
    if(_portableProbe)d[@"portableSafe"]=[_portableProbe copy];
    if(_engine.isGameThread && _playerOwner.valid && _speedOwner.valid && [self objectGetter:191902 owner:31594 object:_speedOwner.component]==_condition){
        float (*play)(void *,void *)=[_engine method:191873 owner:23201];float (*motion)(void *,void *)=[_engine method:191875 owner:23201];
        if(play && motion && _engine.threadContext){float p=play(_engine.threadContext,_speedOwner.component),m=motion(_engine.threadContext,_speedOwner.component);if(isfinite(p) && isfinite(m))d[@"localSpeed"]=@{@"input":@(p),@"effective":@(m),@"intervalApplications":@(_speedTelemetryCalls),@"intervalRestores":@(_speedTelemetryRestores)};}
    }
    return d;
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {
    if(!_engine.isGameThread)return NO;
    // The exact-build HID singleton belongs to the process, not a player.
    // UI input must also work in title/pause menus and while no player exists.
    void *device=[_engine singletonAt:0x108a48770];
    const size_t offsets[]={0x168,0x169,0x16b};const uint8_t values[]={1,0,1};
    if(_mouseOwned && (device!=_mouseDevice || !wanted)){
        BOOL restored=YES;
        if(device==_mouseDevice)for(NSUInteger i=0;i<3;i++){uint8_t current=0;if(MTReadMemory((uint8_t *)device+offsets[i],&current,1) && current==values[i]){restored&=MTWriteByte(device,offsets[i],_mouseBefore[i]) && MTReadMemory((uint8_t *)device+offsets[i],&current,1) && current==_mouseBefore[i];}}
        _mouseOwned=NO;os_log(_log,"Native mouse ownership released readback=%{public}d",restored);
    }
    if(!wanted || !device)return NO;
    uint8_t observed[3];
    for(NSUInteger i=0;i<3;i++)if(!MTReadMemory((uint8_t *)device+offsets[i],&observed[i],1) || observed[i]>1)return NO;
    BOOL first=!_mouseOwned;
    if(first){memcpy(_mouseBefore,observed,sizeof(observed));_mouseDevice=device;_mouseOwned=YES;}
    // Menus and controller input can change their request during our lease.
    // Preserve those newer values for release before renewing our UI request.
    else for(NSUInteger i=0;i<3;i++)if(observed[i]!=values[i])_mouseBefore[i]=observed[i];
    BOOL confirmed=YES;
    for(NSUInteger i=0;i<3;i++){uint8_t current=0;confirmed&=MTWriteByte(device,offsets[i],values[i]) && MTReadMemory((uint8_t *)device+offsets[i],&current,1) && current==values[i];}
    if(first)os_log(_log,"Native mouse ownership acquired readback=%{public}d",confirmed);
    return confirmed;
}
@end
