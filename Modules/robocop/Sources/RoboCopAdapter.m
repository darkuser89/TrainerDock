// SPDX-License-Identifier: GPL-3.0-only
#import "RoboCopAdapter.h"
#import "MemoryAccess.h"
#import <AppKit/AppKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/message.h>
#include <math.h>
#include <string.h>
#import "RoboCopBindings.h"

static BOOL readAt(void *p,size_t offset,void *out,size_t count) {
    return p && (uintptr_t)p<=UINTPTR_MAX-offset && MTReadMemory((uint8_t *)p+offset,out,count);
}
static void *pointer(void *p,size_t offset) {void *v=NULL;readAt(p,offset,&v,sizeof(v));return v;}
static int32_t integer(void *p,size_t offset) {int32_t v=0;readAt(p,offset,&v,sizeof(v));return v;}
static uint8_t byte(void *p,size_t offset) {uint8_t v=0;readAt(p,offset,&v,sizeof(v));return v;}
static float scalar(void *p,size_t offset) {float v=NAN;readAt(p,offset,&v,sizeof(v));return v;}
static BOOL realGameThread(void) {
    SEL selector=NSSelectorFromString(@"isGameThread");
    return [NSThread respondsToSelector:selector] && ((BOOL(*)(id,SEL))objc_msgSend)(NSThread.class,selector);
}
RCNativeAPI RCResolveNativeAPI(void) {
    RCNativeAPI api={0};
    const struct mach_header_64 *header=NULL;intptr_t slide=0;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *h=(const void *)_dyld_get_image_header(i);
        if(h && h->magic==MH_MAGIC_64 && h->filetype==MH_EXECUTE){header=h;slide=_dyld_get_image_vmaddr_slide(i);break;}
    }
    if(!header || header->cputype!=CPU_TYPE_ARM64 || header->sizeofcmds>1024*1024 || header->ncmds>4096)return api;
    const uint8_t *cmd=(const uint8_t *)(header+1),*end=cmd+header->sizeofcmds;BOOL uuid=NO;
    for(uint32_t i=0;i<header->ncmds;i++){
        if((size_t)(end-cmd)<sizeof(struct load_command))return api;
        const struct load_command *c=(const void *)cmd;
        if(c->cmdsize<sizeof(*c) || c->cmdsize>(size_t)(end-cmd))return api;
        if(c->cmd==LC_UUID && c->cmdsize==sizeof(struct uuid_command))
            uuid=[[[NSUUID alloc]initWithUUIDBytes:((const struct uuid_command *)c)->uuid].UUIDString isEqual:@"1FA73710-C3C8-3F83-97C3-CBF0ED3215ED"];
        cmd+=c->cmdsize;
    }
    if(!uuid || ![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.nacon.robocoproguecitysteam"])return api;
    for(size_t i=0;i<sizeof(rcBindings)/sizeof(*rcBindings);i++){
        uint8_t bytes[16];const RCBinding *b=&rcBindings[i];
        if(!MTReadMemory((void *)(b->address+slide),bytes,sizeof(bytes)) || memcmp(bytes,b->bytes,sizeof(bytes)))return api;
    }
#define BIND(field) for(size_t i=0;i<sizeof(rcBindings)/sizeof(*rcBindings);i++)if(!strcmp(rcBindings[i].name,#field))api.field=(__typeof__(api.field))(rcBindings[i].address+slide)
    BIND(gameThreadCall);BIND(weakAssign);BIND(weakGet);BIND(isA);BIND(getPlayer);BIND(getController);
    BIND(getComponent);BIND(healthClass);BIND(weaponComponentClass);BIND(rifleClass);BIND(getMovement);
    BIND(getWeapon);BIND(getProgression);BIND(setCanBeDamaged);BIND(heal);BIND(getClipCapacity);
    BIND(setSkillPoints);BIND(addXP);BIND(getViewport);BIND(getGameInstance);BIND(worldIsGame);BIND(getNetMode);
    BIND(setCapture);BIND(setLock);BIND(setHide);BIND(setPrecision);BIND(cursorLock);BIND(cursorShow);
    BIND(cursorType);BIND(ignoreMove);BIND(ignoreLook);BIND(releaseCapture);BIND(focusViewport);
    BIND(fppRifleClass);BIND(aiControllerClass);BIND(attributeClass);BIND(actorWorld);BIND(getAttributes);BIND(getWorldSettings);BIND(getActors);BIND(freeMemory);BIND(oneHitEnabled);BIND(infiniteAmmoEnabled);BIND(fillClip);BIND(getFireRate);BIND(getHitDamage);BIND(getTime);BIND(setTime);BIND(getXPRequired);BIND(atMaxLevel);
#undef BIND
    api.oneHitSlot=(int32_t **)(0x10884c338ULL+slide);
    api.worldSlot=(void **)(0x1089327a8ULL+slide);
    api.macApplicationSlot=(void **)(0x1088f3fb0ULL+slide);
    api.slateSlot=(void **)(0x1088f4f18ULL+slide);
    api.isGameThread=realGameThread;api.valid=YES;return api;
}
// Reversible writable-data leases. UObject lifetime is always checked by index+serial.
typedef NS_ENUM(uint8_t,RCValueKind){RCFloat,RCInt,RCByte,RCPointer};
typedef NS_ENUM(uint8_t,RCValueMode){RCConstant,RCMultiply,RCDivide,RCXPBonus};
typedef struct {size_t offset;RCValueKind kind;RCValueMode mode;double value;} RCField;
@interface RCDataLease : NSObject
@property(nonatomic) RCWeak owner;
@property(nonatomic) size_t offset;
@property(nonatomic) RCValueKind kind;
@property(nonatomic) uint64_t original,last;
@end
@implementation RCDataLease
@end
static size_t widthFor(RCValueKind kind){return kind==RCByte ? 1 : kind==RCPointer ? 8 : 4;}
static double decode(uint64_t bits,RCValueKind kind){if(kind==RCFloat){float f;memcpy(&f,&bits,4);return f;}return kind==RCPointer ? (double)bits : kind==RCByte ? (uint8_t)bits : (int32_t)bits;}
static uint64_t encode(double value,RCValueKind kind){if(kind==RCFloat){float f=(float)value;uint32_t bits;memcpy(&bits,&f,4);return bits;}return kind==RCPointer ? (uint64_t)value : (uint32_t)(int32_t)value;}
static BOOL writeBits(void *p,size_t offset,RCValueKind kind,uint64_t bits){
    if(kind==RCPointer)return MTWritePointer(p,offset,(void *)(uintptr_t)bits);
    if(kind==RCByte)return MTWriteByte(p,offset,(uint8_t)bits);
    if(kind==RCInt)return MTWriteInt(p,offset,(int32_t)bits);
    float f;memcpy(&f,&bits,4);return MTWriteFloat(p,offset,f);
}
typedef struct {
    RCWeak owner;
    BOOL captured;
    float original[3],last[3];
} RCEffect;
typedef struct {
    BOOL owned;
    RCWeak controller,viewport,instance;
    void *application,*cursor;
    uint8_t capture,lock,hide,show,visible,precision;
    int32_t type,rect[4];
    uint8_t moveCount,lookCount;
} RCCursorLease;
@implementation RCRoboCopAdapter {
    RCNativeAPI _api;
    RCWeak _world,_player,_controller,_health,_movement,_weapon,_progression,_attributes;
    NSMutableDictionary<NSNumber *,NSMutableArray<RCDataLease *> *> *_leases;
    int32_t *_oneHitAddress,_oneHitOriginal;BOOL _oneHitOwned;
    RCWeak _timeWorld;float _timeOriginal,_timeLast;BOOL _timeOwned;
    NSUInteger _aiCount;
    RCEffect _god;
    RCCursorLease _cursor;
    NSString *_focus;
}
- (instancetype)init {return [self initWithAPI:RCResolveNativeAPI()];}
- (instancetype)initWithAPI:(RCNativeAPI)api {if((self=[super init])){_api=api;_leases=[NSMutableDictionary new];}return self;}
- (void)onGameThread:(dispatch_block_t)work {
    if(!_api.valid){dispatch_async(dispatch_get_main_queue(),work);return;}
    _api.gameThreadCall(work,@[NSDefaultRunLoopMode,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode],false);
}
- (void *)resolve:(RCWeak)weak {return _api.weakGet(&weak);}
- (RCWeak)weak:(void *)object {RCWeak w={0};if(object)_api.weakAssign(&w,object);return w;}
- (BOOL)typed:(void *)object kind:(void *)kind {return object && kind && _api.isA(&object,kind);}
- (BOOL)gameThread {return _api.valid && _api.isGameThread();}
- (NSString *)focusFor:(void *)instance {
    void *data=pointer(instance,0x3a8);int32_t count=integer(instance,0x3b0);
    if(count<0 || count>1024)return nil;
    if(!count)return @"";
    unichar text[1024];if(!data || !MTReadMemory(data,text,(size_t)count*2))return nil;
    return [[NSString alloc]initWithCharacters:text length:text[count-1]==0 ? count-1 : count];
}
- (MTGameContext *)captureContext {
    MTGameContext *c=[MTGameContext new];if(![self gameThread]){c.note=@"RoboCop-Build oder GameThread nicht bestätigt.";return c;}
    _world=_player=_controller=_health=_movement=_weapon=_progression=_attributes=(RCWeak){0};
    c.kind=MTSessionLoading;c.identity=@"loading";c.note=@"Wartet auf RoboCop und einen gültigen Spieler.";
    void *world=NULL;if(!MTReadMemory(_api.worldSlot,&world,sizeof(world)) || !world)return c;
    RCWeak ww=[self weak:world];if([self resolve:ww]!=world || !_api.worldIsGame(world))return c;
    _world=ww;
    void *pc=_api.getController(world,0),*player=_api.getPlayer(world);
    RCWeak pw=[self weak:player],cw=[self weak:pc];
    if(pc && [self resolve:cw]==pc)_controller=cw;
    if(!player || !pc || [self resolve:pw]!=player || [self resolve:cw]!=pc || pointer(pc,0x2d8)!=player || pointer(player,0x2d0)!=pc)return c;
    void *health=_api.getComponent(player,_api.healthClass());
    if(![self typed:health kind:_api.healthClass()] || pointer(health,0x90)!=player)return c;
    float hp=scalar(health,0x10c),max=scalar(health,0x114);
    if(!isfinite(hp) || !isfinite(max) || hp<=0 || max<=0 || max>10000000)return c;
    void *movement=_api.getMovement(player),*wc=_api.getComponent(player,_api.weaponComponentClass()),*weapon=NULL;
    if(wc && pointer(wc,0x90)==player){
        weapon=_api.getWeapon(wc,false);
        if(weapon){RCWeak owner={0};if(!readAt(weapon,0x4c4,&owner,sizeof(owner)) || [self resolve:owner]!=player || ![self typed:weapon kind:_api.fppRifleClass()])weapon=NULL;}
    }
    _world=ww;_player=pw;_controller=cw;_health=[self weak:health];
    _movement=[self weak:movement];_weapon=[self weak:weapon];_progression=[self weak:_api.getProgression(world)];
    void *attributes=_api.getAttributes(player);
    if([self typed:attributes kind:_api.attributeClass()])_attributes=[self weak:attributes];
    int netMode=_api.getNetMode(world);c.kind=netMode==0 ? MTSessionSolo : MTSessionNetwork;
    c.identity=[NSString stringWithFormat:@"%d:%d/%d:%d/%d:%d/%d:%d/%d:%d/%d:%d/%d:%d",ww.index,ww.serial,pw.index,pw.serial,cw.index,cw.serial,_weapon.index,_weapon.serial,_movement.index,_movement.serial,_health.index,_health.serial,_progression.index,_progression.serial];
    c.identity=[c.identity stringByAppendingFormat:@"/%d:%d",_attributes.index,_attributes.serial];
    c.note=@"RoboCop arm64 · Plus 17 · native Anbindung";
    return c;
}
- (void)releaseGod {
    void *owner=[self resolve:_god.owner];
    if(_god.captured && owner && !(integer(owner,0x58)&0x40000))_api.setCanBeDamaged(owner,_god.original[0]!=0);
    memset(&_god,0,sizeof(_god));
}
- (void)releaseLeases:(MTFeature)feature {
    for(RCDataLease *lease in _leases[@(feature)]){
        void *owner=[self resolve:lease.owner];uint64_t now=0;
        if(owner && readAt(owner,lease.offset,&now,widthFor(lease.kind)) && now==lease.last)writeBits(owner,lease.offset,lease.kind,lease.original);
    }
    [_leases removeObjectForKey:@(feature)];
}
- (BOOL)modify:(MTFeature)feature owner:(void *)owner fields:(const RCField *)fields count:(size_t)count {
    if(!owner || count>16)return NO;
    RCWeak weak=[self weak:owner];if(!weak.serial || [self resolve:weak]!=owner)return NO;
    NSMutableArray<RCDataLease *> *leases=_leases[@(feature)];
    if(!leases){leases=[NSMutableArray new];_leases[@(feature)]=leases;}
    NSMutableArray<RCDataLease *> *selected=[NSMutableArray new];uint64_t target[16];
    for(size_t i=0;i<count;i++){
        const RCField *field=&fields[i];uint64_t now=0;
        if(!readAt(owner,field->offset,&now,widthFor(field->kind))){[self releaseLeases:feature];return NO;}
        RCDataLease *match=nil;
        for(RCDataLease *lease in leases)if(lease.owner.index==weak.index && lease.owner.serial==weak.serial && lease.offset==field->offset){match=lease;break;}
        // Rebind only on the following poll; never overwrite a newly observed foreign change.
        if(match && now!=match.last){[self releaseLeases:feature];return NO;}
        if(!match){match=[RCDataLease new];match.owner=weak;match.offset=field->offset;match.kind=field->kind;match.original=match.last=now;[leases addObject:match];}
        double original=decode(match.original,field->kind),value=field->value;
        if(!isfinite(original) || !isfinite(value)){[self releaseLeases:feature];return NO;}
        if(field->mode==RCMultiply)value*=original;
        else if(field->mode==RCDivide)value=original/value;
        else if(field->mode==RCXPBonus)value=(original+1)*value-1;
        if(!isfinite(value) || fabs(value)>1000000000){[self releaseLeases:feature];return NO;}
        target[i]=encode(value,field->kind);[selected addObject:match];
    }
    for(size_t i=0;i<count;i++){
        RCDataLease *lease=selected[i];
        if(!writeBits(owner,lease.offset,lease.kind,target[i])){[self releaseLeases:feature];return NO;}
        lease.last=target[i];uint64_t now=0;
        if(!readAt(owner,lease.offset,&now,widthFor(lease.kind)) || now!=target[i]){[self releaseLeases:feature];return NO;}
    }
    return YES;
}
- (void)releaseOneHit {
    if(_oneHitOwned && _oneHitAddress==pointer(_api.oneHitSlot,0) && integer(_oneHitAddress,0)==1)MTWriteInt(_oneHitAddress,0,_oneHitOriginal);
    _oneHitOwned=NO;_oneHitAddress=NULL;
}
- (void)releaseTime {
    void *world=[self resolve:_timeWorld];
    if(_timeOwned && world && _api.getTime(world)==_timeLast)_api.setTime(world,_timeOriginal);
    _timeOwned=NO;_timeWorld=(RCWeak){0};
}
- (void)releaseEffects {
    if(![self gameThread])return;
    [self releaseGod];[self releaseOneHit];[self releaseTime];
    for(NSNumber *feature in _leases.allKeys)[self releaseLeases:feature.integerValue];_aiCount=0;
}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    const MTFeatureInfo *info=MTFeatureInfoAt(feature);
    MTFeatureState *s=[MTFeatureState new];if(!info)return s;s.note=@"Kein gültiger lokaler Besitzer.";
    if(![self gameThread])return s;
    void *player=[self resolve:_player],*health=[self resolve:_health],*weapon=[self resolve:_weapon],*movement=[self resolve:_movement],*world=[self resolve:_world];
    if(!player || !health || pointer(health,0x90)!=player)return s;
    s.available=YES;s.note=MTFeatureInfoAt(feature)->detail;
    if(!wanted){[self releaseLeases:feature];if(feature==MTFeatureGod)[self releaseGod];if(feature==MTFeatureOneHit)[self releaseOneHit];if(feature==MTFeatureGameSpeed)[self releaseTime];}
    if(wanted && info->numeric && (!isfinite(value) || value<info->minimum || value>info->maximum)){[self releaseLeases:feature];if(feature==MTFeatureGameSpeed)[self releaseTime];s.note=@"Ungültiger Faktor; keine Änderung.";return s;}
    if(feature==MTFeatureGod){
        if(!wanted)return s;
        if(_god.captured && [self resolve:_god.owner]!=player)[self releaseGod];
        if(!_god.captured){_god.owner=_player;_god.original[0]=(integer(player,0x58)&0x40000)!=0;_god.captured=YES;}
        _api.setCanBeDamaged(player,false);s.active=!(integer(player,0x58)&0x40000);
    }else if(feature==MTFeatureHealth){
        if(wanted){float max=scalar(health,0x114);if(isfinite(max) && max>0){_api.heal(health,-1.f);s.active=scalar(health,0x10c)==max;}}
    }else if(feature==MTFeatureMovement){
        s.available=movement && pointer(player,0x1750)==movement && pointer(movement,0x90)==player;
        if(!s.available || !wanted)return s;
        const RCField fields[]={{0xfb4,RCFloat,RCMultiply,value},{0x248,RCFloat,RCMultiply,value},{0x24c,RCFloat,RCMultiply,value}};
        s.active=[self modify:feature owner:movement fields:fields count:3];
    }else if(feature==MTFeatureDefense){
        if(wanted){const RCField field={0x248,RCFloat,RCDivide,value};s.active=value>0 && [self modify:feature owner:health fields:&field count:1];}
    }else if(feature==MTFeaturePlayerSpeed){
        if(wanted){const RCField field={0x64,RCFloat,RCMultiply,value};s.active=[self modify:feature owner:player fields:&field count:1];}
    }else if(feature==MTFeatureGameSpeed){
        s.available=world && _api.getWorldSettings(world,false,true);
        if(wanted && s.available){
            if(_timeOwned && ([self resolve:_timeWorld]!=world || _api.getTime(world)!=_timeLast)){[self releaseTime];return s;}
            if(!_timeOwned){_timeOriginal=_api.getTime(world);_timeWorld=_world;_timeOwned=isfinite(_timeOriginal) && _timeOriginal>0;}
            if(_timeOwned){_api.setTime(world,_timeOriginal*(float)value);_timeLast=_api.getTime(world);s.active=fabsf(_timeLast-_timeOriginal*(float)value)<0.0001f;if(!s.active)[self releaseTime];}
        }
    }else if(feature==MTFeatureXPMultiplier){
        void *attributes=[self resolve:_attributes];s.available=attributes!=NULL;
        if(wanted && s.available){
            // Only current values are leased. Base attributes (the save cache) are untouched.
            // The native AddExpPoints path adds the type-2 bonus to GeneralExpBoost.
            RCField fields[]={{0x1dc,RCFloat,RCXPBonus,value}};
            void *progress=[self resolve:_progression];
            // FGameplayAttribute's resolved FProperty carries the actual secondary attribute offset.
            void *property=pointer(progress,0x350+0x10);int32_t secondaryOffset=integer(property,0x44);
            if(secondaryOffset==0xf0 || secondaryOffset==0x100 || secondaryOffset==0x180){
                RCField pair[]={fields[0],{(size_t)secondaryOffset+12,RCFloat,RCMultiply,value}};
                s.active=[self modify:feature owner:attributes fields:pair count:2];
            }else s.active=[self modify:feature owner:attributes fields:fields count:1];
        }
    }else if(feature==MTFeatureAISpeed){
        if(!wanted){_aiCount=0;return s;}
        RCActorArray actors={0};_api.getActors(world,_api.aiControllerClass(),&actors);
        BOOL valid=actors.count>=0 && actors.count<=4096 && actors.capacity>=actors.count && actors.capacity<=65536;
        NSMutableSet<NSString *> *seen=[NSMutableSet new];NSUInteger changed=0;BOOL success=valid;
        if(valid)for(int32_t i=0;i<actors.count;i++){
            void *controller=pointer(actors.data,(size_t)i*8),*pawn=pointer(controller,0x2d8);
            RCWeak cw=[self weak:controller],pw=[self weak:pawn];
            if(!pawn || pawn==player || [self resolve:cw]!=controller || [self resolve:pw]!=pawn || pointer(pawn,0x2d0)!=controller || _api.actorWorld(pawn)!=world || _api.actorWorld(controller)!=world)continue;
            const RCField field={0x64,RCFloat,RCMultiply,value};
            BOOL p=[self modify:feature owner:pawn fields:&field count:1],c=[self modify:feature owner:controller fields:&field count:1];success&=p && c;changed++;
            [seen addObject:[NSString stringWithFormat:@"%d:%d",cw.index,cw.serial]];[seen addObject:[NSString stringWithFormat:@"%d:%d",pw.index,pw.serial]];
        }
        if(actors.data)_api.freeMemory(actors.data);
        NSMutableArray *leases=_leases[@(feature)];
        for(RCDataLease *lease in leases.copy)if(![seen containsObject:[NSString stringWithFormat:@"%d:%d",lease.owner.index,lease.owner.serial]]){
            void *owner=[self resolve:lease.owner];if(owner && scalar(owner,lease.offset)==decode(lease.last,RCFloat))writeBits(owner,lease.offset,lease.kind,lease.original);[leases removeObject:lease];
        }
        _aiCount=changed;s.active=success && changed>0;s.note=changed ? [NSString stringWithFormat:@"%lu KI-Figuren samt Controller nativ erfasst; Zeitfaktor zurückgelesen.",(unsigned long)changed] : @"Wartet auf gültige KI-Figuren in dieser Welt.";
    }else if(feature==MTFeatureSkillPoints || feature==MTFeatureInfiniteXP){s.available=[self resolve:_progression]!=NULL;
    }else{
        RCWeak owner={0};s.available=weapon && readAt(weapon,0x4c4,&owner,sizeof(owner)) && [self resolve:owner]==player && [self typed:weapon kind:_api.fppRifleClass()];
        if(!s.available || !wanted)return s;
        if(feature==MTFeatureAmmo){const RCField field={0x8a4,RCByte,RCConstant,1};s.active=[self modify:feature owner:weapon fields:&field count:1] && byte(weapon,0x8a4)==1;}
        else if(feature==MTFeatureNoReload){
            if(integer(weapon,0x6c0)==0)_api.fillClip(weapon);
            const RCField field={0xa30,RCByte,RCConstant,0};s.active=integer(weapon,0x6c0)>0 && [self modify:feature owner:weapon fields:&field count:1];
        }else if(feature==MTFeatureRapidFire){const RCField field={0x844,RCInt,RCMultiply,4};s.active=[self modify:feature owner:weapon fields:&field count:1] && _api.getFireRate(weapon)>0;}
        else if(feature==MTFeatureAccuracy){const RCField fields[]={{0x8a6,RCByte,RCConstant,0},{0xa00,RCFloat,RCConstant,0}};s.active=[self modify:feature owner:weapon fields:fields count:2];}
        else if(feature==MTFeatureNoRecoil){const RCField fields[]={{0x8d4,RCByte,RCConstant,0},{0x980,RCPointer,RCConstant,0},{0x988,RCPointer,RCConstant,0}};s.active=[self modify:feature owner:weapon fields:fields count:3];}
        else if(feature==MTFeatureDamage){const RCField field={0x850,RCInt,RCMultiply,value};s.active=[self modify:feature owner:weapon fields:&field count:1] && _api.getHitDamage(weapon,true)>0;}
        else if(feature==MTFeatureOneHit){
            int32_t *address=pointer(_api.oneHitSlot,0);
            if(_oneHitOwned && _oneHitAddress!=address)[self releaseOneHit];
            if(!_oneHitOwned && address){_oneHitAddress=address;_oneHitOriginal=integer(address,0);_oneHitOwned=YES;}
            if(_oneHitOwned)s.active=MTWriteInt(address,0,1) && _api.oneHitEnabled(weapon);
        }
    }
    return s;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {
    if(![self gameThread])return @"GameThread fehlt; keine Änderung.";
    void *p=[self resolve:_progression],*world=[self resolve:_world];
    if(!p || !world || _api.getProgression(world)!=p)return @"Fortschrittsbesitzer gewechselt; Aktion verworfen.";
    if(feature==MTFeatureSkillPoints && isfinite(value) && value>=0 && value<=999999999 && floor(value)==value){
        _api.setSkillPoints(p,(int)value);
        return integer(p,0xc8)==(int)value ? [NSString stringWithFormat:@"Skillpunkte auf %.0f gesetzt und zurückgelesen.",value] : @"Skillpunkte nicht bestätigt.";
    }
    if(feature==MTFeatureInfiniteXP){
        if(_api.atMaxLevel(p))return @"Maximallevel bereits nativ bestätigt.";
        int count=integer(p,0xd8),level=integer(p,0xc4),xp=integer(p,0xc0);void *thresholds=pointer(p,0xd0);
        if(!thresholds || count<1 || count>1000 || level<1 || level>count || xp<0)return @"XP-Grenzen dieses Besitzers nicht bestätigt; keine Änderung.";
        int64_t remaining=-xp;for(int i=level-1;i<count;i++){int threshold=integer(thresholds,i*4);if(threshold<0 || threshold>100000000)return @"Ungültige XP-Tabelle; keine Änderung.";remaining+=threshold;}
        void *attributes=[self resolve:_attributes];float bonus=attributes ? scalar(attributes,0x1dc) : 0;
        if(!isfinite(bonus) || bonus<=-1 || remaining<0 || remaining>1000000000)return @"XP-Ziel nicht sicher berechenbar; keine Änderung.";
        int grant=(int)ceil((double)remaining/(1+bonus));if(grant<=0)return @"Keine XP fehlen.";
        _api.addXP(p,grant,0,false);
        return _api.atMaxLevel(p) ? @"Maximallevel durch native XP-Vergabe erreicht und zurückgelesen." : @"Maximallevel nicht bestätigt; keine automatische Wiederholung.";
    }return @"Aktion nicht unterstützt.";
}
- (void)releaseCursor {
    if(!_cursor.owned)return;
    void *pc=[self resolve:_cursor.controller],*vp=[self resolve:_cursor.viewport],*instance=[self resolve:_cursor.instance];
    void *currentWorld=[self resolve:_world];
    void *currentInstance=currentWorld ? _api.getGameInstance(currentWorld) : NULL;
    BOOL sameFocus=(_cursor.instance.serial ? instance && instance==currentInstance && [_focus isEqual:[self focusFor:instance]] : !currentInstance)
        && (_cursor.controller.serial ? pc && byte(pc,0x329)==_cursor.moveCount+1 && byte(pc,0x32a)==_cursor.lookCount+1 : YES);
    if(pc){
        // Decrement only our reason, preserving additional menu/engine reasons.
        if(byte(pc,0x329)>_cursor.moveCount)_api.ignoreMove(pc,false);
        if(byte(pc,0x32a)>_cursor.lookCount)_api.ignoreLook(pc,false);
        if(sameFocus && (byte(pc,0x54c)&1))MTWriteByte(pc,0x54c,(byte(pc,0x54c)&~1)|_cursor.show);
    }
    if(sameFocus && vp){
        if(byte(vp,0x3a2)==0)_api.setCapture(vp,_cursor.capture);
        if(byte(vp,0x3a4)==0)_api.setLock(vp,_cursor.lock);
        if(byte(vp,0x3a3)==0)_api.setHide(vp,_cursor.hide);
    }
    if(sameFocus && pointer(_api.macApplicationSlot,0)==_cursor.application && pointer(_cursor.application,8)==_cursor.cursor){
        void *cursor=_cursor.cursor;
        if(byte(_cursor.application,0x88)==0)_api.setPrecision(_cursor.application,_cursor.precision,NULL);
        if(byte(cursor,0x110)==1)_api.cursorShow(cursor,_cursor.visible);
        if(integer(cursor,8)==1)_api.cursorType(cursor,_cursor.type);
        int32_t rect[4];memcpy(rect,_cursor.rect,sizeof(rect));rect[2]++;rect[3]++;
        if(integer(cursor,0x100)==0 && integer(cursor,0x104)==0 && integer(cursor,0x108)==0 && integer(cursor,0x10c)==0
            && _cursor.rect[2]>_cursor.rect[0] && _cursor.rect[3]>_cursor.rect[1])_api.cursorLock(cursor,rect);
        if(_cursor.precision){void *slate=pointer(_api.slateSlot,0);if(slate)_api.focusViewport(slate,0);}
    }
    memset(&_cursor,0,sizeof(_cursor));_focus=nil;
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {
    if(![self gameThread])return NO;
    if(!wanted){[self releaseCursor];return NO;}
    void *pc=[self resolve:_controller],*world=[self resolve:_world];
    void *vp=_api.getViewport(),*app=pointer(_api.macApplicationSlot,0),*cursor=pointer(app,8);
    if(_cursor.owned && ([self resolve:_cursor.controller]!=pc || [self resolve:_cursor.viewport]!=vp || _cursor.application!=app))[self releaseCursor];
    if(!app || !cursor)return NO;
    if(!_cursor.owned){
        void *instance=world ? _api.getGameInstance(world) : NULL;_focus=instance ? [self focusFor:instance] : @"";if(!_focus)return NO;
        _cursor=(RCCursorLease){.owned=YES,.controller=_controller,.viewport=[self weak:vp],.instance=[self weak:instance],.application=app,.cursor=cursor,
            .capture=byte(vp,0x3a2),.lock=byte(vp,0x3a4),.hide=byte(vp,0x3a3),.show=byte(pc,0x54c)&1,
            .visible=byte(cursor,0x110),.precision=byte(app,0x88),.type=integer(cursor,8),.moveCount=byte(pc,0x329),.lookCount=byte(pc,0x32a)};
        readAt(cursor,0x100,_cursor.rect,sizeof(_cursor.rect));
        if(_cursor.moveCount==255 || _cursor.lookCount==255){memset(&_cursor,0,sizeof(_cursor));return NO;}
        if(pc){_api.ignoreMove(pc,true);_api.ignoreLook(pc,true);}
    }
    // Unreal can reacquire capture after its own focus/input tick. Maintain our
    // lease while visible without stacking controller ignore reasons.
        if(vp){_api.setCapture(vp,0);_api.setLock(vp,0);_api.setHide(vp,false);}
        void *slate=pointer(_api.slateSlot,0);if(slate)_api.releaseCapture(slate,-1);
        _api.setPrecision(app,false,NULL);_api.cursorLock(cursor,NULL);_api.cursorType(cursor,1);_api.cursorShow(cursor,true);
        if(pc)MTWriteByte(pc,0x54c,byte(pc,0x54c)|1);
    BOOL success=byte(app,0x88)==0 && byte(cursor,0x111)==0 && byte(cursor,0x110)==1
        && (!vp || (byte(vp,0x3a2)==0 && byte(vp,0x3a4)==0)) && (!pc || (byte(pc,0x54c)&1));
    if(!success)[self releaseCursor];return success;
}
- (NSDictionary *)diagnosticMeasurements {
    if(![self gameThread] || ![NSProcessInfo.processInfo.environment[@"MT_TRAINER_DIAGNOSTICS"] hasPrefix:@"/private/tmp/"])return nil;
    void *player=[self resolve:_player],*health=[self resolve:_health],*movement=[self resolve:_movement],*weapon=[self resolve:_weapon],*progress=[self resolve:_progression],*world=[self resolve:_world],*attributes=[self resolve:_attributes];
    NSMutableDictionary *values=[NSMutableDictionary new];
    if(player){values[@"canBeDamaged"]=@((integer(player,0x58)&0x40000)!=0);values[@"playerTime"]=@(scalar(player,0x64));}
    if(health){values[@"health"]=@(scalar(health,0x10c));values[@"maximumHealth"]=@(scalar(health,0x114));values[@"incomingDamageFactor"]=@(scalar(health,0x248));}
    if(movement){values[@"sprintSpeed"]=@(scalar(movement,0xfb4));values[@"walkSpeed"]=@(scalar(movement,0x248));}
    if(weapon){values[@"clip"]=@(integer(weapon,0x6c0));values[@"capacity"]=@(_api.getClipCapacity(weapon));values[@"infiniteReserve"]=@(byte(weapon,0x8a4));values[@"magazineConsumption"]=@(byte(weapon,0xa30));values[@"fireRate"]=@(_api.getFireRate(weapon));values[@"shots"]=@(integer(weapon,0x750));values[@"spreadEnabled"]=@(byte(weapon,0x8a6));values[@"pelletSpread"]=@(scalar(weapon,0xa00));values[@"recoilEnabled"]=@(byte(weapon,0x8d4));values[@"shotShake"]=@(pointer(weapon,0x980)!=NULL || pointer(weapon,0x988)!=NULL);values[@"oneHitKill"]=@(_api.oneHitEnabled(weapon));values[@"hitDamage"]=@(_api.getHitDamage(weapon,true));}
    if(progress){values[@"xp"]=@(integer(progress,0xc0));values[@"level"]=@(integer(progress,0xc4));values[@"skillPoints"]=@(integer(progress,0xc8));values[@"maximumLevel"]=@(integer(progress,0xd8)+1);}
    if(attributes){values[@"xpBonus"]=@(scalar(attributes,0x1dc));values[@"xpBonusBase"]=@(scalar(attributes,0x1d8));void *property=pointer(progress,0x360);values[@"secondaryXPOffset"]=@(integer(property,0x44));}
    if(world)values[@"gameTime"]=@(_api.getTime(world));
    void *vp=_api.getViewport(),*app=pointer(_api.macApplicationSlot,0),*cursor=pointer(app,8),*pc=[self resolve:_controller];
    if(app && cursor)values[@"cursor"]=@{@"lease":@(_cursor.owned),@"precision":@(byte(app,0x88)),@"visible":@(byte(cursor,0x110)),@"hiddenForPrecision":@(byte(cursor,0x111)),@"capture":@(byte(vp,0x3a2)),@"lock":@(byte(vp,0x3a4)),@"showBit":@(byte(pc,0x54c)&1),@"ignoreMove":@(byte(pc,0x329)),@"ignoreLook":@(byte(pc,0x32a))};
    values[@"aiCount"]=@(_aiCount);NSMutableArray *times=[NSMutableArray new];
    for(RCDataLease *lease in _leases[@(MTFeatureAISpeed)]){void *owner=[self resolve:lease.owner];if(owner && times.count<8)[times addObject:@{ @"index":@(lease.owner.index),@"serial":@(lease.owner.serial),@"original":@(decode(lease.original,RCFloat)),@"current":@(scalar(owner,0x64))}];}
    values[@"aiTimes"]=times;return values;
}

@end
