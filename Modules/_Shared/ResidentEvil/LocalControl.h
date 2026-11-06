// SPDX-License-Identifier: GPL-3.0-only
#import "GameBridge.h"
typedef void (^MTControlReply)(NSDictionary *response);
typedef void (^MTControlHandler)(NSDictionary *request, MTControlReply reply);
@interface MTLocalControl : NSObject
- (instancetype)initWithMetadata:(NSDictionary *)metadata handler:(MTControlHandler)handler;
- (void)stop;
@end
NSDictionary *MTControlSnapshot(RE2TrainerState *state);
NSDictionary *MTControlClient(NSString *target,NSDictionary *request);
int MTControlCLI(int argc,const char *argv[]);
