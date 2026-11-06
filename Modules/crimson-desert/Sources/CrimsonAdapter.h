// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
@interface CDCrimsonAdapter : NSObject <MTGameAdapter>
- (instancetype)initWithReader:(NSDictionary *(^)(void))reader
                     requester:(BOOL(^)(unsigned,BOOL,double,uint32_t))requester
                      releaser:(dispatch_block_t)releaser
                        cursor:(BOOL(^)(BOOL))cursor;
@end
