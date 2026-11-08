// SPDX-License-Identifier: GPL-3.0-only
#import "CyberpunkAdapter.h"
#import "CyberpunkNativeBridge.h"
#import "CyberpunkMetadata.h"
#import "CyberpunkEffects.h"
#import "CyberpunkCursor.h"
static NSData *bytes(const void *value,NSUInteger size){return [NSData dataWithBytes:value length:size];}
static uintptr_t instance(NSData *handle){uintptr_t value=0;if(handle.length==16)memcpy(&value,handle.bytes,8);return value;}
static BOOL sameHandle(NSData *a,NSData *b){return a.length==16 && b.length==16 && !memcmp(a.bytes,b.bytes,16);}
@implementation CPCyberpunkAdapter {
    CPNativeBridge *_native;
    CPEffects *_effects;
    NSDictionary *_getPlayerSystem,*_getGodSystem,*_getLocalPlayer,*_getEntityID,*_isLocal,*_isAttached,*_worldValid,*_restoring,*_add,*_remove,*_has;
    NSData *_playerWeak,*_godWeak,*_world;
    NSString *_identity,*_failure;
    uint64_t _entityID,_reason;
    int32_t _mode;
    BOOL _ownsEffect,_bound;
}
- (instancetype)init {
    if((self=[super init])){
        _native=[CPNativeBridge new];_effects=[[CPEffects alloc]initWithNative:_native];_reason=CPNameHash([@"CodexCyberpunkTrainer." stringByAppendingString:NSUUID.UUID.UUIDString]);
        _identity=@"unbound";_failure=@"Warte auf die native Spielanbindung.";
    }return self;
}
- (void)onGameThread:(dispatch_block_t)work {
    NSError *error=nil;
    if(![_native install:&error]){_failure=error.localizedDescription;dispatch_async(dispatch_get_main_queue(),work);return;}
    [_native enqueue:work];
}
- (BOOL)resolveBindings {
    if(_bound)return YES;
    _getPlayerSystem=[_native resolveClass:@"ScriptGameInstance" method:@"GetPlayerSystem" parameters:@[@"ScriptGameInstance"] result:@"handle:cpPlayerSystem"];
    _getGodSystem=[_native resolveClass:@"ScriptGameInstance" method:@"GetGodModeSystem" parameters:@[@"ScriptGameInstance"] result:@"handle:gameGodModeSystem"];
    _getLocalPlayer=[_native resolveClass:@"cpPlayerSystem" method:@"GetLocalPlayerControlledGameObject" parameters:@[] result:@"handle:gameObject"];
    _getEntityID=[_native resolveClass:@"PlayerPuppet" method:@"GetEntityID" parameters:@[] result:@"entEntityID"];
    _isLocal=[_native resolveClass:@"PlayerPuppet" method:@"IsControlledByLocalPeer" parameters:@[] result:@"Bool"];
    _isAttached=[_native resolveClass:@"PlayerPuppet" method:@"IsAttached" parameters:@[] result:@"Bool"];
    _worldValid=[_native resolveClass:@"ScriptGameInstance" method:@"IsValid" parameters:@[@"ScriptGameInstance"] result:@"Bool"];
    _restoring=[_native resolveClass:@"ScriptGameInstance" method:@"IsRestoringState" parameters:@[@"ScriptGameInstance"] result:@"Bool"];
    NSArray *signature=@[@"entEntityID",@"gameGodModeType",@"CName"];
    _add=[_native resolveClass:@"gameGodModeSystem" method:@"AddGodMode" parameters:signature result:@"Bool"];
    _remove=[_native resolveClass:@"gameGodModeSystem" method:@"RemoveGodMode" parameters:signature result:@"Bool"];
    _has=[_native resolveClass:@"gameGodModeSystem" method:@"HasGodMode" parameters:@[@"entEntityID",@"gameGodModeType"] result:@"Bool"];
    NSNumber *mode=[_native enumType:@"gameGodModeType" member:@"Invulnerable"];
    _bound=_getPlayerSystem && _getGodSystem && _getLocalPlayer && _getEntityID && _isLocal && _isAttached && _worldValid && _restoring && _add && _remove && _has && mode && mode.intValue==0
        && [_native supportsHandleClass:@"gameObject" weak:YES] && [_native supportsHandleClass:@"gameGodModeSystem" weak:YES]
        && [_native supportsHandleClass:@"cpPlayerSystem" weak:NO];
    _mode=mode.intValue;
    if(!_bound){
        NSMutableArray *missing=[NSMutableArray new];
        NSArray *names=@[@"GetPlayerSystem",@"GetGodModeSystem",@"GetLocalPlayer",@"GetEntityID",@"IsControlledByLocalPeer",@"IsAttached",@"IsValid",@"IsRestoringState",@"AddGodMode",@"RemoveGodMode",@"HasGodMode"];
        NSArray *bindings=@[_getPlayerSystem ?: NSNull.null,_getGodSystem ?: NSNull.null,_getLocalPlayer ?: NSNull.null,_getEntityID ?: NSNull.null,_isLocal ?: NSNull.null,_isAttached ?: NSNull.null,_worldValid ?: NSNull.null,_restoring ?: NSNull.null,_add ?: NSNull.null,_remove ?: NSNull.null,_has ?: NSNull.null];
        for(NSUInteger i=0;i<names.count;i++)if(bindings[i]==NSNull.null)[missing addObject:names[i]];
        if(!mode || mode.intValue!=0)[missing addObject:[NSString stringWithFormat:@"Invulnerable enum=%@",mode ?: @"missing"]];
        if(![_native supportsHandleClass:@"gameObject" weak:YES])[missing addObject:@"gameObject weak ABI"];
        if(![_native supportsHandleClass:@"gameGodModeSystem" weak:YES])[missing addObject:@"GodModeSystem weak ABI"];
        if(![_native supportsHandleClass:@"cpPlayerSystem" weak:NO])[missing addObject:@"PlayerSystem handle ABI"];
        _failure=[@"Bindung gesperrt: " stringByAppendingString:[missing componentsJoinedByString:@", "]];
    }
    return _bound;
}
- (NSData *)call:(NSDictionary *)binding context:(uintptr_t)context args:(NSArray<NSData *> *)args size:(NSUInteger)size {
    NSError *error=nil;NSData *result=[_native invoke:binding context:context arguments:args resultSize:size error:&error];
    if(error)_failure=error.localizedDescription;return result;
}
- (BOOL)truth:(NSData *)value {return value.length==1 && ((const uint8_t *)value.bytes)[0]!=0;}
- (BOOL)removeOwned {
    if(!_ownsEffect)return YES;
    NSData *system=[_native lockWeak:_godWeak];
    if(!instance(system)){
        if([[_native weakIsExpired:_godWeak] isEqual:@YES]){_ownsEffect=NO;return YES;}
        _failure=@"Alte Unverwundbarkeit-Quelle kann noch nicht sicher aufgelöst werden.";return NO;
    }
    @try {
        NSArray *args=@[bytes(&_entityID,8),bytes(&_mode,4),bytes(&_reason,8)];
        if([self truth:[self call:_remove context:instance(system) args:args size:1]]){_ownsEffect=NO;return YES;}
        _failure=@"Eigene Unverwundbarkeit-Quelle wurde noch nicht zurückgenommen.";return NO;
    } @finally {[_native destroyValue:system type:@"handle:gameGodModeSystem"];}
}
- (MTGameContext *)captureContext {
    MTGameContext *context=[MTGameContext new];context.kind=MTSessionUnsupported;context.note=_failure;
    if(!_native.insideEngineCallback){
        // Startup may precede RTTI/native registration. Keep saved selection
        // while waiting; actual calls and binding validation still require scope.
        if([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.cdprojektred.cyberpunk.steam"])
            context.kind=MTSessionLoading;
        return context;
    }
    if(![self resolveBindings])return context;
    context.kind=MTSessionLoading;context.note=@"Warte auf die lokale Spielfigur.";
    NSData *world=_native.currentGameInstance;
    if(world.length!=24){context.note=@"Spielanbindung: Engine-Kontext fehlt.";return context;}
    if(![self truth:[self call:_worldValid context:0 args:@[world] size:1]] || [self truth:[self call:_restoring context:0 args:@[world] size:1]]){context.note=@"Warte auf eine vollständig geladene Spielwelt.";return context;}
    NSData *playerSystem=[self call:_getPlayerSystem context:0 args:@[world] size:16];
    NSData *player=nil,*god=nil;
    @try {
        if(!instance(playerSystem)){context.note=@"Spielanbindung: PlayerSystem noch nicht verfügbar.";return context;}
        player=[self call:_getLocalPlayer context:instance(playerSystem) args:@[] size:16];
        if(!instance(player) || instance(player)!=_native.currentCallbackContext
           || ![self truth:[self call:_isLocal context:instance(player) args:@[] size:1]]){context.note=@"Spielanbindung: lokaler Spieler-Callback noch nicht bestätigt.";return context;}
        if(![self truth:[self call:_isAttached context:instance(player) args:@[] size:1]]){context.note=@"Warte auf den in der Spielwelt angehängten lokalen Spieler.";return context;}
        NSData *idValue=[self call:_getEntityID context:instance(player) args:@[] size:8];uint64_t identifier=0;
        if(idValue.length==8)memcpy(&identifier,idValue.bytes,8);
        if(!identifier)return context;
        god=[self call:_getGodSystem context:0 args:@[world] size:16];
        if(!instance(god)){context.note=@"Spielanbindung: GodModeSystem noch nicht verfügbar.";return context;}
        // Compare the native world pointer, not padding/context payload in the
        // 24-byte ScriptGameInstance value. Retained weak control blocks prevent
        // reused object addresses alone from being mistaken for the old owner.
        NSData *worldIdentity=[world subdataWithRange:NSMakeRange(0,8)];
        BOOL changed=![_world isEqual:worldIdentity] || !sameHandle(_playerWeak,player) || !sameHandle(_godWeak,god) || identifier!=_entityID;
        if(changed){
            if(![self removeOwned] || ![_effects releaseEffects]){context.note=_failure;return context;}
            [_native destroyValue:_playerWeak type:@"whandle:gameObject"];[_native destroyValue:_godWeak type:@"whandle:gameGodModeSystem"];
            _playerWeak=[_native weakFromStrong:player className:@"gameObject"];
            _godWeak=[_native weakFromStrong:god className:@"gameGodModeSystem"];
            _world=[worldIdentity copy];_entityID=identifier;_identity=NSUUID.UUID.UUIDString;
        }
        if(!_playerWeak || !_godWeak){context.kind=MTSessionUnsupported;context.note=@"Native Weak-Handles fehlen.";return context;}
        // This adapter targets only the exact original single-player Steam build.
        // It never treats an arbitrary puppet or a captured raw pointer as local.
        if(![_effects bindWorld:world player:player entityID:_entityID identity:_identity]){context.note=@"Spielanbindung: lokale Effektbindung nicht bestätigt.";return context;}
        context.kind=MTSessionSolo;context.identity=_identity;context.note=@"Lokaler Spieler über PlayerSystem und native Handles gebunden.";
        return context;
    } @finally {
        [_native destroyValue:god type:@"handle:gameGodModeSystem"];
        [_native destroyValue:player type:@"handle:gameObject"];
        [_native destroyValue:playerSystem type:@"handle:cpPlayerSystem"];
    }
}
- (void)releaseEffects {if(_native.insideEngineCallback){[self removeOwned];[_effects releaseEffects];}}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *state=[MTFeatureState new];state.value=value;state.wanted=wanted;
    if(feature!=MTFeatureHealth)return [_effects applyFeature:feature wanted:wanted value:value];
    if(!_native.insideEngineCallback || !_bound){state.note=@"Native Callback-Zustellung nicht bereit.";return state;}
    if(!wanted){
        if(![self removeOwned]){state.note=_failure;return state;}
        NSData *system=[_native lockWeak:_godWeak];
        @try {
            if(!instance(system)){state.note=@"Unverwundbarkeit-Rücklese wartet auf gültiges System.";return state;}
            NSData *readback=[self call:_has context:instance(system) args:@[bytes(&_entityID,8),bytes(&_mode,4)] size:1];
            state.available=readback.length==1;
            state.note=!state.available ? @"Unverwundbarkeit-Rücklese fehlgeschlagen." : [self truth:readback]
                ? @"Eigene Quelle aus; weitere Unverwundbarkeit-Quelle bleibt aktiv."
                : @"Eigene Quelle aus; nativer Unverwundbarkeit ist aus.";
            return state;
        } @finally {[_native destroyValue:system type:@"handle:gameGodModeSystem"];}
    }
    NSData *player=[_native lockWeak:_playerWeak],*system=[_native lockWeak:_godWeak];
    @try {
        if(!instance(player) || !instance(system)){state.note=@"Besitzer nicht mehr gültig.";return state;}
        NSData *idValue=[self call:_getEntityID context:instance(player) args:@[] size:8];uint64_t identifier=0;
        if(idValue.length==8)memcpy(&identifier,idValue.bytes,8);
        if(identifier!=_entityID || ![self truth:[self call:_isLocal context:instance(player) args:@[] size:1]]){state.note=@"Lokaler Besitzer hat gewechselt.";return state;}
        state.available=YES;
        if(!_ownsEffect)_ownsEffect=[self truth:[self call:_add context:instance(system) args:@[bytes(&_entityID,8),bytes(&_mode,4),bytes(&_reason,8)] size:1]];
        state.active=_ownsEffect && [self truth:[self call:_has context:instance(system) args:@[bytes(&_entityID,8),bytes(&_mode,4)] size:1]];
        state.note=state.active ? @"Nativer Unverwundbarkeit zurückgelesen; eigene Quelle." : @"Unverwundbarkeit nicht bestätigt.";
        return state;
    } @finally {[_native destroyValue:player type:@"handle:gameObject"];[_native destroyValue:system type:@"handle:gameGodModeSystem"];}
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {(void)feature;(void)value;return [_effects performOneShot:feature value:value];}
- (void)setMovementInput:(uint32_t)input {[_effects setMovementInput:input];}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return wanted && CPOverlayCursorActive();}
@end
