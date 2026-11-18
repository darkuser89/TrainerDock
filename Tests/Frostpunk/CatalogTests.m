// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "TrainerFeatures.h"
#import "SelectionSettings.h"
#include <math.h>
#include <stdlib.h>

static void check(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"Frostpunk-Katalogprüfung fehlgeschlagen: %@", message); exit(1); }
}
static BOOL resourceAction(NSInteger feature) {
    return feature <= MTFeatureProstheses ||
        (feature >= MTFeatureStructuralProfiles && feature <= MTFeatureSteamExchangers);
}
static NSDictionary *selection(NSInteger feature, id value) {
    return MTNormalizeCheatSelection(@{@"features":@{
        [NSString stringWithFormat:@"%ld", (long)feature]:@{@"wanted":@YES,@"value":value}}});
}
static NSDictionary *entry(NSDictionary *selection, NSInteger feature) {
    return selection[@"features"][[NSString stringWithFormat:@"%ld", (long)feature]];
}
void MHTFrostpunkCatalogContractTests(void) {
    check(MTFeatureCount == 15 && MTFeatureStorage == 6 && MTFeatureGameSpeed == 14,
          @"Stabile gespeicherte Funktions-IDs");
    check(MTFeatureInfoAt((MTFeature)-1) == NULL && MTFeatureInfoAt(MTFeatureCount) == NULL,
          @"Unbekannte Funktions-IDs dürfen keinen Katalogeintrag liefern");
    NSMutableDictionary *all = [NSMutableDictionary new];
    for (NSInteger feature = 0; feature < MTFeatureCount; feature++) {
        const MTFeatureInfo *info = MTFeatureInfoAt(feature);
        check(info && info->title.length && info->detail.length, @"Vollständiger Katalogtext");
        check(info->oneShot == resourceAction(feature), @"Ressourcenaktionen niemals als Dauereffekt speichern");
        check(info->numeric == (resourceAction(feature) || feature == MTFeatureGameSpeed),
              @"Nur Ressourcen und Tempo besitzen einen Zahlenwert");
        if (info->numeric) {
            check(isfinite(info->initial) && isfinite(info->minimum) && isfinite(info->maximum) &&
                  info->step > 0 && info->minimum > 0 && info->minimum <= info->initial &&
                  info->initial <= info->maximum, @"Endliche und positive Mengen-/Tempogrenzen");
            for (NSNumber *invalid in @[@(NAN), @(INFINITY), @(-INFINITY), @(info->minimum - 1), @(info->maximum + 1)])
                check([entry(selection(feature, invalid), feature)[@"value"] doubleValue] == info->initial,
                      @"Nichtendliche oder zu große Werte dürfen nicht ins Spiel gelangen");
        }
        if (resourceAction(feature)) {
            check(info->integer && floor(info->initial) == info->initial,
                  @"Nur ganze Ressourcenmengen");
            check([entry(selection(feature, @1.5), feature)[@"value"] doubleValue] == info->initial,
                  @"Bruchteile dürfen keine Ressourcenaktion auslösen");
            check([entry(selection(feature, @(info->minimum)), feature)[@"value"] doubleValue] == info->minimum &&
                  [entry(selection(feature, @(info->maximum)), feature)[@"value"] doubleValue] == info->maximum,
                  @"Gültige Mengengrenzen bleiben erhalten");
        }
        all[[NSString stringWithFormat:@"%ld", (long)feature]] = @{@"wanted":@YES,@"value":@(info->initial)};
    }
    all[@"999"] = @{@"wanted":@YES,@"value":@1};
    NSDictionary *clean = MTDecodeCheatSelection(MTEncodeCheatSelection(@{@"features":all}));
    check([clean[@"features"] count] == MTFeatureCount && !clean[@"features"][@"999"],
          @"Unbekannte gespeicherte Funktionen ignorieren");
    for (NSInteger feature = 0; feature < MTFeatureCount; feature++) {
        const MTFeatureInfo *info = MTFeatureInfoAt(feature);
        BOOL expected = info->implemented && !info->oneShot;
        check([entry(clean, feature)[@"wanted"] boolValue] == expected,
              @"Wiederherstellung darf niemals Ressourcen erneut hinzufügen");
    }
    check(!MTFeatureInfoAt(MTFeatureGameSpeed)->integer &&
          [entry(selection(MTFeatureGameSpeed, @1.25), MTFeatureGameSpeed)[@"value"] doubleValue] == 1.25,
          @"Spieltempo bleibt ein nicht ganzzahliger Faktor");
    NSString *message = MTSelectionMessage(clean, @"test-session", @"steam-test", 123);
    check(MTSelectionMessageSelection(message, @"test-session", @"steam-test", 123) != nil,
          @"Passende Auswahlmeldung wird angenommen");
    check(!MTSelectionMessageSelection(message, @"other-session", @"steam-test", 123) &&
          !MTSelectionMessageSelection(message, @"test-session", @"other-profile", 123) &&
          !MTSelectionMessageSelection(message, @"test-session", @"steam-test", 124),
          @"Auswahlmeldungen anderer Besitzer werden verworfen");
    NSLog(@"Frostpunk-Katalog und Auswahlgrenzen geprüft; keine Ingame-Prüfung.");
}
