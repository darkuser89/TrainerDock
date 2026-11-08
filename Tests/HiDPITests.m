// SPDX-License-Identifier: GPL-3.0-only
// Software 1x/2x rendering; no game or display setting is touched.
#import "Overlay.h"
#import "MHTHiDPI.h"
#import "MHTGlassIntensity.h"
#import "TrainerMaterial.h"
#import "OverlaySettings.h"
#import <objc/runtime.h>
#if defined(MHT_DI2)
#define OverlayRoot DI2OverlayRoot
#define Material DI2TrainerMaterial
#define Normalize DI2NormalizeOverlayOptions
#define TrainerState DI2TrainerState
#elif defined(MHT_RE)
#define OverlayRoot RE2OverlayRoot
#define Material MTTrainerMaterial
#define Normalize RE2NormalizeOverlayOptions
#define TrainerState RE2TrainerState
#else
#define OverlayRoot MTOverlayRoot
#define Material MTTrainerMaterial
#define Normalize MTNormalizeOverlayOptions
#define TrainerState MTTrainerState
#endif
@interface OverlayRoot (GlassChecks)
- (void)headerClick:(NSPoint)point;
@end
static void check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static NSBitmapImageRep *bitmap(NSInteger width,NSInteger height) {
    return [[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
}
static MHTGlassSlider *sliderIn(NSView *view) {
    if([view isKindOfClass:MHTGlassSlider.class])return (MHTGlassSlider *)view;
    for(NSView *child in view.subviews){MHTGlassSlider *slider=sliderIn(child);if(slider)return slider;}
    return nil;
}
static NSView *watchedOverlay;
static NSUInteger invalidations;
static IMP originalSetNeedsDisplay;
static void countInvalidation(NSView *view,SEL selector,BOOL flag) {
    if(flag && [view isDescendantOf:watchedOverlay])invalidations++;
    ((void(*)(id,SEL,BOOL))originalSetNeedsDisplay)(view,selector,flag);
}
static void checkIdlePresentation(OverlayRoot *root) {
    TrainerState *state=[TrainerState new];state.ready=YES;state.status=@"Synthetischer Kontext";state.message=@"Unverändert";
    [root applyOverlayOptions:@{@"visible":@YES}];[root updateState:state];
    // Count actual invalidation requests, not AppKit's existing deferred dirty
    // flags (glass may legitimately retain those until the next display pass).
    Method method=class_getInstanceMethod(NSView.class,@selector(setNeedsDisplay:));
    watchedOverlay=root;invalidations=0;originalSetNeedsDisplay=method_setImplementation(method,(IMP)countInvalidation);
    @try {
        for(NSUInteger i=0;i<1000;i++)[root updateState:state];
        check(invalidations==0,"1000 unchanged state polls invalidate no overlay view");
        [root applyOverlayOptions:@{@"visible":@NO,@"badge":@NO}];invalidations=0;
        for(NSUInteger i=0;i<1000;i++){
            state.features[0].active=(i%2)==1;state.features[0].wanted=state.features[0].active;
            [root updateState:state];
        }
        check(invalidations==0,"1000 changing states invalidate no hidden overlay view");
        [root applyOverlayOptions:@{@"visible":@YES}];
        check(invalidations>0,"reopening presents the latest hidden state immediately");
        invalidations=0;[root updateState:state];
        check(invalidations==0,"presentation snapshots handle an in-place mutable bridge state");
    } @finally {
        method_setImplementation(method,originalSetNeedsDisplay);watchedOverlay=nil;
    }
}
static void checkGlass(OverlayRoot *root,NSWindow *window) {
    check([Normalize(@{})[@"glassIntensity"] doubleValue]==0.5,"old preferences use unchanged native glass at the midpoint");
    check([Normalize(@{@"glassIntensity":@(-5)})[@"glassIntensity"] doubleValue]==0 && [Normalize(@{@"glassIntensity":@5})[@"glassIntensity"] doubleValue]==1,"opacity is clamped to its real endpoints");
    check([Normalize(@{@"glassIntensity":@(NAN)})[@"glassIntensity"] doubleValue]==0.5 && [Normalize(@{@"glassIntensity":@"invalid"})[@"glassIntensity"] doubleValue]==0.5,"invalid opacity cannot enter rendering or preferences");
    Material *material=(Material *)root.panel;MHTGlassSlider *slider=sliderIn(material);
    check(slider!=nil,"each real trainer contains the shared intensity slider");
    __block NSDictionary *reported=nil;__block NSUInteger changes=0;
    root.optionsChanged=^(NSDictionary *options){reported=options;changes++;};
    for(NSNumber *value in @[@0,@0.25,@0.5,@0.75,@1]){
        NSUInteger before=changes;[root applyOverlayOptions:@{@"visible":@YES,@"scale":@0.9,@"glassIntensity":value}];[root layout];
        check(changes==before && slider.doubleValue==value.doubleValue && material.glassIntensity==value.doubleValue,"restoring opacity updates material and slider without recursive commands");
        check(NSContainsRect(material.contentView.bounds,slider.frame) && NSMaxX(slider.frame)>NSWidth(material.contentView.bounds)-20,"slider stays in the bottom-right footer");
        check(material.contentView.alphaValue==1 && material.contentView.superview==material,"background intensity never fades foreground controls");
        if(![material reducesTransparency]){
            NSView *background=[material valueForKey:@"material"];NSView *fill=[material valueForKey:@"opaqueBacking"];
            check(fabs(background.alphaValue-MIN(1,value.doubleValue*2))<0.001 && fabs(fill.alphaValue-MAX(0,value.doubleValue*2-1))<0.001,"clear/native-glass/opaque background layers follow the full range");
        }
    }
    NSPoint left=[slider convertPoint:NSMakePoint(39,9) toView:nil];
    NSPoint right=[slider convertPoint:NSMakePoint(NSWidth(slider.bounds)+50,9) toView:nil];
    NSArray *types=@[@(NSEventTypeLeftMouseDown),@(NSEventTypeLeftMouseDragged),@(NSEventTypeLeftMouseUp)];
    for(NSUInteger i=0;i<types.count;i++){
        NSEvent *event=[NSEvent mouseEventWithType:[types[i] unsignedIntegerValue] location:i ? right : left modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:i clickCount:1 pressure:1];
        check([root handleMouseEvent:event],"slider consumes the full forwarded mouse sequence, including drag outside its frame");
    }
    check(changes==2 && [reported[@"glassIntensity"] doubleValue]==1 && slider.doubleValue==1,"slider changes reach the existing options persistence channel");
    check([slider accessibilityPerformDecrement] && slider.doubleValue==0.95,"slider is adjustable through accessibility");
    // RoboCop has a wider header; Lies of P retains its compact header over
    // an 820-point body. Exercise the real existing fold hit regions.
    NSPoint fold=NSMakePoint(NSWidth(material.contentView.bounds)==716 ? 676 : 500,10);[root headerClick:fold];
    check(slider.hidden,"folded trainer hides its footer slider");[root headerClick:fold];check(!slider.hidden,"unfolding restores the slider and its value");
    root.optionsChanged=nil;
}
static void checkPixelDrawing(CGFloat backing,CGFloat zoom) {
    NSBitmapImageRep *rep=bitmap(96,96);
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    CGContextRef context=NSGraphicsContext.currentContext.CGContext;
    CGContextTranslateCTM(context,0.37,0.23);CGContextScaleCTM(context,backing*zoom,backing*zoom);
    NSRect text=MHTPixelAlignedTextRect(NSMakeRect(3.25,4.7,50,12));
    CGPoint pixel=CGContextConvertPointToDeviceSpace(context,text.origin);
    check(fabs(pixel.x-round(pixel.x))<0.00001 && fabs(pixel.y-round(pixel.y))<0.00001,"text origin must align after backing and overlay transforms");
    check(text.size.width==50 && text.size.height==12,"alignment preserves wrapping and clipping size");
    NSRect line=MHTOnePixelVerticalRect(NSMakeRect(9.3,3.6,0.5,27));
    CGRect device=CGRectStandardize(CGContextConvertRectToDeviceSpace(context,line));
    check(fabs(device.size.width-1)<0.00001,"separator must be exactly one physical pixel");
    [NSColor.whiteColor setFill];NSRectFill(line);
    [NSGraphicsContext restoreGraphicsState];
    NSUInteger columns=0;
    for(NSInteger x=0;x<rep.pixelsWide;x++){
        BOOL painted=NO;
        for(NSInteger y=0;y<rep.pixelsHigh;y++){
            CGFloat alpha=[rep colorAtX:x y:y].alphaComponent;
            check(alpha<0.001 || alpha>0.999,"separator must not blur across neighbouring pixels");
            painted|=alpha>0.999;
        }
        if(painted)columns++;
    }
    check(columns==1,"rasterized separator occupies exactly one column");
}
int main(void){@autoreleasepool {
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
#if defined(TEST_CRIMSON)
    MTUseCrimsonFeatures();
#endif
    NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1200,900) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO;
    OverlayRoot *root=[[OverlayRoot alloc]initWithFrame:window.contentView.bounds version:@"HiDPI synthetic"];
    [window.contentView addSubview:root];
    checkIdlePresentation(root);
    checkGlass(root,window);
    for(NSNumber *zoom in @[@0.7,@0.9,@1.0,@1.3]){
        [root applyOverlayOptions:@{@"visible":@YES,@"liquidGlass":@NO,@"scale":zoom,@"position":@"free",@"x":@0.413,@"y":@0.287}];
        [root layout];[root viewDidChangeBackingProperties];[root layoutSubtreeIfNeeded];
        check(NSContainsRect(root.bounds,root.panel.frame),"scaled panel remains inside the window");
        NSRect frame=[root convertRectToBacking:root.panel.frame];
        check(fabs(frame.origin.x-round(frame.origin.x))<0.00001 && fabs(frame.origin.y-round(frame.origin.y))<0.00001,"physical panel origin aligns to the screen pixel grid");
        for(NSNumber *density in @[@1,@2]){@autoreleasepool {
            CGFloat backing=density.doubleValue;checkPixelDrawing(backing,zoom.doubleValue);
            NSBitmapImageRep *rep=bitmap(1200*backing,900*backing);
            NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
            [NSGraphicsContext saveGraphicsState];NSGraphicsContext.currentContext=context;
            CGContextScaleCTM(context.CGContext,backing,backing);
            [root displayRectIgnoringOpacity:root.bounds inContext:context];
            [NSGraphicsContext restoreGraphicsState];
            check(rep.pixelsWide==1200*backing && rep.pixelsHigh==900*backing,"software render retains requested backing resolution");
        }}
    }
    [root removeFromSuperview];[window close];
    puts("PASS: idle/hidden overlay invalidation, glass range, forwarded slider input, restoration, accessibility and footer; real overlay at 1x/2x and four zoom levels. No game launched.");
}return 0;}
