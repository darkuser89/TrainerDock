// SPDX-License-Identifier: GPL-3.0-only
#import "RE7Ownership.h"
#import "RE7Engine.h"
#import "MemoryAccess.h"
static uintptr_t w7(const void *p,size_t offset){uintptr_t n=0;MTReadMemory((const uint8_t *)p+offset,&n,8);return n;}
@implementation RE7Owner {
    MTRE2Engine *_weakEngine7;
}
+ (instancetype)ownerForGameObject:(void *)go engine:(MTRE2Engine *)engine {
    RE7Owner *owner=[super ownerForGameObject:go engine:engine];if(owner)owner->_weakEngine7=engine;return owner;
}
+ (instancetype)ownerForComponent:(void *)component engine:(MTRE2Engine *)engine {
    RE7Owner *owner=[super ownerForComponent:component engine:engine];if(owner)owner->_weakEngine7=engine;return owner;
}
- (void)retainPayload:(void *)payload {
    // Payloads remain owned by their game's component/field/list. Every RE7
    // effect must validate that connection again before reading or writing.
    (void)payload;
}
- (BOOL)valid {
    MTRE2Engine *e=_weakEngine7;void *go=self.gameObject,*component=self.component;
    if(!e.isGameThread || [e typeOf:go]!=34333)return NO;
    if(component){
        if(![e isObject:component kindOf:32277])return NO;
        uintptr_t at=w7(go,0x18);BOOL found=NO;
        for(NSUInteger i=0;at && i<512;i++){
            if(![e isObject:(void *)at kindOf:32277] || w7((void *)at,0x10)!=(uintptr_t)go)return NO;
            if(at==(uintptr_t)component){found=YES;break;}
            uintptr_t next=w7((void *)at,0x18);if(next==at)return NO;at=next;
        }
        if(!found)return NO;
    }
    // Resolves the native Guid and checks the exact GameObject, then the
    // component's validity. The checked list prevents stale component calls.
    return [super valid];
}
@end
