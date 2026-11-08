// SPDX-License-Identifier: GPL-3.0-only
#pragma once
// Call only on Stray's original GameThread. AppKit drawing remains in OverlayCursor.
bool STSetOverlayInteraction(bool wanted);
