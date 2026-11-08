// SPDX-License-Identifier: GPL-3.0-only
#import "MHTModule.h"
// Read-only discovery; no game or store process is launched.
void MHTDiscoverInstallations(NSArray<MHTModule *> *modules);
// Store-separated keys prevent one bundle identifier from choosing both stores.
NSString *MHTInstallationKey(MHTModule *module, NSDictionary *profile);
// Reads bounded Epic .item files and installation metadata only; never accounts.
NSDictionary<NSString *,NSString *> *MHTFindEpicInstallations(NSArray<MHTModule *> *modules, NSString *manifestDirectory, BOOL (^cancelled)(void));
// Worker scan returns candidates only. Apply on the UI thread, rechecking paths.
NSDictionary<NSString *,NSString *> *MHTFindInstallations(NSArray<MHTModule *> *modules,BOOL (^cancelled)(void));
BOOL MHTApplyInstallations(NSArray<MHTModule *> *modules,NSDictionary<NSString *,NSString *> *found);
BOOL MHTIsInstalled(MHTModule *module, NSDictionary *profile);
