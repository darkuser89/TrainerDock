// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Godmode / No Hit",@"F1",@"Native permanente Unverwundbarkeit des lokalen Spielers.",YES,NO,NO,NO,0,0,0,0,122,0},
    {@"Super Movement Speed",@"F2",@"Dreifache lokale Bewegungsgeschwindigkeit.",YES,NO,NO,NO,0,0,0,0,120,0},
    {@"Super Damage",@"F3",@"Zehnfacher Machtwert; native Schadensgrenzen gelten.",YES,NO,NO,NO,0,0,0,0,99,0},
    {@"Super Attack Radius",@"F4",@"Vierfacher Flächenwert; native Waffengrenzen gelten.",YES,NO,NO,NO,0,0,0,0,118,0},
    {@"Super Attack Speed",@"F5",@"Native Abklingzeit auf 10 %; Engine-Untergrenzen bleiben erhalten.",YES,NO,NO,NO,0,0,0,0,96,0},
    {@"Mega EXP",@"F6",@"Hundertfaches Wachstum beim Sammeln von Erfahrung.",YES,NO,NO,NO,0,0,0,0,97,0},
    {@"EXP Multiplier",@"F7",@"Multipliziert den lokalen Wachstumswert und damit gesammelte Erfahrung.",YES,YES,NO,NO,2,1,100,0.5,98,0},
    {@"Movement Speed Multiplier",@"F8",@"Multipliziert nur die Bewegung des lokalen Spielers.",YES,YES,NO,NO,2,1,100,0.5,100,0},
    {@"Damage Multiplier",@"F9",@"Multipliziert den lokalen Machtwert; native Schadensgrenzen gelten.",YES,YES,NO,NO,2,1,100,0.5,101,0},
    {@"Edit: EXP",@"F10",@"Setzt die aktuell angesammelte Erfahrung einmalig.",YES,YES,YES,NO,1000,0,1000000000,100,109,0},
    {@"Edit: Growth",@"F11",@"Setzt den natürlichen Wachstumswert einmalig; aktive Faktoren wirken zusätzlich.",YES,YES,YES,NO,1,0,1000000000,0.1,103,0},
    {@"Edit: Luck",@"F12",@"Setzt den lokalen Glückswert einmalig.",YES,YES,YES,NO,1,0,1000000000,0.1,111,0},
    {@"Edit: Revivals",@"⇧F1",@"Setzt verbleibende Wiederbelebungen einmalig.",YES,YES,YES,YES,5,0,9999,1,122,1},
    {@"Edit: Rerolls",@"⇧F2",@"Setzt den lokalen Reroll-Wert einmalig.",YES,YES,YES,YES,5,0,9999,1,120,1},
    {@"Edit: Coins",@"⇧F3",@"Setzt verfügbares Münzguthaben. Kann vom Spiel gespeichert werden.",YES,YES,YES,NO,1000,0,1000000000,100,99,1},
    {@"Edit: Coins Collected",@"⇧F4",@"Setzt den gesammelten Münzwert der laufenden Runde (RunCoins).",YES,YES,YES,NO,1000,0,1000000000,100,118,1},
    {@"Edit: Enemies Killed",@"⇧F5",@"Setzt den Gegnerzähler der laufenden Runde.",YES,YES,YES,YES,1000,0,1000000000,100,96,1},
    {@"Edit: Lifetime Coins",@"⇧F6",@"Setzt den nativen LifetimeCoins-Zähler. Kann gespeichert werden.",YES,YES,YES,NO,1000,0,1000000000,100,97,1},
    {@"Edit: Total Coins",@"⇧F7",@"Setzt den nativen TotalCoins-Zähler. Kann gespeichert werden.",YES,YES,YES,NO,1000,0,1000000000,100,98,1}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature f){return f>=0&&f<MTFeatureCount?&catalog[f]:NULL;}
@implementation MTFeatureState @end
