// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Heizmarken bearbeiten",@"F1",@"Setzt den Bestand einmalig über die originale Ressourcenverwaltung.",YES,YES,YES,YES,10000,0,100000000,1,kVK_F1,0},
    {@"Fertigteile bearbeiten",@"F2",@"Setzt den Bestand einmalig über die originale Ressourcenverwaltung.",YES,YES,YES,YES,10000,0,100000000,1,kVK_F2,0},
    {@"Kerne bearbeiten",@"F3",@"Setzt den Bestand einmalig über die originale Ressourcenverwaltung.",YES,YES,YES,YES,10000,0,100000000,1,kVK_F3,0},
    {@"Kohlevorrat bearbeiten",@"F4",@"Setzt den Bestand einmalig über die originale Ressourcenverwaltung.",YES,YES,YES,YES,10000,0,100000000,1,kVK_F4,0},
    {@"Ölvorrat bearbeiten",@"F5",@"Setzt den Bestand einmalig über die originale Ressourcenverwaltung.",YES,YES,YES,YES,10000,0,100000000,1,kVK_F5,0},
    {@"Nahrungsvorrat bearbeiten",@"F6",@"Setzt den Bestand einmalig über die originale Ressourcenverwaltung.",YES,YES,YES,YES,10000,0,100000000,1,kVK_F6,0},
    {@"Materialvorrat bearbeiten",@"F7",@"Setzt den Bestand einmalig über die originale Ressourcenverwaltung.",YES,YES,YES,YES,10000,0,100000000,1,kVK_F7,0},
    {@"Warenlager bearbeiten",@"F8",@"Setzt den Bestand einmalig über die originale Ressourcenverwaltung.",YES,YES,YES,YES,10000,0,100000000,1,kVK_F8,0},
    {@"Schrott bearbeiten",@"F9",@"Setzt den Bestand einmalig über die originale Ressourcenverwaltung.",YES,YES,YES,YES,10000,0,100000000,1,kVK_F9,0},
    {@"Kein Generatorverschleiß",@"F10",@"Erhält den Verschleiß des Generators auf der nativen Untergrenze.",YES,NO,NO,YES,0,0,100000000,1,kVK_F10,0},
    {@"Bevölkerung: ausgewählte Gemeinschaft/Fraktion",@"⇧F1",@"Setzt die im Spiel ausgewählte, bestehende Gemeinschaft auf den Zielwert; mindestens eine Person bleibt.",YES,YES,YES,YES,10000,1,100000,1,kVK_F1,NSEventModifierFlagShift},
    {@"Maximale Beziehungen",@"⇧F2",@"Globale native Mindestbeziehung auf die originale Obergrenze setzen; keine Vertrauenshistorie verändern.",YES,NO,NO,YES,0,0,100000000,1,kVK_F2,NSEventModifierFlagShift},
    {@"Sofort bauen",@"⇧F3",@"Originale Sofortbau-Schalter für Gebäude und Bezirke.",YES,NO,NO,YES,0,0,100000000,1,kVK_F3,NSEventModifierFlagShift},
    {@"Sofort erweitern",@"⇧F4",@"Originalen Sofortschalter zur Gebietserschließung aktivieren.",YES,NO,NO,YES,0,0,100000000,1,kVK_F4,NSEventModifierFlagShift},
    {@"Sofort abreißen",@"⇧F5",@"Schließt nur laufende, registrierte Abrissoperationen der eigenen Stadt nativ ab. Abgeschlossene Abrisse werden nicht rückgängig gemacht.",YES,NO,NO,YES,0,0,100000000,1,kVK_F5,NSEventModifierFlagShift},
    {@"Sofort forschen",@"⇧F6",@"Originalen Sofortforschungs-Schalter aktivieren.",YES,NO,NO,YES,0,0,100000000,1,kVK_F6,NSEventModifierFlagShift},
    {@"Sofortige Expeditionen",@"⇧F7",@"Originalen Schalter für sofortige Erkundung aktivieren.",YES,NO,NO,YES,0,0,100000000,1,kVK_F7,NSEventModifierFlagShift},
    {@"Ratspause jetzt beenden",@"⇧F8",@"Beendet die aktuelle Ratspause einmalig über die originale Ratsfunktion.",YES,NO,YES,YES,0,0,100000000,1,kVK_F8,NSEventModifierFlagShift},
    {@"Gesetzesvorschläge immer annehmen",@"⇧F11",@"Originalen Schalter zur Annahme von Gesetzesvorschlägen aktivieren.",YES,NO,NO,YES,0,0,100000000,1,kVK_F11,NSEventModifierFlagShift},
    {@"Spielgeschwindigkeit",@"⇧F10",@"Originales Engine-Tempo; Pausen und die native Tempoauswahl bleiben maßgeblich.",YES,YES,NO,NO,2,0.25,4,0.25,kVK_F10,NSEventModifierFlagShift},
    {@"Spannung bearbeiten",@"⌥F1",@"Spannung einmalig über die originale Statistikverwaltung setzen.",YES,YES,YES,YES,0,0,100,1,kVK_F1,NSEventModifierFlagOption},
    {@"Hunger bearbeiten",@"⌥F2",@"Hunger einmalig über die originale Statistikverwaltung setzen.",YES,YES,YES,YES,0,0,100,1,kVK_F2,NSEventModifierFlagOption},
    {@"Krankheit bearbeiten",@"⌥F3",@"Krankheit einmalig über die originale Statistikverwaltung setzen.",YES,YES,YES,YES,0,0,100,1,kVK_F3,NSEventModifierFlagOption},
    {@"Kälte bearbeiten",@"⌥F4",@"Kälte einmalig über die originale Statistikverwaltung setzen.",YES,YES,YES,YES,0,0,100,1,kVK_F4,NSEventModifierFlagOption},
    {@"Elend bearbeiten",@"⌥F5",@"Elend einmalig über die originale Statistikverwaltung setzen.",YES,YES,YES,YES,0,0,100,1,kVK_F5,NSEventModifierFlagOption},
    {@"Kriminalität bearbeiten",@"⌥F6",@"Kriminalität einmalig über die originale Statistikverwaltung setzen.",YES,YES,YES,YES,0,0,100,1,kVK_F6,NSEventModifierFlagOption},
    {@"Bevölkerung: alle Gemeinschaften der Stadt",@"⌥F7",@"Setzt jede bestehende Gemeinschaft der aktuellen Stadt auf den gewählten Wert.",YES,YES,YES,YES,10000,1,100000,1,kVK_F7,NSEventModifierFlagOption}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
