// SPDX-License-Identifier: GPL-3.0-only
#import "GameAccess.h"
#import "TrainerFeatures.h"

// Owned by the bridge. Every method, including reset, runs on the GameThread.
@interface DI2ExtraFeatures : NSObject
- (instancetype)initWithAPI:(DI2GameAPI)api;
- (void)reset;
- (void)updatePlayer:(void *)player controller:(void *)controller inventory:(void *)inventory
             wanted:(const BOOL *)wanted values:(const double *)values
          available:(BOOL *)available active:(BOOL *)active
             states:(NSArray<DI2FeatureState *> *)states;
@end
