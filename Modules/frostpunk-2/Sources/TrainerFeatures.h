// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
// Stable feature identifiers shared by the native backend and module metadata.
typedef NS_ENUM(NSInteger,MTFeature){MTFeatureHeatstamps,MTFeaturePrefabs,MTFeatureCores,MTFeatureCoal,MTFeatureOil,MTFeatureFood,MTFeatureMaterials,MTFeatureGoods,MTFeatureScraps,MTFeatureGeneratorWear,MTFeaturePopulation,MTFeatureRelations,MTFeatureConstruction,MTFeatureExpansion,MTFeatureDemolish,MTFeatureResearch,MTFeatureExpedition,MTFeatureCouncil,MTFeatureLaws,MTFeatureSpeed,MTFeatureTension,MTFeatureHunger,MTFeatureDisease,MTFeatureCold,MTFeatureSqualor,MTFeatureCrime,MTFeaturePopulationAll,MTFeatureCount};
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
