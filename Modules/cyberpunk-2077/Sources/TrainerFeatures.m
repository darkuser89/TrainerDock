// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
_Static_assert(MTFeatureCount==46,"Reference catalog has 46 features.");
static MTFeatureInfo demoCatalog[MTFeatureCount]={
 {@"Gesundheit",@"F1",@"Demo: Gesundheit simulieren. Im Spiel nur mit passender Adapter-Anbindung.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Ausdauer",@"F2",@"Demo: Ausdauer simulieren; keine universelle Speicheradresse.",YES,NO,NO,NO,0,0,0,0,120,0},
 {@"Munition",@"F3",@"Demo: Munition simulieren. Besitzer/Handler im Spiel separat prüfen.",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Bewegung ×",@"F4",@"Demo: eigener Faktor mit Wiederherstellung des Ursprungswerts.",YES,YES,NO,NO,2,0.25,4,0.25,118,0},
 {@"Geld setzen",@"F5",@"Demo: Zielbetrag einmal setzen. Echte Geldgaben können gespeichert werden.",YES,YES,YES,YES,1000,0,999999999,1000,96,0},
 {@"Ressourcen +100",@"F6",@"Demo: einmalige simulierte Gabe; wird nach Kontextwechsel verworfen.",YES,NO,YES,NO,0,0,0,0,97,0}
};
static const MTFeatureInfo gameCatalog[MTFeatureCount]={
 {@"Godmode",@"F1",@"Eigene native Unverwundbarkeitsquelle.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Unbegrenzte Ausdauer",@"N2",@"Eigener CanIgnoreStamina-Modifikator.",YES,NO,NO,NO,0,0,0,0,84,0},
 {@"Unbegr. Items/Munition",@"N3",@"Erhält vorhandene Nicht-Quest-Items und Munition durch natives Nachfüllen.",YES,NO,NO,NO,0,0,0,0,85,0},
 {@"Bewegung ×",@"⌥N6",@"Eigener MaxSpeed-Faktor; beim Ausschalten entfernt.",YES,YES,NO,NO,2,0.25,4,0.25,88,2},
 {@"Geld setzen",@"⌃N1",@"Zielbetrag einmal nativ setzen und zurücklesen.",YES,YES,YES,YES,9999999,0,999999999,1000,83,4},
 {@"Unbegr. Komponenten",@"⌥N3",@"Fünf Komponentenarten auf mindestens 999 halten.",YES,NO,NO,NO,0,0,0,0,85,2},
 {@"Items nicht verbrauchen",@"N4",@"Erhält vorhandene Nicht-Quest-Items; Geld bleibt separat.",YES,NO,NO,NO,0,0,0,0,86,0},
 {@"Heilung ohne Wartezeit",@"N5",@"Füllt den aktiven Heilungs-Ladungspool nach.",YES,NO,NO,NO,0,0,0,0,87,0},
 {@"Granaten ohne Wartezeit",@"N6",@"Füllt den aktiven Granaten-Ladungspool nach.",YES,NO,NO,NO,0,0,0,0,88,0},
 {@"Armwerfer ohne Wartezeit",@"N*",@"Benötigt ausgerüsteten Projektilwerfer; füllt dessen Ladungspool nach.",YES,NO,NO,NO,0,0,0,0,67,0},
 {@"Nicht nachladen",@"N7",@"Eigener Magazin-Autofill-Modifikator an der gezogenen Waffe.",YES,NO,NO,NO,0,0,0,0,89,0},
 {@"Hohe Präzision",@"N8",@"Eigene Streuungs-Modifikatoren an der gezogenen Waffe.",YES,NO,NO,NO,0,0,0,0,91,0},
 {@"Kein Rückstoß",@"N9",@"Eigene Rückstoß-Modifikatoren an der gezogenen Waffe.",YES,NO,NO,NO,0,0,0,0,92,0},
 {@"Ein Treffer tötet",@"N0",@"Sehr hoher eigener Schadensfaktor; geskriptete Unverwundbarkeit bleibt wirksam.",YES,NO,NO,NO,0,0,0,0,82,0},
 {@"Schaden ×",@"N.",@"Eigener Schadensfaktor, mit Ein-Treffer-Schalter kombinierbar.",YES,YES,NO,NO,2,1,1000,0.5,65,0},
 {@"Verteidigung ×",@"N+",@"Teilt eingehenden Spielerschaden durch den Faktor; bestätigt beim Treffer.",YES,YES,NO,NO,2,1,1000,0.5,69,0},
 {@"Schleichmodus",@"N−",@"Native Spieler-Unsichtbarkeit; eigener Anteil wird zurückgenommen.",YES,NO,NO,NO,0,0,0,0,78,0},
 {@"Unbegrenzte XP",@"⌃N2",@"Nächste reguläre Spieler-XP-Vergabe bis zur nativen Levelgrenze erweitern.",YES,NO,NO,NO,0,0,0,0,84,4},
 {@"XP ×",@"⌃N3",@"Multipliziert neue Spieler-XP; Bestätigung bei der nächsten Vergabe.",YES,YES,NO,NO,2,1,1000,0.5,85,4},
 {@"Unbegr. Street Cred",@"⌃N4",@"Nächste Street-Cred-Vergabe bis zur nativen Grenze erweitern.",YES,NO,NO,NO,0,0,0,0,86,4},
 {@"Street Cred ×",@"⌃N5",@"Multipliziert neue Street-Cred-XP; Bestätigung bei der nächsten Vergabe.",YES,YES,NO,NO,2,1,1000,0.5,87,4},
 {@"Max. Fertigkeitsfortschritt",@"⌃N6",@"Erweitert neue Fertigkeits-XP bis zur jeweiligen nativen Grenze.",YES,NO,NO,NO,0,0,0,0,88,4},
 {@"Fertigkeits-XP ×",@"⌃N7",@"Multipliziert neue Fertigkeits-XP; Bestätigung bei der nächsten Vergabe.",YES,YES,NO,NO,2,1,1000,0.5,89,4},
 {@"Attributpunkte",@"⌃N8",@"Attributpunkte einmal setzen und nativ zurücklesen.",YES,YES,YES,YES,99,0,999,1,91,4},
 {@"Perkpunkte",@"⌃N9",@"Perkpunkte einmal setzen und nativ zurücklesen.",YES,YES,YES,YES,99,0,999,1,92,4},
 {@"Reliktpunkte",@"⌃N0",@"Reliktpunkte einmal setzen und nativ zurücklesen.",YES,YES,YES,YES,99,0,999,1,82,4},
 {@"Cyberware-Limit aufheben",@"⌃N.",@"Eigener HumanityOverallocationPossible-Modifikator.",YES,NO,NO,NO,0,0,0,0,65,4},
 {@"Spieltempo ×",@"⌃N+",@"Eigene benannte Zeitdilatation; Ausschalten entfernt nur diese Quelle.",YES,YES,NO,NO,1,0.1,3,0.1,69,4},
 {@"Unbegrenzter RAM",@"⌥N1",@"Füllt den aktiven Cyberdeck-RAM-Pool nach.",YES,NO,NO,NO,0,0,0,0,83,2},
 {@"Breach-Timer anhalten",@"⌥N2",@"Hält den Timer eines lokal geöffneten Breach-Minispiels an.",YES,NO,NO,NO,0,0,0,0,84,2},
 {@"Unbegr. Quickhack-Teile",@"⌥N4",@"Vier Quickhack-Komponentenarten auf mindestens 999 halten.",YES,NO,NO,NO,0,0,0,0,86,2},
 {@"Max. Traglast",@"⌥N5",@"Ziel-Traglast mit eigenem nativen Modifikator.",YES,YES,NO,YES,999999,1,999999,100,87,2},
 {@"Hoher Sprung",@"⌥N7",@"Zusätzlicher vertikaler Impuls beim lokalen Sprung.",YES,NO,NO,NO,0,0,0,0,89,2},
 {@"Unbegr. Doppelsprünge",@"⌥N8",@"Benötigt verstärkte Sehnen; setzt den nativen Mehrfachsprungzähler zurück.",YES,NO,NO,NO,0,0,0,0,91,2},
 {@"Spielerlevel",@"⌥N9",@"Spielerlevel einmal nativ setzen; Levelsenkung kann Fortschritt zurücksetzen.",YES,YES,YES,YES,25,1,60,1,92,2},
 {@"Street-Cred-Level",@"⌥N0",@"Street-Cred-Level einmal nativ setzen.",YES,YES,YES,YES,25,1,50,1,82,2},
 {@"Tageszeit anhalten",@"⌥N.",@"Eigene Pausenquelle für die Tageszeit; Spiel läuft weiter.",YES,NO,NO,NO,0,0,0,0,65,2},
 {@"Tageszeit +1 Stunde",@"⌥N+",@"Native Tageszeit einmal um 3600 Sekunden vorziehen.",YES,NO,YES,NO,0,0,0,0,69,2},
 {@"Headhunter-Level",@"⇧F1",@"Headhunter-Fertigkeitslevel einmal nativ setzen.",YES,YES,YES,YES,25,1,60,1,122,1},
 {@"Netrunner-Level",@"⇧F2",@"Netrunner-Fertigkeitslevel einmal nativ setzen.",YES,YES,YES,YES,25,1,60,1,120,1},
 {@"Shinobi-Level",@"⇧F3",@"Shinobi-Fertigkeitslevel einmal nativ setzen.",YES,YES,YES,YES,25,1,60,1,99,1},
 {@"Solo-Level",@"⇧F4",@"Solo-Fertigkeitslevel einmal nativ setzen.",YES,YES,YES,YES,25,1,60,1,118,1},
 {@"Engineer-Level",@"⇧F5",@"Engineer-Fertigkeitslevel einmal nativ setzen.",YES,YES,YES,YES,25,1,60,1,96,1},
 {@"Flugmodus",@"⇧Pg↑",@"Native Positionssteuerung: WASD, Leertaste aufwärts, C abwärts.",YES,NO,NO,NO,0,0,0,0,116,1},
 {@"Flughöhe",@"⇧N+",@"Zielhöhe relativ zum Start des aktiven Flugmodus.",YES,YES,NO,NO,10,0.1,1000,0.5,69,1},
 {@"Flugtempo ×",@"⇧N−",@"Bewegungsfaktor im aktiven Flugmodus.",YES,YES,NO,NO,2,0.25,10,0.25,78,1},
};
static BOOL demo;
void MTUseDemoFeatures(void) {
    for(NSInteger i=6;i<MTFeatureCount;i++){
        demoCatalog[i]=gameCatalog[i];demoCatalog[i].implemented=NO;
        demoCatalog[i].shortcut=@"—";demoCatalog[i].detail=@"Nicht Teil der sechs Vorlagen-Simulationen.";
    }
    demo=YES;
}
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature) { return feature>=0 && feature<MTFeatureCount ? &(demo ? demoCatalog : gameCatalog)[feature] : NULL; }
@implementation MTFeatureState
@end
