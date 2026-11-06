// SPDX-License-Identifier: GPL-3.0-only
// Test-only host for the real runtime protocol and native store observations.
#import <AppKit/AppKit.h>
#import "MHTProtocol.h"
int main(int argc,const char *argv[]){@autoreleasepool{
 if(argc!=2)return 2;NSString *root=@(argv[1]);NSDictionary *config=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"Launch.json"]] options:0 error:NULL];
 NSString *session=config[@"environment"][@"MHT_SESSION"];if(!session.length)return 2;
 for(NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications)if([@[@"com.remedygames.control-ue",@"com.remedygames.control-ue-steam"]containsObject:app.bundleIdentifier]){fprintf(stderr,"Control already running; no launch performed.\n");return 2;}
 __block pid_t pid=0;__block NSDictionary *runtime,*native;__block NSUInteger serial=0;
 void (^write)(NSString *,NSDictionary *)=^(NSString *name,NSDictionary *data){[[NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:[root stringByAppendingPathComponent:name] options:NSDataWritingAtomic error:NULL];};
 for(NSString *name in @[MHTStateNotification,@"local.mht.control.native-test.v1"])[NSDistributedNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){NSDictionary *d=MHTDecodeMessage(event.object);if(!MHTMatchesSession(d,@"control",session,pid))return;if([event.name isEqual:MHTStateNotification]){runtime=d;write(@"RuntimeState.json",d);}else{native=d;write(@"NativeState.json",d);}}];
 NSWorkspaceOpenConfiguration *settings=NSWorkspaceOpenConfiguration.configuration;settings.createsNewApplicationInstance=NO;settings.activates=YES;settings.environment=config[@"environment"];
 [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:config[@"app"]] configuration:settings completionHandler:^(NSRunningApplication *app,NSError *error){if(error){fprintf(stderr,"Launch failed: %s\n",error.localizedDescription.UTF8String);exit(1);}pid=app.processIdentifier;printf("Single store test pid=%d\n",pid);fflush(stdout);write(@"Process.json",@{@"pid":@(pid)});}];
 [NSTimer scheduledTimerWithTimeInterval:.2 repeats:YES block:^(NSTimer *timer){(void)timer;if(!pid)return;NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:pid];if(!app||app.terminated)exit(0);
  NSData *data=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"Requests.json"]];NSDictionary *q=data&&data.length<=16384?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;NSUInteger next=[q[@"serial"]unsignedIntegerValue];if(next<=serial)return;serial=next;
  NSArray *commands=q[@"commands"];if(![commands isKindOfClass:NSArray.class]||commands.count>24)return;
  for(NSDictionary *command in commands){NSMutableDictionary *message=[command mutableCopy];BOOL probe=[message[@"channel"]isEqual:@"probe"];[message removeObjectForKey:@"channel"];
   [message addEntriesFromDictionary:@{@"version":@1,@"module":@"control",@"session":session,@"pid":@(pid),@"request":NSUUID.UUID.UUIDString,@"deadline":@(NSDate.date.timeIntervalSince1970+4),@"context":runtime[@"state"][@"context"]?:@0,@"owner":native[@"state"][@"owner"]?:@0}];
   MHTPost(probe?@"local.mht.control.native-test.command.v1":MHTCommandNotification,message);
  }write(@"RequestAck.json",@{@"serial":@(serial)});
 }];
 [NSRunLoop.mainRunLoop run];
}return 0;}
