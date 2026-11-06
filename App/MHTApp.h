// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
@interface MHTApp : NSObject <NSApplicationDelegate,NSTableViewDataSource,NSTableViewDelegate>
@property(nonatomic) BOOL smokeTest;
- (void)openSettings:(id)sender;
- (void)rescan:(id)sender;
- (void)showLibrary:(id)sender;
@end
