// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <AppKit/AppKit.h>
#include <math.h>
#define MHTGlassOptionsDidCommitNotification @"local.mht.overlay.glass-commit"
// 0 = clear background, 0.5 = native glass, 1 = opaque background.
static inline double MHTGlassIntensity(id value) {
    return [value isKindOfClass:NSNumber.class] && isfinite([value doubleValue]) ? MIN(1,MAX(0,[value doubleValue])) : 0.5;
}
// Manual tracking uses the overlay's existing down/drag/up forwarding. Native
// tracking loops would steal events from engine windows and break mouse capture.
@interface MHTGlassSlider : NSView
@property(nonatomic) double doubleValue;
@property(nonatomic,copy) void (^valueChanged)(double value);
@end
