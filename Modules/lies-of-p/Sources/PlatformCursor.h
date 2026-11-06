// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

typedef struct {
    uintptr_t application,cursor,reference;
    int32_t type,overrideType;
    BOOL visible,hasShape,hasDefaultShape,free;
} MTPlatformCursorState;
typedef NS_ENUM(NSInteger,MTPlatformCursorOperation) {
    MTPlatformCursorOverride,MTPlatformCursorType,MTPlatformCursorVisibility
};
// Private native cursor ownership; no additional user control or hotkey.
@interface MTPlatformCursorLease : NSObject
- (instancetype)initWithRead:(MTPlatformCursorState (^)(void))read
                       apply:(BOOL (^)(MTPlatformCursorState owner,MTPlatformCursorOperation operation,int32_t value))apply;
- (BOOL)show;
- (void)restore:(BOOL)restoreAppearance;
@end
