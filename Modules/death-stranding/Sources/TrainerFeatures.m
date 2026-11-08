// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Unbegrenztes Leben",@"F1",@"Füllt den Blutwert über die originale Zustandsfunktion auf. Ausschalten beendet das Nachfüllen.",YES,NO,NO,YES,0,0,0,1,122,0},
    {@"Maximales Bewusstsein",@"F2",@"Füllt das Bewusstsein über die native Erholungsfunktion auf.",YES,NO,NO,YES,0,0,0,1,120,0},
    {@"Unbegrenzte Ausdauer",@"F3",@"Füllt die aktuelle Ausdauer nativ auf; unveränderte Spielgrenzen bleiben maßgeblich.",YES,NO,NO,YES,0,0,0,1,99,0},
    {@"Keine Erschöpfung",@"F4",@"Setzt die native langfristige Erschöpfung auf null. Ausschalten beendet das Nachfüllen.",YES,NO,NO,YES,0,0,0,1,118,0},
    {@"Kein BB-Stress",@"F5",@"Hält BBs Stress über die originale Spielroutine auf null. Aktiv erst nach Rücklesen von Zustand und Spielanzeige; Ausschalten beendet das Zurücksetzen.",YES,NO,NO,YES,0,0,0,1,96,0},
    {@"Tragfähigkeit",@"F6",@"Setzt beide nativen Traglast-Basisgrenzen. Ausdauerfaktor und Spielboni bleiben wirksam; Ausschalten nimmt nur eigene Werte zurück.",YES,YES,NO,YES,9999,1,9999,1,97,0},
    {@"Unbegrenzte Munition / Gegenstände",@"F7",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,98,0},
    {@"Maximale Schuhhaltbarkeit",@"F8",@"Derzeit nur getragene Schuhe; andere Ausrüstung ist nicht als geprüft freigegeben.",YES,NO,NO,YES,0,0,0,1,100,0},
    {@"Maximale Frachthaltbarkeit",@"F9",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,101,0},
    {@"Maximale Behälterhaltbarkeit",@"F10",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,109,0},
    {@"Standreserve im Wasser",@"F11",@"Hält die separate Stand-/Atemreserve nativ voll; im flachen Wasser geprüft. Tiefes Wasser und starke Strömung bleiben ungeprüft. Ausschalten beendet das Nachfüllen.",YES,NO,NO,YES,0,0,0,1,103,0},
    {@"Unverwundbar / Treffer ignorieren",@"F12",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,111,0},
    {@"Unbegrenzter Ausrüstungsakku",@"⌥F1",@"Füllt den Ausrüstungsakku über die originale Wiederherstellungsfunktion auf.",YES,NO,NO,YES,0,0,0,1,122,2},
    {@"Unbegrenzter Fahrzeugakku",@"⌥F2",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,120,2},
    {@"Gewicht ignorieren",@"⌥F3",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,99,2},
    {@"Unbegrenzter Urin",@"⌥F4",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,118,2},
    {@"Tarnmodus",@"⌥F5",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,96,2},
    {@"Kein Nachladen",@"⌥F6",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,97,2},
    {@"Maximale Fahrzeughaltbarkeit",@"⌥F7",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,98,2},
    {@"Einfaches Bauen / Materialien setzen",@"⌥F8",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,YES,NO,YES,8000,0,99999,1,100,2},
    {@"Unbegrenzte Materialien",@"⌥F9",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,101,2},
    {@"Maximale Materiallagerkapazität",@"⌥F10",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,109,2},
    {@"Chirale Kristalle setzen",@"⌥F11",@"Explizite Einmalaktion über den nativen Kristall-Setter. Native Obergrenze bleibt erhalten.",YES,YES,YES,YES,50000,0,99999,1,103,2},
    {@"Spielgeschwindigkeit",@"⌥F12",@"Steuert Welt, Spieler und Kamera über einen eigenen nativen Zeitauftrag. Ausschalten entfernt nur diesen Auftrag.",YES,YES,NO,NO,2.5,0.25,3,0.25,111,2},
    {@"Maximale Gebäudehaltbarkeit",@"⇧F1",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,122,1},
    {@"Unbegrenzte chirale Bandbreite",@"⇧F2",@"Noch keine bestätigte native Wirkung; deaktiviert.",NO,NO,NO,YES,0,0,0,1,120,1},
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
