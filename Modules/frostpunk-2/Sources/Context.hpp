// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "Unreal.hpp"
namespace fp {
struct Context {
    bool ready=false;
    Object localPlayer{},controller{},world{},level{},city{},nation{};
    Weak playerWeak{},controllerWeak{},worldWeak{},cityWeak{},nationWeak{};
    NSString *identity=@"",*note=@"Spielkontext wird geladen.";
};
// Must run on the original GameThread. Resolves the active local controller,
// selected city and player nation through original references/getters. Failure
// is a loading context; there is no first-city or arbitrary-nation fallback.
Context captureContext();
// Resolves gameplay ownership through ULevel.OwningWorld, including streamed
// levels whose package Outer is a different World. Original GameThread only.
Object worldOf(Object);
Object linkedObject(Object,NSString *propertyName);
// Exact original CDO for a BlueprintFunctionLibrary. Callers must separately
// require native+static flags before invoking any utility method.
Object utility(NSString *className);
}
