// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <stdbool.h>
// Negative results prohibit a write. Do not refill inside an active weapon
// sequence, and never roll ammunition back when this consumable cheat stops.
static inline int MTRE8MagazineTarget(int current,int capacity,bool trigger,bool sequence,bool timer,bool attacking,bool shootEvent,bool menu) {
    if(capacity<1 || capacity>9999 || current<0 || current>capacity)return -2;
    if(menu || attacking || shootEvent || !trigger || !sequence || !timer)return -1;
    return capacity;
}

// Exact-build Rose observation: the initial weapon can retain a positive
// loaded-work offset from its display count across actual shots. Preserve it
// through the native paired refill; every other mode still requires equality.
static inline int MTRE8LoadedBulletTarget(int current,int loaded,int capacity,int target,bool rose) {
    if(capacity<1 || capacity>9999 || current<0 || current>capacity || loaded<current || target<current || target>capacity)return -1;
    int offset=loaded-current;if(offset>capacity || (!rose && offset!=0))return -1;
    return loaded+(target-current);
}
