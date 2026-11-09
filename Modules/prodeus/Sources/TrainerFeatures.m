// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Unbegrenzte Gesundheit",@"F1",@"Hält die Gesundheit des lokalen Spielers im Einzelspieler gefüllt.",YES,NO,NO,NO,0,0,0,0,122,0},
    {@"Unbegrenzte Rüstung",@"F2",@"Hält die Rüstung des lokalen Spielers im Einzelspieler gefüllt.",YES,NO,NO,NO,0,0,0,0,120,0},
    {@"Unbegrenzte Sprünge",@"F3",@"Erlaubt weitere Sprünge in der Luft.",YES,NO,NO,NO,0,0,0,0,99,0},
    {@"Roten Schlüssel geben",@"F4",@"Gibt dem lokalen Spieler einmal den roten Schlüssel.",YES,NO,YES,NO,0,0,0,0,118,0},
    {@"Grünen Schlüssel geben",@"F5",@"Gibt dem lokalen Spieler einmal den grünen Schlüssel.",YES,NO,YES,NO,0,0,0,0,96,0},
    {@"Blauen Schlüssel geben",@"F6",@"Gibt dem lokalen Spieler einmal den blauen Schlüssel.",YES,NO,YES,NO,0,0,0,0,97,0},
    {@"Gelben Schlüssel geben",@"F7",@"Gibt dem lokalen Spieler einmal den gelben Schlüssel.",YES,NO,YES,NO,0,0,0,0,98,0},
    {@"Automatische Karte geben",@"F8",@"Schaltet die Karte für den aktuellen Einzelspieler frei.",YES,NO,YES,NO,0,0,0,0,100,0},
    {@"Doppelsprung geben",@"F9",@"Gibt dem lokalen Spieler die Doppelsprung-Fähigkeit.",YES,NO,YES,NO,0,0,0,0,101,0},
    {@"Sprintstoß geben",@"F10",@"Gibt dem lokalen Spieler die Dash-Fähigkeit.",YES,NO,YES,NO,0,0,0,0,109,0},
    {@"Unbegrenzte Munition",@"F11",@"Hält die Munition des lokalen Spielers gefüllt.",YES,NO,NO,NO,0,0,0,0,103,0},
    {@"Kein Nachladen",@"F12",@"Hält die geladene Munition der aktuellen Waffe bereit.",YES,NO,NO,NO,0,0,0,0,111,0},
    {@"Spielgeschwindigkeit",@"⇧F1",@"Verändert das lokale Spieltempo; stellt beim Ausschalten den eigenen Ausgangswert wieder her.",YES,YES,NO,NO,2,0.1,3,0.1,122,NSEventModifierFlagShift}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
