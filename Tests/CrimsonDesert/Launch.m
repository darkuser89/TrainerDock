// SPDX-License-Identifier: GPL-3.0-only
// Explicit local test: exact original check, one instance, genuine runtime IPC.
#import <AppKit/AppKit.h>
#import "GameIdentity.h"
#import "MHTProtocol.h"
int main(int argc,const char *argv[]){@autoreleasepool{
 if(argc!=2)return 2;
 NSString *root=@(argv[1]);
 NSString *bundle=@"/Volumes/Mac Games/SteamLibrary/steamapps/common/Crimson Desert/CrimsonDesert_Steam.app";
 NSString *module=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/TrainerDock/Modules/crimson-desert.mhtmodule"];
 NSString *configuration=[module stringByAppendingPathComponent:@"TrainerConfig.json"];
 NSError *failure=nil;NSDictionary *config=MTLoadConfiguration(configuration,&failure);
 NSDictionary *profile=MTFindProfile(config,@"crimson-steam-arm64-26636972");
 NSDictionary *game=MTInspectGame(bundle,profile,&failure);
 if(!game){fprintf(stderr,"%s\n",failure.localizedDescription.UTF8String);return 1;}
 if(MTExecutableIsRunning(game[@"executable"]) || [NSRunningApplication runningApplicationsWithBundleIdentifier:profile[@"bundleIdentifier"]].count){fputs("Spiel läuft bereits; kein zweiter Start.\n",stderr);return 2;}
 NSString *session=NSUUID.UUID.UUIDString;__block pid_t pid=0;__block NSDictionary *runtime;__block NSUInteger serial=0;
 void (^write)(NSString *,NSDictionary *)=^(NSString *name,NSDictionary *value){[[NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:[root stringByAppendingPathComponent:name] options:NSDataWritingAtomic error:NULL];};
 [NSDistributedNotificationCenter.defaultCenter addObserverForName:MHTStateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){NSDictionary *message=MHTDecodeMessage(note.object);if(MHTMatchesSession(message,@"crimson-desert",session,pid)){runtime=message;write(@"RuntimeState.json",message);}}];
 NSWorkspaceOpenConfiguration *open=NSWorkspaceOpenConfiguration.configuration;open.activates=YES;open.createsNewApplicationInstance=NO;
 open.environment=@{@"DYLD_INSERT_LIBRARIES":[NSString stringWithFormat:@"%@:%@",[module stringByAppendingPathComponent:@"Trainer.dylib"],[root stringByAppendingPathComponent:@"Probe.dylib"]],@"MHT_MODULE":@"crimson-desert",@"MHT_SESSION":session,@"MHT_CONFIG":configuration,@"MHT_PROFILE":profile[@"id"],@"MHT_TARGET":game[@"executable"],@"MHT_SELECTION":@"{}",@"MHT_OPTIONS":@"{\"visible\":false,\"glassIntensity\":0.5}",@"MT_CRIMSON_PROBE_OUTPUT":[root stringByAppendingPathComponent:@"NativeState.json"],@"SteamAppId":@"3321460",@"SteamGameId":@"3321460"};
 [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:bundle] configuration:open completionHandler:^(NSRunningApplication *app,NSError *error){if(!app){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);exit(1);}pid=app.processIdentifier;write(@"Session.json",@{@"pid":@(pid),@"session":session});printf("Genau eine Crimson-Desert-Prüfinstanz, PID %d.\n",pid);fflush(stdout);}];
 [NSTimer scheduledTimerWithTimeInterval:.2 repeats:YES block:^(NSTimer *timer){(void)timer;if(!pid)return;
  NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:pid];if(!app || app.terminated)exit(0);
  NSData *data=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"Requests.json"]];
  NSDictionary *request=data && data.length<16384 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
  if([request[@"serial"]unsignedIntegerValue]<=serial)return;serial=[request[@"serial"]unsignedIntegerValue];
  NSArray *commands=request[@"commands"];if(![commands isKindOfClass:NSArray.class] || commands.count>24)return;
  for(NSDictionary *command in commands){if(![command isKindOfClass:NSDictionary.class])continue;NSMutableDictionary *message=[command mutableCopy];[message addEntriesFromDictionary:@{@"version":@1,@"module":@"crimson-desert",@"session":session,@"pid":@(pid),@"request":NSUUID.UUID.UUIDString,@"deadline":@(NSDate.date.timeIntervalSince1970+4),@"context":runtime[@"state"][@"context"]?:@0}];MHTPost(MHTCommandNotification,message);}
  write(@"RequestAck.json",@{@"serial":@(serial)});
 }];
 [NSRunLoop.mainRunLoop run];return 0;
}}
