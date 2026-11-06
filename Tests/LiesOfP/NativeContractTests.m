// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "LiesOfPAdapter.h"
int main(void){@autoreleasepool{
 NSCAssert(MTFeatureCount==36&&MTFeatureHealth==0,@"No master option in native catalog");
 LOPGameAdapter *adapter=[LOPGameAdapter new];NSCAssert([adapter captureContext].kind==MTSessionUnsupported,@"Unrelated executable cannot access native game bindings");
 for(NSInteger i=0;i<MTFeatureCount;i++){
  const MTFeatureInfo *f=MTFeatureInfoAt(i);NSCAssert(![f->title containsString:@"Trainer aktivieren"],@"Removed action cannot be displayed");
  MTFeatureState *s=[adapter applyFeature:i wanted:YES value:f->initial];NSCAssert(!s.available&&!s.active,@"Removing the master preserves real process/context checks");
 }
 __block BOOL done=NO;[adapter onGameThread:^{done=YES;}];NSDate *until=[NSDate dateWithTimeIntervalSinceNow:1];while(!done&&until.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]];NSCAssert(done,@"Unsupported process completes without pretending to be the GameThread");
 [adapter releaseEffects];puts("Lies of P catalog/native context checks passed");
}return 0;}
