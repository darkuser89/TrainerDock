// SPDX-License-Identifier: GPL-3.0-only
// Synthetic memory/queue checks; never linked into the delivered trainer.
#import "NMSAdapter.h"
#import "NMSBuilds.h"
#import "GameBridge.h"
#import "OverlayCursor.h"
#import <objc/runtime.h>
#include <math.h>
@interface NMSInputViewFixture : NSView { @public BOOL isMouseCaptured; }
@end
@implementation NMSInputViewFixture @end
@interface NMSDelayedFixture : NSObject <MTGameAdapter>
@property(nonatomic) NSMutableArray<dispatch_block_t> *pending;
@property(nonatomic) NSUInteger actions;
@property(nonatomic) MTSessionKind mode;
@property(nonatomic) BOOL readOnly;
@end
@implementation NMSDelayedFixture
- (instancetype)init {if((self=[super init])){_pending=[NSMutableArray new];_mode=MTSessionSolo;}return self;}
- (void)onGameThread:(dispatch_block_t)work {[_pending addObject:[work copy]];}
- (MTGameContext *)captureContext {MTGameContext *c=[MTGameContext new];c.kind=_mode;c.readOnly=_readOnly;c.identity=@"fixture";return c;}
- (void)releaseEffects {}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {(void)feature;(void)value;MTFeatureState *s=[MTFeatureState new];s.available=YES;s.active=wanted;return s;}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {(void)feature;(void)value;_actions++;return @"fixture";}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return wanted;}
@end
static void check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static void flush(NMSDelayedFixture *f){for(int i=0;i<8;i++){if(f.pending.count){dispatch_block_t w=f.pending.firstObject;[f.pending removeObjectAtIndex:0];w();}[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.003]];}}
int main(void){@autoreleasepool{
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    ptrdiff_t field=MTNMSCaptureIvarOffset(NMSInputViewFixture.class);
    check(field==ivar_getOffset(class_getInstanceVariable(NMSInputViewFixture.class,"isMouseCaptured")) && field>44,"native capture field follows AppKit's runtime superclass layout");
    check(MTNMSCaptureIvarOffset(NSView.class)<0,"missing native capture field rejected");
    NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,800,600) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed=NO;[window orderFront:nil];
    MHTNMSCursorView *cursor=[[MHTNMSCursorView alloc]initWithFrame:NSZeroRect];[window.contentView addSubview:cursor];
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
    check(MTFeatureCount==30,"full original feature catalog retained");
    for(NSInteger i=0;i<MTFeatureCount;i++){
        const MTFeatureInfo *a=MTFeatureInfoAt(i);
        check(a && (!a->numeric || (isfinite(a->initial) && a->minimum<=a->initial && a->initial<=a->maximum)),"catalog bounds");
        for(NSInteger j=i+1;j<MTFeatureCount;j++){const MTFeatureInfo *b=MTFeatureInfoAt(j);check(a->key!=b->key || a->modifiers!=b->modifiers,"unique hotkeys");}
    }
    check(MTNMSBuildUUIDSupported(MTNMSOriginalUUID) && MTNMSBuildUUIDSupported(MTNMSUpdatedUUID),"only both explicitly bound original builds accepted");
    check(!MTNMSBuildUUIDSupported(nil) && !MTNMSBuildUUIDSupported(@"00000000-0000-0000-0000-000000000000"),"unknown UUID rejected");
    for(NSUInteger i=0;i<sizeof(MTNMSNativeBindings)/sizeof(*MTNMSNativeBindings);i++){
        const MTNMSNativeBinding *b=&MTNMSNativeBindings[i];
        check(MTNMSPreferredAddress(MTNMSOriginalUUID,b->original)==b->original,"old build retains its original binding");
        check(MTNMSPreferredAddress(MTNMSUpdatedUUID,b->original)==b->updated && b->updated!=b->original,"updated build selects its independently resolved binding");
        check(!MTNMSPreferredAddress(@"unknown",b->original),"a known key cannot bypass build identity");
        for(NSUInteger j=0;j<i;j++)check(MTNMSNativeBindings[j].original!=b->original,"binding keys unique");
    }
    check(!MTNMSPreferredAddress(MTNMSOriginalUUID,0x100000000) && !MTNMSPreferredAddress(MTNMSUpdatedUUID,0x100000000),"unlisted native address never falls back across builds");
    check(!MTNMSProcessBuildMatches(),"test process cannot bind the original game");
    MTNMSAdapter *native=[MTNMSAdapter new];
    check(![native applyFeature:MTFeatureHealth wanted:YES value:0].active,"off-frame writes rejected");
    check(![native setOverlayInteraction:YES],"off-frame mouse takeover rejected");
    uint8_t flag=0,one=1;MTNMSValue *lease=[[MTNMSValue alloc]initWithAddress:&flag size:1];
    check(![lease applyBytes:&one readOnly:YES] && flag==0 && !lease.ownsValue,"read-only cannot acquire a data lease");
    check([lease applyBytes:&one readOnly:NO] && flag==1,"native byte write/readback");
    check([lease applyBytes:&one readOnly:NO] && [lease releaseValue] && flag==0,"polling preserves the first baseline");
    float original=1,target=2;MTNMSValue *scalar=[[MTNMSValue alloc]initWithAddress:&original size:4];
    check([scalar applyBytes:&target readOnly:NO] && original==2,"native float representation");
    original=3;check(![scalar applyBytes:&target readOnly:NO] && [scalar releaseValue] && original==3,"foreign edits preserved");
    uint32_t sessions[3]={0};check(MTNMSSessionKind(YES,NO,sessions)==MTSessionSolo,"native offline context");
    check(MTNMSSessionKind(YES,YES,sessions)==MTSessionSolo,"network flags do not gate a valid player");
    for(int i=0;i<3;i++){sessions[i]=4;check(MTNMSSessionKind(YES,NO,sessions)==MTSessionSolo,"lobby state does not block local ownership");sessions[i]=UINT32_MAX;check(MTNMSSessionKind(YES,NO,sessions)==MTSessionSolo,"unrelated unknown lobby does not block");sessions[i]=0;}
    uint8_t edit[72]={0};check(!MTNMSPrepareRecharge(edit,sizeof(edit)) && !MTNMSPrepareRecharge(edit,71),"invalid inventory edit cannot be committed");
    NMSDelayedFixture *fixture=[NMSDelayedFixture new];MTGameBridge *bridge=[[MTGameBridge alloc]initWithAdapter:fixture];
    [bridge poll];flush(fixture);check(bridge.state.ready,"valid fixture");
    [bridge performFeature:MTFeatureMoney];[bridge performAction:MTTrainerDisableAll];flush(fixture);check(fixture.actions==0,"all-off cancels an in-flight one-shot");
    [bridge performFeature:MTFeatureMoney];[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.05]];flush(fixture);check(fixture.actions==0,"expired one-shot rejected");
    fixture.mode=MTSessionNetwork;[bridge poll];flush(fixture);[bridge performFeature:MTFeatureMoney];flush(fixture);check(bridge.state.ready && fixture.actions==1,"network does not block explicit native commands");
    fixture.mode=MTSessionSolo;fixture.readOnly=YES;[bridge poll];flush(fixture);[bridge performFeature:MTFeatureMoney];flush(fixture);check(!bridge.state.ready && fixture.actions==1,"read-only blocks UI commands");
    puts("PASS: No Man’s Sky runtime ivar layout, visible 1x/2x cursor pixels, native gates, memory leases, foreign writes, network-independent commands and one-shot cancellation. Synthetic only.");
}return 0;}
