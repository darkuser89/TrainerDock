// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
@interface MHTUpdater : NSObject <NSUserInterfaceValidations>
- (instancetype)initWithRunningGames:(BOOL (^)(void))runningGames;
- (void)start;
- (void)checkForUpdates:(id)sender;
- (void)toggleAutomaticChecks:(id)sender;
@property(nonatomic,readonly) BOOL installationDeferred;
@end
