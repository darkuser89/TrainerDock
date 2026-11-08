// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <string>
#include <vector>
#include <cstdint>
// Only the bound local run's exact original paths are protected. No save bytes
// are read, copied, edited or written by the guard.
void TLDProtectSaves(const std::vector<std::string>& paths,uintptr_t healthAddress,uintptr_t modeAddress=0,int deadMode=1);
void TLDObserveSaveGuard();
void TLDReleaseSaveGuard();
void TLDClearSaveGuard();
uint64_t TLDBlockedSaveDeletes();
size_t TLDProtectedSaveCount();

int TLDGuardedUnlink(const char *path);
