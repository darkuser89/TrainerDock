// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <memory>
class MHTControlMovement {
public:
    MHTControlMovement();
    ~MHTControlMovement();
    bool update(uintptr_t avatar,uintptr_t movement,bool wanted,double factor);
    void release();
private:
    struct State;
    std::unique_ptr<State> state;
};
