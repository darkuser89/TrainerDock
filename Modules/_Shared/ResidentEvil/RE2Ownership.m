// SPDX-License-Identifier: GPL-3.0-only
#import "RE2Ownership.h"
#import "RE2Bindings.h"
#import "MemoryAccess.h"
@implementation RE2Owner {
    MTRE2Engine *_engine;
    void *_component,*_gameObject;
    uint64_t _boxedGameObjectRef[4];
    NSMutableArray<NSValue *> *_payloads;
}
+ (instancetype)ownerForComponent:(void *)component engine:(MTRE2Engine *)engine {
    if(!engine.isGameThread || !component || [engine typeOf:component]==UINT32_MAX)return nil;
    BOOL (*valid)(void *,void *)=[engine method:engine.componentValidMethod owner:engine.componentType];
    void *(*gameObject)(void *,void *)=[engine method:engine.componentGameObjectMethod owner:engine.componentType];
    void (*construct)(void *,void *,void *)=[engine method:engine.weakConstructor owner:engine.weakGameObjectType];
    void *(*resolve)(void *,void *)=[engine method:engine.weakResolver owner:engine.weakGameObjectType];
    void *context=engine.threadContext;
    if(!context || !valid || !gameObject || !construct || !resolve || !valid(context,component))return nil;
    void *go=gameObject(context,component);if(!go)return nil;
    RE2Owner *owner=[self new];owner->_engine=engine;owner->_payloads=[NSMutableArray new];
    // The exact wrapper constructs the Guid payload at +0x10 and resolves the
    // same native GameObject through the engine's scene-object registry.
    construct(context,owner->_boxedGameObjectRef,go);
    if(resolve(context,owner->_boxedGameObjectRef)!=go)return nil;
    NSUInteger base=engine.weakPayloadOffset/8;uint64_t nonzero=owner->_boxedGameObjectRef[base]|owner->_boxedGameObjectRef[base+1];if(!nonzero)return nil;
    owner->_component=component;owner->_gameObject=go;
    [owner retainPayload:component];return owner;
}
// Non-component managed triggers use the same native Guid registry, with the
// GameObject wrapper retained only for this binding's lifetime.
+ (instancetype)ownerForGameObject:(void *)go engine:(MTRE2Engine *)engine {
    if(!engine.isGameThread || [engine typeOf:go]!=engine.gameObjectType)return nil;
    uintptr_t native=0;if(!MTReadMemory((uint8_t *)go+engine.gameObjectComponentsOffset,&native,8) || !native)return nil;
    void (*construct)(void *,void *,void *)=[engine method:engine.weakConstructor owner:engine.weakGameObjectType];
    void *(*resolve)(void *,void *)=[engine method:engine.weakResolver owner:engine.weakGameObjectType];
    if(!construct || !resolve || !engine.threadContext)return nil;
    RE2Owner *owner=[self new];owner->_engine=engine;owner->_payloads=[NSMutableArray new];
    construct(engine.threadContext,owner->_boxedGameObjectRef,go);
    NSUInteger base=engine.weakPayloadOffset/8;
    if(!(owner->_boxedGameObjectRef[base]|owner->_boxedGameObjectRef[base+1]) || resolve(engine.threadContext,owner->_boxedGameObjectRef)!=go)return nil;
    owner->_gameObject=go;[owner retainPayload:go];return owner;
}
- (void *)component {return _component;}
- (void *)gameObject {return _gameObject;}
- (NSString *)identity {
    NSUInteger base=_engine.weakPayloadOffset/8;
    return [NSString stringWithFormat:@"%016llx%016llx",(unsigned long long)_boxedGameObjectRef[base],(unsigned long long)_boxedGameObjectRef[base+1]];
}
- (BOOL)valid {
    if(!_gameObject || !_engine.isGameThread)return NO;
    void *context=_engine.threadContext;
    void *(*resolve)(void *,void *)=[_engine method:_engine.weakResolver owner:_engine.weakGameObjectType];
    BOOL (*valid)(void *,void *)=[_engine method:_engine.componentValidMethod owner:_engine.componentType];
    void *(*gameObject)(void *,void *)=[_engine method:_engine.componentGameObjectMethod owner:_engine.componentType];
    if(!context || !resolve || resolve(context,_boxedGameObjectRef)!=_gameObject)return NO;
    if(!_component){uintptr_t native=0;return [_engine typeOf:_gameObject]==_engine.gameObjectType && MTReadMemory((uint8_t *)_gameObject+_engine.gameObjectComponentsOffset,&native,8) && native;}
    return valid && gameObject && valid(context,_component) && gameObject(context,_component)==_gameObject;
}
- (void)retainPayload:(void *)payload {
    if(!payload || !_engine.isGameThread || [_payloads containsObject:[NSValue valueWithPointer:payload]])return;
    if([_engine typeOf:payload]==UINT32_MAX)return;
    void (*retainObject)(void *)=(void *)(_engine.retainAddress);
    retainObject(payload);[_payloads addObject:[NSValue valueWithPointer:payload]];
}
- (void)dealloc {
    NSArray<NSValue *> *payloads=[_payloads copy];uintptr_t releaseAddress=_engine.releaseAddress;
    dispatch_block_t release=^{void (*releaseObject)(void *)=(void *)releaseAddress;for(NSValue *entry in payloads.reverseObjectEnumerator)releaseObject(entry.pointerValue);};
    if(_engine.isGameThread)release();else if(payloads.count)[_engine enqueue:release];
}
@end
