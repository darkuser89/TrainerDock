// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
@class MHTTrainerStore;
@interface MHTTrainerLibrary : NSWindowController <NSTableViewDataSource,NSTableViewDelegate,NSSearchFieldDelegate>
@property(nonatomic,copy) void (^didChange)(void);
- (instancetype)initWithStore:(MHTTrainerStore *)store protectedRuntimePaths:(NSSet<NSString *> *(^)(void))paths;
- (void)reloadForIdentifier:(NSString *)identifier;
@end
