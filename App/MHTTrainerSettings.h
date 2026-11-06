// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "MHTModule.h"

@interface MHTTrainerSettings : NSWindowController <NSSearchFieldDelegate>
@property(nonatomic,copy) void (^choosePath)(MHTModule *,NSDictionary *,dispatch_block_t completion);
- (instancetype)initWithModules:(NSArray<MHTModule *> *)modules;
- (void)reloadModules:(NSArray<MHTModule *> *)modules;
@end
