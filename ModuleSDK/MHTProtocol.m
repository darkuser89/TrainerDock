// SPDX-License-Identifier: GPL-3.0-only
#import "MHTProtocol.h"
#include <math.h>
NSString *const MHTCommandNotification=@"local.mht.command.v1";
NSString *const MHTStateNotification=@"local.mht.state.v1";
NSDictionary *MHTDecodeMessage(id text) {
    if(![text isKindOfClass:NSString.class] || [text length]>65536)return nil;
    NSData *data=[text dataUsingEncoding:NSUTF8StringEncoding];
    id value=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}
void MHTPost(NSString *name,NSDictionary *message) {
    NSData *data=[NSJSONSerialization dataWithJSONObject:message options:0 error:NULL];
    if(!data || data.length>65536)return;
    @try {[NSDistributedNotificationCenter.defaultCenter postNotificationName:name
        object:[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding] userInfo:nil deliverImmediately:YES];}
    @catch(NSException *exception){(void)exception;}
}
BOOL MHTMatchesSession(NSDictionary *m,NSString *module,NSString *session,int pid) {
    return session.length>0 && pid>0 && [m[@"version"] isEqual:@1] && [m[@"module"] isEqual:module]
        && [m[@"session"] isEqual:session] && [m[@"pid"] isKindOfClass:NSNumber.class]
        && [m[@"pid"] doubleValue]==pid;
}
BOOL MHTAcceptCommand(NSDictionary *m,NSString *module,NSString *session,int pid,NSMutableOrderedSet *seen,double now) {
    if(!MHTMatchesSession(m,module,session,pid) || ![m[@"request"] isKindOfClass:NSString.class]
       || ![[NSUUID alloc]initWithUUIDString:m[@"request"]] || ![m[@"deadline"] isKindOfClass:NSNumber.class])return NO;
    double deadline=[m[@"deadline"] doubleValue];
    if(!isfinite(deadline) || deadline<=now || deadline>now+5 || [seen containsObject:m[@"request"]])return NO;
    [seen addObject:m[@"request"]];
    if(seen.count>256)[seen removeObjectAtIndex:0];
    return YES;
}
