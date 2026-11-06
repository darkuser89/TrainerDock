// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import "OverlayShortcuts.h"
_Static_assert(MTFeatureCount==36,"Lies of P catalog");
static const MTFeatureInfo catalog[MTFeatureCount]={
 {@"Unbegrenzte Gesundheit",@"⌃⇧2",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,19,MTTrainerModifiers},
 {@"Unbegrenzte Ausdauer",@"⌃⇧3",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,20,MTTrainerModifiers},
 {@"Unbegrenzte Legion",@"⌃⇧4",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,21,MTTrainerModifiers},
 {@"Ein Treffer tötet",@"⌃⇧5",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,23,MTTrainerModifiers},
 {@"Unbegrenzte Pulszellen",@"⌃⇧6",@"Pulszellen fortlaufend auffüllen; die Mengen können vom Spiel gespeichert werden.",YES,NO,NO,NO,0,0,0,0,22,MTTrainerModifiers},
 {@"Spielzeit einfrieren",@"⌃⇧7",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,26,MTTrainerModifiers},
 {@"Erhöhtes Spielertempo",@"⌃⇧8",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,28,MTTrainerModifiers},
 {@"KI verlangsamen",@"⌃⇧9",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,25,MTTrainerModifiers},
 {@"Erhöhtes Bewegungstempo",@"⌃⇧0",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,29,MTTrainerModifiers},
 {@"Koordinaten speichern",@"⌃⇧A",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,YES,NO,0,0,0,0,0,MTTrainerModifiers},
 {@"Zur gespeicherten Position teleportieren",@"⌃⇧B",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,YES,NO,0,0,0,0,11,MTTrainerModifiers},
 {@"Unbegrenzte Gegenstandsnutzung",@"⌃⇧C",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,8,MTTrainerModifiers},
 {@"Unbegrenztes Ergo",@"⌃⇧D",@"Ergo auf 999999999 halten; dieser Betrag kann gespeichert werden.",YES,NO,NO,NO,0,0,0,0,2,MTTrainerModifiers},
 {@"Schleichmodus",@"⌃⇧E",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,NO,NO,NO,0,0,0,0,14,MTTrainerModifiers},
 {@"Menge des gewählten Gegenstands",@"⌃⇧F",@"Gewählter Schnellzugriffs-Gegenstand; nur eigene Inventarobjekte, maximal dessen erlaubter Stapel.",YES,YES,YES,YES,1,1,9999,1,3,MTTrainerModifiers},
 {@"Ergo-Faktor",@"⌃⇧G",@"Nur im bestätigten Einzelspieler-Kontext; grün nach Rücklesen.",YES,YES,NO,NO,2,1,100,0.5,5,MTTrainerModifiers},
 {@"Spielertempo-Faktor",@"⌃⇧H",@"Eigener Faktor; allein oder zusammen mit dem zugehörigen Super-Schalter aktivieren. Faktoren werden nicht verdoppelt.",YES,YES,NO,NO,2,0.1,10,0.1,4,MTTrainerModifiers},
 {@"KI-Tempo-Faktor",@"⌃⇧I",@"Eigener Faktor; allein oder zusammen mit dem zugehörigen Super-Schalter aktivieren. Faktoren werden nicht verdoppelt.",YES,YES,NO,NO,0.25,0.05,5,0.05,34,MTTrainerModifiers},
 {@"Bewegungstempo-Faktor",@"⌃⇧J",@"Eigener Faktor; allein oder zusammen mit dem zugehörigen Super-Schalter aktivieren. Faktoren werden nicht verdoppelt.",YES,YES,NO,NO,2,0.1,10,0.1,38,MTTrainerModifiers},
 {@"Aktuelle Gesundheit setzen",@"⌃⇧K",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,100,1,1000000,10,40,MTTrainerModifiers},
 {@"Max. Gesundheit setzen",@"⌃⇧L",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,500,1,1000000,10,37,MTTrainerModifiers},
 {@"Aktuelle Ausdauer setzen",@"⌃⇧M",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,100,0,1000000,10,46,MTTrainerModifiers},
 {@"Max. Ausdauer setzen",@"⌃⇧N",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,150,1,1000000,10,45,MTTrainerModifiers},
 {@"Aktuelle Legion setzen",@"⌃⇧O",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,100,0,1000000,10,31,MTTrainerModifiers},
 {@"Max. Legion setzen",@"⌃⇧P",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,150,1,1000000,10,35,MTTrainerModifiers},
 {@"Max. Traglast setzen",@"⌃⇧Q",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,1000,1,1000000,10,12,MTTrainerModifiers},
 {@"Feuerresistenz setzen",@"⌃⇧R",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,100,0,1000000,10,15,MTTrainerModifiers},
 {@"Elektroblitzresistenz setzen",@"⌃⇧S",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,100,0,1000000,10,1,MTTrainerModifiers},
 {@"Säureresistenz setzen",@"⌃⇧T",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,100,0,1000000,10,17,MTTrainerModifiers},
 {@"Spielzeit setzen",@"⌃⇧U",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,NO,0,0,315360000,60,32,MTTrainerModifiers},
 {@"Stufe setzen",@"⌃⇧V",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,10,1,561,1,9,MTTrainerModifiers},
 {@"Ergo setzen",@"⌃⇧W",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,1000,0,999999999,1000,13,MTTrainerModifiers},
 {@"Menschlichkeit setzen",@"⌃⇧X",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,YES,1,1,4,1,7,MTTrainerModifiers},
 {@"X-Koordinate setzen",@"⌃⇧Y",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,NO,0,-10000000,10000000,100,16,MTTrainerModifiers},
 {@"Y-Koordinate setzen",@"⌃⇧Z",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,NO,0,-10000000,10000000,100,6,MTTrainerModifiers},
 {@"Z-Koordinate setzen",@"⌃⇧-",@"Einmal mit LOS anwenden; kann vom Spiel gespeichert werden.",YES,YES,YES,NO,0,-10000000,10000000,100,27,MTTrainerModifiers},
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature) { return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL; }
@implementation MTFeatureState
@end
