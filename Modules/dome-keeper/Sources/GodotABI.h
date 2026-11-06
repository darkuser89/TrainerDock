// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL DKSupportedImage(void);
BOOL DKEnqueue(dispatch_block_t work);
NSDictionary *DKInspect(void);
NSDictionary *DKEffect(NSInteger feature,BOOL wanted,double value);
NSString *DKOneShot(NSInteger feature,double value);
void DKRelease(void);
BOOL DKMouse(BOOL enabled);
#ifdef __cplusplus
}
#endif
