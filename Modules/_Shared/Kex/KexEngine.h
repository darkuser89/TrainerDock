// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
void KEXEnqueue(dispatch_block_t work);
NSDictionary *KEXInspect(void);
NSDictionary *KEXEffect(NSInteger feature,BOOL wanted);
void KEXRelease(void);
BOOL KEXMouse(BOOL wanted);
