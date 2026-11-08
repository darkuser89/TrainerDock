// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
// GitHub metadata is untrusted input. Only stable, newer releases of our repository qualify.
NSDictionary *MHTNewRelease(NSDictionary *json,NSString *current,NSError **error);
BOOL MHTVerifyUpdateArchive(NSURL *archive,NSDictionary *release,NSError **error);
BOOL MHTExtractUpdate(NSURL *archive,NSURL *directory,NSError **error);
BOOL MHTValidateUpdateApp(NSURL *app,NSString *version,NSError **error);
BOOL MHTSwapUpdate(NSURL *current,NSURL *candidate,NSError **error);
BOOL MHTPreserveBundledTrainers(NSURL *current,NSString *storeDirectory,NSError **error);
int MHTApplyUpdate(NSString *planPath);
