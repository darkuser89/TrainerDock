// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <stdbool.h>
#include <math.h>
// Permit normal ticking (including the supported maximum game speed), while
// rejecting a counter which reverted to its old pre-subtraction value.
static inline bool MTRE8TimeReadback(float expected,float observed,double elapsed) {
    return isfinite(expected) && isfinite(observed) && isfinite(elapsed) && expected>=0 && observed>=expected-0.1f && elapsed>=0 && observed<=expected+3*elapsed+1;
}
