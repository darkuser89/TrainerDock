// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "Unreal.hpp"
namespace fp {
struct ManagerResult {
    Object manager{};
    Weak managerWeak{},controllerWeak{};
    bool ready=false;
    bool initializationAttempted=false;
    NSString *reason=nil;
};
// Requires the original GameThread and local controller. Accepts only its
// original typed CheatManager backlink. Only call in response to an explicit
// trainer feature request. If missing, the original GameplayStatics.SpawnObject
// creates a real PXCheatManager under this controller; the original reflected
// object-property setter installs its GC-visible backlink. No altered CheatClass,
// fake frame, raw reference write or AddToRoot is used.
ManagerResult ensureCheatManager(Object controller);
}
