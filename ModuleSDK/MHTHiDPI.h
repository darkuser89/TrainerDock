// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <AppKit/AppKit.h>
#include <math.h>

// AppKit owns backing-layer contentsScale. Work in points; align only at the
// final drawing transform, which includes both Retina and the overlay's zoom.
static inline NSRect MHTPixelAlignedTextRect(NSRect rect) {
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    if(!context)return rect;
    CGPoint pixel=CGContextConvertPointToDeviceSpace(context,rect.origin);
    pixel.x=round(pixel.x);pixel.y=round(pixel.y);
    rect.origin=CGContextConvertPointToUserSpace(context,pixel);
    return rect;
}
static inline NSRect MHTOnePixelVerticalRect(NSRect rect) {
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    if(!context)return rect;
    CGRect pixels=CGRectStandardize(CGContextConvertRectToDeviceSpace(context,rect));
    CGFloat bottom=round(CGRectGetMinY(pixels)),top=round(CGRectGetMaxY(pixels));
    pixels=CGRectMake(round(CGRectGetMinX(pixels)),bottom,1,MAX(1,top-bottom));
    return CGContextConvertRectToUserSpace(context,pixels);
}
static inline NSRect MHTPixelAlignedFrame(NSView *parent,NSRect frame) {
    return parent.window ? [parent backingAlignedRect:frame options:NSAlignAllEdgesNearest] : frame;
}
static inline void MHTInvalidateDrawing(NSView *content) {
    content.needsDisplay=YES;
    for(NSView *child in content.subviews)MHTInvalidateDrawing(child);
}
