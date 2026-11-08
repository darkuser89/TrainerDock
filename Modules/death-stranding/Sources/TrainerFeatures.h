// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,MTFeature){MTFeatureHealth,MTFeatureConsciousness,MTFeatureStamina,MTFeatureFatigue,MTFeatureBBStress,MTFeatureCapacity,MTFeatureAmmoItems,MTFeatureEquipmentDurability,MTFeatureCargoDurability,MTFeatureContainerDurability,MTFeatureBalance,MTFeatureInvulnerable,MTFeatureEquipmentBattery,MTFeatureVehicleBattery,MTFeatureIgnoreWeight,MTFeatureUrine,MTFeatureStealth,MTFeatureNoReload,MTFeatureVehicleDurability,MTFeatureBuildMaterials,MTFeatureMaterials,MTFeatureMaterialCapacity,MTFeatureCrystals,MTFeatureGameSpeed,MTFeatureBuildingDurability,MTFeatureBandwidth,MTFeatureCount};
typedef struct {
    __unsafe_unretained NSString *title,*shortcut,*detail;
    BOOL implemented,numeric,oneShot,integer;
    double initial,minimum,maximum,step;
    unsigned short key;
    NSUInteger modifiers;
} MTFeatureInfo;
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature);
@interface MTFeatureState : NSObject
@property(nonatomic) BOOL available,wanted,active;
@property(nonatomic) double value;
@property(nonatomic,copy) NSString *note;
@end
