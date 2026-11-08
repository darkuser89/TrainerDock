// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "GameAdapter.h"
#import "Context.hpp"
namespace fp::backend {
MTGameContext *capture();
void release();
MTFeatureState *apply(MTFeature,bool,double);
NSString *perform(MTFeature,double);
bool mouse(bool);
Context context();
NSDictionary *diagnostics();
}
