// SPDX-License-Identifier: GPL-3.0-only
#import "../../Modules/_Shared/Kex/KexEngine.h"
#import "../../Modules/_Shared/Kex/KexBits.h"
#import "../../Modules/_Shared/Kex/OverlayCursor.h"
static void check(BOOL ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
int main(){@autoreleasepool{
 check([KEXInspect()[@"kind"] integerValue]==0 && ![KEXEffect(0,YES)[@"active"] boolValue] && !KEXMouse(YES),"no effects, fake context or mouse capture outside the engine callback");
 uint32_t flags=0x100;KEXBitState bit={0};
 check(KEXApplyBit(&flags,0,8,YES,&bit) && flags==0x108 && bit.held && !bit.baseline,"native protection sets exactly its own bit");
 check(KEXApplyBit(&flags,0,8,YES,&bit) && !bit.baseline,"repeated enabling preserves the original baseline");flags|=0x200;
 check(KEXApplyBit(&flags,0,8,NO,&bit) && flags==0x300 && !bit.held,"release preserves unrelated engine bits");
 flags=8;check(KEXApplyBit(&flags,0,8,YES,&bit) && KEXApplyBit(&flags,0,8,NO,&bit) && flags==8,"pre-existing original protection is preserved");
 check(!KEXApplyBit(NULL,0,8,YES,&bit) && !KEXApplyBit(&flags,0,12,YES,&bit),"invalid owners and multi-bit writes rejected");
 MHTKexCursorView *cursor=[[MHTKexCursorView alloc]initWithFrame:NSMakeRect(0,0,20,27)];check(![cursor hitTest:NSMakePoint(3,3)],"vector cursor never intercepts clicks");
 for(NSInteger scale=1;scale<=2;scale++){
  NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:20*scale pixelsHigh:27*scale bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  memset(bitmap.bitmapData,0,bitmap.bytesPerRow*bitmap.pixelsHigh);bitmap.size=NSMakeSize(20,27);
  [NSGraphicsContext saveGraphicsState];NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];[cursor drawRect:cursor.bounds];[NSGraphicsContext restoreGraphicsState];
  BOOL visible=NO;for(NSInteger y=0;y<bitmap.pixelsHigh;y++)for(NSInteger x=0;x<bitmap.pixelsWide;x++)visible|=[bitmap colorAtX:x y:y].alphaComponent>0;check(visible,"cursor has real visible pixels at 1x and 2x");
 }
 puts("PASS: native bit ownership/readback/release, outside-frame rejection and visible click-through 1x/2x cursor. No game launched.");return 0;
}}
