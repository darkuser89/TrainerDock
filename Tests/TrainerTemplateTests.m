// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
#import "SelectionSettings.h"
#import "OverlaySettings.h"
static void check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
int main(void){@autoreleasepool {
    id<MTGameAdapter> adapter=MTCreateGameAdapter();
    check([adapter captureContext].kind==MTSessionUnsupported,"template must not claim a real game context");
    __block BOOL executed=NO;[adapter onGameThread:^{executed=YES;}];
    check(!executed,"missing engine delivery must never execute a fake GameThread callback");
    for(NSInteger i=0;i<MTFeatureCount;i++){
        check(!MTFeatureInfoAt(i)->implemented,"template exposes no implemented cheat");
        MTFeatureState *state=[adapter applyFeature:i wanted:YES value:100];
        check(!state.active && !state.available,"template cannot claim native effects");
    }
    check(![adapter setOverlayInteraction:YES],"no fabricated cursor ownership");
    NSDictionary *selection=MTNormalizeCheatSelection(@{@"features":@{@"0":@{@"wanted":@YES,@"value":@100}}});
    check(![selection[@"features"][@"0"][@"wanted"] boolValue],"unimplemented selection remains disabled");
    check(![MTNormalizeOverlayOptions(@{@"liquidGlass":@NO})[@"liquidGlass"] boolValue],"native glass option is preserved");
    puts("PASS: neutral template compiles, refuses fake context/thread/effects, and keeps unsupported selection disabled.");
}return 0;}
