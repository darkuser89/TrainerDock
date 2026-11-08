// SPDX-License-Identifier: GPL-3.0-only
#import "RuntimeMod.h"
#import "LuaEngine.hpp"
#import "LuaProgram.hpp"
#import "MissionData.h"
#include <exception>
#include <cstdlib>
namespace {
NSString *directory,*identifier;
NSDictionary<NSString *,NSData *> *ownedFiles;
NSTimer *mountTimer;
bool inFlight=false,mounted=false;
void cleanup(){@autoreleasepool{
 if(!directory.length||!ownedFiles)return;
 NSFileManager *fm=NSFileManager.defaultManager;
 // Remove only byte-identical files created by this process. Preserve edits.
 for(NSString *relative in ownedFiles){NSString *path=[directory stringByAppendingPathComponent:relative];if([[NSData dataWithContentsOfFile:path] isEqual:ownedFiles[relative]])[fm removeItemAtPath:path error:nil];}
 for(NSString *relative in @[@"lua/B2/Components",@"lua/B2",@"lua",@""]){NSString *p=relative.length?[directory stringByAppendingPathComponent:relative]:directory;if([fm contentsOfDirectoryAtPath:p error:nil].count==0)[fm removeItemAtPath:p error:nil];}
}}
}
void IZStartRuntimeMod(){dispatch_async(dispatch_get_main_queue(),^{
 if(mountTimer||mounted)return;
 NSString *session=getenv("MHT_SESSION")?@(getenv("MHT_SESSION")):nil;
 NSCharacterSet *invalid=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"] invertedSet];
 if(!session.length||session.length>128||[session rangeOfCharacterFromSet:invalid].location!=NSNotFound)return;
 identifier=[@"TrainerDockRuntime_" stringByAppendingString:session];
 directory=[NSHomeDirectory() stringByAppendingPathComponent:[@"Documents/inZOI/Mods/InGame" stringByAppendingPathComponent:identifier]];
 NSFileManager *fm=NSFileManager.defaultManager;
 if([fm fileExistsAtPath:directory])return; // Never overwrite another session.
 NSString *pulse=@"local M={}\nfunction M.on_begin(self,owner) if not __TrainerDockInZOI then __TrainerDockInZOI=require('B2.Trainer') end;__TrainerDockInZOI.context() end\nfunction M.on_tick(self,owner,dt) if __TrainerDockInZOI then __TrainerDockInZOI.tick() end end\nfunction M.on_end(self,owner) if __TrainerDockInZOI then __TrainerDockInZOI.release() end end\nreturn M\n";
 NSString *skill=@"local M={}\nfunction M.Override_AddSkillExp(comp,id,exp) if __TrainerDockInZOI then return __TrainerDockInZOI.skillGain(comp,id,exp) end;return comp:AddSkillExp(id,exp) end\nreturn M\n";
 NSDictionary *manifest=@{@"settings":@{@"auto_require":@NO},@"bindings":@{@"B2":@[@{@"type":@"Manager",@"key":@"Time",@"script":@"B2.TimePulse"}],@"B1":@[]}};
 ownedFiles=@{@"lua/lua_manifest.json":[NSJSONSerialization dataWithJSONObject:manifest options:0 error:nil],@"lua/B2/Trainer.lua":[@(IZTrainerProgram) dataUsingEncoding:NSUTF8StringEncoding],@"lua/B2/TimePulse.lua":[pulse dataUsingEncoding:NSUTF8StringEncoding],@"lua/B2/Components/B2SkillComponent.lua":[skill dataUsingEncoding:NSUTF8StringEncoding]};
 if(![fm createDirectoryAtPath:[directory stringByAppendingPathComponent:@"lua/B2/Components"] withIntermediateDirectories:YES attributes:nil error:nil])return;
 for(NSString *relative in ownedFiles)if(![ownedFiles[relative] writeToFile:[directory stringByAppendingPathComponent:relative] options:NSDataWritingAtomic error:nil]){cleanup();return;}
 atexit(cleanup);
 mountTimer=[NSTimer timerWithTimeInterval:.5 repeats:YES block:^(NSTimer *){
  if(inFlight)return;inFlight=true;bool alreadyMounted=mounted;
  IZOnPresentationThread(^{bool success=alreadyMounted;@try{try{
   if(!alreadyMounted){NSDictionary *response=IZPresentationCommand([@"luamod.mount mod_id=" stringByAppendingString:identifier]);success=[response[@"ok"] boolValue];}
   if(success)IZLoadMissionData();
  }catch(const std::exception &){}}@catch(NSException *){}
  dispatch_async(dispatch_get_main_queue(),^{inFlight=false;if(success)mounted=true;if(mounted&&IZMissionDataReady()){[mountTimer invalidate];mountTimer=nil;}});
  });
 }];[NSRunLoop.mainRunLoop addTimer:mountTimer forMode:NSRunLoopCommonModes];
});}
