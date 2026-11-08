// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "Unreal.hpp"
// Must be called on the original GameThread. False releases only this lease.
// The host supplies false for closing, loading, owner changes and focus loss.
bool FPSetOverlayMouse(bool wanted, fp::Object controller);
