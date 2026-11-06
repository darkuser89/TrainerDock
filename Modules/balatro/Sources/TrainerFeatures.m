// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
 {@"Unlimited Money",@"F1",@"Hält das Geld bei mindestens 9.999.999. Eigene Anhebung wird beim Ausschalten gelöst.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Unlimited Round Score",@"F2",@"Setzt jede ausgewertete Hand auf mindestens 1 Billion Punkte; echte Schlusswertung vor der Addition zu den Rundenchips.",YES,NO,NO,NO,0,0,0,0,120,0},
 {@"Unlimited Hands",@"F3",@"Füllt verbrauchte Hände auf den Vorrat beim Aktivieren auf (mindestens eine).",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Unlimited Discards",@"F4",@"Füllt verbrauchte Abwürfe auf den Vorrat beim Aktivieren auf (mindestens einen).",YES,NO,NO,NO,0,0,0,0,118,0},
 {@"Game Speed",@"F5",@"Multiplikator für den tatsächlichen love.update-Zeitschritt. Spiel-Einstellungen bleiben unangetastet.",YES,YES,NO,NO,2,0.1,10,0.1,96,0},
 {@"Edit: Money",@"⇧F1",@"Setzt den Geldbetrag einmalig. Unlimited Money gegebenenfalls vorher ausschalten.",YES,YES,YES,YES,1000,0,1000000000,100,122,NSEventModifierFlagShift},
 {@"Edit: Total Score",@"⇧F2",@"Setzt G.GAME.chips: die gesammelten Chips der aktuellen Runde.",YES,YES,YES,YES,100000,0,1000000000000000,1000,120,NSEventModifierFlagShift},
 {@"Edit: Round Score",@"⇧F3",@"Merkt das Ergebnis für die nächste ausgewertete Hand vor. Wird bei Runden-/Besitzerwechsel verworfen. Vorrang vor Unlimited Round Score.",YES,YES,YES,YES,10000,0,1000000000000000,100,99,NSEventModifierFlagShift},
 {@"Edit: Hands Left",@"⇧F4",@"Setzt die verbleibenden Hände der aktuellen Runde einmalig (0–99).",YES,YES,YES,YES,10,0,99,1,118,NSEventModifierFlagShift},
 {@"Edit: Discards Left",@"⇧F5",@"Setzt die verbleibenden Abwürfe der aktuellen Runde einmalig (0–99).",YES,YES,YES,YES,10,0,99,1,96,NSEventModifierFlagShift}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
