// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
// Stable IDs: resource actions must never be restored as continuous effects.
typedef NS_ENUM(NSInteger,MTFeature){
    MTFeatureCoal, MTFeatureWood, MTFeatureSteel, MTFeatureSteamCores,
    MTFeatureRawFood, MTFeatureProstheses, MTFeatureStorage,
    MTFeatureStructuralProfiles, MTFeatureSteelComposites, MTFeatureSteamExchangers,
    MTFeatureInstantBuild, MTFeatureInstantResearch, MTFeatureLawCooldown,
    MTFeatureGeneratorStress, MTFeatureGameSpeed, MTFeatureCount
};
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
