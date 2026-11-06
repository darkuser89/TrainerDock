// SPDX-License-Identifier: GPL-3.0-only
#import "RE4Adapter.h"
#import "RE4Features.h"
#import "RE2EffectLedger.h"
#import "RE2Engine.h"
#import "RE4Engine.h"
#import "RE4Math.h"
#import "RE4ItemCatalog.h"
#import "MemoryAccess.h"
#import <os/log.h>
#include <math.h>
static uintptr_t r4p(void *p,size_t o){uintptr_t v=0;MTReadMemory((uint8_t *)p+o,&v,8);return v;}
static uint32_t r4n(void *p,size_t o){uint32_t v=0;MTReadMemory((uint8_t *)p+o,&v,4);return v;}
static NSData *r4bytes(const void *p,size_t n){return [NSData dataWithBytes:p length:n];}
// RE's generated value-type getters use x8 for the result even for Guid16.
// A 24-byte C return buffer selects that indirect ABI; only the first 16 are used.
typedef struct {uint64_t words[3];} RE4IndirectGuid;
@implementation RE4NativeAdapter {
    MTRE2Engine *_e4;RE2Owner *_owner4;
    void *_manager4,*_character4,*_hp4;
    BOOL _pump4;
    BOOL _mouseOwned4;void *_mouseDevice4;uint8_t _mouseBefore4[3];
    NSMutableDictionary<NSNumber *,NSNumber *> *_wanted4;
    NSString *_identity4;
    os_log_t _log4;
    NSMutableSet<NSString *> *_inventoryDiagnostics4;
    NSMutableDictionary<NSNumber *,NSValue *> *_runtimeTypes4;
    NSMutableDictionary<NSNumber *,RE2Owner *> *_controllers4;
    RE2Owner *_reflectionOwner4;
    void *_scene4;
    CFAbsoluteTime _nextControllerScan4[2],_clockSampleWall4;
    uint64_t _clockSample4;BOOL _clockMicroseconds4;
    void *_gainMoneyObject4;int32_t _lastPTAS4;BOOL _gainMoneyReady4,_gainMoneyApplied4;
    void *_gainScoreObject4;int32_t _lastScore4;BOOL _gainScoreReady4,_gainScoreApplied4;
    NSMutableSet<NSString *> *_effectDiagnostics4;
    NSUInteger _itemNameCursor4;
    void *_defenseRankData4;
    NSUInteger _recoilCancellations4;
    RE2Owner *_recoilCamera4;
    NSMutableSet<NSString *> *_recoilNotes4;
}
- (void *)objectGetter:(uint32_t)index owner:(uint32_t)owner object:(void *)object {
    if(!_e4.isGameThread || ![_e4 isObject:object kindOf:owner])return NULL;
    void *(*fn)(void *,void *)=[_e4 method:index owner:owner];
    return fn ? fn(_e4.threadContext,object) : NULL;
}
- (void)trace4:(NSString *)message {
    if(![NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"])return;
    if(!_effectDiagnostics4)_effectDiagnostics4=[NSMutableSet new];
    if(_effectDiagnostics4.count<24 && ![_effectDiagnostics4 containsObject:message]){[_effectDiagnostics4 addObject:message];os_log(_log4,"RE4 binding detail %{public}@",message);}
}
- (void *)field4:(uint32_t)fid owner:(uint32_t)type type:(uint32_t)fieldType object:(void *)object size:(NSUInteger)n {
    return [(MTRE4Engine *)_e4 field:fid owner:type type:fieldType object:object size:n];
}
- (void *)runtimeType4:(NSString *)name type:(uint32_t)type {
    if(!_runtimeTypes4)_runtimeTypes4=[NSMutableDictionary new];
    NSValue *cached=_runtimeTypes4[@(type)];if(cached)return cached.pointerValue;
    void *(*allocate)(void *,int32_t)=[_e4 method:593401 owner:74725];
    void *(*resolve)(void *,void *)=[_e4 method:594013 owner:66486];
    if(!allocate || !resolve || !name.length || name.length>128)return NULL;
    if(!_reflectionOwner4)_reflectionOwner4=[RE2Owner ownerForGameObject:_owner4.gameObject engine:_e4];
    if(!_reflectionOwner4.valid)return NULL;
    void *string=allocate(_e4.threadContext,(int32_t)name.length);
    if([_e4 typeOf:string]!=74725 || r4n(string,0x10)!=name.length)return NULL;
    [_reflectionOwner4 retainPayload:string];NSData *utf16=[name dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    const uint8_t *bytes=utf16.bytes;
    for(NSUInteger i=0;i<utf16.length;i++)if(!MTWriteByte(string,0x14+i,bytes[i]))return NULL;
    void *rt=resolve(_e4.threadContext,string);if(![_e4 isObject:rt kindOf:66486])return NULL;
    [_reflectionOwner4 retainPayload:rt];_runtimeTypes4[@(type)]=[NSValue valueWithPointer:rt];return rt;
}
- (RE2Owner *)controller4:(uint32_t)type {
    void *(*current)(void *)=[_e4 method:661854 owner:33668];
    void *(*find)(void *,void *,void *)=[_e4 method:374001 owner:21642];if(!current || !find)return nil;
    void *scene=current(_e4.threadContext);if([_e4 typeOf:scene]!=21642)return nil;
    if(scene!=_scene4){_scene4=scene;_controllers4=[NSMutableDictionary new];memset(_nextControllerScan4,0,sizeof(_nextControllerScan4));}
    RE2Owner *old=_controllers4[@(type)];if(old.valid && [_e4 isObject:old.component kindOf:type])return old;
    NSUInteger slot=type==69813 ? 0 : 1;CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();if(now<_nextControllerScan4[slot])return nil;_nextControllerScan4[slot]=now+0.5;
    NSString *name=type==69813 ? @"chainsaw.MercenariesModeController" : @"chainsaw.ShootingGallery2Controller";
    void *rt=[self runtimeType4:name type:type];if(!rt)return nil;
    void *array=find(_e4.threadContext,scene,rt);uint32_t n=r4n(array,0x1c);
    if([_e4 typeOf:array]==UINT32_MAX || n>128)return nil;
    void (*retain)(void *)=(void *)_e4.retainAddress,(*release)(void *)=(void *)_e4.releaseAddress;retain(array);
    RE2Owner *found=nil;
    for(uint32_t i=0;i<n;i++){
        void *component=(void *)r4p(array,0x20+i*8);if(![_e4 isObject:component kindOf:type])continue;
        RE2Owner *owner=[RE2Owner ownerForComponent:component engine:_e4];if(!owner.valid)continue;
        if(found){found=nil;break;}found=owner;[owner retainPayload:scene];
    }release(array);
    if(found){_controllers4[@(type)]=found;os_log(_log4,"RE4 mode controller bound type=%{public}u",type);}return found;
}
- (BOOL)fieldBytes4:(NSData *)bytes object:(void *)object field:(uint32_t)fid type:(uint32_t)type fieldType:(uint32_t)fieldType owner:(RE2Owner *)owner feature:(RE2Feature)feature guard:(BOOL (^)(void))guard {
    void *address=[self field4:fid owner:type type:fieldType object:object size:bytes.length];
    if(!address)return NO;[owner retainPayload:object];
    return [self applyBytes:bytes object:object offset:(uint8_t *)address-(uint8_t *)object owner:owner global:NO feature:feature guard:guard];
}
- (void)calibrateClock4 {
    if(_clockMicroseconds4 || ![self local4])return;
    if([self paused4] || _wanted4[@(RE4FreezeTime)]){_clockSampleWall4=0;return;}
    void *clock=[_e4 singletonAt:0x1110b5f18];if([_e4 typeOf:clock]!=31665)return;
    uint64_t n=r4p(clock,0x30);CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
    if(!_clockSampleWall4){_clockSampleWall4=now;_clockSample4=n;return;}
    double seconds=now-_clockSampleWall4;if(seconds<2)return;
    double rate=n>=_clockSample4 ? (double)(n-_clockSample4)/seconds : 0;
    if(seconds<4 && rate>950000 && rate<1050000){_clockMicroseconds4=YES;os_log(_log4,"RE4 clock microsecond unit confirmed delta=%{public}llu seconds=%{public}f",(unsigned long long)(n-_clockSample4),seconds);}
    _clockSampleWall4=0;
}
- (void *)instance4:(uint32_t)method owner:(uint32_t)owner type:(uint32_t)type {
    void *(*get)(void *)=[_e4 method:method owner:owner];if(!get)return NULL;
    void *object=get(_e4.threadContext);return [_e4 isObject:object kindOf:type] ? object : NULL;
}
- (NSString *)itemNameID4:(int32_t)itemID {
    RE4IndirectGuid (*nameID)(void *,int32_t,uint32_t)=[_e4 method:750416 owner:67045];
    void *(*text)(void *,const void *)=[_e4 method:688672 owner:67186];
    if(!nameID || !text)return nil;
    RE4IndirectGuid guid=nameID(_e4.threadContext,itemID,0);if(!(guid.words[0]|guid.words[1]))return nil;
    void *string=text(_e4.threadContext,&guid);uint32_t n=r4n(string,0x10);
    if([_e4 typeOf:string]!=74725 || !n || n>128)return nil;unichar chars[128];
    return MTReadMemory((uint8_t *)string+0x14,chars,n*2) ? [NSString stringWithCharacters:chars length:n] : nil;
}
- (NSString *)itemName4:(void *)item {
    int32_t (*itemID)(void *,void *)=[_e4 method:91696 owner:50224];
    return itemID && [_e4 isObject:item kindOf:50224] ? [self itemNameID4:itemID(_e4.threadContext,item)] : nil;
}
- (void)diagnosticItemNames4 {
    if(![self local4] || ![NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"])return;
    for(NSUInteger i=0;i<2 && _itemNameCursor4<sizeof(RE4ItemIDs)/sizeof(RE4ItemIDs[0]);i++, _itemNameCursor4++){
        int32_t itemID=RE4ItemIDs[_itemNameCursor4];NSString *name=[self itemNameID4:itemID];
        if(name && [name rangeOfString:@"marke|token|ticket|gold|silber" options:NSRegularExpressionSearch|NSCaseInsensitiveSearch].location!=NSNotFound)
            os_log(_log4,"RE4 item definition id=%{public}d name=%{public}@",itemID,name);
    }
}
- (void)diagnosticRoots4 {
    if(![NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"])return;
    const uint32_t roots[][3]={{55407,30103,16751},{296918,24679,59361},{624057,48696,55843},{109635,27483,63178},{643136,38187,71906}};
    for(NSUInteger i=0;i<sizeof(roots)/sizeof(roots[0]);i++){
        void *p=[self instance4:roots[i][0] owner:roots[i][1] type:roots[i][2]];
        os_log(_log4,"RE4 root requested=%{public}u actual=%{public}u",roots[i][2],[_e4 typeOf:p]);
    }
    void *main=(void *)r4p(_character4,0x188),*controller=[self objectGetter:353921 owner:34293 object:main];
    void *recoil=[_e4 isObject:controller kindOf:41015] ? [self objectGetter:353240 owner:41015 object:controller] : NULL;
    os_log(_log4,"RE4 recoil controller=%{public}u parameter=%{public}u",[_e4 typeOf:controller],[_e4 typeOf:recoil]);
    for(uint32_t field=67555;field<=67556;field++){
        void *address=[(MTRE4Engine *)_e4 field:field owner:6386 type:45360 object:recoil size:4];
        float n=0;if(address)MTReadMemory(address,&n,4);
        os_log(_log4,"RE4 field check id=%{public}u offset=%{public}ld value=%{public}f",field,address ? (long)((uint8_t *)address-(uint8_t *)recoil) : -1,n);
    }
    for(NSValue *entry in [self items4IncludingSpecial:YES]){
        void *item=entry.pointerValue;NSString *name=[self itemName4:item];
        if(name)os_log(_log4,"RE4 item original id=%{public}u name=%{public}@ count=%{public}u",r4n(item,0x28),name,r4n(item,0x34));
    }
    for(NSNumber *type in @[@69813,@44170]){RE2Owner *owner=[self controller4:type.unsignedIntValue];os_log(_log4,"RE4 mode lookup type=%{public}u present=%{public}d",type.unsignedIntValue,owner.valid);}
    [self diagnosticShop4];
}
- (void)diagnosticShop4 {
    void *manager=[self instance4:624057 owner:48696 type:55843];
    void *(*infos)(void *,void *)=[_e4 method:624662 owner:55843];
    BOOL (*unlocked)(void *,void *,int32_t)=[_e4 method:624675 owner:55843];
    if(!manager || !infos || !unlocked)return;
    void *array=infos(_e4.threadContext,manager);uint32_t n=r4n(array,0x1c);
    if([_e4 typeOf:array]!=30082 || n>512)return;
    void (*retain)(void *)=(void *)_e4.retainAddress,(*release)(void *)=(void *)_e4.releaseAddress;retain(array);
    NSUInteger cp=0,locked=0;
    for(uint32_t i=0;i<n;i++){
        void *info=(void *)r4p(array,0x20+i*8);
        void *price=[self field4:65358 owner:68616 type:11111 object:info size:4],*idField=[self field4:65357 owner:68616 type:8818 object:info size:4];
        if(!price || !idField || (int32_t)r4n(price,0)<=0 || (int32_t)r4n(idField,0)<0)continue;
        cp++;if(!unlocked(_e4.threadContext,manager,(int32_t)r4n(idField,0)))locked++;
    }release(array);
    os_log(_log4,"RE4 CP shop read-only registered=%{public}lu locked=%{public}lu",(unsigned long)cp,(unsigned long)locked);
}
- (instancetype)init {if((self=[super init])){_e4=MTRE2Engine.shared;_wanted4=[NSMutableDictionary new];_log4=os_log_create("local.mactrainer.re2","re4-effects");}return self;}
- (void *)playerContext4 {
    void *mgr=[_e4 singletonAt:0x1110b5f30];return [_e4 typeOf:mgr]==54264 ? [self objectGetter:341494 owner:54264 object:mgr] : NULL;
}
- (BOOL)local4 {
    if(!_e4.isGameThread || !_owner4.valid || [self playerContext4]!=_character4)return NO;
    BOOL (*valid)(void *,void *)=[_e4 method:356350 owner:13556];
    return valid && valid(_e4.threadContext,_character4) && [self objectGetter:356441 owner:13556 object:_character4]==_owner4.gameObject && [self objectGetter:356412 owner:13556 object:_character4]==_hp4;
}
- (BOOL)paused4 {
    void *(*instance)(void *)=[_e4 method:47486 owner:878];BOOL (*paused)(void *,void *)=[_e4 method:48800 owner:14697];
    if(!instance || !paused)return YES;void *p=instance(_e4.threadContext);return [_e4 typeOf:p]!=14697 || paused(_e4.threadContext,p);
}
- (void *)equipment4 {
    void *head=[self objectGetter:356432 owner:13556 object:_character4];if(![_e4 isObject:head kindOf:38892])return NULL;
    void *e=[self objectGetter:352618 owner:38892 object:head];return [_e4 isObject:e kindOf:8310] && [self objectGetter:241830 owner:8310 object:e]==_character4 ? e : NULL;
}
- (NSArray<NSValue *> *)items4 {return [self items4IncludingSpecial:NO];}
- (NSArray<NSValue *> *)items4IncludingSpecial:(BOOL)includeSpecial {
    void *equipment=[self equipment4];if(!equipment)return @[];
    NSMutableArray *items=[NSMutableArray new];
    const uint32_t getters[]={241836,241838,352614,352616};
    const uint32_t listOwners[]={76292,23092,65763,58532};
    for(NSUInteger k=0;k<(includeSpecial ? 4 : 2);k++){
        void *head=[self objectGetter:356432 owner:13556 object:_character4];
        void *inventory=[self objectGetter:getters[k] owner:k<2 ? 8310 : 38892 object:k<2 ? equipment : head];
        BOOL controller=[_e4 isObject:inventory kindOf:60956],specific=[_e4 isObject:inventory kindOf:listOwners[k]];
        void *context=controller ? [self objectGetter:133742 owner:60956 object:inventory] : NULL;
        if([NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"]){
            NSString *d=[NSString stringWithFormat:@"controller=%lu type=%u base=%d specific=%d localContext=%d",(unsigned long)k,[_e4 typeOf:inventory],controller,specific,context==_character4];
            if(!_inventoryDiagnostics4)_inventoryDiagnostics4=[NSMutableSet new];
            if(_inventoryDiagnostics4.count<24 && ![_inventoryDiagnostics4 containsObject:d]){[_inventoryDiagnostics4 addObject:d];os_log(_log4,"RE4 inventory %{public}@",d);}
        }
        if(!controller || context!=_character4 || !specific)continue;
        // The public getItems methods call Item.getCopy. Read the actual
        // storage lists used by those exact RE4 methods instead of modifying
        // their disposable copies. Both controller getters load +0xa0;
        // CsInventory iterates +0x38, UniqueInventory iterates +0x20.
        const uint32_t storageTypes[]={23723,75646,9319,42160},listTypes[]={65538,66362,19940,64539};
        void *storage=k<2 ? (void *)r4p(inventory,0xa0) : (void *)r4p([self field4:k==2 ? 71481 : 69112 owner:listOwners[k] type:storageTypes[k] object:inventory size:8],0);
        if([_e4 typeOf:storage]!=storageTypes[k])continue;
        void *list=k<2 ? (void *)r4p(storage,k==0 ? 0x38 : 0x20) : (void *)r4p([self field4:k==2 ? 21864 : 22015 owner:storageTypes[k] type:listTypes[k] object:storage size:8],0);
        void *array=(void *)r4p(list,0x10);uint32_t count=r4n(list,0x18),capacity=r4n(array,0x1c);
        if([NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"]){
            NSString *d=[NSString stringWithFormat:@"list=%lu type=%u arrayType=%u count=%u capacity=%u firstType=%u",(unsigned long)k,[_e4 typeOf:list],[_e4 typeOf:array],count,capacity,[_e4 typeOf:(void *)r4p(array,0x20)]];
            if(_inventoryDiagnostics4.count<24 && ![_inventoryDiagnostics4 containsObject:d]){[_inventoryDiagnostics4 addObject:d];os_log(_log4,"RE4 inventory %{public}@",d);}
        }
        if([_e4 typeOf:list]!=listTypes[k] || [_e4 typeOf:array]==UINT32_MAX || count>512 || capacity>4096 || count>capacity)continue;
        for(uint32_t i=0;i<count;i++){
            void *item=(void *)r4p(array,0x20+i*8);
            if([_e4 isObject:item kindOf:37382])item=[self objectGetter:94045 owner:37382 object:item];
            if(![_e4 isObject:item kindOf:50224])continue;
            NSValue *p=[NSValue valueWithPointer:item];if(![items containsObject:p])[items addObject:p];
        }
    }return items;
}
- (void *)equippedItem4 {
    void *equipment=[self equipment4],*selected=[self objectGetter:241886 owner:8310 object:equipment];
    if(![_e4 isObject:selected kindOf:70989])return NULL;
    // Inventory selection may return an Item copy. Resolve its nonzero Guid
    // back to exactly one original item in this local equipment's storage.
    uint64_t guid[2]={0};if(!MTReadMemory((uint8_t *)selected+0x18,guid,16) || !(guid[0]|guid[1]))return NULL;
    void *match=NULL;
    for(NSValue *p in [self items4]){
        void *item=p.pointerValue;uint64_t id[2]={0};
        if(![_e4 isObject:item kindOf:70989] || !MTReadMemory((uint8_t *)item+0x18,id,16) || memcmp(guid,id,16))continue;
        if(match)return NULL;match=item;
    }return match;
}
- (NSString *)inventoryCurrency4:(RE2Feature)feature value:(double)value {
    if(!isfinite(value) || value<0 || value>9999 || floor(value)!=value)return @"Ungültiger Stapelwert.";
    // Exact Mac ItemID literals, independently confirmed by native localization;
    // ticket00 is also the literal used by getTicket00CountSum. Ticket01 (DLC)
    // is deliberately excluded. This operation never creates an item.
    int32_t wantedID=(NSInteger)feature==RE4Tickets ? 120867200 : (NSInteger)feature==RE4GoldTokens ? 119288000 : 119286400;
    int32_t (*itemID)(void *,void *)=[_e4 method:91696 owner:50224];
    int32_t (*get)(void *,void *)=[_e4 method:91698 owner:50224],(*max)(void *,void *)=[_e4 method:91709 owner:50224];
    void (*set)(void *,void *,int32_t)=[_e4 method:91719 owner:50224];
    if(!itemID || !get || !max || !set)return @"Native Inventarmethoden fehlen.";
    void *match=NULL;
    for(NSValue *p in [self items4IncludingSpecial:YES]){
        void *item=p.pointerValue;if(itemID(_e4.threadContext,item)!=wantedID)continue;
        if(match)return @"Mehrere passende Stapel: Änderung ohne eindeutigen Besitzer verworfen.";
        match=item;
    }
    if(!match){[self trace4:[NSString stringWithFormat:@"currency id=%d absent; no write",wantedID]];return @"Kein vorhandener Stapel dieses Tickets bzw. Jetons im lokalen Inventar.";}
    int32_t before=get(_e4.threadContext,match),limit=max(_e4.threadContext,match);
    if(before<0 || limit<1 || limit>1000000 || ![self local4])return @"Stapelgrenzen nicht bestätigt.";
    int32_t requested=MIN((int32_t)value,limit);[_owner4 retainPayload:match];
    set(_e4.threadContext,match,requested);int32_t after=get(_e4.threadContext,match);
    os_log(_log4,"RE4 inventory currency id=%{public}d before=%{public}d requested=%{public}d nativeLimit=%{public}d after=%{public}d",wantedID,before,requested,limit,after);
    if(after!=requested)return @"Inventaränderung nicht nativ bestätigt.";
    return [NSString stringWithFormat:@"Vorhandener Stapel auf %d gesetzt (natives Maximum %d).",after,limit];
}
- (BOOL)nativeInt4:(int32_t)n object:(void *)object getter:(uint32_t)gid setter:(uint32_t)sid type:(uint32_t)type owner:(RE2Owner *)owner feature:(RE2Feature)feature guard:(BOOL (^)(void))guard {
    int32_t (*get)(void *,void *)=[_e4 method:gid owner:type];void (*set)(void *,void *,int32_t)=[_e4 method:sid owner:type];if(!get || !set || ![_e4 isObject:object kindOf:type])return NO;MTRE2Engine *engine=_e4;
    return [self applyNativeBytes:r4bytes(&n,4) object:object tag:gid owner:owner feature:feature guard:guard read:^NSData *{int32_t v=get(engine.threadContext,object);return r4bytes(&v,4);} write:^(NSData *b){int32_t v;[b getBytes:&v length:4];set(engine.threadContext,object,v);}];
}
- (BOOL)nativeFloat4:(float)n object:(void *)object getter:(uint32_t)gid setter:(uint32_t)sid type:(uint32_t)type owner:(RE2Owner *)owner feature:(RE2Feature)feature guard:(BOOL (^)(void))guard {
    float (*get)(void *,void *)=[_e4 method:gid owner:type];void (*set)(void *,void *,float)=[_e4 method:sid owner:type];if(!get || !set || !isfinite(n) || ![_e4 isObject:object kindOf:type])return NO;MTRE2Engine *engine=_e4;
    return [self applyNativeBytes:r4bytes(&n,4) object:object tag:gid owner:owner feature:feature guard:guard read:^NSData *{float v=get(engine.threadContext,object);return r4bytes(&v,4);} write:^(NSData *b){float v;[b getBytes:&v length:4];set(engine.threadContext,object,v);}];
}
- (BOOL)inventory4:(RE2Feature)feature {
    NSArray<NSValue *> *items=[self items4];BOOL okay=YES;NSUInteger targets=0;RE2Owner *owner=_owner4;void *character=_character4;
    int32_t (*type)(void *,void *)=[_e4 method:91707 owner:50224],(*count)(void *,void *)=[_e4 method:91698 owner:50224],(*max)(void *,void *)=[_e4 method:91709 owner:50224],(*durability)(void *,void *)=[_e4 method:91699 owner:50224],(*durabilityMax)(void *,void *)=[_e4 method:91710 owner:50224];
    if(!type || !count || !max || !durability || !durabilityMax)return NO;
    for(NSValue *p in items){
        void *item=p.pointerValue;int32_t t=type(_e4.threadContext,item),n=0;
        BOOL durabilityFeature=(NSInteger)feature==RE4Knife || (NSInteger)feature==RE4Armor;
        if(durabilityFeature){if(t!=((NSInteger)feature==RE4Knife ? 6 : 8) || durability(_e4.threadContext,item)<=0)continue;n=durabilityMax(_e4.threadContext,item);if(n<=0 || n>1000000)continue;}
        else{if(!((NSInteger)feature==RE4Ammo ? t==1 : t==2 || t==3 || t==4 || t==7) || count(_e4.threadContext,item)<=0)continue;n=max(_e4.threadContext,item);if(n<=1 || n>9999)continue;}
        BOOL (^guard)(void)=^BOOL{return owner.valid && [self playerContext4]==character && [[self items4] containsObject:p];};
        [owner retainPayload:item];
        okay&=[self nativeInt4:n object:item getter:durabilityFeature ? 91699 : 91698 setter:durabilityFeature ? 91722 : 91719 type:50224 owner:owner feature:feature guard:guard];targets++;
    }return okay && targets>0;
}
- (NSArray<NSValue *> *)enemies4 {
    void *list=[self objectGetter:341449 owner:54264 object:_manager4],*array=(void *)r4p(list,0x10);uint32_t n=r4n(list,0x18),capacity=r4n(array,0x1c);
    if([_e4 typeOf:list]!=9019 || [_e4 typeOf:array]==UINT32_MAX || n>512 || capacity>4096 || n>capacity)return @[];
    NSMutableArray *contexts=[NSMutableArray new];
    for(uint32_t i=0;i<n;i++){void *c=(void *)r4p(array,0x20+i*8);if(c!=_character4 && [_e4 isObject:c kindOf:13556])[contexts addObject:[NSValue valueWithPointer:c]];}
    return contexts;
}
- (void *)motion4:(void *)character {
    void *body=[self objectGetter:356434 owner:13556 object:character];if(![_e4 isObject:body kindOf:31138])return NULL;
    if([self objectGetter:344154 owner:31138 object:body]!=character)return NULL;
    void *motion=[self objectGetter:344195 owner:31138 object:body];return [_e4 isObject:motion kindOf:24506] ? motion : NULL;
}
- (BOOL)motionSpeed4:(double)value feature:(RE2Feature)feature {
    if(!isfinite(value) || value<0.1 || value>3)return NO;
    float (*get)(void *,void *)=[_e4 method:5524 owner:24506];if(!get)return NO;
    NSArray *contexts=(NSInteger)feature==RE4PlayerSpeed ? @[[NSValue valueWithPointer:_character4]] : [self enemies4];
    BOOL okay=YES;NSUInteger targets=0;void *player=_character4;
    for(NSValue *p in contexts){void *character=p.pointerValue,*motion=[self motion4:character];RE2Owner *owner=[RE2Owner ownerForComponent:motion engine:_e4];
        if(!owner.valid)continue;[owner retainPayload:character];float base=get(_e4.threadContext,motion);NSData *saved=[self baselineForNativeObject:motion tag:5524 feature:feature];if(saved)[saved getBytes:&base length:4];
        if(!isfinite(base) || base<=0 || base>10)continue;float n=base*(float)value;
        okay&=[self nativeFloat4:n object:motion getter:5524 setter:5525 type:24506 owner:owner feature:feature guard:^BOOL{return owner.valid && [self playerContext4]==player && [self motion4:character]==motion;}];targets++;
    }return okay && targets>0;
}
- (BOOL)easyKills4:(RE2Feature)feature {
    BOOL okay=YES;NSUInteger targets=0;void *player=_character4;uint32_t one=1;
    for(NSValue *p in [self enemies4]){
        void *c=p.pointerValue,*go=[self objectGetter:356441 owner:13556 object:c],*hp=[self objectGetter:356412 owner:13556 object:c];RE2Owner *owner=[RE2Owner ownerForGameObject:go engine:_e4];uint32_t health=r4n(hp,0x14);
        if(!owner.valid || go==_owner4.gameObject || [_e4 typeOf:hp]!=55484 || !health || health>10000000)continue;
        [owner retainPayload:c];okay&=[self applyBytes:r4bytes(&one,4) object:hp offset:0x14 owner:owner global:NO feature:feature guard:^BOOL{return owner.valid && [self playerContext4]==player && [self objectGetter:356412 owner:13556 object:c]==hp && [self objectGetter:356441 owner:13556 object:c]==go;}];targets++;
    }return okay && targets>0;
}
- (void *)damageData4:(void *)character {
    void *param=[self objectGetter:356443 owner:13556 object:character];if(![_e4 isObject:param kindOf:32051]){[self trace4:[NSString stringWithFormat:@"damage parameter type=%u",[_e4 typeOf:param]]];return NULL;}
    void *(*get)(void *,void *)=[(MTRE4Engine *)_e4 virtualMethod:90912 owner:32051 object:param];
    void *data=get ? get(_e4.threadContext,param) : NULL;
    if(![_e4 isObject:data kindOf:9282])[self trace4:[NSString stringWithFormat:@"damage parameter=%u data=%u getterOffset=%lld",[_e4 typeOf:param],[_e4 typeOf:data],get ? (long long)((uintptr_t)get-_e4.slide-0x1082f2924) : 0]];
    return [_e4 isObject:data kindOf:9282] ? data : NULL;
}
- (BOOL)damageFactor4:(double)value feature:(RE2Feature)feature {
    if(!isfinite(value) || value<1 || value>100)return NO;
    BOOL defense=(NSInteger)feature==RE4Defense;void *player=_character4,*localData=[self damageData4:player];
    NSArray *targets=defense ? @[[NSValue valueWithPointer:player]] : [self enemies4];
    NSMutableSet *seen=[NSMutableSet new];BOOL okay=YES;NSUInteger applied=0;
    for(NSValue *p in targets){
        void *c=p.pointerValue,*data=[self damageData4:c];if(!data || (!defense && data==localData))continue;
        NSValue *key=[NSValue valueWithPointer:data];if([seen containsObject:key])continue;[seen addObject:key];
        void *go=[self objectGetter:356441 owner:13556 object:c];RE2Owner *owner=[RE2Owner ownerForGameObject:go engine:_e4];if(!owner.valid)continue;
        void *address=[self field4:19997 owner:9282 type:45360 object:data size:4];float base=0;if(!address || !MTReadMemory(address,&base,4))continue;
        size_t offset=(uint8_t *)address-(uint8_t *)data;NSData *saved=[self baselineForObject:data offset:offset feature:feature];if(saved)[saved getBytes:&base length:4];
        if(!isfinite(base) || base<=0 || base>1000){[self trace4:[NSString stringWithFormat:@"damage data=%u base=%f defense=%d",[_e4 typeOf:data],base,defense]];continue;}float n=defense ? base/(float)value : base*(float)value;
        [owner retainPayload:c];BOOL (^guard)(void)=^BOOL{return owner.valid && [self playerContext4]==player && [self damageData4:c]==data && [self objectGetter:356441 owner:13556 object:c]==go;};
        okay&=[self fieldBytes4:r4bytes(&n,4) object:data field:19997 type:9282 fieldType:45360 owner:owner feature:feature guard:guard];applied++;
    }return okay && applied>0;
}
- (BOOL)defense4:(double)value feature:(RE2Feature)feature {
    if(!isfinite(value) || value<1 || value>100)return NO;
    void *rank=[self instance4:402248 owner:65738 type:33083];
    float (*get)(void *,void *,void *)=[_e4 method:403689 owner:33083];
    void *p=[self field4:90657 owner:33083 type:64573 object:rank size:8],*parameters=(void *)r4p(p,0);
    void *enabled=[self field4:90577 owner:64573 type:72798 object:parameters size:1];uint8_t yes=0;
    if(!get || !enabled || !MTReadMemory(enabled,&yes,1) || yes!=1)return NO;
    void *rankField=[self field4:90648 owner:33083 type:11111 object:rank size:4];
    int32_t index=(int32_t)r4n(rankField,0);
    void *array=(void *)r4p([self field4:90582 owner:64573 type:16616 object:parameters size:8],0);
    uint32_t n=r4n(array,0x1c);if(!rankField || [_e4 typeOf:array]!=16616 || index<0 || n>32 || (uint32_t)index>=n)return NO;
    void *data=(void *)r4p(array,0x20+(size_t)index*8);
    void *rate=[self field4:90467 owner:13738 type:45360 object:data size:4];float current=0;
    if(!rate || !MTReadMemory(rate,&current,4) || !isfinite(current) || current<=0 || current>100)return NO;
    if(_defenseRankData4!=data){[self releaseFeature:feature];_defenseRankData4=data;}
    // Confirm that this exact rank entry is the native local damage source.
    // An exceptional character/rank override must not modify a different entry.
    if(get(_e4.threadContext,rank,_owner4.gameObject)!=current)return NO;
    size_t offset=(uint8_t *)rate-(uint8_t *)data;float base=current;
    NSData *saved=[self baselineForObject:data offset:offset feature:feature];if(saved)[saved getBytes:&base length:4];
    float requested=base/(float)value;void *character=_character4;RE2Owner *owner=_owner4;
    [owner retainPayload:rank];[owner retainPayload:parameters];[owner retainPayload:array];
    BOOL (^guard)(void)=^BOOL{return owner.valid && [self playerContext4]==character && [self instance4:402248 owner:65738 type:33083]==rank && r4p([self field4:90657 owner:33083 type:64573 object:rank size:8],0)==(uintptr_t)parameters && r4p([self field4:90582 owner:64573 type:16616 object:parameters size:8],0)==(uintptr_t)array && r4p(array,0x20+(size_t)index*8)==(uintptr_t)data;};
    BOOL okay=[self fieldBytes4:r4bytes(&requested,4) object:data field:90467 type:13738 fieldType:45360 owner:owner feature:feature guard:guard];
    float after=get(_e4.threadContext,rank,owner.gameObject);okay=okay && after==requested;
    if(okay)[self trace4:[NSString stringWithFormat:@"defense rank=%d before=%f after=%f nativeReadback=1",index,base,after]];
    return okay;
}
- (void *)recoilParameter4:(void *)arms {
    void *manager=[self instance4:292349 owner:51662 type:51450];
    void *(*custom)(void *,void *,void *)=[_e4 method:296048 owner:51450];
    void *param=manager && custom ? custom(_e4.threadContext,manager,arms) : NULL;
    if([_e4 typeOf:param]==6386)return param;
    int32_t (*kind)(void *,void *)=[_e4 method:356357 owner:13556];
    int32_t (*weaponID)(void *,void *)=[_e4 method:240755 owner:28753];
    void *equipmentManager=[self instance4:622970 owner:45349 type:70029];
    void *(*get)(void *,void *,int32_t,int32_t)=[_e4 method:623463 owner:70029];
    if(!kind || !weaponID || !equipmentManager || !get)return NULL;
    int32_t weapon=weaponID(_e4.threadContext,arms),characterKind=kind(_e4.threadContext,_character4);
    param=get(_e4.threadContext,equipmentManager,weapon,characterKind);
    if([_e4 typeOf:param]!=6386)[self trace4:[NSString stringWithFormat:@"recoil default manager=%u weapon=%d characterKind=%d parameter=%u",[_e4 typeOf:equipmentManager],weapon,characterKind,[_e4 typeOf:param]]];
    return [_e4 typeOf:param]==6386 ? param : NULL;
}
- (void)recoilNote4:(NSString *)note {
    if(!_recoilNotes4)_recoilNotes4=[NSMutableSet new];
    if(_recoilNotes4.count<8 && ![_recoilNotes4 containsObject:note]){
        [_recoilNotes4 addObject:note];os_log(_log4,"RE4 recoil binding %{public}@",note);
    }
}
- (BOOL)recoil4:(RE2Feature)feature {
    void *main=(void *)r4p(_character4,0x188);
    void *(*registered)(void *,void *,int32_t)=[_e4 method:353959 owner:34293];
    void (*end)(void *,void *,BOOL)=[_e4 method:353299 owner:41015];
    if(!registered || !end || ![_e4 isObject:main kindOf:34293] || [self objectGetter:353908 owner:34293 object:main]!=_character4)return NO;
    // Player=0 is the exact CameraControlType literal in this Mac TDB.
    // The busy controller can instead be Inventory/Action/ItemGet. The native
    // shot request targets the registered Player controller independently.
    void *camera=registered(_e4.threadContext,main,0);
    void *target=[_e4 isObject:camera kindOf:41015] ? [self objectGetter:353573 owner:16441 object:camera] : NULL;
    if(![_e4 isObject:camera kindOf:41015] || (target && target!=_character4)){
        [self recoilNote4:[NSString stringWithFormat:@"registeredType=%u targetType=%u local=%d",[_e4 typeOf:camera],[_e4 typeOf:target],target==_character4]];return NO;
    }
    if(!_recoilCamera4.valid || _recoilCamera4.component!=camera){
        _recoilCamera4=[RE2Owner ownerForComponent:camera engine:_e4];
        [self recoilNote4:[NSString stringWithFormat:@"registeredType=%u weakOwner=%d targetLocal=%d targetNil=%d",[_e4 typeOf:camera],_recoilCamera4.valid,target==_character4,target==NULL]];
    }
    if(!_recoilCamera4.valid)return NO;
    void *equipment=[self equipment4],*arms=[self objectGetter:241307 owner:64794 object:equipment];
    if(![_e4 isObject:arms kindOf:28753] || [self objectGetter:240763 owner:28753 object:arms]!=equipment)return NO;
    void *param=[self recoilParameter4:arms];RE2Owner *owner=[RE2Owner ownerForComponent:arms engine:_e4];
    if([_e4 typeOf:param]!=6386 || !owner.valid)return NO;
    BOOL (^guard)(void)=^BOOL{return owner.valid && [self local4] && [self objectGetter:241307 owner:64794 object:equipment]==arms && [self objectGetter:240763 owner:28753 object:arms]==equipment && [self recoilParameter4:arms]==param;};
    float zero=0;uint64_t range=0;BOOL okay=YES;
    for(uint32_t fid=67555;fid<=67558;fid++)okay&=[self fieldBytes4:fid<=67556 ? r4bytes(&zero,4) : r4bytes(&range,8) object:param field:fid type:6386 fieldType:fid<=67556 ? 45360 : 9653 owner:owner feature:feature guard:guard];
    // requestRecoil creates a randomized per-shot copy. End that transient
    // request through the native API without baking recoil into the aim.
    void *pending=[self objectGetter:353240 owner:41015 object:camera];
    if(okay && pending){
        if([_e4 typeOf:pending]!=6386 || !_recoilCamera4.valid || registered(_e4.threadContext,main,0)!=camera)return NO;
        end(_e4.threadContext,camera,NO);
        BOOL cleared=[self objectGetter:353240 owner:41015 object:camera]==NULL;okay=okay && cleared;
        if(_recoilCancellations4<4){_recoilCancellations4++;os_log(_log4,"RE4 native shot recoil ended count=%{public}lu cleared=%{public}d",(unsigned long)_recoilCancellations4,cleared);}
    }
    return okay;
}
- (RE2FeatureState *)moneyMultiplier4:(double)value {
    RE2FeatureState *s=[RE2FeatureState new];void *inv=[_e4 singletonAt:0x1110a4d00];
    int32_t (*get)(void *,void *)=[_e4 method:111532 owner:4772];void (*set)(void *,void *,int32_t)=[_e4 method:111584 owner:4772];
    if(!isfinite(value) || value<1 || value>100 || [_e4 typeOf:inv]!=4772 || !get || !set)return s;
    int32_t n=get(_e4.threadContext,inv);if(n<0 || n>99999999)return s;
    if(!_gainMoneyReady4 || inv!=_gainMoneyObject4){_gainMoneyObject4=inv;_lastPTAS4=n;_gainMoneyReady4=YES;}
    int32_t after=n;
    if(MTRE4RewardTotal(_lastPTAS4,n,value,99999999,&after)){
        set(_e4.threadContext,inv,after);int32_t actual=get(_e4.threadContext,inv);
        os_log(_log4,"RE4 PTAS gain base=%{public}d observed=%{public}d requested=%{public}d after=%{public}d",_lastPTAS4,n,after,actual);
        _gainMoneyApplied4=actual==after;n=actual;
    }
    _lastPTAS4=n;s.available=YES;s.active=_gainMoneyApplied4;
    s.note=s.active ? @"Peseten-Einnahme multipliziert und nativ bestätigt." : @"Bereit; wartet auf eine neue Peseten-Einnahme.";return s;
}
- (RE2Owner *)mercOwner4 {
    RE2Owner *owner=[self controller4:69813];if(!owner.valid)return nil;
    void *address=[self field4:119338 owner:69813 type:13556 object:owner.component size:8];
    BOOL (*active)(void *,void *)=[_e4 method:563090 owner:69813];
    return address && r4p(address,0)==(uintptr_t)_character4 && active && active(_e4.threadContext,owner.component) ? owner : nil;
}
- (BOOL)merc4:(RE2Feature)feature {
    RE2Owner *owner=[self mercOwner4];if(!owner.valid || [self paused4])return NO;
    void *mode=owner.component,*character=_character4;NSInteger f=(NSInteger)feature;
    uint32_t rootField=f==RE4MercTimer ? 119344 : f==RE4MercCombo ? 119343 : f==RE4MercScore ? 119345 : 119346;
    uint32_t type=f==RE4MercTimer ? 15652 : f==RE4MercCombo ? 66233 : f==RE4MercScore ? 37964 : 54098;
    void *field=[self field4:rootField owner:69813 type:type object:mode size:8],*counter=(void *)r4p(field,0);
    if([_e4 typeOf:counter]!=type)return NO;[owner retainPayload:counter];
    BOOL (^guard)(void)=^BOOL{return owner.valid && [self playerContext4]==character && [self mercOwner4].component==mode && r4p([self field4:rootField owner:69813 type:type object:mode size:8],0)==(uintptr_t)counter;};
    if(f==RE4MercScore){
        int32_t (*get)(void *,void *)=[_e4 method:562905 owner:37964];void (*set)(void *,void *,int32_t)=[_e4 method:312515 owner:54503];
        if(!get || !set)return NO;int32_t n=9999999;MTRE2Engine *engine=_e4;
        // The game replaces its value wrapper when adding points. Keep the
        // baseline on the stable score counter and use the current wrapper.
        return [self applyNativeBytes:r4bytes(&n,4) object:counter tag:562905 owner:owner feature:feature guard:guard read:^NSData *{int32_t value=get(engine.threadContext,counter);return r4bytes(&value,4);} write:^(NSData *b){
            void *p=[self field4:119275 owner:37964 type:54503 object:counter size:8],*score=(void *)r4p(p,0);int32_t value=0;[b getBytes:&value length:4];
            if([engine typeOf:score]==54503)set(engine.threadContext,score,value);
        }];
    }
    if(f==RE4MercGauge){
        int32_t (*max)(void *,void *)=[_e4 method:400131 owner:54098];BOOL (*busy)(void *,void *)=[_e4 method:400124 owner:54098];
        if(!max || !busy || busy(_e4.threadContext,counter))return NO;int32_t n=max(_e4.threadContext,counter);if(n<1 || n>10)return NO;
        BOOL (*full)(void *,void *)=[_e4 method:400133 owner:54098];
        return full && [self fieldBytes4:r4bytes(&n,4) object:counter field:90069 type:54098 fieldType:11111 owner:owner feature:feature guard:guard] && full(_e4.threadContext,counter);
    }
    if(f==RE4MercCombo){BOOL (*combo)(void *,void *)=[_e4 method:562538 owner:66233];if(!combo || !combo(_e4.threadContext,counter))return NO;}
    if(f==RE4MercDuration){BOOL (*busy)(void *,void *)=[_e4 method:400124 owner:54098];if(!busy || !busy(_e4.threadContext,counter))return NO;}
    uint32_t fid=f==RE4MercTimer ? 119245 : f==RE4MercCombo ? 119222 : 90071;
    void *p=[self field4:fid owner:type type:45360 object:counter size:4];if(!p)return NO;
    float n=0;NSData *saved=[self baselineForObject:counter offset:(uint8_t *)p-(uint8_t *)counter feature:feature];
    if(saved)[saved getBytes:&n length:4];else MTReadMemory(p,&n,4);
    if(!isfinite(n) || n<0 || n>86400 || (f==RE4MercTimer && n<=0))return NO;
    return [self fieldBytes4:r4bytes(&n,4) object:counter field:fid type:type fieldType:45360 owner:owner feature:feature guard:guard];
}
- (RE2FeatureState *)mercMultiplier4:(double)value {
    RE2FeatureState *s=[RE2FeatureState new];RE2Owner *owner=[self mercOwner4];
    if(!owner.valid){_gainScoreReady4=NO;_gainScoreApplied4=NO;return s;}
    if([self paused4] || !isfinite(value) || value<1 || value>100)return s;
    if(_wanted4[@(RE4MercScore)]){_gainScoreReady4=NO;s.available=YES;s.note=@"Maximale Söldner-Punkte hat Vorrang vor dem Multiplikator.";return s;}
    void *field=[self field4:119345 owner:69813 type:37964 object:owner.component size:8],*counter=(void *)r4p(field,0);
    void *p=[self field4:119275 owner:37964 type:54503 object:counter size:8],*score=(void *)r4p(p,0);
    int32_t (*get)(void *,void *)=[_e4 method:312514 owner:54503];void (*set)(void *,void *,int32_t)=[_e4 method:312515 owner:54503];
    if([_e4 typeOf:score]!=54503 || !get || !set)return s;int32_t n=get(_e4.threadContext,score);if(n<0 || n>9999999)return s;
    if(!_gainScoreReady4 || _gainScoreObject4!=counter){_gainScoreObject4=counter;_lastScore4=n;_gainScoreReady4=YES;_gainScoreApplied4=NO;}
    int32_t after=n;if(MTRE4RewardTotal(_lastScore4,n,value,9999999,&after)){
        set(_e4.threadContext,score,after);int32_t actual=get(_e4.threadContext,score);
        os_log(_log4,"RE4 merc score gain base=%{public}d observed=%{public}d requested=%{public}d after=%{public}d",_lastScore4,n,after,actual);
        _gainScoreApplied4=after==actual;n=actual;
    }_lastScore4=n;s.available=YES;s.active=_gainScoreApplied4;s.note=s.active ? @"Söldner-Punktegewinn multipliziert und nativ bestätigt." : @"Bereit; wartet auf neue Söldner-Punkte.";return s;
}
- (BOOL)rangeScore4:(RE2Feature)feature {
    RE2Owner *owner=[self controller4:44170];if(!owner.valid || [self paused4])return NO;
    void *controller=owner.component,*stage=(void *)r4p([self field4:89674 owner:44170 type:24171 object:controller size:8],0);
    int32_t (*routine)(void *,void *)=[_e4 method:399590 owner:44170];
    if([_e4 typeOf:stage]!=24171 || !routine || routine(_e4.threadContext,controller)!=4)return NO;int32_t n=99999;void *player=_character4;
    return [self fieldBytes4:r4bytes(&n,4) object:controller field:89673 type:44170 fieldType:11111 owner:owner feature:feature guard:^BOOL{return owner.valid && [self playerContext4]==player && [self controller4:44170].component==controller && r4p([self field4:89674 owner:44170 type:24171 object:controller size:8],0)==(uintptr_t)stage;}];
}
- (BOOL)craft4:(RE2Feature)feature {
    void *manager=[self instance4:109635 owner:27483 type:63178];
    void *dict=(void *)r4p([self field4:23599 owner:63178 type:29107 object:manager size:8],0);
    if([_e4 typeOf:dict]!=29107)return NO;
    void *entries=(void *)r4p([self field4:23555 owner:29107 type:33073 object:dict size:8],0);
    void *countField=[self field4:23556 owner:29107 type:11111 object:dict size:4];uint32_t n=r4n(countField,0),capacity=r4n(entries,0x1c);
    if(!countField || [_e4 typeOf:entries]!=33073 || n>256 || capacity>1024 || n>capacity)return NO;
    NSMutableSet *seen=[NSMutableSet new];BOOL okay=YES;NSUInteger targets=0;RE2Owner *owner=_owner4;void *player=_character4;
    for(uint32_t i=0;i<n;i++){
        // Exact Dictionary<RecipeID, ItemCraftRecipe>.Entry is 24 bytes:
        // next +0, hash +4, enum key +8, managed recipe reference +16.
        uint8_t *entry=(uint8_t *)entries+0x20+i*24;if((int32_t)r4n(entry,0)<-1)continue;
        void *recipe=(void *)r4p(entry,16);if([_e4 typeOf:recipe]!=41666)continue;
        void *materials=[self objectGetter:101319 owner:41666 object:recipe];uint32_t m=r4n(materials,0x1c);
        if([_e4 typeOf:materials]!=71679 || !m || m>8)continue;[owner retainPayload:recipe];
        for(uint32_t j=0;j<m;j++){
            void *material=(void *)r4p(materials,0x20+j*8);if([_e4 typeOf:material]!=57164)continue;
            NSValue *key=[NSValue valueWithPointer:material];if([seen containsObject:key])continue;[seen addObject:key];[owner retainPayload:material];
            BOOL (^guard)(void)=^BOOL{return owner.valid && [self playerContext4]==player && [self instance4:109635 owner:27483 type:63178]==manager && r4p([self field4:23555 owner:29107 type:33073 object:dict size:8],0)==(uintptr_t)entries && r4p(entry,16)==(uintptr_t)recipe && [self objectGetter:101319 owner:41666 object:recipe]==materials && r4p(materials,0x20+j*8)==(uintptr_t)material;};
            okay&=[self nativeInt4:0 object:material getter:101240 setter:101241 type:57164 owner:owner feature:feature guard:guard];targets++;
        }
    }return okay && targets>0;
}
- (NSString *)unlockShop4 {
    void *manager=[self instance4:624057 owner:48696 type:55843];
    void *(*infos)(void *,void *)=[_e4 method:624662 owner:55843];
    void (*unlock)(void *,void *,int32_t)=[_e4 method:624673 owner:55843];
    BOOL (*unlocked)(void *,void *,int32_t)=[_e4 method:624675 owner:55843];
    if(!manager || !infos || !unlock || !unlocked)return @"Bonusshop-Daten oder Methoden fehlen.";
    void *array=infos(_e4.threadContext,manager);uint32_t n=r4n(array,0x1c);if([_e4 typeOf:array]!=30082 || n>512)return @"Bonusshop-Liste nicht bestätigt.";
    void (*retain)(void *)=(void *)_e4.retainAddress,(*release)(void *)=(void *)_e4.releaseAddress;retain(array);
    NSUInteger targets=0,confirmed=0;
    for(uint32_t i=0;i<n;i++){
        void *info=(void *)r4p(array,0x20+i*8);if([_e4 typeOf:info]!=68616)continue;
        void *price=[self field4:65358 owner:68616 type:11111 object:info size:4],*idField=[self field4:65357 owner:68616 type:8818 object:info size:4];
        if(!price || !idField || (int32_t)r4n(price,0)<=0)continue;
        int32_t id=(int32_t)r4n(idField,0);if(id<0)continue;targets++;
        if(!unlocked(_e4.threadContext,manager,id))unlock(_e4.threadContext,manager,id);
        if(unlocked(_e4.threadContext,manager,id))confirmed++;
    }release(array);
    os_log(_log4,"RE4 CP shop unlock registered=%{public}lu confirmed=%{public}lu",(unsigned long)targets,(unsigned long)confirmed);
    return targets ? [NSString stringWithFormat:@"CP-Bonusshop: %lu/%lu Freischaltungen nativ bestätigt.",(unsigned long)confirmed,(unsigned long)targets] : @"Keine bestätigten registrierten CP-Bonusshopartikel gefunden.";
}
- (RE2GameContext *)captureContext {
    RE2GameContext *s=[RE2GameContext new];if(!_e4.identified || !_e4.isGameThread){s.note=_e4.failure;return s;}
    if(!_pump4){__weak RE4NativeAdapter *w=self;[_e4 setContinuousWork:^{[w frame4];}];_pump4=YES;}
    void *c=[self playerContext4];BOOL (*valid)(void *,void *)=[_e4 method:356350 owner:13556];
    if(![_e4 isObject:c kindOf:13556] || !valid || !valid(_e4.threadContext,c)){s.kind=RE2SessionLoading;s.identity=@"re4/loading";s.note=@"Wartet auf die lokale RE4-Spielfigur.";return s;}
    void *go=[self objectGetter:356441 owner:13556 object:c],*hp=[self objectGetter:356412 owner:13556 object:c];
    RE2Owner *owner=[RE2Owner ownerForGameObject:go engine:_e4];
    if(!owner.valid || [_e4 typeOf:hp]!=55484){s.kind=RE2SessionLoading;s.identity=@"re4/loading";s.note=@"Lokaler RE4-Besitzer wird geprüft.";return s;}
    [owner retainPayload:c];[owner retainPayload:hp];_character4=c;_hp4=hp;_owner4=owner;_manager4=[_e4 singletonAt:0x1110b5f30];
    s.kind=RE2SessionSolo;s.identity=[NSString stringWithFormat:@"re4/%@/%p",owner.identity,c];s.note=@"RE4 · lokale Spielfigur und Gameplay-Thread bestätigt.";
    if(![_identity4 isEqual:s.identity]){
        _clockMicroseconds4=NO;_clockSampleWall4=0;_gainMoneyReady4=NO;_gainMoneyApplied4=NO;_gainScoreReady4=NO;_gainScoreApplied4=NO;
        _reflectionOwner4=nil;_runtimeTypes4=nil;_controllers4=nil;_scene4=NULL;_recoilCamera4=nil;
        _identity4=s.identity;os_log(_log4,"RE4 local owner confirmed health=%{public}u maximum=%{public}u bodyType=%{public}u",r4n(hp,0x14),r4n(hp,0x10),[_e4 typeOf:go]);
        [self diagnosticRoots4];
        void *clock=[_e4 singletonAt:0x1110b5f18];if([_e4 typeOf:clock]==31665)os_log(_log4,"RE4 campaign clock raw=%{public}llu",(unsigned long long)r4p(clock,0x30));
        if([NSProcessInfo.processInfo.environment[@"RE2_BINDING_SCAN"] isEqual:@"1"]){
            void *body=[self objectGetter:356434 owner:13556 object:c];os_log(_log4,"RE4 body updater type=%{public}u",[_e4 typeOf:body]);
            for(size_t o=0x10;o<0x340;o+=8){uint32_t t=[_e4 typeOf:(void *)r4p(c,o)];if(t!=UINT32_MAX)os_log(_log4,"RE4 context field=%{public}lu type=%{public}u",(unsigned long)o,t);}
        }
    }return s;
}
- (void)releaseEffects {[_wanted4 removeAllObjects];_recoilCamera4=nil;_gainMoneyReady4=NO;_gainMoneyApplied4=NO;_gainScoreReady4=NO;_gainScoreApplied4=NO;[super releaseEffects];}
- (void)frame4 {
    if(_mouseOwned4)[self setOverlayInteraction:YES];
    [self calibrateClock4];
    [self diagnosticItemNames4];
    if(!_wanted4.count)return;if(![self local4]){[self releaseEffects];return;}
    for(NSNumber *f in _wanted4.allKeys.copy)[self applyFeature:(RE2Feature)f.integerValue wanted:YES value:_wanted4[f].doubleValue];
}
- (RE2FeatureState *)applyFeature:(RE2Feature)feature wanted:(BOOL)wanted value:(double)value {
    NSInteger f=(NSInteger)feature;RE2FeatureState *s=[RE2FeatureState new];const RE2FeatureInfo *info=RE4FeatureInfoAt(f);
    if(!info || !info->implemented){s.note=@"Noch keine native RE4-Anbindung für diese Option.";return s;}
    if(!wanted){[_wanted4 removeObjectForKey:@(f)];[self releaseFeature:feature];if(f==RE4PesetasMultiplier){_gainMoneyReady4=NO;_gainMoneyApplied4=NO;}if(f==RE4MercMultiplier){_gainScoreReady4=NO;_gainScoreApplied4=NO;}if(f==RE4Recoil)_recoilCamera4=nil;s.available=YES;s.note=@"Aus.";return s;}
    if(![self local4]){s.note=@"Wartet auf den gültigen lokalen Spieler.";return s;}
    _wanted4[@(f)]=@(value);BOOL okay=NO;
    void *character=_character4,*hp=_hp4;RE2Owner *owner=_owner4;
    BOOL (^guard)(void)=^BOOL{return owner.valid && [self playerContext4]==character && [self objectGetter:356412 owner:13556 object:character]==hp;};
    if(f==RE4PesetasMultiplier)return [self moneyMultiplier4:value];
    if(f==RE4MercMultiplier)return [self mercMultiplier4:value];
    if(f==RE4God){uint8_t yes=1;okay=[self applyBytes:r4bytes(&yes,1) object:hp offset:0x18 owner:owner global:NO feature:feature guard:guard];}
    else if(f==RE4Health || f==RE4MaxHealth){
        uint32_t current=r4n(hp,0x14),maximum=r4n(hp,0x10);
        if(current>0 && maximum>0 && maximum<=50000 && current<=50000){
            if(f==RE4Health)okay=[self applyBytes:r4bytes(&maximum,4) object:hp offset:0x14 owner:owner global:NO feature:feature guard:guard];
            else if(isfinite(value) && value>=1 && value<=50000 && floor(value)==value){
                uint32_t n=(uint32_t)value;okay=[self applyBytes:r4bytes(&n,4) object:hp offset:0x10 owner:owner global:NO feature:feature guard:guard];
                if(current>n)okay&=[self applyBytes:r4bytes(&n,4) object:hp offset:0x14 owner:owner global:NO feature:feature guard:guard];
            }
        }
    }else if(f==RE4Damage)okay=[self damageFactor4:value feature:feature];
    else if(f==RE4Defense)okay=[self defense4:value feature:feature];
    else if(f==RE4Recoil)okay=[self recoil4:feature];
    else if(f==RE4RangeScore)okay=[self rangeScore4:feature];
    else if(f==RE4Craft)okay=[self craft4:feature];
    else if(f==RE4MercTimer || f==RE4MercCombo || f==RE4MercGauge || f==RE4MercDuration || f==RE4MercScore)okay=[self merc4:feature];
    else if(f==RE4Armor || f==RE4Items || f==RE4Ammo || f==RE4Knife)okay=[self inventory4:feature];
    else if(f==RE4NoReload){
        void *item=[self equippedItem4];
        int32_t (*maximum)(void *,void *)=[_e4 method:97628 owner:70989],(*type)(void *,void *)=[_e4 method:91707 owner:50224];
        if([_e4 isObject:item kindOf:70989] && maximum && type && type(_e4.threadContext,item)==5 && [[self items4] containsObject:[NSValue valueWithPointer:item]]){
            int32_t n=maximum(_e4.threadContext,item);if(n>0 && n<=1000){
                [owner retainPayload:item];
                BOOL (^bound)(void)=^BOOL{return guard() && [self equippedItem4]==item;};
                okay=[self applyBytes:r4bytes(&n,4) object:item offset:0x44 owner:owner global:NO feature:feature guard:bound];
            }
        }
    }else if(f==RE4PlayerSpeed || f==RE4AISpeed){
        if([self paused4]){[self releaseFeature:feature];s.available=YES;s.note=@"Animationstempo pausiert im Spielmenü.";return s;}
        okay=[self motionSpeed4:value feature:feature];
    }else if(f==RE4EasyKills)okay=[self easyKills4:feature];
    else if(f==RE4Accuracy){
        void *equipment=[self equipment4],*arms=[self objectGetter:241307 owner:64794 object:equipment];
        if([_e4 isObject:arms kindOf:28753] && [self objectGetter:240763 owner:28753 object:arms]==equipment){
            void *param=[self objectGetter:240771 owner:28753 object:arms];RE2Owner *weaponOwner=[RE2Owner ownerForComponent:arms engine:_e4];
            if([_e4 typeOf:param]==1379 && weaponOwner.valid){
                const uint32_t getters[]={67509,67511,67513,67517};okay=YES;
                for(NSUInteger i=0;i<4;i++)okay&=[self nativeFloat4:i==0 ? 10000 : 0 object:param getter:getters[i] setter:getters[i]+1 type:1379 owner:weaponOwner feature:feature guard:^BOOL{return weaponOwner.valid && [self objectGetter:240763 owner:28753 object:arms]==equipment;}];
            }
        }
    }else if(f==RE4FOV && isfinite(value) && value>=30 && value<=120){
        void *cameraController=(void *)r4p(_character4,0x188);
        if([_e4 isObject:cameraController kindOf:34293] && [self objectGetter:353908 owner:34293 object:cameraController]==_character4){
            void *camera=[self objectGetter:353905 owner:34293 object:cameraController];RE2Owner *cameraOwner=[RE2Owner ownerForComponent:camera engine:_e4];float (*get)(void *,void *)=[_e4 method:12547 owner:1406];
            if([_e4 isObject:camera kindOf:1406] && cameraOwner.valid && get){
                float original=get(_e4.threadContext,camera);NSData *base=[self baselineForNativeObject:camera tag:12547 feature:feature];if(base)[base getBytes:&original length:4];
                float n=(float)value;
                okay=isfinite(original) && original>0 && original<180 && [self nativeFloat4:n object:camera getter:12547 setter:12548 type:1406 owner:cameraOwner feature:feature guard:^BOOL{return cameraOwner.valid && [self objectGetter:353905 owner:34293 object:cameraController]==camera;}];
            }
        }
    }else if(f==RE4GameSpeed && isfinite(value) && value>=0.1 && value<=3){
        if([self paused4]){[self releaseFeature:feature];s.available=YES;s.note=@"Spieltempo pausiert im Spielmenü.";return s;}
        void *app=[_e4 singletonAt:0x10cbd1d20];float original=0;NSData *base=[self baselineForObject:app offset:0x248 feature:feature];
        if(base)[base getBytes:&original length:4];else MTReadMemory((uint8_t *)app+0x248,&original,4);
        float n=original*(float)value;if(isfinite(original) && original>0 && original<=10 && isfinite(n) && n>0)okay=[self applyBytes:r4bytes(&n,4) object:app offset:0x248 owner:nil global:YES feature:feature];
    }else if(f==RE4FreezeTime){
        void *clock=[_e4 singletonAt:0x1110b5f18];uint64_t n=0;
        if([_e4 typeOf:clock]==31665){
            NSData *base=[self baselineForObject:clock offset:0x30 feature:feature];if(base)[base getBytes:&n length:8];else MTReadMemory((uint8_t *)clock+0x30,&n,8);
            [owner retainPayload:clock];okay=[self applyBytes:r4bytes(&n,8) object:clock offset:0x30 owner:owner global:NO feature:feature guard:^BOOL{return guard() && [_e4 singletonAt:0x1110b5f18]==clock;}];
        }
    }
    if(!okay)[self releaseFeature:feature];s.available=okay;s.active=okay;s.note=okay ? @"In RE4 angewandt und nativ zurückgelesen." : @"Wartet auf passende lokale RE4-Daten.";return s;
}
- (NSString *)performOneShot:(RE2Feature)feature value:(double)value {
    if(![self local4])return @"Kein bestätigter lokaler RE4-Kontext.";
    if((NSInteger)feature==RE4Tickets || (NSInteger)feature==RE4GoldTokens || (NSInteger)feature==RE4SilverTokens)return [self inventoryCurrency4:feature value:value];
    if((NSInteger)feature==RE4Unlock)return [self unlockShop4];
    if((NSInteger)feature==RE4AdjustTime){
        if(!_clockMicroseconds4)return @"Wartet auf die unabhängige Bestätigung der nativen Zeiteinheit.";
        void *clock=[_e4 singletonAt:0x1110b5f18];uint64_t (*get)(void *,void *)=[_e4 method:620848 owner:31665];void (*set)(void *,void *,uint64_t)=[_e4 method:620849 owner:31665];
        if([_e4 typeOf:clock]!=31665 || !get || !set)return @"Kampagnenuhr fehlt.";
        uint64_t before=get(_e4.threadContext,clock),n=0;if(!MTRE4AdjustClock(before,value,&n))return @"Ungültige Zeitkorrektur.";
        [self releaseFeature:(RE2Feature)RE4FreezeTime];
        set(_e4.threadContext,clock,n);uint64_t after=get(_e4.threadContext,clock);
        os_log(_log4,"RE4 clock adjust before=%{public}llu requested=%{public}llu after=%{public}llu",(unsigned long long)before,(unsigned long long)n,(unsigned long long)after);
        return after==n ? @"Spielzeit korrigiert und nativ bestätigt." : @"Zeitkorrektur nicht bestätigt.";
    }
    if((NSInteger)feature==RE4Spinels || (NSInteger)feature==RE4SaveCount || (NSInteger)feature==RE4CP){
        if(!isfinite(value) || value<0 || value>99999999 || floor(value)!=value)return @"Ungültiger RE4-Zählerwert.";
        BOOL spinel=(NSInteger)feature==RE4Spinels,save=(NSInteger)feature==RE4SaveCount;
        void *object=[self instance4:spinel ? 296918 : save ? 55407 : 624057 owner:spinel ? 24679 : save ? 30103 : 48696 type:spinel ? 59361 : save ? 16751 : 55843];
        uint32_t type=spinel ? 59361 : save ? 16751 : 55843,gid=spinel ? 303930 : save ? 56783 : 624666,sid=spinel ? 304013 : save ? 56784 : 624667;
        int32_t (*get)(void *,void *)=[_e4 method:gid owner:type];void (*set)(void *,void *,int32_t)=[_e4 method:sid owner:type];
        if(!object || !get || !set)return @"RE4-Zählerbesitzer oder native Methoden fehlen.";
        int32_t before=get(_e4.threadContext,object),requested=save ? 0 : (int32_t)value;
        if(before<0 || before>99999999)return @"RE4-Ausgangswert außerhalb des bestätigten Bereichs.";
        // CP exposes an additive native API; apply exactly one bounded delta.
        int32_t argument=(NSInteger)feature==RE4CP ? requested-before : requested;
        set(_e4.threadContext,object,argument);int32_t after=get(_e4.threadContext,object);
        os_log(_log4,"RE4 one-shot feature=%{public}ld before=%{public}d requested=%{public}d after=%{public}d",(long)feature,before,requested,after);
        return after==requested ? @"RE4-Zähler gesetzt und nativ bestätigt." : @"RE4-Zähleränderung nicht bestätigt.";
    }
    if((NSInteger)feature==RE4Pesetas && isfinite(value) && value>=0 && value<=99999999 && floor(value)==value){
        void *inv=[_e4 singletonAt:0x1110a4d00];int32_t (*get)(void *,void *)=[_e4 method:111532 owner:4772];void (*set)(void *,void *,int32_t)=[_e4 method:111533 owner:4772];
        if([_e4 typeOf:inv]!=4772 || !get || !set)return @"RE4-Pesetendaten fehlen.";
        int32_t before=get(_e4.threadContext,inv);set(_e4.threadContext,inv,(int32_t)value);int32_t after=get(_e4.threadContext,inv);
        if(_gainMoneyReady4 && _gainMoneyObject4==inv)_lastPTAS4=after;
        os_log(_log4,"RE4 pesetas before=%{public}d after=%{public}d",before,after);return after==(int32_t)value ? @"Peseten gesetzt und nativ bestätigt." : @"Pesetenänderung nicht bestätigt.";
    }return @"Diese RE4-Einmalaktion ist noch nicht angebunden.";
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {
    if(!_e4.isGameThread)return NO;
    // UI mouse belongs to the process HID device, not a loaded player context.
    void *device=[_e4 singletonAt:0x10cd8d9e8];const size_t offsets[]={0x160,0x161,0x163};const uint8_t values[]={1,0,1};
    if(_mouseOwned4 && (device!=_mouseDevice4 || !wanted)){
        BOOL okay=YES;if(device==_mouseDevice4)for(NSUInteger i=0;i<3;i++){uint8_t v=0;if(MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==values[i])okay&=MTWriteByte(device,offsets[i],_mouseBefore4[i]) && MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==_mouseBefore4[i];}
        _mouseOwned4=NO;os_log(_log4,"RE4 native mouse released readback=%{public}d",okay);
    }
    if(!wanted || !device)return NO;BOOL first=!_mouseOwned4;
    if(first){for(NSUInteger i=0;i<3;i++)if(!MTReadMemory((uint8_t *)device+offsets[i],&_mouseBefore4[i],1) || _mouseBefore4[i]>1)return NO;_mouseDevice4=device;_mouseOwned4=YES;}
    // Mouse ownership is independent of gameplay pause. Menus can change
    // their native input request while our UI lease remains active. Preserve
    // each observed foreign request for release, then reapply our own values.
    uint8_t observed[3];for(NSUInteger i=0;i<3;i++)if(!MTReadMemory((uint8_t *)device+offsets[i],&observed[i],1) || observed[i]>1)return NO;
    if(!first)for(NSUInteger i=0;i<3;i++)if(observed[i]!=values[i])_mouseBefore4[i]=observed[i];
    BOOL okay=YES;for(NSUInteger i=0;i<3;i++){uint8_t v=0;okay&=MTWriteByte(device,offsets[i],values[i]) && MTReadMemory((uint8_t *)device+offsets[i],&v,1) && v==values[i];}
    if(first)os_log(_log4,"RE4 native mouse acquired readback=%{public}d",okay);return okay;
}
@end
