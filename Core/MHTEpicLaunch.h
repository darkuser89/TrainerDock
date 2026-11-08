// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN
// Main-queue API. Exactly one completion, on the main queue, for each request.
// No Epic client termination, direct-game fallback, or automatic retry.
@interface MHTEpicLaunchService : NSObject
- (instancetype)initWithBrokerURL:(NSURL *)brokerURL;
- (BOOL)recoverPendingTransactions:(NSError * _Nullable * _Nullable)error;
- (void)launchGame:(NSDictionary *)game
           profile:(NSDictionary *)profile
       environment:(NSDictionary<NSString *,NSString *> *)environment
        completion:(void (^)(NSRunningApplication * _Nullable app,NSError * _Nullable error))completion;
- (void)cancelPendingLaunch;
@end

// Shared native entry for the product tool and the synthetic broker test tool.
int MHTEpicBrokerMain(int argc,char * _Nonnull * _Nonnull argv);
NS_ASSUME_NONNULL_END
