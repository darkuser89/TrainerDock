// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "DredgeHarvestTypes.hpp"
#include "DredgeSalePrice.hpp"
#include <cstdlib>
#include <cstdio>
static void DREquipmentLeaseTests(void) {
    auto expect=[](bool ok,const char *text){if(!ok){fprintf(stderr,"FAIL: %s\n",text);exit(1);}};
    int32_t current=1;size_t writes=0;
    auto read=[&]{return current;};auto write=[&](int32_t value){writes++;current=value;};
    dredge::HarvestTypeLease lease;
    expect(lease.apply(4,read,write)&&current==4&&lease.original==1,"existing coastal rod can use the actually requested abyssal type");
    for(int i=0;i<1000;i++)expect(lease.apply(4,read,write),"stable original-array lease keeps its verified type");
    expect(writes==1,"1,000 unchanged rod checks never rewrite the managed array");
    lease.apply(6,read,write);expect(current==6&&lease.original==1,"changing harvest target does not compound the baseline");
    lease.release(read,write);expect(current==1&&!lease.held,"off restores the rod's original type");
    lease.apply(4,read,write);current=7;lease.release(read,write);
    expect(current==7,"off preserves a foreign type change");
    lease.apply(4,read,write);current=3;lease.apply(6,read,write);lease.release(read,write);
    expect(current==3,"a changed original type becomes the next owned baseline");
    size_t before=writes;bool rejected=false;
    try{lease.apply(11,read,write);}catch(const std::exception&){rejected=true;}
    expect(rejected&&writes==before,"COUNT is never mistaken for a harvest type");
    rejected=false;try{lease.apply(0,read,write);}catch(const std::exception&){rejected=true;}
    expect(rejected&&writes==before,"NONE cannot be granted as equipment");
    dredge::HarvestTypeLease failed;rejected=false;
    try{failed.apply(4,read,[](int32_t){});}catch(const std::exception&){rejected=true;}
    expect(rejected&&!failed.held,"failed managed-array readback never claims effect ownership");
    expect(dredge::saleModifier(.5,2)==2,"fish uses the original clamp before applying factor two");
    expect(dredge::saleModifier(.5,2)*dredge::resaleCorrection(.5)==1,"gear retains its original half-price base without changing purchase value");
    expect(dredge::saleModifier(1.5,3)==4.5,"higher original fish bonus is preserved");
    expect(dredge::resaleCorrection(1.5)==1,"higher original resale bases need no compensation");
    for(double base:{.25,.5,.75,1.,1.5})for(double factor:{1.,2.,5.}){
     expect(dredge::saleModifier(base,factor)==std::max(1.,base)*factor,"fish scale is correct in a mixed shop");
     expect(dredge::saleModifier(base,factor)*dredge::resaleCorrection(base)==base*factor,"gear scale is correct in the same mixed shop");
    }
    puts("PASS: fish price clamp and original gear resale base.");
    puts("PASS: original rod type lease, changed targets, 1,000 unchanged checks without writes, off, foreign edits and failed readback. Synthetic array only.");
}
