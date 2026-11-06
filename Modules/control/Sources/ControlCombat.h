// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <memory>
struct MHTControlCombatResult {bool available=false,confirmed=false;size_t targets=0;};
class MHTControlCombat {
public:
    MHTControlCombat();
    ~MHTControlCombat();
    MHTControlCombatResult update(uintptr_t avatar,bool wanted);
    void reset();
private:
    struct State;
    std::unique_ptr<State> state;
};
