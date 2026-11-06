// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
@interface LOPGameAdapter : NSObject <MTGameAdapter>
- (NSDictionary *)diagnosticSnapshot;
- (NSDictionary *)runReversibleChecks;
@end
