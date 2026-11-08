// SPDX-License-Identifier: GPL-3.0-only
// Render the real overlay with presentation-only state. No engine or runtime.
#import "Overlay.h"
#import <objc/runtime.h>
#if defined(MHT_DI2)
#define Root DI2OverlayRoot
#define State DI2TrainerState
#define FeatureState DI2FeatureState
#define FeatureCount DI2FeatureCount
#define FeatureInfo DI2FeatureInfoAt
#elif defined(MHT_RE)
#define Root RE2OverlayRoot
#define State RE2TrainerState
#define FeatureState RE2FeatureState
#define FeatureCount RE2ActiveFeatureCount()
#define FeatureInfo RE2FeatureInfoAt
#else
#define Root MTOverlayRoot
#define State MTTrainerState
#define FeatureState MTFeatureState
#define FeatureCount MTFeatureCount
#define FeatureInfo MTFeatureInfoAt
#endif
// Only the state needed by the view; never linked into a shipped trainer.
@implementation State
- (instancetype)init {
    if((self=[super init])) {
        self.status=@"Darstellungsprüfung";self.message=@"Kein Spiel gestartet";
        NSMutableArray *rows=[NSMutableArray new];
        for(NSInteger i=0;i<FeatureCount;i++){FeatureState *state=[FeatureState new];state.value=FeatureInfo(i)->initial;[rows addObject:state];}
        self.features=rows;
    }return self;
}
@end
@interface Root (TitleChecks)
- (void)drawPanel:(NSRect)bounds;
@end
static IMP originalDraw;
static NSString *expected;
static NSUInteger titles;
static CGFloat titleRight,firstControl;
static void require(BOOL okay,const char *message){if(!okay){fprintf(stderr,"FAIL %s: %s\n",expected.UTF8String,message);exit(1);}}
static void observeDraw(NSString *text,SEL selector,NSRect box,NSDictionary *attributes) {
    if(fabs(box.origin.x-10)<1 && fabs(box.origin.y-7)<1 && box.size.height==18) {
        titles++;require([text isEqual:expected],"actual drawn title differs from the module's game name");
        require([text sizeWithAttributes:attributes].width<=box.size.width,"game title is truncated");titleRight=NSMaxX(box);
    }
    if(box.origin.y>=5 && box.origin.y<=10 && box.origin.x>400)firstControl=MIN(firstControl,NSMinX(box));
    ((void(*)(id,SEL,NSRect,id))originalDraw)(text,selector,box,attributes);
}
int main(int argc,const char **argv){@autoreleasepool {
    if(argc!=2)return 2;expected=@(argv[1]);
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
#if defined(TEST_CRIMSON)
    MTUseCrimsonFeatures();
#endif
    Root *root=[[Root alloc]initWithFrame:NSMakeRect(0,0,1400,1100) version:@"Titelprüfung"];
    require([root.accessibilityLabel hasPrefix:expected],"accessible title differs from game name");
    Method draw=class_getInstanceMethod(NSString.class,@selector(drawInRect:withAttributes:));
    originalDraw=method_setImplementation(draw,(IMP)observeDraw);
    @try {
        for(NSInteger density=1;density<=2;density++) {
            titles=0;titleRight=0;firstControl=CGFLOAT_MAX;
            NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:820*density pixelsHigh:1100*density bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            memset(bitmap.bitmapData,0,bitmap.bytesPerRow*bitmap.pixelsHigh);
            [NSGraphicsContext saveGraphicsState];NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
            CGContextScaleCTM(NSGraphicsContext.currentContext.CGContext,density,density);
            [root drawPanel:NSMakeRect(0,0,820,1100)];
            [NSGraphicsContext restoreGraphicsState];
            require(titles==1,"expected exactly one actual upper-left game heading");
            require(titleRight<firstControl,"heading overlaps the right-hand controls");
        }
    } @finally {method_setImplementation(draw,originalDraw);}
    printf("PASS: %s — actual heading at 1x/2x, complete text, separate controls, matching accessibility.\n",expected.UTF8String);
    return 0;
}}
