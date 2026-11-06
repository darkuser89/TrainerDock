// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
// One catalog owns labels, parameter bounds and keyboard assignments.
static const DI2FeatureInfo catalog[DI2FeatureCount] = {
 {@"Gottmodus", @"F1", @"Eigener God-Mode-Grund. Schutz gegen Treffer; Sonder-/Skriptschaden separat testen.", YES,NO,NO,0,0,0,0,122,0},
 {@"Gesundheit auffüllen", @"F6", @"Füllt Gesundheit alle 0,25 Sekunden auf. Gottmodus schützt zusätzlich zwischen Aktualisierungen.",YES,NO,NO,0,0,0,0,97,0},
 {@"Ausdauer", @"F2", @"Kein Ausdauerabzug und regelmäßiges Auffüllen.",YES,NO,NO,0,0,0,0,120,0},
 {@"Waffenhaltbarkeit", @"F7", @"Eigener Unendlich-Grund für die gehaltene Nahkampfwaffe; repariert sie beim Aktivieren.",YES,NO,NO,0,0,0,0,98,0},
 {@"KI ignoriert Spieler", @"⌥F5", @"Nativer KI-Ignorierzustand nur für die lokale Spieler-ID. Originalzustand wird wiederhergestellt; geskriptete Angriffe separat testen.",YES,NO,NO,0,0,0,0,96,2},
 {@"Spielertempo", @"⇧F2", @"Zeitfaktor nur des lokalen Spieler-Actors, einschließlich dessen Animationen.",YES,YES,NO,2,0.25,4,0.25,120,1},
 {@"Bewegungstempo", @"⇧F3", @"Eigener entfernbarer Modifikator des lokalen Laufgeschwindigkeitswerts. Verändert weder Animations- noch Weltzeit.",YES,YES,NO,2,0.25,4,0.25,99,1},
 {@"Spieltempo", @"⇧F4", @"Globaler Zeitfaktor der aktuellen Einzelspieler-Welt. Ursprünglichen Faktor beim Ausschalten wiederherstellen.",YES,YES,NO,1.5,0.25,3,0.25,118,1},
 {@"Super-Kraftschaden", @"⇧F9", @"Sehr hohe Kraft der gehaltenen Nahkampfwaffe. Entspricht Stabilitäts-/Taumelschaden, nicht Gesundheitsschaden.",YES,NO,NO,0,0,0,0,101,1},
 {@"Kraftschaden ×", @"⇧F8", @"Multiplikator des Kraft-Attributs der gehaltenen Nahkampfwaffe.",YES,YES,NO,2,1,100,1,100,1},
 {@"One-Hit (Nahkampf)", @"⇧F7", @"Sehr hoher Nahkampf-Grundschaden. Keine Garantie gegen Skript-Unverwundbarkeit.",YES,NO,NO,0,0,0,0,98,1},
 {@"Schaden × (Nahkampf)", @"⇧F6", @"Multiplikator des Schadens-Attributs der gehaltenen Nahkampfwaffe. Originalwert bei Waffenwechsel wiederherstellen.",YES,YES,NO,2,1,100,1,97,1},
 {@"Verteidigung ×", @"⇧F5", @"Reduziert eingehenden Schaden des lokalen Spielers um den gewählten Faktor.",YES,YES,NO,2,1,100,1,96,1},
 {@"Geld setzen", @"⇧F1", @"Einmaliger Zielbetrag. Wert anklicken, Zahl eingeben, Enter; dann GO. F4/F5 geben weiterhin +1.000/+10.000. Geld wird gespeichert.",YES,YES,YES,99999999,0,999999999,1000,122,1},
 {@"Verbrauch & Materialien", @"⌥F2", @"Hält erkannte Material-/Verbrauchsstapel alle 0,25 Sekunden auf ihrem bisherigen Höchststand. Keine Questobjekte oder Waffen; Ergänzungen werden gespeichert.",YES,NO,NO,0,0,0,0,120,2},
 {@"Stapel behalten", @"⌥F3", @"Hält normale Material-, Verbrauchs- und Munitionsstapel auf ihrem Höchststand. Questobjekte, Schlüssel, Geld und Waffen sind ausgenommen. Auch Verkauf/Ablegen kann nachgefüllt werden.",YES,NO,NO,0,0,0,0,99,2},
 {@"Crafting ohne Kosten", @"⌥F4", @"Setzt Material- und Geldkosten geladener unterstützter Rezepte nur im Speicher auf null. Rezept-, DLC- und andere Freischaltungen bleiben erforderlich.",YES,NO,NO,0,0,0,0,118,2},
 {@"Munitionsreserve", @"F3", @"Unendliche Reserve der gehaltenen Schusswaffe; Magazinverbrauch separat über Kein Nachladen.",YES,NO,NO,0,0,0,0,99,0},
 {@"Kein Nachladen", @"F8", @"Unendliches Magazin und Auffüllen der gehaltenen Schusswaffe.",YES,NO,NO,0,0,0,0,100,0},
 {@"Präzision", @"⇧F10", @"Setzt die beiden Streuungs-Proxys des Standard-Spread-Handlers auf null. Ursprüngliche Proxy-Werte wiederherstellen.",YES,NO,NO,0,0,0,0,109,1},
 {@"Kein Rückstoß", @"⇧F11", @"Setzt die vier Rückstoß-Amplituden-Proxys des Standard-Handlers auf null; kein Eingriff in Kameracode.",YES,NO,NO,0,0,0,0,103,1},
 {@"Curveball sofort bereit", @"F11", @"Setzt lokale Quick-Throw-Abklingzeiten regelmäßig zurück. Wurfgegenstände müssen vorhanden sein.",YES,NO,NO,0,0,0,0,103,0},
 {@"Wut auffüllen", @"F9", @"Einmal bis zum aktuellen Maximum auffüllen. Erst nach Freischaltung der Wut verfügbar.",YES,NO,YES,0,0,0,0,101,0},
 {@"Wut ohne Zeitlimit", @"F10", @"Nativer Infinite-Fury-Schalter; Originalzustand beim Ausschalten wiederherstellen.",YES,NO,NO,0,0,0,0,109,0},
 {@"XP bis Maximallevel", @"⌥F1", @"Einmal XP bis zur regulären Maximallevel-Schwelle geben; normale Levelprüfung und Belohnungen. Dauerhafte Save-Änderung.",YES,NO,YES,0,0,0,0,122,2},
 {@"XP-Multiplikator", @"⇧F12", @"Ergänzt beobachtete positive XP-Zuwächse um den gewählten Faktor. Keine rekursive Multiplikation eigener Gaben. Wird gespeichert.",YES,YES,NO,2,1,100,1,111,1}
};
const DI2FeatureInfo *DI2FeatureInfoAt(DI2Feature feature) {
    return feature >= 0 && feature < DI2FeatureCount ? &catalog[feature] : NULL;
}
@implementation DI2FeatureState
@end
