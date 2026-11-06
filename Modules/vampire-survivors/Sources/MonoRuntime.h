// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL VSSupportedImage(void);
BOOL VSEnqueue(dispatch_block_t work);
NSDictionary *VSInspect(void);
NSDictionary *VSEffect(NSInteger feature,BOOL wanted,double value);
NSString *VSOneShot(NSInteger feature,double value);
void VSRelease(void);
BOOL VSMouse(BOOL wanted);
NSDictionary *VSObservation(void);
#ifdef __cplusplus
}
#endif
