// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "Context.hpp"
#import "TrainerFeatures.h"
namespace fp::continuous {
struct Result { bool available=false,active=false;NSString *note=nil; };
// Only original GameThread work; no manager is created for a disabled feature.
// A manager is requested only by an enabled research/exploration/law feature.
Result apply(const Context &,MTFeature,bool wanted);
// Compare and restore only this module's still-observable writes. Keeps an
// unresolved live lease for retry; dead owners and external changes are released.
bool releaseOwnEffects();
}
