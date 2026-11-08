// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT BOOL TREnqueue(dispatch_block_t work);
FOUNDATION_EXPORT BOOL TRInFrame(void);
FOUNDATION_EXPORT NSDictionary *TRInspect(void);
FOUNDATION_EXPORT NSDictionary *TREffect(NSInteger feature,BOOL wanted,double value);
FOUNDATION_EXPORT void TRRelease(void);
FOUNDATION_EXPORT BOOL TRMouse(BOOL wanted);
FOUNDATION_EXPORT NSDictionary *TRValues(void);
