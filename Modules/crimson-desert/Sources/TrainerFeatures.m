// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
// These six entries are UI examples. Real effects exist only in a verified adapter.
_Static_assert(MTFeatureCapacity>0 && MTFeatureCapacity<=26,"Overlay supports 1 through 26 catalog entries.");
static const MTFeatureInfo catalog[6]={
 {@"Gesundheit",@"F1",@"Demo: Gesundheit simulieren. Im Spiel nur mit passender Adapter-Anbindung.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Ausdauer",@"F2",@"Demo: Ausdauer simulieren; keine universelle Speicheradresse.",YES,NO,NO,NO,0,0,0,0,120,0},
 {@"Munition",@"F3",@"Demo: Munition simulieren. Besitzer/Handler im Spiel separat prüfen.",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Bewegung ×",@"F4",@"Demo: eigener Faktor mit Wiederherstellung des Ursprungswerts.",YES,YES,NO,NO,2,0.25,4,0.25,118,0},
 {@"Geld setzen",@"F5",@"Demo: Zielbetrag einmal setzen. Echte Geldgaben können gespeichert werden.",YES,YES,YES,YES,1000,0,999999999,1000,96,0},
 {@"Ressourcen +100",@"F6",@"Demo: einmalige simulierte Gabe; wird nach Kontextwechsel verworfen.",YES,NO,YES,NO,0,0,0,0,97,0}
};
static const MTFeatureInfo crimson[MTFeatureCapacity]={
 {@"Unbegrenztes Leben",@"F1",@"Eigener nativer Lebens-Buff verhindert den Verbrauch von Leben.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Max. Leben",@"F2",@"Setzt den maximalen Lebenswert; Ausschalten entfernt nur den eigenen Zusatz.",YES,YES,NO,YES,2000,1,10000,100,120,0},
 {@"Unbegrenzte Ausdauer",@"F3",@"Verhindert Ausdauerverbrauch der lokalen Spielfigur.",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Max. Ausdauer",@"F4",@"Maximalwert mit Rückleseprüfung und Rücknahme des eigenen Zusatzes.",YES,YES,NO,YES,500,1,10000,50,118,0},
 {@"Unbegrenzter Geist",@"F5",@"Verhindert Geistverbrauch der lokalen Spielfigur.",YES,NO,NO,NO,0,0,0,0,96,0},
 {@"Max. Geist",@"F6",@"Maximalwert mit Rückleseprüfung und Rücknahme des eigenen Zusatzes.",YES,YES,NO,YES,200,1,10000,10,97,0},
 {@"Verteidigung",@"F7",@"Setzt den Verteidigungswert; fremde Modifikatoren bleiben erhalten.",YES,YES,NO,YES,999,0,10000,10,98,0},
 {@"Gewählten Stapel setzen",@"F8",@"Inventar öffnen und einen Stapel auswählen. Native Inventartransaktion; kann gespeichert werden.",YES,YES,YES,YES,99,1,10000000,1,100,0},
 {@"Spieltempo ×",@"F9",@"Nativer Spielzeitfaktor; beim Ausschalten den übernommenen Faktor zurückgeben.",YES,YES,NO,NO,2.5,0.25,4,0.25,101,0},
 {@"Superschaden",@"F10",@"Setzt den Angriffswert auf 10.000; normale Gegner im Kampftest mit einem Schlag besiegt.",YES,NO,NO,NO,0,0,0,0,109,0},
 {@"Tageszeit anhalten",@"F11",@"Hält die aktuelle Feldzeit an; Ausschalten stellt deren Geschwindigkeit wieder her.",YES,NO,NO,NO,0,0,0,0,103,0},
 {@"Tageszeit +1 Stunde",@"F12",@"Einmalig eine Spielstunde weiterstellen; nie automatisch ausführen.",YES,NO,YES,NO,0,0,0,0,111,0},
 {@"Geld ×0,01",@"⌘F8",@"100 entspricht 1,00 im Spiel. Eindeutig ermittelten Geldstapel mit einer nativen Inventartransaktion setzen. Kann gespeichert werden.",YES,YES,YES,YES,1000,1,10000000,100,100,NSEventModifierFlagCommand}
};
static const MTFeatureInfo *selected=catalog;
void MTUseCrimsonFeatures(void) {selected=crimson;}
void MTUseDemoFeatures(void) {selected=catalog;}
NSInteger MTActiveFeatureCount(void) {return selected==crimson ? MTFeatureCapacity : 6;}
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature) { return feature>=0 && feature<MTFeatureCount ? &selected[feature] : NULL; }
@implementation MTFeatureState
@end
