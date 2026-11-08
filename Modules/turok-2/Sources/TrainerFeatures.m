// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Unbegrenzte Gesundheit",@"F1",@"Verwendet die originale Unverwundbarkeit der eigenen Spielfigur.",YES,NO,NO,NO,0,0,0,0,122,0},
    {@"Unbegrenzte Munition",@"F2",@"Verhindert den Verbrauch vorhandener Munition über den originalen Spielzustand.",YES,NO,NO,NO,0,0,0,0,120,0},
    {@"Nebel entfernen",@"F3",@"Entfernt den Renderer-Nebel; die originale Geometriesichtweite bleibt erhalten.",YES,NO,NO,NO,0,0,0,0,99,0}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
