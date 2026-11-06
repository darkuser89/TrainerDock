// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "TrainerFeatures.h"
FOUNDATION_EXPORT NSString *const MTSelectionChangedNotification;
NSDictionary *MTNormalizeSelection(id input);
NSDictionary *MTSelectionForFeatures(NSArray<MTFeatureState *> *features);
NSString *MTEncodeSelection(id input);
NSDictionary *MTDecodeSelection(id input);
NSDictionary *MTLoadSelection(NSUserDefaults *preferences,NSString *profile);
BOOL MTShouldRestoreSelection(NSUserDefaults *preferences,NSString *profile);
void MTSetRestoreSelection(NSUserDefaults *preferences,NSString *profile,BOOL enabled);
NSDictionary *MTLoadLaunchSelection(NSUserDefaults *preferences,NSString *profile);
void MTSaveSelection(NSUserDefaults *preferences,NSString *profile,id selection);
NSString *MTSelectionMessage(id selection,NSString *session,int pid);
NSDictionary *MTSelectionMessageValue(id message,NSString *session,int pid);
