// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
void IZEnableLuaEngine(void);
void IZOnSimulationThread(dispatch_block_t work);
void IZOnPresentationThread(dispatch_block_t work);
bool IZIsSimulationThread(void);
id IZCall(NSString *method,NSArray *arguments);
id IZPresentationCommand(NSString *command);
#ifdef IZ_PRIVATE_PROBE
id IZTestEvaluate(NSString *script);
NSDictionary *IZTestEngineStatus(void);
#endif
