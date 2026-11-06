// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const DI2OverlayPreferencesKey;
FOUNDATION_EXPORT NSString *const DI2OverlaySettingsNotification;
FOUNDATION_EXPORT NSString *const DI2OverlayChangedNotification;
NSDictionary *DI2NormalizeOverlayOptions(id input);
// New game processes start hidden with mouse interaction ready for opening.
// Placement and size survive; last-session visibility/mouse state does not.
NSDictionary *DI2InitialOverlayOptions(id input);
NSString *DI2EncodeOverlayOptions(NSDictionary *options);
NSDictionary *DI2DecodeOverlayOptions(NSString *json);
// Use an object string with userInfo:nil, including when sending from the MAS sandbox.
NSString *DI2OverlayMessage(NSDictionary *options, NSString *session, int pid);
NSDictionary *DI2OverlayMessageOptions(id message, NSString *session, int pid);
