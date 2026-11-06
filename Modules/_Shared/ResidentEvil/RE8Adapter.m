// SPDX-License-Identifier: GPL-3.0-only
#import "RE8Adapter.h"
#import "RE8Engine.h"
#import "RE8Ownership.h"
#import "RE8Features.h"
#import "RE2EffectLedger.h"
#import "RE8MagazinePolicy.h"
#import "RE8TimeMath.h"
#import "RE8MercenaryPolicy.h"
#import "MemoryAccess.h"
#import <os/log.h>
#include <math.h>
static uintptr_t p8a(const void *p,size_t o){uintptr_t n=0;MTReadMemory((const uint8_t *)p+o,&n,8);return n;}
static uint32_t n8a(const void *p,size_t o){uint32_t n=0;MTReadMemory((const uint8_t *)p+o,&n,4);return n;}
static NSData *b8a(const void *p,size_t n){return [NSData dataWithBytes:p length:n];}
@implementation RE8NativeAdapter {
    MTRE8Engine *_e8;RE8Owner *_owner8;
    void *_reference8,*_core8,*_status8,*_damage8,*_health8,*_inventory8;
    NSMutableDictionary<NSNumber *,NSNumber *> *_wanted8;
    NSMutableDictionary<NSNumber *,NSValue *> *_weaponBindings8;
    NSMutableSet<NSString *> *_notes8;
    NSString *_identity8;BOOL _pump8,_moneyReady8;
    int32_t _moneyBefore8;
    NSMutableDictionary<NSValue *,RE8Owner *> *_highlightOwners8;
    CFAbsoluteTime _highlightNext8;BOOL _highlightApplied8;
    CFAbsoluteTime _weaponTraceUntil8,_weaponTraceNext8;NSString *_weaponTraceLast8;NSUInteger _weaponTraceCount8;
    CFAbsoluteTime _guiPauseNext8;BOOL _guiPause8;
    CFAbsoluteTime _timeVerifyAt8,_timeVerifyStart8;float _timeVerifyExpected8;BOOL _timeVerifyRose8;
    void *_timeVerifyData8;NSString *_timeVerifyIdentity8;BOOL _roseBindingsLogged8;NSUInteger _roseRecoilCorrections8;
    BOOL _mouseOwned8;void *_mouseDevice8;uint8_t _mouseBefore8[3];
    void *_mercFlow8,*_mercStage8,*_mercTimer8,*_mercScore8,*_mercContainer8;
    uint32_t _mercHash8;int32_t _mercFloor8,_mercBefore8;BOOL _mercReady8,_mercLogged8;
    NSMutableArray<NSValue *> *_mercPending8;NSMutableSet<NSValue *> *_mercSeen8;
    NSMutableDictionary<NSString *,RE8Owner *> *_mercGoals8;
    CFAbsoluteTime _mercScanNext8,_mercTraceNext8;NSUInteger _mercVisited8,_mercTraceCount8;
    CFAbsoluteTime _mercTimeLogNext8;NSUInteger _mercCursor8;
    RE8Owner *_mercResumeOwner8;void *_mercResumeSource8;NSString *_mercResumeIdentity8;
    RE8Owner *_mercGoalVerifyOwner8;NSString *_mercGoalVerifyIdentity8;CFAbsoluteTime _mercGoalVerifyAt8;
    os_log_t _log8;
}
- (instancetype)init {if((self=[super init])){_e8=(MTRE8Engine *)MTRE2Engine.shared;_wanted8=[NSMutableDictionary new];_weaponBindings8=[NSMutableDictionary new];_notes8=[NSMutableSet new];_highlightOwners8=[NSMutableDictionary new];_log8=os_log_create("local.mactrainer.re2","re8-effects");}return self;}
- (void)note8:(NSString *)note {if(_notes8.count<64 && ![_notes8 containsObject:note]){[_notes8 addObject:note];os_log(_log8,"RE8 binding %{public}@",note);}}
- (void *)pointer8:(uint32_t)i owner:(uint32_t)o type:(uint32_t)t object:(void *)object {
    void *f=[_e8 field:i owner:o type:t object:object size:8];return f ? (void *)p8a(f,0) : NULL;
}
- (void *)localGO8 {
    // Village clears this cache after loading. Its own getter repopulates it
    // through GameObjectManager. Delivery was already armed from the exact
    // gameplay object; invoke only with that manager and a live VM context.
    void *manager=[_e8 singletonAt:0x10fd61a98];
    if(![_e8 isObject:manager kindOf:1341] || !_e8.threadContext){
        [self note8:[NSString stringWithFormat:@"localGO objectManager=%u context=%d",[_e8 typeOf:manager],_e8.threadContext!=NULL]];return NULL;
    }
    void *(*get)(void *)=[_e8 method:148655 owner:24896];
    void *ctx=_e8.threadContext,*native=get && ctx ? get(ctx) : NULL;
    void *definition=[_e8 singletonAt:0x10fd691c8],*go=(void *)p8a(definition,0x10);
    BOOL okay=_e8.threadContext && [_e8 isObject:definition kindOf:34880] && [_e8 typeOf:native]==101222 && native==go && p8a(go,0x20);
    if(!okay)[self note8:[NSString stringWithFormat:@"localGO native=%u definition=%u matches=%d contextAfter=%d",[_e8 typeOf:native],[_e8 typeOf:definition],native==go,_e8.threadContext!=NULL]];
    return okay ? go : NULL;
}
- (void *)activeInventory8 {
    void *m=[_e8 singletonAt:0x10fd53540];
    return [self pointer8:96014 owner:127576 type:102832 object:m];
}
- (void *)global8:(uint32_t)method type:(uint32_t)type {
    if(!_e8.threadContext)return NULL;void *(*get)(void *)=[_e8 method:method owner:76614];
    void *p=get ? get(_e8.threadContext) : NULL;return _e8.threadContext && [_e8 isObject:p kindOf:type] ? p : NULL;
}
- (NSArray<NSValue *> *)list8:(void *)list type:(uint32_t)type limit:(uint32_t)limit {
    if(![_e8 isObject:list kindOf:type])return @[];
    void *array=(void *)p8a(list,0x10);uint32_t count=n8a(list,0x18),capacity=n8a(array,0x1c);
    if([_e8 typeOf:array]==UINT32_MAX || count>limit || capacity>8192 || count>capacity)return @[];
    NSMutableArray *out=[NSMutableArray new];for(uint32_t i=0;i<count;i++){
        void *p=(void *)p8a(array,0x20+i*8);if([_e8 typeOf:p]!=UINT32_MAX)[out addObject:[NSValue valueWithPointer:p]];
    }return out;
}
- (void *)mercGetter8:(uint32_t)method type:(uint32_t)type {
    void *(*get)(void *)=[_e8 method:method owner:19855];
    void *p=get && _e8.threadContext ? get(_e8.threadContext) : NULL;
    return _e8.threadContext && [_e8 isObject:p kindOf:type] ? p : NULL;
}
- (BOOL)mercLinked8 {
    if(!_mercStage8 || !_e8.threadContext || [self mercGetter8:739886 type:5676]!=_mercFlow8 || [self mercGetter8:739888 type:7897]!=_mercStage8 ||
       [self mercGetter8:739916 type:47418]!=_mercTimer8 || [self mercGetter8:739906 type:118526]!=_mercScore8)return NO;
    void *mode=[_e8 field:49412 owner:5676 type:122731 object:_mercFlow8 size:1];uint8_t active=0;
    void *hash=[_e8 field:49413 owner:5676 type:12387 object:_mercFlow8 size:4],*floor=[_e8 field:49570 owner:7897 type:18821 object:_mercStage8 size:4];
    return mode && MTReadMemory(mode,&active,1) && active==1 && hash && n8a(hash,0)==_mercHash8 && floor && (int32_t)n8a(floor,0)==_mercFloor8 &&
        [self pointer8:49565 owner:7897 type:18186 object:_mercStage8]==_status8 &&
        [self pointer8:49586 owner:7897 type:5676 object:_mercStage8]==_mercFlow8 &&
        [self pointer8:49566 owner:7897 type:47418 object:_mercStage8]==_mercTimer8 &&
        [self pointer8:111678 owner:118526 type:12577 object:_mercScore8]==_mercContainer8;
}
- (BOOL)mercActive8 {
    if(![self mercLinked8])return NO;
    void *state=[_e8 field:49567 owner:7897 type:18821 object:_mercStage8 size:4];
    void *(*areaGet)(void *,void *)=[_e8 method:197019 owner:7897];
    void *area=areaGet && _e8.threadContext ? areaGet(_e8.threadContext,_mercStage8) : NULL;
    void *shop=[_e8 field:48994 owner:46035 type:122731 object:area size:1];uint8_t isShop=1;
    return state && n8a(state,0)==1 && shop && MTReadMemory(shop,&isShop,1) && isShop==0 && _e8.threadContext;
}
- (BOOL)local8 {
    return (!_mercStage8 || [self mercLinked8]) && _e8.threadContext && _owner8.valid && [self localGO8]==_owner8.gameObject &&
        [self pointer8:22026 owner:77364 type:101222 object:_core8]==_owner8.gameObject &&
        [self pointer8:22026 owner:77364 type:101222 object:_status8]==_owner8.gameObject &&
        [self pointer8:34373 owner:30622 type:27366 object:_reference8]==_core8 &&
        [self pointer8:34375 owner:30622 type:68031 object:_reference8]==_status8 &&
        [self pointer8:34370 owner:30622 type:114814 object:_reference8]==_damage8 &&
        [self pointer8:27499 owner:114814 type:124637 object:_damage8]==_health8 &&
        [self activeInventory8]==_inventory8;
}
- (BOOL)paused8 {
    uint8_t a=0,b=0,c=0;
    const uint32_t fields[]={154881,154882,154883};uint8_t *out[]={&a,&b,&c};
    for(NSUInteger i=0;i<3;i++){void *p=[_e8 field:fields[i] owner:120284 type:122731 object:_status8 size:1];if(!p || !MTReadMemory(p,out[i],1) || *out[i]>1)return YES;}
    void *input=[_e8 field:154880 owner:120284 type:122731 object:_status8 size:1];uint8_t blocked=1;
    if(!input || !MTReadMemory(input,&blocked,1) || blocked)return YES;
    return a || b || c || [self pauseMenu8];
}
- (BOOL)pauseMenu8 {
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();if(now<_guiPauseNext8)return _guiPause8;
    _guiPauseNext8=now+0.1;_guiPause8=YES;
    void *manager=[self global8:728083 type:54040],*list=[self pointer8:94375 owner:54040 type:6256 object:manager];
    BOOL (*showing)(void *,void *,uint32_t)=[_e8 method:495000 owner:54040];
    if(!manager || !showing || ![_e8 isObject:list kindOf:6256] || n8a(list,0x18)>512)return YES;
    _guiPause8=NO;
    for(NSValue *entry in [self list8:list type:6256 limit:512]){
        void *handle=entry.pointerValue,*driver=[self pointer8:1813 owner:80675 type:22340 object:handle];
        // Match actual native pause drivers, then let GUIManager determine
        // visibility; pooled/hidden windows do not count as an open menu.
        if(![_e8 isObject:driver kindOf:59784] && ![_e8 isObject:driver kindOf:81620] && ![_e8 isObject:driver kindOf:62404] && ![_e8 isObject:driver kindOf:34001] && ![_e8 isObject:driver kindOf:74665] && ![_e8 isObject:driver kindOf:50761])continue;
        void *alias=[_e8 field:1815 owner:80675 type:12387 object:handle size:4];
        if(!alias || !_e8.threadContext){_guiPause8=YES;break;}
        BOOL visible=showing(_e8.threadContext,manager,n8a(alias,0));
        if(!_e8.threadContext || visible){_guiPause8=YES;break;}
    }
    return _guiPause8;
}
- (BOOL)craft8:(RE2Feature)feature {
    void *manager=[self global8:728137 type:18774];
    void *dataList=[self pointer8:146948 owner:18774 type:24433 object:manager];
    NSUInteger changed=0;BOOL okay=YES;int32_t zero=0;
    for(NSValue *dataValue in [self list8:dataList type:24433 limit:256]){
        void *data=dataValue.pointerValue,*units=[self pointer8:93990 owner:69463 type:73303 object:data];
        for(NSValue *unitValue in [self list8:units type:73303 limit:512]){
            void *unit=unitValue.pointerValue,*materials=[self pointer8:94007 owner:45456 type:114174 object:unit];
            for(NSValue *materialValue in [self list8:materials type:114174 limit:16]){
                void *material=materialValue.pointerValue,*p=[_e8 field:93992 owner:12740 type:18821 object:material size:4];
                int32_t cost=p ? (int32_t)n8a(p,0) : -1;if(cost<0 || cost>9999)continue;
                okay&=[self bytes8:b8a(&zero,4) field:93992 owner:12740 type:18821 object:material feature:feature guard:^BOOL{
                    return [self global8:728137 type:18774]==manager && [self pointer8:146948 owner:18774 type:24433 object:manager]==dataList &&
                        [[self list8:dataList type:24433 limit:256] containsObject:dataValue] && [self pointer8:93990 owner:69463 type:73303 object:data]==units &&
                        [[self list8:units type:73303 limit:512] containsObject:unitValue] && [self pointer8:94007 owner:45456 type:114174 object:unit]==materials &&
                        [[self list8:materials type:114174 limit:16] containsObject:materialValue];
                }];changed++;
            }
        }
    }return okay && changed>0;
}
- (BOOL)cooking8:(RE2Feature)feature {
    if([_e8 isObject:_core8 kindOf:75607])return NO; // Rose has no Duke cooking.
    void *manager=[self global8:728236 type:68071];
    void *dataList=[self pointer8:100293 owner:68071 type:17485 object:manager];
    NSUInteger changed=0;BOOL okay=YES;int32_t zero=0;
    for(NSValue *dataValue in [self list8:dataList type:17485 limit:256]){
        void *data=dataValue.pointerValue,*units=[self pointer8:95684 owner:38724 type:19388 object:data];
        for(NSValue *unitValue in [self list8:units type:19388 limit:512]){
            void *unit=unitValue.pointerValue,*materials=[self pointer8:95704 owner:105790 type:51577 object:unit];
            for(NSValue *materialValue in [self list8:materials type:51577 limit:16]){
                void *material=materialValue.pointerValue,*p=[_e8 field:95707 owner:44299 type:18821 object:material size:4];
                int32_t cost=p ? (int32_t)n8a(p,0) : -1;if(cost<0 || cost>9999)continue;
                okay&=[self bytes8:b8a(&zero,4) field:95707 owner:44299 type:18821 object:material feature:feature guard:^BOOL{
                    return [self global8:728236 type:68071]==manager && [self pointer8:100293 owner:68071 type:17485 object:manager]==dataList &&
                        [[self list8:dataList type:17485 limit:256] containsObject:dataValue] && [self pointer8:95684 owner:38724 type:19388 object:data]==units &&
                        [[self list8:units type:19388 limit:512] containsObject:unitValue] && [self pointer8:95704 owner:105790 type:51577 object:unit]==materials &&
                        [[self list8:materials type:51577 limit:16] containsObject:materialValue];
                }];changed++;
            }
        }
    }return okay && changed>0;
}
- (BOOL)bytes8:(NSData *)bytes field:(uint32_t)i owner:(uint32_t)o type:(uint32_t)t object:(void *)object feature:(RE2Feature)f guard:(BOOL (^)(void))guard {
    return [self bytes8:bytes field:i owner:o type:t object:object feature:f bindingOwner:_owner8 guard:guard];
}
- (BOOL)bytes8:(NSData *)bytes field:(uint32_t)i owner:(uint32_t)o type:(uint32_t)t object:(void *)object feature:(RE2Feature)f bindingOwner:(RE8Owner *)owner guard:(BOOL (^)(void))guard {
    void *p=[_e8 field:i owner:o type:t object:object size:bytes.length];
    RE8Owner *localOwner=_owner8;NSString *identity=[_identity8 copy];
    return p && [self applyBytes:bytes object:object offset:(uint8_t *)p-(uint8_t *)object owner:owner global:NO feature:f guard:^BOOL{
        return owner.valid && localOwner.valid && [_identity8 isEqual:identity] && _owner8.gameObject==localOwner.gameObject && [self local8] && (!guard || guard());
    }];
}
- (NSArray<NSValue *> *)items8 {
    void *list=[self pointer8:23075 owner:102832 type:74516 object:_inventory8];
    if(![_e8 isObject:list kindOf:74516])return @[];
    void *array=(void *)p8a(list,0x10);uint32_t count=n8a(list,0x18),capacity=n8a(array,0x1c);
    if([_e8 typeOf:array]==UINT32_MAX || count>256 || capacity>4096 || count>capacity)return @[];
    NSMutableArray *out=[NSMutableArray new];for(uint32_t i=0;i<count;i++){
        void *item=(void *)p8a(array,0x20+i*8);if([_e8 isObject:item kindOf:81486])[out addObject:[NSValue valueWithPointer:item]];
    }return out;
}
- (void *)equipped8 {
    void *weapon=[self pointer8:41404 owner:126251 type:109220 object:_status8];
    void *owner=[self pointer8:45492 owner:109220 type:101222 object:weapon];
    if(owner!=_owner8.gameObject || ![[self items8] containsObject:[NSValue valueWithPointer:weapon]])return NULL;
    void *f=[_e8 field:45491 owner:109220 type:122731 object:weapon size:1];uint8_t equipped=0;
    return f && MTReadMemory(f,&equipped,1) && equipped==1 ? weapon : NULL;
}
- (BOOL)ownsWeapon8:(void *)weapon {
    // Restore an old weapon while it still belongs to this inventory, even
    // after another weapon was equipped. Application eligibility is separate.
    return [_e8 isObject:weapon kindOf:109220] && [[self items8] containsObject:[NSValue valueWithPointer:weapon]];
}
- (RE2GameContext *)captureContext {
    RE2GameContext *s=[RE2GameContext new];if(!_e8.identified){s.note=_e8.failure;return s;}
    s.kind=RE2SessionLoading;s.identity=@"re8/loading";s.note=@"Village · wartet auf die lokale Spielfigur.";
    if(!_e8.isGameThread || !_e8.threadContext)return s;
    [self note8:@"captureContext entered confirmed GameThread"];
    if(!_pump8){__weak RE8NativeAdapter *weakSelf=self;[_e8 setContinuousWork:^{[weakSelf frame8];}];_pump8=YES;}
    void *go=[self localGO8];if(!go)return s;
    void *(*get)(void *)=[_e8 method:148661 owner:24896];
    void *reference=get ? get(_e8.threadContext) : NULL;
    void *core=[self pointer8:34373 owner:30622 type:27366 object:reference];
    void *status=[self pointer8:34375 owner:30622 type:68031 object:reference];
    void *damage=[self pointer8:34370 owner:30622 type:114814 object:reference];
    void *hp=[self pointer8:27499 owner:114814 type:124637 object:damage];
    void *inventory=[self activeInventory8];
    if(![_e8 isObject:reference kindOf:120403] || ![_e8 isObject:core kindOf:20717] || ![_e8 isObject:status kindOf:120284] || [_e8 typeOf:hp]!=124637 || [_e8 typeOf:inventory]!=102832 ||
       [self pointer8:22026 owner:77364 type:101222 object:core]!=go || [self pointer8:22026 owner:77364 type:101222 object:status]!=go){
        [self note8:[NSString stringWithFormat:@"waiting ref=%u core=%u status=%u health=%u inventory=%u",[_e8 typeOf:reference],[_e8 typeOf:core],[_e8 typeOf:status],[_e8 typeOf:hp],[_e8 typeOf:inventory]]];return s;
    }
    [self note8:@"local player graph ready; validating native Guid"];
    RE8Owner *owner=[RE8Owner ownerForGameObject:go engine:_e8];if(!owner.valid){[self note8:[NSString stringWithFormat:@"Guid owner created=%d identity=%@ contextAfter=%d",owner!=nil,owner.identity ?: @"missing",_e8.threadContext!=NULL]];return s;}
    void *flow=[self mercGetter8:739886 type:5676],*stage=NULL,*timer=NULL,*score=NULL,*container=NULL;
    void *mode=[_e8 field:49412 owner:5676 type:122731 object:flow size:1];uint8_t inMerc=0;
    uint32_t stageHash=0;int32_t floor=0;
    if(mode && MTReadMemory(mode,&inMerc,1) && inMerc==1){
        stage=[self mercGetter8:739888 type:7897];timer=[self mercGetter8:739916 type:47418];score=[self mercGetter8:739906 type:118526];
        container=[self pointer8:111678 owner:118526 type:12577 object:score];
        void *h=[_e8 field:49413 owner:5676 type:12387 object:flow size:4],*f=[_e8 field:49570 owner:7897 type:18821 object:stage size:4];
        if(!stage || !timer || !score || !container || !h || !f || [self pointer8:49565 owner:7897 type:18186 object:stage]!=status ||
           [self pointer8:49586 owner:7897 type:5676 object:stage]!=flow || [self pointer8:49566 owner:7897 type:47418 object:stage]!=timer){
            [self note8:[NSString stringWithFormat:@"merc waiting flow=%u stage=%u timer=%u score=%u container=%u statusMatch=%d",[_e8 typeOf:flow],[_e8 typeOf:stage],[_e8 typeOf:timer],[_e8 typeOf:score],[_e8 typeOf:container],[self pointer8:49565 owner:7897 type:18186 object:stage]==status]];return s;
        }
        stageHash=n8a(h,0);floor=(int32_t)n8a(f,0);if(!stageHash || floor<0 || floor>100)return s;
    }
    NSString *identity=[NSString stringWithFormat:@"re8/%@/%p/%p/%p/%p/%p/%p/merc:%p/%u/%d/%p/%p",owner.identity,inventory,reference,core,status,damage,hp,stage,stageHash,floor,timer,container];
    if(_identity8 && ![_identity8 isEqual:identity])[self releaseEffects];
    _owner8=owner;_reference8=reference;_core8=core;_status8=status;_damage8=damage;_health8=hp;_inventory8=inventory;
    _mercFlow8=stage ? flow : NULL;_mercStage8=stage;_mercTimer8=timer;_mercScore8=score;_mercContainer8=container;_mercHash8=stageHash;_mercFloor8=floor;
    BOOL rose=[_e8 isObject:core kindOf:75607];
    s.kind=RE2SessionSolo;s.identity=identity;s.note=rose ? @"Rose-DLC · lokale Figur und Spielthread bestätigt." : @"Village · lokale Figur und Spielthread bestätigt.";
    if(rose && !_roseBindingsLogged8){_roseBindingsLogged8=YES;
        os_log(_log8,"RE8 Rose graph ref=%{public}u core=%{public}u status=%{public}u health=%{public}u inventory=%{public}u",[_e8 typeOf:reference],[_e8 typeOf:core],[_e8 typeOf:status],[_e8 typeOf:hp],[_e8 typeOf:inventory]);
        const uint32_t bindings[][2]={{789367,70663},{789368,70663},{789369,70663},{607856,47358},{607852,47358},{607853,47358},{607857,47358},{607858,47358},{397614,33234}};
        for(NSUInteger i=0;i<sizeof(bindings)/sizeof(bindings[0]);i++){void *fn=[_e8 method:bindings[i][0] owner:bindings[i][1]];os_log(_log8,"RE8 Rose method=%{public}u imageVA=0x%{public}lx",bindings[i][0],fn ? (unsigned long)((uintptr_t)fn-_e8.slide) : 0);}
    }
    if(![_identity8 isEqual:s.identity]){
        _identity8=s.identity;[self note8:@"local gameplay graph and native Guid owner confirmed"];
        const uint32_t methods[]={126711,126712,126733,126751};
        for(NSUInteger i=0;i<4;i++){void *fn=[_e8 method:methods[i] owner:41677];if(fn)[self note8:[NSString stringWithFormat:@"weapon method=%u imageVA=0x%lx",methods[i],(unsigned long)((uintptr_t)fn-_e8.slide)]];}
        for(NSValue *entry in [self items8]){
            void *item=entry.pointerValue,*work=[self pointer8:23094 owner:81486 type:8566 object:item];
            void *stack=[_e8 field:22800 owner:8566 type:18821 object:work size:4],*category=[_e8 field:22797 owner:8566 type:12387 object:work size:4];
            [self note8:[NSString stringWithFormat:@"item type=%u category=%u stack=%d",[_e8 typeOf:item],category ? n8a(category,0) : 0,stack ? (int32_t)n8a(stack,0) : -1]];
        }
    }return s;
}
- (void)releaseEffects {_mercGoalVerifyAt8=0;_mercGoalVerifyOwner8=nil;_mercReady8=NO;_mercPending8=nil;_mercSeen8=nil;_mercGoals8=nil;_mercScanNext8=0;[_wanted8 removeAllObjects];_moneyReady8=NO;_highlightApplied8=NO;_highlightNext8=0;_guiPauseNext8=0;_timeVerifyAt8=0;_timeVerifyIdentity8=nil;[super releaseEffects];[_highlightOwners8 removeAllObjects];[_weaponBindings8 removeAllObjects];}
- (void)frame8 {
    if(_mouseOwned8)[self setOverlayInteraction:YES];
    if(![self local8]){[self releaseEffects];return;}
    [self resumeMerc8];
    [self inspectMerc8];
    [self traceWeapon8];
    [self verifyTime8];
    for(NSNumber *f in _wanted8.allKeys.copy)[self applyFeature:f.integerValue wanted:YES value:_wanted8[f].doubleValue];
}
- (void *)objectGetter8:(uint32_t)method owner:(uint32_t)owner object:(void *)object type:(uint32_t)type {
    if(![_e8 isObject:object kindOf:owner] || !_e8.threadContext)return NULL;
    void *(*get)(void *,void *)=[_e8 method:method owner:owner];void *p=get ? get(_e8.threadContext,object) : NULL;
    return _e8.threadContext && [_e8 isObject:p kindOf:type] ? p : NULL;
}
- (void *)component8:(uint32_t)type gameObject:(void *)go {
    if([_e8 typeOf:go]!=101222)return NULL;void *found=NULL,*c=(void *)p8a(go,0x20);
    for(NSUInteger i=0;c && i<512;i++){
        if(![_e8 isObject:c kindOf:95136] || (void *)p8a(c,0x10)!=go)return NULL;
        if([_e8 isObject:c kindOf:type]){if(found)return NULL;found=c;}
        void *next=(void *)p8a(c,0x18);if(next==c)return NULL;c=next;
    }return c ? NULL : found;
}
- (void)inspectMerc8 {
    if(!_mercStage8 || ![self mercLinked8])return;
    if(!_mercLogged8){_mercLogged8=YES;
        const uint32_t methods[][2]={{608060,15896},{53261,15036},{607854,47358},{607855,47358},{607857,47358},{256496,36598},{3847,112442},{3848,112442},{739886,19855},{739888,19855},{739906,19855},{739912,19855},{739916,19855},{197019,7897},{192643,47418},{192651,47418},{192656,47418},{192657,47418},{597514,12577},{597512,12577},{597525,106785},{738944,14680},{738950,14680},{793918,53980},{793916,53980},{793922,80223},{738952,14680}};
        for(NSUInteger i=0;i<sizeof(methods)/sizeof(methods[0]);i++){void *fn=[_e8 method:methods[i][0] owner:methods[i][1]];os_log(_log8,"RE8 merc method=%{public}u imageVA=0x%{public}lx",methods[i][0],fn ? (unsigned long)((uintptr_t)fn-_e8.slide) : 0);}
    }
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
    if(now>=_mercTraceNext8 && _mercTraceCount8<40){_mercTraceNext8=now+3;_mercTraceCount8++;
        double (*remaining)(void *,void *)=[_e8 method:192643 owner:47418];double t=remaining ? remaining(_e8.threadContext,_mercTimer8) : NAN;
        void *stop=[_e8 field:48948 owner:47418 type:122731 object:_mercTimer8 size:1],*state=[_e8 field:49567 owner:7897 type:18821 object:_mercStage8 size:4];
        void *total=[_e8 field:111663 owner:12577 type:18821 object:_mercContainer8 size:4],*area=[_e8 field:111664 owner:12577 type:18821 object:_mercContainer8 size:4];
        os_log(_log8,"RE8 merc round=%{public}u floor=%{public}d flow=%{public}u active=%{public}d time=%{public}.3f stop=%{public}u total=%{public}u area=%{public}u",_mercHash8,_mercFloor8,state ? n8a(state,0) : UINT32_MAX,[self mercActive8],t,stop ? n8a(stop,0)&255 : 255,total ? n8a(total,0) : UINT32_MAX,area ? n8a(area,0) : UINT32_MAX);
    }
    if(![self mercActive8])return;
    if(!_mercPending8 && now>=_mercScanNext8){_mercScanNext8=now+10;_mercVisited8=0;_mercCursor8=0;_mercPending8=[NSMutableArray new];_mercSeen8=[NSMutableSet new];if(!_mercGoals8)_mercGoals8=[NSMutableDictionary new];
        const uint32_t sources[]={643821,643822};
        for(NSUInteger i=0;i<2;i++){void *(*get)(void *)=[_e8 method:sources[i] owner:57015];void *scene=get && _e8.threadContext ? get(_e8.threadContext) : NULL;
            void *first=[self objectGetter8:256496 owner:36598 object:scene type:112442];
            [self note8:[NSString stringWithFormat:@"merc tree source=%u scene=%u first=%u method=%d",sources[i],[_e8 typeOf:scene],[_e8 typeOf:first],[_e8 method:256496 owner:36598]!=NULL]];if(first)[_mercPending8 addObject:[NSValue valueWithPointer:first]];}
    }
    for(NSUInteger i=0;i<64 && _mercCursor8<_mercPending8.count && _mercVisited8<65536;i++){
        NSValue *entry=_mercPending8[_mercCursor8++];if([_mercSeen8 containsObject:entry])continue;[_mercSeen8 addObject:entry];_mercVisited8++;
        void *t=entry.pointerValue,*go=[self objectGetter8:352118 owner:95136 object:t type:101222];if([self component8:112442 gameObject:go]!=t)continue;
        const uint32_t links[]={3848,3847};for(NSUInteger n=0;n<2;n++){void *next=[self objectGetter8:links[n] owner:112442 object:t type:112442];if(next && next!=t && _mercPending8.count<65536)[_mercPending8 addObject:[NSValue valueWithPointer:next]];}
        void *goal=[self component8:14680 gameObject:go];if(!goal)continue;
        RE8Owner *owner=[RE8Owner ownerForComponent:goal engine:_e8];if(!owner.valid)continue;
        NSString *key=[owner.identity stringByAppendingFormat:@"/%p",goal];if(_mercGoals8[key])continue;
        if(_mercGoals8.count<32)_mercGoals8[key]=owner;
        void *threshold=[_e8 field:151910 owner:14680 type:18821 object:goal size:4],*active=[_e8 field:151914 owner:14680 type:122731 object:goal size:1];uint8_t on=0;if(active)MTReadMemory(active,&on,1);
        os_log(_log8,"RE8 merc goal discovered threshold=%{public}d active=%{public}d component=%{public}u",threshold ? (int32_t)n8a(threshold,0) : -1,on,[_e8 typeOf:goal]);
    }
    if(_mercCursor8>=_mercPending8.count || _mercVisited8>=65536)_mercPending8=nil;
    if(!_mercPending8 && _mercVisited8)[self note8:[NSString stringWithFormat:@"merc tree visited=%lu goals=%lu",(unsigned long)_mercVisited8,(unsigned long)_mercGoals8.count]];
    if(_mercGoalVerifyAt8 && now>=_mercGoalVerifyAt8){_mercGoalVerifyAt8=0;
        if([_identity8 isEqual:_mercGoalVerifyIdentity8] && _mercGoalVerifyOwner8.valid){
            void *goal=_mercGoalVerifyOwner8.component,*controller=[self pointer8:151913 owner:14680 type:50495 object:goal];
            void *state=[self pointer8:151906 owner:50495 type:102424 object:controller],*shown=[_e8 field:205087 owner:80223 type:122731 object:state size:1];uint8_t on=0;
            BOOL okay=shown && MTReadMemory(shown,&on,1) && on==1;
            os_log(_log8,"RE8 merc goal deferred state=%{public}u showing=%{public}d confirmed=%{public}d",[_e8 typeOf:state],on,okay);
        }_mercGoalVerifyOwner8=nil;
    }
}
- (void *)mercTimerSource8 {
    void *timer=[self global8:727957 type:50832],*dictionary=[self pointer8:113051 owner:50832 type:15896 object:timer];
    BOOL (*find)(void *,void *,uint32_t,void **)=[_e8 method:608060 owner:15896];void *source=NULL;
    if(!dictionary || !find || !_e8.threadContext || !find(_e8.threadContext,dictionary,0x9940ff6e,&source))return NULL;
    // Key independently verified in this executable's remainTimeSec,
    // requestTimeStart and requestTimeStop implementations.
    return _e8.threadContext && [_e8 typeOf:source]==47358 ? source : NULL;
}
- (void)resumeMerc8 {
    if(!_mercResumeOwner8)return;
    if(!_mercResumeOwner8.valid || ![_identity8 isEqual:_mercResumeIdentity8] || ![self mercLinked8] || [self mercTimerSource8]!=_mercResumeSource8){_mercResumeOwner8=nil;return;}
    if([self paused8])return;
    void (*start)(void *,void *)=[_e8 method:607854 owner:47358];void (*pause)(void *,void *,BOOL)=[_e8 method:607857 owner:47358];
    if(start && pause && _e8.threadContext){start(_e8.threadContext,_mercResumeSource8);if(_e8.threadContext)pause(_e8.threadContext,_mercResumeSource8,NO);os_log(_log8,"RE8 merc timer deferred native resume");}
    _mercResumeOwner8=nil;
}
- (BOOL)mercTime8 {
    void *source=[self mercTimerSource8],*watch=[self pointer8:112936 owner:47358 type:15036 object:source];
    BOOL (*running)(void *,void *)=[_e8 method:53261 owner:15036];
    void (*start)(void *,void *)=[_e8 method:607854 owner:47358],(*stop)(void *,void *)=[_e8 method:607855 owner:47358];
    if(!watch || !running || !start || !stop || !_e8.threadContext)return NO;
    RE2Feature feature=(RE2Feature)RE8MercTime;
    if(![self baselineForNativeObject:watch tag:53261 feature:feature] && ([self paused8] || !running(_e8.threadContext,watch)))return NO;
    RE8Owner *owner=_owner8;NSString *identity=[_identity8 copy];void *timer=_mercTimer8;
    BOOL (^guard)(void)=^BOOL{return owner.valid && [_identity8 isEqual:identity] && [self local8] && [self mercLinked8] && _mercTimer8==timer && [self mercTimerSource8]==source && [self pointer8:112936 owner:47358 type:15036 object:source]==watch;};
    uint8_t no=0;
    BOOL okay=[self applyNativeBytes:b8a(&no,1) object:watch tag:53261 owner:owner feature:feature guard:guard read:^NSData *{
        if(!_e8.threadContext)return nil;uint8_t v=running(_e8.threadContext,watch);return _e8.threadContext ? b8a(&v,1) : nil;
    } write:^(NSData *bytes){
        uint8_t v=0;[bytes getBytes:&v length:1];
        if(v && [self paused8]){_mercResumeOwner8=owner;_mercResumeSource8=source;_mercResumeIdentity8=identity;return;}
        if(v){start(_e8.threadContext,source);void (*pause)(void *,void *,BOOL)=[_e8 method:607857 owner:47358];if(pause && _e8.threadContext)pause(_e8.threadContext,source,NO);}
        else {_mercResumeOwner8=nil;stop(_e8.threadContext,source);}
    }];
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();if(okay && now>=_mercTimeLogNext8){_mercTimeLogNext8=now+5;
        double (*remaining)(void *,void *)=[_e8 method:192643 owner:47418];double t=remaining ? remaining(_e8.threadContext,timer) : NAN;
        os_log(_log8,"RE8 merc timer native stopped=%{public}d remaining=%{public}.6f",!running(_e8.threadContext,watch),t);
    }return okay;
}
- (NSString *)mercOpenGoal8 {
    if(![self mercActive8])return @"Ziel benötigt ein aktives Söldner-Gebiet außerhalb des Shops.";
    NSMutableArray<RE8Owner *> *active=[NSMutableArray new];
    for(RE8Owner *owner in _mercGoals8.allValues.copy){if(!owner.valid)continue;
        void *p=[_e8 field:151914 owner:14680 type:122731 object:owner.component size:1];uint8_t on=0;
        if(p && MTReadMemory(p,&on,1) && on==1)[active addObject:owner];
    }
    if(active.count!=1)return @"Wartet auf genau ein geladenes, aktives Zielportal. Bitte in wenigen Sekunden erneut ausführen.";
    RE8Owner *owner=active.firstObject;void *goal=owner.component;
    void *p=[_e8 field:151910 owner:14680 type:18821 object:goal size:4];int32_t before=p ? (int32_t)n8a(p,0) : -1;
    if(before<0 || before>10000)return @"Native Zielbedingung nicht bestätigt.";
    // HideState.canChangeState compares this threshold against actual kills.
    // Leave the game to enter its regular ShowState, with effect, GUI and
    // interaction checker. Never invoke warp, goal-interact or stage-result.
    if(!owner.valid || ![self mercActive8] || !MTWriteInt(p,0,0) || n8a(p,0)!=0)return @"Zielbedingung konnte nicht bestätigt werden.";
    _mercGoalVerifyOwner8=owner;_mercGoalVerifyIdentity8=[_identity8 copy];_mercGoalVerifyAt8=CFAbsoluteTimeGetCurrent()+1;
    os_log(_log8,"RE8 merc goal threshold before=%{public}d after=0 readback=1",before);
    return @"Zielbedingung nativ freigegeben; das Spiel öffnet das vorhandene Portal.";
}
- (BOOL)mercScore8:(RE2Feature)feature factor:(double)factor {
    void *total=[_e8 field:111663 owner:12577 type:18821 object:_mercContainer8 size:4],*area=[_e8 field:111664 owner:12577 type:18821 object:_mercContainer8 size:4];
    int32_t current=total ? (int32_t)n8a(total,0) : -1,local=area ? (int32_t)n8a(area,0) : -1;
    if(current<0 || local<0 || current<local || current>99999999)return NO;
    int32_t bonus=0;
    if((NSInteger)feature==RE8MercScore){bonus=current<9999999 ? 9999999-current : 0;_mercReady8=NO;}
    else if(_mercReady8)bonus=MTRE8MercenaryBonus(_mercBefore8,current,local,factor);
    if(bonus>0){
        void *gui=[self pointer8:111680 owner:118526 type:106785 object:_mercScore8];void (*update)(void *,void *,int32_t)=[_e8 method:597525 owner:106785];
        if(!gui || !update || ![self mercActive8] || !MTWriteInt(area,0,local+bonus) || !MTWriteInt(total,0,current+bonus))return NO;
        int32_t (*get)(void *,void *)=[_e8 method:597531 owner:118526];
        if(!get || !_e8.threadContext || get(_e8.threadContext,_mercScore8)!=current+bonus || n8a(area,0)!=(uint32_t)(local+bonus))return NO;
        update(_e8.threadContext,gui,current+bonus);if(!_e8.threadContext)return NO;
        os_log(_log8,"RE8 merc score feature=%{public}ld gain=%{public}d factor=%{public}.2f before=%{public}d bonus=%{public}d total=%{public}d area=%{public}d readback=1",(long)feature,_mercReady8 ? current-_mercBefore8 : 0,factor,current,bonus,current+bonus,local+bonus);
        current+=bonus;
    }
    _mercBefore8=current;_mercReady8=(NSInteger)feature==RE8MercMultiplier;return YES;
}
- (void *)rosePlayTimeSource8 {
    if(![_e8 isObject:_core8 kindOf:75607])return NULL;
    void *manager=[self global8:727957 type:50832],*dictionary=[self pointer8:113051 owner:50832 type:15896 object:manager];
    BOOL (*find)(void *,void *,uint32_t,void **)=[_e8 method:608060 owner:15896];void *source=NULL;
    // TDB71 app.ContentTimerType.PlayingTimeHash (literal field80187).
    if(!dictionary || !find || !_e8.threadContext || !find(_e8.threadContext,dictionary,3613960333u,&source))return NULL;
    return _e8.threadContext && [_e8 typeOf:source]==47358 ? source : NULL;
}
- (NSString *)adjustRoseTime8 {
    void *source=[self rosePlayTimeSource8],*watch=[self pointer8:112936 owner:47358 type:15036 object:source];
    double (*elapsed)(void *,void *,BOOL)=[_e8 method:607858 owner:47358];BOOL (*running)(void *,void *)=[_e8 method:53261 owner:15036];
    void (*reset)(void *,void *)=[_e8 method:607856 owner:47358];
    void (*setup)(void *,void *,double,BOOL)=[_e8 method:607852 owner:47358],(*setupPause)(void *,void *,double)=[_e8 method:607853 owner:47358];
    void (*pause)(void *,void *,BOOL)=[_e8 method:607857 owner:47358];
    if(!source || !watch || !elapsed || !running || !reset || !setup || !setupPause || !pause || !_e8.threadContext)return @"Aktueller Rose-Spielzeitgeber nicht bestätigt.";
    double before=elapsed(_e8.threadContext,source,YES);BOOL wasRunning=_e8.threadContext && running(_e8.threadContext,watch);
    if(!_e8.threadContext || !isfinite(before) || before<0 || before>1.0e12 || ![self local8])return @"Rose-Spielzeit nicht plausibel.";
    double next=fmax(0,before-3600000.0);BOOL isPaused=[self paused8];
    // Source.setup assigns its loaded TimeSpan but does not clear elapsed
    // Stopwatch ticks. Use the native reset for both linked watches first,
    // then restore the observed run/pause state with the new loaded duration.
    reset(_e8.threadContext,source);if(!_e8.threadContext)return @"Rose-Zeitgeber konnte nicht neu bezogen werden.";
    setup(_e8.threadContext,source,next,wasRunning);if(!_e8.threadContext)return @"Rose-Zeitgeber hat den Aufruf abgelehnt.";
    setupPause(_e8.threadContext,source,0);if(!_e8.threadContext)return @"Rose-Pausenzeit konnte nicht neu bezogen werden.";
    pause(_e8.threadContext,source,isPaused);if(!_e8.threadContext)return @"Rose-Pausenzustand nicht bestätigt.";
    double after=elapsed(_e8.threadContext,source,YES);
    BOOL okay=_e8.threadContext && [self rosePlayTimeSource8]==source && isfinite(after) && after>=next-1 && after<=next+100;
    if(okay){_timeVerifyStart8=CFAbsoluteTimeGetCurrent();_timeVerifyAt8=_timeVerifyStart8+2;_timeVerifyExpected8=(float)(next/1000);_timeVerifyData8=source;_timeVerifyRose8=YES;_timeVerifyIdentity8=[_identity8 copy];}
    os_log(_log8,"RE8 Rose active play time beforeMS=%{public}.3f afterMS=%{public}.3f running=%{public}d paused=%{public}d readback=%{public}d",before,after,wasRunning,isPaused,okay);
    return okay ? @"Rose-Spielzeit des laufenden Spielstands um bis zu eine Stunde verringert." : @"Rose-Spielzeit-Rückleseprüfung fehlgeschlagen.";
}
- (void)verifyTime8 {
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();if(!_timeVerifyAt8 || now<_timeVerifyAt8)return;_timeVerifyAt8=0;
    if(![_identity8 isEqual:_timeVerifyIdentity8] || ![self local8])return;
    BOOL rose=_timeVerifyRose8;
    if(rose){
        void *source=[self rosePlayTimeSource8];double (*elapsed)(void *,void *,BOOL)=[_e8 method:607858 owner:47358];
        if(source!=_timeVerifyData8 || !elapsed || !_e8.threadContext)return;
        double observed=elapsed(_e8.threadContext,source,YES)/1000.0,seconds=now-_timeVerifyStart8;
        BOOL okay=_e8.threadContext && MTRE8TimeReadback(_timeVerifyExpected8,(float)observed,seconds);
        os_log(_log8,"RE8 Rose active time delayed expected=%{public}.3f observed=%{public}.3f elapsed=%{public}.3f stable=%{public}d",_timeVerifyExpected8,observed,seconds,okay);return;
    }
    void *manager=[self global8:rose ? 727921 : 728065 type:rose ? 33234 : 76042];
    void *data=[self pointer8:rose ? 77564 : 77851 owner:rose ? 33234 : 76042 type:rose ? 5030 : 14304 object:manager];
    if(data!=_timeVerifyData8)return;
    void *p=[_e8 field:rose ? 77584 : 77890 owner:rose ? 5030 : 14304 type:76277 object:data size:4];float observed=NAN;
    BOOL read=p && MTReadMemory(p,&observed,4);double elapsed=now-_timeVerifyStart8;
    BOOL okay=read && MTRE8TimeReadback(_timeVerifyExpected8,observed,elapsed);
    os_log(_log8,"RE8 time delayed expected=%{public}.3f observed=%{public}.3f elapsed=%{public}.3f stable=%{public}d",_timeVerifyExpected8,observed,elapsed,okay);
}
- (void)traceWeapon8 {
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();if(now>_weaponTraceUntil8 || now<_weaponTraceNext8 || _weaponTraceCount8>=32)return;_weaponTraceNext8=now+0.25;
    void *weapon=[self equipped8],*work=[self pointer8:23094 owner:81486 type:8566 object:weapon];
    void *mag=[_e8 field:22803 owner:8566 type:18821 object:work size:4];
    void *child=[self pointer8:22781 owner:8566 type:8566 object:work],*count=[_e8 field:22800 owner:8566 type:18821 object:child size:4],*usable=[_e8 field:35054 owner:41677 type:18821 object:weapon size:4];
    const uint32_t gunFields[]={35076,35077,35078,45509,35086};NSMutableString *state=[NSMutableString stringWithFormat:@"mag=%d child=%d usable=%d",mag ? (int32_t)n8a(mag,0) : -1,count ? (int32_t)n8a(count,0) : -1,usable ? (int32_t)n8a(usable,0) : -1];
    for(NSUInteger i=0;i<5;i++){void *p=[_e8 field:gunFields[i] owner:i==3 ? 109220 : 41677 type:122731 object:weapon size:1];uint8_t v=255;if(p)MTReadMemory(p,&v,1);[state appendFormat:@" g%u=%u",gunFields[i],v];}
    const uint32_t statusFields[]={154871,154872,154877,154879,154880};
    for(NSUInteger i=0;i<5;i++){void *p=[_e8 field:statusFields[i] owner:120284 type:122731 object:_status8 size:1];uint8_t v=255;if(p)MTReadMemory(p,&v,1);[state appendFormat:@" s%u=%u",statusFields[i],v];}
    if(![_weaponTraceLast8 isEqual:state]){_weaponTraceLast8=state;_weaponTraceCount8++;os_log(_log8,"RE8 weapon state %{public}@",state);}
}
- (BOOL)stacks8:(RE2Feature)feature {
    NSUInteger changed=0;BOOL okay=YES;
    for(NSValue *entry in [self items8]){
        void *item=entry.pointerValue,*spec=[self pointer8:23089 owner:81486 type:113238 object:item];
        void *basic=[self pointer8:22386 owner:113238 type:98336 object:spec];
        void *work=[self pointer8:23094 owner:81486 type:8566 object:item];
        void *a=[_e8 field:22083 owner:98336 type:18821 object:basic size:4],*b=[_e8 field:22797 owner:8566 type:12387 object:work size:4],*c=[_e8 field:22800 owner:8566 type:18821 object:work size:4];
        int32_t max=a ? (int32_t)n8a(a,0) : 0,current=c ? (int32_t)n8a(c,0) : -1;uint32_t cat=b ? n8a(b,0) : 0;
        BOOL allowed=cat==1053957234u || ((NSInteger)feature==RE8Items && (cat==2936421236u || cat==963607484u || cat==4025304392u || cat==1585764422u));
        if(!allowed || max<=1 || max>9999 || current<=0 || current>max)continue;
        okay&=[self bytes8:b8a(&max,4) field:22800 owner:8566 type:18821 object:work feature:feature guard:^BOOL{return [[self items8] containsObject:entry] && [self pointer8:23094 owner:81486 type:8566 object:item]==work;}];changed++;
    }return okay && changed>0;
}
- (BOOL)reload8:(RE2Feature)feature {
    (void)feature;
    void *weapon=[self equipped8];if(![_e8 isObject:weapon kindOf:41677])return NO;
    void *work=[self pointer8:23094 owner:81486 type:8566 object:weapon];
    int32_t (*maximum)(void *,void *)=[_e8 method:61745 owner:81486];
    if([_e8 typeOf:work]!=8566 || !maximum || !_e8.threadContext)return NO;
    int32_t max=maximum(_e8.threadContext,weapon);
    void *p=[_e8 field:22803 owner:8566 type:18821 object:work size:4];
    int32_t current=p ? (int32_t)n8a(p,0) : -1;
    if(!p || !_e8.threadContext)return NO;
    void *child=[self pointer8:22781 owner:8566 type:8566 object:work];
    void *count=[_e8 field:22800 owner:8566 type:18821 object:child size:4],*itemID=[_e8 field:22796 owner:8566 type:12387 object:child size:4],*includeID=[_e8 field:22802 owner:8566 type:12387 object:work size:4];
    void *category=[_e8 field:22797 owner:8566 type:12387 object:child size:4];
    int32_t loaded=count ? (int32_t)n8a(count,0) : -1;BOOL rose=[_e8 isObject:_core8 kindOf:75607];
    if(!count || !itemID || !includeID || !category || n8a(itemID,0)!=n8a(includeID,0) || n8a(category,0)!=1053957234u || MTRE8LoadedBulletTarget(current,loaded,max,current,rose)<0){
        [self note8:@"magazine cache and loaded bullet work not confirmed consistent"];return NO;
    }
    const uint32_t fields[]={35076,35077,35078,45509,35086};uint8_t flags[5];
    for(NSUInteger i=0;i<5;i++){void *f=[_e8 field:fields[i] owner:i==3 ? 109220 : 41677 type:122731 object:weapon size:1];if(!f || !MTReadMemory(f,&flags[i],1) || flags[i]>1)return NO;}
    int target=MTRE8MagazineTarget(current,max,flags[0],flags[1],flags[2],flags[3],flags[4],[self paused8]);
    int loadedTarget=MTRE8LoadedBulletTarget(current,loaded,max,target,rose);
    if(target<0 || loadedTarget<0 || ![self local8] || [self equipped8]!=weapon || [self pointer8:23094 owner:81486 type:8566 object:weapon]!=work)return NO;
    // Rose's initial pistol was observed with cache5/loaded8, then cache0/
    // loaded3 after real shots. Preserve that game's bounded positive offset;
    // the native operation adds the same delta to both linked counters. Do not
    // force equality or edit either counter independently.
    // Use the actual native refill operation, which owns the loaded-bullet
    // work and weapon bookkeeping. Writing IncludeStackSize alone left a full
    // HUD while the actual shot sequence ran out in the Build 51 game test.
    void (*reload)(void *,void *,int32_t)=[_e8 method:126712 owner:41677];
    if(current!=target){if(!reload || !_e8.threadContext)return NO;reload(_e8.threadContext,weapon,target-current);}
    BOOL okay=_e8.threadContext && [self equipped8]==weapon && [self pointer8:22781 owner:8566 type:8566 object:work]==child && n8a(p,0)==(uint32_t)target && n8a(count,0)==(uint32_t)loadedTarget;
    if(current!=target && CFAbsoluteTimeGetCurrent()<_weaponTraceUntil8)os_log(_log8,"RE8 magazine native refill before=%{public}d requested=%{public}d cache=%{public}d loaded=%{public}d readback=%{public}d",current,target,(int32_t)n8a(p,0),(int32_t)n8a(count,0),okay);
    return okay;
}
- (BOOL)roseRecoil8:(RE2Feature)feature {
    void *camera=[self pointer8:36157 owner:120403 type:69696 object:_reference8];
    if(![_e8 isObject:camera kindOf:19879] || [self pointer8:38890 owner:52187 type:120403 object:camera]!=_reference8)return NO;
    void *solver=[self pointer8:38948 owner:52187 type:46630 object:camera];
    void *controller=[self pointer8:38256 owner:46630 type:47213 object:solver];
    if(![_e8 isObject:controller kindOf:57199])return NO;
    void *parameter=[self pointer8:38303 owner:47213 type:91340 object:controller];
    if([self pointer8:38025 owner:91340 type:52187 object:parameter]!=camera ||
       [self pointer8:38052 owner:91340 type:120403 object:parameter]!=_reference8 ||
       [self pointer8:38022 owner:91340 type:105329 object:parameter]!=_status8)return NO;
    void *aim=[_e8 field:38867 owner:52187 type:122731 object:camera size:1];uint8_t aiming=0;
    if(!aim || !MTReadMemory(aim,&aiming,1) || aiming!=1 || [self paused8])return NO;
    void *p=[_e8 field:38040 owner:91340 type:47020 object:parameter size:12];float angles[3],zero=0;
    if(!p || !MTReadMemory(p,angles,12))return NO;
    for(NSUInteger i=0;i<3;i++)if(!isfinite(angles[i]) || fabsf(angles[i])>180)return NO;
    NSData *original=[self baselineForObject:parameter offset:(uint8_t *)p-(uint8_t *)parameter feature:feature];
    BOOL nonzero=angles[0]!=0 || angles[1]!=0 || angles[2]!=0;
    // Never capture a transient kick as the value to restore on Aus. Acquire
    // only an idle zero vector, then suppress measured shot corrections.
    if(!original && nonzero)return NO;
    void *reference=_reference8;RE8Owner *owner=_owner8;NSString *identity=[_identity8 copy];
    BOOL (^guard)(void)=^BOOL{
        return owner.valid && [_identity8 isEqual:identity] && _owner8.gameObject==owner.gameObject && [self local8] && [_e8 field:38040 owner:91340 type:47020 object:parameter size:12]==p && [self pointer8:36157 owner:120403 type:69696 object:reference]==camera &&
            [self pointer8:38890 owner:52187 type:120403 object:camera]==reference &&
            [self pointer8:38948 owner:52187 type:46630 object:camera]==solver &&
            [self pointer8:38256 owner:46630 type:47213 object:solver]==controller &&
            [self pointer8:38303 owner:47213 type:91340 object:controller]==parameter &&
            [self pointer8:38025 owner:91340 type:52187 object:parameter]==camera &&
            [self pointer8:38052 owner:91340 type:120403 object:parameter]==reference &&
            [self pointer8:38022 owner:91340 type:105329 object:parameter]==_status8;
    };
    // Independently verified in Free.RecoilAdjust.calcRecoilRotation at
    //0x105c436bc: it consumes this vector (+0xe0,+0xe4,+0xe8), separately
    //from the horizontal/vertical mouse input and the camera's main rotation.
    // The shared ledger supports only1/4/8-byte values. Keep three scalar
    // originals/readbacks instead of handing it an unsupported12-byte block.
    BOOL okay=YES;
    for(NSUInteger i=0;i<3;i++)okay&=[self applyBytes:b8a(&zero,4) object:parameter offset:(uint8_t *)p-(uint8_t *)parameter+i*4 owner:owner global:NO feature:feature guard:guard];
    if(okay && nonzero && _roseRecoilCorrections8++<8)os_log(_log8,"RE8 Rose recoil vector x=%{public}.6f y=%{public}.6f z=%{public}.6f ->0 readback=1",angles[0],angles[1],angles[2]);
    return okay;
}
- (BOOL)highlight8:(RE2Feature)feature {
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();if(now<_highlightNext8)return _highlightApplied8;
    _highlightNext8=now+0.5;
    void *manager=[self global8:728107 type:121712];
    void *list=[self pointer8:146712 owner:121712 type:24182 object:manager];
    NSUInteger targets=0;BOOL okay=YES;uint8_t yes=1;float distance=1000,squared=1000000;
    for(NSValue *entry in [self list8:list type:24182 limit:2048]){
        void *interact=entry.pointerValue;if(![_e8 isObject:interact kindOf:44454])continue;
        void *enabled=[_e8 field:23119 owner:11318 type:122731 object:interact size:1];uint8_t active=0;
        if(!enabled || !MTReadMemory(enabled,&active,1) || active!=1)continue;
        void *go=[self pointer8:23115 owner:11318 type:101222 object:interact];
        void *range=[self pointer8:23149 owner:44454 type:124685 object:interact];
        if([_e8 typeOf:go]!=101222 || [_e8 typeOf:range]!=124685)continue;
        RE8Owner *owner=_highlightOwners8[entry];
        if(!owner.valid || owner.gameObject!=go){owner=[RE8Owner ownerForGameObject:go engine:_e8];if(!owner.valid)continue;_highlightOwners8[entry]=owner;}
        BOOL (^guard)(void)=^BOOL{
            return owner.valid && [self global8:728107 type:121712]==manager && [self pointer8:146712 owner:121712 type:24182 object:manager]==list &&
                [[self list8:list type:24182 limit:2048] containsObject:entry] && [self pointer8:23115 owner:11318 type:101222 object:interact]==go &&
                [self pointer8:23149 owner:44454 type:124685 object:interact]==range;
        };
        // Only the existing far-icon range changes. The independent RangeUnit
        // and RangeDistSq controlling actual interaction remain untouched.
        okay&=[self bytes8:b8a(&yes,1) field:23150 owner:124685 type:122731 object:range feature:feature bindingOwner:owner guard:guard];
        okay&=[self bytes8:b8a(&distance,4) field:23151 owner:124685 type:76277 object:range feature:feature bindingOwner:owner guard:guard];
        okay&=[self bytes8:b8a(&squared,4) field:23148 owner:44454 type:76277 object:interact feature:feature bindingOwner:owner guard:guard];targets++;
    }
    _highlightApplied8=okay && targets>0;
    if(_highlightApplied8)[self note8:[NSString stringWithFormat:@"native far-icon ranges applied targets=%lu readback=1",(unsigned long)targets]];
    return _highlightApplied8;
}
- (BOOL)moneyMultiplier8:(double)value {
    void *p=[_e8 field:23083 owner:102832 type:18821 object:_inventory8 size:4];if(!p || !isfinite(value) || value<1 || value>10)return NO;
    int32_t current=(int32_t)n8a(p,0);if(current<0 || current>9999999)return NO;
    if(_moneyReady8 && current>_moneyBefore8){
        int32_t gain=current-_moneyBefore8;int64_t next=(int64_t)current+(int64_t)floor((double)gain*(value-1));if(next>9999999)next=9999999;
        if(next!=current && (!MTWriteInt(p,0,(int32_t)next) || n8a(p,0)!=(uint32_t)next))return NO;
        os_log(_log8,"RE8 money gain=%{public}d factor=%{public}.2f before=%{public}d after=%{public}d readback=1",gain,value,_moneyBefore8,(int32_t)next);current=(int32_t)next;
    }
    _moneyBefore8=current;_moneyReady8=YES;return YES;
}
- (RE2FeatureState *)applyFeature:(RE2Feature)feature wanted:(BOOL)wanted value:(double)value {
    RE2FeatureState *s=[RE2FeatureState new];const RE2FeatureInfo *info=RE8FeatureInfoAt(feature);if(!info)return s;
    if((NSInteger)feature==RE8NoReload && (_wanted8[@(feature)]!=nil)!=wanted){_weaponTraceUntil8=CFAbsoluteTimeGetCurrent()+120;_weaponTraceNext8=0;_weaponTraceCount8=0;_weaponTraceLast8=nil;}
    s.wanted=wanted;s.value=value;
    if(!wanted){[_wanted8 removeObjectForKey:@(feature)];[self releaseFeature:feature];[_weaponBindings8 removeObjectForKey:@(feature)];if((NSInteger)feature==RE8MoneyMultiplier)_moneyReady8=NO;if((NSInteger)feature==RE8MercMultiplier)_mercReady8=NO;if((NSInteger)feature==RE8Highlight){_highlightApplied8=NO;_highlightNext8=0;[_highlightOwners8 removeAllObjects];}s.available=info->implemented;s.note=@"Aus.";return s;}
    if(!info->implemented){s.note=@"Native Village-Anbindung wird noch geprüft.";return s;}
    if(info->oneShot){s.available=YES;s.note=@"Einmalaktion bereit.";return s;}
    if(![self local8] || !isfinite(value)){[self releaseFeature:feature];s.note=@"Wartet auf lokale Village-Daten.";return s;}
    if((NSInteger)feature==RE8NoReload || (NSInteger)feature==RE8Rapid || (NSInteger)feature==RE8Recoil || (NSInteger)feature==RE8OneHit || (NSInteger)feature==RE8Damage){
        void *weapon=[self equipped8];
        if(_weaponBindings8[@(feature)].pointerValue!=weapon){
            [self releaseFeature:feature];
            if(weapon)_weaponBindings8[@(feature)]=[NSValue valueWithPointer:weapon];else [_weaponBindings8 removeObjectForKey:@(feature)];
        }
    }
    _wanted8[@(feature)]=@(value);BOOL okay=NO;uint8_t no=0;
    if((NSInteger)feature==RE8God){
        okay=[self bytes8:b8a(&no,1) field:39563 owner:20717 type:122731 object:_core8 feature:feature guard:nil];
        okay&=[self bytes8:b8a(&no,1) field:39564 owner:20717 type:122731 object:_core8 feature:feature guard:nil];
        okay&=[self bytes8:b8a(&no,1) field:39562 owner:20717 type:122731 object:_core8 feature:feature guard:nil];
    }else if((NSInteger)feature==RE8Health){
        void *a=[_e8 field:27471 owner:124637 type:76277 object:_health8 size:4],*b=[_e8 field:27472 owner:124637 type:76277 object:_health8 size:4];float max=0,current=0;
        if(a && b && MTReadMemory(a,&max,4) && MTReadMemory(b,&current,4) && isfinite(max) && isfinite(current) && current>0 && max>=current && max<10000000)
            okay=[self bytes8:b8a(&max,4) field:27472 owner:124637 type:76277 object:_health8 feature:feature guard:nil];
    }else if((NSInteger)feature==RE8Ammo || (NSInteger)feature==RE8Items)okay=[self stacks8:feature];
    else if((NSInteger)feature==RE8NoReload)okay=[self reload8:feature];
    else if((NSInteger)feature==RE8Highlight){
        if([self paused8]){[self releaseFeature:feature];_highlightApplied8=NO;_highlightNext8=0;s.available=YES;s.note=@"Markierungen pausieren im Spielmenü.";return s;}
        okay=[self highlight8:feature];
    }
    else if((NSInteger)feature==RE8MercTime || (NSInteger)feature==RE8MercScore || (NSInteger)feature==RE8MercMultiplier){
        if(![self mercActive8]){[self releaseFeature:feature];_mercReady8=NO;s.note=@"Wartet auf eine aktive Söldner-Runde außerhalb des Shops.";return s;}
        if((NSInteger)feature==RE8MercTime){okay=[self mercTime8];}else if((NSInteger)feature==RE8MercMultiplier && _wanted8[@(RE8MercScore)]){_mercReady8=NO;s.available=YES;s.note=@"Hohe Punktzahl hat Vorrang.";return s;}
        else okay=[self mercScore8:feature factor:value];
    }
    else if((NSInteger)feature==RE8Craft)okay=[self craft8:feature];
    else if((NSInteger)feature==RE8Cooking)okay=[self cooking8:feature];
    else if((NSInteger)feature==RE8GameSpeed){
        if([self paused8]){[self releaseFeature:feature];s.available=YES;s.note=@"Pausiert im Spielmenü.";return s;}
        // Village's Application update at 0x108152bfc multiplies +0x248
        // into the +0x24c DeltaTime returned by its native getter.
        void *app=[_e8 singletonAt:0x10cfb8bc0];float base=0;NSData *old=[self baselineForObject:app offset:0x248 feature:feature];
        if(old)[old getBytes:&base length:4];else MTReadMemory((uint8_t *)app+0x248,&base,4);float next=base*(float)value;
        if(value>=0.1 && value<=3 && isfinite(base) && base>0 && base<=10)
            okay=[self applyBytes:b8a(&next,4) object:app offset:0x248 owner:nil global:YES feature:feature guard:^BOOL{return [self local8] && [_e8 singletonAt:0x10cfb8bc0]==app;}];
    }
    else if((NSInteger)feature==RE8PlayerSpeed){
        if([self paused8]){[self releaseFeature:feature];s.available=YES;s.note=@"Pausiert im Spielmenü.";return s;}
        void *p=[_e8 field:39587 owner:20717 type:76277 object:_core8 size:4];float base=0;NSData *old=p ? [self baselineForObject:_core8 offset:(uint8_t *)p-(uint8_t *)_core8 feature:feature] : nil;
        if(old)[old getBytes:&base length:4];else if(p)MTReadMemory(p,&base,4);float next=base*(float)value;
        if(value>=0.25 && value<=3 && isfinite(base) && base>0 && base<=10)okay=[self bytes8:b8a(&next,4) field:39587 owner:20717 type:76277 object:_core8 feature:feature guard:nil];
    }else if((NSInteger)feature==RE8MoneyMultiplier)okay=[self moneyMultiplier8:value];
    else {
        void *weapon=[self equipped8];BOOL (^guard)(void)=^BOOL{return [self ownsWeapon8:weapon];};
        if((NSInteger)feature==RE8OneHit || (NSInteger)feature==RE8Damage){
            if((NSInteger)feature==RE8Damage && _wanted8[@(RE8OneHit)]){[self releaseFeature:feature];s.available=YES;s.note=@"Ein Treffer hat Vorrang.";return s;}
            if((NSInteger)feature==RE8OneHit)[self releaseFeature:(RE2Feature)RE8Damage];
            void *p=[_e8 field:45524 owner:109220 type:76277 object:weapon size:4];float base=0;NSData *old=p ? [self baselineForObject:weapon offset:(uint8_t *)p-(uint8_t *)weapon feature:feature] : nil;
            if(old)[old getBytes:&base length:4];else if(p)MTReadMemory(p,&base,4);
            float next=(NSInteger)feature==RE8OneHit ? 1000000.0f : base*(float)value;
            if(isfinite(base) && base>0 && base<=1000000 && value>=0 && value<=100)okay=[self bytes8:b8a(&next,4) field:45524 owner:109220 type:76277 object:weapon feature:feature guard:guard];
        }else if((NSInteger)feature==RE8Rapid && [_e8 isObject:weapon kindOf:41677]){
            float zero=0;okay=[self bytes8:b8a(&zero,4) field:35087 owner:41677 type:76277 object:weapon feature:feature guard:guard];
        }else if((NSInteger)feature==RE8Recoil && [_e8 isObject:_core8 kindOf:75607]){
            okay=[self roseRecoil8:feature];
        }else if((NSInteger)feature==RE8Recoil && [_e8 isObject:weapon kindOf:41677]){
            void *spec=[self pointer8:23089 owner:81486 type:113238 object:weapon];
            void *ws=[self pointer8:22388 owner:113238 type:13823 object:spec];
            void *gs=[self pointer8:22198 owner:13823 type:47595 object:ws];float zero=0;
            BOOL (^specGuard)(void)=^BOOL{return guard() && [self pointer8:23089 owner:81486 type:113238 object:weapon]==spec && [self pointer8:22388 owner:113238 type:13823 object:spec]==ws && [self pointer8:22198 owner:13823 type:47595 object:ws]==gs;};
            okay=[self bytes8:b8a(&zero,4) field:22144 owner:47595 type:76277 object:gs feature:feature guard:specGuard];
            okay&=[self bytes8:b8a(&zero,4) field:22145 owner:47595 type:76277 object:gs feature:feature guard:specGuard];
        }
    }
    if(!okay)[self releaseFeature:feature];s.available=okay;s.active=okay;s.note=okay ? @"In Village angewandt und nativ zurückgelesen." : @"Wartet auf passende Village-Objekte bzw. die ausgerüstete Waffe.";return s;
}
- (NSString *)performOneShot:(RE2Feature)feature value:(double)value {
    if(![self local8])return @"Keine bestätigte lokale Village-Spielfigur.";
    if((NSInteger)feature==RE8MercGoal)return [self mercOpenGoal8];
    if((NSInteger)feature==RE8Unlock){
        void *manager=[self global8:727963 type:97524];
        void *list=[self pointer8:77701 owner:97524 type:5830 object:manager];
        NSMutableSet<NSNumber *> *hashes=[NSMutableSet new];
        const uint32_t lists[]={77666,77667,77669},listTypes[]={16320,20324,1870};
        const uint32_t idFields[]={77593,77629,77650},unitTypes[]={123160,127516,17504};
        for(NSValue *dataValue in [self list8:list type:5830 limit:256]){
            void *data=dataValue.pointerValue;
            for(NSUInteger kind=0;kind<3;kind++){
                void *units=[self pointer8:lists[kind] owner:104420 type:listTypes[kind] object:data];
                for(NSValue *unit in [self list8:units type:listTypes[kind] limit:4096]){
                    void *p=[_e8 field:idFields[kind] owner:unitTypes[kind] type:12387 object:unit.pointerValue size:4];
                    uint32_t hash=p ? n8a(p,0) : 0;if(hash)[hashes addObject:@(hash)];
                }
            }
        }
        BOOL (*opened)(void *,void *,uint32_t)=[_e8 method:398557 owner:97524];
        BOOL (*unlocked)(void *,void *,uint32_t)=[_e8 method:398558 owner:97524];
        void (*open)(void *,void *,uint32_t)=[_e8 method:398552 owner:97524];
        void (*unlock)(void *,void *,uint32_t)=[_e8 method:398553 owner:97524];
        if(!manager || !hashes.count || hashes.count>4096 || !opened || !unlocked || !open || !unlock)return @"Registrierte Bonusshop-Artikel nicht bestätigt.";
        NSUInteger changed=0,confirmed=0;
        for(NSNumber *entry in hashes){
            if(![self local8] || [self global8:727963 type:97524]!=manager || !_e8.threadContext)break;
            uint32_t hash=entry.unsignedIntValue;BOOL wasOpen=opened(_e8.threadContext,manager,hash);
            if(!_e8.threadContext)break;
            BOOL wasUnlocked=unlocked(_e8.threadContext,manager,hash);if(!_e8.threadContext)break;
            if(!wasOpen)open(_e8.threadContext,manager,hash);
            if(!wasUnlocked && _e8.threadContext)unlock(_e8.threadContext,manager,hash);
            if(!_e8.threadContext)break;
            BOOL nowOpen=opened(_e8.threadContext,manager,hash);if(!_e8.threadContext)break;
            BOOL nowUnlocked=nowOpen && unlocked(_e8.threadContext,manager,hash);if(!_e8.threadContext)break;
            if(nowOpen && nowUnlocked){confirmed++;if(!wasOpen || !wasUnlocked)changed++;}
        }
        // Native open/unlock only: no purchase, Has, DLC ownership or save-file
        // editing. This durable action runs solely after an explicit UI action.
        os_log(_log8,"RE8 bonus shop registered=%{public}lu changed=%{public}lu confirmed=%{public}lu",(unsigned long)hashes.count,(unsigned long)changed,(unsigned long)confirmed);
        return [NSString stringWithFormat:@"Bonusshop: %lu von %lu registrierten Sperren nativ aufgehoben (%lu geändert).",(unsigned long)confirmed,(unsigned long)hashes.count,(unsigned long)changed];
    }
    if((NSInteger)feature==RE8CP){
        void *manager=[self global8:727963 type:97524];
        int32_t (*get)(void *,void *)=[_e8 method:398534 owner:97524];void (*add)(void *,void *,int32_t)=[_e8 method:398549 owner:97524];
        if(!manager || !get || !add || !isfinite(value) || value<0 || value>9999999 || floor(value)!=value)return @"CP-Manager oder Wert nicht bestätigt.";
        int32_t before=get(_e8.threadContext,manager);if(!_e8.threadContext || before<0 || before>99999999)return @"CP-Ausgangswert nicht bestätigt.";
        add(_e8.threadContext,manager,(int32_t)value-before);BOOL okay=_e8.threadContext && get(_e8.threadContext,manager)==(int32_t)value;
        os_log(_log8,"RE8 CP before=%{public}d requested=%{public}d readback=%{public}d",before,(int32_t)value,okay);return okay ? @"CP nativ gesetzt." : @"CP-Rückleseprüfung fehlgeschlagen.";
    }
    if((NSInteger)feature==RE8Time){
        if([_e8 isObject:_core8 kindOf:75607])return [self adjustRoseTime8];
        BOOL rose=[_e8 isObject:_core8 kindOf:75607];
        void *manager=[self global8:rose ? 727921 : 728065 type:rose ? 33234 : 76042];
        void *data=[self pointer8:rose ? 77564 : 77851 owner:rose ? 33234 : 76042 type:rose ? 5030 : 14304 object:manager];
        void *p=[_e8 field:rose ? 77584 : 77890 owner:rose ? 5030 : 14304 type:76277 object:data size:4];float before=0,after=0;
        if(!p || !MTReadMemory(p,&before,4) || !isfinite(before) || before<0)return @"Gesamtspielzeit nicht bestätigt.";
        float next=fmaxf(0,before-3600);BOOL okay=MTWriteFloat(p,0,next) && MTReadMemory(p,&after,4) && after==next;
        if(okay){_timeVerifyStart8=CFAbsoluteTimeGetCurrent();_timeVerifyAt8=_timeVerifyStart8+2;_timeVerifyExpected8=next;_timeVerifyData8=data;_timeVerifyRose8=rose;_timeVerifyIdentity8=[_identity8 copy];}
        os_log(_log8,"RE8 total time rose=%{public}d before=%{public}.3f after=%{public}.3f readback=%{public}d",rose,before,after,okay);return okay ? @"Gesamtspielzeit um bis zu eine Stunde verringert." : @"Zeit-Rückleseprüfung fehlgeschlagen.";
    }
    if((NSInteger)feature==RE8Money){
        void *p=[_e8 field:23083 owner:102832 type:18821 object:_inventory8 size:4];
        if(!p || !isfinite(value) || value<0 || value>9999999 || floor(value)!=value)return @"Geldbestand oder Wert nicht bestätigt.";
        BOOL okay=MTWriteInt(p,0,(int32_t)value) && n8a(p,0)==(uint32_t)value;
        if(okay){_moneyBefore8=(int32_t)value;_moneyReady8=NO;}
        os_log(_log8,"RE8 money requested=%{public}d readback=%{public}d",(int32_t)value,okay);return okay ? @"Lei nativ gesetzt." : @"Geld-Rückleseprüfung fehlgeschlagen.";
    }return @"Diese Village-Einmalaktion ist noch nicht freigegeben.";
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {
    if(!_e8.isGameThread)return NO;
    // UI mouse is independent of Ethan/Rose/Mercenaries gameplay ownership.
    // Independently derived from Village Mouse wrappers and their native
    // Show/Clip/Absolute accessors, not from a different game's addresses.
    void *device=[_e8 singletonAt:0x10cfb8d38];const size_t offsets[]={0x160,0x161,0x163};const uint8_t values[]={1,0,1};
    if(_mouseOwned8 && (device!=_mouseDevice8 || !wanted)){
        BOOL okay=YES;if(device==_mouseDevice8)for(NSUInteger i=0;i<3;i++){uint8_t v=0;if(MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==values[i])okay&=MTWriteByte(device,offsets[i],_mouseBefore8[i]) && MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==_mouseBefore8[i];}
        _mouseOwned8=NO;os_log(_log8,"RE8 mouse released readback=%{public}d",okay);
    }
    if(!wanted || !device)return NO;BOOL first=!_mouseOwned8;
    if(first){for(NSUInteger i=0;i<3;i++)if(!MTReadMemory((uint8_t *)device+offsets[i],&_mouseBefore8[i],1) || _mouseBefore8[i]>1)return NO;_mouseDevice8=device;_mouseOwned8=YES;}
    uint8_t observed[3];for(NSUInteger i=0;i<3;i++)if(!MTReadMemory((uint8_t *)device+offsets[i],&observed[i],1) || observed[i]>1)return NO;
    if(!first)for(NSUInteger i=0;i<3;i++)if(observed[i]!=values[i])_mouseBefore8[i]=observed[i];
    BOOL okay=YES;for(NSUInteger i=0;i<3;i++){uint8_t v=0;okay&=MTWriteByte(device,offsets[i],values[i]) && MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==values[i];}
    if(first)os_log(_log8,"RE8 mouse acquired readback=%{public}d",okay);return okay;
}
@end
