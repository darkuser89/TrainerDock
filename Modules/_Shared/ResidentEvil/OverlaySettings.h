// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const RE2OverlayPreferencesKey;
FOUNDATION_EXPORT NSString *const RE2OverlaySettingsNotification;
FOUNDATION_EXPORT NSString *const RE2OverlayChangedNotification;
NSDictionary *RE2NormalizeOverlayOptions(id input);
NSDictionary *RE2OverlayOptionsForLaunch(id input);
NSString *RE2EncodeOverlayOptions(NSDictionary *options);
NSDictionary *RE2DecodeOverlayOptions(NSString *json);
// Use an object string with userInfo:nil, including when sending from the MAS sandbox.
NSString *RE2OverlayMessage(NSDictionary *options, NSString *session, int pid);
NSDictionary *RE2OverlayMessageOptions(id message, NSString *session, int pid);
