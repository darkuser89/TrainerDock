// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import "RE4Features.h"
#import "RE7Features.h"
#import "RE8Features.h"
static const RE2FeatureInfo catalog[RE2FeatureCount]={
 {@"Unbegrenzte Gesundheit",@"F1",@"Schützt deine Spielfigur vor Schaden.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Unbegrenzte Reservemunition",@"F3",@"Füllt vorhandene Reservemunition auf. Für ein dauerhaft volles Magazin zusätzlich „Kein Nachladen“ einschalten.",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Kein Nachladen",@"F4",@"Hält das Magazin der ausgerüsteten Waffe gefüllt, damit du ohne Nachladen weiterschießen kannst.",YES,NO,NO,NO,0,0,0,0,118,0},
 {@"Unbegrenzte Farbbänder",@"⇧ F4",@"Füllt vorhandene Farbbänder zum Speichern im Hardcore-Modus auf.",YES,NO,NO,NO,0,0,0,0,118,1},
 {@"Maximale Zielgenauigkeit",@"F5",@"Das Fadenkreuz fokussiert schneller und verliert beim Bewegen oder Schießen keinen Fokus.",YES,NO,NO,NO,0,0,0,0,96,0},
 {@"Kein Rückstoß",@"F6",@"Unterdrückt den Rückstoß der ausgerüsteten Waffe.",YES,NO,NO,NO,0,0,0,0,97,0},
 {@"Zeitlupen-Faktor",@"⇧ F5",@"Verlangsamt das gesamte Spiel: 0,5 bedeutet halbe Geschwindigkeit. Pausiert in Spielmenüs.",YES,YES,NO,NO,0.5,0.1,1,0.1,96,1},
 {@"Mit einem Treffer töten",@"F10",@"Senkt die Lebenspunkte lebender Gegner auf 1, damit ein wirksamer Treffer genügt. Skriptsperren bleiben bestehen.",YES,NO,NO,NO,0,0,0,0,109,0},
 {@"Inventar auf 20 Plätze erweitern",@"⇧ F2",@"Erweitert den Rucksack einmalig auf 20 Plätze. Ausschalten und ⇧F9 machen die Erweiterung nicht rückgängig.",YES,NO,YES,NO,0,0,0,0,120,1},
 {@"Spielzeit zurücksetzen",@"⇧ F8",@"Setzt die aktuelle Spielzeit einmalig auf 0. ⇧F9 macht diese Änderung nicht rückgängig.",YES,NO,YES,NO,0,0,0,0,100,1},
 {@"Anzahl Speicherungen zurücksetzen",@"⇧ F10",@"Setzt den Statistikzähler für Speicherungen einmalig auf 0; löscht keine Spielstände. ⇧F9 macht dies nicht rückgängig.",YES,NO,YES,NO,0,0,0,0,109,1},
 {@"Countdown anhalten",@"⌥ F1",@"Hält die verbleibende Zeit eines laufenden Szenen-Countdowns an.",YES,NO,NO,NO,0,0,0,0,122,2},
 {@"Itembox-Öffnungen zurücksetzen",@"⌥ F2",@"Setzt nur den Statistikzähler geöffneter Itemboxen auf 0. Der Inhalt bleibt erhalten. Einmalaktion; keine ⇧F9-Rücknahme.",YES,NO,YES,NO,0,0,0,0,120,2},
 {@"Heilmittel-Zähler zurücksetzen",@"⌥ F3",@"Setzt die Anzahl verwendeter Heilgegenstände in der Statistik auf 0. Gibt keine verbrauchten Items zurück. Keine ⇧F9-Rücknahme.",YES,NO,YES,NO,0,0,0,0,99,2},
 {@"Schrittzähler zurücksetzen",@"⌥ F4",@"Setzt die gezählten Schritte einmalig auf 0. ⇧F9 macht diese Änderung nicht rückgängig.",YES,NO,YES,NO,0,0,0,0,118,2},
 {@"Unbegrenzte Messerhaltbarkeit",@"F8",@"Hält vorhandene, noch intakte Messer auf maximaler Haltbarkeit.",YES,NO,NO,NO,0,0,0,0,100,0},
 {@"Geschwindigkeit der Spielfigur ×",@"⌥ F6",@"Beschleunigt deine Spielfigur und ihre Bewegungsanimationen: 2 bedeutet doppelte Geschwindigkeit.",YES,YES,NO,NO,2,1,3,0.25,97,2},
 {@"Tyrant am Boden halten",@"⌥ F7",@"Senkt die Lebenspunkte des patrouillierenden Tyrant auf 1 und hält seine Erholung nach dem Niederschlag an.",YES,NO,NO,NO,0,0,0,0,98,2},
 {@"Gegenstände & Interaktionen markieren",@"⌥ F8",@"Zeigt zusätzliche Markierungen für geladene Gegenstände und Interaktionen aus der Ferne. Die Benutzungsreichweite bleibt gleich.",YES,NO,NO,NO,0,0,0,0,100,2},
 {@"Unbegrenzte Holzbretter",@"⌥ F9",@"Füllt bereits vorhandene Holzbretter im Inventar auf; erzeugt keinen neuen Stapel.",YES,NO,NO,NO,0,0,0,0,101,2},
 {@"Mini-Tresor lösen",@"⌥ F10",@"Löst den gerade geöffneten tragbaren Mini-Tresor einmalig. Öffne zuerst das Rätsel mit den acht Tasten. Wird beim Spielstart nicht automatisch ausgeführt.",YES,NO,YES,NO,0,0,0,0,109,2},
};
static const RE2FeatureInfo re3Catalog[RE3FeatureCount]={
 {@"Unbegrenzte Gesundheit",@"F1",@"Füllt die Lebenspunkte deiner lebenden Spielfigur laufend bis zum Maximum auf.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Unbegrenzte Munition & Granaten",@"F3",@"Füllt vorhandene Reservemunition auf und verhindert den Verbrauch vorhandener Hand- und Blendgranaten.",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Kein Nachladen",@"F4",@"Hält das Magazin der ausgerüsteten Waffe gefüllt, damit du ohne Nachladen weiterschießen kannst.",YES,NO,NO,NO,0,0,0,0,118,0},
 {@"Unverwundbarkeit: Treffer ignorieren",@"F2",@"Aktiviert die Unverwundbarkeit deiner Spielfigur. Unbegrenzte Gesundheit ist ein eigener Schalter.",YES,NO,NO,NO,0,0,0,0,120,0},
 {@"Maximale Zielgenauigkeit",@"F5",@"Das Fadenkreuz fokussiert schneller und verliert beim Bewegen oder Schießen keinen Fokus.",YES,NO,NO,NO,0,0,0,0,96,0},
 {@"Kein Rückstoß",@"F6",@"Unterdrückt den Rückstoß der ausgerüsteten Waffe.",YES,NO,NO,NO,0,0,0,0,97,0},
 {@"Zeitlupen-Faktor",@"⇧ F5",@"Verlangsamt das gesamte Spiel: 0,5 bedeutet halbe Geschwindigkeit. Pausiert in Spielmenüs.",YES,YES,NO,NO,0.5,0.1,1,0.1,96,1},
 {@"Mit einem Treffer töten",@"F10",@"Senkt die Lebenspunkte lebender Gegner auf 1, damit ein wirksamer Treffer genügt. Skriptsperren bleiben bestehen.",YES,NO,NO,NO,0,0,0,0,109,0},
 {@"Inventar auf 20 Plätze erweitern",@"⇧ F2",@"Erweitert das Inventar einmalig auf 20 Plätze. ⇧F9 macht die Erweiterung nicht rückgängig.",YES,NO,YES,NO,0,0,0,0,120,1},
 {@"Spielzeit zurücksetzen",@"⇧ F8",@"Setzt die aktuelle Spielzeit samt Zeitabzügen einmalig auf 0. Keine ⇧F9-Rücknahme.",YES,NO,YES,NO,0,0,0,0,100,1},
 {@"Anzahl Speicherungen zurücksetzen",@"⇧ F10",@"Setzt den Statistikzähler für Speicherungen auf 0; löscht keine Spielstände. Einmalaktion; keine ⇧F9-Rücknahme.",YES,NO,YES,NO,0,0,0,0,109,1},
 {@"Todeszähler zurücksetzen",@"⌥ F1",@"Setzt die Anzahl deiner Tode in der Statistik einmalig auf 0. Keine ⇧F9-Rücknahme.",YES,NO,YES,NO,0,0,0,0,122,2},
 {@"Itembox-Öffnungen zurücksetzen",@"⌥ F2",@"Setzt nur den Statistikzähler geöffneter Itemboxen auf 0. Der Inhalt bleibt erhalten. Keine ⇧F9-Rücknahme.",YES,NO,YES,NO,0,0,0,0,120,2},
 {@"Heilmittel-Zähler zurücksetzen",@"⌥ F3",@"Setzt die Anzahl verwendeter Heilgegenstände in der Statistik auf 0. Gibt keine Items zurück. Keine ⇧F9-Rücknahme.",YES,NO,YES,NO,0,0,0,0,99,2},
 {@"Alle Herausforderungen abschließen",@"⌥ F4",@"Schließt alle registrierten Records ab. Freischaltungen können gespeichert werden; ⇧F9 macht sie nicht rückgängig.",YES,NO,YES,NO,0,0,0,0,118,2},
 {@"Gesamte Spielzeit zurücksetzen",@"⌥ F5",@"Setzt die übergreifende Gesamtspielzeit einmalig auf 0. Keine ⇧F9-Rücknahme.",YES,NO,YES,NO,0,0,0,0,96,2},
 {@"Geschwindigkeit der Spielfigur ×",@"⌥ F6",@"Beschleunigt deine Spielfigur und ihre Bewegungsanimationen: 2 bedeutet doppelte Geschwindigkeit.",YES,YES,NO,NO,2,1,3,0.25,97,2},
 {@"Nemesis am Boden halten",@"⌥ F7",@"Senkt die Lebenspunkte des humanoiden Nemesis auf 1 und stoppt seine Erholung nach dem Niederschlag. Andere Bossformen sind ausgenommen.",YES,NO,NO,NO,0,0,0,0,98,2},
 {@"Gegenstände & Interaktionen markieren",@"⌥ F8",@"Zeigt zusätzliche Markierungen für geladene Gegenstände und Interaktionen aus der Ferne.",YES,NO,NO,NO,0,0,0,0,100,2},
 {@"Shop-Punkte bearbeiten",@"⌥ F9",@"Setzt die Shop-Punkte einmalig auf den gewählten Wert. Zahl anklicken zum Bearbeiten; ⇧F9 setzt die Punkte nicht zurück.",YES,YES,YES,YES,999999,0,9999999,1000,101,2},
};
BOOL RE2IsRE3Game(void){return [NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE3US"];}
const RE2FeatureInfo *RE2FeatureInfoForGame(RE2Feature feature, BOOL re3){return feature>=0 && feature<(re3 ? RE3FeatureCount : RE2FeatureCount) ? &(re3 ? re3Catalog : catalog)[feature] : NULL;}
BOOL RE2IsRE4Game(void){return [NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE4US"];}
BOOL RE2IsRE7Game(void){return [NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.RE7US"];}
BOOL RE2IsRE8Game(void){return [NSBundle.mainBundle.bundleIdentifier isEqual:@"jp.co.capcom.VillageUS"];}
NSInteger RE2ActiveFeatureCount(void){return RE2IsRE8Game() ? RE8FeatureCount : RE2IsRE7Game() ? RE7FeatureCount : RE2IsRE4Game() ? RE4FeatureCount : RE2IsRE3Game() ? RE3FeatureCount : RE2FeatureCount;}
NSString *RE2GameShortName(void){return RE2IsRE8Game() ? @"RE8" : RE2IsRE7Game() ? @"RE7" : RE2IsRE4Game() ? @"RE4" : RE2IsRE3Game() ? @"RE3" : @"RE2";}
NSString *RE2GameVersionLabel(void){return RE2IsRE8Game() ? @"Village 1.1.8" : RE2IsRE7Game() ? @"RE7 1.0.4" : RE2IsRE4Game() ? @"RE4 1.0.7" : RE2IsRE3Game() ? @"RE3 1.0.0" : @"RE2 1.0.2";}
const RE2FeatureInfo *RE2FeatureInfoAt(RE2Feature feature){return RE2IsRE8Game() ? RE8FeatureInfoAt(feature) : RE2IsRE7Game() ? RE7FeatureInfoAt(feature) : RE2IsRE4Game() ? RE4FeatureInfoAt(feature) : RE2FeatureInfoForGame(feature,RE2IsRE3Game());}
@implementation RE2FeatureState
@end
