// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
typedef NS_ENUM(NSInteger,RE4Feature){
 RE4God,RE4Health,RE4MaxHealth,RE4Armor,RE4Items,RE4Ammo,RE4NoReload,RE4Knife,
 RE4GameSpeed,RE4PlayerSpeed,RE4AISpeed,RE4EasyKills,RE4Damage,RE4Defense,
 RE4Pesetas,RE4PesetasMultiplier,RE4Spinels,RE4Tickets,RE4CP,RE4Unlock,RE4Craft,
 RE4Recoil,RE4Accuracy,RE4FOV,RE4RangeScore,RE4GoldTokens,RE4SilverTokens,
 RE4SaveCount,RE4FreezeTime,RE4AdjustTime,RE4MercTimer,RE4MercCombo,RE4MercGauge,
 RE4MercDuration,RE4MercScore,RE4MercMultiplier,RE4FeatureCount
};
const RE2FeatureInfo *RE4FeatureInfoAt(NSInteger feature);
