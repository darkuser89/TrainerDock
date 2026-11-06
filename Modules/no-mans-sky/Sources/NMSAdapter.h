// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
// Flags are native cGcDebugOptions/cGcPlayerGlobals members, resolved by metadata.
@interface MTNMSAdapter : NSObject <MTGameAdapter>
@end
BOOL MTNMSProcessBuildMatches(void);
BOOL MTNMSReadOnly(void);
// Objective-C's non-fragile ivars move with AppKit superclass layouts.
ptrdiff_t MTNMSCaptureIvarOffset(Class viewClass);
// Validate the native 72-byte inventory-edit record before charging technology.
BOOL MTNMSPrepareRecharge(void *bytes,NSUInteger length);
// These helpers are shared by the native adapter and synthetic regression tests.
MTSessionKind MTNMSSessionKind(BOOL playing, BOOL enabled, const uint32_t sessions[3]);
@interface MTNMSValue : NSObject
- (instancetype)initWithAddress:(void *)address size:(NSUInteger)size;
- (BOOL)applyBytes:(const void *)bytes readOnly:(BOOL)readOnly;
- (BOOL)releaseValue;
@property(nonatomic,readonly) BOOL ownsValue;
@end
