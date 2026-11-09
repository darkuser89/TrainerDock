// SPDX-License-Identifier: GPL-3.0-only
// Explicit Epic test through the production broker. No fallback or second start.
#import <AppKit/AppKit.h>
#import "GameIdentity.h"
#import "MHTEpicLaunch.h"
int main(void){@autoreleasepool{
 [NSApplication sharedApplication];
 NSString *root=@"/private/tmp/trainerdock-dredge";
 NSString *configuration=[root stringByAppendingPathComponent:@"ProbeConfig.json"];
 NSError *error=nil;NSDictionary *config=MTLoadConfiguration(configuration,&error);
 NSDictionary *input=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"LaunchInput.json"]] options:0 error:NULL];
 NSDictionary *profile=MTFindProfile(config,input[@"profile"]);
 NSDictionary *game=MTInspectGame(input[@"gameApp"],profile,&error);
 if(!game){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;}
 if(MTExecutableIsRunning(game[@"executable"])){fputs("DREDGE läuft bereits; kein zweiter Start.\n",stderr);return 2;}
 NSString *token=NSUUID.UUID.UUIDString;
 NSDictionary *environment=@{@"DYLD_INSERT_LIBRARIES":[root stringByAppendingPathComponent:@"Trainer.dylib"],
  @"MHT_MODULE":@"dredge",@"MHT_SESSION":token,@"MHT_CONFIG":configuration,
  @"MHT_PROFILE":profile[@"id"],@"MHT_TARGET":game[@"executable"],@"MHT_SELECTION":@"{}",
  @"MHT_DREDGE_TEST":@"1",@"MHT_OPTIONS":@"{\"visible\":false,\"glassIntensity\":0.5}"};
 NSURL *broker=[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/TrainerDock/TrainerDock.app/Contents/MacOS/TrainerDockEpicBroker"]];
 MHTEpicLaunchService *service=[[MHTEpicLaunchService alloc]initWithBrokerURL:broker];
 void (^completion)(NSRunningApplication *,NSError *)=^(NSRunningApplication *app,NSError *failure){
  if(!app){fprintf(stderr,"%s\n",failure.localizedDescription.UTF8String);exit(4);}
  NSDictionary *session=@{@"pid":@(app.processIdentifier),@"token":token};
  NSData *data=[NSJSONSerialization dataWithJSONObject:session options:0 error:NULL];
  [data writeToFile:[root stringByAppendingPathComponent:@"Session.json"] atomically:YES];
  [NSFileManager.defaultManager setAttributes:@{NSFilePosixPermissions:@0600} ofItemAtPath:[root stringByAppendingPathComponent:@"Session.json"] error:NULL];
  printf("Genau eine DREDGE-Prüfinstanz gestartet, PID %d.\n",app.processIdentifier);exit(0);
 };
 if([profile[@"launchMode"] isEqual:@"epic"]){
  if(![service recoverPendingTransactions:&error]){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 3;}
  [service launchGame:game profile:profile environment:environment completion:completion];
 }else{
  NSWorkspaceOpenConfiguration *open=[NSWorkspaceOpenConfiguration configuration];open.environment=environment;open.activates=YES;open.createsNewApplicationInstance=NO;
  [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:game[@"path"]] configuration:open completionHandler:completion];
 }
 [NSRunLoop.mainRunLoop run];return 0;
}}
