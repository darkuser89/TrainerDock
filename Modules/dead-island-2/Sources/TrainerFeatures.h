// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, DI2Feature) {
    DI2FeatureGod, DI2FeatureHealth, DI2FeatureStamina, DI2FeatureDurability,
    DI2FeatureStealth, DI2FeaturePlayerSpeed, DI2FeatureMovementSpeed, DI2FeatureGameSpeed,
    DI2FeatureSuperForce, DI2FeatureForceMultiplier, DI2FeatureOneHit,
    DI2FeatureDamageMultiplier, DI2FeatureDefenseMultiplier, DI2FeatureMoney,
    DI2FeatureConsumables, DI2FeatureItems, DI2FeatureCrafting, DI2FeatureAmmo,
    DI2FeatureNoReload, DI2FeatureAccuracy, DI2FeatureNoRecoil, DI2FeatureCurveball,
    DI2FeatureFullFury, DI2FeatureInfiniteFury, DI2FeatureMaxXP, DI2FeatureXPMultiplier,
    DI2FeatureCount
};
typedef struct {
    __unsafe_unretained NSString *title, *shortcut, *detail;
    BOOL implemented, numeric, oneShot;
    double initial, minimum, maximum, step;
    unsigned short key;
    NSUInteger modifiers; // 0, Shift (1), Option (2)
} DI2FeatureInfo;
const DI2FeatureInfo *DI2FeatureInfoAt(DI2Feature feature);

@interface DI2FeatureState : NSObject
@property(nonatomic) BOOL available, wanted, active;
@property(nonatomic) double value;
@property(nonatomic, copy) NSString *note;
@end
