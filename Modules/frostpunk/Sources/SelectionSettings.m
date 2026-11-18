// SPDX-License-Identifier: GPL-3.0-only
#import "SelectionSettings.h"
#include <math.h>

NSString *const MTSelectionRestorePreferencesKey=@"RestoreCheats.v1";
NSString *const MTSelectionChangedNotification=@"local.mactrainer.template.selection-changed";
NSString *MTSelectionPreferencesKey(NSString *profile) {
    return [@"CheatSelection.v1." stringByAppendingString:profile ?: @""];
}
NSDictionary *MTNormalizeCheatSelection(id input) {
    NSDictionary *source=[input isKindOfClass:NSDictionary.class] ? input : @{};
    NSDictionary *entries=[source[@"features"] isKindOfClass:NSDictionary.class] ? source[@"features"] : @{};
    NSMutableDictionary *clean=[NSMutableDictionary new];
    for (NSInteger i=0;i<MTFeatureCount;i++) {
        const MTFeatureInfo *info=MTFeatureInfoAt(i);
        NSDictionary *entry=[entries[[NSString stringWithFormat:@"%ld",(long)i]] isKindOfClass:NSDictionary.class]
            ? entries[[NSString stringWithFormat:@"%ld",(long)i]] : @{};
        BOOL wanted=info->implemented && !info->oneShot && [entry[@"wanted"] isKindOfClass:NSNumber.class]
            && [entry[@"wanted"] boolValue];
        double value=info->initial;
        if (info->numeric && [entry[@"value"] isKindOfClass:NSNumber.class]) {
            double candidate=[entry[@"value"] doubleValue];
            if (isfinite(candidate) && candidate>=info->minimum && candidate<=info->maximum
                && (!info->integer || floor(candidate)==candidate)) value=candidate;
        }
        clean[[NSString stringWithFormat:@"%ld",(long)i]]=@{@"wanted":@(wanted),@"value":@(value)};
    }
    return @{@"features":clean};
}
NSDictionary *MTSelectionFromState(MTTrainerState *state) {
    NSMutableDictionary *entries=[NSMutableDictionary new];
    if (state.features.count!=(NSUInteger)MTFeatureCount) return MTNormalizeCheatSelection(nil);
    for (NSInteger i=0;i<MTFeatureCount;i++) {
        MTFeatureState *feature=state.features[i];
        entries[[NSString stringWithFormat:@"%ld",(long)i]]=@{@"wanted":@(feature.wanted),@"value":@(feature.value)};
    }
    return MTNormalizeCheatSelection(@{@"features":entries});
}
NSString *MTEncodeCheatSelection(id input) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:MTNormalizeCheatSelection(input) options:0 error:NULL];
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}
NSDictionary *MTDecodeCheatSelection(NSString *json) {
    if (![json isKindOfClass:NSString.class] || json.length>16384) return MTNormalizeCheatSelection(nil);
    NSData *data=[json dataUsingEncoding:NSUTF8StringEncoding];
    return MTNormalizeCheatSelection(data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil);
}
NSString *MTSelectionMessage(id selection, NSString *session, NSString *profile, int pid) {
    if (!session.length || session.length>128 || !profile.length || profile.length>128 || pid<=0) return nil;
    NSDictionary *envelope=@{@"session":session,@"profile":profile,@"pid":@(pid),
        @"selection":MTNormalizeCheatSelection(selection)};
    NSData *data=[NSJSONSerialization dataWithJSONObject:envelope options:0 error:NULL];
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
}
NSDictionary *MTSelectionMessageSelection(id message, NSString *session, NSString *profile, int pid) {
    if (![message isKindOfClass:NSString.class] || [message length]>16384 || !session.length || !profile.length || pid<=0) return nil;
    NSData *data=[message dataUsingEncoding:NSUTF8StringEncoding];
    id decoded=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if (![decoded isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *envelope=decoded;
    if (![session isEqual:envelope[@"session"]] || ![profile isEqual:envelope[@"profile"]]
        || ![envelope[@"pid"] isKindOfClass:NSNumber.class] || [envelope[@"pid"] doubleValue]!=pid
        || ![envelope[@"selection"] isKindOfClass:NSDictionary.class]) return nil;
    return MTNormalizeCheatSelection(envelope[@"selection"]);
}
