// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Unverwundbarkeit",@"F1",@"Native permanente Unverwundbarkeit des lokalen Spielers.",YES,NO,NO,NO,0,0,0,0,122,0},
    {@"Dreifache Bewegungsgeschwindigkeit",@"F2",@"Dreifache lokale Bewegungsgeschwindigkeit.",YES,NO,NO,NO,0,0,0,0,120,0},
    {@"Extremer Schaden",@"F3",@"Zehnfacher Machtwert; native Schadensgrenzen gelten.",YES,NO,NO,NO,0,0,0,0,99,0},
    {@"Vergrößerter Angriffsradius",@"F4",@"Vierfacher Flächenwert; native Waffengrenzen gelten.",YES,NO,NO,NO,0,0,0,0,118,0},
    {@"Erhöhte Angriffsgeschwindigkeit",@"F5",@"Native Abklingzeit auf 10 %; Engine-Untergrenzen bleiben erhalten.",YES,NO,NO,NO,0,0,0,0,96,0},
    {@"Hundertfache Erfahrung",@"F6",@"Hundertfaches Wachstum beim Sammeln von Erfahrung.",YES,NO,NO,NO,0,0,0,0,97,0},
    {@"EP-Multiplikator",@"F7",@"Multipliziert den lokalen Wachstumswert und damit gesammelte Erfahrung.",YES,YES,NO,NO,2,1,100,0.5,98,0},
    {@"Bewegungsgeschwindigkeitsfaktor",@"F8",@"Multipliziert nur die Bewegung des lokalen Spielers.",YES,YES,NO,NO,2,1,100,0.5,100,0},
    {@"Schadensmultiplikator",@"F9",@"Multipliziert den lokalen Machtwert; native Schadensgrenzen gelten.",YES,YES,NO,NO,2,1,100,0.5,101,0},
    {@"Erfahrung einstellen",@"F10",@"Setzt die aktuell angesammelte Erfahrung einmalig.",YES,YES,YES,NO,1000,0,1000000000,100,109,0},
    {@"Wachstum einstellen",@"F11",@"Setzt den natürlichen Wachstumswert einmalig; aktive Faktoren wirken zusätzlich.",YES,YES,YES,NO,1,0,1000000000,0.1,103,0},
    {@"Glück einstellen",@"F12",@"Setzt den lokalen Glückswert einmalig.",YES,YES,YES,NO,1,0,1000000000,0.1,111,0},
    {@"Wiederbelebungen einstellen",@"⇧F1",@"Setzt verbleibende Wiederbelebungen einmalig.",YES,YES,YES,YES,5,0,9999,1,122,1},
    {@"Neuauswahlen einstellen",@"⇧F2",@"Setzt die Anzahl der lokalen Neuauswahlen einmalig.",YES,YES,YES,YES,5,0,9999,1,120,1},
    {@"Münzguthaben einstellen",@"⇧F3",@"Setzt verfügbares Münzguthaben. Kann vom Spiel gespeichert werden.",YES,YES,YES,NO,1000,0,1000000000,100,99,1},
    {@"Rundenmünzen einstellen",@"⇧F4",@"Setzt den gesammelten Münzwert der laufenden Runde.",YES,YES,YES,NO,1000,0,1000000000,100,118,1},
    {@"Besiegte Gegner einstellen",@"⇧F5",@"Setzt den Gegnerzähler der laufenden Runde.",YES,YES,YES,YES,1000,0,1000000000,100,96,1},
    {@"Lebenszeitmünzen einstellen",@"⇧F6",@"Setzt den ursprünglichen Lebenszeit-Münzzähler. Kann gespeichert werden.",YES,YES,YES,NO,1000,0,1000000000,100,97,1},
    {@"Gesamtmünzen einstellen",@"⇧F7",@"Setzt den ursprünglichen Gesamtmünzzähler. Kann gespeichert werden.",YES,YES,YES,NO,1000,0,1000000000,100,98,1}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature f){return f>=0&&f<MTFeatureCount?&catalog[f]:NULL;}
@implementation MTFeatureState @end
