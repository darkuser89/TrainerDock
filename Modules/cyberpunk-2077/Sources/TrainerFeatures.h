// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, MTFeature) {
    MTFeatureHealth, MTFeatureStamina, MTFeatureAmmo, MTFeatureSpeed, MTFeatureMoney, MTFeatureResources, MTFeatureKeepItems, MTFeatureHealingCooldown, MTFeatureGrenadeCooldown, MTFeatureProjectileCooldown, MTFeatureNoReload, MTFeatureAccuracy, MTFeatureRecoil, MTFeatureOneHitKill, MTFeatureDamageMultiplier, MTFeatureDefenseMultiplier, MTFeatureStealth, MTFeatureXP, MTFeatureXPMultiplier, MTFeatureStreetCred, MTFeatureStreetCredMultiplier, MTFeatureSkillXP, MTFeatureSkillXPMultiplier, MTFeatureAttributePoints, MTFeaturePerkPoints, MTFeatureRelicPoints, MTFeatureCyberwareCapacity, MTFeatureGameSpeed, MTFeatureRAM, MTFeatureBreachTimer, MTFeatureQuickhackComponents, MTFeatureCarryWeight, MTFeatureSuperJump, MTFeatureDoubleJump, MTFeaturePlayerLevel, MTFeatureStreetCredLevel, MTFeatureFreezeDaytime, MTFeatureAddHour, MTFeatureHeadhunterLevel, MTFeatureNetrunnerLevel, MTFeatureShinobiLevel, MTFeatureSoloLevel, MTFeatureEngineerLevel, MTFeatureFly, MTFeatureFlyHeight, MTFeatureFlySpeed, MTFeatureCount
};
typedef struct {
    __unsafe_unretained NSString *title, *shortcut, *detail;
    BOOL implemented, numeric, oneShot, integer;
    double initial, minimum, maximum, step;
    unsigned short key;
    NSUInteger modifiers;
} MTFeatureInfo;
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature);
// Select once at process startup, before creating any UI or bridge.
void MTUseDemoFeatures(void);
@interface MTFeatureState : NSObject
@property(nonatomic) BOOL available, wanted, active;
@property(nonatomic) double value;
@property(nonatomic,copy) NSString *note;
@end
