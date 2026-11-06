// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, MTFeature) { MTFeatureHealth, MTFeatureStamina, MTFeatureAmmo, MTFeatureSpeed, MTFeatureMoney, MTFeatureResources, MTFeatureCapacity=13 };
NSInteger MTActiveFeatureCount(void);
#define MTFeatureCount (MTActiveFeatureCount())
typedef struct {
    __unsafe_unretained NSString *title, *shortcut, *detail;
    BOOL implemented, numeric, oneShot, integer;
    double initial, minimum, maximum, step;
    unsigned short key;
    NSUInteger modifiers;
} MTFeatureInfo;
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature);
void MTUseCrimsonFeatures(void);
void MTUseDemoFeatures(void);
@interface MTFeatureState : NSObject
@property(nonatomic) BOOL available, wanted, active;
@property(nonatomic) double value;
@property(nonatomic,copy) NSString *note;
@end
