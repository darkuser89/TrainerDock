// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Native Anbindung fehlt",@"",@"Entwicklungsvorlage: keine Trainerfunktion implementiert.",NO,NO,NO,NO,0,0,0,0,0,0}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
