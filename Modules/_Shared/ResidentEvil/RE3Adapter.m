// SPDX-License-Identifier: GPL-3.0-only
#import "RE3Adapter.h"
#import "RE2EffectLedger.h"
#import "RE2Engine.h"
#import "MemoryAccess.h"
#import <os/log.h>
#include <math.h>
static uintptr_t p3(void *p,size_t off){uintptr_t v=0;MTReadMemory((uint8_t *)p+off,&v,8);return v;}
static uint32_t n3(void *p,size_t off){uint32_t v=0;MTReadMemory((uint8_t *)p+off,&v,4);return v;}
static NSData *b3(const void *p,size_t n){return [NSData dataWithBytes:p length:n];}
@implementation RE3NativeAdapter {
    MTRE2Engine *_e;
    RE2Owner *_player,*_motionOwner;
    void *_condition,*_hp,*_equipment,*_weapon,*_inventory,*_localInventory,*_record;
    NSMutableDictionary<NSNumber *,NSNumber *> *_selected;
    NSMutableDictionary<NSValue *,RE2Owner *> *_icons;
    BOOL _installed,_mouseOwned;
    void *_mouseDevice;
    uint8_t _mouseBefore[3];
    NSString *_identity,*_enemyStage;
    NSMutableDictionary<NSNumber *,NSString *> *_enemyCounts;
    BOOL _enemyMethodsLogged;
    BOOL _preflightLogged;
    NSUInteger _iconCount;
    os_log_t _log3;
}
- (instancetype)init {if((self=[super init])){_e=MTRE2Engine.shared;_selected=[NSMutableDictionary new];_icons=[NSMutableDictionary new];_enemyCounts=[NSMutableDictionary new];_log3=os_log_create("local.mactrainer.re2","re3-effects");}return self;}
- (BOOL)loading {
    BOOL (*get)(void *)=[_e method:404551 owner:20787];
    if(!_e.isGameThread || !get || get(_e.threadContext))return YES;
    void *gui=[_e singletonAt:0x10b88a598];BOOL (*screen)(void *,void *)=[_e method:99306 owner:45474];
    // Scene deserialization can finish before the loading screen releases input.
    return [_e typeOf:gui]!=45474 || !screen || screen(_e.threadContext,gui);
}
- (BOOL)localValid {
    return _e.isGameThread && ![self loading] && _player.valid && [self objectGetter:471109 owner:26965 object:[_e singletonAt:0x10b88e5e0]]==_condition;
}
- (BOOL)menu {
    void *gui=[_e singletonAt:0x10b88a598];if([_e typeOf:gui]!=45474)return YES;
    const uint32_t ids[]={98923,98925,98927,98929};
    for(NSUInteger i=0;i<4;i++){BOOL (*get)(void *,void *)=[_e method:ids[i] owner:45474];if(!get || get(_e.threadContext,gui))return YES;}return NO;
}
- (RE2GameContext *)captureContext {
    RE2GameContext *state=[RE2GameContext new];
    if(!_e.isRE3 || !_e.isGameThread){state.note=_e.failure;return state;}
    if(!_installed){__weak RE3NativeAdapter *w=self;[_e setContinuousWork:^{[w continuousFrame];}];_installed=YES;}
    if([self loading]){_player=nil;state.kind=RE2SessionLoading;state.identity=@"re3/loading";state.note=@"RE3 lädt; eigene Effekte werden gelöst.";return state;}
    void *condition=[self objectGetter:471109 owner:26965 object:[_e singletonAt:0x10b88e5e0]];
    RE2Owner *owner=[_e isObject:condition kindOf:29283] ? [RE2Owner ownerForComponent:condition engine:_e] : nil;
    if(!owner.valid){_player=nil;state.kind=RE2SessionLoading;state.identity=@"re3/loading";state.note=@"Wartet auf Jill oder Carlos.";return state;}
    _condition=condition;_hp=[self objectGetter:162117 owner:29283 object:condition];
    _equipment=[self objectGetter:162041 owner:29283 object:condition];
    _weapon=[self objectGetter:154568 owner:22238 object:_equipment];
    if([_e typeOf:_equipment]!=22238 || [self objectGetter:154664 owner:22238 object:_equipment]!=condition)_weapon=NULL;
    RE2Owner *weaponOwner=_weapon ? [RE2Owner ownerForComponent:_weapon engine:_e] : nil;
    if(!weaponOwner.valid)_weapon=NULL;
    _inventory=[_e singletonAt:0x10b89f8c8];_record=[_e singletonAt:0x10b8c7790];
    _localInventory=[self objectGetter:162039 owner:29283 object:condition];
    if([_e typeOf:_inventory]!=15586 || [_e typeOf:_localInventory]!=26346 || [self objectGetter:152777 owner:15586 object:_inventory]!=_localInventory || [self objectGetter:151615 owner:26346 object:_localInventory]!=condition)_localInventory=NULL;
    _player=owner;state.kind=RE2SessionSolo;
    if(!_preflightLogged && [_e typeOf:_record]==17433){
        void *list=(void *)p3(_record,0xd0),*items=(void *)p3(list,0x10),*system=(void *)p3(_record,0x70),*flags=(void *)p3(system,0x48);
        os_log(_log3,"RE3 read-only record preflight listType=%{public}u arrayType=%{public}u count=%{public}u capacity=%{public}u systemType=%{public}u flagCount=%{public}u",[_e typeOf:list],[_e typeOf:items],n3(list,0x18),n3(items,0x1c),[_e typeOf:system],n3(flags,0x1c));_preflightLogged=YES;
    }
    state.identity=[NSString stringWithFormat:@"re3/%@/%@/%p",owner.identity,weaponOwner.identity ?: @"no-weapon",_localInventory];
    state.note=@"RE3 · lokale Kampagne und GameThread bestätigt.";
    if(![_identity isEqual:state.identity]){_identity=state.identity;os_log(_log3,"RE3 local context bound player=1 inventory=%{public}d weapon=%{public}d",_localInventory!=NULL,_weapon!=NULL);}
    return state;
}
- (void)releaseFeature:(RE2Feature)feature {
    if(feature==RE2FeatureHighlight){[_icons removeAllObjects];_iconCount=0;}
    [super releaseFeature:feature];
}
- (void)releaseEffects {[_selected removeAllObjects];[_icons removeAllObjects];_iconCount=0;[super releaseEffects];}
- (void)continuousFrame {
    if(_mouseOwned)[self setOverlayInteraction:YES];
    if(!_selected.count)return;
    if(![self localValid] || [self objectGetter:154568 owner:22238 object:_equipment]!=_weapon){[self releaseEffects];return;}
    for(NSNumber *key in _selected.allKeys.copy)[self applyFeature:key.integerValue wanted:YES value:_selected[key].doubleValue];
}
- (void *)motion {
    if(_motionOwner.valid && [self objectGetter:219765 owner:33399 object:_motionOwner.component]==_condition)return _motionOwner.component;
    [self releaseFeature:RE2FeatureSpeed];_motionOwner=nil;
    void *array=[self objectGetter:271209 owner:36843 object:_player.gameObject];uint32_t count=n3(array,0x1c);
    if([_e typeOf:array]!=22235 || count>128)return NULL;
    for(uint32_t i=0;i<count;i++){
        void *c=(void *)p3(array,0x20+i*8);
        if([_e typeOf:c]!=33399 || [self objectGetter:219765 owner:33399 object:c]!=_condition)continue;
        RE2Owner *owner=[RE2Owner ownerForComponent:c engine:_e];if(owner.valid){_motionOwner=owner;return c;}
    }return NULL;
}
- (BOOL)isGrenade:(void *)slot {
    // Native localized weapon names identify existing throwable stacks only.
    void *str=[self objectGetter:150843 owner:46209 object:slot];uint32_t len=n3(str,0x10);unichar chars[96];
    if([_e typeOf:str]!=45875 || !len || len>96 || !MTReadMemory((uint8_t *)str+0x14,chars,len*2))return NO;
    NSString *name=[[[NSString alloc]initWithCharacters:chars length:len] lowercaseString];
    return [@[@"handgranate",@"blendgranate",@"hand grenade",@"flash grenade",@"flashbang"] containsObject:name];
}
- (BOOL)ammo:(RE2Feature)feature {
    if(!_localInventory)return NO;
    void *(*slotAt)(void *,void *,int32_t)=[_e method:152874 owner:15586];
    int32_t (*bullet)(void *,void *)=[_e method:152905 owner:15586];
    int32_t (*max)(void *,void *)=[_e method:150817 owner:46209];
    int32_t (*size)(void *,void *)=[_e method:152781 owner:15586];
    if(!slotAt || !max || !bullet || !size)return NO;
    int32_t count=size(_e.threadContext,_inventory),ammo=bullet(_e.threadContext,_inventory);if(count<1 || count>20)return NO;
    RE2Owner *owner=[RE2Owner ownerForComponent:_localInventory engine:_e];if(!owner.valid)return NO;
    BOOL okay=YES;NSUInteger targets=0;
    for(int32_t i=0;i<count;i++){
        BOOL main=feature==RE2FeatureNoReload;
        void *slot=main ? (void *)p3(_localInventory,0x90) : slotAt(_e.threadContext,_inventory,i);
        if([_e typeOf:slot]!=46209){if(main)break;continue;}
        void *stock=(void *)p3(slot,0x10),*item=(void *)p3(stock,0x10);
        if([_e typeOf:stock]!=22148 || [_e typeOf:item]!=39506){if(main)break;continue;}
        BOOL grenade=[self isGrenade:slot];
        // Throwables belong to F2; F3 must not hide consumption in an F2-off test.
        if(main && grenade)break;
        if(!main && !((ammo>0 && n3(item,0x10)==(uint32_t)ammo) || grenade))continue;
        int32_t limit=max(_e.threadContext,slot);if(limit<1 || limit>1000){okay=NO;break;}
        if(main){uint32_t old=n3(item,0x20);NSData *base=[self baselineForObject:item offset:0x20 feature:feature];if(base)[base getBytes:&old length:4];if(old>1000)break;limit=MAX(MAX(limit,2),(int32_t)old);}
        [owner retainPayload:slot];[owner retainPayload:stock];
        MTRE2Engine *engine=_e;void *inv=_localInventory,*manager=_inventory,*condition=_condition;int32_t index=i;
        void *(*currentInventory)(void *,void *)=[_e method:152777 owner:15586];
        void *(*localCondition)(void *,void *)=[_e method:151615 owner:26346];
        if(!currentInventory || !localCondition)return NO;
        // Resolve through the same indexed API used to select the slot. The
        // overloaded local getSlot is not an equivalent inventory-index lookup.
        // A moved slot still belongs to this inventory and can restore its flag.
        BOOL (^slotGuard)(void)=^BOOL{
            if(!owner.valid || localCondition(engine.threadContext,inv)!=condition || currentInventory(engine.threadContext,manager)!=inv)return NO;
            if(main)return p3(inv,0x90)==(uintptr_t)slot;
            int32_t liveSize=size(engine.threadContext,manager);if(liveSize<1 || liveSize>20)return NO;
            if(index<liveSize && slotAt(engine.threadContext,manager,index)==slot)return YES;
            for(int32_t j=0;j<liveSize;j++)if(j!=index && slotAt(engine.threadContext,manager,j)==slot)return YES;
            return NO;
        };
        BOOL (^guard)(void)=^BOOL{return slotGuard() && p3((void *)p3(slot,0x10),0x10)==(uintptr_t)item;};
        okay&=[self applyBytes:b3(&limit,4) object:item offset:0x20 owner:owner global:NO feature:feature guard:guard];
        if(!main && grenade){uint8_t yes=1;okay&=[self applyBytes:b3(&yes,1) object:slot offset:0x1d owner:owner global:NO feature:feature guard:slotGuard];}
        targets++;
        if(main)break;
    }return okay && targets>0;
}
- (BOOL)enemies:(RE2Feature)feature {
    void *manager=[_e singletonAt:0x10b88d3b0];
    void *list=[self objectGetter:103076 owner:36906 object:manager],*items=(void *)p3(list,0x10);uint32_t count=n3(list,0x18);
    NSString *stage=[NSString stringWithFormat:@"manager=%u list=%u array=%u count=%u capacity=%u",[_e typeOf:manager],[_e typeOf:list],[_e typeOf:items],count,n3(items,0x1c)];
    if(![_enemyStage isEqual:stage]){_enemyStage=stage;os_log(_log3,"RE3 enemy binding %{public}s",stage.UTF8String);}
    if([_e typeOf:manager]!=36906 || [_e typeOf:list]!=8876 || [_e typeOf:items]!=29075 || count>512 || count>n3(items,0x1c))return NO;
    if(!_enemyMethodsLogged){
        const uint32_t ids[]={44877,103351,143454,143466,173825};const uint32_t owners[]={35455,31302,40858,40858,5100};
        for(NSUInteger i=0;i<5;i++){void *fn=[_e method:ids[i] owner:owners[i]];os_log(_log3,"RE3 target method index=%{public}u owner=%{public}u address=%{public}llx",ids[i],owners[i],fn ? (unsigned long long)((uintptr_t)fn-_e.slide) : 0);}
        _enemyMethodsLogged=YES;
    }
    NSUInteger targets=0,registrations=0,controllers=0,hitpoints=0,alive=0,validOwners=0,nemesis=0;
    uint32_t sampleRegistration=UINT32_MAX,sampleController=UINT32_MAX,sampleHP=UINT32_MAX;
    BOOL okay=YES;uint32_t one=1;
    for(uint32_t i=0;i<count;i++){
        void *registration=(void *)p3(items,0x20+i*8);
        if(i==0)sampleRegistration=[_e typeOf:registration];
        if([_e typeOf:registration]!=35455)continue;registrations++;
        // Exact RE3 getter validates the live native context before returning its controller.
        void *enemy=[self objectGetter:44877 owner:35455 object:registration];
        if(enemy && sampleController==UINT32_MAX)sampleController=[_e typeOf:enemy];
        if(![_e isObject:enemy kindOf:40858])continue;controllers++;
        if(feature==RE2FeatureTyrant){
            void *think=[self objectGetter:143466 owner:40858 object:enemy];if([_e typeOf:think]!=5100)continue;nemesis++;
            float sleep=0;if(!MTReadMemory((uint8_t *)think+0x49c,&sleep,4) || !isfinite(sleep) || sleep<0 || sleep>36000)continue;
            if(sleep>0){RE2Owner *owner=[RE2Owner ownerForComponent:think engine:_e];if(!owner.valid)continue;NSData *base=[self baselineForObject:think offset:0x49c feature:feature];if(base)[base getBytes:&sleep length:4];okay&=[self applyBytes:b3(&sleep,4) object:think offset:0x49c owner:owner global:NO feature:feature];targets++;continue;}
        }
        void *hp=[self objectGetter:143454 owner:40858 object:enemy];uint32_t health=n3(hp,0x54);
        if(hp && sampleHP==UINT32_MAX)sampleHP=[_e typeOf:hp];
        if(![_e isObject:hp kindOf:15590])continue;hitpoints++;
        if(!health || health>10000000)continue;alive++;
        RE2Owner *owner=[RE2Owner ownerForComponent:hp engine:_e];if(!owner.valid)continue;validOwners++;
        okay&=[self applyBytes:b3(&one,4) object:hp offset:0x54 owner:owner global:NO feature:feature];targets++;
    }
    NSString *counts=[NSString stringWithFormat:@"feature=%ld registrations=%lu controllers=%lu hp=%lu alive=%lu validOwners=%lu nemesis=%lu targets=%lu sampleTypes=%u/%u/%u",(long)feature,(unsigned long)registrations,(unsigned long)controllers,(unsigned long)hitpoints,(unsigned long)alive,(unsigned long)validOwners,(unsigned long)nemesis,(unsigned long)targets,sampleRegistration,sampleController,sampleHP];
    if(![_enemyCounts[@(feature)] isEqual:counts]){_enemyCounts[@(feature)]=counts;os_log(_log3,"RE3 target counters %{public}s",counts.UTF8String);}
    return okay && targets>0;
}
- (BOOL)highlights {
    if([self menu])return NO;
    void *ctx=_e.threadContext,*gui=[_e singletonAt:0x10b88a598],*manager=[_e singletonAt:0x10b88fe40];
    void *registry=(void *)p3(manager,0x78),*list=(void *)p3(registry,0x18),*items=(void *)p3(list,0x10);uint32_t count=n3(list,0x18);
    BOOL (*enabled)(void *,void *)=[_e method:36789 owner:41125];void (*draw)(void *,void *)=[_e method:35946 owner:27888];
    if([_e typeOf:manager]!=7785 || [_e typeOf:registry]!=20014 || [_e typeOf:list]!=98273 || [_e typeOf:items]!=9267 || count>2048 || count>n3(items,0x1c) || !enabled || !draw)return NO;
    NSMutableSet *live=[NSMutableSet new],*drawn=[NSMutableSet new];NSUInteger requested=0,confirmed=0;
    for(uint32_t i=0;i<count && requested<32;i++){
        void *work=(void *)p3(items,0x20+i*8),*trigger=(void *)p3(work,0x10);
        if([_e typeOf:work]!=3671 || ![_e isObject:trigger kindOf:27888] || !enabled(ctx,trigger))continue;
        void *go=[self objectGetter:36792 owner:41125 object:trigger],*iconGO=[self objectGetter:35703 owner:44166 object:trigger];
        if([_e typeOf:go]!=36843 || [_e typeOf:iconGO]!=36843 || !p3(iconGO,0x18))continue;
        NSValue *key=[NSValue valueWithPointer:trigger],*iconKey=[NSValue valueWithPointer:iconGO];if([drawn containsObject:iconKey])continue;
        RE2Owner *owner=_icons[key];if(!owner.valid || owner.gameObject!=go){owner=[RE2Owner ownerForGameObject:go engine:_e];if(!owner.valid)continue;[owner retainPayload:trigger];_icons[key]=owner;}
        [live addObject:key];[drawn addObject:iconKey];draw(ctx,trigger);requested++;
        void *dict=(void *)p3(gui,0x1a0),*entries=(void *)p3(dict,0x18);uint32_t n=n3(dict,0x3c);
        if([_e typeOf:dict]!=21405 || [_e typeOf:entries]!=16010 || n>256 || n>n3(entries,0x1c))continue;
        for(uint32_t j=0;j<n;j++){uint8_t *entry=(uint8_t *)entries+0x20+j*24;void *icon=(void *)p3(entry,0x10);uint8_t request=0;
            if(p3(entry,8)==(uintptr_t)iconGO && [_e typeOf:icon]==15656 && MTReadMemory((uint8_t *)icon+0xfe,&request,1) && request==1){confirmed++;break;}}
    }
    for(NSValue *key in _icons.allKeys.copy)if(![live containsObject:key])[_icons removeObjectForKey:key];
    if(_iconCount!=confirmed){_iconCount=confirmed;os_log(_log3,"RE3 highlights registered=%{public}u requested=%{public}lu confirmed=%{public}lu",count,(unsigned long)requested,(unsigned long)confirmed);}
    return confirmed>0;
}
- (RE2FeatureState *)applyFeature:(RE2Feature)feature wanted:(BOOL)wanted value:(double)value {
    RE2FeatureState *s=[RE2FeatureState new];s.note=@"Wartet auf einen passenden lokalen Besitzer.";
    if(!wanted){[_selected removeObjectForKey:@(feature)];[self releaseFeature:feature];s.available=YES;s.note=@"Aus.";return s;}
    if(![self localValid])return s;
    _selected[@(feature)]=@(value);BOOL okay=NO;
    if((feature==RE2FeatureHealth || feature==RE2FeatureRibbons) && [_e typeOf:_hp]==15590){
        RE2Owner *owner=[RE2Owner ownerForComponent:_hp engine:_e];
        if(feature==RE2FeatureRibbons){uint8_t yes=1;okay=[self applyBytes:b3(&yes,1) object:_hp offset:0x51 owner:owner global:NO feature:feature];}
        else{uint32_t hp=n3(_hp,0x54),max=n3(_hp,0x58);if(hp>0 && max>=hp && max<=100000)okay=[self applyBytes:b3(&max,4) object:_hp offset:0x54 owner:owner global:NO feature:feature];}
    }else if(feature==RE2FeatureAmmo || feature==RE2FeatureNoReload)okay=[self ammo:feature];
    else if(feature==RE2FeatureAccuracy || feature==RE2FeatureRecoil){
        RE2Owner *owner=_weapon ? [RE2Owner ownerForComponent:_weapon engine:_e] : nil;
        void *param=[self objectGetter:feature==RE2FeatureAccuracy ? 164366 : 164362 owner:33283 object:[_e isObject:_weapon kindOf:33283] ? _weapon : NULL];
        if(owner.valid && [_e typeOf:param]==(feature==RE2FeatureAccuracy ? 2360 : 24366)){
            okay=YES;const size_t focus[]={0x10,0x18,0x1c,0x20};
            for(NSUInteger i=0;i<4;i++){float n=feature==RE2FeatureAccuracy && i==0 ? 10000 : 0;okay&=[self applyBytes:b3(&n,4) object:param offset:feature==RE2FeatureAccuracy ? focus[i] : 0x10+i*4 owner:owner global:NO feature:feature];}
        }
    }else if(feature==RE2FeatureSlowMotion && isfinite(value) && value>=0.1 && value<=1){
        if([self menu]){[self releaseFeature:feature];s.available=YES;s.note=@"Zeitlupe pausiert im Spielmenü.";return s;}
        void *app=[_e singletonAt:0x1092f33c8];float baseline=1;NSData *old=[self baselineForObject:app offset:0x248 feature:feature];
        if(old)[old getBytes:&baseline length:4];else if(!MTReadMemory((uint8_t *)app+0x248,&baseline,4))return s;
        float result=baseline*value;if(isfinite(result) && result>0 && result<=10)okay=[self applyBytes:b3(&result,4) object:app offset:0x248 owner:nil global:YES feature:feature];
    }else if(feature==RE2FeatureSpeed && isfinite(value) && value>=1 && value<=3){
        void *motion=[self motion];float baseline=1;NSData *old=[self baselineForObject:motion offset:0x54 feature:feature];
        if(old)[old getBytes:&baseline length:4];else if(!motion || !MTReadMemory((uint8_t *)motion+0x54,&baseline,4))return s;
        float result=baseline*value;if(isfinite(baseline) && baseline>0 && baseline<=10)okay=[self applyBytes:b3(&result,4) object:motion offset:0x54 owner:_motionOwner global:NO feature:feature];
    }else if(feature==RE2FeatureOneHit || feature==RE2FeatureTyrant)okay=[self enemies:feature];
    else if(feature==RE2FeatureHighlight)okay=[self highlights];
    if(!okay)[self releaseFeature:feature];s.available=okay;s.active=okay;
    s.note=okay ? @"In RE3 angewandt und nativ zurückgelesen." : feature==RE2FeatureTyrant ? @"Wartet auf humanoiden Nemesis im Verfolgungsmodus." : feature==RE2FeatureHighlight ? @"Wartet auf geladene Objektmarkierungen außerhalb von Menüs." : feature==RE2FeatureOneHit ? @"Wartet auf lebende Gegner." : @"Wartet auf passende lokale Ausrüstung.";return s;
}
- (NSString *)performOneShot:(RE2Feature)feature value:(double)value {
    if(![self localValid])return @"Kein bestätigter lokaler RE3-Spielkontext.";
    void *ctx=_e.threadContext;
    if(feature==RE2FeatureBackpack){
        int32_t (*get)(void *,void *)=[_e method:152781 owner:15586],(*max)(void *,void *)=[_e method:152783 owner:15586];void (*set)(void *,void *,int32_t)=[_e method:152782 owner:15586];
        if(!_localInventory || !get || !max || !set)return @"Lokales Inventar fehlt.";int32_t before=get(ctx,_inventory),limit=max(ctx,_inventory);
        if(before<8 || before>20 || limit!=20)return @"Abweichende Inventargrenzen.";set(ctx,_inventory,limit);BOOL ok=get(ctx,_inventory)==limit;
        os_log(_log3,"RE3 backpack before=%{public}d after=%{public}d confirmed=%{public}d",before,get(ctx,_inventory),ok);return ok ? @"Rucksack auf 20 Plätze erweitert und bestätigt." : @"Rucksackänderung nicht bestätigt.";
    }
    if(feature==RE2FeatureGameTime || feature==RE2FeatureKnife){
        void *clock=[_e singletonAt:0x10b895f60];BOOL total=feature==RE2FeatureKnife;
        uint64_t (*get)(void *,void *)=[_e method:total ? 465313 : 465314 owner:9830];
        const uint32_t setters[]={465334,465336,465338,465340};void (*set[4])(void *,void *,uint64_t)={0};
        if([_e typeOf:clock]!=9830 || !get || !p3(clock,total ? 0x50 : 0x58))return @"RE3-Spieluhr fehlt.";
        for(NSUInteger i=0;i<(total ? 1u : 4u);i++){set[i]=[_e method:total ? 465332 : setters[i] owner:9830];if(!set[i])return @"Zeit-Setter unvollständig.";}
        uint64_t before=get(ctx,clock);for(NSUInteger i=0;i<(total ? 1u : 4u);i++)set[i](ctx,clock,0);uint64_t after=get(ctx,clock);
        os_log(_log3,"RE3 time total=%{public}d before=%{public}llu after=%{public}llu",total,(unsigned long long)before,(unsigned long long)after);
        return after==0 ? (total ? @"Gesamtspielzeit auf 0 gesetzt und bestätigt." : @"Spielzeit auf 0 gesetzt und bestätigt.") : @"Zeitänderung nicht bestätigt.";
    }
    if([_e typeOf:_record]!=17433)return @"RE3-Statistikbesitzer fehlt.";
    if(feature==RE2FeatureSteps){
        void *list=(void *)p3(_record,0xd0),*items=(void *)p3(list,0x10);uint32_t count=n3(list,0x18);
        void (*clear)(void *,void *,int32_t)=[_e method:80060 owner:17433];BOOL (*get)(void *,void *,int32_t)=[_e method:80067 owner:17433];
        if([_e typeOf:list]!=98305 || [_e typeOf:items]!=39034 || !count || count>1024 || count>n3(items,0x1c) || !clear || !get)return @"Native RE3-Record-Liste nicht bestätigt.";
        // Snapshot actual native IDs before calling game methods; never invent enum IDs.
        int32_t ids[1024];if(!MTReadMemory((uint8_t *)items+0x20,ids,count*4))return @"Record-IDs nicht lesbar.";
        void *system=(void *)p3(_record,0x70),*flags=(void *)p3(system,0x48);uint32_t limit=n3(flags,0x1c);
        if([_e typeOf:system]!=14727 || !limit || limit>4096)return @"Record-Grenzen nicht bestätigt.";
        for(uint32_t i=0;i<count;i++)if(ids[i]<0 || (uint32_t)ids[i]>=limit)return @"Ungültige Record-ID; keine Änderungen.";
        NSUInteger done=0;for(uint32_t i=0;i<count;i++){if(!get(ctx,_record,ids[i]))clear(ctx,_record,ids[i]);if(get(ctx,_record,ids[i]))done++;}
        os_log(_log3,"RE3 records requested=%{public}u confirmed=%{public}lu",count,(unsigned long)done);
        return [NSString stringWithFormat:@"Records: %lu von %u nativ bestätigt.",(unsigned long)done,count];
    }
    if(feature==RE2FeatureBoards){
        if(!isfinite(value) || value<0 || value>9999999 || floor(value)!=value)return @"Shop-Punkte müssen ganzzahlig zwischen 0 und 9999999 liegen.";
        int32_t (*get)(void *,void *)=[_e method:80015 owner:17433];void (*set)(void *,void *,int32_t)=[_e method:80016 owner:17433];
        if([_e typeOf:(void *)p3(_record,0x70)]!=14727 || !get || !set)return @"Shop-Daten fehlen.";
        int32_t before=get(ctx,_record);set(ctx,_record,(int32_t)value);int32_t after=get(ctx,_record);
        os_log(_log3,"RE3 shop before=%{public}d after=%{public}d",before,after);return after==(int32_t)value ? @"Shop-Punkte gesetzt und nativ bestätigt." : @"Punkteänderung nicht bestätigt.";
    }
    uint32_t getter=feature==RE2FeatureSaveCount ? 79991 : feature==RE2FeatureCountdown ? 79995 : feature==RE2FeatureItemBoxCount ? 80010 : feature==RE2FeatureHealingCount ? 80011 : 0;
    if(!getter)return @"Keine solche RE3-Einmalaktion.";
    int32_t (*get)(void *,void *)=[_e method:getter owner:17433];if(!get)return @"Statistik-Getter fehlt.";
    int32_t before=get(ctx,_record);if(before<0 || before>1000000000)return @"Statistikgrenzen weichen ab.";
    BOOL written=NO;
    if(feature==RE2FeatureSaveCount || feature==RE2FeatureCountdown){void (*set)(void *,void *,int32_t)=[_e method:getter+1 owner:17433];if(set){set(ctx,_record,0);written=YES;}}
    else{void *data=(void *)p3(_record,0x78);if([_e typeOf:data]==22710)written=MTWriteInt(data,feature==RE2FeatureItemBoxCount ? 0x28 : 0x20,0);}
    int32_t after=get(ctx,_record);os_log(_log3,"RE3 counter feature=%{public}ld before=%{public}d after=%{public}d confirmed=%{public}d",(long)feature,before,after,written && after==0);
    return written && after==0 ? @"Zähler auf 0 gesetzt und nativ bestätigt." : @"Zähleränderung nicht bestätigt.";
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {
    if(!_e.isGameThread)return NO;
    // UI input is owned by the process HID device, even in menus without Jill/Carlos.
    void *device=[_e singletonAt:0x1092f3a30];const size_t offsets[]={0x168,0x169,0x16b};const uint8_t values[]={1,0,1};
    if(_mouseOwned && (device!=_mouseDevice || !wanted)){
        BOOL ok=YES;if(device==_mouseDevice)for(NSUInteger i=0;i<3;i++){uint8_t v=0;if(MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==values[i])ok&=MTWriteByte(device,offsets[i],_mouseBefore[i]) && MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==_mouseBefore[i];}
        _mouseOwned=NO;os_log(_log3,"RE3 native mouse released confirmed=%{public}d",ok);
    }
    if(!wanted || !device)return NO;BOOL first=!_mouseOwned;
    uint8_t observed[3];for(NSUInteger i=0;i<3;i++)if(!MTReadMemory((uint8_t *)device+offsets[i],&observed[i],1) || observed[i]>1)return NO;
    if(first){memcpy(_mouseBefore,observed,sizeof(observed));_mouseDevice=device;_mouseOwned=YES;}
    else for(NSUInteger i=0;i<3;i++)if(observed[i]!=values[i])_mouseBefore[i]=observed[i];
    BOOL ok=YES;for(NSUInteger i=0;i<3;i++){uint8_t v=0;ok&=MTWriteByte(device,offsets[i],values[i]) && MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==values[i];}
    if(first)os_log(_log3,"RE3 native mouse acquired confirmed=%{public}d",ok);return ok;
}
@end
