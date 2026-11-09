// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,MTFeature){
    MTFeatureGod,MTFeatureMoney,MTFeatureSellPrice,MTFeatureEquipment,
    MTFeatureHarvest,MTFeatureSpoil,MTFeatureInfection,MTFeatureNets,
    MTFeaturePots,MTFeatureResearch,MTFeatureUpgrades,MTFeatureMovement,
    MTFeatureGameSpeed,MTFeatureFreezeTime,MTFeatureTimeSpeed,MTFeatureCount
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
