// SPDX-License-Identifier: GPL-3.0-only
// Explicitly invoked local title-menu test. No save is loaded or edited here.
#import <AppKit/AppKit.h>
#import "../../Core/GameIdentity.h"
int main(void){@autoreleasepool{
    NSString *bundle=@"/Volumes/Mac Games/SteamLibrary/steamapps/common/Lies of P/LiesofP.app";
    NSString *module=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/TrainerDock/Modules/lies-of-p.mhtmodule"];
    NSString *configuration=[module stringByAppendingPathComponent:@"TrainerConfig.json"];
    NSError *error=nil;NSDictionary *config=MTLoadConfiguration(configuration,&error);
    NSDictionary *profile=MTFindProfile(config,@"steam-114-arm64");
    NSDictionary *game=MTInspectGame(bundle,profile,&error);
    if(!game){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;}
    if(MTExecutableIsRunning(game[@"executable"])){fputs("Already running; no second instance started.\n",stderr);return 2;}
    NSString *session=NSUUID.UUID.UUIDString;
    NSWorkspaceOpenConfiguration *open=[NSWorkspaceOpenConfiguration configuration];
    open.createsNewApplicationInstance=NO;
    open.environment=@{@"DYLD_INSERT_LIBRARIES":[module stringByAppendingPathComponent:@"Trainer.dylib"],
        @"MHT_MODULE":@"lies-of-p",@"MHT_SESSION":session,@"MHT_CONFIG":configuration,
        @"MHT_PROFILE":profile[@"id"],@"MHT_TARGET":game[@"executable"],@"MHT_SELECTION":@"{}",
        @"MHT_OPTIONS":@"{\"visible\":false,\"glassIntensity\":0.5}",@"SteamAppId":@"1627720",@"SteamGameId":@"1627720"};
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:bundle] configuration:open completionHandler:^(NSRunningApplication *app,NSError *failure){
        if(!app){fprintf(stderr,"%s\n",failure.localizedDescription.UTF8String);exit(1);}
        NSDictionary *identity=@{@"pid":@(app.processIdentifier),@"session":session};
        NSData *data=[NSJSONSerialization dataWithJSONObject:identity options:0 error:NULL];
        [data writeToFile:@"/private/tmp/trainerdock-lop-fullscreen/Session.json" atomically:YES];
        printf("One Lies-of-P test instance, pid=%d\n",app.processIdentifier);exit(0);
    }];
    [NSRunLoop.mainRunLoop run];return 0;
}}
