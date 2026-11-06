// SPDX-License-Identifier: GPL-3.0-only
// Tests the real adapter's rejection of a non-game process. No fake engine.
#import "GameAdapter.h"
#import "GodotABI.h"
static void check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(void){@autoreleasepool {
    check(!DKSupportedImage(),"native ABI must reject this test executable");
    id<MTGameAdapter> adapter=MTCreateGameAdapter();
    check([adapter captureContext].kind==MTSessionUnsupported,"wrong process must never claim a solo world");
    __block BOOL delivered=NO;[adapter onGameThread:^{delivered=YES;}];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    check(!delivered,"no fake GameThread fallback outside the verified game");
    for(NSInteger i=0;i<MTFeatureCount;i++){
        MTFeatureState *state=[adapter applyFeature:i wanted:YES value:100];
        check(!state.active && !state.available,"unbound native features cannot claim success");
    }
    check(![adapter setOverlayInteraction:YES],"no fake native cursor ownership");
    [adapter releaseEffects];
    puts("PASS: Dome Keeper native UUID/ABI guard, unsupported process, no substitute GameThread or fabricated effects/cursor ownership.");
}return 0;}
