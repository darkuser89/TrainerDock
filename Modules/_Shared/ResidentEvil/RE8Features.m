// SPDX-License-Identifier: GPL-3.0-only
#import "RE8Features.h"
static const RE2FeatureInfo catalog8[RE8FeatureCount]={
 {@"Unverwundbarkeit: Treffer ignorieren",@"F2",@"Verhindert Schaden und Trefferreaktionen deiner Spielfigur. Unbegrenzte Gesundheit ist ein eigener Schalter.",YES,NO,NO,NO,0,0,0,0,120,0},
 {@"Unbegrenzte Gesundheit",@"F1",@"Füllt die Lebenspunkte deiner lebenden Spielfigur laufend bis zum Maximum auf.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Unbegrenzte Munition",@"F3",@"Füllt vorhandene Reservemunition auf. Für ein dauerhaft volles Magazin zusätzlich „Kein Nachladen“ einschalten.",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Kein Nachladen",@"F4",@"Füllt das Magazin zwischen Schüssen auf. Ausschalten beendet das Auffüllen; vorhandene Munition bleibt erhalten.",YES,NO,NO,NO,0,0,0,0,118,0},
 {@"Schnellere Feuerrate",@"⇧ F3",@"Verkürzt die Wartezeit zwischen Schüssen der ausgerüsteten Waffe.",YES,NO,NO,NO,0,0,0,0,99,1},
 {@"Kein Rückstoß",@"F6",@"Unterdrückt den Kamerarückstoß beim Zielen, auch mit Rose. Die Waffenanimation darf sich weiterhin bewegen.",YES,NO,NO,NO,0,0,0,0,97,0},
 {@"Unbegrenzte Gegenstände & Ressourcen",@"F7",@"Füllt vorhandene stapelbare Verbrauchsgegenstände und Herstellungsmaterialien auf. Schlüssel sind ausgenommen.",YES,NO,NO,NO,0,0,0,0,98,0},
 {@"Herstellen ohne Material",@"⌥ F10",@"Setzt die Materialkosten vorhandener Herstellungsrezepte auf 0.",YES,NO,NO,NO,0,0,0,0,109,2},
 {@"Spielgeschwindigkeit ×",@"F9",@"Ändert das Tempo des gesamten Spiels: 2 bedeutet doppelt, 0,5 halb so schnell. Pausiert in Spielmenüs.",YES,YES,NO,NO,2,0.1,3,0.1,101,0},
 {@"Mit einem Treffer töten",@"F10",@"Erhöht die Angriffsstärke der ausgerüsteten Waffe, damit ein wirksamer Treffer genügt. Skriptsperren bleiben bestehen.",YES,NO,NO,NO,0,0,0,0,109,0},
 {@"Verursachter Schaden ×",@"⌥ F2",@"Multipliziert die Angriffsstärke deiner Waffe: 2 bedeutet doppelte Stärke. „Mit einem Treffer töten“ hat Vorrang.",YES,YES,NO,NO,2,0.25,100,0.25,120,2},
 {@"Gegenstände & Interaktionen markieren",@"⌥ F8",@"Zeigt zusätzliche Markierungen für geladene Gegenstände und Interaktionen aus der Ferne. Pausiert in Menüs.",YES,NO,NO,NO,0,0,0,0,100,2},
 {@"Spielzeit um 1 Stunde reduzieren",@"⇧ F8",@"Zieht einmalig bis zu eine Stunde von der Hauptspiel- bzw. Rose-Spielzeit ab, mindestens bis 0. Keine ⇧F9-Rücknahme.",YES,NO,YES,NO,0,0,0,0,100,1},
 {@"Kochen ohne Zutaten",@"⌥ F3",@"Setzt die benötigten Zutaten freigeschalteter Gerichte in der Küche des Dukes auf 0.",YES,NO,NO,NO,0,0,0,0,99,2},
 {@"Geschwindigkeit der Spielfigur ×",@"⌥ F6",@"Ändert das Bewegungstempo deiner Spielfigur, ohne das übrige Spiel zu beschleunigen. 2 bedeutet doppelt so schnell.",YES,YES,NO,NO,2,0.25,3,0.25,97,2},
 {@"Lei-Guthaben bearbeiten",@"⌥ F4",@"Setzt dein Lei-Guthaben einmalig auf den gewählten Betrag. Keine ⇧F9-Rücknahme.",YES,YES,YES,YES,9999999,0,9999999,1000,118,2},
 {@"Lei-Einnahmen ×",@"⌥ F5",@"Multipliziert neu erhaltene Lei: 2 verdoppelt Einnahmen. Vorhandenes Guthaben und Ausgaben bleiben unverändert.",YES,YES,NO,NO,2,1,10,0.25,96,2},
 {@"Bonuspunkte (CP) bearbeiten",@"⇧ F6",@"Setzt deine CP für den Bonusshop einmalig auf den gewählten Wert. Keine ⇧F9-Rücknahme.",YES,YES,YES,YES,9999999,0,9999999,1000,97,1},
 {@"Alle Bonusshop-Artikel freischalten",@"⇧⌥ F7",@"Hebt die Sperren registrierter Bonusshop-Artikel dauerhaft auf. Kein Kauf. ⇧F9 macht die Freischaltungen nicht rückgängig.",YES,NO,YES,NO,0,0,0,0,98,3},
 {@"Söldner: Restzeit anhalten",@"⌥ F9",@"Hält die verbleibende Zeit einer aktiven Söldner-Runde an.",YES,NO,NO,NO,0,0,0,0,101,2},
 {@"Söldner: 9.999.999 Punkte",@"⇧⌥ F2",@"Erhöht Gebiets- und Gesamtpunkte der laufenden Söldner-Runde auf 9.999.999. Aus stoppt weitere Zugaben; vergebene Punkte bleiben.",YES,NO,NO,NO,0,0,0,0,120,3},
 {@"Söldner: Punktegewinn ×",@"⇧⌥ F3",@"Multipliziert neu verdiente Punkte einer laufenden Söldner-Runde. 2 bedeutet doppelten Gewinn.",YES,YES,NO,NO,2,1,10,0.25,99,3},
 {@"Söldner: Zielportal sofort öffnen",@"⇧ F1",@"Öffnet das vorhandene gelbe Zielportal, ohne die normale Gegnerzahl abzuwarten. Erst das Betreten beendet das Gebiet.",YES,NO,YES,NO,0,0,0,0,122,1},
};
const RE2FeatureInfo *RE8FeatureInfoAt(NSInteger f){return f>=0 && f<RE8FeatureCount ? &catalog8[f] : NULL;}
