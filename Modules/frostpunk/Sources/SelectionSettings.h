// SPDX-License-Identifier: GPL-3.0-only
#import "GameBridge.h"

FOUNDATION_EXPORT NSString *const MTSelectionRestorePreferencesKey;
FOUNDATION_EXPORT NSString *const MTSelectionChangedNotification;
NSString *MTSelectionPreferencesKey(NSString *profile);
NSDictionary *MTNormalizeCheatSelection(id input);
NSDictionary *MTSelectionFromState(MTTrainerState *state);
NSString *MTEncodeCheatSelection(id input);
NSDictionary *MTDecodeCheatSelection(NSString *json);
NSString *MTSelectionMessage(id selection, NSString *session, NSString *profile, int pid);
NSDictionary *MTSelectionMessageSelection(id message, NSString *session, NSString *profile, int pid);
