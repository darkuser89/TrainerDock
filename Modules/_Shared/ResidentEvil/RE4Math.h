// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
static inline bool MTRE4AdjustClock(uint64_t before,double minutes,uint64_t *after){
    if(!after || !isfinite(minutes) || minutes < -600 || minutes > 600)return false;
    int64_t delta=llround(minutes*60000000.0);
    if(delta<0)*after=before<(uint64_t)-delta ? 0 : before-(uint64_t)-delta;
    else *after=UINT64_MAX-before<(uint64_t)delta ? UINT64_MAX : before+(uint64_t)delta;
    return true;
}
static inline bool MTRE4RewardTotal(int32_t previous,int32_t current,double factor,int32_t ceiling,int32_t *after){
    if(!after || previous<0 || current<0 || current>ceiling || current<=previous || !isfinite(factor) || factor<1 || factor>100)return false;
    double bonus=((double)current-previous)*(factor-1);
    int64_t n=(int64_t)current+llround(bonus);*after=(int32_t)(n>ceiling ? ceiling : n);
    return *after!=current;
}
