// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
// Native NMS bindings are isolated from the explicitly labeled simulation.
_Static_assert(MTFeatureCount>0 && MTFeatureCount<=30,"Overlay supports 1 through 30 catalog entries.");
static const MTFeatureInfo catalog[MTFeatureCount]={
 {@"Kein Gesundheitsschaden",@"F1",@"TakeNoDamage: nativer Schalter. Kein Schutzversprechen gegen alle Todesursachen; Wirkung ungeprüft.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Unbegrenzte Ausdauer",@"F2",@"InfiniteStamina: nativer Schalter; Wirkung im Spiel noch ungeprüft.",YES,NO,NO,NO,0,0,0,0,120,0},
 {@"Lebenserhaltung ohne Verbrauch",@"F3",@"UseEnergy deaktivieren; Originalwert wird beim Ausschalten zurückgegeben.",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Sprintfaktor",@"F4",@"Nativer SprintMultiplier. Zahlenwert ist der absolute Faktor, keine Spielgeschwindigkeit.",YES,YES,NO,NO,2,0.25,4,0.25,118,0},
 {@"Units hinzufügen",@"F5",@"Einmal AwardUnits mit Rückleseprüfung. Diese Gabe kann im Spielstand gespeichert werden.",YES,YES,YES,YES,1000,0,999999999,1000,96,0},
 {@"Naniten +100",@"F6",@"Einmal AwardNanites(100). Kann gespeichert werden; keine automatische Wiederholung.",YES,NO,YES,NO,0,0,0,0,97,0},
 {@"Gefahrenschutz ohne Verbrauch",@"F7",@"UseHazardProtection deaktivieren; ursprünglichen Schalter beim Ausschalten wiederherstellen.",YES,NO,NO,NO,0,0,0,0,98,0},
 {@"Alien-Sprache lesbar",@"F8",@"DoAlienLanguage deaktivieren. Keine Wörter in den Spielstand schreiben; Wirkung ungeprüft.",YES,NO,NO,NO,0,0,0,0,100,0},
 {@"Quecksilber +",@"F9",@"Einmal AwardSpecials. Kann dauerhaft gespeichert werden; keine automatische Wiederholung.",YES,YES,YES,YES,1000,0,999999999,1000,101,0} ,
 {@"Unbegrenzter Schild",@"⌥F1",@"Schildwert des lokalen Spielers auf das native Maximum auffüllen.",YES,NO,NO,NO,0,0,0,0,122,2},
 {@"Jetpack ohne Verbrauch",@"⌥F2",@"Nativen Jetpack-Tank des lokalen Spielers auffüllen.",YES,NO,NO,NO,0,0,0,0,120,2},
 {@"Multi-Tool ohne Überhitzen",@"⌥F3",@"Wärme des aktuell geführten Multi-Tools zurücksetzen.",YES,NO,NO,NO,0,0,0,0,99,2},
 {@"Kein Nachladen",@"⌥F4",@"Magazin der aktuell geführten Waffe mit nativer SetAmmo-Funktion auffüllen.",YES,NO,NO,NO,0,0,0,0,118,2},
 {@"Unbegrenzte Granaten",@"⌥F5",@"Vorhandene Granaten-Technologien nativ aufladen; keine Ausrüstung erzeugen.",YES,NO,NO,NO,0,0,0,0,96,2},
 {@"Unbegrenzte Gegenstände",@"⌥F6",@"Vorhandene Ressourcen und Produkte bis zur zulässigen Stapelgröße auffüllen. Kann gespeichert werden.",YES,NO,NO,NO,0,0,0,0,97,2},
 {@"Herstellen ohne Material",@"⌥F7",@"Native CraftingIsFree-Freigabe. Bekannte Rezepte bleiben erforderlich.",YES,NO,NO,NO,0,0,0,0,98,2},
 {@"Extremer Schaden",@"⌥F8",@"Nativer Schalter SuperKillGuns; genaue Wirkung noch ungeprüft.",YES,NO,NO,NO,0,0,0,0,100,2},
 {@"Raumschiff: Gesundheit",@"⌥F9",@"Gesundheit des aktuellen eigenen Schiffs auf das native Maximum auffüllen.",YES,NO,NO,NO,0,0,0,0,101,2},
 {@"Raumschiff: Schild",@"⌥F10",@"Vorhandenen Schild des eigenen Schiffs über native Inventar-Handles auffüllen.",YES,NO,NO,NO,0,0,0,0,109,2},
 {@"Raumschiff: keine Überhitzung",@"⌥F11",@"Native Überhitzungszeiten verlängern. Keine fremden Schiffsobjekte bearbeiten.",YES,NO,NO,NO,0,0,0,0,103,2},
 {@"Unbegrenzte Units",@"⌥F12",@"Nativen Mindestbestand von 999999999 Units halten. Kann gespeichert werden.",YES,NO,NO,NO,0,0,0,0,111,2},
 {@"Spielgeschwindigkeit",@"⇧F1",@"Engine-Zeitskala der lokalen cTkClock; ursprünglichen Faktor beim Ausschalten wiederherstellen.",YES,YES,NO,NO,2.5,0.25,4,0.25,122,1},
 {@"Schlösser ohne Atlas-Pass",@"⇧F2",@"Native ACCESS1/2/3-Produktanforderungen aufheben; Originalanforderungen beim Ausschalten wiederherstellen. Keine Pässe erzeugen.",YES,NO,NO,NO,0,0,0,0,120,1},
 {@"Unbegrenzte Naniten",@"⇧F3",@"Nativen Mindestbestand von 999999999 Naniten halten. Kann gespeichert werden.",YES,NO,NO,NO,0,0,0,0,99,1},
 {@"Unbegrenztes Quecksilber",@"⇧F4",@"Nativen Mindestbestand von 999999999 Quecksilber halten. Kann gespeichert werden.",YES,NO,NO,NO,0,0,0,0,118,1},
 {@"Startschubdüse: Energie",@"⇧F5",@"Vorhandene Startschubdüsen-Technologie nativ aufladen; keine Reparatur.",YES,NO,NO,NO,0,0,0,0,96,1},
 {@"Impulsantrieb: Energie",@"⇧F6",@"Vorhandenen Impulsantrieb nativ aufladen; keine Reparatur.",YES,NO,NO,NO,0,0,0,0,97,1},
 {@"Hyperantrieb: Energie",@"⇧F7",@"Vorhandenen Hyperantrieb nativ aufladen; keine Reparatur.",YES,NO,NO,NO,0,0,0,0,98,1},
 {@"Scanner sofort bereit",@"⇧F8",@"Nativen Ladefortschritt des persönlichen Scanners auffüllen.",YES,NO,NO,NO,0,0,0,0,100,1},
 {@"Multi-Tool: Energie",@"⇧F10",@"Vorhandene aktive Multi-Tool-Technologie nativ aufladen.",YES,NO,NO,NO,0,0,0,0,109,1}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature) { return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL; }
@implementation MTFeatureState
@end
