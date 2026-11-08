// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
static const MTFeatureInfo catalog[MTFeatureCount]={
 {@"Sättigung maximieren",@"F1",@"Hält die Sättigung des gesteuerten Zoi am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,122,0},
 {@"Hygiene maximieren",@"F2",@"Hält die Hygiene des gesteuerten Zoi am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,120,0},
 {@"Schlaf maximieren",@"F3",@"Hält das Schlafbedürfnis des gesteuerten Zoi am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,99,0},
 {@"Toilettenbedürfnis maximieren",@"F4",@"Hält das Toilettenbedürfnis am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,118,0},
 {@"Spaß maximieren",@"F5",@"Hält den Spaß am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,96,0},
 {@"Soziales maximieren",@"F6",@"Hält das Sozialbedürfnis am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,97,0},
 {@"Anerkennung maximieren",@"F7",@"Hält das Anerkennungsbedürfnis am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,98,0},
 {@"Energie maximieren",@"F8",@"Hält die Energie am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,100,0},
 {@"Bedürfnisverlust-Multiplikator",@"F9",@"Skaliert den gemessenen Bedürfnisverlust je Simulationsschritt.",YES,YES,NO,NO,0.5,0,5,0.1,101,0},
 {@"Karma maximieren",@"F10",@"Hält das Karma am ursprünglichen Maximum.",YES,NO,NO,NO,0,0,0,0,109,0},
 {@"Karma-Zuwachs-Multiplikator",@"F11",@"Multipliziert positiven Karma-Zuwachs.",YES,YES,NO,NO,2,1,100,0.5,103,0},
 {@"Ambitionen schnell abschließen",@"F12",@"Schließt die aktive Ambition einmalig über reguläre Missionsereignisse ab.",YES,NO,YES,NO,0,0,0,0,111,0},
 {@"Geld bearbeiten",@"⇧F1",@"Setzt das Guthaben des gesteuerten Haushalts einmalig.",YES,YES,YES,YES,100000,0,999999999,1000,122,NSEventModifierFlagShift},
 {@"Geld-Multiplikator",@"⇧F2",@"Multipliziert positiven Nettogeldzuwachs je Simulationsschritt des gesteuerten Haushalts.",YES,YES,NO,NO,2,1,100,0.5,120,NSEventModifierFlagShift},
 {@"Meow-Münzen bearbeiten",@"⇧F3",@"Setzt Meow-Münzen einmalig.",YES,YES,YES,YES,1000,0,999999999,100,99,NSEventModifierFlagShift},
 {@"Meow-Münzen-Multiplikator",@"⇧F4",@"Multipliziert positiven Nettozuwachs an Meow-Münzen je Simulationsschritt.",YES,YES,NO,NO,2,1,100,0.5,118,NSEventModifierFlagShift},
 {@"Unbegrenzte Fähigkeiten-EP",@"⇧F5",@"Gewährt beim Erlernen maximale Fähigkeiten-Erfahrung.",YES,NO,NO,NO,0,0,0,0,96,NSEventModifierFlagShift},
 {@"Fähigkeiten-EP-Multiplikator",@"⇧F6",@"Multipliziert neu gewonnene Fähigkeiten-Erfahrung.",YES,YES,NO,NO,2,1,100,0.5,97,NSEventModifierFlagShift},
 {@"Bewegungsgeschwindigkeit",@"⇧F7",@"Verändert die Bewegungsgeschwindigkeit des gesteuerten Zoi.",YES,YES,NO,NO,2,0.25,10,0.25,98,NSEventModifierFlagShift},
 {@"Spielgeschwindigkeit",@"⇧F8",@"Verändert die Geschwindigkeit der lokalen Simulation.",YES,YES,NO,NO,2.5,0.1,10,0.1,100,NSEventModifierFlagShift},
};
const MTFeatureInfo *MTFeatureInfoAt(MTFeature f){return f>=0&&f<MTFeatureCount?&catalog[f]:NULL;}
@implementation MTFeatureState @end
