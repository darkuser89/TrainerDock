// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
static const MTFeatureInfo catalog[MTFeatureCount]={
 {@"Keine Trageverlangsamung",@"F1",@"Nur Ingenieur: setzt den nativen Geschwindigkeitsverlust pro getragenem Gegenstand auf 0.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Eisen setzen",@"F2",@"Setzt den lokalen Eisenbestand einmalig. Kann im Lauf gespeichert werden.",YES,YES,YES,YES,100,0,1000000,10,120,0},
 {@"Wasser setzen",@"F3",@"Setzt den lokalen Wasserbestand einmalig. Kann im Lauf gespeichert werden.",YES,YES,YES,YES,100,0,1000000,10,99,0},
 {@"Kobalt setzen",@"F4",@"Setzt den lokalen Kobaltbestand einmalig.",YES,YES,YES,YES,100,0,1000000,10,118,0},
 {@"Unbegrenzter Schild",@"F5",@"Füllt einen ausgerüsteten Schild laufend auf seine native Kapazität auf.",YES,NO,NO,NO,0,0,0,0,96,0},
 {@"Unbegrenzte Kuppelgesundheit",@"F6",@"Hält die native Schadensschutzzeit der lokalen Kuppel auf mindestens zwei Sekunden.",YES,NO,NO,NO,0,0,0,0,97,0},
 {@"Massiver Laserschaden",@"F7",@"Setzt den nativen Laserschadensfaktor auf 1000. Nur bei vorhandenem Laser.",YES,NO,NO,NO,0,0,0,0,98,0},
 {@"Massiver Bohrschaden",@"F8",@"Nur Ingenieur: setzt die native Bohrstärke auf 100000.",YES,NO,NO,NO,0,0,0,0,100,0},
 {@"Neue Monsterwellen anhalten",@"F9",@"Hält die native Wellenverzögerung auf mindestens zwei Sekunden. Aktive Monster bleiben.",YES,NO,NO,NO,0,0,0,0,101,0},
 {@"Spielgeschwindigkeit ×",@"F10",@"Nativer Godot-Zeitfaktor. Ausschalten stellt den übernommenen Faktor wieder her.",YES,YES,NO,NO,1,0.25,4,0.25,109,0},
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
