// SPDX-License-Identifier: GPL-3.0-only
#import "GameBridge.h"

FOUNDATION_EXPORT NSString *const DI2SelectionRestorePreferencesKey;
FOUNDATION_EXPORT NSString *const DI2SelectionChangedNotification;
NSString *DI2SelectionPreferencesKey(NSString *profile);
NSDictionary *DI2NormalizeCheatSelection(id input);
NSDictionary *DI2SelectionFromState(DI2TrainerState *state);
NSString *DI2EncodeCheatSelection(id input);
NSDictionary *DI2DecodeCheatSelection(NSString *json);
NSString *DI2SelectionMessage(id selection, NSString *session, NSString *profile, int pid);
NSDictionary *DI2SelectionMessageSelection(id message, NSString *session, NSString *profile, int pid);
