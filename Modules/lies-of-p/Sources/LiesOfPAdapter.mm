// SPDX-License-Identifier: GPL-3.0-only
#import "LiesOfPAdapter.h"
#import "LiesOfPBuild.h"
#import "MemoryAccess.h"
#import "PlatformCursor.h"
#import <mach-o/dyld.h>
#import <objc/message.h>
#include <math.h>
#include <string.h>

// All constants are specific to the UUID in LiesOfPBuild.h. No code pages are patched.
namespace {
struct Weak { int32_t index=-1, serial=0; };
struct Vector { float x,y,z; };
struct FString { const char16_t *data; int32_t count, capacity; };
static intptr_t slide;
static const mach_header_64 *mainHeader(uint32_t *index) {
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const mach_header_64 *h=(const mach_header_64 *)_dyld_get_image_header(i);
        if(h && h->magic==MH_MAGIC_64 && h->filetype==MH_EXECUTE){if(index)*index=i;return h;}
    }return nullptr;
}
static uintptr_t at(uintptr_t p) { return p+slide; }
static uintptr_t ptr(uintptr_t p) { uintptr_t n=0; MTReadMemory((void *)p,&n,sizeof(n));return n; }
static int32_t integer(uintptr_t p) { int32_t n=0;MTReadMemory((void *)p,&n,sizeof(n));return n; }
static uint8_t byte(uintptr_t p) { uint8_t n=0;MTReadMemory((void *)p,&n,1);return n; }
static float real(uintptr_t p) { float n=NAN;MTReadMemory((void *)p,&n,4);return n; }
static MTPlatformCursorState platformCursorState(void) {
    MTPlatformCursorState s={};
    // FMacApplication owns its cursor through GenericApplication::Cursor.
    // Constructor/vtable, +8 shared pointer and FMacCursor fields were checked
    // in this build. These native objects are not UObjects.
    uintptr_t app=ptr(at(0x1066bf850));
    if(!app || ptr(app)!=at(0x105a6a838))return s;
    uintptr_t cursor=ptr(app+8),reference=ptr(app+0x10);
    if(!cursor || !reference || ptr(cursor)!=at(0x105a6ad18))return s;
    s.application=app;s.cursor=cursor;s.reference=reference;
    s.type=integer(cursor+8);s.overrideType=integer(cursor+0x120);
    s.visible=byte(cursor+0x110)!=0;s.hasShape=ptr(cursor+0x118)!=0;s.hasDefaultShape=ptr(cursor+0x18)!=0;
    s.free=byte(app+0x88)==0 && byte(cursor+0x111)==0 && integer(cursor+0x100)==0 && integer(cursor+0x104)==0 && integer(cursor+0x108)==0 && integer(cursor+0x10c)==0;
    return s;
}
static BOOL object(uintptr_t p) {
    int32_t i=-1;if(!p || !MTReadMemory((void *)(p+12),&i,4) || i<0)return NO;
    uintptr_t a=at(0x1066bd2b0);int32_t count=integer(a+0x24);
    if(count<=0 || count>10000000 || i>=count)return NO;
    uintptr_t chunk=ptr(ptr(a+0x10)+(uint32_t(i)>>16)*8);
    uintptr_t item=chunk+(uint32_t(i)&65535)*24;
    return chunk && ptr(item)==p && !(uint32_t(integer(item+8))&0x30000000) && !(uint32_t(integer(p+8))&0x18030);
}
static Weak weak(uintptr_t p) {
    Weak w;if(object(p))((void(*)(Weak *,uintptr_t))at(LOPWeakAssign))(&w,p);return w;
}
static uintptr_t get(Weak w) { return w.serial ? ((uintptr_t(*)(const Weak *))at(LOPWeakGet))(&w) : 0; }
static BOOL isClass(uintptr_t p,uintptr_t cls) {
    if(!object(p)||!object(cls))return NO;
    uintptr_t actual=ptr(p+0x10);int32_t i=integer(cls+0x38),n=integer(actual+0x38);
    return i>=0 && i<=n && n<4096 && ptr(ptr(actual+0x30)+i*8)==cls+0x30;
}
static int32_t stat(uintptr_t owner,uint8_t id) {return ((int32_t(*)(uintptr_t,uint8_t))at(LOPStatGet))(owner,id);}
static uintptr_t datum(uintptr_t owner,uint8_t id) {
    uintptr_t list=ptr(owner+0xe0);int32_t n=integer(list+0x30);
    if(!object(owner)||!object(list)||!id||n<id||n>1024)return 0;
    uintptr_t d=((uintptr_t(*)(uintptr_t,uint8_t))at(LOPStatData))(owner,id);
    return d==ptr(list+0x28)+(id-1)*40 ? d : 0;
}
static void setStat(uintptr_t owner,uint8_t id,int32_t value) {
    ((void(*)(uintptr_t,uint8_t,int32_t,bool,bool))at(LOPStatSet))(owner,id,value,false,true);
}
static int32_t partial(uintptr_t owner,uint8_t id) {return ((int32_t(*)(uintptr_t,uint8_t,uint8_t))at(LOPPartialGet))(owner,1,id);}
static void setPartial(uintptr_t owner,uint8_t id,int32_t n) {((void(*)(uintptr_t,uint8_t,uint8_t,int32_t,bool,bool))at(LOPPartialSet))(owner,1,id,n,false,true);}
// Non-trivial return type deliberately selects the engine's arm64 x8 sret ABI.
struct ActorArray {
    uintptr_t *data=nullptr; int32_t count=0,capacity=0;
    ~ActorArray() {if(data)((void(*)(void *))at(LOPFree))(data);}
};
static BOOL buildMatches(void) {
    uint32_t mainIndex=0;const mach_header_64 *h=mainHeader(&mainIndex);
    if(!h||h->magic!=MH_MAGIC_64||h->cputype!=CPU_TYPE_ARM64||h->filetype!=MH_EXECUTE)return NO;
    const uint8_t *p=(const uint8_t *)(h+1),*end=p+h->sizeofcmds;BOOL uuid=NO;
    for(uint32_t i=0;i<h->ncmds;i++){
        if(p+sizeof(load_command)>end)return NO;const load_command *c=(const load_command *)p;
        if(c->cmdsize<sizeof(*c)||c->cmdsize>(size_t)(end-p))return NO;
        if(c->cmd==LC_UUID&&c->cmdsize==sizeof(uuid_command))uuid=[[[NSUUID alloc]initWithUUIDBytes:((const uuid_command *)c)->uuid].UUIDString isEqual:LOP_BUILD_UUID];
        p+=c->cmdsize;
    }
    if(!uuid)return NO;slide=_dyld_get_image_vmaddr_slide(mainIndex);
    for(const auto &c:LOPCodeChecks){uint8_t bytes[16];if(!MTReadMemory((void *)at(c.address),bytes,16)||memcmp(bytes,c.bytes,16))return NO;}
    return YES;
}
static NSData *weakData(Weak w) {return [NSData dataWithBytes:&w length:sizeof(w)];}
static Weak dataWeak(NSData *data) {Weak w;if(data.length==sizeof(w))memcpy(&w,data.bytes,sizeof(w));return w;}
static uint8_t editStat(MTFeature f) {
    switch(f){case MTFeatureCurrentHealth:return 1;case MTFeatureMaxHealth:return 71;
    case MTFeatureCurrentStamina:return 2;case MTFeatureMaxStamina:return 72;
    case MTFeatureCurrentLegion:return 5;case MTFeatureMaxLegion:return 75;
    case MTFeatureMaxWeight:return 8;case MTFeatureFireResistance:return 122;
    case MTFeatureElectricResistance:return 123;case MTFeatureAcidResistance:return 124;default:return 0;}
}
}

@interface LOPGameAdapter () {
    BOOL _valid,_selected[MTFeatureCount];
    BOOL _mouseOwned;Weak _mouseController,_mouseViewport,_mouseInput;
    MTPlatformCursorLease *_platformCursor;
    uint8_t _cursorOriginal,_captureOriginal,_lockOriginal,_hideOriginal,_lookOriginal,_moveOriginal,_captureOwned;
    double _parameters[MTFeatureCount];
    uintptr_t _world,_player,_stats,_data,_save,_items,_inventory,_equipment,_controller;
    Weak _playerWeak,_statsWeak,_worldWeak,_inventoryWeak,_equipmentWeak,_saveWeak,_controllerWeak,_reason,_stealthOwner;
    uint64_t _stealthName; BOOL _stealthOwned;
    NSString *_savedContext;Vector _savedPosition,_savedRotation;
    NSMutableDictionary<NSString *,NSMutableDictionary *> *_writes,*_contributions;
    NSMutableSet<NSString *> *_conflicts;
}
@end
@implementation LOPGameAdapter
- (instancetype)init {
    if((self=[super init])){
        _writes=[NSMutableDictionary new];_contributions=[NSMutableDictionary new];_conflicts=[NSMutableSet new];
        for(NSInteger i=0;i<MTFeatureCount;i++)_parameters[i]=MTFeatureInfoAt((MTFeature)i)->initial;
        _valid=[NSBundle.mainBundle.bundleIdentifier isEqual:@"com.neowiz.game.lop.steam"] && buildMatches();
    }return self;
}
- (void)onGameThread:(dispatch_block_t)work {
    if(!_valid){dispatch_async(dispatch_get_main_queue(),work);return;}
    id thread=((id(*)(id,SEL))objc_msgSend)(NSThread.class,NSSelectorFromString(@"gameThread"));
    if(!thread || !ptr(at(0x10666efe8))){dispatch_async(dispatch_get_main_queue(),work);return;}
    ((void(*)(dispatch_block_t,NSArray *,bool))at(LOPGameThreadCall))(work,@[NSDefaultRunLoopMode],false);
}
- (BOOL)isGameThread {
    return _valid && [NSThread respondsToSelector:NSSelectorFromString(@"isGameThread")] && ((BOOL(*)(id,SEL))objc_msgSend)(NSThread.class,NSSelectorFromString(@"isGameThread"));
}
- (NSString *)identity {
    return [NSString stringWithFormat:@"%d:%d/%d:%d/%d:%d/%d:%d/%d:%d/%d:%d/%d:%d",_worldWeak.index,_worldWeak.serial,_playerWeak.index,_playerWeak.serial,_statsWeak.index,_statsWeak.serial,_inventoryWeak.index,_inventoryWeak.serial,_equipmentWeak.index,_equipmentWeak.serial,_saveWeak.index,_saveWeak.serial,_controllerWeak.index,_controllerWeak.serial];
}
- (MTGameContext *)captureContext {
    MTGameContext *c=[MTGameContext new];
    if(!_valid){c.note=@"Nur Lies of P Steam 1.14.0 arm64 mit passender UUID und nativen Funktionsbytes.";return c;}
    c.kind=MTSessionLoading;c.identity=@"loading";c.note=@"Wartet auf lokalen Spieler und GameThread.";
    if(![self isGameThread])return c;
    _world=ptr(at(0x10673d830));
    if(!object(_world)){c.note=@"Spielwelt noch nicht gültig.";return c;}
    uintptr_t manager=ptr(at(0x1063021f8));
    if(!object(manager)){c.note=@"Objektverwaltung noch nicht gültig.";return c;}
    _player=((uintptr_t(*)(uintptr_t,int))at(LOPGameplayPlayer))(_world,0);
    if(!object(_player)||!isClass(_player,((uintptr_t(*)())at(LOPPlayerClass))())){c.note=@"Lokale Spielfigur noch nicht gültig.";return c;}
    _controller=((uintptr_t(*)(uintptr_t,int))at(LOPGetController))(_world,0);
    if(!object(_controller)||!((bool(*)(uintptr_t))at(LOPLocalController))(_controller)){c.note=@"Lokaler Controller noch nicht gültig.";return c;}
    // Both engine paths must resolve the same possessed pawn, never an Outer guess.
    uintptr_t registered=((uintptr_t(*)(uintptr_t))at(LOPGetPlayer))(manager);
    if(registered && registered!=_player){c.note=@"Spielerregistrierung und lokaler Pawn stimmen noch nicht überein.";return c;}
    _stats=ptr(_player+0x8c0);Weak statOwner; if(!object(_stats)||!MTReadMemory((void *)(_stats+0xb0),&statOwner,sizeof(statOwner))||get(statOwner)!=_player){c.note=@"Stat-Besitzer noch nicht bestätigt.";return c;}
    if(!datum(_stats,1)||stat(_stats,71)<=0){c.note=@"Statliste noch nicht bereit.";return c;}
    _data=ptr(at(0x106302200));_save=object(_data)?ptr(_data+0xa0):0;
    _items=ptr(at(0x106302220));_inventory=object(_items)?ptr(_items+0x180):0;_equipment=object(_items)?ptr(_items+0x188):0;
    _worldWeak=weak(_world);_playerWeak=weak(_player);_statsWeak=weak(_stats);_inventoryWeak=weak(_inventory);_equipmentWeak=weak(_equipment);_saveWeak=weak(_save);_controllerWeak=weak(_controller);
    c.kind=MTSessionSolo;c.identity=self.identity;c.note=@"Lies of P 1.14.0 · lokaler Besitzer und Einzelspieler bestätigt.";return c;
}
// A record owns only bytes last written by this adapter. Changed external values win.
- (uintptr_t)addressOf:(NSDictionary *)r {
    uintptr_t owner=[r[@"owner"] unsignedLongLongValue];
    if(owner && get(dataWeak(r[@"weak"]))!=owner)return 0;
    uintptr_t base=[r[@"base"] unsignedLongLongValue];uint8_t id=[r[@"stat"] unsignedCharValue];
    if(id && datum(owner,id)!=base)return 0;
    return base+[r[@"offset"] unsignedLongLongValue];
}
- (void)restorePrefix:(NSString *)prefix {
    for(NSString *key in _writes.allKeys)if(!prefix.length || [key hasPrefix:prefix]){
        NSDictionary *r=_writes[key];uintptr_t p=[self addressOf:r];NSData *last=r[@"last"],*original=r[@"original"];
        uint8_t bytes[64];if(p && MTReadMemory((void *)p,bytes,last.length)&&!memcmp(bytes,last.bytes,last.length))MTWriteMemory((void *)p,original.bytes,original.length);
        [_writes removeObjectForKey:key];
    }
    for(NSString *key in _contributions.allKeys)if(!prefix.length || [key hasPrefix:prefix]){
        NSDictionary *r=_contributions[key];uintptr_t owner=get(dataWeak(r[@"weak"]));uint8_t id=[r[@"stat"] unsignedCharValue];
        if(owner && datum(owner,id) && partial(owner,id)==[r[@"lastPartial"] intValue]){int64_t n=int64_t(partial(owner,id))-[r[@"delta"] intValue];if(n>=INT32_MIN&&n<=INT32_MAX)setPartial(owner,id,(int32_t)n);}
        [_contributions removeObjectForKey:key];
    }
    for(NSString *key in _conflicts.allObjects)if(!prefix.length || [key hasPrefix:prefix])[_conflicts removeObject:key];
}
- (BOOL)write:(NSString *)key owner:(uintptr_t)owner base:(uintptr_t)base stat:(uint8_t)id offset:(size_t)offset bytes:(const void *)bytes length:(size_t)n {
    if(n>64||!base||[_conflicts containsObject:key])return NO;
    NSMutableDictionary *r=_writes[key];
    if(r && ([r[@"base"] unsignedLongLongValue]!=base||![self addressOf:r])){[self restorePrefix:key];r=nil;}
    uintptr_t address=base+offset;uint8_t previous[64];if(!MTReadMemory((void *)address,previous,n))return NO;
    if(r && (n!=[r[@"last"] length]||memcmp(previous,[r[@"last"] bytes],n))){[_conflicts addObject:key];return NO;}
    if(!r){r=[@{@"owner":@(owner),@"weak":weakData(owner?weak(owner):Weak{}),@"base":@(base),@"offset":@(offset),@"stat":@(id),@"original":[NSData dataWithBytes:previous length:n],@"last":[NSData dataWithBytes:previous length:n]} mutableCopy];_writes[key]=r;}
    if(!MTWriteMemory((void *)address,bytes,n))return NO;
    r[@"last"]=[NSData dataWithBytes:bytes length:n];uint8_t readback[64];return MTReadMemory((void *)address,readback,n)&&!memcmp(bytes,readback,n);
}
- (BOOL)fixed:(uint8_t)id target:(int32_t)value prefix:(NSString *)prefix {
    uintptr_t d=datum(_stats,id);if(!d||byte(d+0x15)!=1)return NO;
    uint8_t yes=1;
    BOOL a=[self write:[prefix stringByAppendingString:@"value"] owner:_stats base:d stat:id offset:0x10 bytes:&value length:4];
    BOOL b=[self write:[prefix stringByAppendingString:@"fixed"] owner:_stats base:d stat:id offset:0x14 bytes:&yes length:1];
    return a&&b&&stat(_stats,id)==value;
}
- (BOOL)factor:(double)factor stat:(uint8_t)id key:(NSString *)key {
    if(!datum(_stats,id)||[_conflicts containsObject:key])return NO;
    NSMutableDictionary *r=_contributions[key];
    if(r && get(dataWeak(r[@"weak"]))!=_stats){[self restorePrefix:key];r=nil;}
    int32_t currentPartial=partial(_stats,id);
    if(r && currentPartial!=[r[@"lastPartial"] intValue]){[_conflicts addObject:key];return NO;}
    int32_t previous=r?[r[@"delta"] intValue]:0;int32_t current=stat(_stats,id);
    int64_t base=int64_t(current)-previous;
    if(base<INT32_MIN||base>INT32_MAX)return NO;
    int64_t delta=llround(base*(factor-1.0));
    if(id==177)delta=llround((factor-1.0)*10000);
    int64_t next=int64_t(currentPartial)-previous+delta;
    if(next<INT32_MIN||next>INT32_MAX||delta<INT32_MIN||delta>INT32_MAX||base+delta<INT32_MIN||base+delta>INT32_MAX)return NO;
    if(!r){r=[@{@"weak":weakData(_statsWeak),@"stat":@(id),@"delta":@0} mutableCopy];_contributions[key]=r;}
    setPartial(_stats,id,(int32_t)next);r[@"delta"]=@(delta);r[@"lastPartial"]=@(next);
    return partial(_stats,id)==next && stat(_stats,id)==base+delta;
}
- (void)releaseStealth {
    uintptr_t owner=get(_stealthOwner),reason=get(_reason);
    if(_stealthOwned&&owner&&reason)((bool(*)(uintptr_t,uint64_t,bool,uintptr_t,uint8_t,bool))at(LOPRemoveState))(owner,_stealthName,true,reason,0,false);
    _stealthOwned=NO;_stealthOwner=Weak{};
}
- (void)releaseEffects {
    if(_valid&&[self isGameThread]){[self releaseStealth];[self restorePrefix:@""];}
    memset(_selected,0,sizeof(_selected));
}
- (BOOL)stealth {
    uintptr_t mgr=((uintptr_t(*)(uintptr_t))at(LOPGetActMgr))(_player);
    if(!object(mgr))return NO;
    uintptr_t reason=get(_reason);
    if(!reason){
        uintptr_t cls=((uintptr_t(*)())at(LOPObjectClass))();uintptr_t outer=((uintptr_t(*)())at(LOPTransientPackage))();
        reason=((uintptr_t(*)(uintptr_t,uintptr_t,uint64_t,uint32_t,uintptr_t,bool,uintptr_t,uintptr_t))at(LOPCreateObject))(outer,cls,0,0xc0,0,false,0,0);
        if(!object(reason))return NO;_reason=weak(reason);
    }
    _stealthName=ptr(at(0x106615318)); // ULActionState::AITargetList_Disable_Player; paired with our own engine UObject.
    if(!_stealthName)return NO;
    if(_stealthOwned&&get(_stealthOwner)!=mgr)[self releaseStealth];
    if(!_stealthOwned){
        static const char16_t text[]=u"LiesOfPTrainer.Stealth";FString debug={text,int32_t(sizeof(text)/2),int32_t(sizeof(text)/2)};
        _stealthOwned=((bool(*)(uintptr_t,uint64_t,bool,uintptr_t,uintptr_t,uint8_t,const FString *))at(LOPAddState))(mgr,_stealthName,true,reason,0,0,&debug);
        if(_stealthOwned)_stealthOwner=weak(mgr);
    }
    return _stealthOwned&&((bool(*)(uintptr_t,uint64_t))at(LOPFindState))(mgr,_stealthName);
}
- (BOOL)aiFactor:(double)factor {
    uintptr_t manager=ptr(at(0x1063021f8));if(!object(manager))return NO;
    ActorArray enemies=((ActorArray(*)(uintptr_t,uint8_t,uintptr_t))at(LOPEnemies))(manager,1,_player);
    if(enemies.count<0||enemies.count>4096||enemies.capacity<enemies.count||enemies.capacity>65536)return NO;
    NSMutableSet *seen=[NSMutableSet new];BOOL ok=YES;NSUInteger applied=0;
    uintptr_t cls=((uintptr_t(*)())at(LOPNPCClass))();
    for(int32_t i=0;i<enemies.count;i++){
        uintptr_t p=0;if(!MTReadMemory(enemies.data+i,&p,8)||!isClass(p,cls))continue;
        Weak w=weak(p);if(!get(w))continue;
        NSString *key=[NSString stringWithFormat:@"ai/%d:%d/",w.index,w.serial];[seen addObject:key];
        NSDictionary *r=_writes[key];float baseline=r?*(const float *)[r[@"original"] bytes]:real(p+0x98);
        float target=baseline*factor;if(!isfinite(target)||target<0.001f||target>100)continue;
        ok=[self write:key owner:p base:p stat:0 offset:0x98 bytes:&target length:4]&&ok;applied++;
    }
    for(NSString *key in _writes.allKeys)if([key hasPrefix:@"ai/"]&&![seen containsObject:key])[self restorePrefix:key];
    return ok&&applied>0;
}
- (MTFeatureState *)applyFeature:(MTFeature)f wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *s=[MTFeatureState new];s.available=_valid&&[self isGameThread];s.note=@"Bereit; Wirkung wird nach Anwendung zurückgelesen.";
    if(!s.available || !MTFeatureInfoAt(f)){s.available=NO;return s;}
    _parameters[f]=value;_selected[f]=wanted;
    if(MTFeatureInfoAt(f)->oneShot){
        s.available=f!=MTFeatureTeleport||[_savedContext isEqual:self.identity];uint8_t id=editStat(f);
        if(id)s.note=[NSString stringWithFormat:@"Aktuell im Spiel: %d · LOS setzt den eingegebenen Zielwert.",stat(_stats,id)];
        else if(f==MTFeatureErgo && object(_save))s.note=[NSString stringWithFormat:@"Aktuell: %d Ergo · Änderungen können gespeichert werden.",((int32_t(*)(uintptr_t))at(LOPGetErgo))(_data)];
        else if(f==MTFeatureTimePlayed && object(_save)){double seconds=0;MTReadMemory((void *)(_save+0x70),&seconds,8);s.note=[NSString stringWithFormat:@"Aktuell: %.0f Sekunden · LOS setzt den Zielwert.",seconds];}
        else if(f==MTFeatureItemQuantity)s.note=@"Gewähltes Schnellzugriffs-Item; LOS beachtet eigene Inventarzugehörigkeit und Stapelgrenze.";
        return s;
    }
    NSString *prefix=[NSString stringWithFormat:@"f%ld/",(long)f];
    if(!wanted){
        [self restorePrefix:prefix];
        if(f==MTFeatureStealth)[self releaseStealth];
        if((f==MTFeatureSlowAI||f==MTFeatureAIMultiplier)&&!_selected[MTFeatureSlowAI]&&!_selected[MTFeatureAIMultiplier])[self restorePrefix:@"ai/"];
        if((f==MTFeatureSpeed||f==MTFeaturePlayerMultiplier)&&!_selected[MTFeatureSpeed]&&!_selected[MTFeaturePlayerMultiplier])[self restorePrefix:@"player-speed/"];
        if((f==MTFeatureMovement||f==MTFeatureMovementMultiplier)&&!_selected[MTFeatureMovement]&&!_selected[MTFeatureMovementMultiplier])[self restorePrefix:@"movement/"];
        return s;
    }
    switch(f){
    case MTFeatureHealth:case MTFeatureStamina:case MTFeatureLegion:{uint8_t id=f==MTFeatureHealth?1:f==MTFeatureStamina?2:5;uint8_t max=id==1?71:id==2?72:75;s.active=[self fixed:id target:stat(_stats,max) prefix:prefix];break;}
    case MTFeatureOneHit:case MTFeatureItemUsage:{uint8_t yes=1;uintptr_t address=at(f==MTFeatureOneHit?0x106300e74:0x106616d40);s.active=[self write:prefix owner:0 base:address stat:0 offset:0 bytes:&yes length:1];break;}
    case MTFeatureFreezeTime:{uint8_t no=0;s.available=object(_data);if(s.available)s.active=[self write:prefix owner:_data base:_data stat:0 offset:0x80 bytes:&no length:1];break;}
    case MTFeaturePotions:{
        if(!object(_inventory)){s.available=NO;break;}
        uintptr_t pulse=((uintptr_t(*)(uintptr_t))at(LOPPulseGet))(_inventory);
        if(!object(pulse)){s.available=NO;break;}
        // Refill through the native pulse implementation; no items are created.
        ((void(*)(uintptr_t))at(LOPPulseRecharge))(pulse);
        s.active=integer(pulse+0x40)>0;s.note=@"Pulszellen werden nativ aufgefüllt; aufgefüllte Mengen können gespeichert werden.";break;}
    case MTFeatureSpeed:case MTFeaturePlayerMultiplier:{
        float baseline=_writes[@"player-speed/"]?*(const float *)[_writes[@"player-speed/"][@"original"] bytes]:real(_player+0x98);
        float target=baseline*_parameters[MTFeaturePlayerMultiplier];s.active=isfinite(target)&&[self write:@"player-speed/" owner:_player base:_player stat:0 offset:0x98 bytes:&target length:4];break;}
    case MTFeatureSlowAI:case MTFeatureAIMultiplier:s.active=[self aiFactor:_parameters[MTFeatureAIMultiplier]];s.note=s.active?@"Feindliche lokale NPCs: Zeitfaktor zurückgelesen.":@"Wartet auf feindliche lokale NPCs.";break;
    case MTFeatureMovement:case MTFeatureMovementMultiplier:s.active=[self factor:_parameters[MTFeatureMovementMultiplier] stat:65 key:@"movement/walk"]&&[self factor:_parameters[MTFeatureMovementMultiplier] stat:74 key:@"movement/sprint"];break;
    case MTFeatureErgoMultiplier:s.active=[self factor:value stat:177 key:prefix];break;
    case MTFeatureUnlimitedErgo:{
        s.available=object(_save);if(s.available){int32_t target=999999999;((void(*)(uintptr_t,int32_t))at(LOPSetErgo))(_save+0x60,target);s.active=((int32_t(*)(uintptr_t))at(LOPGetErgo))(_data)==target;}
        s.note=@"Ergo auf 999999999 halten; diese Änderung kann gespeichert werden.";break;}
    case MTFeatureStealth:s.active=[self stealth];s.note=@"Eigener gepaarter Zustand gegen KI-Spielererkennung; bestehende fremde Zustände bleiben erhalten.";break;
    default:s.available=NO;break;
    }
    if(wanted&&!s.active&&s.available)s.note=[s.note stringByAppendingString:@" Noch keine aktive Rücklese-Bestätigung."];
    return s;
}
- (BOOL)position:(Vector *)position rotation:(Vector *)rotation {
    uintptr_t root=ptr(_player+0xf0);if(!object(root)||!MTReadMemory((void *)(root+0x1c0),position,sizeof(*position)))return NO;
    float q[4];if(!MTReadMemory((void *)(root+0x1b0),q,sizeof(q)))return NO;
    *rotation=((Vector(*)(const float *))at(LOPQuatRotator))(q);
    return isfinite(position->x)&&isfinite(position->y)&&isfinite(position->z);
}
- (NSString *)performOneShot:(MTFeature)f value:(double)value {
    if(!_valid||![self isGameThread]||get(_playerWeak)!=_player||get(_statsWeak)!=_stats)return @"Kein gültiger Spielkontext.";
    if(!isfinite(value))return @"Ungültiger Zahlenwert.";
    uint8_t id=editStat(f);
    if(id){
        if(id==1||id==2||id==5){if(byte(datum(_stats,id)+0x14))return @"Zuerst den entsprechenden Unbegrenzt-Schalter lösen.";setStat(_stats,id,(int32_t)value);}
        else {int64_t next=int64_t(partial(_stats,id))+(int32_t)value-stat(_stats,id);if(next<INT32_MIN||next>INT32_MAX)return @"Wert außerhalb des gültigen Bereichs.";setPartial(_stats,id,(int32_t)next);}
        return stat(_stats,id)==(int32_t)value?@"Spielwert gesetzt und zurückgelesen.":@"Spiel hat den Zielwert nicht bestätigt.";
    }
    if(f==MTFeatureSaveCoordinates||f==MTFeatureTeleport||f==MTFeatureX||f==MTFeatureY||f==MTFeatureZ){
        Vector p,r;if(![self position:&p rotation:&r])return @"Spielposition fehlt.";
        if(f==MTFeatureSaveCoordinates){_savedPosition=p;_savedRotation=r;_savedContext=self.identity;return @"Koordinaten und Blickrichtung für diesen Spielkontext gespeichert.";}
        if(f==MTFeatureTeleport){if(![_savedContext isEqual:self.identity])return @"Gespeicherte Position gehört zu einem anderen Spielkontext.";p=_savedPosition;r=_savedRotation;}
        else if(f==MTFeatureX)p.x=value;else if(f==MTFeatureY)p.y=value;else p.z=value;
        if(!((bool(*)(uintptr_t,Vector,Vector))at(LOPTeleport))(_player,p,r))return @"Teleport vom Spiel abgelehnt (z. B. Kollision).";
        Vector actual,rotation;if(![self position:&actual rotation:&rotation])return @"Teleport ohne Rücklese-Bestätigung.";
        return fabs(actual.x-p.x)<2&&fabs(actual.y-p.y)<2&&fabs(actual.z-p.z)<2?@"Teleport nativ ausgeführt und Position zurückgelesen.":@"Spiel hat die Zielposition angepasst; Ziel nicht bestätigt.";
    }
    if(f==MTFeatureItemQuantity){
        // Selection means the game's currently chosen quickbelt item, never a guessed UI pointer.
        uintptr_t item=object(_equipment)?ptr(_equipment+0x1b0):0;
        if(!object(item)||!object(_inventory)||!((bool(*)(uintptr_t,uintptr_t))at(LOPItemHas))(_inventory,item))return @"Kein eigener Gegenstand im ausgewählten Schnellzugriffsplatz.";
        int32_t maximum=((int32_t(*)(uintptr_t))at(LOPItemMax))(item);if(value>maximum)return [NSString stringWithFormat:@"Dieser Gegenstand erlaubt höchstens %d Stück.",maximum];
        ((void(*)(uintptr_t,int32_t))at(LOPItemSet))(item,(int32_t)value);
        return integer(item+0x40)==(int32_t)value?@"Menge des ausgewählten Schnellzugriffs-Gegenstands bestätigt.":@"Gegenstandsmenge nicht bestätigt.";
    }
    if(!object(_save))return @"Charakterdaten fehlen.";
    if(f==MTFeatureErgo){((void(*)(uintptr_t,int32_t))at(LOPSetErgo))(_save+0x60,(int32_t)value);return ((int32_t(*)(uintptr_t))at(LOPGetErgo))(_data)==value?@"Ergo gesetzt und zurückgelesen.":@"Ergo nicht bestätigt.";}
    size_t offset=f==MTFeatureTimePlayed?0x70:f==MTFeatureLevel?0xa0:f==MTFeatureHumanity?0xc8:0;
    if(!offset)return @"Keine native Aktion für diesen Eintrag.";
    BOOL ok=NO;if(f==MTFeatureTimePlayed){double n=value,actual;ok=MTWriteMemory((void *)(_save+offset),&n,8)&&MTReadMemory((void *)(_save+offset),&actual,8)&&actual==n;}
    else {int32_t n=(int32_t)value;ok=MTWriteInt((void *)_save,offset,n)&&integer(_save+offset)==n;}
    return ok?@"Charakterfeld gesetzt und zurückgelesen; vom Spiel speicherbar.":@"Charakterfeld nicht bestätigt.";
}
- (BOOL)showPlatformCursor {
    if(!_platformCursor)_platformCursor=[[MTPlatformCursorLease alloc]initWithRead:^MTPlatformCursorState{return platformCursorState();}
        apply:^BOOL(MTPlatformCursorState owner,MTPlatformCursorOperation operation,int32_t value){
            MTPlatformCursorState current=platformCursorState();
            if(!owner.cursor || current.application!=owner.application || current.cursor!=owner.cursor || current.reference!=owner.reference)return NO;
            if(operation==MTPlatformCursorOverride)return MTWriteInt((void *)owner.cursor,0x120,value);
            if(operation==MTPlatformCursorType)((void(*)(uintptr_t,int32_t))at(LOPMacCursorType))(owner.cursor,value);
            else if(operation==MTPlatformCursorVisibility)((void(*)(uintptr_t,bool))at(LOPMacCursorShow))(owner.cursor,value!=0);
            return YES;
        }];
    return [_platformCursor show];
}
- (void)releaseMouse {
    if(!_mouseOwned)return;
    uintptr_t controller=get(_mouseController),viewport=get(_mouseViewport),input=get(_mouseInput);
    BOOL stillOwned=controller&&viewport&&input&&byte(input+0xf8)==1&&
        (byte(controller+0x408)&1)&&byte(viewport+0x352)==_captureOwned&&byte(viewport+0x354)==0&&byte(viewport+0x353)==0;
    if(stillOwned){
        ((void(*)(uintptr_t))at(LOPModeGame))(controller);
        ((void(*)(uintptr_t,uint8_t))at(LOPCapture))(viewport,_captureOriginal);
        ((void(*)(uintptr_t,uint8_t))at(LOPLock))(viewport,_lockOriginal);
        ((void(*)(uintptr_t,bool))at(LOPHideCursor))(viewport,_hideOriginal!=0);
        uint8_t cursor=(byte(controller+0x408)&~1u)|(_cursorOriginal&1u);MTWriteByte((void *)controller,0x408,cursor);
    }
    // Native ignore counters are paired; later menu increments are preserved.
    if(controller){
        if(byte(controller+0x256)>_lookOriginal)((void(*)(uintptr_t,bool))at(LOPIgnoreLook))(controller,false);
        if(byte(controller+0x255)>_moveOriginal)((void(*)(uintptr_t,bool))at(LOPIgnoreMove))(controller,false);
    }
    [_platformCursor restore:stillOwned];
    _mouseOwned=NO;_mouseController=Weak{};_mouseViewport=Weak{};_mouseInput=Weak{};
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {
    if(!_valid||![self isGameThread])return NO;
    uintptr_t world=ptr(at(0x10673d830));
    uintptr_t controller=object(world)?((uintptr_t(*)(uintptr_t,int))at(LOPGetController))(world,0):0;
    if(!object(controller)||!((bool(*)(uintptr_t))at(LOPLocalController))(controller))controller=0;
    uintptr_t input=ptr(at(0x1063021e0));
    if(_mouseOwned && (!wanted||get(_mouseController)!=controller||get(_mouseInput)!=input||!object(input)||byte(input+0xf8)!=1)) [self releaseMouse];
    if(!wanted){[_platformCursor restore:YES];return NO;}
    if(_mouseOwned){
        uintptr_t viewport=get(_mouseViewport);
        if(viewport && (byte(controller+0x408)&1) && byte(viewport+0x352)==_captureOwned && byte(viewport+0x354)==0 && byte(viewport+0x353)==0)return [self showPlatformCursor];
        [self releaseMouse];return NO;
    }
    // Main menus may have no pawn/controller. Their already-free native cursor
    // still needs a visible shape; it must not depend on the cheat context.
    if(!object(controller)||!object(world)||!object(input)||byte(input+0xf8)!=1||(byte(controller+0x408)&1))return [self showPlatformCursor];
    uintptr_t viewport=((uintptr_t(*)(uintptr_t))at(LOPViewport))(world);
    if(!object(viewport)||byte(controller+0x255)>250||byte(controller+0x256)>250)return NO;
    _mouseController=weak(controller);_mouseViewport=weak(viewport);_mouseInput=weak(input);
    _cursorOriginal=byte(controller+0x408);_captureOriginal=byte(viewport+0x352);_lockOriginal=byte(viewport+0x354);_hideOriginal=byte(viewport+0x353);
    _lookOriginal=byte(controller+0x256);_moveOriginal=byte(controller+0x255);
    ((void(*)(uintptr_t,bool))at(LOPIgnoreLook))(controller,true);
    ((void(*)(uintptr_t,bool))at(LOPIgnoreMove))(controller,true);
    _mouseOwned=YES;
    ((void(*)(uintptr_t,uintptr_t,uint8_t,bool))at(LOPModeUI))(controller,0,0,false);
    uint8_t cursor=byte(controller+0x408)|1;MTWriteByte((void *)controller,0x408,cursor);
    _captureOwned=byte(viewport+0x352);
    BOOL confirmed=(byte(controller+0x408)&1)&&byte(viewport+0x354)==0&&byte(viewport+0x353)==0&&_captureOwned<=4;
    if(!confirmed){[self releaseMouse];return NO;}
    return [self showPlatformCursor];
}

- (NSDictionary *)diagnosticSnapshot {
    MTGameContext *context=[self captureContext];
    NSMutableDictionary *d=[@{@"kind":@(context.kind),@"identity":context.identity,@"note":context.note,@"gameThread":@([self isGameThread])} mutableCopy];
    if(!_valid){
        d[@"bundleID"]=NSBundle.mainBundle.bundleIdentifier?:@"missing";
        uint32_t mainIndex=0;const mach_header_64 *h=mainHeader(&mainIndex);
        d[@"magic"]=@(h->magic);d[@"cpu"]=@(h->cputype);d[@"filetype"]=@(h->filetype);
        intptr_t currentSlide=_dyld_get_image_vmaddr_slide(mainIndex);
        const uint8_t *p=(const uint8_t *)(h+1);for(uint32_t i=0;i<h->ncmds;i++){const load_command *c=(const load_command *)p;if(c->cmd==LC_UUID)d[@"uuid"]=[[NSUUID alloc]initWithUUIDBytes:((const uuid_command *)c)->uuid].UUIDString;p+=c->cmdsize;}
        for(const auto &c:LOPCodeChecks){uint8_t actual[16];if(!MTReadMemory((void *)(c.address+currentSlide),actual,16)||memcmp(actual,c.bytes,16)){
            d[@"mismatchAddress"]=[NSString stringWithFormat:@"%llx",(unsigned long long)c.address];
            d[@"actualBytes"]=[[NSData dataWithBytes:actual length:16] base64EncodedStringWithOptions:0];break;
        }}
    }
    if(context.kind!=MTSessionSolo){
        d[@"worldObject"]=@(object(_world));d[@"worldFlags"]=@(integer(_world+8));d[@"objectCount"]=@(integer(at(0x1066bd2b0)+0x24));
        d[@"playerObject"]=@(object(_player));d[@"playerFlags"]=@(integer(_player+8));d[@"playerIndex"]=@(integer(_player+12));d[@"statsObject"]=@(object(_stats));return d;
    }
    NSMutableDictionary *stats=[NSMutableDictionary new];
    for(NSNumber *id in @[@1,@2,@5,@8,@65,@71,@72,@74,@75,@122,@123,@124,@177])stats[id.stringValue]=@(stat(_stats,id.unsignedCharValue));
    d[@"stats"]=stats;
    d[@"fixedFlags"]=@[@(byte(datum(_stats,1)+0x14)),@(byte(datum(_stats,2)+0x14)),@(byte(datum(_stats,5)+0x14))];
    d[@"fixedValues"]=@[@(integer(datum(_stats,1)+0x10)),@(integer(datum(_stats,2)+0x10)),@(integer(datum(_stats,5)+0x10))];
    uintptr_t viewport=((uintptr_t(*)(uintptr_t))at(LOPViewport))(_world);
    if(object(viewport))d[@"viewportInput"]=@[@(byte(viewport+0x352)),@(byte(viewport+0x353)),@(byte(viewport+0x354))];
    uintptr_t actMgr=((uintptr_t(*)(uintptr_t))at(LOPGetActMgr))(_player);
    if(object(actMgr))d[@"stealthState"]=@(((bool(*)(uintptr_t,uint64_t))at(LOPFindState))(actMgr,ptr(at(0x106615318))));
    d[@"playerTimeDilation"]=@(real(_player+0x98));
    d[@"ergo"]=@(((int32_t(*)(uintptr_t))at(LOPGetErgo))(_data));
    d[@"dataReady"]=@(object(_save));d[@"cursor"]=@(byte(_controller+0x408)&1);d[@"lookIgnore"]=@(byte(_controller+0x256));d[@"moveIgnore"]=@(byte(_controller+0x255));d[@"inventoryReady"]=@(object(_inventory));
    d[@"playTimerActive"]=@(byte(_data+0x80));d[@"notConsume"]=@(byte(at(0x106616d40)));d[@"oneHit"]=@(byte(at(0x106300e74)));
    Vector p,r;if([self position:&p rotation:&r])d[@"position"]=@[@(p.x),@(p.y),@(p.z)];
    return d;
}
- (NSDictionary *)runReversibleChecks {
    NSDictionary *before=self.diagnosticSnapshot;
    if([before[@"kind"] integerValue]!=MTSessionSolo)return @{@"skipped":@"No solo context"};
    NSMutableDictionary *checks=[NSMutableDictionary new];
    for(NSNumber *number in @[@(MTFeatureHealth),@(MTFeatureStamina),@(MTFeatureLegion),@(MTFeatureOneHit),@(MTFeatureItemUsage),@(MTFeatureFreezeTime),@(MTFeaturePlayerMultiplier),@(MTFeatureMovementMultiplier),@(MTFeatureErgoMultiplier),@(MTFeatureAIMultiplier),@(MTFeatureStealth)]){
        MTFeature f=(MTFeature)number.integerValue;
        double n=(f==MTFeaturePlayerMultiplier||f==MTFeatureMovementMultiplier)?1.25:MTFeatureInfoAt(f)->initial;
        MTFeatureState *state=[self applyFeature:f wanted:YES value:n];
        NSDictionary *during=self.diagnosticSnapshot;
        [self releaseEffects];
        checks[MTFeatureInfoAt(f)->title]=@{@"readback":@(state.active),@"note":state.note?:@"",@"during":during};
    }
    NSString *saved=[self performOneShot:MTFeatureSaveCoordinates value:0];
    NSString *teleported=[self performOneShot:MTFeatureTeleport value:0];
    checks[@"Save and teleport same coordinates"]=@{@"save":saved,@"teleport":teleported};[self releaseEffects];
    BOOL mouse=[self setOverlayInteraction:YES];
    NSDictionary *mouseDuring=self.diagnosticSnapshot;[self setOverlayInteraction:NO];
    checks[@"Overlay mouse"]=@{@"readback":@(mouse),@"during":mouseDuring};
    NSDictionary *after=self.diagnosticSnapshot;
    BOOL restored=[before[@"stats"] isEqual:after[@"stats"]]&&[before[@"playerTimeDilation"] isEqual:after[@"playerTimeDilation"]]&&[before[@"oneHit"] isEqual:after[@"oneHit"]]&&[before[@"notConsume"] isEqual:after[@"notConsume"]]&&[before[@"ergo"] isEqual:after[@"ergo"]]&&[before[@"playTimerActive"] isEqual:after[@"playTimerActive"]]&&[before[@"cursor"] isEqual:after[@"cursor"]]&&[before[@"lookIgnore"] isEqual:after[@"lookIgnore"]]&&[before[@"moveIgnore"] isEqual:after[@"moveIgnore"]]&&[before[@"fixedFlags"] isEqual:after[@"fixedFlags"]]&&[before[@"fixedValues"] isEqual:after[@"fixedValues"]]&&[before[@"stealthState"] isEqual:after[@"stealthState"]]&&[before[@"viewportInput"] isEqual:after[@"viewportInput"]];
    return @{@"before":before,@"after":after,@"restored":@(restored),@"checks":checks,@"permanentEditorsTested":@NO,@"combatTested":@NO};
}
@end
