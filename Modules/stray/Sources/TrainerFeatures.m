// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Unverwundbar / Treffer ignorieren",@"F1",@"Verhindert Trefferreaktionen der gesteuerten Katze.",YES,NO,NO,NO,0,0,0,0,122,0},
    {@"Unbegrenzte Gesundheit",@"F2",@"Hält die Gesundheit der gesteuerten Katze am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,120,0},
    {@"Unsichtbar für Zurks (WIP)",@"F3",@"WIP · Deaktiviert: Zurks greifen trotz abgeschalteter Sinne weiterhin an.",NO,NO,NO,NO,0,0,0,0,99,0},
    {@"Unsichtbar für Sentinels (WIP)",@"F4",@"WIP · Deaktiviert: Wirkung im Spiel noch nicht bestätigt.",NO,NO,NO,NO,0,0,0,0,118,0},
    {@"Sentinels greifen nicht an (WIP)",@"F5",@"WIP · Deaktiviert: Verhindern von Angriffen im Spiel noch nicht bestätigt.",NO,NO,NO,NO,0,0,0,0,96,0},
    {@"Defluxor ohne Überhitzung",@"F6",@"Verhindert die Überhitzung des vorhandenen Defluxors.",YES,NO,NO,NO,0,0,0,0,97,0},
    {@"Bewegungsgeschwindigkeit (WIP)",@"F7",@"WIP · Deaktiviert: korrigierter Bewegungsfaktor noch nicht im Spiel geprüft.",NO,YES,NO,NO,2,0.25,10,0.25,98,0},
    {@"Spielgeschwindigkeit",@"F8",@"Verändert das Tempo der lokalen Spielwelt.",YES,YES,NO,NO,2.5,0.1,5,0.1,100,0}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
