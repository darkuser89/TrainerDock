// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
BOOL MHTTrainerVerifyArchive(NSURL *archive,NSDictionary *version,NSError **error);
BOOL MHTTrainerExtractArchive(NSURL *archive,NSURL *destination,NSString *identifier,NSError **error);
BOOL MHTTrainerValidatePackage(NSURL *package,NSDictionary *version,NSString *identifier,NSError **error);
