// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
 {@"Infinite Health",@"F1",@"Verhindert Gesundheitsschaden über Controls native Unverwundbarkeit.",YES,NO,NO,NO,0,0,0,0,kVK_F1,0},
 {@"Infinite Energy",@"F2",@"Hält die lokale Fähigkeitsenergie gefüllt.",YES,NO,NO,NO,0,0,0,0,kVK_F2,0},
 {@"Infinite Ammo / No Reload",@"F3",@"Aktiviert das native Flag für unbegrenzte Waffenenergie.",YES,NO,NO,NO,0,0,0,0,kVK_F3,0},
 {@"Edit: Money",@"F4",@"Setzt die Quellenenergie einmalig.",YES,YES,YES,YES,9999999,0,999999999,1000,kVK_F4,0},
 {@"Edit: Skill Points",@"F5",@"Setzt die verfügbaren Fähigkeitspunkte einmalig.",YES,YES,YES,YES,99,0,9999,1,kVK_F5,0},
 {@"Infinite Materials",@"F6",@"Hält vorhandene eigene Herstellungsmaterialien bei mindestens 999. Beim Ausschalten werden unveränderte eigene Stapel zurückgesetzt.",YES,NO,NO,NO,0,0,0,0,kVK_F6,0},
 {@"Super Speed",@"F7",@"Erhöht die lokalen Bewegungsgrenzen; beim Ausschalten zurücksetzen.",YES,YES,NO,NO,2,1,4,.25,kVK_F7,0},
 {@"Slow Motion",@"F8",@"Regelt den nativen Zeitfaktor der Spielsimulation.",YES,YES,NO,NO,.5,.1,1,.1,kVK_F8,0},
 {@"One Hit Destroy Shield",@"F9",@"Zerstört einen feindlichen Schild nach dem ersten tatsächlich angenommenen Schildschaden.",YES,NO,NO,NO,0,0,0,0,kVK_F9,0},
 {@"One Hit Kill",@"F10",@"Setzt feindliche Lebenspunkte nach angenommenem Gesundheitsschaden auf null. Schildschaden allein löst keinen Kill aus.",YES,NO,NO,NO,0,0,0,0,kVK_F10,0},
 {@"No Crafting / Upgrading Requirements",@"F11",@"Entfernt Quellenenergie- und Materialkosten geladener Rezepte. Storyfreischaltungen bleiben erforderlich.",YES,NO,NO,NO,0,0,0,0,kVK_F11,0},
 {@"Money Multiplier",@"F12",@"Multipliziert neu erhaltene Quellenenergie. Setzen und Laden werden ausgenommen.",YES,YES,NO,NO,2,1,100,.5,kVK_F12,0}
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature f){return f>=0&&f<MTFeatureCount?&catalog[f]:NULL;}
@implementation MTFeatureState @end
