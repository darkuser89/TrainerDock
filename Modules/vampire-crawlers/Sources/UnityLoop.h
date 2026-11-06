// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL VCEnsureLoop(void);
BOOL VCEnqueue(dispatch_block_t);
BOOL VCInFrame(void);
NSDictionary *VCLoopDiagnostics(void);
void VCSetFrameHandler(dispatch_block_t);
#ifdef __cplusplus
}
#endif
