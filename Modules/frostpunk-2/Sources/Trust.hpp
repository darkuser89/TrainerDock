// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "Context.hpp"
namespace fp::trust {
struct Result {
    bool available=false,active=false;
    double maximum=0;
    size_t checkedCommunities=0;
    NSString *note=nil;
};
// The original TrustConfig is shared: this changes the GLOBAL native relation
// floor, not only one city's records. No raw standing/history record is edited.
// Active requires original GetCommunityStanding==MaximumCommunityTrust for every
// current, enabled, nonempty community of the verified local city.
Result apply(const Context &,bool wanted);
bool releaseOwnEffects();
}
