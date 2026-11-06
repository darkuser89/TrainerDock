// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, MTFeature) { MTFeatureHealth, MTFeatureStamina, MTFeatureAmmo, MTFeatureSpeed, MTFeatureMoney, MTFeatureResources, MTFeatureHazards, MTFeatureLanguages, MTFeatureQuicksilver, MTFeatureShield, MTFeatureJetpack, MTFeatureMultiToolHeat, MTFeatureNoReload, MTFeatureGrenades, MTFeatureItems, MTFeatureCrafting, MTFeatureDamage, MTFeatureShipHealth, MTFeatureShipShield, MTFeatureShipHeat, MTFeatureInfiniteUnits, MTFeatureGameSpeed, MTFeatureAtlasLocks, MTFeatureInfiniteNanites, MTFeatureInfiniteQuicksilver, MTFeatureLaunchFuel, MTFeaturePulseFuel, MTFeatureHyperdriveFuel, MTFeatureScanner, MTFeatureToolEnergy, MTFeatureCount };
typedef struct {
    __unsafe_unretained NSString *title, *shortcut, *detail;
    BOOL implemented, numeric, oneShot, integer;
    double initial, minimum, maximum, step;
    unsigned short key;
    NSUInteger modifiers;
} MTFeatureInfo;
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature);
@interface MTFeatureState : NSObject
@property(nonatomic) BOOL available, wanted, active;
@property(nonatomic) double value;
@property(nonatomic,copy) NSString *note;
@end
