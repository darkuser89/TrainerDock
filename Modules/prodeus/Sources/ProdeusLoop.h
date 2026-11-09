// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL PREnsureLoop(void);
BOOL PREnqueue(dispatch_block_t);
BOOL PRInFrame(void);
NSDictionary *PRLoopDiagnostics(void);
void PRSetFrameHandler(dispatch_block_t);
#ifdef __cplusplus
}
#endif
