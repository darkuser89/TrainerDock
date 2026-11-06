// SPDX-License-Identifier: GPL-3.0-only
#import "SelectionSettings.h"
#include <math.h>
NSString *const MTSelectionChangedNotification=@"local.mactrainer.liesofp.selection-changed";
static NSDictionary *defaults(void) {
    NSMutableArray *entries=[NSMutableArray new];
    for(NSInteger i=0;i<MTFeatureCount;i++){
        const MTFeatureInfo *info=MTFeatureInfoAt(i);
        if(info->implemented && !info->oneShot)[entries addObject:@{@"id":@(i),@"wanted":@NO,@"value":@(info->initial)}];
    }
    return @{@"schema":@1,@"catalog":@"liesofp-36-v2",@"features":entries};
}
NSDictionary *MTNormalizeSelection(id input) {
    NSDictionary *empty=defaults();
    BOOL legacy=[input isKindOfClass:NSDictionary.class] && [input[@"catalog"] isEqual:@"liesofp-37-v1"];
    if(![input isKindOfClass:NSDictionary.class] || ![input[@"schema"] isEqual:@1] || (!legacy && ![input[@"catalog"] isEqual:@"liesofp-36-v2"]) || ![input[@"features"] isKindOfClass:NSArray.class] || [input[@"features"] count]>(legacy ? MTFeatureCount+1 : MTFeatureCount))return empty;
    NSMutableDictionary<NSNumber *,NSDictionary *> *byID=[NSMutableDictionary new];
    for(id entry in input[@"features"]){
        if(![entry isKindOfClass:NSDictionary.class])return empty;
        NSNumber *identifier=entry[@"id"],*wanted=entry[@"wanted"],*value=entry[@"value"];
        if(![identifier isKindOfClass:NSNumber.class] || !isfinite(identifier.doubleValue) || floor(identifier.doubleValue)!=identifier.doubleValue || identifier.doubleValue<0 || identifier.doubleValue>=(legacy ? MTFeatureCount+1 : MTFeatureCount))return empty;
        NSInteger index=identifier.integerValue;if(legacy){if(index==0)continue;index--;}const MTFeatureInfo *info=MTFeatureInfoAt(index);
        if(!info->implemented || info->oneShot)continue;
        if(byID[@(index)] || ![wanted isKindOfClass:NSNumber.class] || (wanted.doubleValue!=0 && wanted.doubleValue!=1) ||
           ![value isKindOfClass:NSNumber.class] || !isfinite(value.doubleValue) || value.doubleValue<info->minimum || value.doubleValue>info->maximum || (info->integer && floor(value.doubleValue)!=value.doubleValue))return empty;
        byID[@(index)]=@{@"id":@(index),@"wanted":@(wanted.boolValue),@"value":@(value.doubleValue)};
    }
    NSMutableArray *entries=[NSMutableArray new];
    for(NSDictionary *entry in empty[@"features"])[entries addObject:byID[entry[@"id"]] ?: entry];
    return @{@"schema":@1,@"catalog":@"liesofp-36-v2",@"features":entries};
}
NSDictionary *MTSelectionForFeatures(NSArray<MTFeatureState *> *features) {
    if(features.count!=MTFeatureCount)return defaults();
    NSMutableArray *entries=[NSMutableArray new];
    for(NSInteger i=0;i<MTFeatureCount;i++){
        const MTFeatureInfo *info=MTFeatureInfoAt(i);if(!info->implemented || info->oneShot)continue;
        MTFeatureState *feature=features[i];
        [entries addObject:@{@"id":@(i),@"wanted":@(feature.wanted),@"value":@(feature.value)}];
    }
    return MTNormalizeSelection(@{@"schema":@1,@"catalog":@"liesofp-36-v2",@"features":entries});
}
NSString *MTEncodeSelection(id input) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:MTNormalizeSelection(input) options:0 error:NULL];
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
}
NSDictionary *MTDecodeSelection(id input) {
    if(![input isKindOfClass:NSString.class] || [input length]>8192)return defaults();
    NSData *data=[input dataUsingEncoding:NSUTF8StringEncoding];
    return MTNormalizeSelection(data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil);
}
static NSString *preferenceKey(NSString *profile) {
    return [profile isKindOfClass:NSString.class] && profile.length && profile.length<=128 ? [@"FeatureSelection.v1." stringByAppendingString:profile] : nil;
}
NSDictionary *MTLoadSelection(NSUserDefaults *preferences,NSString *profile) {
    NSString *key=preferenceKey(profile);return MTNormalizeSelection(key?[preferences objectForKey:key]:nil);
}
static NSString *restoreKey(NSString *profile) {
    NSString *key=preferenceKey(profile);return key?[@"RestoreLastSelection." stringByAppendingString:profile]:nil;
}
BOOL MTShouldRestoreSelection(NSUserDefaults *preferences,NSString *profile) {
    NSString *key=restoreKey(profile);return key && [preferences boolForKey:key];
}
void MTSetRestoreSelection(NSUserDefaults *preferences,NSString *profile,BOOL enabled) {
    NSString *key=restoreKey(profile);if(key)[preferences setBool:enabled forKey:key];
}
NSDictionary *MTLoadLaunchSelection(NSUserDefaults *preferences,NSString *profile) {
    return MTShouldRestoreSelection(preferences,profile)?MTLoadSelection(preferences,profile):defaults();
}
void MTSaveSelection(NSUserDefaults *preferences,NSString *profile,id selection) {
    NSString *key=preferenceKey(profile);if(!key)return;
    NSDictionary *normalized=MTNormalizeSelection(selection);
    if(![normalized isEqual:[preferences objectForKey:key]])[preferences setObject:normalized forKey:key];
}
NSString *MTSelectionMessage(id selection,NSString *session,int pid) {
    if(!session.length || session.length>128 || pid<=0)return nil;
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"session":session,@"pid":@(pid),@"selection":MTNormalizeSelection(selection)} options:0 error:NULL];
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
}
NSDictionary *MTSelectionMessageValue(id message,NSString *session,int pid) {
    if(![message isKindOfClass:NSString.class] || [message length]>8192 || !session.length || pid<=0)return nil;
    NSData *data=[message dataUsingEncoding:NSUTF8StringEncoding];
    id envelope=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
    if(![envelope isKindOfClass:NSDictionary.class] || ![session isEqual:envelope[@"session"]] || ![envelope[@"pid"] isKindOfClass:NSNumber.class] || [envelope[@"pid"] doubleValue]!=pid || ![envelope[@"selection"] isKindOfClass:NSDictionary.class])return nil;
    return MTNormalizeSelection(envelope[@"selection"]);
}
