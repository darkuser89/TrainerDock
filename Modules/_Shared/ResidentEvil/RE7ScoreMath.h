// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <stdint.h>
#include <math.h>
// Infer the game's actual weighted bonus from two native total-score reads.
// Include a small margin for the final float-to-Int32 conversion.
static inline float MTRE7ScoreFactor(float original,float probe,int32_t before,int32_t after) {
    double delta=(double)probe-original;
    if(!isfinite(original) || !isfinite(probe) || delta==0)return NAN;
    double slope=((double)after-before)/delta;
    if(!isfinite(slope) || slope<=0)return NAN;
    double factor=(double)original+(1000100.0-before)/slope;
    return isfinite(factor) && factor>0 && factor<=10000000 ? (float)factor : NAN;
}
