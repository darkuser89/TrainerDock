// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "NativeAdapter.h"
#import "MonoRuntime.h"
int main(void){@autoreleasepool{
 NSCAssert(!VSSupportedImage(),@"A test process cannot impersonate the pinned game");
 NSCAssert(MTFeatureCount==19,@"Stable requested catalog");
 for(NSInteger i=12;i<19;i++)NSCAssert(MTFeatureInfoAt(i)->modifiers==1,@"Shift hotkeys use the overlay's compact modifier mask");
 NSCAssert(!MTFeatureInfoAt(MTFeatureExp)->integer&&!MTFeatureInfoAt(MTFeatureCoins)->integer,@"Original floating-point values can be restored without rounding");
 MHTNativeAdapter *a=[MHTNativeAdapter new];NSCAssert([a captureContext].kind==MTSessionUnsupported,@"No fabricated Unity context");
 for(NSInteger i=0;i<19;i++){const MTFeatureInfo *f=MTFeatureInfoAt(i);NSCAssert(f&&f->implemented&&f->oneShot==(i>=9),@"Real implemented action types");MTFeatureState *s=[a applyFeature:i wanted:YES value:f->initial];NSCAssert(!s.active&&!s.available,@"No effects in an unrelated process");}
 __block BOOL done=NO;[a onGameThread:^{done=YES;}];NSDate *until=[NSDate dateWithTimeIntervalSinceNow:1];while(!done&&until.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]];NSCAssert(done,@"Unsupported identity completes without a synthetic GameThread");
 NSCAssert(![a setOverlayInteraction:YES],@"No foreign-process cursor manipulation");puts("Vampire Survivors identity/adapter checks passed");
}return 0;}
