// SPDX-License-Identifier: GPL-3.0-only
#import "RE8Ownership.h"
#import "RE8Engine.h"
#import "MemoryAccess.h"
static uintptr_t w8(const void *p,size_t offset){uintptr_t n=0;MTReadMemory((const uint8_t *)p+offset,&n,8);return n;}
@implementation RE8Owner {
    MTRE2Engine *_weakEngine8;
}
+ (instancetype)ownerForGameObject:(void *)go engine:(MTRE2Engine *)engine {
    RE8Owner *owner=[super ownerForGameObject:go engine:engine];if(owner)owner->_weakEngine8=engine;return owner;
}
+ (instancetype)ownerForComponent:(void *)component engine:(MTRE2Engine *)engine {
    RE8Owner *owner=[super ownerForComponent:component engine:engine];if(owner)owner->_weakEngine8=engine;return owner;
}
- (void)retainPayload:(void *)payload {
    // Payloads remain owned by their game's component/field/list. Every RE8
    // effect must validate that connection again before reading or writing.
    (void)payload;
}
- (BOOL)valid {
    MTRE2Engine *e=_weakEngine8;void *go=self.gameObject,*component=self.component;
    if(!e.isGameThread || [e typeOf:go]!=101222)return NO;
    if(component){
        if(![e isObject:component kindOf:95136])return NO;
        uintptr_t at=w8(go,0x20);BOOL found=NO;
        for(NSUInteger i=0;at && i<512;i++){
            if(![e isObject:(void *)at kindOf:95136] || w8((void *)at,0x10)!=(uintptr_t)go)return NO;
            if(at==(uintptr_t)component){found=YES;break;}
            uintptr_t next=w8((void *)at,0x18);if(next==at)return NO;at=next;
        }
        if(!found)return NO;
    }
    // Resolves the native Guid and checks the exact GameObject, then the
    // component's validity. The checked list prevents stale component calls.
    return [super valid];
}
@end
