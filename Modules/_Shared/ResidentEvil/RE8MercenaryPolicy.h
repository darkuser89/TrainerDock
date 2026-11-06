// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <stdint.h>
#include <math.h>
// Only an external positive gain since the last post-bonus sample is eligible.
// Rebase after a new area/context, score reset, manual score action or max-score.
static inline int32_t MTRE8MercenaryBonus(int32_t before,int32_t current,int32_t area,double factor) {
    if(before<0 || current<=before || area<0 || area>current || current>99999999 || !isfinite(factor) || factor<1 || factor>10)return 0;
    int64_t extra=(int64_t)floor((double)(current-before)*(factor-1));
    int64_t room=99999999-(int64_t)current;if(extra>room)extra=room;
    return (int32_t)extra;
}
