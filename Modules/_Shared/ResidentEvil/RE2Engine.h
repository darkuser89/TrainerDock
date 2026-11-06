// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
// Exact-build native backend. No code-page patches or protection changes.
@interface MTRE2Engine : NSObject
@property(nonatomic,readonly) BOOL identified, installed, isRE3;
@property(nonatomic,readonly) uint32_t componentType, gameObjectType, weakGameObjectType, weakConstructor, weakResolver;
@property(nonatomic,readonly) uint32_t componentValidMethod, componentGameObjectMethod;
@property(nonatomic,readonly) NSUInteger weakPayloadOffset;
@property(nonatomic,readonly) NSUInteger gameObjectComponentsOffset;
@property(nonatomic,readonly) uintptr_t retainAddress, releaseAddress;
@property(nonatomic,readonly) uintptr_t slide;
@property(nonatomic,readonly) NSString *failure;
+ (instancetype)shared;
- (BOOL)installGameThreadDelivery;
- (void)enqueue:(dispatch_block_t)work;
- (BOOL)isGameThread;
- (void *)threadContext;
- (void *)method:(uint32_t)index owner:(uint32_t)owner;
- (void *)singletonAt:(uintptr_t)unslidSlot;
- (uint32_t)typeOf:(const void *)object;
- (void)setContinuousWork:(dispatch_block_t)work;
- (BOOL)isObject:(void *)object kindOf:(uint32_t)type;
@end
typedef struct {
    uint64_t frames, gameThreadID;
    uintptr_t context, playerManager, playerCondition, hitPoints;
    uint32_t health, maxHealth, error;
    char threadName[64];
} MTRE2EngineEvidence;
extern MTRE2EngineEvidence MTRE2Evidence;
void MTRE2PrepareEngineVerification(void);
