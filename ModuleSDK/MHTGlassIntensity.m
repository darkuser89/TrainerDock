// SPDX-License-Identifier: GPL-3.0-only
#import "MHTGlassIntensity.h"
#import "MHTHiDPI.h"
@implementation MHTGlassSlider
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])){
        _doubleValue=0.5;self.identifier=@"MHT.GlassIntensity";
        self.accessibilityElement=YES;self.accessibilityRole=NSAccessibilitySliderRole;
        self.accessibilityLabel=@"Liquid Glass – Deckkraft";
        self.toolTip=@"Links: transparenter Hintergrund. Rechts: undurchsichtig. Wird für diesen Trainer gespeichert.";
    }return self;
}
- (BOOL)isFlipped{return YES;}
- (BOOL)isOpaque{return NO;}
- (BOOL)acceptsFirstMouse:(NSEvent *)event {(void)event;return YES;}
- (void)resetCursorRects {[super resetCursorRects];[self addCursorRect:self.bounds cursor:NSCursor.arrowCursor];}
- (void)setDoubleValue:(double)value {
    double normalized=MHTGlassIntensity(@(value));if(_doubleValue==normalized)return;
    _doubleValue=normalized;self.needsDisplay=YES;
}
- (id)accessibilityValue{return @(round(self.doubleValue*100));}
- (id)accessibilityMinValue{return @0;}
- (id)accessibilityMaxValue{return @100;}
- (NSString *)accessibilityValueDescription {return [NSString stringWithFormat:@"%.0f Prozent Deckkraft",self.doubleValue*100];}
- (void)changeTo:(double)value {
    double previous=self.doubleValue;self.doubleValue=value;
    if(previous!=self.doubleValue && self.valueChanged)self.valueChanged(self.doubleValue);
}
- (void)track:(NSEvent *)event {
    NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];
    [self changeTo:(point.x-39)/MAX(1,NSWidth(self.bounds)-85)];
}
- (void)mouseDown:(NSEvent *)event {[self track:event];}
- (void)mouseDragged:(NSEvent *)event {[self track:event];}
- (void)commit { [NSNotificationCenter.defaultCenter postNotificationName:MHTGlassOptionsDidCommitNotification object:self]; }
- (void)mouseUp:(NSEvent *)event {[self track:event];[self commit];}
- (BOOL)accessibilityPerformIncrement {[self changeTo:self.doubleValue+0.05];[self commit];return YES;}
- (BOOL)accessibilityPerformDecrement {[self changeTo:self.doubleValue-0.05];[self commit];return YES;}
- (void)drawRect:(NSRect)dirty {
    (void)dirty;CGFloat length=MAX(1,NSWidth(self.bounds)-85),center=NSMidY(self.bounds);
    NSDictionary *attributes=@{NSFontAttributeName:[NSFont systemFontOfSize:9],NSForegroundColorAttributeName:NSColor.whiteColor};
    [@"Glas" drawInRect:MHTPixelAlignedTextRect(NSMakeRect(0,center-6,32,14)) withAttributes:attributes];
    [[NSString stringWithFormat:@"%.0f %%",self.doubleValue*100] drawInRect:MHTPixelAlignedTextRect(NSMakeRect(NSWidth(self.bounds)-38,center-6,38,14)) withAttributes:attributes];
    [[NSColor colorWithWhite:0.55 alpha:1] setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(39,center-2,length,4) xRadius:2 yRadius:2] fill];
    [NSColor.systemCyanColor setFill];[[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(39,center-2,length*self.doubleValue,4) xRadius:2 yRadius:2] fill];
    [NSColor.whiteColor setFill];[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(39+length*self.doubleValue-5,center-5,10,10)] fill];
}
@end
