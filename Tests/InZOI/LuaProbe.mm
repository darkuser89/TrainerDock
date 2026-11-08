// SPDX-License-Identifier: GPL-3.0-only
// Private diagnostics excluded from all product targets.
#import <Foundation/Foundation.h>
#import "LuaEngine.hpp"
#import "Movement.h"
#include <exception>
#include <stdexcept>
#include <unistd.h>
static NSMutableSet *consumed;
static bool busy;
static NSTimer *timer;
__attribute__((constructor))static void startProbe(){dispatch_async(dispatch_get_main_queue(),^{
 if(strcmp(getenv("IZ_PRIVATE_SESSION") ?: "","1"))return;
 consumed=[NSMutableSet new];NSString *token=getenv("MHT_SESSION")?@(getenv("MHT_SESSION")):nil;if(!token.length)return;
 timer=[NSTimer timerWithTimeInterval:.1 repeats:YES block:^(NSTimer *){
  NSData *bytes=[NSData dataWithContentsOfFile:@"/private/tmp/trainerdock-inzoi/Request.json"];
  NSDictionary *r=bytes?[NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil]:nil;
  if(![r isKindOfClass:NSDictionary.class]||![r[@"token"] isEqual:token]||![r[@"id"] isKindOfClass:NSString.class]||[consumed containsObject:r[@"id"]]||consumed.count>=4096)return;
  if([r[@"action"][@"op"] isEqual:@"engine"]){[consumed addObject:r[@"id"]];NSDictionary *reply=@{@"id":r[@"id"],@"result":IZTestEngineStatus()};[[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil] writeToFile:@"/private/tmp/trainerdock-inzoi/Reply.json" atomically:YES];return;}
  if(busy)return;
  [consumed addObject:r[@"id"]];busy=true;NSTimeInterval submitted=NSDate.date.timeIntervalSince1970;
  dispatch_block_t action=^{@autoreleasepool{
   NSMutableDictionary *reply=[@{@"id":r[@"id"]} mutableCopy];@try{try{
    if(NSDate.date.timeIntervalSince1970-submitted>20)throw std::runtime_error("Expired native diagnostic request");
    NSDictionary *a=r[@"action"];NSString *op=a[@"op"];
    if([op isEqual:@"status"])reply[@"result"]=@{@"simulationThread":@(IZIsSimulationThread()),@"pid":@(getpid())};
    else if([op isEqual:@"eval"])reply[@"result"]=IZTestEvaluate(a[@"script"] ?: @"return nil");
    else if([op isEqual:@"b1eval"])reply[@"result"]=IZTestEvaluate(a[@"script"] ?: @"return nil");
    else if([op isEqual:@"b1command"])reply[@"result"]=IZPresentationCommand(a[@"command"] ?: @"");
    else if([op isEqual:@"movement"]){NSDictionary *context=IZCall(@"context",@[]);if(![context[@"ready"] boolValue])throw std::runtime_error("Local context unavailable");reply[@"result"]=IZMovementApply(context[@"identity"],[a[@"wanted"] boolValue],[a[@"value"] doubleValue]);}
    else if([op isEqual:@"call"])reply[@"result"]=IZCall(a[@"method"],a[@"arguments"] ?: @[]);
    else throw std::runtime_error("Unknown native diagnostic action");
   }catch(const std::exception &e){reply[@"error"]=@(e.what());}}@catch(NSException *e){reply[@"error"]=e.reason;}
   [[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil] writeToFile:@"/private/tmp/trainerdock-inzoi/Reply.json" atomically:YES];
   dispatch_async(dispatch_get_main_queue(),^{busy=false;});
  }};
  if([r[@"action"][@"op"] hasPrefix:@"b1"])IZOnPresentationThread(action);else IZOnSimulationThread(action);
 }];[NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
});}
