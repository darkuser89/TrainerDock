// SPDX-License-Identifier: GPL-3.0-only
#import "MHTBranding.h"

NSDictionary *MHTMergedLegacyPreferences(NSDictionary *legacy, NSDictionary *current) {
    NSMutableDictionary *merged=[current mutableCopy] ?: [NSMutableDictionary new];
    for(NSString *key in legacy) {
        if([key hasPrefix:@"MHT."] && !merged[key])merged[key]=legacy[key];
    }
    return merged;
}

void MHTMigrateLegacyPreferences(void) {
    NSString *domain=@"local.trainerdock.launcher",*marker=@"TrainerDock.migratedMHTPreferences";
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:domain])return;
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    NSDictionary *current=[defaults persistentDomainForName:domain] ?: @{};
    if([current[marker] boolValue])return;
    NSDictionary *legacy=[defaults persistentDomainForName:@"local.mht.launcher"] ?: @{};
    NSMutableDictionary *merged=[MHTMergedLegacyPreferences(legacy,current) mutableCopy];
    merged[marker]=@YES;
    [defaults setPersistentDomain:merged forName:domain];
}
