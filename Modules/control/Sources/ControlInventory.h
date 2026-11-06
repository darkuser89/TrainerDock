// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <memory>
struct MHTControlInventoryResult {
    bool recipesAvailable=false,craftActive=false,materialsActive=false;
    size_t materialCount=0;
};
class MHTControlInventory {
public:
    MHTControlInventory();
    ~MHTControlInventory();
    MHTControlInventoryResult update(uintptr_t avatar,uintptr_t inventory,bool materials,bool freeCraft);
    void release();
    void discardOwner();
private:
    struct State;
    std::unique_ptr<State> state;
};
