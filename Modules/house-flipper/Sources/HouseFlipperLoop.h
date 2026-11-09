// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL HFEnsureLoop(void);
BOOL HFEnqueue(dispatch_block_t);
BOOL HFEnqueueChecked(dispatch_block_t, dispatch_block_t);
BOOL HFInFrame(void);
void HFSetFrameHandler(dispatch_block_t);
BOOL HFMouse(BOOL);
NSDictionary *HFLoopDiagnostics(void);
BOOL HFSupportedImages(void);
#ifdef __cplusplus
}
#endif
