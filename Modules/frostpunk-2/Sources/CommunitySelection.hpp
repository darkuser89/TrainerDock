// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "Context.hpp"
namespace fp {
// Existing, enabled, nonempty components belonging to this exact context city
// and its original communities holder. Rejects malformed/changing metadata/data.
std::vector<Object> listLocalCommunities(const Context &);
// Resolves original PXSelectionUtils.GetSelectedCommunity (PXCommunityType)
// against the city's checked membership. Empty if no community is selected;
// never chooses the first member or a community from another city.
Object selectedCommunity(const Context &);
Object communityType(Object community);
}
