// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
void TLDStartBackend(void);
NSDictionary *TLDInspect(void);
NSDictionary *TLDEffect(NSInteger,BOOL,double);
NSString *TLDOneShot(NSInteger,double);
void TLDRelease(void);
BOOL TLDMouse(BOOL);
NSDictionary *TLDValues(void);
#ifdef __cplusplus
}
#endif
