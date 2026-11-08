// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <Carbon/Carbon.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"God Mode",@"F1",@"Originale Immunität ohne Blinken; kein Rückstoß und Fallschaden.",YES,NO,NO,NO,0,0,0,0,kVK_F1,0},
    {@"Unbegrenzte Gesundheit",@"F2",@"Füllt die Gesundheit bis zum aktuellen Maximum. Für Schutz vor tödlichem Einzelschaden God Mode verwenden.",YES,NO,NO,NO,0,0,0,0,kVK_F2,0},
    {@"Unbegrenztes Mana",@"F3",@"Füllt Mana bis zum aktuellen Maximum.",YES,NO,NO,NO,0,0,0,0,kVK_F3,0},
    {@"Unbegrenzter Atem",@"F4",@"Erhält die Atemreserve auch unter Wasser.",YES,NO,NO,NO,0,0,0,0,kVK_F4,0},
    {@"Unbegrenzte Flugdauer",@"F5",@"Füllt Flügel- und Raketenflugreserven. Passende Ausrüstung ist erforderlich.",YES,NO,NO,NO,0,0,0,0,kVK_F5,0},
    {@"Geistermodus",@"F6",@"Originaler Geisterflug durch Gelände. Vor dem Ausschalten eine freie Stelle wählen.",YES,NO,NO,NO,0,0,0,0,kVK_F6,0},
    {@"Unbegrenzte Gegenstände",@"F7",@"Füllt vorhandene Inventarstapel auf ihre originale Stapelgrenze. Erzeugt keine neuen Gegenstandstypen.",YES,NO,NO,NO,0,0,0,0,kVK_F7,0},
    {@"Maximales Licht",@"F8",@"Hellt die originale Lichtkarte auf. Beim Ausschalten wird die Beleuchtung neu berechnet.",YES,NO,NO,NO,0,0,0,0,kVK_F8,0},
    {@"Alle Handwerksrezepte",@"F9",@"Zeigt alle geladenen Rezepte. Originale Material- und Ortsanforderungen bleiben erhalten.",YES,NO,NO,NO,0,0,0,0,kVK_F9,0},
    {@"Superschaden / Eintreffer-Kills",@"F10",@"Erhöht den Schaden nicht verbrauchbarer Waffen. Munition, Münzen und Wurfstapel bleiben unverändert; ein Treffer ist erforderlich.",YES,NO,NO,NO,0,0,0,0,kVK_F10,0},
    {@"Tageszeit einfrieren",@"F11",@"Hält Uhrzeit und Tag-/Nachtphase auf dem Wert beim Einschalten.",YES,NO,NO,NO,0,0,0,0,kVK_F11,0},
    {@"Spielgeschwindigkeit",@"F12",@"Skaliert die originale FNA-Updatefrequenz. Menüs und Ladepausen verwenden die normale Frequenz.",YES,YES,NO,NO,2,0.25,4,0.25,kVK_F12,0},
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
