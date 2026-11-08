// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
 {@"Unbegrenztes Geld",@"F1",@"Hält das Geld bei mindestens 9.999.999. Eigene Anhebung wird beim Ausschalten gelöst.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Unbegrenzte Handwertung",@"F2",@"Setzt jede ausgewertete Hand auf mindestens 1 Billion Punkte; echte Schlusswertung vor der Addition zu den Rundenchips.",YES,NO,NO,NO,0,0,0,0,120,0},
 {@"Unbegrenzte Hände",@"F3",@"Füllt verbrauchte Hände auf den Vorrat beim Aktivieren auf (mindestens eine).",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Unbegrenzte Abwürfe",@"F4",@"Füllt verbrauchte Abwürfe auf den Vorrat beim Aktivieren auf (mindestens einen).",YES,NO,NO,NO,0,0,0,0,118,0},
 {@"Spielgeschwindigkeit",@"F5",@"Multiplikator für den tatsächlichen love.update-Zeitschritt. Spiel-Einstellungen bleiben unangetastet.",YES,YES,NO,NO,2,0.1,10,0.1,96,0},
 {@"Geld einstellen",@"⇧F1",@"Setzt den Geldbetrag einmalig. Unbegrenztes Geld gegebenenfalls vorher ausschalten.",YES,YES,YES,YES,1000,0,1000000000,100,122,NSEventModifierFlagShift},
 {@"Rundenchips einstellen",@"⇧F2",@"Setzt die gesammelten Chips der aktuellen Runde.",YES,YES,YES,YES,100000,0,1000000000000000,1000,120,NSEventModifierFlagShift},
 {@"Handwertung einstellen",@"⇧F3",@"Merkt das Ergebnis für die nächste ausgewertete Hand vor. Wird bei Runden-/Besitzerwechsel verworfen. Vorrang vor Unbegrenzte Handwertung.",YES,YES,YES,YES,10000,0,1000000000000000,100,99,NSEventModifierFlagShift},
 {@"Verbleibende Hände einstellen",@"⇧F4",@"Setzt die verbleibenden Hände der aktuellen Runde einmalig (0–99).",YES,YES,YES,YES,10,0,99,1,118,NSEventModifierFlagShift},
 {@"Verbleibende Abwürfe einstellen",@"⇧F5",@"Setzt die verbleibenden Abwürfe der aktuellen Runde einmalig (0–99).",YES,YES,YES,YES,10,0,99,1,96,NSEventModifierFlagShift}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
