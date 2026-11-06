// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
typedef NS_ENUM(NSInteger,RE8Feature){RE8God,RE8Health,RE8Ammo,RE8NoReload,RE8Rapid,RE8Recoil,RE8Items,RE8Craft,RE8GameSpeed,RE8OneHit,RE8Damage,RE8Highlight,RE8Time,RE8Cooking,RE8PlayerSpeed,RE8Money,RE8MoneyMultiplier,RE8CP,RE8Unlock,RE8MercTime,RE8MercScore,RE8MercMultiplier,RE8MercGoal,RE8FeatureCount};
const RE2FeatureInfo *RE8FeatureInfoAt(NSInteger feature);
