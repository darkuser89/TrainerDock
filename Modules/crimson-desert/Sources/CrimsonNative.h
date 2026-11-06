// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL CDCorrectBuild(void);
void CDOnGameThread(dispatch_block_t work);
NSDictionary *CDReadPlayer(void);
BOOL CDSetPlayerStatRatio(unsigned kind, double ratio, uint32_t expectedActorKey);
void CDReleaseEffects(void);
BOOL CDRequestEffect(unsigned feature, BOOL wanted, double value, uint32_t expectedActorKey);
BOOL CDSetOverlayInteraction(BOOL wanted);
#ifdef __cplusplus
}
#endif
