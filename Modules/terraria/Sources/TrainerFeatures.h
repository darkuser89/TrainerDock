// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger,MTFeature){MTFeatureGod,MTFeatureHealth,MTFeatureMana,MTFeatureBreath,MTFeatureFlight,MTFeatureGhost,MTFeatureItems,MTFeatureLight,MTFeatureRecipes,MTFeatureDamage,MTFeatureTime,MTFeatureSpeed,MTFeatureCount};
typedef struct {
    __unsafe_unretained NSString *title,*shortcut,*detail;
    BOOL implemented,numeric,oneShot,integer;
    double initial,minimum,maximum,step;
    unsigned short key;
    NSUInteger modifiers;
} MTFeatureInfo;
FOUNDATION_EXPORT const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature);
@interface MTFeatureState : NSObject
@property(nonatomic) BOOL available,wanted,active;
@property(nonatomic) double value;
@property(nonatomic,copy) NSString *note;
@end
