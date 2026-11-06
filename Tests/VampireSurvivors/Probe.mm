// SPDX-License-Identifier: GPL-3.0-only
// Actual, read-only Unity observations. Never linked into the product.
#import "MonoRuntime.h"
extern "C" {
#import "MHTProtocol.h"
}
#include <atomic>
__attribute__((constructor))static void start(){dispatch_async(dispatch_get_main_queue(),^{
 NSString *token=[NSProcessInfo.processInfo.environment[@"MHT_SESSION"]copy];if(!token.length)return;
 static std::atomic<bool> pending{false};[NSTimer scheduledTimerWithTimeInterval:.5 repeats:YES block:^(NSTimer *t){(void)t;if(pending.exchange(true))return;
  if(!VSEnqueue(^{@autoreleasepool{NSDictionary *state=VSObservation();MHTPost(@"local.mht.vampire-survivors.native-test.v1",@{@"version":@1,@"module":@"vampire-survivors",@"session":token,@"pid":@(getpid()),@"state":state});pending=false;}}))pending=false;
 }];
});}
