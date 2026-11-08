// SPDX-License-Identifier: GPL-3.0-only
// Test-only host for the real runtime protocol and native store observations.
#import <AppKit/AppKit.h>
#import "MHTProtocol.h"
#include <libproc.h>
#include <limits.h>
#include <string.h>
// Observe only executable identity, never a process's arguments or environment.
static int matchingProcess(const char *target,pid_t *found,struct proc_bsdinfo *identity){
 int count=proc_listallpids(NULL,0);if(count<=0 || count>65536)return -1;
 NSUInteger capacity=(NSUInteger)count+64;NSMutableData *storage=[NSMutableData dataWithLength:capacity*sizeof(pid_t)];
 int actual=proc_listallpids(storage.mutableBytes,(int)storage.length);if(actual<0 || (NSUInteger)actual>=capacity)return -1;
 pid_t *pids=storage.mutableBytes;int matches=0;
 for(int i=0;i<actual;i++){
  char raw[PROC_PIDPATHINFO_MAXSIZE],canonical[PATH_MAX];
  if(pids[i]<=0 || proc_pidpath(pids[i],raw,sizeof(raw))<=0 || !realpath(raw,canonical) || strcmp(target,canonical))continue;
  if(++matches>1)return -2;
  struct proc_bsdinfo info={0};if(proc_pidinfo(pids[i],PROC_PIDTBSDINFO,0,&info,sizeof(info))!=(int)sizeof(info))return -1;
  *found=pids[i];*identity=info;
 }
 return matches;
}
int main(int argc,const char *argv[]){@autoreleasepool{
 if(argc!=2 && argc!=3)return 2;BOOL observe=argc==3;if(observe && strcmp(argv[2],"--observe"))return 2;
 NSString *root=@(argv[1]);NSData *configData=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"Launch.json"]];
 NSDictionary *config=configData ? [NSJSONSerialization JSONObjectWithData:configData options:0 error:NULL] : nil;
 if(![config isKindOfClass:NSDictionary.class] || ![config[@"environment"] isKindOfClass:NSDictionary.class])return 2;
 NSString *session=config[@"environment"][@"MHT_SESSION"];if(![session isKindOfClass:NSString.class] || !session.length)return 2;
 char target[PATH_MAX]={0};if(observe){NSString *path=config[@"environment"][@"MHT_TARGET"];
  if(![path isKindOfClass:NSString.class] || !path.isAbsolutePath || !realpath(path.fileSystemRepresentation,target) || ![NSFileManager.defaultManager isExecutableFileAtPath:path])return 2;
 }else for(NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications)if([@[@"com.poncle.VampireSurvivors",@"com.poncle.VampireSurvivors"]containsObject:app.bundleIdentifier]){fprintf(stderr,"Vampire Survivors already running; no launch performed.\n");return 2;}
 __block pid_t pid=0;__block NSDictionary *runtime,*native;__block NSUInteger serial=0;
 __block struct proc_bsdinfo observedIdentity={0};NSString *targetPath=observe ? @(target) : nil;
 double observeDeadline=NSProcessInfo.processInfo.systemUptime+120;
 void (^write)(NSString *,NSDictionary *)=^(NSString *name,NSDictionary *data){[[NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:[root stringByAppendingPathComponent:name] options:NSDataWritingAtomic error:NULL];};
 for(NSString *name in @[MHTStateNotification,@"local.mht.vampire-survivors.native-test.v1"])[NSDistributedNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){NSDictionary *d=MHTDecodeMessage(event.object);if(!MHTMatchesSession(d,@"vampire-survivors",session,pid))return;if([event.name isEqual:MHTStateNotification]){runtime=d;write(@"RuntimeState.json",d);}else{native=d;write(@"NativeState.json",d);}}];
 if(!observe){NSWorkspaceOpenConfiguration *settings=NSWorkspaceOpenConfiguration.configuration;settings.createsNewApplicationInstance=NO;settings.activates=YES;settings.environment=config[@"environment"];
 [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:config[@"app"]] configuration:settings completionHandler:^(NSRunningApplication *app,NSError *error){if(error){fprintf(stderr,"Launch failed: %s\n",error.localizedDescription.UTF8String);exit(1);}pid=app.processIdentifier;printf("Single store test pid=%d\n",pid);fflush(stdout);write(@"Process.json",@{@"pid":@(pid)});}];
 }
 [NSTimer scheduledTimerWithTimeInterval:.2 repeats:YES block:^(NSTimer *timer){(void)timer;
  if(observe){pid_t found=0;struct proc_bsdinfo identity={0};int result=matchingProcess(targetPath.fileSystemRepresentation,&found,&identity);
   if(result<0){fprintf(stderr,"Executable identity unavailable or ambiguous; no launch performed.\n");exit(2);}
   if(!pid){
    if(NSProcessInfo.processInfo.systemUptime>=observeDeadline){fprintf(stderr,"Timed out waiting for executable; no launch performed.\n");exit(3);}
    if(!result)return;pid=found;observedIdentity=identity;printf("Observed store test pid=%d\n",pid);fflush(stdout);write(@"Process.json",@{@"pid":@(pid)});
   }else if(!result)exit(0);
   else if(found!=pid || identity.pbi_start_tvsec!=observedIdentity.pbi_start_tvsec || identity.pbi_start_tvusec!=observedIdentity.pbi_start_tvusec){fprintf(stderr,"Observed executable identity changed; no launch performed.\n");exit(2);}
  }else {if(!pid)return;NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:pid];if(!app||app.terminated)exit(0);}
  NSData *data=[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"Requests.json"]];NSDictionary *q=data&&data.length<=16384?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;NSUInteger next=[q[@"serial"]unsignedIntegerValue];if(next<=serial)return;serial=next;
  NSArray *commands=q[@"commands"];if(![commands isKindOfClass:NSArray.class]||commands.count>24)return;
  for(NSDictionary *command in commands){NSMutableDictionary *message=[command mutableCopy];BOOL probe=[message[@"channel"]isEqual:@"probe"];[message removeObjectForKey:@"channel"];
   [message addEntriesFromDictionary:@{@"version":@1,@"module":@"vampire-survivors",@"session":session,@"pid":@(pid),@"request":NSUUID.UUID.UUIDString,@"deadline":@(NSDate.date.timeIntervalSince1970+4),@"context":runtime[@"state"][@"context"]?:@0,@"owner":native[@"state"][@"owner"]?:@0}];
   MHTPost(probe?@"local.mht.vampire-survivors.native-test.command.v1":MHTCommandNotification,message);
  }write(@"RequestAck.json",@{@"serial":@(serial)});
 }];
 [NSRunLoop.mainRunLoop run];
}return 0;}
