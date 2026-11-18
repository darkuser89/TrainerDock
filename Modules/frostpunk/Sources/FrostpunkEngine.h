// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>

typedef struct {
    void *game, *state, *economy, *economyConfig, *cheats, *time, *timer;
    void *sociotech, *generator;
    BOOL gameplay;
    uint64_t generation;
} FPOwner;

BOOL FPReadAt(const void *object, size_t offset, void *result, size_t length);
void *FPOriginalSymbol(const char *name);
FPOwner FPCaptureOwner(void);
BOOL FPSameOwner(FPOwner left, FPOwner right);
__attribute__((visibility("default"))) void FPOnGameThread(dispatch_block_t work);
__attribute__((visibility("default"))) NSDictionary *FPInspect(void);
NSDictionary *FPEffect(NSInteger feature, BOOL wanted, double value);
NSString *FPOneShot(NSInteger feature, double value);
void FPReleaseEffects(void);
BOOL FPSetMouse(BOOL wanted);
