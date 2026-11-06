// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
_Static_assert(MTFeatureCount==17,"RoboCop Plus 17 catalog");
#define SWITCH(title,key,code,detail) {title,key,detail,YES,NO,NO,NO,0,0,0,0,code,0}
#define FACTOR(title,key,code,mods,initial,min,max,detail) {title,key,detail,YES,YES,NO,NO,initial,min,max,0.1,code,mods}
static const MTFeatureInfo catalog[MTFeatureCount]={
 {@"Unverwundbarkeit",@"F1",@"Native Schadensannahme des lokalen Spielers ausschalten und beim Deaktivieren wiederherstellen.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Unendliche Gesundheit",@"F2",@"Gesundheit nativ auf Maximum halten. Unverwundbarkeit schützt zusätzlich vor tödlichem Einzelschaden.",YES,NO,NO,NO,0,0,0,0,120,0},
 {@"Unendliche Munition",@"F3",@"Native unendliche Reserve der ausgerüsteten Spielerwaffe; Nachladen bleibt möglich.",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Kein Nachladen",@"F7",@"Verhindert native Magazinabnahme und Nachladen. Funktioniert getrennt von unendlicher Reserve.",YES,NO,NO,NO,0,0,0,0,98,0},
 {@"Schnellfeuer",@"F8",@"Vierfache native Feuerrate der eigenen Waffe; Originalwert beim Ausschalten wiederherstellen.",YES,NO,NO,NO,0,0,0,0,100,0},
 {@"Superpräzision",@"F9",@"Deaktiviert native Geschossstreuung einschließlich zusätzlicher Schrotprojektile.",YES,NO,NO,NO,0,0,0,0,101,0},
 {@"Kein Rückstoß",@"F10",@"Deaktiviert Waffenrückstoß und Schuss-Kameraerschütterung der eigenen Waffe.",YES,NO,NO,NO,0,0,0,0,109,0},
 {@"One-Hit-Kills",@"⌃F1",@"Aktiviert die native One-Hit-Kill-Abfrage für Spielerwaffen. Geskriptete Unverwundbarkeit bleibt Sache des Spiels.",YES,NO,NO,NO,0,0,0,0,122,NSEventModifierFlagControl},
 FACTOR(@"Schaden ×",@"⌃F2",120,NSEventModifierFlagControl,2,0.1,100,@"Multipliziert den nativen Trefferschaden der eigenen Waffe ohne wiederholtes Aufmultiplizieren."),
 FACTOR(@"Verteidigung ×",@"⌃F3",99,NSEventModifierFlagControl,2,0.1,100,@"Teilt eingehenden Schaden durch diesen Faktor; eigene Änderung wird beim Ausschalten gelöst."),
 {@"Unendliche XP",@"F6",@"Einmalig genügend XP für das native Maximallevel vergeben. XP und Skillpunkte können gespeichert werden.",YES,NO,YES,NO,0,0,0,0,97,0},
 FACTOR(@"XP ×",@"⌃F4",118,NSEventModifierFlagControl,2,0.1,100,@"Multipliziert neu verdiente XP über das native Fortschrittsattribut; kein wiederholter XP-Zuschlag."),
 {@"Skillpunkte setzen",@"F5",@"Einmalige native Änderung. Skillpunkte können gespeichert werden.",YES,YES,YES,YES,99,0,999999999,1,96,0},
 FACTOR(@"Bewegung ×",@"F4",118,0,2,0.25,4,@"Faktor für Gehen, Sprinten und Ducken; unabhängig von persönlicher und globaler Zeit."),
 FACTOR(@"Spielergeschwindigkeit ×",@"⌃F5",96,NSEventModifierFlagControl,2,0.1,4,@"Persönliche Zeit des lokalen Spielers: Bewegung und Animationen. Originalzeit wird wiederhergestellt."),
 FACTOR(@"KI-Geschwindigkeit ×",@"⌃F6",97,NSEventModifierFlagControl,0.1,0.1,4,@"Persönliche Zeit der KI-Figuren und ihrer Controller in der aktuellen Welt. Neue Besitzer werden erfasst."),
 FACTOR(@"Spielgeschwindigkeit ×",@"⌃F7",98,NSEventModifierFlagControl,2.5,0.1,4,@"Native globale Zeitsteuerung; vorherigen Wert beim Ausschalten wiederherstellen.")
};
#undef SWITCH
#undef FACTOR
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature) { return feature>=0 && feature<MTFeatureCount ? &catalog[feature] : NULL; }
@implementation MTFeatureState
@end
