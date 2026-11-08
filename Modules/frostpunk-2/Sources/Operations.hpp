// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "Context.hpp"
namespace fp::operations {
struct Result {
    bool available=false,invoked=false,confirmed=false;
    double value=0;
    NSString *note=nil;
};
// Continuous effects: call only for explicit enabled desires on the GameThread.
Result generatorWear(const Context &,bool enabled);
Result demolish(const Context &,bool enabled);
// Explicit button only. Never call from a periodic desired-state reconciliation.
Result council(const Context &);
// Restores only our still-owned generator wear value. Completed demolition and
// council transitions are not replayed or fabricated as reversible data edits.
// False retains the lease for a later GameThread retry, including Loading polls.
bool release();
bool hasPendingRelease();
}
