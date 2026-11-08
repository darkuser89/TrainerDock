// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "OverlayCursor.h"
static void check(BOOL v,const char *s){if(!v){fprintf(stderr,"FAIL: %s\n",s);exit(1);}}
int main(void){@autoreleasepool{
 [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
 NSWindow *w=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,800,600) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];w.releasedWhenClosed=NO;[w orderFront:nil];
 MHTIZCursorView *c=[[MHTIZCursorView alloc]initWithFrame:NSZeroRect];[w.contentView addSubview:c];
 NSPoint p=NSMakePoint(200,300);[c updateAtScreenPoint:[w convertPointToScreen:p] enabled:YES];check(!c.hidden&&![c hitTest:NSZeroPoint],"cursor is visible and click-through");
 NSPoint h=c.pointerHotspot;check(fabs(NSMinX(c.frame)+h.x-p.x)<1&&fabs(NSMaxY(c.frame)-h.y-p.y)<1,"native-coordinate hotspot");
 for(NSInteger scale=1;scale<=2;scale++){
  NSSize s=c.pointerSize;NSBitmapImageRep *r=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:s.width*scale pixelsHigh:s.height*scale bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  [NSGraphicsContext saveGraphicsState];NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:r];CGContextClearRect(NSGraphicsContext.currentContext.CGContext,CGRectMake(0,0,r.pixelsWide,r.pixelsHigh));CGContextScaleCTM(NSGraphicsContext.currentContext.CGContext,scale,scale);[c drawRect:NSMakeRect(0,0,s.width,s.height)];[NSGraphicsContext restoreGraphicsState];
  NSUInteger count=0;for(NSInteger y=0;y<r.pixelsHigh;y++)for(NSInteger x=0;x<r.pixelsWide;x++)if([r colorAtX:x y:y].alphaComponent>.5)count++;check(count>50*(NSUInteger)(scale*scale),"actual visible cursor pixels at both backing scales");
 }
 [c updateAtScreenPoint:NSZeroPoint enabled:NO];check(c.hidden,"hidden after release");[c removeFromSuperview];[w close];puts("PASS: visible 1x/2x cursor pixels, native hotspot, click-through and release. No game started.");
}return 0;}
