// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
// Original GameThread only; local controller's unlocked equipment only.
NSDictionary *STDefluxorApply(bool wanted);
void STDefluxorRelease(void);
NSDictionary *STDefluxorDiagnostics(void);
