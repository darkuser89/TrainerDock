// SPDX-License-Identifier: GPL-3.0-only
// Real engine binder against this unrelated test executable. No original game started.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "DecimaEngine.h"
#import "TrainerFeatures.h"
#import "NativeAdapter.h"
#import "OverlayCursor.h"
#import "Overlay.h"
#include <math.h>
@interface FramePacingTimer : NSObject
- (void)waitForNextFrame;
@end
@implementation FramePacingTimer
- (void)waitForNextFrame{}
@end
static void check(BOOL condition,const char *message){if(!condition){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(void){@autoreleasepool{
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,800,600) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO;[window orderFront:nil];
    MHTDSCursorView *cursor=[[MHTDSCursorView alloc]initWithFrame:NSZeroRect];[window.contentView addSubview:cursor];
    NSPoint point=NSMakePoint(200,300);NSPoint screen=[window convertPointToScreen:point];
    [cursor updateAtScreenPoint:screen enabled:YES];
    check(!cursor.hidden && ![cursor hitTest:NSZeroPoint],"visible cursor cannot intercept clicks");
    NSPoint hot=cursor.pointerHotspot;
    check(fabs(NSMinX(cursor.frame)+hot.x-point.x)<1 && fabs(NSMaxY(cursor.frame)-hot.y-point.y)<1,"cursor hotspot follows native panel coordinates");
    for(NSNumber *density in @[@1,@2]){
        NSInteger scale=density.integerValue;NSSize size=cursor.pointerSize;
        NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:(NSInteger)size.width*scale pixelsHigh:(NSInteger)size.height*scale bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [NSGraphicsContext saveGraphicsState];NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        CGContextClearRect(NSGraphicsContext.currentContext.CGContext,CGRectMake(0,0,rep.pixelsWide,rep.pixelsHigh));
        CGContextScaleCTM(NSGraphicsContext.currentContext.CGContext,scale,scale);
        [cursor drawRect:NSMakeRect(0,0,size.width,size.height)];[NSGraphicsContext restoreGraphicsState];
        NSUInteger visible=0;for(NSInteger y=0;y<rep.pixelsHigh;y++)for(NSInteger x=0;x<rep.pixelsWide;x++)if([rep colorAtX:x y:y].alphaComponent>0.5)visible++;
        check(visible>50*(NSUInteger)scale*(NSUInteger)scale,"cursor really draws visible pixels at 1x and 2x even when NSCursor.image is empty");
    }
    [cursor updateAtScreenPoint:screen enabled:NO];check(cursor.hidden,"closing overlay removes its cursor");
    [cursor updateAtScreenPoint:NSMakePoint(-10000,-10000) enabled:YES];check(cursor.hidden,"outside-window cursor hidden");
    [cursor removeFromSuperview];[window close];
    MTOverlayRoot *overlay=[[MTOverlayRoot alloc]initWithFrame:NSMakeRect(0,0,1000,800) version:@"test"];
    MTTrainerState *presentation=[MTTrainerState new];presentation.ready=YES;[overlay updateState:presentation];
    __block NSInteger invoked=-1;overlay.featureHandler=^(MTFeature feature){invoked=feature;};
    NSEvent *optionF1=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagOption
        timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:122];
    check([overlay handleEvent:optionF1] && invoked==MTFeatureEquipmentBattery,"Option-F1 reaches the actual overlay feature handler");

    Method method=class_getInstanceMethod(FramePacingTimer.class,@selector(waitForNextFrame));IMP original=method_getImplementation(method);
    check(!MHTDSBuildMatches(),"unrelated process cannot match Death Stranding UUID");
    check(!MHTDSAttachEngine(),"same-named pacing class cannot authorize an unrelated executable");
    check(original==method_getImplementation(method),"failed identity check leaves original methods untouched");
    check(!MHTDSIsEngineThread(),"arbitrary caller is never a GameThread");
    check(!MHTDSOverlayInteraction(YES),"unbound process cannot call original cursor methods");
    __block BOOL executed=NO;MHTDSSchedule(^{executed=YES;});check(!executed,"no fallback thread executes engine work");
    MHTDSOwner owner={0};check(!MHTDSCaptureOwner(&owner),"unbound process cannot provide a player owner");
    check(!MHTDSAddStandReserve(owner,1) && !MHTDSAddStandReserve(owner,NAN),"stand-reserve native calls reject missing owners and nonfinite input");
    MHTDSTimeRequest timeRequest;MHTDSTimeControl timeControl={0};float scales[3];
    check(MHTDSPrepareTimeRequest(0.5f,&timeRequest) && timeRequest.scales[0]==0.5f
        && timeRequest.scales[1]==0.5f && timeRequest.scales[2]==0.5f && timeRequest.name==-1
        && !timeRequest.curves[0] && timeRequest.retained==1 && timeRequest.duration==3600,"native time request ABI and clean defaults");
    check(!MHTDSPrepareTimeRequest(NAN,&timeRequest) && !MHTDSPrepareTimeRequest(0,&timeRequest)
        && !MHTDSPrepareTimeRequest(4,&timeRequest),"time request rejects unsupported engine scales");
    check(!MHTDSSetTime(owner,0.5f,&timeControl) && !MHTDSReadTime(owner,scales) && !timeControl.owned,"time routines reject foreign process and missing owner");
    MHTDSClearTime(&timeControl);
    MHTDSCapacityControl capacityControl={0};float bases[2],capacity[2];
    check(!MHTDSReadCapacity(owner,bases,capacity) && !MHTDSSetCapacity(owner,150,&capacityControl)
        && !MHTDSSetCapacity(owner,NAN,&capacityControl) && !MHTDSSetCapacity(owner,1.5f,&capacityControl)
        && !capacityControl.owned,"capacity data writes require the bound current player and a valid value");
    MHTDSClearCapacity(&capacityControl);
    check(!MHTDSSetBBStressRate(owner,0) && !MHTDSSetBBStressRate(owner,NAN)
        && !MHTDSSetBBStressRate(owner,-1) && !MHTDSSetBBStressRate(owner,2),"BB stress requires current native owner and a finite valid rate");
    MHTDSClearBBRequest(0);
    check(MTFeatureCount==26,"stable requested catalog has 26 independent IDs");
    MHTNativeAdapter *adapter=[MHTNativeAdapter new];
    check(MHTDSResourceFull(970,940),"native limit drop does not clear a full-resource confirmation");
    check(!MHTDSResourceFull(800,940),"depleted resource is not marked full");
    check(!MHTDSResourceFull(NAN,940) && !MHTDSResourceFull(1000,0),"nonfinite or invalid resource limit is rejected");
    for(NSInteger i=0;i<MTFeatureCount;i++){
        const MTFeatureInfo *info=MTFeatureInfoAt(i);
        check(info!=NULL,"catalog entry exists");
        MTFeatureState *state=[adapter applyFeature:i wanted:YES value:info->initial];
        check(!state.available && !state.active,"a foreign process cannot claim native effects");
        check(info->title.length && info->detail.length,"unsupported functions state their development status");
    }
    puts("PASS: wrong-build rejection, no fallback GameThread, no accidental hooks and unavailable effects outside the bound original. No game started.");
}return 0;}
