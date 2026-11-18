// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const MTOverlayPreferencesKey;
FOUNDATION_EXPORT NSString *const MTOverlaySettingsNotification;
FOUNDATION_EXPORT NSString *const MTOverlayChangedNotification;
NSDictionary *MTNormalizeOverlayOptions(id input);
// A new game session starts with a hidden panel and interactive input on open.
NSDictionary *MTOverlayOptionsForLaunch(id input);
NSString *MTEncodeOverlayOptions(NSDictionary *options);
NSDictionary *MTDecodeOverlayOptions(NSString *json);
// Use an object string with userInfo:nil, including when sending from the MAS sandbox.
NSString *MTOverlayMessage(NSDictionary *options, NSString *session, int pid);
NSDictionary *MTOverlayMessageOptions(id message, NSString *session, int pid);
