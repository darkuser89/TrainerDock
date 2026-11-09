// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
void HFStartBackend(void);
NSDictionary *HFInspect(void);
NSDictionary *HFEffect(NSInteger feature,BOOL wanted,double value);
void HFRelease(void);
NSDictionary *HFValues(void);
// Valid only inside the original Unity callback; caller roots it immediately.
void *HFPlayerForInput(void);
#ifdef __cplusplus
}
#endif
