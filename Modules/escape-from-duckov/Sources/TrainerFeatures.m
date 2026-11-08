// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
    {@"Unverwundbar",@"F1",@"Native Trefferunterdrückung ausschließlich für die lokale Figur.",YES,NO,NO,NO,0,0,0,0,kVK_F1,0},
    {@"Unbegrenztes Leben",@"F2",@"Füllt die lokale Gesundheit über den nativen Setter auf.",YES,NO,NO,NO,0,0,0,0,kVK_F2,0},
    {@"Unbegrenzte Ausdauer",@"F3",@"Eigener Verbrauchsmodifikator und bestätigte Ausdauerfüllung.",YES,NO,NO,NO,0,0,0,0,kVK_F3,0},
    {@"Unbegrenzte Nahrung",@"F4",@"Füllt Energie; eigener Modifikator stoppt den Verbrauch.",YES,NO,NO,NO,0,0,0,0,kVK_F4,0},
    {@"Unbegrenztes Wasser",@"F5",@"Füllt Wasser; eigener Modifikator stoppt den Verbrauch.",YES,NO,NO,NO,0,0,0,0,kVK_F5,0},
    {@"Kein Nachladen",@"F6",@"Hält das geladene Magazin voll. Benötigt eine lokal gehaltene Waffe mit gewählter Munition.",YES,NO,NO,NO,0,0,0,0,kVK_F6,0},
    {@"Sofort nachladen",@"F7",@"Eigener Modifikator setzt die native Nachladezeit auf 0,01 Sekunden.",YES,NO,NO,NO,0,0,0,0,kVK_F7,0},
    {@"Kein Tragegewicht",@"F8",@"Setzt ausschließlich das Gewicht eigener Gegenstände vorübergehend auf 0.",YES,NO,NO,NO,0,0,0,0,kVK_F8,0},
    {@"Garantierte kritische Treffer",@"F9",@"Eigene Modifikatoren erhöhen die kritische Trefferchance für Schuss- und Nahkampf.",YES,NO,NO,NO,0,0,0,0,kVK_F9,0},
    {@"Superschaden",@"F10",@"Eigene Schuss- und Nahkampfschadensfaktoren von 1000.",YES,NO,NO,NO,0,0,0,0,kVK_F10,0},
    {@"Schaden ×",@"F11",@"Eigene Multiplikatoren für Schuss- und Nahkampfschaden.",YES,YES,NO,NO,2,0.1,100,0.1,kVK_F11,0},
    {@"Rüstung ×",@"F12",@"Eigener Multiplikator für Kopf- und Körperrüstung.",YES,YES,NO,NO,2,0.1,100,0.1,kVK_F12,0},
    {@"Geld setzen",@"⌘F1",@"Explizite native Einmalaktion; kann normal vom Spiel gespeichert werden.",YES,YES,YES,YES,9999999,0,1000000000000.0,1000,kVK_F1,NSEventModifierFlagCommand},
    {@"Geldgewinn ×",@"⌘F2",@"Multipliziert neue positive Geldeinnahmen über das native Geldereignis.",YES,YES,NO,NO,2,1,100,0.5,kVK_F2,NSEventModifierFlagCommand},
    {@"Gewählten Stapel setzen",@"⌘F3",@"Eigenen Stapel im Inventar auswählen. Native Stapelgrenze gilt; explizite Einmalaktion.",YES,YES,YES,YES,99,1,99999,1,kVK_F3,NSEventModifierFlagCommand},
    {@"Unbegrenzte Haltbarkeit",@"⌘F4",@"Füllt die Haltbarkeit eigener Ausrüstung ohne deren Verschleißgrenze zu verändern.",YES,NO,NO,NO,0,0,0,0,kVK_F4,NSEventModifierFlagCommand},
    {@"Sofort durchsuchen",@"⌘F5",@"Schließt die laufende native Untersuchung in der geöffneten Beutekiste ab.",YES,NO,NO,NO,0,0,0,0,kVK_F5,NSEventModifierFlagCommand},
    {@"Keine Herstellungs-/Forschungskosten",@"⌘F6",@"Entfernt Kosten und Forschungslevelbedingungen im laufenden Prozess. Schaltet keine Rezepte oder Vorteile frei.",YES,NO,NO,NO,0,0,0,0,kVK_F6,NSEventModifierFlagCommand},
    {@"Sofort forschen",@"⌘F7",@"Native Forschungsdauer 0. Forschung weiterhin selbst starten und bestätigen.",YES,NO,NO,NO,0,0,0,0,kVK_F7,NSEventModifierFlagCommand},
    {@"Nebel aus",@"⌘F8",@"Entfernt die native Nebeldarstellung und aktiviert Rundumsicht (50 m). Deckt keine Kartenfortschritte auf.",YES,NO,NO,NO,0,0,0,0,kVK_F8,NSEventModifierFlagCommand},
    {@"EP setzen",@"⌥F1",@"Explizite native Einmalaktion; kann normal vom Spiel gespeichert werden.",YES,YES,YES,YES,999999,0,1000000000.0,1000,kVK_F1,NSEventModifierFlagOption},
    {@"EP-Gewinn ×",@"⌥F2",@"Multipliziert nur neue positive EP über das native EP-Ereignis.",YES,YES,NO,NO,2,1,100,0.5,kVK_F2,NSEventModifierFlagOption},
    {@"Bewegung ×",@"⌥F3",@"Eigene Modifikatoren für Geh- und Laufgeschwindigkeit.",YES,YES,NO,NO,2,0.25,5,0.1,kVK_F3,NSEventModifierFlagOption},
    {@"Spielgeschwindigkeit ×",@"⌥F4",@"Zeitfaktor nach dem nativen Update; Pause und Bullet-Time bleiben maßgeblich.",YES,YES,NO,NO,2.5,0.25,4,0.1,kVK_F4,NSEventModifierFlagOption},
    {@"Sichtfeld",@"⌥F5",@"Setzt das native Kamera-Sichtfeld einschließlich Zielen.",YES,YES,NO,YES,40,20,100,1,kVK_F5,NSEventModifierFlagOption},
    {@"Tageszeit anhalten",@"⌥F6",@"Hält die native Spieluhr an; unabhängig von der Spielgeschwindigkeit.",YES,NO,NO,NO,0,0,0,0,kVK_F6,NSEventModifierFlagOption},
    {@"Tageszeittempo",@"⌥F7",@"Nativer Spieluhrfaktor. Tageszeit anhalten hat Vorrang.",YES,YES,NO,NO,0.5,0,100,0.5,kVK_F7,NSEventModifierFlagOption},
    {@"Maximales Leben",@"⇧F1",@"Eigener Modifikator für den maximalen Lebenswert.",YES,YES,NO,YES,999,1,100000,100,kVK_F1,NSEventModifierFlagShift},
    {@"Maximale Ausdauer",@"⇧F2",@"Eigener Modifikator für den maximalen Ausdauerwert.",YES,YES,NO,YES,999,1,100000,100,kVK_F2,NSEventModifierFlagShift},
    {@"Begleiter-Inventarplätze",@"⇧F3",@"Nur der tatsächliche lokale Begleiter; belegte Plätze werden niemals entfernt.",YES,YES,NO,YES,5,1,200,1,kVK_F3,NSEventModifierFlagShift},
    {@"Maximales Tragegewicht",@"⇧F4",@"Eigener Modifikator für die native Traglastgrenze.",YES,YES,NO,YES,9999,1,100000,100,kVK_F4,NSEventModifierFlagShift},
    {@"Spieler-Inventarplätze",@"⇧F5",@"Eigener Kapazitätsmodifikator. Belegte Zusatzplätze bleiben bis zum Leeren erhalten.",YES,YES,NO,YES,50,1,200,1,kVK_F5,NSEventModifierFlagShift},
    {@"Ausdauerverbrauch ×",@"⇧F6",@"Eigener Verbrauchsfaktor; unbegrenzte Ausdauer hat Vorrang.",YES,YES,NO,NO,0.5,0,10,0.1,kVK_F6,NSEventModifierFlagShift},
    {@"Nahrungsverbrauch ×",@"⇧F7",@"Eigener Verbrauchsfaktor; unbegrenzte Nahrung hat Vorrang.",YES,YES,NO,NO,0.5,0,10,0.1,kVK_F7,NSEventModifierFlagShift},
    {@"Wasserverbrauch ×",@"⇧F8",@"Eigener Verbrauchsfaktor; unbegrenztes Wasser hat Vorrang.",YES,YES,NO,NO,0.5,0,10,0.1,kVK_F8,NSEventModifierFlagShift},
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature){return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL;}
@implementation MTFeatureState @end
