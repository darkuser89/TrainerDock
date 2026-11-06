// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,MTFeature){
    MTFeatureGodmode,MTFeatureNoManaCost,MTFeatureOneHitKill,MTFeatureEXPMultiplier,
    MTFeatureTownCoins,MTFeatureDungeonCoins,MTFeatureExperience,MTFeatureHealth,
    MTFeatureArmor,MTFeatureMight,MTFeatureAmount,MTFeatureArea,MTFeatureGrowth,
    MTFeatureGreed,MTFeatureLuck,MTFeatureRecovery,MTFeatureMana,MTFeatureHand,
    MTFeatureMagnet,MTFeatureDuration,MTFeatureRevivalCharge,MTFeatureRevivalStacks,
    MTFeatureCardSkips,MTFeatureRerolls,MTFeatureBanishes,MTFeatureCurse,MTFeatureCharm,
    MTFeatureCount
};
typedef struct {
    __unsafe_unretained NSString *title,*shortcut,*detail;
    BOOL implemented,numeric,oneShot,integer;
    double initial,minimum,maximum,step;
    unsigned short key;
    NSUInteger modifiers;
} MTFeatureInfo;
#ifdef __cplusplus
extern "C" {
#endif
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature);
#ifdef __cplusplus
}
#endif
@interface MTFeatureState : NSObject
@property(nonatomic) BOOL available,wanted,active;
@property(nonatomic) double value;
@property(nonatomic,copy) NSString *note;
@end
