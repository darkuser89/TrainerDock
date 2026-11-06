// SPDX-License-Identifier: GPL-3.0-only
#import "MHTModule.h"
// Read-only discovery; no game or store process is launched.
void MHTDiscoverInstallations(NSArray<MHTModule *> *modules);
// Worker scan returns candidates only. Apply on the UI thread, rechecking paths.
NSDictionary<NSString *,NSString *> *MHTFindInstallations(NSArray<MHTModule *> *modules,BOOL (^cancelled)(void));
BOOL MHTApplyInstallations(NSArray<MHTModule *> *modules,NSDictionary<NSString *,NSString *> *found);
BOOL MHTIsInstalled(MHTModule *module, NSDictionary *profile);
