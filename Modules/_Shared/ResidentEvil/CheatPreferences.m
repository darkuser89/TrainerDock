// SPDX-License-Identifier: GPL-3.0-only
#import "CheatPreferences.h"
#import "RE4Features.h"
#import "RE7Features.h"
#import "RE8Features.h"
#include <math.h>
NSString *const RE2RestoreCheatsKey=@"RestoreCheatSelection.v1";
NSString *const RE2SelectionChangedNotification=@"local.mactrainer.selection-changed.v1";
static NSInteger game(NSString *profile){return [@[@"re2-mac-1.0.2",@"re3-mac-1.0.0",@"re4-mac-1.0.7",@"re7-mac-1.0.4",@"re8-mac-1.1.8"] indexOfObject:profile ?: @""];}
NSInteger RE2SelectionCount(NSString *profile){NSInteger g=game(profile);return g==0 ? RE2FeatureCount : g==1 ? RE3FeatureCount : g==2 ? RE4FeatureCount : g==3 ? RE7FeatureCount : g==4 ? RE8FeatureCount : 0;}
static const RE2FeatureInfo *info(NSString *profile,NSInteger i){NSInteger g=game(profile);return g<2 ? RE2FeatureInfoForGame(i,g==1) : g==2 ? RE4FeatureInfoAt(i) : g==3 ? RE7FeatureInfoAt(i) : RE8FeatureInfoAt(i);}
static NSString *binding(const RE2FeatureInfo *f,NSInteger i){return [NSString stringWithFormat:@"%ld:%hu:%lu:%d:%d",(long)i,f->key,(unsigned long)f->modifiers,f->numeric,f->oneShot];}
NSString *RE2CurrentSelectionProfile(void){return RE2IsRE8Game() ? @"re8-mac-1.1.8" : RE2IsRE7Game() ? @"re7-mac-1.0.4" : RE2IsRE4Game() ? @"re4-mac-1.0.7" : RE2IsRE3Game() ? @"re3-mac-1.0.0" : @"re2-mac-1.0.2";}
NSString *RE2SelectionKey(NSString *profile){return RE2SelectionCount(profile) ? [@"CheatSelection.v1." stringByAppendingString:profile] : nil;}
NSDictionary *RE2NormalizeSelection(id input,NSString *profile){
    NSInteger count=RE2SelectionCount(profile);if(!count || ![input isKindOfClass:NSDictionary.class])return nil;
    NSDictionary *source=input;NSArray *rows=source[@"features"];
    if(![source[@"schema"] isEqual:@1] || ![source[@"profile"] isEqual:profile] || ![rows isKindOfClass:NSArray.class] || (rows.count!=(NSUInteger)count && !([profile isEqual:@"re2-mac-1.0.2"] && rows.count==RE2FeaturePortableSafe)))return nil;
    NSMutableArray *clean=[NSMutableArray new];
    for(NSInteger i=0;i<count;i++){
        const RE2FeatureInfo *f=info(profile,i);id entry=i<(NSInteger)rows.count ? rows[i] : @{@"binding":binding(f,i),@"wanted":@NO,@"value":@(f->initial)};if(![entry isKindOfClass:NSDictionary.class] || ![entry[@"binding"] isEqual:binding(f,i)])return nil;
        id raw=entry[@"value"];double value=[raw isKindOfClass:NSNumber.class] ? [raw doubleValue] : NAN;
        if(!f->numeric || !isfinite(value) || value<f->minimum || value>f->maximum || (f->integer && floor(value)!=value))value=f->initial;
        BOOL wanted=[entry[@"wanted"] isKindOfClass:NSNumber.class] && [entry[@"wanted"] boolValue] && f->implemented && !f->oneShot;
        [clean addObject:@{@"binding":binding(f,i),@"wanted":@(wanted),@"value":@(value)}];
    }return @{@"schema":@1,@"profile":profile,@"features":clean};
}
NSDictionary *RE2SelectionFromState(RE2TrainerState *state,NSString *profile){
    NSInteger count=RE2SelectionCount(profile);if(!count || state.features.count!=(NSUInteger)count)return nil;
    NSMutableArray *rows=[NSMutableArray new];for(NSInteger i=0;i<count;i++){
        const RE2FeatureInfo *f=info(profile,i);RE2FeatureState *s=state.features[i];
        [rows addObject:@{@"binding":binding(f,i),@"wanted":@(s.wanted && !f->oneShot),@"value":@(isfinite(s.value) ? s.value : f->initial)}];
    }return RE2NormalizeSelection(@{@"schema":@1,@"profile":profile,@"features":rows},profile);
}
static NSString *encode(id object){NSData *d=object ? [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingSortedKeys error:NULL] : nil;return d ? [[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding] : nil;}
static id decode(id json){if(![json isKindOfClass:NSString.class] || [json length]>16384)return nil;NSData *d=[json dataUsingEncoding:NSUTF8StringEncoding];return d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL] : nil;}
NSString *RE2EncodeSelection(NSDictionary *selection){return encode(RE2NormalizeSelection(selection,selection[@"profile"]));}
NSDictionary *RE2DecodeSelection(id json,NSString *profile){return RE2NormalizeSelection(decode(json),profile);}
NSString *RE2SelectionMessage(NSDictionary *selection,NSString *session,int pid){if(!session.length || session.length>128 || pid<=0 || !selection)return nil;return encode(@{@"session":session,@"pid":@(pid),@"selection":selection});}
NSDictionary *RE2SelectionMessageOptions(id json,NSString *profile,NSString *session,int pid){
    id decoded=decode(json);if(![decoded isKindOfClass:NSDictionary.class] || !session.length || pid<=0)return nil;
    NSDictionary *d=decoded;if(![d[@"session"] isEqual:session] || ![d[@"pid"] isKindOfClass:NSNumber.class] || [d[@"pid"] doubleValue]!=pid)return nil;
    return RE2NormalizeSelection(d[@"selection"],profile);
}
