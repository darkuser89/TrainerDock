// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
void VCStartBackend(void);
NSDictionary *VCInspect(void);
NSDictionary *VCEffect(NSInteger feature,BOOL wanted,double value);
NSString *VCOneShot(NSInteger feature,double value);
void VCRelease(void);
BOOL VCMouse(BOOL wanted);
NSDictionary *VCValues(void);
#ifdef __cplusplus
}
#endif
