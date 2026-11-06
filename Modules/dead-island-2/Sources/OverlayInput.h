// SPDX-License-Identifier: GPL-3.0-only
#import "GameAccess.h"

// GameThread-only UI ownership; independent from the single-player cheat gate.
@interface DI2OverlayInput : NSObject
- (instancetype)initWithAPI:(DI2GameAPI)api;
- (BOOL)updateWorld:(void *)world wanted:(BOOL)wanted;
@end
