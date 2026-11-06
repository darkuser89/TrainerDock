// SPDX-License-Identifier: GPL-3.0-only
#import "RE2Engine.h"
@interface MTRE8Engine : MTRE2Engine
- (void *)field:(uint32_t)field owner:(uint32_t)owner type:(uint32_t)type object:(void *)object size:(NSUInteger)size;
- (void *)virtualMethod:(uint32_t)method owner:(uint32_t)owner object:(void *)object;
@end
