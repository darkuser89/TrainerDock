// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
#import "CyberpunkNativeBridge.h"
@interface CPEffects : NSObject
- (instancetype)initWithNative:(CPNativeBridge *)native;
- (BOOL)bindWorld:(NSData *)world player:(NSData *)player entityID:(uint64_t)entity identity:(NSString *)identity;
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value;
- (void)setMovementInput:(uint32_t)input;
- (BOOL)releaseEffects;
- (NSString *)performOneShot:(MTFeature)feature value:(double)value;
@end
