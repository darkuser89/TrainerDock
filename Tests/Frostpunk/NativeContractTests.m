// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "OverlayCursor.h"
#include <stdlib.h>
// Selection contracts need the module's selection implementation. Keep them
// with the full native test, not the minimal catalog exporter's SDL fixtures.
#define check catalogCheck
#import "CatalogTests.m"
#undef check
void MHTFrostpunkEngineContractTests(void);
void MHTFrostpunkResourceContractTests(void);
static void check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(void){@autoreleasepool{
    MHTFrostpunkCatalogContractTests();
    MHTFrostpunkEngineContractTests();
    MHTFrostpunkResourceContractTests();
    MHTFrostpunkCursorView *cursor=[[MHTFrostpunkCursorView alloc]initWithFrame:NSMakeRect(0,0,20,27)];
    check(![cursor hitTest:NSMakePoint(3,3)],"cursor must never consume clicks");
    for(NSInteger scale=1;scale<=2;scale++){
        NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:20*scale pixelsHigh:27*scale bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        check(bitmap!=nil,"cursor bitmap allocation");
        memset(bitmap.bitmapData,0,bitmap.bytesPerRow*bitmap.pixelsHigh);
        bitmap.size=NSMakeSize(20,27);
        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
        [cursor drawRect:cursor.bounds];
        [NSGraphicsContext restoreGraphicsState];
        BOOL visible=NO;
        for(NSInteger y=0;y<bitmap.pixelsHigh;y++)for(NSInteger x=0;x<bitmap.pixelsWide;x++)
            visible|=[bitmap colorAtX:x y:y].alphaComponent>0;
        check(visible,"cursor needs visible pixels at 1x and 2x");
    }
    puts("PASS: Frostpunk native contracts and visible 1x/2x cursor; no game launched.");
    return 0;
}}
