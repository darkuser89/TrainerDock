// SPDX-License-Identifier: GPL-3.0-only
#import "OverlaySettings.h"
#import "MHTGlassIntensity.h"
#include <math.h>

NSString *const RE2OverlayPreferencesKey=@"OverlayOptions.v1";
NSString *const RE2OverlaySettingsNotification=@"local.mactrainer.template.overlay-settings";
NSString *const RE2OverlayChangedNotification=@"local.mactrainer.template.overlay-changed";
static double bounded(id value, double fallback, double minimum, double maximum) {
    if (![value isKindOfClass:NSNumber.class] || !isfinite([value doubleValue])) return fallback;
    return MIN(maximum,MAX(minimum,[value doubleValue]));
}
NSDictionary *RE2NormalizeOverlayOptions(id input) {
    NSDictionary *source=[input isKindOfClass:NSDictionary.class] ? input : @{};
    NSString *position=[source[@"position"] isKindOfClass:NSString.class] ? source[@"position"] : @"top-left";
    if (![@[@"top-left",@"top-right",@"bottom-left",@"bottom-right",@"center",@"free"] containsObject:position]) position=@"top-left";
    return @{@"glassIntensity":@(MHTGlassIntensity(source[@"glassIntensity"])),@"liquidGlass":@(bounded(source[@"liquidGlass"],1,0,1)!=0),@"visible":@(bounded(source[@"visible"],0,0,1)!=0),
        @"badge":@(bounded(source[@"badge"],0,0,1)!=0),
        // Retain the wire key for older preferences/launchers. Visible UI is
        // always interactive; there is no separate mouse activation state.
        @"mouse":@YES,
        @"draggable":@(bounded(source[@"draggable"],1,0,1)!=0),@"position":position,
        @"x":@(bounded(source[@"x"],0,0,1)),@"y":@(bounded(source[@"y"],0,0,1)),
        @"scale":@(bounded(source[@"scale"],0.9,0.7,1.3))};
}
NSString *RE2EncodeOverlayOptions(NSDictionary *options) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:RE2NormalizeOverlayOptions(options) options:0 error:NULL];
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}
NSDictionary *RE2OverlayOptionsForLaunch(id input) {
    NSMutableDictionary *options=[RE2NormalizeOverlayOptions(input) mutableCopy];
    // Always start unobtrusively, regardless of the previous session's state.
    // Opening the panel grants UI input automatically; hidden UI requests none.
    options[@"visible"]=@NO;options[@"badge"]=@NO;options[@"mouse"]=@YES;
    return options;
}
NSDictionary *RE2DecodeOverlayOptions(NSString *json) {
    if (![json isKindOfClass:NSString.class] || json.length>4096) return RE2NormalizeOverlayOptions(nil);
    NSData *data=[json dataUsingEncoding:NSUTF8StringEncoding];
    return RE2NormalizeOverlayOptions(data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil);
}
NSString *RE2OverlayMessage(NSDictionary *options, NSString *session, int pid) {
    if (!session.length || session.length>128 || pid<=0) return nil;
    NSDictionary *envelope=@{@"session":session,@"pid":@(pid),@"options":RE2NormalizeOverlayOptions(options)};
    NSData *data=[NSJSONSerialization dataWithJSONObject:envelope options:0 error:NULL];
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
}
NSDictionary *RE2OverlayMessageOptions(id message, NSString *session, int pid) {
    if (![message isKindOfClass:NSString.class] || [message length]>4096 || !session.length || pid<=0) return nil;
    NSData *data=[message dataUsingEncoding:NSUTF8StringEncoding];
    id decoded=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    if (![decoded isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *envelope=decoded;
    if (![session isEqual:envelope[@"session"]] || ![envelope[@"pid"] isKindOfClass:NSNumber.class]
        || [envelope[@"pid"] doubleValue]!=pid || ![envelope[@"options"] isKindOfClass:NSDictionary.class]) return nil;
    return RE2NormalizeOverlayOptions(envelope[@"options"]);
}
