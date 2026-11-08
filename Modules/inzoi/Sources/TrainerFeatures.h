// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#define MT_GLASS_ALWAYS_ON 1
// Stable feature IDs shared by the module catalog, bridge and native adapter.
typedef NS_ENUM(NSInteger,MTFeature){MTFeatureHunger,MTFeatureHygiene,MTFeatureSleep,MTFeatureBathroom,MTFeatureFun,MTFeatureSocial,MTFeatureRecognition,MTFeatureEnergy,MTFeatureNeedsRate,MTFeatureKarma,MTFeatureKarmaRate,MTFeatureAmbitions,MTFeatureMoney,MTFeatureMoneyRate,MTFeatureMeow,MTFeatureMeowRate,MTFeatureSkill,MTFeatureSkillRate,MTFeaturePlayerSpeed,MTFeatureGameSpeed,MTFeatureCount};
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
