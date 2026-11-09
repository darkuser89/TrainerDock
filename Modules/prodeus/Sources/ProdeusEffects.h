// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
void PRStartBackend(void);
NSDictionary *PRInspect(void);
NSDictionary *PREffect(NSInteger,BOOL,double);
NSString *PROneShot(NSInteger,double);
void PRRelease(void);
BOOL PRMouse(BOOL);
NSDictionary *PRValues(void);
#ifdef __cplusplus
}
#endif
