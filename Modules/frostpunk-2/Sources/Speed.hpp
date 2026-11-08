// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "Context.hpp"
struct FPSpeedResult {bool available=false,active=false;double value=1;NSString *note=nil;};
FPSpeedResult FPApplySpeed(const fp::Context &,bool,double);
void FPReleaseSpeed();
