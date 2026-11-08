// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL TLDEnsureLoop(void);
BOOL TLDEnqueue(dispatch_block_t);
BOOL TLDInFrame(void);
NSDictionary *TLDLoopDiagnostics(void);
void TLDSetFrameHandler(dispatch_block_t);
#ifdef __cplusplus
}
#endif
