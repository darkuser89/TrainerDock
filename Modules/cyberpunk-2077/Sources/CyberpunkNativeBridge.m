// SPDX-License-Identifier: GPL-3.0-only
#import "CyberpunkNativeBridge.h"
#import "CyberpunkMetadata.h"
#import "GameProfile.h"
#import <mach-o/dyld.h>
#import <mach/mach_vm.h>
#import <mach/mach_time.h>
#import <os/lock.h>
#include <stdatomic.h>
#include <pthread.h>
typedef void (*CPHandler)(void *,void *,void *,void *);
static CPNativeBridge *installed;
static _Atomic(CPHandler) original;
static _Thread_local __unsafe_unretained CPNativeBridge *scope;
static _Thread_local const void *gameInstance;
static _Thread_local uintptr_t callbackContext;
static _Thread_local BOOL progressionRecursive;
static _Atomic(uintptr_t) progressionContext;
static _Atomic(CPHandler) originalInvoke[2];
static _Atomic(uintptr_t) observationFunctions[8];
static _Atomic(uint64_t) observationNames[8],observationFunctionNames[8];
static _Atomic(unsigned) observationCount;
static _Thread_local BOOL observingInvocation;
static BOOL matchesObservation(int kind,void *frame){
    unsigned count=atomic_load(&observationCount);if(!count || observingInvocation)return NO;
    const uint8_t *head=*(const uint8_t **)frame;uint64_t target=0;memcpy(&target,head+4,8);
    uint64_t functionName=0;if(!kind && target)memcpy(&functionName,(const void *)(target+8),8);
    for(unsigned i=0;i<count;i++){
        if(kind ? (target==atomic_load(&observationNames[i]) || target==atomic_load(&observationFunctionNames[i]))
           : (target==atomic_load(&observationFunctions[i]) || functionName==atomic_load(&observationFunctionNames[i])))return YES;
    }
    return NO;
}
typedef struct {
    uintptr_t function,control,types[4];uint64_t functionName;
    int32_t level,cred,skills[5];
    double factors[3];BOOL maximum[3];
    uint64_t count[3],epoch;int32_t input[3],scaled[3],before[3],after[3];BOOL verified[3],maxReached[3];
} CPProgressionPolicy;
@interface CPNativeBridge () {
    os_unfair_lock _lock;
    NSMutableArray *_pending;
    uintptr_t _slot,_replacement;
    const struct mach_header_64 *_image;
    _Atomic(BOOL) _attached;
    _Atomic(BOOL) _draining,_hasPending,_hasFrameWork;
    dispatch_block_t _frameWork;NSData *_frameWorld,*_framePlayerWeak;
    _Atomic(uintptr_t) _frameContext;
    _Atomic(uint64_t) _nextFrameTicks;uint64_t _frameIntervalTicks;
    NSDictionary *_dispatchPlayerSystem,*_dispatchLocalPlayer;
    os_unfair_lock _progressionLock;
    CPProgressionPolicy _progression;
    NSData *_progressionWeak;
    NSDictionary *_progressionSettings,*_progressionGetter,*_progressionLevel,*_progressionMax,*_progressionCap;
    uintptr_t _invokeSlots[2];BOOL _invokeAttached;
    os_unfair_lock _observationLock;NSMutableDictionary *_observations;
}
- (void)received:(const void *)value context:(uintptr_t)context;
- (BOOL)observeInvocation:(int)kind context:(void *)context frame:(void *)frame result:(void *)result resultType:(void *)resultType;
- (BOOL)interceptInvocation:(int)kind context:(void *)context frame:(void *)frame result:(void *)result resultType:(void *)resultType;
@end
static BOOL readable(uintptr_t source,void *destination,size_t count){
    mach_vm_size_t copied=0;return source && mach_vm_read_overwrite(mach_task_self(),source,count,(mach_vm_address_t)destination,&copied)==KERN_SUCCESS && copied==count;
}
static BOOL writableData(uintptr_t address,size_t length){
    mach_vm_address_t start=address;mach_vm_size_t size=0;mach_port_t object=0;
    vm_region_basic_info_data_64_t info={0};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
    kern_return_t result=mach_vm_region(mach_task_self(),&start,&size,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&object);
    if(object)mach_port_deallocate(mach_task_self(),object);
    return !result && start<=address && address-start<=size && length<=size-(address-start)
        && (info.protection&VM_PROT_WRITE) && !(info.protection&VM_PROT_EXECUTE);
}
static id fail(NSError **error,NSString *message){
    if(error)*error=[NSError errorWithDomain:@"local.cyberpunk2077.native" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return nil;
}
static NSUInteger valueSize(NSString *name){
    if([name isEqual:@"Void"] || [name isEqual:@"Bool"])return 1;
    if([@[@"Int32",@"Uint32",@"Float",@"GameTime",@"gameGodModeType",@"gamecheatsystemFlag",@"gamedataDamageType",@"gamedataItemType",@"gamedataEquipmentArea",@"gameStatModifierType",@"gamedataStatType",@"gamedataStatPoolType",@"gamedataProficiencyType",@"gamedataDevelopmentPointType",@"telemetryLevelGainReason",@"gameStatPoolModificationTypes"] containsObject:name])return 4;
    if([@[@"CName",@"Int64",@"Uint64",@"entEntityID",@"TweakDBID",@"EngineTime"] containsObject:name])return 8;
    if([@[@"gameStatsObjectID",@"gameItemID",@"Vector4",@"Quaternion",@"WorldPosition",@"array:CName",@"array:whandle:gameItemData"] containsObject:name])return 16;
    if([name isEqual:@"EulerAngles"])return 12;
    if([name isEqual:@"gameStatPoolModifier"])return 128;
    if([name hasPrefix:@"handle:"] || [name hasPrefix:@"whandle:"])return 16;
    if([name isEqual:@"ScriptGameInstance"])return 24;
    return 0;
}
static void observeGetGame(void *context,void *frame,void *result,void *resultType){
    // Exact original ABI and all original outputs are preserved.
    atomic_load(&original)(context,frame,result,resultType);
    if(!scope && result){@autoreleasepool{[installed received:result context:(uintptr_t)context];}}
}
static void observeInvocation24(void *context,void *frame,void *result,void *type){
    if(matchesObservation(0,frame)){@autoreleasepool{if([installed observeInvocation:0 context:context frame:frame result:result resultType:type])return;}}
    if(!progressionRecursive && (uintptr_t)context==atomic_load(&progressionContext) && context){
        @autoreleasepool {if([installed interceptInvocation:0 context:context frame:frame result:result resultType:type])return;}
    }
    atomic_load(&originalInvoke[0])(context,frame,result,type);
}
static void observeInvocation25(void *context,void *frame,void *result,void *type){
    if(matchesObservation(1,frame)){@autoreleasepool{if([installed observeInvocation:1 context:context frame:frame result:result resultType:type])return;}}
    if(!progressionRecursive && (uintptr_t)context==atomic_load(&progressionContext) && context){
        @autoreleasepool {if([installed interceptInvocation:1 context:context frame:frame result:result resultType:type])return;}
    }
    atomic_load(&originalInvoke[1])(context,frame,result,type);
}
@implementation CPNativeBridge
- (instancetype)init {if((self=[super init])){_lock=OS_UNFAIR_LOCK_INIT;_progressionLock=OS_UNFAIR_LOCK_INIT;_observationLock=OS_UNFAIR_LOCK_INIT;_observations=[NSMutableDictionary new];_pending=[NSMutableArray new];}return self;}
- (BOOL)insideEngineCallback {return scope==self;}
- (NSData *)currentGameInstance {return scope==self && gameInstance ? [NSData dataWithBytes:gameInstance length:24] : nil;}
- (uintptr_t)currentCallbackContext {return scope==self ? callbackContext : 0;}
- (BOOL)install:(NSError **)error {
    if(_attached){
        if(atomic_load((_Atomic(uintptr_t) *)_slot)==_replacement)return YES;
        fail(error,@"Native observer was replaced; refusing to overwrite another owner.");return NO;
    }
    if(installed && installed!=self){fail(error,@"A native observer already owns this process.");return NO;}
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *h=(const void *)_dyld_get_image_header(i);
        if(h && h->magic==MH_MAGIC_64 && h->filetype==MH_EXECUTE)_image=h;
    }
    NSDictionary *identity=MTReadExecutableIdentity(NSBundle.mainBundle.executablePath);
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.cdprojektred.cyberpunk.steam"]
       || ![identity[@"uuid"] isEqual:@"7D7382D0-EADD-36F0-BA1C-CEBEC1D5BEBC"]){fail(error,@"Exact Cyberpunk process required.");return NO;}
    NSDictionary *binding=[self resolveClass:@"PlayerPuppet" method:@"GetGame" parameters:@[] result:@"ScriptGameInstance"];
    if(!binding || [binding[@"registrationIndex"] unsignedIntValue]!=1396
       || ![binding[@"nativeHandlerOffset"] isEqual:@"0x16ec9c0"]){fail(error,@"GetGame binding differs from the inspected build.");return NO;}
    _dispatchPlayerSystem=[self resolveClass:@"ScriptGameInstance" method:@"GetPlayerSystem" parameters:@[@"ScriptGameInstance"] result:@"handle:cpPlayerSystem"];
    _dispatchLocalPlayer=[self resolveClass:@"cpPlayerSystem" method:@"GetLocalPlayerControlledGameObject" parameters:@[] result:@"handle:gameObject"];
    if(!_dispatchPlayerSystem || !_dispatchLocalPlayer){fail(error,@"Authoritative local-player dispatch getters unavailable.");return NO;}
    // Independently inspected native dispatcher: two 64-bit words per member
    // function entry. No executable page or protection flag is changed.
    uint32_t words[3]={0};const uint32_t expected[]={0xf0044a08,0x91250108,0x8b205108};
    if(!readable((uintptr_t)_image+0x1099c8c,words,sizeof(words)) || memcmp(words,expected,sizeof(words))){fail(error,@"Native dispatcher changed.");return NO;}
    _slot=[binding[@"slot"] unsignedLongLongValue];_replacement=(uintptr_t)observeGetGame;
    if((_slot&15) || !writableData(_slot,16)){fail(error,@"Native slot is not writable data.");return NO;}
    uintptr_t expectedHandler=[binding[@"handler"] unsignedLongLongValue];
    atomic_store(&original,(CPHandler)expectedHandler);installed=self;
    if(!atomic_compare_exchange_strong((_Atomic(uintptr_t) *)_slot,&expectedHandler,_replacement)){
        fail(error,@"Native slot changed concurrently; no observer installed.");return NO;
    }
    _attached=YES;return YES;
}
- (void)enqueue:(dispatch_block_t)work {
    if(!work)return;
    os_unfair_lock_lock(&_lock);
    if(_pending.count<32){[_pending addObject:[work copy]];_hasPending=YES;}
    os_unfair_lock_unlock(&_lock);
}
- (void)received:(const void *)value context:(uintptr_t)context {
    if(!_attached)return;
    uint64_t now=mach_absolute_time();BOOL frameDue=_hasFrameWork && now>=_nextFrameTicks;
    if(!_hasPending && (!frameDue || context!=_frameContext))return;
    BOOL expected=NO;if(!atomic_compare_exchange_strong(&_draining,&expected,YES))return;
    uint8_t copy[24]={0};if(!readable((uintptr_t)value,copy,sizeof(copy))){_draining=NO;return;}
    scope=self;gameInstance=copy;callbackContext=context;
    NSData *system=nil,*player=nil;
    @try {
        if(![self supportsHandleClass:@"cpPlayerSystem" weak:NO] || ![self supportsHandleClass:@"gameObject" weak:NO])return;
        // REDengine script jobs run on engine workers as well as the main
        // thread. Dispatch only from the authoritative local player's own
        // native script callback, never from a random background queue/NPC.
        system=[self invoke:_dispatchPlayerSystem context:0 arguments:@[self.currentGameInstance] resultSize:16 error:NULL];
        uintptr_t systemPointer=0,playerPointer=0;
        if(system.length==16)memcpy(&systemPointer,system.bytes,8);
        if(systemPointer)player=[self invoke:_dispatchLocalPlayer context:systemPointer arguments:@[] resultSize:16 error:NULL];
        if(player.length==16)memcpy(&playerPointer,player.bytes,8);
        if(playerPointer && playerPointer!=context)return;
        os_unfair_lock_lock(&_lock);NSArray *work=[_pending copy];[_pending removeAllObjects];_hasPending=NO;os_unfair_lock_unlock(&_lock);
        for(dispatch_block_t block in work)block();
        if(_hasFrameWork && now>=_nextFrameTicks && playerPointer && playerPointer==context && _frameWorld.length==24
           && !memcmp(_frameWorld.bytes,copy,8) && player.length==16 && [_framePlayerWeak isEqual:player]){
            _nextFrameTicks=now+_frameIntervalTicks;dispatch_block_t frameWork=_frameWork;if(frameWork)frameWork();
        }
    } @finally {
        [self destroyValue:player type:@"handle:gameObject"];[self destroyValue:system type:@"handle:cpPlayerSystem"];
        gameInstance=NULL;callbackContext=0;scope=nil;_draining=NO;
    }
}
- (void)detach {
    if(!_attached)return;
    [self clearFrameWork];[self clearProgression];[self clearScriptObservers];
    uintptr_t expected=_replacement;
    if(writableData(_slot,8))atomic_compare_exchange_strong((_Atomic(uintptr_t) *)_slot,&expected,(uintptr_t)atomic_load(&original));
    _attached=NO;os_unfair_lock_lock(&_lock);[_pending removeAllObjects];_hasPending=NO;os_unfair_lock_unlock(&_lock);
    // Static original/owner remain alive until process exit: an in-flight call
    // may still be returning through our signed library after slot restoration.
}
- (NSDictionary *)resolveClass:(NSString *)className method:(NSString *)method parameters:(NSArray<NSString *> *)parameters result:(NSString *)result {
    if(!_image)return nil;
    NSDictionary *binding=CPResolveNativeBinding(_image,className,method);
    if(![binding[@"parameterTypes"] isEqual:parameters] || ![binding[@"returnType"] isEqual:result])return nil;
    return binding;
}
- (NSDictionary *)resolveScriptClass:(NSString *)className method:(NSString *)method parameters:(NSArray<NSString *> *)parameters result:(NSString *)result {
    if(!_image)return nil;
    NSDictionary *binding=CPResolveScriptBinding(_image,className,method);
    return [binding[@"parameterTypes"] isEqual:parameters] && [binding[@"returnType"] isEqual:result] ? binding : nil;
}
static void prepareFrame(uint8_t *frame,uintptr_t image,uintptr_t context,void *code,void *locals){
    uintptr_t c=(uintptr_t)code,l=(uintptr_t)locals;
    memcpy(frame,&c,8);memcpy(frame+0x10,&l,8);memcpy(frame+0x18,&l,8);memcpy(frame+0x40,&context,8);
    frame[0x64]=1;uint32_t empty=UINT32_MAX;memcpy(frame+0x88,&empty,4);
    uintptr_t pool=image+0x7cddb78,map=(uintptr_t)frame+0x68;
    memcpy(frame+0x90,&pool,8);memcpy(frame+0x98,&map,8);
}
- (NSData *)invokeScript:(NSDictionary *)binding context:(uintptr_t)context arguments:(NSArray<NSData *> *)arguments resultSize:(NSUInteger)size error:(NSError **)error {
    if(scope!=self || !_attached || !binding[@"function"] || [binding[@"native"] boolValue]
       || arguments.count>8 || [binding[@"properties"] count]!=arguments.count || size!=valueSize(binding[@"returnType"]))
        return fail(error,@"Script call requires a validated engine scope and typed signature.");
    uintptr_t opcode=0;uint32_t fingerprint[3]={0};const uint32_t expected[]={0xd101c3ff,0xa9016ffc,0xa90267fa};
    if(!readable((uintptr_t)_image+0x9a5c940+0x24*8,&opcode,8) || (opcode!=(uintptr_t)_image+0x12011e4 && opcode!=(uintptr_t)observeInvocation24)
       || !readable((uintptr_t)_image+0x12011e4,fingerprint,sizeof(fingerprint)) || memcmp(fingerprint,expected,sizeof(fingerprint)))
        return fail(error,@"Exact native script dispatcher fingerprint required.");
    uint8_t locals[8*32]={0},properties[8][0x30]={0},code[14+8*9+1]={0},frame[0xa8]={0};
    uintptr_t function=[binding[@"function"] unsignedLongLongValue];memcpy(code+4,&function,8);
    uint16_t flags=0; // Local arguments are lvalues; the VM must not steal their handles.
    memcpy(code+12,&flags,2);size_t cursor=14;
    for(NSUInteger i=0;i<arguments.count;i++){
        NSData *value=arguments[i];uintptr_t type=0;
        if(value.length!=valueSize(binding[@"parameterTypes"][i]) || value.length>32
           || !readable([binding[@"properties"][i] unsignedLongLongValue],&type,8) || !type)
            return fail(error,@"Unsupported script argument shape.");
        memcpy(locals+i*32,value.bytes,value.length);memcpy(properties[i],&type,8);
        uint32_t offset=(uint32_t)i*32;memcpy(properties[i]+0x20,&offset,4);
        code[cursor++]=0x18;uintptr_t property=(uintptr_t)properties[i];memcpy(code+cursor,&property,8);cursor+=8;
    }
    code[cursor]=0x26;uint16_t exit=(uint16_t)(cursor-1);memcpy(code,&exit,2);
    prepareFrame(frame,(uintptr_t)_image,context,code,locals);
    NSMutableData *output=[NSMutableData dataWithLength:size];
    @try {((CPHandler)opcode)((void *)context,frame,output.mutableBytes,(void *)[binding[@"returnTypePointer"] unsignedLongLongValue]);}
    @finally {((void (*)(void *))((uintptr_t)_image+0x11ab310))(frame);}
    return output;
}
- (NSData *)createInstance:(NSString *)className error:(NSError **)error {
    if(scope!=self || !_attached)return fail(error,@"Instance creation requires the active engine callback.");
    NSDictionary *schema=CPReadTypeSchema(_image,className);uint32_t flags=[schema[@"flags"] unsignedIntValue];
    uintptr_t cls=CPFindNativeType(_image,className),opcode=0;uint32_t words[3]={0};
    const uint32_t expected[]={0xd10183ff,0xa90357f6,0xa9044ff4};
    if(!cls || ![schema[@"kind"] isEqual:@"class"] || (flags&1) || !(flags&2)
       || ![schema[@"size"] unsignedIntValue] || [schema[@"size"] unsignedIntValue]>4096
       || !CPNativeClassIsA(_image,className,@"IScriptable") || ![self supportsHandleClass:@"IScriptable" weak:NO]
       || !readable((uintptr_t)_image+0x9a5c940+0x30*8,&opcode,8) || opcode!=(uintptr_t)_image+0x1202fdc
       || !readable(opcode,words,sizeof(words)) || memcmp(words,expected,sizeof(words)))
        return fail(error,@"Native constructible class/dispatcher validation failed.");
    uint8_t frame[0xa8]={0};prepareFrame(frame,(uintptr_t)_image,callbackContext,&cls,NULL);
    NSMutableData *result=[NSMutableData dataWithLength:16];
    @try {((CPHandler)opcode)((void *)callbackContext,frame,result.mutableBytes,NULL);}
    @finally {((void (*)(void *))((uintptr_t)_image+0x11ab310))(frame);}
    uintptr_t instance=0;memcpy(&instance,result.bytes,8);
    return instance ? result : fail(error,@"Native instance allocation returned no handle.");
}
- (BOOL)writeScalarProperty:(NSString *)property className:(NSString *)className object:(NSData *)object type:(NSString *)typeName value:(NSData *)value {
    if(scope!=self || object.length!=16 || value.length!=valueSize(typeName) || value.length>8)return NO;
    uintptr_t instance=0;memcpy(&instance,object.bytes,8);if(!instance)return NO;
    NSDictionary *schema=CPReadTypeSchema(_image,className);NSUInteger size=[schema[@"size"] unsignedIntegerValue];
    NSString *hash=[NSString stringWithFormat:@"%016llx",(unsigned long long)CPNameHash(property)];
    for(NSDictionary *field in schema[@"properties"]){
        NSUInteger offset=[field[@"offset"] unsignedIntegerValue];
        if(![field[@"nameHash"] isEqual:hash] || ![field[@"type"] isEqual:typeName] || ([field[@"flags"] unsignedLongLongValue]&(1ull<<21))
           || offset>size || value.length>size-offset || !writableData(instance+offset,value.length))continue;
        uintptr_t type=0,assign=[self typeMethod:typeName offset:0x58 type:&type];if(!assign)return NO;
        ((void (*)(uintptr_t,void *,const void *))assign)(type,(void *)(instance+offset),value.bytes);
        uint8_t check[8]={0};return readable(instance+offset,check,value.length) && !memcmp(check,value.bytes,value.length);
    }return NO;
}
- (NSData *)invoke:(NSDictionary *)binding context:(uintptr_t)context arguments:(NSArray<NSData *> *)arguments resultSize:(NSUInteger)resultSize error:(NSError **)error {
    if(scope!=self || !_attached)return fail(error,@"Native calls require the active engine callback.");
    NSArray *properties=binding[@"properties"];
    if(![binding[@"native"] boolValue] || properties.count!=arguments.count || arguments.count>8 || !resultSize || resultSize!=valueSize(binding[@"returnType"]))
        return fail(error,@"Invalid native call shape.");
    uintptr_t handler=[binding[@"handler"] unsignedLongLongValue];
    if(handler<(uintptr_t)_image || handler>=(uintptr_t)_image+0x7758000)return fail(error,@"Foreign native handler rejected.");
    // ScriptGameInstance is 24 bytes in this build; 128-byte argument slots keep
    // it intact. Never use the 16-byte generic result buffer seen in older tools.
    uint8_t locals[8*128]={0},props[8][0x30]={0},code[8*9+1]={0},frame[0xa8]={0};
    size_t cursor=0;
    for(NSUInteger i=0;i<arguments.count;i++){
        NSData *argument=arguments[i];uintptr_t type=0;
        if(![argument isKindOfClass:NSData.class] || !argument.length || argument.length!=valueSize(binding[@"parameterTypes"][i])
           || argument.length>128 || !readable([properties[i] unsignedLongLongValue],&type,8) || !type)return fail(error,@"Invalid typed argument.");
        uint64_t flags=0;
        if(!readable([properties[i] unsignedLongLongValue]+0x28,&flags,8) || ((flags&(1ull<<9)) && ![argument isKindOfClass:NSMutableData.class]))return fail(error,@"Out parameter requires owned mutable typed storage.");
        memcpy(locals+i*128,argument.bytes,argument.length);memcpy(props[i],&type,8);
        uint32_t offset=(uint32_t)i*128;memcpy(props[i]+0x20,&offset,4);
        code[cursor++]=0x18;uintptr_t property=(uintptr_t)props[i];memcpy(code+cursor,&property,8);cursor+=8;
    }
    code[cursor]=0x26;
    uintptr_t codePointer=(uintptr_t)code,localsPointer=(uintptr_t)locals;
    memcpy(frame,&codePointer,8);memcpy(frame+0x10,&localsPointer,8);memcpy(frame+0x18,&localsPointer,8);memcpy(frame+0x40,&context,8);
    frame[0x64]=1;uint32_t empty=UINT32_MAX;memcpy(frame+0x88,&empty,4);
    uintptr_t pool=(uintptr_t)_image+0x7cddb78,map=(uintptr_t)frame+0x68;
    memcpy(frame+0x90,&pool,8);memcpy(frame+0x98,&map,8);
    NSMutableData *output=[NSMutableData dataWithLength:resultSize];
    @try {((CPHandler)handler)((void *)context,frame,output.mutableBytes,(void *)[binding[@"returnTypePointer"] unsignedLongLongValue]);}
    @finally {((void (*)(void *))((uintptr_t)_image+0x11ab310))(frame);}
    for(NSUInteger i=0;i<arguments.count;i++){
        uint64_t flags=0;readable([properties[i] unsignedLongLongValue]+0x28,&flags,8);
        if(flags&(1ull<<9))memcpy(((NSMutableData *)arguments[i]).mutableBytes,locals+i*128,arguments[i].length);
    }
    return output;
}
- (uintptr_t)typeMethod:(NSString *)typeName offset:(NSUInteger)offset type:(uintptr_t *)type {
    if(scope!=self)return 0;
    uintptr_t t=CPFindNativeType(_image,typeName),vt=0,method=0;
    if(!t || !readable(t,&vt,8) || !readable(vt+offset,&method,8) || method<(uintptr_t)_image || method>=(uintptr_t)_image+0x7758000)return 0;
    if(type)*type=t;return method;
}
- (void)destroyValue:(NSData *)value type:(NSString *)typeName {
    if(![value isKindOfClass:NSMutableData.class] || value.length!=valueSize(typeName))return;
    if([typeName hasPrefix:@"handle:"])typeName=[self strongTypeForClass:[typeName substringFromIndex:7]];
    if([typeName hasPrefix:@"whandle:"])typeName=[self weakTypeForClass:[typeName substringFromIndex:8]];
    uintptr_t type=0,method=[self typeMethod:typeName offset:0x48 type:&type];
    if(method){((void (*)(uintptr_t,void *))method)(type,((NSMutableData *)value).mutableBytes);[(NSMutableData *)value resetBytesInRange:NSMakeRange(0,value.length)];}
}
- (NSData *)weakFromStrong:(NSData *)value className:(NSString *)className {
    if(value.length!=16)return nil;
    uintptr_t type=0,method=[self typeMethod:[self weakTypeForClass:className] offset:0x58 type:&type];
    if(!method)return nil;
    NSMutableData *weak=[NSMutableData dataWithLength:16];
    ((void (*)(uintptr_t,void *,const void *))method)(type,weak.mutableBytes,value.bytes);return weak;
}
- (NSData *)lockWeak:(NSData *)value {
    if(scope!=self || value.length!=16)return nil;
    uintptr_t pair[2]={0};memcpy(pair,value.bytes,16);
    if(!pair[0] || !pair[1] || (pair[1]&3) || !writableData(pair[1],8))return nil;
    // Engine RefCnt ABI: atomic strong count at +0, weak count at +4.
    // The caller owns a native weak reference, keeping this control block alive.
    _Atomic(uint32_t) *counter=(_Atomic(uint32_t) *)pair[1];uint32_t count=atomic_load(counter);
    while(count && count<UINT32_MAX)if(atomic_compare_exchange_weak(counter,&count,count+1))return [NSMutableData dataWithBytes:pair length:16];
    return nil;
}
- (NSNumber *)weakIsExpired:(NSData *)value {
    if(scope!=self || value.length!=16)return nil;
    uintptr_t pair[2]={0};memcpy(pair,value.bytes,16);
    if(!pair[0] && !pair[1])return @YES;
    uint32_t count=0;if(!pair[1] || !readable(pair[1],&count,4))return nil;
    return @(count==0);
}
- (BOOL)supportsHandleClass:(NSString *)className weak:(BOOL)weak {
    if(![self typeMethod:[self strongTypeForClass:className] offset:0x48 type:NULL])return NO;
    if(!weak)return YES;
    NSString *type=[self weakTypeForClass:className];
    return [self typeMethod:type offset:0x48 type:NULL] && [self typeMethod:type offset:0x58 type:NULL];
}
- (NSString *)weakTypeForClass:(NSString *)className {
    // WeakHandle<Derived> upcasts to a registered WeakHandle<Base> without
    // changing its 16-byte pair. Require actual RTTI ancestry before upcasting;
    // no synthetic reference counter or forged object lifetime is introduced.
    for(NSString *candidate in @[className,@"IScriptable",@"ISerializable"]){
        if(![candidate isEqual:className] && !CPNativeClassIsA(_image,className,candidate))continue;
        NSString *type=[@"whandle:" stringByAppendingString:candidate];
        if([self typeMethod:type offset:0x48 type:NULL] && [self typeMethod:type offset:0x58 type:NULL])return type;
    }return nil;
}
- (NSNumber *)enumType:(NSString *)typeName member:(NSString *)member {
    return scope==self ? CPFindEnumValue(_image,typeName,member) : nil;
}
- (NSArray<NSData *> *)copyItemWeakArray:(NSData *)array {
    if(scope!=self || array.length!=16)return nil;
    uintptr_t pointer=0;uint32_t capacity=0,count=0;memcpy(&pointer,array.bytes,8);memcpy(&capacity,(const uint8_t *)array.bytes+8,4);memcpy(&count,(const uint8_t *)array.bytes+12,4);
    if(count>capacity || capacity>65536 || count>8192 || (count && !pointer))return nil;
    uintptr_t type=0,assign=[self typeMethod:@"whandle:gameItemData" offset:0x58 type:&type];
    if(!assign)return nil;NSMutableArray *values=[NSMutableArray new];
    for(uint32_t i=0;i<count;i++){
        uint8_t source[16]={0};if(!readable(pointer+i*16,source,16)){
            for(NSData *value in values)[self destroyValue:value type:@"whandle:gameItemData"];return nil;
        }
        NSMutableData *value=[NSMutableData dataWithLength:16];((void (*)(uintptr_t,void *,const void *))assign)(type,value.mutableBytes,source);[values addObject:value];
    }return values;
}

- (BOOL)configureProgressionOwner:(NSData *)owner binding:(NSDictionary *)binding settings:(NSDictionary *)settings {
    if(scope!=self || owner.length!=16 || !binding || [binding[@"native"] boolValue] || ![binding[@"parameterTypes"] isEqual:@[@"Int32",@"gamedataProficiencyType",@"telemetryLevelGainReason",@"Bool"]])return NO;
    uintptr_t pair[2]={0};memcpy(pair,owner.bytes,16);if(!pair[0] || !pair[1])return NO;
    if(_invokeAttached && [_progressionSettings isEqual:settings] && pair[0]==atomic_load(&progressionContext) && pair[1]==_progression.control)return YES;
    if(![self ensureInvocationObservers])return NO;
    if(!_progressionGetter){
        _progressionGetter=[self resolveScriptClass:@"PlayerDevelopmentData" method:@"GetCurrentLevelProficiencyExp" parameters:@[@"gamedataProficiencyType"] result:@"Int32"];
        _progressionLevel=[self resolveScriptClass:@"PlayerDevelopmentData" method:@"GetProficiencyLevel" parameters:@[@"gamedataProficiencyType"] result:@"Int32"];
        _progressionCap=[self resolveScriptClass:@"PlayerDevelopmentData" method:@"GetTotalProfExperience" parameters:@[@"gamedataProficiencyType"] result:@"Int32"];
        _progressionMax=[self resolveScriptClass:@"PlayerDevelopmentData" method:@"IsProficiencyMaxLvl" parameters:@[@"gamedataProficiencyType"] result:@"Bool"];
    }
    if(!_progressionGetter || !_progressionLevel || !_progressionMax || !_progressionCap)return NO;
    NSData *weak=[self weakFromStrong:owner className:@"PlayerDevelopmentData"];if(!weak)return NO;
    CPProgressionPolicy next={0};next.function=[binding[@"function"] unsignedLongLongValue];readable(next.function+8,&next.functionName,8);next.control=pair[1];
    NSString *members[]={@"Level",@"StreetCred",@"CoolSkill",@"IntelligenceSkill",@"ReflexesSkill",@"StrengthSkill",@"TechnicalAbilitySkill"};
    int32_t *values[]={&next.level,&next.cred,&next.skills[0],&next.skills[1],&next.skills[2],&next.skills[3],&next.skills[4]};
    for(int i=0;i<7;i++){NSNumber *value=[self enumType:@"gamedataProficiencyType" member:members[i]];if(!value){[self destroyValue:weak type:@"whandle:PlayerDevelopmentData"];return NO;}*values[i]=value.intValue;}
    for(int i=0;i<4;i++)if(!readable([binding[@"properties"][i] unsignedLongLongValue],&next.types[i],8)){[self destroyValue:weak type:@"whandle:PlayerDevelopmentData"];return NO;}
    NSArray *groups=@[@"level",@"cred",@"skill"];
    for(int i=0;i<3;i++){
        next.factors[i]=[settings[[groups[i] stringByAppendingString:@"Factor"]] doubleValue];next.maximum[i]=[settings[[groups[i] stringByAppendingString:@"Max"]] boolValue];
        if(!isfinite(next.factors[i]) || next.factors[i]<1 || next.factors[i]>1000){[self destroyValue:weak type:@"whandle:PlayerDevelopmentData"];return NO;}
    }
    os_unfair_lock_lock(&_progressionLock);atomic_store(&progressionContext,0);NSData *old=_progressionWeak;
    next.epoch=_progression.epoch+1;_progression=next;_progressionWeak=weak;_progressionSettings=[settings copy];atomic_store(&progressionContext,pair[0]);os_unfair_lock_unlock(&_progressionLock);
    [self destroyValue:old type:@"whandle:PlayerDevelopmentData"];return YES;
}
- (void)clearProgression {
    if(scope!=self)return;
    os_unfair_lock_lock(&_progressionLock);atomic_store(&progressionContext,0);NSData *old=_progressionWeak;_progressionWeak=nil;_progressionSettings=nil;os_unfair_lock_unlock(&_progressionLock);
    [self destroyValue:old type:@"whandle:PlayerDevelopmentData"];
    if(_invokeAttached && !atomic_load(&observationCount)){
        CPHandler replacements[]={observeInvocation24,observeInvocation25};
        for(int i=0;i<2;i++){uintptr_t expected=(uintptr_t)replacements[i];if(writableData(_invokeSlots[i],8))atomic_compare_exchange_strong((_Atomic(uintptr_t) *)_invokeSlots[i],&expected,(uintptr_t)atomic_load(&originalInvoke[i]));}
        _invokeAttached=NO;
    }
}
- (NSDictionary *)progressionObservation {
    os_unfair_lock_lock(&_progressionLock);CPProgressionPolicy copy=_progression;os_unfair_lock_unlock(&_progressionLock);
    return @{@"epoch":@(copy.epoch),@"counts":@[@(copy.count[0]),@(copy.count[1]),@(copy.count[2])],@"scaled":@[@(copy.scaled[0]),@(copy.scaled[1]),@(copy.scaled[2])],
             @"before":@[@(copy.before[0]),@(copy.before[1]),@(copy.before[2])],@"after":@[@(copy.after[0]),@(copy.after[1]),@(copy.after[2])],
             @"verified":@[@(copy.verified[0]),@(copy.verified[1]),@(copy.verified[2])],@"maximum":@[@(copy.maxReached[0]),@(copy.maxReached[1]),@(copy.maxReached[2])]};
}
- (BOOL)interceptInvocation:(int)kind context:(void *)context frame:(void *)rawFrame result:(void *)result resultType:(void *)resultType {
    uint8_t *frame=rawFrame,*head=NULL;memcpy(&head,frame,8);if(!head)return NO;
    os_unfair_lock_lock(&_progressionLock);CPProgressionPolicy policy=_progression;uint32_t strong=0;
    BOOL live=(uintptr_t)context==atomic_load(&progressionContext) && policy.control && readable(policy.control,&strong,4) && strong>0;
    os_unfair_lock_unlock(&_progressionLock);if(!live)return NO;
    uint64_t target=0;memcpy(&target,head+4,8);
    if(kind ? (target!=CPNameHash(@"AddExperience;Int32gamedataProficiencyTypetelemetryLevelGainReasonBool") && target!=CPNameHash(@"AddExperience")) : (target!=policy.function && *(const uint64_t *)(target+8)!=policy.functionName))return NO;
    // Evaluate each original expression exactly once, retaining the caller's
    // locals/parameters/context. Only four verified scalar inputs are accepted.
    __unsafe_unretained CPNativeBridge *policyScope=scope;scope=self;
    progressionRecursive=YES;uint16_t oldFlags=0,flags=0;uint8_t oldParam=frame[0x62];memcpy(&oldFlags,frame+0x60,2);memcpy(&flags,head+12,2);
    uint8_t *cursor=head+14;memcpy(frame,&cursor,8);memcpy(frame+0x60,&flags,2);frame[0x62]=0;
    uint8_t arguments[4][8]={{0}};
    @try {
        for(int i=0;i<4;i++){
            memcpy(&cursor,frame,8);if(*cursor==0x26 && i==3)break;
            uint8_t opcode=*cursor++;memcpy(frame,&cursor,8);memset(frame+0x30,0,16);frame[0x62]++;
            uintptr_t handler=0;readable((uintptr_t)_image+0x9a5c940+opcode*8,&handler,8);
            uintptr_t evaluationContext=0;memcpy(&evaluationContext,frame+0x40,8);
            ((CPHandler)handler)((void *)evaluationContext,frame,arguments[i],(void *)policy.types[i]);
        }
        memcpy(&cursor,frame,8);uint8_t *end=cursor+1;
        int32_t input=0,proficiency=0;memcpy(&input,arguments[0],4);memcpy(&proficiency,arguments[1],4);
        int group=-1;if(proficiency==policy.level)group=0;else if(proficiency==policy.cred)group=1;else for(int i=0;i<5;i++)if(proficiency==policy.skills[i])group=2;
        int32_t scaled=input;
        if(input>0 && group>=0){
            double amount=input*policy.factors[group];
            if(policy.maximum[group]){
                NSData *typeValue=[NSData dataWithBytes:&proficiency length:4];
                NSData *limit=[self invokeScript:_progressionCap context:(uintptr_t)context arguments:@[typeValue] resultSize:4 error:NULL];int32_t nativeCap=0;if(limit.length==4)memcpy(&nativeCap,limit.bytes,4);
                if(nativeCap>0 && nativeCap<=10000000)amount=MAX(amount,nativeCap);
            }
            if(policy.factors[group]!=1 || policy.maximum[group])scaled=(int32_t)MIN(10000000,MAX(1,llround(amount)));memcpy(arguments[0],&scaled,4);
        }
        uint8_t code[14+4*9+1]={0},props[4][0x30]={0},locals[4*8]={0};memcpy(code+4,&target,8);size_t codeCursor=14;
        for(int i=0;i<4;i++){
            memcpy(locals+i*8,arguments[i],8);memcpy(props[i],&policy.types[i],8);uint32_t offset=i*8;memcpy(props[i]+0x20,&offset,4);
            code[codeCursor++]=0x18;uintptr_t property=(uintptr_t)props[i];memcpy(code+codeCursor,&property,8);codeCursor+=8;
        }
        code[codeCursor]=0x26;uint16_t exit=codeCursor-1;memcpy(code,&exit,2);
        uintptr_t oldLocals=0,newLocals=(uintptr_t)locals;memcpy(&oldLocals,frame+0x10,8);memcpy(frame+0x10,&newLocals,8);
        uint8_t *newCode=code;memcpy(frame,&newCode,8);memcpy(frame+0x60,&oldFlags,2);frame[0x62]=oldParam;
        __unsafe_unretained CPNativeBridge *oldScope=scope;scope=self;
        NSData *typeArgument=[NSData dataWithBytes:&proficiency length:4];
        NSData *before=[self invokeScript:_progressionGetter context:(uintptr_t)context arguments:@[typeArgument] resultSize:4 error:NULL];
        NSData *levelBefore=[self invokeScript:_progressionLevel context:(uintptr_t)context arguments:@[typeArgument] resultSize:4 error:NULL];
        NSData *after=nil,*levelAfter=nil,*maximum=nil;
        @try {
            atomic_load(&originalInvoke[kind])(context,frame,result,resultType);
            after=[self invokeScript:_progressionGetter context:(uintptr_t)context arguments:@[typeArgument] resultSize:4 error:NULL];
            levelAfter=[self invokeScript:_progressionLevel context:(uintptr_t)context arguments:@[typeArgument] resultSize:4 error:NULL];
            maximum=[self invokeScript:_progressionMax context:(uintptr_t)context arguments:@[typeArgument] resultSize:1 error:NULL];
        }
        @finally {scope=oldScope;memcpy(frame+0x10,&oldLocals,8);memcpy(frame,&end,8);memcpy(frame+0x60,&oldFlags,2);frame[0x62]=oldParam;memset(frame+0x30,0,16);}
        int32_t nativeBefore=0,nativeAfter=0,level0=0,level1=0;
        BOOL valuesValid=before.length==4 && after.length==4 && levelBefore.length==4 && levelAfter.length==4;
        if(valuesValid){memcpy(&nativeBefore,before.bytes,4);memcpy(&nativeAfter,after.bytes,4);memcpy(&level0,levelBefore.bytes,4);memcpy(&level1,levelAfter.bytes,4);}
        if(input>0 && group>=0){os_unfair_lock_lock(&_progressionLock);if(_progression.epoch==policy.epoch){_progression.count[group]++;_progression.input[group]=input;_progression.scaled[group]=scaled;_progression.before[group]=nativeBefore;_progression.after[group]=nativeAfter;_progression.verified[group]=valuesValid && (nativeAfter-nativeBefore==scaled || level1>level0);_progression.maxReached[group]=maximum.length==1 && *(const uint8_t *)maximum.bytes;}os_unfair_lock_unlock(&_progressionLock);}
        return YES;
    } @finally {progressionRecursive=NO;scope=policyScope;}
}

- (NSString *)strongTypeForClass:(NSString *)className {
    for(NSString *candidate in @[className,@"IScriptable",@"ISerializable"]){
        if(![candidate isEqual:className] && !CPNativeClassIsA(_image,className,candidate))continue;
        NSString *type=[@"handle:" stringByAppendingString:candidate];
        if([self typeMethod:type offset:0x48 type:NULL])return type;
    }return nil;
}
- (BOOL)object:(NSData *)object isKindOf:(NSString *)className {
    if(scope!=self || object.length!=16)return NO;
    uintptr_t pair[2]={0},vt=0,getType=0,expected=CPFindNativeType(_image,className);memcpy(pair,object.bytes,16);
    if(!pair[0] || !pair[1] || !expected || !readable(pair[0],&vt,8) || !readable(vt+8,&getType,8)
       || getType<(uintptr_t)_image || getType>=(uintptr_t)_image+0x7758000)return NO;
    // ISerializable::GetType precedes both destructor slots on arm64. The
    // resulting native CClass must reach the exact registered declared class.
    uintptr_t actual=((uintptr_t (*)(uintptr_t))getType)(pair[0]);
    for(unsigned depth=0;actual && depth<32;depth++){if(actual==expected)return YES;if(!readable(actual+0x10,&actual,8))return NO;}return NO;
}
- (NSData *)weakForCallbackObject:(uintptr_t)object className:(NSString *)className {
    if(scope!=self || !object)return nil;
    uintptr_t pair[2]={0};uint32_t strong=0;
    if(!readable(object+8,pair,16) || pair[0]!=object || !pair[1] || !readable(pair[1],&strong,4) || !strong)return nil;
    NSData *borrowed=[NSData dataWithBytes:pair length:16];
    if(![self object:borrowed isKindOf:className])return nil;
    return [self weakFromStrong:borrowed className:className];
}
- (NSData *)readProperty:(NSString *)property className:(NSString *)className object:(NSData *)object type:(NSString *)typeName {
    NSUInteger size=valueSize(typeName);if(!size || size>128 || ![self object:object isKindOf:className])return nil;
    uintptr_t prop=CPFindProperty(_image,className,property,typeName),opcode=0;uint32_t words[3]={0};const uint32_t expected[]={0xa9bd57f6,0xa9014ff4,0xa9027bfd};
    if(!prop || !readable((uintptr_t)_image+0x9a5c940+0x1a*8,&opcode,8) || opcode!=(uintptr_t)_image+0x1201454
       || !readable(opcode,words,sizeof(words)) || memcmp(words,expected,sizeof(words)))return nil;
    uintptr_t instance=0;memcpy(&instance,object.bytes,8);uint8_t frame[0xa8]={0};prepareFrame(frame,(uintptr_t)_image,instance,&prop,NULL);
    NSMutableData *result=[NSMutableData dataWithLength:size];
    @try {((CPHandler)opcode)((void *)instance,frame,result.mutableBytes,(void *)CPFindNativeType(_image,typeName));}
    @finally {((void (*)(void *))((uintptr_t)_image+0x11ab310))(frame);}
    return result;
}
- (BOOL)ensureInvocationObservers {
    if(!_invokeAttached){
        const uintptr_t offsets[]={0x12011e4,0x1200ec8};CPHandler replacements[]={observeInvocation24,observeInvocation25};
        for(int i=0;i<2;i++){
            uintptr_t slot=(uintptr_t)_image+0x9a5c940+(0x24+i)*8,expected=(uintptr_t)_image+offsets[i];
            if(!writableData(slot,8))return NO;
            atomic_store(&originalInvoke[i],(CPHandler)expected);_invokeSlots[i]=slot;
            if(!atomic_compare_exchange_strong((_Atomic(uintptr_t) *)slot,&expected,(uintptr_t)replacements[i])){
                if(i){uintptr_t own=(uintptr_t)replacements[0];atomic_compare_exchange_strong((_Atomic(uintptr_t) *)_invokeSlots[0],&own,(uintptr_t)atomic_load(&originalInvoke[0]));}return NO;
            }
        }_invokeAttached=YES;
    }
    return YES;
}

- (BOOL)setScriptObserver:(NSString *)name binding:(NSDictionary *)binding methodName:(NSString *)method handler:(CPScriptObservation)handler {
    if(scope!=self || !name.length || !handler || !binding[@"function"] || [binding[@"native"] boolValue] || [binding[@"properties"] count]>8 || ![self ensureInvocationObservers])return NO;
    uint64_t functionName=0;if(!readable([binding[@"function"] unsignedLongLongValue]+8,&functionName,8) || !functionName)return NO;
    NSDictionary *entry=@{@"binding":binding,@"method":method,@"handler":[handler copy],@"functionName":@(functionName)};
    os_unfair_lock_lock(&_observationLock);
    if(!_observations[name] && _observations.count>=8){os_unfair_lock_unlock(&_observationLock);return NO;}
    _observations[name]=entry;[self publishObservations];os_unfair_lock_unlock(&_observationLock);return YES;
}
- (void)publishObservations {
    atomic_store(&observationCount,0);unsigned index=0;
    for(NSDictionary *entry in _observations.allValues){
        atomic_store(&observationFunctions[index],[entry[@"binding"][@"function"] unsignedLongLongValue]);atomic_store(&observationNames[index],CPNameHash(entry[@"method"]));atomic_store(&observationFunctionNames[index],[entry[@"functionName"] unsignedLongLongValue]);index++;
    }atomic_store(&observationCount,index);
}
- (void)removeScriptObserver:(NSString *)name {
    if(scope!=self)return;os_unfair_lock_lock(&_observationLock);[_observations removeObjectForKey:name];[self publishObservations];os_unfair_lock_unlock(&_observationLock);
    if(!atomic_load(&observationCount) && !atomic_load(&progressionContext))[self clearProgression];
}
- (void)clearScriptObservers {
    if(scope!=self)return;os_unfair_lock_lock(&_observationLock);[_observations removeAllObjects];[self publishObservations];os_unfair_lock_unlock(&_observationLock);
    if(!atomic_load(&progressionContext))[self clearProgression];
}
- (NSData *)copyTypedPointer:(uintptr_t)pointer type:(NSString *)typeName {
    NSUInteger size=valueSize(typeName);if(!size || size>32 || !pointer)return nil;
    uint8_t bytes[32]={0};if(!readable(pointer,bytes,size))return nil;
    if([typeName hasPrefix:@"handle:"] || [typeName hasPrefix:@"whandle:"]){
        uintptr_t type=0,assign=[self typeMethod:typeName offset:0x58 type:&type];if(!assign)return nil;
        NSMutableData *copy=[NSMutableData dataWithLength:size];((void (*)(uintptr_t,void *,const void *))assign)(type,copy.mutableBytes,bytes);return copy;
    }return [NSData dataWithBytes:bytes length:size];
}
- (BOOL)observeInvocation:(int)kind context:(void *)context frame:(void *)rawFrame result:(void *)result resultType:(void *)resultType {
    uint8_t *frame=rawFrame,*head=NULL;memcpy(&head,frame,8);uint64_t target=0;memcpy(&target,head+4,8);
    os_unfair_lock_lock(&_observationLock);NSString *name=nil;NSDictionary *entry=nil;
    uint64_t functionName=0;if(!kind && target)memcpy(&functionName,(const void *)(target+8),8);
    for(NSString *key in _observations){NSDictionary *candidate=_observations[key];uint64_t match=kind ? CPNameHash(candidate[@"method"]) : [candidate[@"binding"][@"function"] unsignedLongLongValue];
        if(match==target || (kind ? target : functionName)==[candidate[@"functionName"] unsignedLongLongValue]){name=key;entry=candidate;break;}}
    os_unfair_lock_unlock(&_observationLock);if(!entry)return NO;
    NSDictionary *binding=entry[@"binding"];NSMutableArray *arguments=[NSMutableArray new];BOOL copied=YES;
    __unsafe_unretained CPNativeBridge *oldScope=scope;scope=self;observingInvocation=YES;
    @try {
        // Inspect typed LocalVar/Param expressions, optionally weak-to-strong. Never execute
        // an argument twice or infer an owner from an arbitrary raw pointer.
        uintptr_t cursor=(uintptr_t)head+14;
        NSUInteger count=binding[@"observedPrefix"] ? [binding[@"observedPrefix"] unsignedIntegerValue] : [binding[@"parameterTypes"] count];
        if(count>[binding[@"parameterTypes"] count])copied=NO;
        for(NSUInteger i=0;copied && i<count;i++){
            uint8_t opcode=0;uintptr_t property=0,type=0,base=0;uint64_t flags=0;uint32_t offset=0;
            NSString *typeName=binding[@"parameterTypes"][i],*sourceType=typeName;
            if(!readable(cursor,&opcode,1)){copied=NO;break;}
            BOOL weakConversion=opcode==0x63 && [typeName hasPrefix:@"handle:"];
            if(weakConversion){cursor++;sourceType=[@"whandle:" stringByAppendingString:[typeName substringFromIndex:7]];if(!readable(cursor,&opcode,1)){copied=NO;break;}}
            if((opcode!=0x18 && opcode!=0x19) || !readable(cursor+1,&property,8)
               || !readable(property,&type,8) || type!=CPFindNativeType(_image,sourceType) || !readable(property+0x20,&offset,4) || offset>65536
               || !readable(property+0x28,&flags,8) || (flags&((1ull<<9)|(1ull<<21))) || !readable((uintptr_t)frame+(opcode==0x18 ? 0x10 : 0x18),&base,8)) {copied=NO;break;}
            NSData *value=[self copyTypedPointer:base+offset type:sourceType];
            if(weakConversion){NSData *weak=value;value=[self lockWeak:weak];[self destroyValue:weak type:sourceType];}
            if(!value){copied=NO;break;}[arguments addObject:value];cursor+=9;
        }
        uint8_t end=0;if(count==[binding[@"parameterTypes"] count] && (!readable(cursor,&end,1) || end!=0x26))copied=NO;
        atomic_load(&originalInvoke[kind])(context,frame,result,resultType);
        if(copied){
            BOOL expected=NO;
            if(atomic_compare_exchange_strong(&_draining,&expected,YES)){
                @try {
                    os_unfair_lock_lock(&_observationLock);BOOL current=_observations[name]==entry;os_unfair_lock_unlock(&_observationLock);
                    if(current){
                        NSData *resultValue=result && ![binding[@"returnType"] isEqual:@"Void"] ? [self copyTypedPointer:(uintptr_t)result type:binding[@"returnType"]] : nil;
                        @try {((CPScriptObservation)entry[@"handler"])((uintptr_t)context,arguments,resultValue);}
                        @finally {[self destroyValue:resultValue type:binding[@"returnType"]];}
                    }
                } @finally {_draining=NO;}
            }
        }
        return YES;
    } @finally {
        for(NSUInteger i=0;i<arguments.count;i++)[self destroyValue:arguments[i] type:binding[@"parameterTypes"][i]];
        observingInvocation=NO;scope=oldScope;
    }
}

- (BOOL)setFrameWork:(dispatch_block_t)work world:(NSData *)world player:(NSData *)player {
    if(scope!=self || !work || world.length!=24 || player.length!=16)return NO;
    NSData *weak=[self weakFromStrong:player className:@"gameObject"];if(!weak)return NO;
    [self clearFrameWork];_framePlayerWeak=weak;_frameWorld=[world copy];_frameWork=[work copy];
    mach_timebase_info_data_t timebase={0};mach_timebase_info(&timebase);_frameIntervalTicks=(uint64_t)((1000000000.0/60)*timebase.denom/timebase.numer);_nextFrameTicks=0;uintptr_t pointer=0;memcpy(&pointer,player.bytes,8);_frameContext=pointer;_hasFrameWork=YES;return YES;
}
- (void)clearFrameWork {
    _hasFrameWork=NO;_frameContext=0;
    if(scope!=self)return;
    _frameWork=nil;_frameWorld=nil;[self destroyValue:_framePlayerWeak type:@"whandle:gameObject"];_framePlayerWeak=nil;
}

- (NSNumber *)hackingTimerPaused:(NSData *)object {
    if(![self object:object isKindOf:@"gameuiHackingMinigameGameController"])return nil;
    NSDictionary *pause=[self resolveClass:@"gameuiHackingMinigameGameController" method:@"PauseTheTimer" parameters:@[] result:@"Void"];
    const uint32_t expected[]={0xf9400028,0x91000508,0xf9000028,0x9107d008,0x52800029,0xb8e98108,0xd65f03c0};uint32_t words[7]={0},paused=0;uintptr_t instance=0;
    if(![pause[@"nativeHandlerOffset"] isEqual:@"0x4c0b6cc"] || !readable([pause[@"handler"] unsignedLongLongValue],words,sizeof(words)) || memcmp(words,expected,sizeof(words)))return nil;
    memcpy(&instance,object.bytes,8);
    // Exact build's native PauseTheTimer/ResumeTheTimer atomically exchange
    // this aligned 32-bit field. No layout from another game build is used.
    if(!readable(instance+0x1f4,&paused,4) || paused>1)return nil;return @(paused!=0);
}
- (void)withoutProgression:(dispatch_block_t)work {
    if(scope!=self || !work)return;BOOL previous=progressionRecursive;progressionRecursive=YES;
    @try {work();} @finally {progressionRecursive=previous;}
}
@end





