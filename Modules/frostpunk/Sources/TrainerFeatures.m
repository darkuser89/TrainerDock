// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Kohle hinzufügen",@"F1",@"Fügt einmal die eingestellte Menge Kohle zum aktuellen Bestand hinzu. Die originalen Lagergrenzen gelten weiter.",YES,YES,YES,YES,1000,1,1000000,100,122,0},
    {@"Holz hinzufügen",@"F2",@"Fügt einmal die eingestellte Menge Holz zum aktuellen Bestand hinzu. Die originalen Lagergrenzen gelten weiter.",YES,YES,YES,YES,1000,1,1000000,100,120,0},
    {@"Stahl hinzufügen",@"F3",@"Fügt einmal die eingestellte Menge Stahl zum aktuellen Bestand hinzu. Die originalen Lagergrenzen gelten weiter.",YES,YES,YES,YES,1000,1,1000000,100,99,0},
    {@"Dampfkerne hinzufügen",@"F4",@"Fügt einmal die eingestellte Zahl Dampfkerne zum aktuellen Bestand hinzu. Die originalen Lagergrenzen gelten weiter.",YES,YES,YES,YES,10,1,10000,1,118,0},
    {@"Rohkost hinzufügen",@"F5",@"Fügt einmal die eingestellte Menge Rohkost zum aktuellen Bestand hinzu. Die originalen Lagergrenzen gelten weiter.",YES,YES,YES,YES,1000,1,1000000,100,96,0},
    {@"Prothesen hinzufügen",@"F6",@"Fügt einmal die eingestellte Zahl Prothesen zum nativen Bestand hinzu. Sichtbarkeit und Nutzung richten sich nach dem Spielkontext.",YES,YES,YES,YES,1000,1,1000000,10,97,0},
    {@"Unbegrenztes Lager",@"F7",@"Erweitert die identifizierten Ressourcenlager auf mindestens 1.000.000. Eigene Erweiterungen werden beim Ausschalten zurückgenommen; fremde Änderungen bleiben erhalten.",YES,NO,NO,NO,0,0,0,0,98,0},
    {@"Strukturprofile hinzufügen",@"⌥F5",@"Fügt einmal Strukturprofile zum nativen Bestand hinzu. Ein ausgeblendeter Rohstoff bleibt ausgeblendet; Szenario und Freischaltungen bestimmen Anzeige und Nutzung.",YES,YES,YES,YES,1000,1,1000000,100,96,NSEventModifierFlagOption},
    {@"Stahlverbundstoffe hinzufügen",@"⌥F6",@"Fügt einmal Stahlverbundstoffe zum nativen Bestand hinzu. Ein ausgeblendeter Rohstoff bleibt ausgeblendet; Szenario und Freischaltungen bestimmen Anzeige und Nutzung.",YES,YES,YES,YES,1000,1,1000000,100,97,NSEventModifierFlagOption},
    {@"Dampftauscher hinzufügen",@"⌥F7",@"Fügt einmal Dampftauscher zum nativen Bestand hinzu. Ein ausgeblendeter Rohstoff bleibt ausgeblendet; Szenario und Freischaltungen bestimmen Anzeige und Nutzung.",YES,YES,YES,YES,1000,1,1000000,100,98,NSEventModifierFlagOption},
    {@"Sofort bauen",@"⌃F1",@"Verwendet den originalen Sofortbau-Schalter für Bau- und Abrissarbeiten. Kosten und Freischaltungen bleiben erforderlich.",YES,NO,NO,NO,0,0,0,0,122,NSEventModifierFlagControl},
    {@"Sofort forschen",@"⌃F2",@"Schließt laufende Forschung über den originalen Sofortforschungs-Schalter ab, sobald die Forschung im Spiel aktualisiert wird. Kosten und Freischaltungen bleiben erforderlich.",YES,NO,NO,NO,0,0,0,0,120,NSEventModifierFlagControl},
    {@"Gesetze ohne Wartezeit",@"⌃F3",@"Setzt die verbleibende Gesetzeswartezeit auf null. Gesetzesvoraussetzungen gelten weiter; bereits abgelaufene Wartezeit wird beim Ausschalten nicht wiederhergestellt.",YES,NO,NO,NO,0,0,0,0,99,NSEventModifierFlagControl},
    {@"Kein Generatorstress",@"⌃F4",@"Hält den vorhandenen Generator über die originale Stresssteuerung bei null. Beim Ausschalten endet die weitere Stresssenkung; abgebauter Stress bleibt abgebaut.",YES,NO,NO,NO,0,0,0,0,118,NSEventModifierFlagControl},
    {@"Spielgeschwindigkeit",@"⌃F5",@"Setzt den Faktor des originalen Spieltimers. Beim Ausschalten wird die eigene Timeränderung zurückgenommen; fremde Änderungen bleiben erhalten.",YES,YES,NO,NO,2.5,0.1,5,0.1,96,NSEventModifierFlagControl}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
