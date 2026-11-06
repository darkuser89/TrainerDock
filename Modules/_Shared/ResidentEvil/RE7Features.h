// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
typedef NS_ENUM(NSInteger,RE7Feature){RE7Health,RE7Ammo,RE7NoReload,RE7Items,RE7Highlight,RE7SuperSpeed,RE7SlowMotion,RE7ResetTime,RE7PlayerSpeed,RE7OneHit,RE7Scraps,RE7Score,RE7Oxygen,RE7BirthdayTimer,RE7Always21,RE7FeatureCount};
const RE2FeatureInfo *RE7FeatureInfoAt(NSInteger feature);
