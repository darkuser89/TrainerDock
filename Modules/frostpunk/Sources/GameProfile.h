// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
NSDictionary *MTLoadConfiguration(NSString *path,NSError **error);
NSDictionary *MTFindProfile(NSDictionary *configuration,NSString *identifier);
NSDictionary *MTReadExecutableIdentity(NSString *path);
NSDictionary *MTInspectGame(NSString *path,NSDictionary *profile,NSError **error);
BOOL MTCurrentProcessMatches(NSDictionary *profile,NSString *target);
