// SPDX-License-Identifier: GPL-3.0-only
// The genuine adapter must reject this process; no Unity fixture is shipped.
#import "GameAdapter.h"
#import "MonoRuntime.h"
static void check(BOOL condition,const char *message){if(!condition){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(void){@autoreleasepool {
 check(!DUSupportedImage(),"test process must not pass the original UUID gate");
 id<MTGameAdapter> adapter=MTCreateGameAdapter();
 __block BOOL ran=NO;[adapter onGameThread:^{ran=YES;}];
 [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
 check(!ran,"no main-queue substitute for Unity PlayerLoop");
 check([adapter captureContext].kind==MTSessionUnsupported,"no imaginary local owner");
 for(NSInteger i=0;i<MTFeatureCount;i++){
  MTFeatureState *state=[adapter applyFeature:i wanted:YES value:2];
  check(!state.available && !state.active,"native readback required for every feature");
 }
 check(![adapter setOverlayInteraction:YES],"no fabricated cursor ownership");
 [adapter releaseEffects];
 puts("PASS: Duckov original UUID guard, unsupported-process rejection, no fake GameThread, effects or cursor.");
}return 0;}
