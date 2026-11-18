// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "FrostpunkEngine.h"

// Called exclusively on the original gameplay thread. Numeric resource features
// are explicit actions; querying their state never repeats an addition.
NSDictionary *FPResourceEffect(FPOwner owner, NSInteger feature, BOOL wanted, double value);
NSString *FPResourceAction(FPOwner owner, NSInteger feature, double value);
void FPResourceRelease(FPOwner owner);
