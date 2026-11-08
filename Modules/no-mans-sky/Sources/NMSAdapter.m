// SPDX-License-Identifier: GPL-3.0-only
#import "NMSAdapter.h"
#import "MemoryAccess.h"
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <os/log.h>
#include <math.h>

// Every engine-specific constant below belongs ONLY to this arm64 UUID.
// A Steam update changes the UUID and is rejected before any engine access.
static NSString *const buildUUID=@"1FABCC98-D6B6-3905-BF1B-823BD5033DA9";
static NSMutableArray<dispatch_block_t> *pending;
static IMP originalUpdate;
static BOOL hookInstalled;
static _Thread_local BOOL onFrame;
static uintptr_t imageBase;
static __weak MTNMSAdapter *frameAdapter;
static __weak MTNMSAdapter *inputAdapter;
static BOOL frameMaintainedFeature(NSInteger i){return i>=MTFeatureShield&&i<MTFeatureCount&&i!=MTFeatureItems
    &&i!=MTFeatureInfiniteUnits&&i!=MTFeatureInfiniteNanites&&i!=MTFeatureInfiniteQuicksilver
    &&i!=MTFeatureCrafting&&i!=MTFeatureAtlasLocks&&i!=MTFeatureDamage&&i!=MTFeatureGameSpeed&&i!=MTFeatureShipHeat;}
@interface MTNMSAdapter (FrameMaintenance)
- (void)maintainFrameEffects;
- (void)maintainOverlayInput;
@end
static BOOL readable(uintptr_t p,void *out,size_t size){return MTReadMemory((const void *)p,out,size);}
static BOOL ptr(uintptr_t p,uintptr_t *out){return readable(p,out,sizeof(*out)) && *out>4096 && !(*out&7);}
BOOL MTNMSReadOnly(void){const char *value=getenv("NMS_TRAINER_READ_ONLY");return value&&!strcmp(value,"1");}
BOOL MTNMSProcessBuildMatches(void){
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *h=(const void *)_dyld_get_image_header(i);
        if(h->magic!=MH_MAGIC_64 || h->filetype!=MH_EXECUTE)continue;
        if(h->cputype!=CPU_TYPE_ARM64 || h->ncmds>4096 || h->sizeofcmds>1024*1024)return NO;
        const uint8_t *bytes=(const void *)(h+1);NSUInteger pos=0;
        for(uint32_t j=0;j<h->ncmds;j++){
            if(pos>h->sizeofcmds || sizeof(struct load_command)>h->sizeofcmds-pos)return NO;
            struct load_command c;memcpy(&c,bytes+pos,sizeof(c));
            if(c.cmdsize<sizeof(c) || c.cmdsize>h->sizeofcmds-pos)return NO;
            if(c.cmd==LC_UUID && c.cmdsize==sizeof(struct uuid_command)){
                struct uuid_command u;memcpy(&u,bytes+pos,sizeof(u));
                if(![[[NSUUID alloc]initWithUUIDBytes:u.uuid].UUIDString isEqual:buildUUID])return NO;
                imageBase=(uintptr_t)h;return YES;
            }pos+=c.cmdsize;
        }
    }return NO;
}
static uintptr_t address(uintptr_t preferred){return imageBase+(preferred-UINT64_C(0x100000000));}
ptrdiff_t MTNMSCaptureIvarOffset(Class viewClass){
    Ivar field=viewClass ? class_getInstanceVariable(viewClass,"isMouseCaptured") : NULL;
    if(!field)return -1;
    const char *type=ivar_getTypeEncoding(field);ptrdiff_t offset=ivar_getOffset(field);
    if(!type || (strcmp(type,"B") && strcmp(type,"c")) || offset<0 || (size_t)offset>=class_getInstanceSize(viewClass))return -1;
    return offset;
}
MTSessionKind MTNMSSessionKind(BOOL playing,BOOL enabled,const uint32_t sessions[3]){
    (void)enabled;(void)sessions;
    return playing ? MTSessionSolo : MTSessionLoading;
}
@implementation MTNMSValue {
    void *_address;NSUInteger _size;uint8_t _original[4],_last[4];BOOL _ownsValue;
}
- (instancetype)initWithAddress:(void *)a size:(NSUInteger)n {if((self=[super init])){if(!a || (n!=1 && n!=4))return nil;_address=a;_size=n;}return self;}
- (BOOL)ownsValue{return _ownsValue;}
- (BOOL)write:(const void *)value {
    if(_size==1)return MTWriteByte(_address,0,*(const uint8_t *)value);
    int32_t v;memcpy(&v,value,4);return MTWriteInt(_address,0,v);
}
- (BOOL)applyBytes:(const void *)bytes readOnly:(BOOL)readOnly {
    if(readOnly || !bytes)return NO;
    uint8_t current[4]={0};if(!MTReadMemory(_address,current,_size))return NO;
    // Never replace a concurrent change from the game, a menu, or another mod.
    if(_ownsValue && memcmp(current,_last,_size))return NO;
    if(!_ownsValue)memcpy(_original,current,_size);
    if(memcmp(current,bytes,_size) && ![self write:bytes])return NO;
    // Retain ownership even when a readback fails, so restoration is still attempted.
    memcpy(_last,bytes,_size);_ownsValue=YES;
    uint8_t actual[4]={0};return MTReadMemory(_address,actual,_size) && !memcmp(actual,bytes,_size);
}
- (BOOL)releaseValue {
    if(!_ownsValue)return YES;
    uint8_t current[4]={0};if(!MTReadMemory(_address,current,_size))return NO;
    if(memcmp(current,_last,_size)){_ownsValue=NO;return YES;}
    if(![self write:_original])return NO;
    if(!MTReadMemory(_address,current,_size) || memcmp(current,_original,_size))return NO;
    _ownsValue=NO;return YES;
}
@end

// The game's MetalKitApplication -update invokes IApp Update and Draw synchronously
// (arm64 0x102f1ec38, vtable slots 0x20 and 0x28). Drain AFTER the original update.
// No executable page, game vtable, or game file is patched.
static void frame(id self,SEL cmd){
    onFrame=YES;[inputAdapter maintainOverlayInput];onFrame=NO;
    ((void(*)(id,SEL))originalUpdate)(self,cmd);
    NSArray<dispatch_block_t> *batch;
    @synchronized(pending){batch=[pending copy];[pending removeAllObjects];}
    static dispatch_once_t once;dispatch_once(&once,^{os_log(os_log_create("local.mht.no-mans-sky","native"),"Game-frame dispatch confirmed; mainThread=%d",NSThread.isMainThread);});
    onFrame=YES;for(dispatch_block_t block in batch){@autoreleasepool{block();}}
    [frameAdapter maintainFrameEffects];[inputAdapter maintainOverlayInput];onFrame=NO;
}
static BOOL installFrame(void){
    if(hookInstalled)return YES;
    if(!MTNMSProcessBuildMatches())return NO;
    Class cls=NSClassFromString(@"MetalKitApplication");SEL selector=NSSelectorFromString(@"update");
    Method m=class_getInstanceMethod(cls,selector);if(!m || strcmp(method_getTypeEncoding(m),"v16@0:8"))return NO;
    IMP imp=method_getImplementation(m);
    if((uintptr_t)imp!=address(0x102f1ec38))return NO;
    os_log(os_log_create("local.mht.no-mans-sky","native"),"Installing native frame dispatch");
    pending=[NSMutableArray new];originalUpdate=method_setImplementation(m,(IMP)frame);hookInstalled=YES;return YES;
}
static NSString *nativeString(uintptr_t p){char bytes[128]={0};if(!readable(p,bytes,127))return nil;return [[NSString alloc]initWithUTF8String:bytes];}
// Native cTkClassMetadata member records have 88 bytes in the bound build.
// Validate name, type, scalar count and bounds instead of guessing an object offset.
static uintptr_t memberWithCount(const char *global,const char *metadata,NSString *name,uint32_t type,uint32_t expectedCount,uint32_t size){
    uintptr_t meta=(uintptr_t)dlsym(RTLD_DEFAULT,metadata),owner=(uintptr_t)dlsym(RTLD_DEFAULT,global),table=0;
    uint32_t count=0,classSize=0;
    if(!meta || !owner || !ptr(meta+24,&table) || !readable(meta+32,&count,4) || !readable(meta+36,&classSize,4) || count>2048 || classSize>65536)return 0;
    uintptr_t found=0;
    for(uint32_t i=0;i<count;i++){
        uint8_t r[88];if(!readable(table+(uintptr_t)i*88,r,sizeof(r)))return 0;
        uintptr_t text=0;uint32_t actualType=0,elements=0,offset=0;
        memcpy(&text,r,8);memcpy(&actualType,r+20,4);memcpy(&elements,r+24,4);memcpy(&offset,r+28,4);
        if(![nativeString(text) isEqual:name])continue;
        if(found || actualType!=type || elements!=expectedCount || offset>classSize || size>classSize-offset){os_log_error(os_log_create("local.mht.no-mans-sky","native"),"Metadata mismatch %{public}s actualType=%u expected=%u count=%u offset=%u",name.UTF8String,actualType,type,elements,offset);return 0;}
        found=owner+offset;
    }return found;
}
static uintptr_t member(const char *global,const char *metadata,NSString *name,uint32_t type,uint32_t size){
    return memberWithCount(global,metadata,name,type,1,size);
}
// Build-bound C++ ABI: sInventoryElementEdit returns 72 bytes via arm64 x8.
// No inventory/weapon child pointer is retained across a native transaction.
// GetHandle (0x100325218) packs choice in the low word and index in the
// high word of x1. Weapon handles legitimately use index=-1.
typedef struct { uint64_t store; int32_t choice,index; } MTNMSInventoryHandle;
typedef struct { uint8_t bytes[48]; } MTNMSInventoryElement;
typedef struct { uint64_t validStore; MTNMSInventoryElement element; MTNMSInventoryHandle handle; } MTNMSInventoryEdit;
_Static_assert(sizeof(MTNMSInventoryEdit)==72,"Native inventory edit ABI");
static void *nativeEntry(const char *symbol,uintptr_t preferred){
    void *p=dlsym(RTLD_DEFAULT,symbol);
    // Local (non-exported) native methods use only this verified image's address.
    return p && (uintptr_t)p==address(preferred) ? p : (void *)address(preferred);
}
static BOOL writeFloatBack(uintptr_t owner,NSUInteger offset,float value){
    float actual=0;return MTWriteFloat((void *)owner,offset,value) && readable(owner+offset,&actual,4) && actual==value;
}
static BOOL writeIntBack(uintptr_t owner,NSUInteger offset,int32_t value){
    int32_t actual=0;return MTWriteInt((void *)owner,offset,value) && readable(owner+offset,&actual,4) && actual==value;
}
static BOOL writeByteBack(uintptr_t owner,NSUInteger offset,uint8_t value){
    uint8_t actual=255;return MTWriteByte((void *)owner,offset,value) && readable(owner+offset,&actual,1) && actual==value;
}
BOOL MTNMSPrepareRecharge(void *bytes,NSUInteger length){
    if(!bytes || length!=72)return NO;
    MTNMSInventoryEdit *edit=bytes;int32_t amount=0,maximum=0;float damage=0;uint32_t type=0;
    memcpy(&amount,edit->element.bytes+0x18,4);memcpy(&maximum,edit->element.bytes+0x20,4);
    memcpy(&damage,edit->element.bytes+0x1c,4);memcpy(&type,edit->element.bytes+0x24,4);
    if(edit->validStore<=4096 || (edit->validStore&7) || edit->handle.index < -1 || edit->handle.choice<0 || edit->handle.choice>32 || type!=1
        || !isfinite(damage) || damage!=0 || amount<0 || maximum<=0 || maximum>100000000 || amount>maximum)return NO;
    memcpy(edit->element.bytes+0x18,&maximum,4);return YES;
}

@interface MTNMSAdapter () {
    BOOL _bound,_failed;NSString *_failure,*_identity;uintptr_t _root,_playerState;
    NSMutableDictionary<NSNumber *,MTNMSValue *> *_values;
    NSMutableDictionary<NSNumber *,NSNumber *> *_addresses;
    BOOL _wantedCache[MTFeatureCount],_confirmed[MTFeatureCount],_operationFailed[MTFeatureCount],_hasReport[MTFeatureCount];
    uint8_t _lastReportBits[MTFeatureCount];
    NSMutableDictionary<NSString *,NSMutableDictionary<NSString *,NSData *> *> *_itemSnapshots;
    NSMutableDictionary<NSData *,NSDictionary *> *_atlasCosts;
    BOOL _mouseOwned;uint8_t _captureBefore,_hiddenBefore,_windowCaptureBefore,_viewCaptureBefore,_lockBefore,_showBefore;
    uintptr_t _inputOwner,_deviceOwner;
    os_log_t _log;
}
@end
@interface MTNMSAdapter (ExtendedOperations)
- (MTFeatureState *)applyExtendedFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value;
@end
@implementation MTNMSAdapter
- (instancetype)init {if((self=[super init])){_log=os_log_create("local.mht.no-mans-sky","native");_values=[NSMutableDictionary new];_addresses=[NSMutableDictionary new];_itemSnapshots=[NSMutableDictionary new];_atlasCosts=[NSMutableDictionary new];}return self;}
- (void)onGameThread:(dispatch_block_t)work {
    if(installFrame()){frameAdapter=self;@synchronized(pending){if(pending.count<64)[pending addObject:[work copy]];}}
    else { if(!_failed)os_log_error(_log,"Native frame entry mismatch");_failure=@"GameThread-Anbindung passt nicht zum geprüften Build.";_failed=YES;dispatch_async(dispatch_get_main_queue(),work);}
}
- (BOOL)bind {
    if(_bound)return YES;if(_failed || !onFrame || !MTNMSProcessBuildMatches())return NO;
    const char *debug="_ZN15cGcDebugOptions14mClassMetadataE",*player="_ZN16cGcPlayerGlobals14mClassMetadataE";
    struct Binding {MTFeature feature;const char *global,*meta;__unsafe_unretained NSString *name;uint32_t type,size;};
    struct Binding bindings[]={
        {MTFeatureHealth,"gGcDebugOptions",debug,@"TakeNoDamage",1,1},
        {MTFeatureStamina,"gGcDebugOptions",debug,@"InfiniteStamina",1,1},
        {MTFeatureAmmo,"gGcPlayerGlobals",player,@"UseEnergy",1,1},
        {MTFeatureSpeed,"gGcDebugOptions",debug,@"SprintMultiplier",4,4},
        {MTFeatureHazards,"gGcPlayerGlobals",player,@"UseHazardProtection",1,1},
        {MTFeatureLanguages,"gGcDebugOptions",debug,@"DoAlienLanguage",1,1},
        {MTFeatureDamage,"gGcDebugOptions",debug,@"SuperKillGuns",1,1}
    };
    for(NSUInteger i=0;i<sizeof(bindings)/sizeof(bindings[0]);i++){
        struct Binding b=bindings[i];uintptr_t a=member(b.global,b.meta,b.name,b.type,b.size);
        if(!a && b.feature>=MTFeatureShield)continue;
        if(!a){_failure=[@"Native Metadaten nicht bestätigt: " stringByAppendingString:b.name];os_log_error(_log,"Binding failed %{public}s",b.name.UTF8String);_failed=YES;return NO;}
        if(b.size==1){uint8_t v=0;if(!readable(a,&v,1) || v>1){_failure=@"Ungültiger nativer Schalter.";_failed=YES;return NO;}}
        else {float v=0;if(!readable(a,&v,4) || !isfinite(v) || v<=0 || v>100){_failure=@"Ungültiger nativer Sprintfaktor.";_failed=YES;return NO;}}
        _addresses[@(b.feature)]=@(a);_values[@(b.feature)]=[[MTNMSValue alloc]initWithAddress:(void *)a size:b.size];
    }
    for(const char **s=(const char *[]){"_ZN14cGcPlayerState10AwardUnitsEi","_ZN14cGcPlayerState12AwardNanitesEi","_ZN14cGcPlayerState13AwardSpecialsEi",NULL};*s;s++)if(!dlsym(RTLD_DEFAULT,*s)){_failure=@"Native Währungsfunktion fehlt.";_failed=YES;return NO;}
    uintptr_t clock=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN14cTkTimeManager11mLocalClockE");
    float factor=0;
    if(clock && readable(clock+0x24,&factor,4) && isfinite(factor) && factor>=0 && factor<=100)
        _values[@(MTFeatureGameSpeed)]=[[MTNMSValue alloc]initWithAddress:(void *)(clock+0x24) size:4];
    const char *ship="_ZN19cGcSpaceshipGlobals14mClassMetadataE";
    for(NSUInteger i=0;i<2;i++){
        uintptr_t a=member("gGcSpaceshipGlobals",ship,i ? @"ProjectileOverheatTime" : @"LaserOverheatTime",4,4);
        float t=0;if(a && readable(a,&t,4) && isfinite(t) && t>=0 && t<1000000)
            _values[@(i ? 1000 : MTFeatureShipHeat)]=[[MTNMSValue alloc]initWithAddress:(void *)a size:4];
    }
    _bound=YES;os_log(_log,"Native bindings confirmed; readOnly=%d mainThread=%d",MTNMSReadOnly(),NSThread.isMainThread);return YES;
}
- (MTGameContext *)captureContext {
    MTGameContext *c=[MTGameContext new];c.readOnly=MTNMSReadOnly();c.kind=MTSessionLoading;c.identity=@"nms-loading";c.note=@"Wartet auf geladenen Spielstand.";
    _playerState=0;
    if(![self bind]){if(_failed){c.kind=MTSessionUnsupported;c.note=_failure ?: @"Native Anbindung nicht bestätigt.";}return c;}
    uintptr_t app=(uintptr_t)dlsym(RTLD_DEFAULT,"gApplication"),fsm=0,root=0;
    if(!app || !ptr(app+0x38,&root) || !ptr(app+0x10,&fsm))return c;
    char state[16]={0};if(!readable(fsm+8,state,16) || memcmp(state,"APPVIEW\0\0\0\0\0\0\0\0\0",16))return c;
    MTSessionKind kind=MTNMSSessionKind(YES,NO,NULL);
    uint64_t uid=0;uintptr_t uidAddress=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN12cGcGameState16muCurrentSaveUidE");
    if(!uidAddress || !readable(uidAddress,&uid,8))return c;
    // The player-state object is embedded in the application allocation, not a
    // heap entity. The current-save UID and APPVIEW lifecycle guard its owner.
    uintptr_t ps=root+0xd40+0xaad0;uint32_t balances[3]={0};
    if(!readable(ps+0x894,balances,sizeof(balances)))return c;
    _root=root;_playerState=ps;
    c.kind=kind;c.identity=[NSString stringWithFormat:@"nms:%llx:%llx",(unsigned long long)root,(unsigned long long)uid];
    c.note=MTNMSReadOnly() ? @"Nur lesen: keine Trainer-Werte werden geändert." : @"Native Anbindung an den geprüften Steam-Build.";
    _identity=c.identity;return c;
}
- (void)releaseEffects {
    if(_atlasCosts.count && ![self updateAtlasCosts:NO])os_log_error(_log,"Atlas cost restoration not confirmed");
    memset(_wantedCache,0,sizeof(_wantedCache));memset(_confirmed,0,sizeof(_confirmed));memset(_operationFailed,0,sizeof(_operationFailed));[_itemSnapshots removeAllObjects];
    for(MTNMSValue *v in _values.allValues)if(![v releaseValue])os_log_error(_log,"Native restoration failed; ownership retained");
}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[self evaluateFeature:feature wanted:wanted value:value];
    if(MTFeatureInfoAt(feature)){
        uint8_t bits=(wanted ? 1 : 0)|(state.available ? 2 : 0)|(state.active ? 4 : 0);
        if(!_hasReport[feature] || _lastReportBits[feature]!=bits){
            _hasReport[feature]=YES;_lastReportBits[feature]=bits;
            os_log(_log,"Feature %{public}ld %{public}s wanted=%d available=%d readback=%d: %{public}s",(long)feature,MTFeatureInfoAt(feature)->title.UTF8String,wanted,state.available,state.active,(state.note ?: @"").UTF8String);
        }
    }return state;
}
- (MTFeatureState *)evaluateFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *s=[MTFeatureState new];
    if(!MTFeatureInfoAt(feature))return s;
    if(!onFrame || MTNMSReadOnly()){s.note=@"Nur lesen · keine Cheat-Anwendung.";return s;}
    MTGameContext *c=[self captureContext];if((c.kind!=MTSessionSolo && c.kind!=MTSessionNetwork)){[self releaseEffects];s.note=c.note;return s;}
    const MTFeatureInfo *info=MTFeatureInfoAt(feature);if(!info)return s;
    _wantedCache[feature]=wanted;if(!wanted)_operationFailed[feature]=NO;
    s.available=YES;MTNMSValue *binding=_values[@(feature)];
    if(feature>=MTFeatureShield){MTFeatureState *actual=[self applyExtendedFeature:feature wanted:wanted value:value];_confirmed[feature]=actual.active;return actual;}
    if(info->oneShot){s.note=@"Einmalige native Gabe; kann vom Spiel gespeichert werden.";return s;}
    if(!binding){s.available=NO;s.note=@"Keine geprüfte native Bindung.";return s;}
    if(!wanted){s.note=[binding releaseValue] ? @"Aus · eigene Änderung zurückgenommen." : @"Rücknahme fehlgeschlagen.";return s;}
    BOOL ok=NO;
    if(feature==MTFeatureSpeed){if(!isfinite(value) || value<0.25 || value>4){s.note=@"Ungültiger Sprintfaktor.";return s;}float v=(float)value;ok=[binding applyBytes:&v readOnly:NO];}
    else {uint8_t v=(feature==MTFeatureAmmo || feature==MTFeatureHazards || feature==MTFeatureLanguages) ? 0 : 1;ok=[binding applyBytes:&v readOnly:NO];}
    s.active=ok;s.note=ok ? @"Nativer Wert gesetzt und zurückgelesen; Wirkung im Spiel ungeprüft." : @"Schreibprüfung fehlgeschlagen oder fremde Änderung erkannt.";return s;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {
    if(!onFrame || MTNMSReadOnly())return @"Nur lesen · Währungsaktion blockiert.";
    NSString *identity=[_identity copy];MTGameContext *c=[self captureContext];
    if(((c.kind!=MTSessionSolo && c.kind!=MTSessionNetwork)) || ![identity isEqual:c.identity] || !_playerState)return @"Kontextwechsel · Aktion verworfen.";
    const char *symbol=NULL;NSUInteger offset=0;uint32_t amount=0;
    if(feature==MTFeatureMoney){symbol="_ZN14cGcPlayerState10AwardUnitsEi";offset=0x894;}
    else if(feature==MTFeatureResources){symbol="_ZN14cGcPlayerState12AwardNanitesEi";offset=0x898;value=100;}
    else if(feature==MTFeatureQuicksilver){symbol="_ZN14cGcPlayerState13AwardSpecialsEi";offset=0x89c;}
    if(!symbol || !isfinite(value) || value<0 || value>999999999 || floor(value)!=value)return @"Ungültige Währungsaktion.";
    amount=(uint32_t)value;uint32_t before=0,after=0;
    if(!readable(_playerState+offset,&before,4) || amount>UINT32_MAX-before)return @"Währungsgrenze oder Lesefehler · keine Gabe.";
    uint32_t (*award)(void *,int)=(void *)dlsym(RTLD_DEFAULT,symbol);if(!award)return @"Native Funktion fehlt.";
    award((void *)_playerState,(int)amount);
    if(!readable(_playerState+offset,&after,4) || after!=before+amount)return @"Native Aktion ausgeführt; Rückleseprüfung fehlgeschlagen. Nicht automatisch wiederholt.";
    return [NSString stringWithFormat:@"%@ +%u → %u · nativ zurückgelesen",MTFeatureInfoAt(feature)->title,amount,after];
}
- (void)maintainOverlayInput {
    if(_mouseOwned && onFrame && NSThread.isMainThread && NSApp.isActive)[self setOverlayInteraction:YES];
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {
    if(!wanted&&!_mouseOwned)return NO;
    if(!onFrame || !NSThread.isMainThread)return NO;
    uintptr_t input=0,root=0,parent=0,view=0,vtable=0;
    uintptr_t app=(uintptr_t)dlsym(RTLD_DEFAULT,"gApplication"),window=(uintptr_t)dlsym(RTLD_DEFAULT,"gCurrentWindow");
    if(!app || !window || !ptr(app+0x38,&root) || !ptr(root+0x971bc8,&parent)
       || !ptr(address(0x103d8f518),&input) || !ptr(input+0x1e0,&view))return NO;
    // cTkInputManager contains its concrete DeviceManager at +8. The original
    // constructor stores this exact vtable; never treat an unrelated child as it.
    uintptr_t device=parent+8;
    if(!readable(device,&vtable,8) || vtable!=address(0x103697768))return NO;
    Class viewClass=NSClassFromString(@"GainputMacInputView");
    ptrdiff_t captureOffset=MTNMSCaptureIvarOffset(viewClass);
    Method setter=viewClass ? class_getInstanceMethod(viewClass,NSSelectorFromString(@"SetMouseCapture:")) : NULL;
    if(captureOffset<0 || !setter || (uintptr_t)method_getImplementation(setter)!=address(0x10143dc08))return NO;
    uint8_t captured=0,hidden=0,windowCapture=0,viewCapture=0,locked=0,shown=0;
    if(!readable(input+0x231,&captured,1) || !readable(window+0x15c,&hidden,1)
       || !readable(window+0x3d,&windowCapture,1) || !readable(view+(uintptr_t)captureOffset,&viewCapture,1)
       || !readable(device+0x2c,&locked,1) || !readable(device+0x20d,&shown,1)
       || captured>1 || hidden>1 || windowCapture>1 || viewCapture>1 || locked>1 || shown>1)return NO;
    BOOL(*capture)(BOOL)=(void *)dlsym(RTLD_DEFAULT,"_Z21setEnableCaptureInputb");
    void(*captureWindow)(void *,BOOL)=(void *)dlsym(RTLD_DEFAULT,"_Z13captureCursorP10WindowDescb");
    void(*show)(void)=(void *)dlsym(RTLD_DEFAULT,"_Z10showCursorv");void(*hide)(void)=(void *)dlsym(RTLD_DEFAULT,"_Z10hideCursorv");
    void(*showDevice)(void *)=(void *)dlsym(RTLD_DEFAULT,"_ZN21cTkInputDeviceManager9ShowMouseEv");
    void(*hideDevice)(void *)=(void *)dlsym(RTLD_DEFAULT,"_ZN21cTkInputDeviceManager9HideMouseEv");
    void(*lock)(void *)=nativeEntry("_ZN21cTkInputDeviceManager9LockMouseEv",0x103140dc0);
    void(*unlock)(void *)=nativeEntry("_ZN21cTkInputDeviceManager11UnlockMouseEv",0x103140de0);
    if(!capture || !captureWindow || !show || !hide || !showDevice || !hideDevice)return NO;
    id nativeView=(__bridge id)(void *)view;
    if(wanted){
        if(!_mouseOwned){
            _inputOwner=input;_deviceOwner=device;_captureBefore=captured;_hiddenBefore=hidden;
            _windowCaptureBefore=windowCapture;_viewCaptureBefore=viewCapture;_lockBefore=locked;_showBefore=shown;
            _mouseOwned=YES;inputAdapter=self;
        }
        if(input!=_inputOwner || device!=_deviceOwner)return NO;
        // Set the actual engine intent, not only the lower-level capture flag.
        // DeviceManager::Update otherwise recaptures/hides the cursor next frame.
        unlock((void *)device);showDevice((void *)device);
        capture(NO);captureWindow((void *)window,NO);
        ((void(*)(id,SEL,BOOL))objc_msgSend)(nativeView,NSSelectorFromString(@"SetMouseCapture:"),NO);
        show();
        uint8_t a=1,b=1,c=1,d=1,e=1,f=0;
        return readable(input+0x231,&a,1) && !a && readable(window+0x3d,&b,1) && !b
            && readable(view+(uintptr_t)captureOffset,&c,1) && !c && readable(device+0x2c,&d,1) && !d
            && readable(window+0x15c,&e,1) && !e && readable(device+0x20d,&f,1) && f==1;
    }
    if(_mouseOwned){
        BOOL(*frontend)(void *)=(void *)dlsym(RTLD_DEFAULT,"_ZN14cGcApplication16IsFrontendActiveEv");
        BOOL menu=frontend && frontend((void *)app);
        if(input==_inputOwner && device==_deviceOwner && !menu){
            if(_lockBefore)lock((void *)device);else unlock((void *)device);
            if(_showBefore)showDevice((void *)device);else hideDevice((void *)device);
            // Never recapture the physical cursor while another application is active.
            if(NSApp.isActive){
                capture(_captureBefore);captureWindow((void *)window,_windowCaptureBefore);
                ((void(*)(id,SEL,BOOL))objc_msgSend)(nativeView,NSSelectorFromString(@"SetMouseCapture:"),_viewCaptureBefore);
                if(_hiddenBefore)hide();else show();
            }
        }
        _mouseOwned=NO;_inputOwner=0;_deviceOwner=0;if(inputAdapter==self)inputAdapter=nil;
    }return NO;
}

- (uintptr_t)localPlayer {return _root+0x4ca550+0x25f850;}
- (uintptr_t)localWeapon {return [self localPlayer]+0x3c0;}
- (BOOL)inventoryLayoutValid {
    const char *meta="_ZN19cGcInventoryElement14mClassMetadataE";uintptr_t base=(uintptr_t)dlsym(RTLD_DEFAULT,meta);
    return base && member(meta,meta,@"Amount",4,4)==base+0x18 && member(meta,meta,@"MaxAmount",4,4)==base+0x20
        && member(meta,meta,@"DamageFactor",4,4)==base+0x1c && member(meta,meta,@"Type",4,4)==base+0x24
        && member(meta,meta,@"Index",8,8)==base+0x10;
}
- (MTNMSInventoryEdit)editStat:(int)stat inventory:(int)choice {
    MTNMSInventoryEdit (*fn)(void *,int,int,int,int)=nativeEntry("_ZN14cGcPlayerState28GetPrimaryItemForStatForEditE10eStatsType16eInventoryChoice14ItemLookupTypei",0x10035c6b0);
    return fn((void *)_playerState,stat,choice,0,-1);
}
- (BOOL)commitRecharge:(MTNMSInventoryEdit)edit reread:(MTNMSInventoryEdit (^)(void))reread {
    if(![self inventoryLayoutValid] || !MTNMSPrepareRecharge(&edit,sizeof(edit)))return NO;
    MTNMSInventoryEdit before=reread();
    // Both the native inventory handle and slot/item identity must still match.
    if(memcmp(&before.handle,&edit.handle,sizeof(edit.handle)) || memcmp(before.element.bytes,edit.element.bytes,24))return NO;
    int32_t current=0,target=0;memcpy(&current,before.element.bytes+0x18,4);memcpy(&target,edit.element.bytes+0x18,4);
    if(current!=target){
        void (*commit)(void *,const MTNMSInventoryEdit *)=nativeEntry("_ZN14cGcPlayerState26CommitInventoryElementEditERK21sInventoryElementEdit",0x10035cb0c);
        commit((void *)_playerState,&edit);
    }
    MTNMSInventoryEdit after=reread();int32_t actual=0;memcpy(&actual,after.element.bytes+0x18,4);
    return after.validStore && !memcmp(&after.handle,&edit.handle,sizeof(edit.handle))
        && !memcmp(after.element.bytes,edit.element.bytes,24) && actual==target;
}
- (BOOL)rechargeStat:(int)stat inventory:(int)choice {
    MTNMSInventoryEdit edit=[self editStat:stat inventory:choice];
    return [self commitRecharge:edit reread:^{return [self editStat:stat inventory:choice];}];
}
- (BOOL)equippedMode:(int32_t *)mode weaponClass:(int32_t *)kind {
    uintptr_t data=0;
    if(!readable([self localWeapon]+0xf54,mode,4) || *mode<0 || *mode>31 || !ptr(_root+0x60+0x298,&data))return NO;
    return readable(data+(uintptr_t)*mode*0x150+0x134,kind,4) && *kind>0 && *kind<=10;
}
- (BOOL)rechargeTool {
    uintptr_t weapon=[self localWeapon];int32_t mode=-1,kind=0;
    if(![self equippedMode:&mode weaponClass:&kind])return NO;
    MTNMSInventoryEdit (*get)(void *,int)=nativeEntry("_ZN15cGcPlayerWeapon23GetInventoryItemForEditE11eWeaponMode",0x100df7834);
    MTNMSInventoryEdit edit=get((void *)weapon,mode);
    return [self commitRecharge:edit reread:^{return get((void *)weapon,mode);}];
}
- (BOOL)fillMagazine {
    uintptr_t weapon=[self localWeapon];int32_t mode=-1,kind=0;
    if(![self equippedMode:&mode weaponClass:&kind] || (kind!=1 && kind!=2))return NO;
    // GetClipSize reads the current equipped mode; lasers/utilities have no clip.
    int (*clipSize)(void *)=nativeEntry("_ZNK15cGcPlayerWeapon11GetClipSizeEv",0x100df7620);
    int maximum=clipSize((void *)weapon);if(maximum<=0 || maximum>1000000)return NO;
    int (*get)(void *,int)=nativeEntry("_ZNK15cGcPlayerWeapon7GetAmmoE11eWeaponMode",0x1003539f8);
    void (*set)(void *,int,int)=nativeEntry("_ZN15cGcPlayerWeapon7SetAmmoE11eWeaponModei",0x10034f4a8);
    if(get((void *)weapon,mode)!=maximum)set((void *)weapon,mode,maximum);
    return get((void *)weapon,mode)==maximum;
}
- (BOOL)fillItems {
    if(![self inventoryLayoutValid])return NO;
    uintptr_t inventory=_playerState+0x8f8;
    MTNMSInventoryHandle (*handleFor)(void *,int,int)=nativeEntry("_ZNK18cGcPlayerInventory9GetHandleE16eInventoryChoicei",0x10032589c);
    void *(*storeFor)(void *,const MTNMSInventoryHandle *)=nativeEntry("_ZN18cGcPlayerInventory17GetStoreWriteableERK18cGcInventoryHandle",0x100325b74);
    void *(*getElement)(void *,const uint64_t *)=nativeEntry("_ZN17cGcInventoryStore20GetElementForEditingERK17cGcInventoryIndex",0x1003393a8);
    int (*maxStorage)(void *,const MTNMSInventoryElement *)=nativeEntry("_ZNK17cGcInventoryStore17GetSlotMaxStorageERK19cGcInventoryElement",0x1002be0dc);
    BOOL (*setElement)(void *,const MTNMSInventoryHandle *,const MTNMSInventoryElement *)=nativeEntry("_ZN18cGcPlayerInventory19SetInventoryElementERK18cGcInventoryHandleRK19cGcInventoryElement",0x10032648c);
    BOOL checked=NO,ok=YES;
    for(NSNumber *number in @[@0,@2,@4,@6]){
        MTNMSInventoryHandle handle=handleFor((void *)inventory,number.intValue,-1);
        uintptr_t store=(uintptr_t)storeFor((void *)inventory,&handle);uint32_t count=0;uintptr_t elements=0;
        if(!store || !readable(store+0x8c,&count,4) || count>512 || (count && !ptr(store+0x90,&elements)))continue;
        NSString *key=[NSString stringWithFormat:@"%llx:%d:%d",(unsigned long long)handle.store,handle.index,handle.choice];
        NSMutableDictionary<NSString *,NSData *> *snapshot=_itemSnapshots[key];
        if(!snapshot){if(_itemSnapshots.count>=8)[_itemSnapshots removeAllObjects];snapshot=[NSMutableDictionary new];_itemSnapshots[key]=snapshot;}
        for(uint32_t j=0;j<count;j++){
            MTNMSInventoryElement element;uint32_t type=0;int32_t amount=0;uint64_t index=0;
            if(!readable(elements+(uintptr_t)j*48,&element,sizeof(element)))continue;
            memcpy(&type,element.bytes+0x24,4);memcpy(&amount,element.bytes+0x18,4);memcpy(&index,element.bytes+0x10,8);
            if((type!=0 && type!=2) || amount<=0)continue;
            NSString *slot=[NSString stringWithFormat:@"%llx",(unsigned long long)index];
            snapshot[slot]=[NSData dataWithBytes:&element length:sizeof(element)];
        }
        for(NSString *slot in snapshot.allKeys){
            MTNMSInventoryElement element;[snapshot[slot] getBytes:&element length:sizeof(element)];uint64_t index=0;
            memcpy(&index,element.bytes+0x10,8);store=(uintptr_t)storeFor((void *)inventory,&handle);if(!store){ok=NO;continue;}
            uintptr_t current=(uintptr_t)getElement((void *)store,&index);MTNMSInventoryElement actual;
            if(current){
                if(!readable(current,&actual,sizeof(actual)) || memcmp(actual.bytes,element.bytes,24))continue; // slot was moved/replaced
                element=actual;
            }
            int maximum=maxStorage((void *)store,&element);if(maximum<=0 || maximum>100000000){ok=NO;continue;}
            int amount=0;memcpy(&amount,element.bytes+0x18,4);memcpy(element.bytes+0x18,&maximum,4);
            if(!current || amount!=maximum)if(!setElement((void *)inventory,&handle,&element)){ok=NO;continue;}
            store=(uintptr_t)storeFor((void *)inventory,&handle);current=store ? (uintptr_t)getElement((void *)store,&index) : 0;
            if(!current || !readable(current,&actual,sizeof(actual)) || memcmp(actual.bytes,element.bytes,24)){ok=NO;continue;}
            memcpy(&amount,actual.bytes+0x18,4);checked=YES;ok&=amount==maximum;
        }
    }return checked && ok;
}
- (BOOL)holdCurrency:(MTFeature)feature {
    if(_operationFailed[feature])return NO;
    MTFeature action=feature==MTFeatureInfiniteUnits ? MTFeatureMoney : feature==MTFeatureInfiniteNanites ? MTFeatureResources : MTFeatureQuicksilver;
    NSUInteger offset=action==MTFeatureMoney ? 0x894 : action==MTFeatureResources ? 0x898 : 0x89c;
    uint32_t before=0,after=0,floor=999999999;
    if(!readable(_playerState+offset,&before,4))return NO;
    if(before>=floor)return YES;
    const char *symbol=action==MTFeatureMoney ? "_ZN14cGcPlayerState10AwardUnitsEi" : action==MTFeatureResources ? "_ZN14cGcPlayerState12AwardNanitesEi" : "_ZN14cGcPlayerState13AwardSpecialsEi";
    uint32_t (*award)(void *,int)=(void *)dlsym(RTLD_DEFAULT,symbol);if(!award)return NO;
    award((void *)_playerState,(int)(floor-before));
    BOOL ok=readable(_playerState+offset,&after,4) && after==floor;
    if(!ok)_operationFailed[feature]=YES;return ok;
}
- (BOOL)runExtendedOperation:(MTFeature)feature {
    uintptr_t player=[self localPlayer],weapon=[self localWeapon];
    if(feature==MTFeatureShield){
        int (*maximum)(void *,int)=nativeEntry("_ZNK14cGcPlayerState16GetMaximumShieldE16eInventoryChoice",0x10035cc08);
        int n=maximum((void *)_playerState,0);return n>0 && n<=100000000 && writeIntBack(_playerState,0x888,n);
    }
    if(feature==MTFeatureJetpack){
        float (*maximum)(void *)=nativeEntry("_ZNK9cGcPlayer18GetJetpackTankSizeEv",0x100e1f880);
        float n=maximum((void *)player);return isfinite(n) && n>0 && n<100000 && writeFloatBack(player,0x34e4,n);
    }
    if(feature==MTFeatureMultiToolHeat){int32_t mode=0,kind=0;if(![self equippedMode:&mode weaponClass:&kind] || kind!=3)return NO;float old=0;return readable(weapon+0x23b0,&old,4) && isfinite(old) && old>=0 && old<100000 && writeFloatBack(weapon,0x23b0,0);}
    if(feature==MTFeatureNoReload)return [self fillMagazine];
    if(feature==MTFeatureGrenades){BOOL any=NO;for(NSNumber *stat in @[@37,@48,@54])any|=[self rechargeStat:stat.intValue inventory:3];return any;}
    if(feature==MTFeatureItems)return [self fillItems];
    if(feature==MTFeatureShipHealth){
        int (*maximum)(void *)=nativeEntry("_ZNK14cGcPlayerState20GetMaximumShipHealthEv",0x10035c390);
        int n=maximum((void *)_playerState);return n>0 && n<100000000 && writeIntBack(_playerState,0x890,n);
    }
    if(feature==MTFeatureShipShield)return [self rechargeStat:142 inventory:4];
    if(feature==MTFeatureInfiniteUnits || feature==MTFeatureInfiniteNanites || feature==MTFeatureInfiniteQuicksilver)return [self holdCurrency:feature];
    if(feature==MTFeatureLaunchFuel)return [self rechargeStat:152 inventory:4];
    if(feature==MTFeaturePulseFuel)return [self rechargeStat:155 inventory:4];
    if(feature==MTFeatureHyperdriveFuel)return [self rechargeStat:148 inventory:4];
    if(feature==MTFeatureScanner){
        // cGcSimulation::Construct -> ScanManager(+0xf1b0) -> Scanner(+0x60).
        // UpdateScanEffect reads/writes this scanner's normalized progress at +0x10.
        uintptr_t scanner=_root+0x4ca550+0xf1b0+0x60;float progress=0;
        return readable(scanner+0x10,&progress,4) && isfinite(progress) && progress>=0 && progress<=1.01 && writeFloatBack(scanner,0x10,1);
    }
    if(feature==MTFeatureToolEnergy)return [self rechargeTool];
    return NO;
}
- (BOOL)bindCostValue:(NSInteger)key address:(uintptr_t)a {
    uint8_t flag=0;if(!readable(a,&flag,1) || flag>1)return NO;
    if(_addresses[@(key)].unsignedLongLongValue!=a){
        if(![_values[@(key)] releaseValue] && _values[@(key)])return NO;
        _values[@(key)]=[[MTNMSValue alloc]initWithAddress:(void *)a size:1];_addresses[@(key)]=@(a);
    }return _values[@(key)]!=nil;
}
- (BOOL)updateAtlasCosts:(BOOL)wanted {
    if(!wanted && !_atlasCosts.count)return YES;
    const char *product="_ZN14cGcCostProduct14mClassMetadataE",*entryMeta="_ZN17cGcCostTableEntry14mClassMetadataE";
    uintptr_t pm=(uintptr_t)dlsym(RTLD_DEFAULT,product),em=(uintptr_t)dlsym(RTLD_DEFAULT,entryMeta);
    if(!pm || !em || member(product,product,@"Id",16,16)!=pm || member(product,product,@"Amount",4,4)!=pm+16
        || member(product,product,@"UseDefaultAmount",1,1)!=pm+25 || member(entryMeta,entryMeta,@"Id",16,16)!=em+80
        || member(entryMeta,entryMeta,@"Cost",16,16)!=em+64)return NO;
    // RealityManager::LookUpCostByID (0x1009940a8) indexes 24-byte map records.
    // Resolve every recorded cost afresh by its native TkID. Never dereference
    // a saved child address; the saved address is only an identity comparison.
    uintptr_t reality=_root+0x60,begin=0,end=0;
    if(!ptr(reality+0x8e8,&begin) || !readable(reality+0x8f0,&end,8) || end<begin || (end-begin)%24 || (end-begin)/24>20000)return NO;
    void *(*getCost)(void *,const void *)=nativeEntry("_ZNK17cGcRealityManager14LookUpCostByIDERK4TkIDILm128EE",0x100995e04);
    void *(*cast)(const void *)=nativeEntry("_ZN14cGcCostProduct4CastERK15cTkClassPointer",0x101f04670);
    if(wanted && !_atlasCosts.count){
        for(uintptr_t row=begin;row<end;row+=24){
            uintptr_t entry=0;if(!ptr(row+16,&entry))continue;
            uint8_t key[16],classPointer[16],bytes[32];
            if(!readable(entry+80,key,16) || (uintptr_t)getCost((void *)reality,key)!=entry || !readable(entry+64,classPointer,16))continue;
            uintptr_t cost=(uintptr_t)cast(classPointer);if(!cost || !readable(cost,bytes,sizeof(bytes)))continue;
            BOOL pass=!memcmp(bytes,"ACCESS1\0",8) || !memcmp(bytes,"ACCESS2\0",8) || !memcmp(bytes,"ACCESS3\0",8);
            int32_t amount=0;memcpy(&amount,bytes+16,4);if(!pass || amount<0 || amount>1000000 || bytes[25]>1)continue;
            _atlasCosts[[NSData dataWithBytes:key length:16]]=@{@"owner":@(cost),@"product":[NSData dataWithBytes:bytes length:16],@"amount":@(amount),@"default":@(bytes[25])};
        }
        os_log(_log,"Atlas product requirements discovered: %{public}lu",(unsigned long)_atlasCosts.count);
    }
    BOOL ok=_atlasCosts.count>0;
    for(NSData *key in _atlasCosts.allKeys){
        NSDictionary *saved=_atlasCosts[key];uintptr_t entry=(uintptr_t)getCost((void *)reality,key.bytes);uint8_t cp[16],bytes[32];
        if(!entry || !readable(entry+64,cp,16)){ok=NO;continue;}
        uintptr_t cost=(uintptr_t)cast(cp);
        if(cost!=[saved[@"owner"] unsignedLongLongValue] || !readable(cost,bytes,sizeof(bytes)) || memcmp(bytes,[saved[@"product"] bytes],16)){ok=NO;continue;}
        int32_t current=0;memcpy(&current,bytes+16,4);
        if(wanted){
            // Respect foreign edits; Amount=0 plus UseDefaultAmount=false removes
            // only this ACCESS1/2/3 requirement, including MustAffordInCreative costs.
            if((current!=0 && current!=[saved[@"amount"] intValue]) || (bytes[25]!=0 && bytes[25]!=[saved[@"default"] unsignedCharValue])){ok=NO;continue;}
            ok=writeIntBack(cost,16,0) && writeByteBack(cost,25,0) && ok;
        }else{
            if(current==0)ok=writeIntBack(cost,16,[saved[@"amount"] intValue]) && ok;
            if(bytes[25]==0)ok=writeByteBack(cost,25,[saved[@"default"] unsignedCharValue]) && ok;
        }
    }
    if(!wanted && ok)[_atlasCosts removeAllObjects];return ok;
}
- (MTFeatureState *)applyCostFeature:(MTFeature)feature wanted:(BOOL)wanted {
    MTFeatureState *state=[MTFeatureState new];state.available=YES;
    if(!wanted){
        BOOL ok=!_values[@(feature)] || [_values[@(feature)] releaseValue];
        if(feature==MTFeatureAtlasLocks)ok=[self updateAtlasCosts:NO] && ok;
        state.note=ok ? @"Aus · eigene Kostenänderung zurückgenommen." : @"Kostenrücknahme fehlgeschlagen.";return state;
    }
    // Native getters and their callers establish the owner and fields:
    // IsCraftingFree: 0x100247d58; Application::GetGameState +0x311ce0.
    // Atlas product costs are separately resolved through their native table.
    // EverythingIsFree is unrelated: it controls shop/scanner/fleet checks.
    uintptr_t difficulty=_root+0xd40+0x311ce0;uint8_t one=1;BOOL ok=NO;
    const char *settings="_ZN25cGcDifficultySettingsData14mClassMetadataE";
    uintptr_t settingsMeta=(uintptr_t)dlsym(RTLD_DEFAULT,settings);
    if(feature==MTFeatureCrafting){
        state.available=settingsMeta && member(settings,settings,@"CraftingIsFree",1,1)==settingsMeta+0x5a
            && [self bindCostValue:feature address:difficulty+0x5a];
        if(state.available){
            BOOL (*isFree)(void *)=nativeEntry("_ZNK21cGcDifficultySettings14IsCraftingFreeEv",0x10024826c);
            ok=[_values[@(feature)] applyBytes:&one readOnly:NO] && isFree((void *)difficulty);
        }
        state.note=@"Native Herstellungsfreigabe; bekannte Rezepte bleiben erforderlich.";
    }else{
        ok=[self updateAtlasCosts:YES];state.available=_atlasCosts.count>0;
        state.note=@"Native Atlas-Pass-Produktanforderungen aufgehoben; keine Pässe ins Inventar geschrieben.";
    }
    state.active=ok;if(!state.available)state.note=@"Native Kostenstruktur nicht bestätigt.";return state;
}
- (MTFeatureState *)applyExtendedFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.available=YES;
    if(feature==MTFeatureCrafting || feature==MTFeatureAtlasLocks)return [self applyCostFeature:feature wanted:wanted];
    if(feature==MTFeatureGameSpeed || feature==MTFeatureShipHeat || feature==MTFeatureDamage){
        MTNMSValue *binding=_values[@(feature)];state.available=binding!=nil;
        if(feature==MTFeatureShipHeat)state.available&=_values[@1000]!=nil;
        BOOL ok=state.available;
        if(!wanted){ok=[binding releaseValue];if(feature==MTFeatureShipHeat)ok=[_values[@1000] releaseValue] && ok;}
        else if(feature==MTFeatureDamage){uint8_t yes=1;ok=[binding applyBytes:&yes readOnly:NO];}
        else {float v=feature==MTFeatureShipHeat ? 1e9f : (float)value;
            if(!isfinite(v) || (feature==MTFeatureGameSpeed && (v<0.25 || v>4)))ok=NO;
            else {ok=[binding applyBytes:&v readOnly:NO];if(feature==MTFeatureShipHeat)ok=[_values[@1000] applyBytes:&v readOnly:NO] && ok;}}
        state.active=wanted && ok;state.note=ok ? @"Nativer Wert zurückgelesen; vollständige Ingame-Wirkung noch ungeprüft." : @"Native Bindung oder Rückleseprüfung fehlt.";return state;
    }
    if(!wanted){if(feature==MTFeatureItems)[_itemSnapshots removeAllObjects];state.note=@"Aus · kein weiteres Auffüllen. Bereits gewährte Mengen bleiben erhalten.";return state;}
    BOOL ok=[self runExtendedOperation:feature];state.active=ok;
    state.note=ok ? @"Im aktuellen nativen Kontext aufgefüllt und zurückgelesen; kann gespeichert werden." : @"Keine passende intakte Ausrüstung oder Rückleseprüfung nicht bestätigt.";
    return state;
}
- (void)maintainFrameEffects {
    if(!onFrame || MTNMSReadOnly() || !_bound)return;
    // The same eligibility rule drives both the cheap gate and actual upkeep.
    // Poll-only global/cost/currency options must not cause empty per-frame
    // player discovery when there is no operation for the frame to perform.
    BOOL any=NO;for(NSInteger i=MTFeatureShield;i<MTFeatureCount;i++)if(_wantedCache[i]&&_confirmed[i]&&frameMaintainedFeature(i)){any=YES;break;}
    if(!any)return;
    NSString *previous=[_identity copy];MTGameContext *context=[self captureContext];
    if(((context.kind!=MTSessionSolo && context.kind!=MTSessionNetwork)) || ![previous isEqual:context.identity]){[self releaseEffects];return;}
    for(NSInteger i=MTFeatureShield;i<MTFeatureCount;i++)if(_wantedCache[i]&&_confirmed[i]&&frameMaintainedFeature(i))
        _confirmed[i]=[self runExtendedOperation:i];
}

@end
