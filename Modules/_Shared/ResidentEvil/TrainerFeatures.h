// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, RE2Feature) {
 RE2FeatureHealth, RE2FeatureAmmo, RE2FeatureNoReload, RE2FeatureRibbons,
 RE2FeatureAccuracy, RE2FeatureRecoil, RE2FeatureSlowMotion, RE2FeatureOneHit,
 RE2FeatureBackpack, RE2FeatureGameTime, RE2FeatureSaveCount, RE2FeatureCountdown,
 RE2FeatureItemBoxCount, RE2FeatureHealingCount, RE2FeatureSteps,
 RE2FeatureKnife, RE2FeatureSpeed, RE2FeatureTyrant, RE2FeatureHighlight, RE2FeatureBoards, RE2FeaturePortableSafe,
 RE2FeatureCount
};
typedef struct {
    __unsafe_unretained NSString *title, *shortcut, *detail;
    BOOL implemented, numeric, oneShot, integer;
    double initial, minimum, maximum, step;
    unsigned short key;
    NSUInteger modifiers;
} RE2FeatureInfo;
// Slot aliases let both games retain independent catalogs and the same UI size.
enum { RE3FeatureInvulnerable=RE2FeatureRibbons, RE3FeatureDeathCount=RE2FeatureCountdown,
       RE3FeatureAllRecords=RE2FeatureSteps, RE3FeatureTotalTime=RE2FeatureKnife, RE3FeatureShopPoints=RE2FeatureBoards };
BOOL RE2IsRE3Game(void);
BOOL RE2IsRE4Game(void);
BOOL RE2IsRE7Game(void);
BOOL RE2IsRE8Game(void);
enum { RE2FeatureCapacity=36, RE3FeatureCount=RE2FeaturePortableSafe };
NSInteger RE2ActiveFeatureCount(void);
NSString *RE2GameShortName(void);
NSString *RE2GameVersionLabel(void);
const RE2FeatureInfo *RE2FeatureInfoForGame(RE2Feature feature, BOOL re3);
const RE2FeatureInfo *RE2FeatureInfoAt(RE2Feature feature);
@interface RE2FeatureState : NSObject
@property(nonatomic) BOOL available, wanted, active;
@property(nonatomic) double value;
@property(nonatomic,copy) NSString *note;
@end
