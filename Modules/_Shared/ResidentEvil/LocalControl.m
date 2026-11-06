// SPDX-License-Identifier: GPL-3.0-only
#import "LocalControl.h"
#import <unistd.h>
#include <math.h>
static NSString *const requestName=@"local.mactrainer.control-request.v1";
static NSString *const replyName=@"local.mactrainer.control-reply.v1";
static NSDictionary *decode(id text){
    if(![text isKindOfClass:NSString.class] || [text length]>65536)return nil;
    NSData *data=[text dataUsingEncoding:NSUTF8StringEncoding];id value=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}
static BOOL post(NSString *name,NSDictionary *value){
    NSData *data=[NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:NULL];if(!data || data.length>65536)return NO;
    @try{[NSDistributedNotificationCenter.defaultCenter postNotificationName:name object:[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding] userInfo:nil deliverImmediately:YES];return YES;}
    @catch(NSException *exception){(void)exception;return NO;}
}
@implementation MTLocalControl {
    NSDictionary *_metadata;
    MTControlHandler _handler;
    id _observer;
    NSMutableOrderedSet<NSString *> *_seen;
}
- (instancetype)initWithMetadata:(NSDictionary *)metadata handler:(MTControlHandler)handler {
    if(!(self=[super init]))return nil;
    if(![metadata[@"session"] isKindOfClass:NSString.class] || ![metadata[@"session"] length] || ![metadata[@"profile"] isKindOfClass:NSString.class] || !handler)return nil;
    _metadata=[metadata copy];_handler=[handler copy];_seen=[NSMutableOrderedSet new];
    __weak MTLocalControl *weakSelf=self;
    _observer=[NSDistributedNotificationCenter.defaultCenter addObserverForName:requestName object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){[weakSelf receive:decode(n.object)];}];
    return self;
}
- (void)receive:(NSDictionary *)r {
    NSString *nonce=r[@"request"],*action=r[@"action"];
    if(![r[@"version"] isEqual:@1] || ![nonce isKindOfClass:NSString.class] || ![[NSUUID alloc]initWithUUIDString:nonce] || ![action isKindOfClass:NSString.class])return;
    NSMutableDictionary *envelope=[_metadata mutableCopy];envelope[@"request"]=nonce;envelope[@"version"]=@1;
    if([action isEqual:@"discover"]){envelope[@"ok"]=@YES;post(replyName,envelope);return;}
    if(![r[@"session"] isEqual:_metadata[@"session"]] || ![r[@"profile"] isEqual:_metadata[@"profile"]] || ![r[@"pid"] isEqual:_metadata[@"pid"]])return;
    double now=NSDate.date.timeIntervalSince1970;id rawDeadline=r[@"deadline"];double deadline=[rawDeadline isKindOfClass:NSNumber.class] ? [rawDeadline doubleValue] : NAN;
    if(!isfinite(deadline) || deadline<=now || deadline>now+10){envelope[@"ok"]=@NO;envelope[@"error"]=@"Expired or invalid request deadline.";post(replyName,envelope);return;}
    if([_seen containsObject:nonce]){envelope[@"ok"]=@NO;envelope[@"error"]=@"Duplicate request rejected; no action repeated.";post(replyName,envelope);return;}
    [_seen addObject:nonce];if(_seen.count>128)[_seen removeObjectAtIndex:0];
    _handler(r,^(NSDictionary *response){NSMutableDictionary *out=[envelope mutableCopy];[out addEntriesFromDictionary:response ?: @{@"ok":@NO,@"error":@"No response."}];post(replyName,out);});
}
- (void)stop {if(_observer){[NSDistributedNotificationCenter.defaultCenter removeObserver:_observer];_observer=nil;}}
- (void)dealloc {[self stop];}
@end
NSDictionary *MTControlSnapshot(RE2TrainerState *state){
    if(!state)return @{};
    NSMutableArray *features=[NSMutableArray new];
    for(NSInteger i=0;i<(NSInteger)state.features.count;i++){
        const RE2FeatureInfo *f=RE2FeatureInfoAt(i);RE2FeatureState *s=state.features[i];
        [features addObject:@{@"id":@(i),@"title":f->title,@"shortcut":f->shortcut,@"implemented":@(f->implemented),@"oneShot":@(f->oneShot),@"numeric":@(f->numeric),@"wanted":@(s.wanted),@"active":@(s.active),@"available":@(s.available),@"value":@(s.value),@"note":s.note ?: @""}];
    }
    return @{@"ready":@(state.ready),@"context":@(state.context),@"status":state.status ?: @"",@"message":state.message ?: @"",@"updatedAt":@(state.updatedAt),@"mouseActive":@(state.overlayMouseActive),@"selectionPending":@(state.selectionPending),@"diagnostics":state.diagnostics ?: @{},@"features":features};
}
static BOOL matches(NSDictionary *m,NSString *target){
    if([target isEqual:m[@"profile"]] || [target isEqual:[m[@"pid"] stringValue]])return YES;
    NSString *prefix=[[target lowercaseString] stringByAppendingString:@"-mac-"];
    return [m[@"profile"] hasPrefix:prefix];
}
static void pumpUntil(BOOL (^done)(void),double seconds){
    NSDate *end=[NSDate dateWithTimeIntervalSinceNow:seconds];while(!done() && end.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}
NSDictionary *MTControlClient(NSString *target,NSDictionary *request){
    NSString *discovery=NSUUID.UUID.UUIDString;NSMutableDictionary *found=[NSMutableDictionary new];
    id observer=[NSDistributedNotificationCenter.defaultCenter addObserverForName:replyName object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){NSDictionary *r=decode(n.object);if([r[@"request"] isEqual:discovery] && [r[@"version"] isEqual:@1] && [r[@"session"] isKindOfClass:NSString.class] && [r[@"profile"] isKindOfClass:NSString.class] && [r[@"pid"] isKindOfClass:NSNumber.class])found[[NSString stringWithFormat:@"%@:%@",r[@"profile"],r[@"pid"]]]=r;}];
    BOOL sent=post(requestName,@{@"version":@1,@"request":discovery,@"action":@"discover"});
    if(sent)pumpUntil(^BOOL{return NO;},0.65);
    [NSDistributedNotificationCenter.defaultCenter removeObserver:observer];
    if([target isEqual:@"list"]){NSMutableArray *games=[NSMutableArray new];for(NSDictionary *m in found.allValues){NSMutableDictionary *v=[m mutableCopy];[v removeObjectsForKeys:@[@"session",@"request"]];[games addObject:v];}return @{@"ok":@YES,@"games":games};}
    NSArray *candidates=[found.allValues filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *m,NSDictionary *bindings){(void)bindings;return matches(m,target);}]];
    if(candidates.count!=1)return @{@"ok":@NO,@"error":candidates.count ? @"Multiple game sessions match; target the game PID." : @"No live control interface found. Start the game with the current trainer build."};
    NSDictionary *m=candidates.firstObject;NSString *nonce=NSUUID.UUID.UUIDString;__block NSDictionary *answer=nil;
    observer=[NSDistributedNotificationCenter.defaultCenter addObserverForName:replyName object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){NSDictionary *r=decode(n.object);if([r[@"request"] isEqual:nonce] && [r[@"session"] isEqual:m[@"session"]] && [r[@"pid"] isEqual:m[@"pid"]] && [r[@"profile"] isEqual:m[@"profile"]])answer=r;}];
    NSMutableDictionary *message=[request mutableCopy] ?: [NSMutableDictionary new];
    [message addEntriesFromDictionary:@{@"version":@1,@"request":nonce,@"session":m[@"session"],@"profile":m[@"profile"],@"pid":m[@"pid"],@"deadline":@(NSDate.date.timeIntervalSince1970+4)}];
    sent=post(requestName,message);if(sent)pumpUntil(^BOOL{return answer!=nil;},7);
    [NSDistributedNotificationCenter.defaultCenter removeObserver:observer];
    if(!answer)return @{@"ok":@NO,@"error":@"No reply before timeout. Execution outcome is unknown; do not repeat one-shot actions automatically."};
    NSMutableDictionary *out=[answer mutableCopy];[out removeObjectsForKeys:@[@"session",@"request"]];return out;
}
int MTControlCLI(int argc,const char *argv[]){
    if(argc!=3 && argc!=4){fprintf(stderr,"Usage: MacTrainer --control list | MacTrainer --control re2 '{\"action\":\"state\"}'\n");return 2;}
    NSString *target=[NSString stringWithUTF8String:argv[2]];NSDictionary *request=argc==4 ? decode([NSString stringWithUTF8String:argv[3]]) : nil;
    if(![target isEqual:@"list"] && !request){fprintf(stderr,"Expected a JSON control request.\n");return 2;}
    NSDictionary *answer=MTControlClient(target,request);NSData *json=[NSJSONSerialization dataWithJSONObject:answer options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:NULL];
    if(json){fwrite(json.bytes,1,json.length,stdout);fputc('\n',stdout);}return [answer[@"ok"] boolValue] ? 0 : 1;
}
