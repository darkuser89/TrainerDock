// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Unbegrenztes Geld",@"F1",@"Hält das Guthaben des aktuellen Spielers gefüllt. Bereits ausgegebene Beträge werden nicht zurückgebucht.",YES,NO,NO,NO,0,0,0,0,122,0},
    {@"Unbegrenzte Fähigkeitspunkte",@"F2",@"Hält freie Punkte in den vorhandenen Fähigkeitskategorien bereit. Vorteile werden weiterhin im Spiel ausgewählt.",YES,NO,NO,NO,0,0,0,0,120,0}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
