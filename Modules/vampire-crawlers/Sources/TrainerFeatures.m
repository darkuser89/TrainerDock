// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <Carbon/Carbon.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Godmode",@"F1",@"Originale Unverwundbarkeit des lokalen Spielers.",YES,NO,NO,NO,0,0,0,0,kVK_F1,0},
    {@"No Mana Cost",@"F2",@"Eigene Laufkarten spielen über die native Freikartenwirkung ohne Manakosten.",YES,NO,NO,NO,0,0,0,0,kVK_F2,0},
    {@"One Hit Kill",@"F3",@"Aktive Gegner des lokalen Kampfes erhalten 1 Gesundheit und 0 Rüstung; erst ein Treffer besiegt sie.",YES,NO,NO,NO,0,0,0,0,kVK_F3,0},
    {@"EXP Multiplier",@"F4",@"Ganzzahliger Faktor für neue, tatsächlich registrierte EXP-Gewinne. Manuelle EXP-Änderungen werden ausgenommen.",YES,YES,NO,YES,2,1,100,1,kVK_F4,0},
    {@"Edit: Town Coins",@"",@"Setzt die Stadtmünzen des aktuellen lokalen Profils.",YES,YES,YES,YES,10000,0,1000000000000,100,65535,0},
    {@"Edit: Dungeon Coins",@"",@"Setzt Münzen im aktuellen Dungeonlauf über die originalen Münzfunktionen.",YES,YES,YES,YES,1000,0,1000000000,100,65535,0},
    {@"Edit: EXP",@"",@"Setzt die gesammelten EXP dieses Laufs. Das Spiel verarbeitet Levelaufstiege.",YES,YES,YES,YES,100,0,1000000000,10,65535,0},
    {@"Edit: Health",@"",@"Setzt aktuelle Gesundheit bis zum nativen Maximum des Spielers.",YES,YES,YES,NO,100,1,1000000,10,65535,0},
    {@"Edit: Armor",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,1000000,1,65535,0},
    {@"Edit: Might",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Edit: Amount",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,5,0,999,1,65535,0},
    {@"Edit: Area",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Edit: Growth",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Edit: Greed",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Edit: Luck",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Edit: Recovery",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,5,0,1000000,1,65535,0},
    {@"Edit: Mana",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,10,0,1000,1,65535,0},
    {@"Edit: Hand",@"",@"Hand entspricht DealCount: Karten pro neuer Hand. Passt bei Bedarf dessen native Laufgrenzen einmalig an.",YES,YES,YES,YES,10,1,100,1,65535,0},
    {@"Edit: Magnet",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,5,0,1000,1,65535,0},
    {@"Edit: Duration",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,100,0,10000,10,65535,0},
    {@"Edit: Revival Charge",@"",@"Ladung der Wiederbelebung; Editorbereich 0 bis 99.",YES,YES,YES,NO,50,0,99,1,65535,0},
    {@"Edit: Revival Stacks",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,5,0,999,1,65535,0},
    {@"Edit: Card Skips",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,10,0,999,1,65535,0},
    {@"Edit: Rerolls",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,10,0,999,1,65535,0},
    {@"Edit: Banishes",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,10,0,999,1,65535,0},
    {@"Edit: Curse",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,NO,0,0,10000,10,65535,0},
    {@"Edit: Charm",@"",@"Setzt den tatsächlichen Spielerwert im aktuellen Lauf; keine dauerhafte Sperre.",YES,YES,YES,YES,0,0,999,1,65535,0},
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
