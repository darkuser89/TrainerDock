// SPDX-License-Identifier: GPL-3.0-only
#import "GameBridge.h"
FOUNDATION_EXPORT NSString *const RE2RestoreCheatsKey;
FOUNDATION_EXPORT NSString *const RE2SelectionChangedNotification;
NSString *RE2SelectionKey(NSString *profile);
NSString *RE2CurrentSelectionProfile(void);
NSInteger RE2SelectionCount(NSString *profile);
NSDictionary *RE2NormalizeSelection(id input,NSString *profile);
NSDictionary *RE2SelectionFromState(RE2TrainerState *state,NSString *profile);
NSString *RE2EncodeSelection(NSDictionary *selection);
NSDictionary *RE2DecodeSelection(id json,NSString *profile);
NSString *RE2SelectionMessage(NSDictionary *selection,NSString *session,int pid);
NSDictionary *RE2SelectionMessageOptions(id json,NSString *profile,NSString *session,int pid);
