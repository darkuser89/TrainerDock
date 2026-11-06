// SPDX-License-Identifier: GPL-3.0-only
// Talks to the real module protocol. Test helper, never shipped.
#import <Foundation/Foundation.h>
#import "MHTProtocol.h"
int main(int argc,const char **argv){@autoreleasepool{
 NSString *base=@"/private/tmp/mht-balatro";
 NSString *session=[[NSString stringWithContentsOfFile:[base stringByAppendingPathComponent:@"session"] encoding:NSUTF8StringEncoding error:NULL] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 int pid=[[NSString stringWithContentsOfFile:[base stringByAppendingPathComponent:@"pid"] encoding:NSUTF8StringEncoding error:NULL] intValue];
 __block NSDictionary *latest=nil;
 id token=[NSDistributedNotificationCenter.defaultCenter addObserverForName:MHTStateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){NSDictionary *d=MHTDecodeMessage(n.object);if([d[@"session"] isEqual:session] && [d[@"pid"] intValue]==pid)latest=d;}];
 NSDate *end=[NSDate dateWithTimeIntervalSinceNow:2];while(!latest && end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
 if(!latest){fprintf(stderr,"No module state received\n");return 1;}
 if(argc>1){NSString *action=[NSString stringWithUTF8String:argv[1]];NSMutableDictionary *command=[@{@"version":@1,@"module":@"balatro",@"session":session,@"pid":@(pid),@"request":NSUUID.UUID.UUIDString,@"deadline":@(NSDate.date.timeIntervalSince1970+2),@"context":latest[@"state"][@"context"],@"action":action} mutableCopy];
 if([action isEqual:@"overlay"] && argc>2)command[@"options"]=MHTDecodeMessage([NSString stringWithUTF8String:argv[2]]);
 else if(argc>2)command[@"feature"]=@(atoi(argv[2]));
 if(argc>3)command[[action isEqual:@"set"] ? @"wanted" : @"value"]=@(atof(argv[3]));
 MHTPost(MHTCommandNotification,command);
 end=[NSDate dateWithTimeIntervalSinceNow:1.1];while(end.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
 }
 NSDictionary *state=latest[@"state"];NSData *full=[NSJSONSerialization dataWithJSONObject:latest options:0 error:NULL];[full writeToFile:[base stringByAppendingPathComponent:@"state.json"] atomically:YES];
 NSMutableArray *features=[NSMutableArray new];for(NSDictionary *f in state[@"features"]){[features addObject:@{@"id":f[@"id"],@"available":f[@"available"],@"active":f[@"active"],@"wanted":f[@"wanted"],@"value":f[@"value"],@"note":f[@"note"]}];}
 NSData *out=[NSJSONSerialization dataWithJSONObject:@{@"ready":state[@"ready"] ?: @NO,@"context":state[@"context"] ?: @0,@"message":state[@"message"] ?: @"",@"error":latest[@"error"] ?: @"",@"features":features} options:NSJSONWritingSortedKeys error:NULL];printf("%.*s\n",(int)out.length,(const char *)out.bytes);
 [NSDistributedNotificationCenter.defaultCenter removeObserver:token];
}return 0;}
