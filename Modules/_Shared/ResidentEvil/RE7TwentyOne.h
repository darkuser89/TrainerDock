// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <stdint.h>
#include <stdbool.h>
// Plan a permutation of the original eleven distinct card values. No new
// cards or out-of-range numbers; keep as many current hand values as possible.
static inline bool MTRE7PlanTwentyOne(const int32_t before[11],uint16_t player,int32_t after[11]) {
    if(player&~0x7ffu)return false;
    unsigned seen=0,hand=0;int count=0;
    for(int i=0;i<11;i++){
        int n=before[i];if(n<1 || n>11 || (seen&(1u<<(n-1))))return false;
        seen|=1u<<(n-1);if(player&(1u<<i)){hand|=1u<<(n-1);count++;}
    }
    if(seen!=0x7ff || count<2 || count>6)return false;
    unsigned chosen=0;int best=-1;
    for(unsigned mask=1;mask<0x800;mask++){
        if(__builtin_popcount(mask)!=count)continue;int sum=0;
        for(int n=1;n<=11;n++)if(mask&(1u<<(n-1)))sum+=n;
        int keep=__builtin_popcount(mask&hand);
        if(sum==21 && keep>best){chosen=mask;best=keep;}
    }
    if(!chosen)return false;unsigned used=0;
    for(int i=0;i<11;i++){after[i]=0;if((player&(1u<<i)) && (chosen&(1u<<(before[i]-1)))){after[i]=before[i];used|=1u<<(before[i]-1);}}
    for(int i=0;i<11;i++)if((player&(1u<<i)) && !after[i])for(int n=1;n<=11;n++)if((chosen&(1u<<(n-1))) && !(used&(1u<<(n-1)))){after[i]=n;used|=1u<<(n-1);break;}
    for(int i=0;i<11;i++)if(!(player&(1u<<i)) && !(used&(1u<<(before[i]-1)))){after[i]=before[i];used|=1u<<(before[i]-1);}
    for(int i=0;i<11;i++)if(!after[i])for(int n=1;n<=11;n++)if(!(used&(1u<<(n-1)))){after[i]=n;used|=1u<<(n-1);break;}
    return used==0x7ff;
}
