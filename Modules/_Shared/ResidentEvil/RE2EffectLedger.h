// SPDX-License-Identifier: GPL-3.0-only
#import "RE2Adapter.h"
#import "RE2Ownership.h"
// Shared ownership/readback ledger. The per-game adapter supplies exact bindings.
@interface RE2NativeAdapter (EffectLedger)
- (BOOL)applyBytes:(NSData *)bytes object:(void *)object offset:(size_t)offset owner:(RE2Owner *)owner global:(BOOL)global feature:(RE2Feature)feature;
- (BOOL)applyBytes:(NSData *)bytes object:(void *)object offset:(size_t)offset owner:(RE2Owner *)owner global:(BOOL)global feature:(RE2Feature)feature guard:(BOOL (^)(void))guard;
- (NSData *)baselineForObject:(void *)object offset:(size_t)offset feature:(RE2Feature)feature;
- (NSData *)baselineForNativeObject:(void *)object tag:(uint32_t)tag feature:(RE2Feature)feature;
- (BOOL)applyNativeBytes:(NSData *)bytes object:(void *)object tag:(uint32_t)tag owner:(RE2Owner *)owner feature:(RE2Feature)feature guard:(BOOL (^)(void))guard read:(NSData *(^)(void))read write:(void (^)(NSData *))write;
- (void)releaseFeature:(RE2Feature)feature;
- (void *)objectGetter:(uint32_t)index owner:(uint32_t)owner object:(void *)object;
@end
