// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL DRSupportedImage(void);
BOOL DREnqueue(dispatch_block_t work);
BOOL DREnqueueChecked(dispatch_block_t work,dispatch_block_t rejected);
BOOL DRInFrame(void);
void DRSetFrameHandler(dispatch_block_t handler);
BOOL DRMouse(BOOL wanted);
NSDictionary *DRNativeObservation(void);
#ifdef __cplusplus
}
#endif
