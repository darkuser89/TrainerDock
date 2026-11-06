// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, DI2GameEdition) { DI2EditionUnknown, DI2EditionMAS, DI2EditionSteam };
DI2GameEdition DI2EditionForKey(NSString *key);
DI2GameEdition DI2EditionForUUID(const uint8_t *uuid);
NSString *DI2EditionKey(DI2GameEdition edition);
NSString *DI2EditionTitle(DI2GameEdition edition);
NSString *DI2EditionBundleID(DI2GameEdition edition);
NSString *DI2EditionDefaultPath(DI2GameEdition edition);
NSString *DI2SteamDefaultPathFromRoot(NSString *steamRoot);
NSString *DI2EditionUUID(DI2GameEdition edition);
// Read-only preflight: exact bundle identity, executable name, arm64 Mach-O UUID.
NSDictionary *DI2InspectGame(NSString *path, DI2GameEdition edition, NSError **error);
