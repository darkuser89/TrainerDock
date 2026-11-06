// SPDX-License-Identifier: GPL-3.0-only
#import "RE7Adapter.h"
#import "RE7Engine.h"
#import "RE7Ownership.h"
#import "RE7Features.h"
#import "RE7ScoreMath.h"
#import "RE7TwentyOne.h"
#import "RE2EffectLedger.h"
#import "MemoryAccess.h"
#import <os/log.h>
#include <math.h>
static uintptr_t p7a(const void *p,size_t offset){uintptr_t n=0;MTReadMemory((const uint8_t *)p+offset,&n,8);return n;}
static uint32_t n7a(const void *p,size_t offset){uint32_t n=0;MTReadMemory((const uint8_t *)p+offset,&n,4);return n;}
static NSData *b7a(const void *p,size_t n){return [NSData dataWithBytes:p length:n];}
@implementation RE7NativeAdapter {
    MTRE7Engine *_e7;RE2Owner *_owner7;
    void *_manager7,*_status7,*_damage7,*_health7,*_inventory7;
    NSMutableDictionary<NSNumber *,NSNumber *> *_wanted7;
    NSString *_identity7,*_scoreIdentity7;int32_t _scoreWave7,_scoreCount7,_scoreTotal7;float _scoreFactor7;CFAbsoluteTime _scoreNextCheck7;os_log_t _log7;BOOL _pump7;
    NSMutableDictionary<NSString *,RE7Owner *> *_enemyOwners7;
    NSMutableArray<NSValue *> *_enemyPending7;
    NSMutableSet<NSValue *> *_enemySeen7;
    CFAbsoluteTime _enemyNextScan7;
    uintptr_t _enemyMainScene7,_enemyCurrentScene7;
    NSUInteger _enemyVisited7;
    RE7Owner *_cardOwner7;void *_cardMaster7,*_cardManager7;
    BOOL _highlightApplied7;
    BOOL _mouseOwned7;void *_mouseDevice7;uint8_t _mouseBefore7[3];
    NSMutableSet<NSString *> *_notes7;
    void *_birthdayResumeWatch7,*_birthdayResumeTimer7;RE2Owner *_birthdayResumeOwner7;
}
- (instancetype)init {if((self=[super init])){_e7=(MTRE7Engine *)MTRE2Engine.shared;_wanted7=[NSMutableDictionary new];_notes7=[NSMutableSet new];_log7=os_log_create("local.mactrainer.re2","re7-effects");}return self;}
- (void)note7:(NSString *)note {
    if(_notes7.count<80 && ![_notes7 containsObject:note]){[_notes7 addObject:note];os_log(_log7,"RE7 binding %{public}@",note);}
}
- (void *)objectGetter:(uint32_t)index owner:(uint32_t)owner object:(void *)object {
    if(!_e7.isGameThread || ![_e7 isObject:object kindOf:owner])return NULL;
    void *(*get)(void *,void *)=[_e7 method:index owner:owner];return get ? get(_e7.threadContext,object) : NULL;
}
- (void *)component7:(uint32_t)type gameObject:(void *)go {
    if(!_e7.isGameThread || [_e7 typeOf:go]!=34333)return NULL;
    // Exact native get_Components and get_Chain use this intrusive list.
    // Read it without creating a temporary managed array or changing its
    // component reference counts. Every link must still name this GameObject.
    void *component=(void *)p7a(go,0x18),*found=NULL;NSMutableSet<NSValue *> *seen=[NSMutableSet new];
    for(NSUInteger i=0;component && i<512;i++){
        NSValue *key=[NSValue valueWithPointer:component];
        if([seen containsObject:key] || ![_e7 isObject:component kindOf:32277] || p7a(component,0x10)!=(uintptr_t)go)return NULL;
        [seen addObject:key];
        if([_e7 isObject:component kindOf:type]){if(found)return NULL;found=component;}
        component=(void *)p7a(component,0x18);
    }return component ? NULL : found;
}
- (void *)instance7:(uint32_t)i owner:(uint32_t)o type:(uint32_t)t {
    if(!_e7.isGameThread)return NULL;void *(*get)(void *)=[_e7 method:i owner:o];
    void *p=get ? get(_e7.threadContext) : NULL;return [_e7 isObject:p kindOf:t] ? p : NULL;
}
- (void *)pointerField7:(uint32_t)i owner:(uint32_t)o type:(uint32_t)t object:(void *)p {
    void *f=[_e7 field:i owner:o type:t object:p size:8];return f ? (void *)p7a(f,0) : NULL;
}
- (void *)localGO7 {
    // The exact GameManager.getPlayer wrapper reads this singleton's +0x88.
    // Check the same read-only chain first: calling that wrapper with an
    // absent startup singleton would raise a managed exception in the game.
    void *root=[_e7 singletonAt:0x10b3993c8];if([_e7 typeOf:root]==UINT32_MAX)return NULL;
    void *go=(void *)p7a(root,0x88);if([_e7 typeOf:go]!=34333 || !p7a(go,0x18))return NULL;
    return [self instance7:185924 owner:11603 type:34333]==go ? go : NULL;
}
- (void *)inventoryForGO7:(void *)go status:(void *)status {
    void *fromStatus=[self pointerField7:23951 owner:40739 type:34866 object:status];
    void *active=[self instance7:149571 owner:34866 type:34866];
    if(active && active==fromStatus)return active;
    void *manager=[self instance7:41892 owner:2753 type:43274];
    void *fromManager=[self pointerField7:9495 owner:43274 type:34866 object:manager];
    void *player=[self pointerField7:9497 owner:43274 type:34333 object:manager];
    [self note7:[NSString stringWithFormat:@"inventory ownership statusType=%u activeType=%u managerType=%u managerPlayerMatches=%d",[_e7 typeOf:fromStatus],[_e7 typeOf:active],[_e7 typeOf:fromManager],player==go]];
    return active && active==fromManager && player==go ? active : NULL;
}
- (BOOL)local7 {
    return _e7.isGameThread && _owner7.valid && [self localGO7]==_owner7.gameObject &&
        [self component7:40739 gameObject:_owner7.gameObject]==_status7 &&
        [self component7:5616 gameObject:_owner7.gameObject]==_damage7 &&
        [self pointerField7:11000 owner:38925 type:42267 object:_damage7]==_health7 &&
        [self inventoryForGO7:_owner7.gameObject status:_status7]==_inventory7;
}
- (BOOL)paused7 {
    BOOL (*get)(void *,void *)=[_e7 method:185862 owner:11603];return !get || ![_e7 isObject:_manager7 kindOf:11603] || get(_e7.threadContext,_manager7);
}
- (BOOL)bytes7:(NSData *)bytes field:(uint32_t)i ownerType:(uint32_t)o fieldType:(uint32_t)t object:(void *)object owner:(RE2Owner *)owner feature:(RE2Feature)feature guard:(BOOL (^)(void))guard {
    void *f=[_e7 field:i owner:o type:t object:object size:bytes.length];if(!f)return NO;
    RE2Owner *bindingOwner=[_e7 isObject:object kindOf:32277] ? [RE7Owner ownerForComponent:object engine:_e7] : owner;
    if(!bindingOwner.valid)return NO;
    return [self applyBytes:bytes object:object offset:(uint8_t *)f-(uint8_t *)object owner:bindingOwner global:NO feature:feature guard:^BOOL{return bindingOwner.valid && (!guard || guard());}];
}
- (NSArray<NSValue *> *)list7:(void *)list type:(uint32_t)type limit:(uint32_t)limit {
    if(![_e7 isObject:list kindOf:type]){[self note7:[NSString stringWithFormat:@"list rejected expected=%u actual=%u",type,[_e7 typeOf:list]]];return @[];}
    void *array=(void *)p7a(list,0x10);uint32_t count=n7a(list,0x18),capacity=n7a(array,0x1c);
    if([_e7 typeOf:array]==UINT32_MAX || count>limit || capacity>8192 || count>capacity){[self note7:[NSString stringWithFormat:@"list bounds expected=%u actual=%u array=%u count=%u capacity=%u",type,[_e7 typeOf:list],[_e7 typeOf:array],count,capacity]];return @[];}
    NSMutableArray *out=[NSMutableArray new];for(uint32_t i=0;i<count;i++){
        void *p=(void *)p7a(array,0x20+i*8);if([_e7 typeOf:p]!=UINT32_MAX)[out addObject:[NSValue valueWithPointer:p]];
    }return out;
}
- (NSArray<NSValue *> *)items7 {
    if(![self local7])return @[];NSMutableArray *items=[NSMutableArray new];
    void *list=[self objectGetter:149562 owner:34866 object:_inventory7];
    [self note7:[NSString stringWithFormat:@"inventory list actual=%u count=%u array=%u capacity=%u",[_e7 typeOf:list],n7a(list,0x18),[_e7 typeOf:(void *)p7a(list,0x10)],n7a((void *)p7a(list,0x10),0x1c)]];
    for(NSValue *entry in [self list7:list type:29537 limit:256]){
        void *p=entry.pointerValue;
        if([_e7 typeOf:p]==16866){
            void *ownerGO=[self pointerField7:9481 owner:16866 type:34333 object:p];
            p=[self pointerField7:9482 owner:16866 type:41133 object:p];
            if([self component7:41133 gameObject:ownerGO]!=p){[self note7:@"inventory ItemInfo owner does not match original item"];continue;}
        }
        if([_e7 typeOf:p]==34333)p=[self component7:41133 gameObject:p];
        if([_e7 isObject:p kindOf:41133]){NSValue *item=[NSValue valueWithPointer:p];if(![items containsObject:item])[items addObject:item];}
        else [self note7:[NSString stringWithFormat:@"inventory entry type=%u",[_e7 typeOf:entry.pointerValue]]];
    }return items;
}
- (NSString *)string7:(void *)p {
    uint32_t n=n7a(p,0x10);if([_e7 typeOf:p]!=42707 || n>128)return nil;unichar chars[128];
    return MTReadMemory((uint8_t *)p+0x14,chars,n*2) ? [NSString stringWithCharacters:chars length:n] : nil;
}
- (void)diagnostic7 {
    float hp=0,max=0;MTReadMemory((uint8_t *)_health7+0x10,&max,4);MTReadMemory((uint8_t *)_health7+0x14,&hp,4);
    [self note7:[NSString stringWithFormat:@"local health=%g maximum=%g inventoryType=%u",hp,max,[_e7 typeOf:_inventory7]]];
    for(NSValue *p in [self items7]){
        void *item=p.pointerValue;if(![_e7 isObject:item kindOf:41133])continue;
        void *data=[self objectGetter:150659 owner:41133 object:item],*category=[_e7 field:33290 owner:33215 type:2206 object:data size:4];
        int32_t (*get)(void *,void *)=[_e7 method:150684 owner:41133],(*limit)(void *,void *)=[_e7 method:150683 owner:41133];
        void *(*id7)(void *,void *,BOOL)=[_e7 method:150682 owner:41133];
        [self note7:[NSString stringWithFormat:@"inventory item=%@ category=%u count=%d maximum=%d",id7 ? [self string7:id7(_e7.threadContext,item,YES)] : @"?",category ? n7a(category,0) : UINT32_MAX,get ? get(_e7.threadContext,item) : -1,limit ? limit(_e7.threadContext,item) : -1]];
    }
}
- (RE2GameContext *)captureContext {
    RE2GameContext *s=[RE2GameContext new];if(!_e7.identified){s.note=_e7.failure;return s;}
    if(!_e7.isGameThread){s.kind=RE2SessionLoading;s.identity=@"re7/startup";s.note=@"RE7 lädt · wartet auf die vollständig geladene Spielfigur.";return s;}
    if(!_pump7){__weak RE7NativeAdapter *weakSelf=self;[_e7 setContinuousWork:^{[weakSelf frame7];}];_pump7=YES;}
    void *manager=[self instance7:15608 owner:9416 type:11603];
    void *chapterField=[_e7 field:43680 owner:11603 type:11825 object:manager size:4];int32_t ch=-1;if(chapterField)MTReadMemory(chapterField,&ch,4);
    BOOL playable=ch==2 || (ch>=4 && ch<=14) || (ch>=22 && ch<=25) || (ch>=29 && ch<=32) || ch==34 || ch==35 || ch==37;
    void *go=playable ? [self localGO7] : NULL;
    void *status=[self component7:40739 gameObject:go],*damage=[self component7:5616 gameObject:go];
    void *hp=[self pointerField7:11000 owner:38925 type:42267 object:damage];
    void *inventory=[self inventoryForGO7:go status:status];
    // No managed ownership changes until the complete local gameplay graph
    // exists. Title/menu preview GameObjects are never retained as players.
    if(![_e7 isObject:status kindOf:40739] || ![_e7 isObject:damage kindOf:5616] || [_e7 typeOf:hp]!=42267 || ![_e7 isObject:inventory kindOf:34866]){
        [self note7:[NSString stringWithFormat:@"waiting chapter=%d go=%u status=%u damage=%u health=%u inventory=%u",ch,[_e7 typeOf:go],[_e7 typeOf:status],[_e7 typeOf:damage],[_e7 typeOf:hp],[_e7 typeOf:inventory]]];
        s.kind=RE2SessionLoading;s.identity=@"re7/loading";s.note=@"Wartet auf die lokale RE7-Spielfigur.";return s;
    }
    [self note7:[NSString stringWithFormat:@"gameplay graph ready chapter=%d",ch]];
    RE2Owner *owner=[RE7Owner ownerForGameObject:go engine:_e7];
    if(!owner.valid){s.kind=RE2SessionLoading;s.identity=@"re7/loading";s.note=@"Lokaler RE7-Besitzer noch nicht bestätigt.";return s;}
    [owner retainPayload:status];[owner retainPayload:damage];[owner retainPayload:hp];[owner retainPayload:inventory];[owner retainPayload:manager];
    _owner7=owner;_manager7=manager;_status7=status;_damage7=damage;_health7=hp;_inventory7=inventory;
    s.kind=RE2SessionSolo;s.identity=[NSString stringWithFormat:@"re7/%@/%d/%p",owner.identity,ch,inventory];s.note=@"RE7 · lokale Spielfigur und Spielthread bestätigt.";
    if(![_identity7 isEqual:s.identity]){_identity7=s.identity;[self note7:[NSString stringWithFormat:@"local owner confirmed chapter=%d",ch]];[self diagnostic7];}
    return s;
}
- (void)releaseEffects {_scoreIdentity7=nil;[_wanted7 removeAllObjects];_enemyPending7=nil;_enemySeen7=nil;[_enemyOwners7 removeAllObjects];_enemyNextScan7=0;[super releaseEffects];}
- (void)frame7 {
    if(_mouseOwned7)[self setOverlayInteraction:YES];
    [self resumeBirthday7];
    if(![self local7]){[self releaseEffects];return;}
    for(NSNumber *feature in _wanted7.allKeys.copy)[self applyFeature:feature.integerValue wanted:YES value:_wanted7[feature].doubleValue];
}
- (BOOL)inventory7:(RE2Feature)feature {
    BOOL ammo=(NSInteger)feature==RE7Ammo,okay=YES;NSUInteger targets=0;
    for(NSValue *p in [self items7]){
        void *item=p.pointerValue;if(![_e7 isObject:item kindOf:41133])continue;
        void *data=[self objectGetter:150659 owner:41133 object:item],*category=[_e7 field:33290 owner:33215 type:2206 object:data size:4];
        if(!category)continue;uint32_t cat=n7a(category,0);
        // Exact ItemCategoryType literals: Shell=2, Drug=3, Material=7,
        // StackWeapon=8, SupplyBox=11. Keys, files and maps are excluded.
        if(ammo ? !(cat==2 || cat==8) : !(cat==0 || cat==2 || cat==3 || cat==7 || cat==8 || cat==11))continue;
        int32_t (*get)(void *,void *)=[_e7 method:150684 owner:41133],(*max)(void *,void *)=[_e7 method:150683 owner:41133];
        void (*set)(void *,void *,int32_t)=[_e7 method:150687 owner:41133];
        if(!get || !max || !set)continue;int32_t before=get(_e7.threadContext,item),n=max(_e7.threadContext,item);
        if(before<=0 || n<=1 || n>9999 || before>n)continue;
        RE2Owner *owner=[RE7Owner ownerForComponent:item engine:_e7];if(!owner.valid)continue;
        BOOL (^guard)(void)=^BOOL{return owner.valid && [_e7 isObject:item kindOf:41133] && [[self items7] containsObject:[NSValue valueWithPointer:item]];};
        okay&=[self applyNativeBytes:b7a(&n,4) object:item tag:150684 owner:owner feature:feature guard:guard read:^NSData *{int32_t v=get(_e7.threadContext,item);return b7a(&v,4);} write:^(NSData *bytes){int32_t v=0;[bytes getBytes:&v length:4];set(_e7.threadContext,item,v);}];targets++;
    }return targets && okay;
}
- (BOOL)reload7:(RE2Feature)feature {
    void *controller=[self component7:1107 gameObject:_owner7.gameObject];
    void *weapon=[self pointerField7:23843 owner:1107 type:2310 object:controller];
    if(![_e7 isObject:weapon kindOf:2310] || [self objectGetter:35042 owner:39702 object:weapon]!=_owner7.gameObject)return NO;
    BOOL (*equipped)(void *,void *)=[_e7 method:35038 owner:39702];
    if(!equipped || !equipped(_e7.threadContext,weapon))return NO;
    RE2Owner *owner=[RE7Owner ownerForComponent:weapon engine:_e7];if(!owner.valid)return NO;
    int32_t (*get)(void *,void *)=[_e7 method:150578 owner:2310],(*max)(void *,void *)=[_e7 virtualMethod:150577 owner:2310 object:weapon];
    void (*set)(void *,void *,int32_t)=[_e7 method:150579 owner:2310];if(!get || !set || !max)return NO;
    int32_t n=max(_e7.threadContext,weapon),before=get(_e7.threadContext,weapon);if(n<=0 || n>10000 || before<0 || before>n)return NO;
    BOOL (^guard)(void)=^BOOL{return owner.valid && [self local7] && [self pointerField7:23843 owner:1107 type:2310 object:[self component7:1107 gameObject:_owner7.gameObject]]==weapon && [self objectGetter:35042 owner:39702 object:weapon]==_owner7.gameObject;};
    return [self applyNativeBytes:b7a(&n,4) object:weapon tag:150578 owner:owner feature:feature guard:guard read:^NSData *{int32_t v=get(_e7.threadContext,weapon);return b7a(&v,4);} write:^(NSData *bytes){int32_t v=0;[bytes getBytes:&v length:4];set(_e7.threadContext,weapon,v);}];
}
- (void)refreshEnemies7 {
    if(!_enemyOwners7)_enemyOwners7=[NSMutableDictionary new];
    for(NSString *key in _enemyOwners7.allKeys.copy)if(!_enemyOwners7[key].valid)[_enemyOwners7 removeObjectForKey:key];
    void *main=[self instance7:292776 owner:19265 type:12371],*current=[self instance7:292777 owner:19265 type:12371];
    if(_enemyMainScene7!=(uintptr_t)main || _enemyCurrentScene7!=(uintptr_t)current){
        _enemyMainScene7=(uintptr_t)main;_enemyCurrentScene7=(uintptr_t)current;_enemyPending7=nil;_enemySeen7=nil;_enemyNextScan7=0;[_enemyOwners7 removeAllObjects];
    }
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
    if(!_enemyPending7.count && now>=_enemyNextScan7){
        _enemyPending7=[NSMutableArray new];_enemySeen7=[NSMutableSet new];_enemyVisited7=0;_enemyNextScan7=now+1;
        for(NSValue *p in @[[NSValue valueWithPointer:main],[NSValue valueWithPointer:current]]){
            void *first=[self objectGetter:187702 owner:12371 object:p.pointerValue];
            if([_e7 isObject:first kindOf:38113])[_enemyPending7 addObject:[NSValue valueWithPointer:first]];
        }
        // Character registrations may refer to a prefab root while the damage
        // controller belongs to a child. Walk each registered hierarchy too.
        void *manager=[self instance7:239463 owner:29063 type:22503];
        void *units=[self pointerField7:55394 owner:22503 type:16863 object:manager];
        NSArray *entries=[self list7:units type:16863 limit:512];
        for(NSValue *p in entries){
            void *go=[self pointerField7:55396 owner:33439 type:34333 object:p.pointerValue];
            void *transform=[self component7:38113 gameObject:go];
            if(transform)[_enemyPending7 addObject:[NSValue valueWithPointer:transform]];
        }
        [self note7:[NSString stringWithFormat:@"enemy sources main=%u current=%u registered=%lu treeGetters=%d/%d",[_e7 typeOf:main],[_e7 typeOf:current],(unsigned long)entries.count,[_e7 method:196288 owner:38113]!=NULL,[_e7 method:196289 owner:38113]!=NULL]];
    }
    // Incremental native hierarchy traversal, with no managed arrays, no
    // reference-count changes, and a finite per-frame and per-pass budget.
    for(NSUInteger n=0;n<32 && _enemyPending7.count && _enemyVisited7<8192;n++){
        NSValue *entry=_enemyPending7.lastObject;[_enemyPending7 removeLastObject];
        if([_enemySeen7 containsObject:entry])continue;[_enemySeen7 addObject:entry];_enemyVisited7++;
        void *transform=entry.pointerValue;if(![_e7 isObject:transform kindOf:38113])continue;
        void *go=[self objectGetter:224206 owner:32277 object:transform];
        if([_e7 typeOf:go]!=34333 || [self component7:38113 gameObject:go]!=transform)continue;
        void *next=[self objectGetter:196289 owner:38113 object:transform],*child=[self objectGetter:196288 owner:38113 object:transform];
        if([_e7 isObject:next kindOf:38113] && next!=transform)[_enemyPending7 addObject:[NSValue valueWithPointer:next]];
        if([_e7 isObject:child kindOf:38113] && child!=transform)[_enemyPending7 addObject:[NSValue valueWithPointer:child]];
        if(go==_owner7.gameObject)continue;
        void *enemy=[self component7:27862 gameObject:go];if(!enemy)continue;
        RE7Owner *owner=[RE7Owner ownerForComponent:enemy engine:_e7];if(!owner.valid || owner.gameObject!=go)continue;
        NSString *key=[owner.identity stringByAppendingFormat:@"/%p",enemy];if(_enemyOwners7.count<256)_enemyOwners7[key]=owner;
    }
    if(_enemyVisited7>=8192)[_enemyPending7 removeAllObjects];
    if(!_enemyPending7.count && _enemyVisited7)[self note7:[NSString stringWithFormat:@"enemy hierarchy visited=%lu owners=%lu",(unsigned long)_enemyVisited7,(unsigned long)_enemyOwners7.count]];
}
- (BOOL)enemies7:(RE2Feature)feature {
    [self refreshEnemies7];NSUInteger targets=0;BOOL okay=YES;
    for(RE7Owner *owner in _enemyOwners7.allValues.copy){
        void *enemy=owner.component;if(!owner.valid || ![_e7 isObject:enemy kindOf:27862])continue;
        void *hp=[self pointerField7:11000 owner:38925 type:42267 object:enemy];float current=0,max=0;
        void *a=[_e7 field:10924 owner:42267 type:25922 object:hp size:4],*b=[_e7 field:10923 owner:42267 type:25922 object:hp size:4];
        if(!a || !b || !MTReadMemory(a,&current,4) || !MTReadMemory(b,&max,4) || !isfinite(current) || !isfinite(max) || current<=0 || current>max || max>100000000)continue;
        float n=fminf(current,1);okay&=[self bytes7:b7a(&n,4) field:10924 ownerType:42267 fieldType:25922 object:hp owner:owner feature:feature guard:^BOOL{return owner.valid && [self pointerField7:11000 owner:38925 type:42267 object:enemy]==hp;}];targets++;
    }return targets && okay;
}
- (void *)nightmare7 {
    void *manager=[self instance7:380874 owner:3399 type:16193];
    int32_t (*wave)(void *,void *)=[_e7 method:381752 owner:16193];
    BOOL (*enabled)(void *,void *)=[_e7 method:224226 owner:2996];
    RE2Owner *owner=[RE7Owner ownerForComponent:manager engine:_e7];
    int32_t n=owner.valid && wave && enabled && enabled(_e7.threadContext,manager) ? wave(_e7.threadContext,manager) : 0;
    return n>=1 && n<=5 ? manager : NULL;
}
- (BOOL)score7:(RE2Feature)feature {
    void *manager=[self nightmare7];if(!manager)return NO;
    int32_t (*wave)(void *,void *)=[_e7 method:381752 owner:16193];
    int32_t (*total)(void *,void *,int32_t)=[_e7 method:381778 owner:16193];
    void *junk=[self instance7:354314 owner:42804 type:22894];
    int32_t (*count)(void *,void *)=[_e7 method:354347 owner:22894];
    void *parameter=[self pointerField7:120512 owner:16193 type:34232 object:manager];
    RE2Owner *owner=[RE7Owner ownerForComponent:manager engine:_e7];
    if(!owner.valid || !wave || !total || !junk || !count || ![_e7 isObject:parameter kindOf:34232])return NO;
    int32_t w=wave(_e7.threadContext,manager),parts=count(_e7.threadContext,junk);
    if(parts<=0 || parts>9999999)return NO;
    void *field=[_e7 field:56981 owner:34232 type:25922 object:parameter size:4];float old=0;
    if(!field || !MTReadMemory(field,&old,4) || !isfinite(old) || old<0 || old>10000000)return NO;
    BOOL changed=![_scoreIdentity7 isEqual:owner.identity] || _scoreWave7!=w || _scoreCount7!=parts;
    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
    // Bound failed retries too; the result getter constructs managed lists.
    if(!changed && _scoreTotal7<999999 && now<_scoreNextCheck7)return NO;
    BOOL (^guard)(void)=^BOOL{
        // Original ownership remains valid after a wave or scrap-count change.
        return owner.valid && [self instance7:380874 owner:3399 type:16193]==manager &&
            [self pointerField7:120512 owner:16193 type:34232 object:manager]==parameter;
    };
    BOOL (^apply)(float)=^BOOL(float factor){return [self bytes7:b7a(&factor,4) field:56981 ownerType:34232 fieldType:25922 object:parameter owner:owner feature:feature guard:guard];};
    if(changed || _scoreTotal7<999999){
        _scoreIdentity7=owner.identity;_scoreWave7=w;_scoreCount7=parts;_scoreNextCheck7=now+0.5;_scoreTotal7=0;
        int32_t before=total(_e7.threadContext,manager,w);
        float probe=1000000.0f/(float)parts;
        if(probe==old)probe=old>500000 ? old*0.5f : old+fmaxf(old,1);
        if(!apply(probe))return NO;
        int32_t sampled=total(_e7.threadContext,manager,w);
        float factor=MTRE7ScoreFactor(old,probe,before,sampled);
        if(!isfinite(factor) || !apply(factor))return NO;
        _scoreFactor7=factor;_scoreTotal7=total(_e7.threadContext,manager,w);
        os_log(_log7,"RE7 nightmare score wave=%{public}d scraps=%{public}d original=%{public}g before=%{public}d probe=%{public}g sampled=%{public}d factor=%{public}g total=%{public}d confirmed=%{public}d",w,parts,old,before,probe,sampled,factor,_scoreTotal7,_scoreTotal7>=999999);
    }else{
        if(!apply(_scoreFactor7))return NO;
        if(now>=_scoreNextCheck7){_scoreTotal7=total(_e7.threadContext,manager,w);_scoreNextCheck7=now+0.5;}
    }
    return _scoreTotal7>=999999;
}
- (void)releaseFeature:(RE2Feature)feature {
    [super releaseFeature:feature];
    if((NSInteger)feature==RE7Highlight && _highlightApplied7){_highlightApplied7=NO;os_log(_log7,"RE7 highlights released; original visibility and clock fields restored where still owned");}
    if((NSInteger)feature==RE7Always21){
        void *master=_cardMaster7;RE7Owner *owner=_cardOwner7;
        if(owner.valid && [self instance7:348054 owner:28372 type:2035]==_cardManager7 && [self pointerField7:82031 owner:2035 type:39359 object:_cardManager7]==master){
            void (*refresh)(void *,void *)=[_e7 method:203725 owner:39359];
            int32_t (*sum)(void *,void *,int32_t,BOOL)=[_e7 method:203724 owner:39359];
            if(refresh)refresh(_e7.threadContext,master);
            if(sum)os_log(_log7,"RE7 21 released total=%{public}d",sum(_e7.threadContext,master,2,NO));
        }
        _cardOwner7=nil;_cardMaster7=NULL;_cardManager7=NULL;
    }
}
- (BOOL)twentyOne7:(RE2Feature)feature {
    int32_t chapter=(int32_t)n7a([_e7 field:43680 owner:11603 type:11825 object:_manager7 size:4],0);
    if(chapter!=30)return NO;
    void *manager=[self instance7:348054 owner:28372 type:2035];
    RE7Owner *managerOwner=[RE7Owner ownerForComponent:manager engine:_e7];
    void *master=[self pointerField7:82031 owner:2035 type:39359 object:manager];
    RE7Owner *owner=[RE7Owner ownerForComponent:master engine:_e7];
    void *player=[self pointerField7:47862 owner:39359 type:34333 object:master];
    [self note7:[NSString stringWithFormat:@"21 graph manager=%u master=%u playerMatches=%d",[_e7 typeOf:manager],[_e7 typeOf:master],player==_owner7.gameObject]];
    if(!managerOwner.valid || !owner.valid || player!=_owner7.gameObject)return NO;
    void *deck=[self pointerField7:47845 owner:39359 type:37766 object:master],*hand=[self pointerField7:47848 owner:39359 type:37766 object:master];
    NSArray<NSValue *> *cards=[self list7:deck type:37766 limit:11],*held=[self list7:hand type:37766 limit:11];
    int32_t (*sum)(void *,void *,int32_t,BOOL)=[_e7 method:203724 owner:39359];
    void (*refresh)(void *,void *)=[_e7 method:203725 owner:39359];
    if(cards.count!=11 || !held.count || !sum || !refresh)return NO;
    int32_t numbers[11],planned[11],expected=0;uint16_t mask=0;
    for(NSUInteger i=0;i<11;i++){
        void *card=cards[i].pointerValue,*n=[_e7 field:47705 owner:16352 type:6395 object:card size:4];
        void *pos=[_e7 field:47706 owner:16352 type:34026 object:card size:4],*removed=[_e7 field:47708 owner:16352 type:41600 object:card size:1];uint8_t gone=0;
        if(!n || !pos || !removed || !MTReadMemory(n,&numbers[i],4) || !MTReadMemory(removed,&gone,1) || gone>1)return NO;
        BOOL inHand=[held containsObject:cards[i]];
        if(inHand && !gone){if(n7a(pos,0)!=2)return NO;mask|=1u<<i;expected+=numbers[i];}
    }
    for(NSValue *p in held)if(![cards containsObject:p])return NO;
    int32_t before=sum(_e7.threadContext,master,2,NO);
    if(before!=expected || !MTRE7PlanTwentyOne(numbers,mask,planned)){
        [self note7:[NSString stringWithFormat:@"21 hand waiting count=%lu native=%d model=%d",(unsigned long)held.count,before,expected]];return NO;
    }
    BOOL first=_cardMaster7!=master || !_cardOwner7.valid,changed=memcmp(numbers,planned,sizeof(numbers))!=0,okay=YES;
    _cardOwner7=owner;_cardMaster7=master;_cardManager7=manager;
    for(NSUInteger i=0;i<11 && okay;i++){
        NSValue *entry=cards[i];void *card=entry.pointerValue;int32_t n=planned[i];
        okay=[self bytes7:b7a(&n,4) field:47705 ownerType:16352 fieldType:6395 object:card owner:owner feature:feature guard:^BOOL{
            return owner.valid && managerOwner.valid && [self instance7:348054 owner:28372 type:2035]==manager &&
                [self pointerField7:82031 owner:2035 type:39359 object:manager]==master &&
                [self pointerField7:47845 owner:39359 type:37766 object:master]==deck && [[self list7:deck type:37766 limit:11] containsObject:entry];
        }];
    }
    int32_t after=okay ? sum(_e7.threadContext,master,2,NO) : -1;
    if(okay && changed)refresh(_e7.threadContext,master);
    if(first || changed || !okay)os_log(_log7,"RE7 21 hand count=%{public}d before=%{public}d after=%{public}d changed=%{public}d readback=%{public}d",__builtin_popcount(mask),before,after,changed,okay && after==21);
    return okay && after==21;
}
- (BOOL)oxygen7:(RE2Feature)feature {
    void *manager=[self instance7:114438 owner:23139 type:36534];
    BOOL (*ingame)(void *,void *)=[_e7 method:119600 owner:36534];
    void *air=[self component7:38082 gameObject:_owner7.gameObject];
    RE2Owner *owner=[RE7Owner ownerForComponent:air engine:_e7];
    if(!manager || !ingame || !ingame(_e7.threadContext,manager) || !owner.valid || owner.gameObject!=_owner7.gameObject)return NO;
    uint8_t yes=1;BOOL (^guard)(void)=^BOOL{return owner.valid && [self instance7:114438 owner:23139 type:36534]==manager && ingame(_e7.threadContext,manager);};
    BOOL okay=[self bytes7:b7a(&yes,1) field:28571 ownerType:36534 fieldType:41600 object:manager owner:owner feature:feature guard:guard];
    BOOL (*empty)(void *,void *)=[_e7 method:158619 owner:38082];
    return okay && empty && !empty(_e7.threadContext,air);
}
- (void)resumeBirthday7 {
    if(!_birthdayResumeOwner7)return;
    RE2Owner *owner=_birthdayResumeOwner7;void *watch=_birthdayResumeWatch7,*timer=_birthdayResumeTimer7;
    BOOL (*playing)(void *)=[_e7 method:347785 owner:13888];
    BOOL (*running)(void *,void *)=[_e7 method:116895 owner:5062];
    void (*start)(void *,void *)=[_e7 method:116890 owner:5062];
    BOOL valid=owner.valid && playing && running && start && playing(_e7.threadContext) && [self instance7:347788 owner:13888 type:18083]==timer && [self pointerField7:47215 owner:18083 type:5062 object:timer]==watch;
    if(valid && [self paused7])return;
    if(valid && !running(_e7.threadContext,watch)){start(_e7.threadContext,watch);os_log(_log7,"RE7 birthday deferred resume readback=%{public}d",running(_e7.threadContext,watch));}
    _birthdayResumeOwner7=nil;_birthdayResumeWatch7=NULL;_birthdayResumeTimer7=NULL;
}
- (BOOL)birthday7:(RE2Feature)feature {
    void *manager=[self instance7:347758 owner:16397 type:13888];
    BOOL (*playing)(void *)=[_e7 method:347785 owner:13888];
    void *timer=[self instance7:347788 owner:13888 type:18083];
    if(!manager || !playing || !playing(_e7.threadContext) || [_e7 typeOf:timer]!=18083)return NO;
    void *a=[_e7 field:47218 owner:18083 type:20897 object:timer size:8];int64_t remaining=0;if(!a || !MTReadMemory(a,&remaining,8) || remaining<=0)return NO;
    void *watch=[self pointerField7:47215 owner:18083 type:5062 object:timer];if([_e7 typeOf:watch]!=5062)return NO;
    RE2Owner *owner=[RE7Owner ownerForComponent:manager engine:_e7];if(!owner.valid)return NO;
    BOOL (*running)(void *,void *)=[_e7 method:116895 owner:5062];
    void (*start)(void *,void *)=[_e7 method:116890 owner:5062],(*stop)(void *,void *)=[_e7 method:116892 owner:5062];
    if(!running || !start || !stop)return NO;
    // Wait for a running round before capturing a baseline. A menu-owned stop
    // must not become this cheat's original running state.
    if(![self baselineForNativeObject:watch tag:116895 feature:feature] && ([self paused7] || !running(_e7.threadContext,watch)))return NO;
    [owner retainPayload:timer];[owner retainPayload:watch];uint8_t no=0;
    BOOL (^guard)(void)=^BOOL{return owner.valid && playing(_e7.threadContext) && [self instance7:347788 owner:13888 type:18083]==timer && [self pointerField7:47215 owner:18083 type:5062 object:timer]==watch;};
    return [self applyNativeBytes:b7a(&no,1) object:watch tag:116895 owner:owner feature:feature guard:guard read:^NSData *{uint8_t v=running(_e7.threadContext,watch);return b7a(&v,1);} write:^(NSData *bytes){
        uint8_t v=0;[bytes getBytes:&v length:1];
        if(v && [self paused7]){_birthdayResumeOwner7=owner;_birthdayResumeWatch7=watch;_birthdayResumeTimer7=timer;return;}
        if(v)start(_e7.threadContext,watch);else {if(_birthdayResumeWatch7==watch)_birthdayResumeOwner7=nil;stop(_e7.threadContext,watch);}
    }];
}
- (RE2FeatureState *)applyFeature:(RE2Feature)feature wanted:(BOOL)wanted value:(double)value {
    RE2FeatureState *s=[RE2FeatureState new];const RE2FeatureInfo *info=RE7FeatureInfoAt(feature);if(!info)return s;
    s.wanted=wanted;s.value=value;
    if(!wanted){
        BOOL wasWanted=_wanted7[@(feature)]!=nil;[_wanted7 removeObjectForKey:@(feature)];[self releaseFeature:feature];
        if(wasWanted && (NSInteger)feature==RE7Score){
            void *manager=[self nightmare7];int32_t (*wave)(void *,void *)=[_e7 method:381752 owner:16193],(*total)(void *,void *,int32_t)=[_e7 method:381778 owner:16193];
            if(manager && wave && total)os_log(_log7,"RE7 nightmare score released total=%{public}d",total(_e7.threadContext,manager,wave(_e7.threadContext,manager)));
            _scoreIdentity7=nil;
        }
        s.available=YES;s.note=@"Aus.";return s;
    }
    if(info->oneShot){s.available=YES;s.note=@"Einmalaktion bereit.";return s;}
    if(![self local7] || !isfinite(value)){[self releaseFeature:feature];s.note=@"Wartet auf lokale RE7-Daten.";return s;}
    _wanted7[@(feature)]=@(value);BOOL okay=NO;RE2Owner *owner=_owner7;void *hp=_health7,*manager=_manager7;
    if((NSInteger)feature==RE7Health){
        float current=0,max=0;void *a=[_e7 field:10924 owner:42267 type:25922 object:hp size:4],*b=[_e7 field:10923 owner:42267 type:25922 object:hp size:4];
        if(a && b && MTReadMemory(a,&current,4) && MTReadMemory(b,&max,4) && isfinite(current) && isfinite(max) && current>0 && max>0 && current<=max && max<=1000000)
            okay=[self bytes7:b7a(&max,4) field:10924 ownerType:42267 fieldType:25922 object:hp owner:owner feature:feature guard:^BOOL{return owner.valid && [self pointerField7:11000 owner:38925 type:42267 object:_damage7]==hp;}];
    }else if((NSInteger)feature==RE7Ammo || (NSInteger)feature==RE7Items)okay=[self inventory7:feature];
    else if((NSInteger)feature==RE7NoReload)okay=[self reload7:feature];
    else if((NSInteger)feature==RE7Highlight){
        if([self paused7]){[self releaseFeature:feature];s.available=YES;s.note=@"Markierungen pausieren im Spielmenü.";return s;}
        uint8_t yes=1,no=0;float elapsed=0,maximum=600,range=1000000;
        BOOL (^guard)(void)=^BOOL{return owner.valid && [self instance7:15608 owner:9416 type:11603]==manager;};
        // Exact Mac megusuriUpdate starts by clearing IsNowMegusuriDisp.
        // MegusuriTime is ELAPSED: 600 there caused immediate expiry against
        // MegusuriMaxTime. The skill flag prevents native elapsed-time advance.
        // Keep the original clock/skill/range/visibility values in the ledger.
        okay=[self bytes7:b7a(&maximum,4) field:43784 ownerType:11603 fieldType:25922 object:manager owner:owner feature:feature guard:guard];
        okay&=[self bytes7:b7a(&elapsed,4) field:43783 ownerType:11603 fieldType:25922 object:manager owner:owner feature:feature guard:guard];
        okay&=[self bytes7:b7a(&no,1) field:43785 ownerType:11603 fieldType:41600 object:manager owner:owner feature:feature guard:guard];
        okay&=[self bytes7:b7a(&yes,1) field:43782 ownerType:11603 fieldType:41600 object:manager owner:owner feature:feature guard:guard];
        okay&=[self bytes7:b7a(&yes,1) field:43781 ownerType:11603 fieldType:41600 object:manager owner:owner feature:feature guard:guard];
        okay&=[self bytes7:b7a(&range,4) field:43786 ownerType:11603 fieldType:25922 object:manager owner:owner feature:feature guard:guard];
        okay&=[self bytes7:b7a(&yes,1) field:43791 ownerType:11603 fieldType:41600 object:manager owner:owner feature:feature guard:guard];
        if(okay && !_highlightApplied7){_highlightApplied7=YES;os_log(_log7,"RE7 highlights applied nativeDisplay=1 elapsed=0 maximum=600 skill=1 readback=1");}
    }else if((NSInteger)feature==RE7SuperSpeed || (NSInteger)feature==RE7SlowMotion){
        if([self paused7]){[self releaseFeature:feature];s.available=YES;s.note=@"Pausiert im Spielmenü.";return s;}
        if((NSInteger)feature==RE7SuperSpeed && _wanted7[@(RE7SlowMotion)]){[self releaseFeature:feature];s.available=YES;s.note=@"Zeitlupe hat Vorrang.";return s;}
        if((NSInteger)feature==RE7SlowMotion)[self releaseFeature:(RE2Feature)RE7SuperSpeed];
        void *app=[_e7 singletonAt:0x108d16d00];float baseline=0;NSData *base=[self baselineForObject:app offset:0x248 feature:feature];
        if(base)[base getBytes:&baseline length:4];else MTReadMemory((uint8_t *)app+0x248,&baseline,4);
        float n=baseline*(float)value;if(value>=info->minimum && value<=info->maximum && isfinite(baseline) && baseline>0 && baseline<=10)
            okay=[self applyBytes:b7a(&n,4) object:app offset:0x248 owner:nil global:YES feature:feature guard:^BOOL{return [_e7 singletonAt:0x108d16d00]==app;}];
    }else if((NSInteger)feature==RE7PlayerSpeed && value>=0.25 && value<=3){
        if([self paused7]){[self releaseFeature:feature];s.available=YES;s.note=@"Pausiert im Spielmenü.";return s;}
        void *movement=[self component7:24443 gameObject:owner.gameObject];RE2Owner *moveOwner=[RE7Owner ownerForComponent:movement engine:_e7];okay=moveOwner.valid;NSUInteger movingFields=0;
        for(uint32_t fid=25391;fid<=25397 && okay;fid++){
            void *a=[_e7 field:fid owner:24443 type:25922 object:movement size:4];float baseline=0;
            NSData *base=a ? [self baselineForObject:movement offset:(uint8_t *)a-(uint8_t *)movement feature:feature] : nil;
            if(base)[base getBytes:&baseline length:4];else if(a)MTReadMemory(a,&baseline,4);
            if(baseline>0)movingFields++;float n=baseline*(float)value;okay=isfinite(baseline) && baseline>=0 && baseline<=100 && [self bytes7:b7a(&n,4) field:fid ownerType:24443 fieldType:25922 object:movement owner:moveOwner feature:feature guard:^BOOL{return moveOwner.valid;}];
        }okay=okay && movingFields>0;
    }else if((NSInteger)feature==RE7OneHit)okay=[self enemies7:feature];
    else if((NSInteger)feature==RE7Score)okay=[self score7:feature];
    else if((NSInteger)feature==RE7Oxygen)okay=[self oxygen7:feature];
    else if((NSInteger)feature==RE7BirthdayTimer)okay=[self birthday7:feature];
    else if((NSInteger)feature==RE7Always21)okay=[self twentyOne7:feature];
    if(!okay)[self releaseFeature:feature];s.available=okay;s.active=okay;s.note=okay ? @"In RE7 angewandt und nativ zurückgelesen." : @"Wartet auf passende RE7-Objekte bzw. den DLC-Modus.";return s;
}
- (NSString *)performOneShot:(RE2Feature)feature value:(double)value {
    if(![self local7])return @"Keine bestätigte lokale RE7-Spielfigur.";
    if((NSInteger)feature==RE7ResetTime){
        void *chapterField=[_e7 field:43680 owner:11603 type:11825 object:_manager7 size:4];int32_t chapter=-1;if(chapterField)MTReadMemory(chapterField,&chapter,4);
        if(!(chapter==2 || chapter==4 || chapter==5 || chapter==6 || chapter==13 || chapter==14))return @"Spielzeit zurücksetzen ist auf das Hauptspiel begrenzt; keine DLC-Zähler verändert.";
        float zero=0,uptime=0;float (*getUp)(void *)=[_e7 method:291880 owner:27429];if(!getUp)return @"Nativer Zeitursprung fehlt.";uptime=getUp(_e7.threadContext);
        const uint32_t fields[]={43730,43732,43729};const float values[]={zero,zero,uptime};void *addresses[3]={0};
        for(NSUInteger i=0;i<3;i++){addresses[i]=[_e7 field:fields[i] owner:11603 type:25922 object:_manager7 size:4];float old=0;if(!addresses[i] || !MTReadMemory(addresses[i],&old,4) || !isfinite(old) || old<0 || !isfinite(values[i]) || values[i]<0)return @"Zeitbestandteile nicht bestätigt.";}
        BOOL okay=YES;for(NSUInteger i=0;i<3;i++){float read=0;okay&=MTWriteFloat(addresses[i],0,values[i]) && MTReadMemory(addresses[i],&read,4) && read==values[i];}
        os_log(_log7,"RE7 time reset readback=%{public}d",okay);return okay ? @"Spielzeit-Bestandteile nativ zurückgesetzt." : @"Spielzeit-Rückleseprüfung fehlgeschlagen.";
    }
    if((NSInteger)feature==RE7Scraps){
        void *nightmare=[self nightmare7],*manager=[self instance7:354314 owner:42804 type:22894];
        int32_t (*get)(void *,void *)=[_e7 method:354347 owner:22894];void (*set)(void *,void *,int32_t)=[_e7 method:354348 owner:22894];
        if(!nightmare || !manager || !get || !set || !isfinite(value) || value<0 || value>9999999 || floor(value)!=value)return @"Wartet auf eine laufende Albtraum-Runde.";
        int32_t before=get(_e7.threadContext,manager),n=(int32_t)value;if(before<0)return @"Schrottbestand nicht bestätigt.";
        set(_e7.threadContext,manager,n);BOOL okay=get(_e7.threadContext,manager)==n;
        os_log(_log7,"RE7 scraps before=%{public}d requested=%{public}d readback=%{public}d",before,n,okay);
        return okay ? @"Schrottbestand nativ gesetzt." : @"Schrott-Rückleseprüfung fehlgeschlagen.";
    }return @"Keine RE7-Einmalaktion für diese Funktion.";
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {
    if(!_e7.isGameThread)return NO;
    // A valid process HID device can serve UI even without an active DLC/player.
    // Exact RE7 Mouse wrappers load this manager, pass +0x10 to the native
    // Show/Clip/Absolute accessors at +0x150/+0x151/+0x153 respectively.
    void *device=[_e7 singletonAt:0x108d45870];const size_t offsets[]={0x160,0x161,0x163};const uint8_t values[]={1,0,1};
    if(_mouseOwned7 && (device!=_mouseDevice7 || !wanted)){
        BOOL okay=YES;if(device==_mouseDevice7)for(NSUInteger i=0;i<3;i++){uint8_t v=0;if(MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==values[i])okay&=MTWriteByte(device,offsets[i],_mouseBefore7[i]) && MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==_mouseBefore7[i];}
        _mouseOwned7=NO;os_log(_log7,"RE7 mouse released readback=%{public}d",okay);
    }
    if(!wanted || !device)return NO;BOOL first=!_mouseOwned7;
    if(first){for(NSUInteger i=0;i<3;i++)if(!MTReadMemory((uint8_t *)device+offsets[i],&_mouseBefore7[i],1) || _mouseBefore7[i]>1)return NO;_mouseDevice7=device;_mouseOwned7=YES;}
    uint8_t observed[3];for(NSUInteger i=0;i<3;i++)if(!MTReadMemory((uint8_t *)device+offsets[i],&observed[i],1) || observed[i]>1)return NO;
    if(!first)for(NSUInteger i=0;i<3;i++)if(observed[i]!=values[i])_mouseBefore7[i]=observed[i];
    BOOL okay=YES;for(NSUInteger i=0;i<3;i++){uint8_t v=0;okay&=MTWriteByte(device,offsets[i],values[i]) && MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==values[i];}
    if(first)os_log(_log7,"RE7 mouse acquired readback=%{public}d",okay);return okay;
}
@end
