// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
// Native DREDGE implementations; exact original profile is bound by Module.json.
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Unverwundbarkeit",@"F1",@"Schützt das Boot vor Beschädigungen.",YES,NO,NO,NO,0,0,0,0,122,0},
    {@"Unbegrenztes Geld",@"F2",@"Hält dein verfügbares Geld auf einem hohen Mindestbetrag.",YES,NO,NO,NO,0,0,0,0,120,0},
    {@"Verkaufspreis-Faktor",@"F3",@"Erhöht den Verkaufspreis von Gegenständen um den eingestellten Faktor.",YES,YES,NO,NO,2,1,100,0.5,99,0},
    {@"Ausrüstungsanforderungen ignorieren",@"F4",@"Erlaubt das Fangen und Bergen unabhängig von den erforderlichen Ausrüstungstypen.",YES,NO,NO,NO,0,0,0,0,118,0},
    {@"Sofort fangen und bergen",@"F5",@"Verkürzt einen laufenden Fang- oder Bergevorgang.",YES,NO,NO,NO,0,0,0,0,96,0},
    {@"Fisch verdirbt nicht",@"F6",@"Verhindert das Altern der vorhandenen Fische im Boot.",YES,NO,NO,NO,0,0,0,0,97,0},
    {@"Keine Fischinfektionen",@"F7",@"Schützt vorhandene Fische im Boot vor Infektionen.",YES,NO,NO,NO,0,0,0,0,98,0},
    {@"Unbegrenzte Netzhaltbarkeit",@"F8",@"Hält die Haltbarkeit des ausgerüsteten Schleppnetzes aufrecht.",YES,NO,NO,NO,0,0,0,0,100,0},
    {@"Unbegrenzte Reusenhaltbarkeit",@"F9",@"Hält die Haltbarkeit deiner geladenen Reusen aufrecht.",YES,NO,NO,NO,0,0,0,0,101,0},
    {@"Unbegrenzte Forschungsteile",@"F10",@"Ergänzt bei Bedarf ein echtes Forschungsteil im Lager; freier Platz ist nötig.",YES,NO,NO,NO,0,0,0,0,109,0},
    {@"Aufwertungskosten ignorieren",@"F11",@"Setzt Geld- und Materialkosten vorhandener Aufwertungen auf null. Vorgänger-, DLC-, Rumpf- und Platzprüfungen bleiben erhalten.",YES,NO,NO,NO,0,0,0,0,103,0},
    {@"Bootsgeschwindigkeit ×",@"⌃ F1",@"Ändert die Bewegungsgeschwindigkeit des Boots.",YES,YES,NO,NO,2,0.25,10,0.25,122,262144},
    {@"Spielgeschwindigkeit ×",@"⌃ F2",@"Ändert die Geschwindigkeit des gesamten Spiels.",YES,YES,NO,NO,2,0.1,5,0.1,120,262144},
    {@"Zeit einfrieren",@"⌃ F3",@"Hält die Spieluhr an, ohne das gesamte Spiel anzuhalten.",YES,NO,NO,NO,0,0,0,0,99,262144},
    {@"Zeitablauf ×",@"⌃ F4",@"Ändert die Geschwindigkeit der Spieluhr; Zeit einfrieren hat Vorrang.",YES,YES,NO,NO,0.5,0.1,10,0.1,118,262144},
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
