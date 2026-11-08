// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <Carbon/Carbon.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Unverwundbarkeit",@"F1",@"Originale Unverwundbarkeit des lokalen Spielers.",YES,NO,NO,NO,0,0,0,0,kVK_F1,0},
    {@"Keine Manakosten",@"F2",@"Eigene Laufkarten spielen über die native Freikartenwirkung ohne Manakosten.",YES,NO,NO,NO,0,0,0,0,kVK_F2,0},
    {@"Mit einem Treffer töten",@"F3",@"Aktive Gegner des lokalen Kampfes erhalten 1 Gesundheit und 0 Rüstung; erst ein Treffer besiegt sie.",YES,NO,NO,NO,0,0,0,0,kVK_F3,0},
    {@"EP-Multiplikator",@"F4",@"Ganzzahliger Faktor für neue, tatsächlich registrierte EP-Gewinne. Manuelle EP-Änderungen werden ausgenommen.",YES,YES,NO,YES,2,1,100,1,kVK_F4,0},
    {@"Stadtmünzen einstellen",@"",@"Setzt die Stadtmünzen des aktuellen lokalen Profils.",YES,YES,YES,YES,10000,0,1000000000000,100,65535,0},
    {@"Verliesmünzen einstellen",@"",@"Setzt Münzen im aktuellen Dungeonlauf über die originalen Münzfunktionen.",YES,YES,YES,YES,1000,0,1000000000,100,65535,0},
    {@"Erfahrung einstellen",@"",@"Setzt die gesammelten EP dieses Laufs. Das Spiel verarbeitet Stufenaufstiege.",YES,YES,YES,YES,100,0,1000000000,10,65535,0},
    {@"Gesundheit einstellen",@"",@"Setzt aktuelle Gesundheit bis zum nativen Maximum des Spielers.",YES,YES,YES,NO,100,1,1000000,10,65535,0},
    {@"Rüstung einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,1000000,1,65535,0},
    {@"Macht einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Anzahl einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,5,0,999,1,65535,0},
    {@"Fläche einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Wachstum einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Gier einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Glück einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Regeneration einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,5,0,1000000,1,65535,0},
    {@"Mana einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,10,0,1000,1,65535,0},
    {@"Handgröße einstellen",@"",@"Legt die Kartenanzahl pro neuer Hand fest. Passt bei Bedarf deren ursprüngliche Grenzen einmalig an.",YES,YES,YES,YES,10,1,100,1,65535,0},
    {@"Magnet einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,5,0,1000,1,65535,0},
    {@"Dauer einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Wiederbelebungsladung einstellen",@"",@"Ladung der Wiederbelebung; Editorbereich 0 bis 99.",YES,YES,YES,NO,50,0,99,1,65535,0},
    {@"Wiederbelebungsstapel einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,5,0,999,1,65535,0},
    {@"Kartenüberspringen einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,10,0,999,1,65535,0},
    {@"Neuauswahlen einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,10,0,999,1,65535,0},
    {@"Verbannungen einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,10,0,999,1,65535,0},
    {@"Fluch einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,0,0,10000,10,65535,0},
    {@"Charme einstellen",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,0,0,999,1,65535,0},
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
