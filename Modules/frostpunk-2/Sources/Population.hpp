// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "Unreal.hpp"
// One explicit signed change on the genuine GameThread; never background retry.
// Caller supplies its current locally confirmed city/type pair. Existing nonempty
// communities only; resulting target must be >=1 and abs(delta)<=100000.
// True requires exact target readback AND agreement with the native returned delta.
// actualDelta is the fresh OriginalGetSize difference, including partial effects.
// False can still mean an unconfirmed/partial effect and must never trigger replay.
bool FPChangeCommunityPopulation(fp::Object worldContext,fp::Object city,
    fp::Object communityType,int32_t delta,int32_t *actualDelta=nullptr);
// Compatibility convenience for positive additions.
bool FPAddCommunityPopulation(fp::Object worldContext,fp::Object city,
    fp::Object communityType,int32_t amount,int32_t *actualDelta=nullptr);
