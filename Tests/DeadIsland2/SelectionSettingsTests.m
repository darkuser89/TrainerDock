// SPDX-License-Identifier: GPL-3.0-only
#import "SelectionSettings.h"
#include <math.h>

void DI2TestSelectionSettings(void) {
    NSDictionary *raw=@{@"features":@{@"0":@{@"wanted":@YES},@"5":@{@"wanted":@YES,@"value":@3},
        @"13":@{@"wanted":@YES,@"value":@12345},@"22":@{@"wanted":@YES},@"24":@{@"wanted":@YES},
        @"6":@{@"value":@(NAN)},@"7":@{@"value":@999},@"9":@{@"value":@"99"},
        @"999":@{@"wanted":@YES}}};
    NSDictionary *clean=DI2NormalizeCheatSelection(raw), *entries=clean[@"features"];
    NSCAssert([entries count]==DI2FeatureCount && [entries[@"0"][@"wanted"] boolValue],@"complete bounded selection");
    NSCAssert([entries[@"5"][@"value"] doubleValue]==3 && [entries[@"13"][@"value"] doubleValue]==12345,@"valid numeric values persist");
    for(NSInteger i=0;i<DI2FeatureCount;i++) if(DI2FeatureInfoAt(i)->oneShot) {
        NSString *key=[NSString stringWithFormat:@"%ld",(long)i];
        NSCAssert(![entries[key][@"wanted"] boolValue],@"one-shots never restore");
    }
    for(NSNumber *index in @[@6,@7,@9]) {
        NSInteger i=index.integerValue;
        NSCAssert([entries[index.stringValue][@"value"] doubleValue]==DI2FeatureInfoAt(i)->initial,@"invalid parameters fall back to catalog defaults");
    }
    NSCAssert([DI2DecodeCheatSelection(DI2EncodeCheatSelection(raw)) isEqual:clean],@"JSON round-trip");
    for(id bad in @[NSNull.null,@[],@42,@"bad",@{@"features":@[]}])
        NSCAssert([DI2NormalizeCheatSelection(bad) isEqual:DI2NormalizeCheatSelection(nil)],@"malformed preferences rejected");
    for(NSString *bad in @[@"[]",@"not json",[@"x" stringByPaddingToLength:17000 withString:@"x" startingAtIndex:0]])
        NSCAssert([DI2DecodeCheatSelection(bad) isEqual:DI2NormalizeCheatSelection(nil)],@"malformed environment rejected");
    NSString *message=DI2SelectionMessage(clean,@"session",@"mas",123);
    NSCAssert([DI2SelectionMessageSelection(message,@"session",@"mas",123) isEqual:clean],@"matching session/profile/process accepted");
    NSCAssert(!DI2SelectionMessageSelection(message,@"other",@"mas",123)
        && !DI2SelectionMessageSelection(message,@"session",@"steam",123)
        && !DI2SelectionMessageSelection(message,@"session",@"mas",124)
        && !DI2SelectionMessageSelection(@"[]",@"session",@"mas",123),@"unrelated or malformed reports ignored");
    NSCAssert(![DI2SelectionPreferencesKey(@"mas") isEqual:DI2SelectionPreferencesKey(@"steam")],@"store selections remain separate");
    DI2TrainerState *state=[DI2TrainerState new];state.features[0].wanted=YES;state.features[13].wanted=YES;
    NSDictionary *snapshot=DI2SelectionFromState(state);
    NSCAssert([snapshot[@"features"][@"0"][@"wanted"] boolValue] && ![snapshot[@"features"][@"13"][@"wanted"] boolValue],@"snapshot filters one-shots");
    puts("Selection checks passed: all 26 entries, one-shot exclusion, bounds, malformed data, JSON and session/profile/PID isolation.");
}
