// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL DUSupportedImage(void);
BOOL DUEnqueue(dispatch_block_t work);
NSDictionary *DUInspect(void);
NSDictionary *DUEffect(NSInteger feature,BOOL wanted,double value);
NSString *DUOneShot(NSInteger feature,double value);
void DURelease(void);
BOOL DUMouse(BOOL wanted);
#ifdef __cplusplus
}
#endif
