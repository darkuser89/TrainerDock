// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSString *const MHTCommandNotification;
FOUNDATION_EXPORT NSString *const MHTStateNotification;
NSDictionary *MHTDecodeMessage(id text);
void MHTPost(NSString *name, NSDictionary *message);
BOOL MHTMatchesSession(NSDictionary *message, NSString *module, NSString *session, int pid);
// Reject malformed, expired and replayed commands before invoking any engine code.
BOOL MHTAcceptCommand(NSDictionary *message, NSString *module, NSString *session,
                     int pid, NSMutableOrderedSet *seen, double now);
