// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "RE2Engine.h"
// A native GameObjectRef protects the owner identity. Engine references protect
// managed wrappers from reuse while original values are held for restoration.
@interface RE2Owner : NSObject
@property(nonatomic,readonly) void *component;
@property(nonatomic,readonly) void *gameObject;
@property(nonatomic,readonly) BOOL valid;
@property(nonatomic,readonly) NSString *identity;
+ (instancetype)ownerForComponent:(void *)component engine:(MTRE2Engine *)engine;
+ (instancetype)ownerForGameObject:(void *)gameObject engine:(MTRE2Engine *)engine;
- (void)retainPayload:(void *)payload;
@end
