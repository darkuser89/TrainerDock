// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
@interface DredgeAdapter : NSObject <MTGameAdapter>
// Read-only diagnostics of the real native context; no effect is enabled here.
- (NSDictionary *)nativeObservation;
- (NSDictionary *)observation;
@end
#ifdef __cplusplus
extern "C" {
#endif
NSDictionary *DREffectObservation(void);
#ifdef __cplusplus
}
#endif
