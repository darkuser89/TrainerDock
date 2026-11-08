// SPDX-License-Identifier: GPL-3.0-only
// Synthetic presentation queue only; never linked into a product.
#import <Foundation/Foundation.h>
#import "Movement.h"
#import "LuaEngine.hpp"
#include <cmath>
static NSMutableArray<dispatch_block_t> *queue;
static NSMutableDictionary<NSString *,NSNumber *> *speeds;
static NSUInteger commands;
void IZOnPresentationThread(dispatch_block_t work){[queue addObject:[work copy]];}
id IZPresentationCommand(NSString *line){
 commands++;
 NSString *id=[line componentsSeparatedByString:@"entity_id="].lastObject;
 NSCAssert(speeds[id],@"Only an explicitly identified fixture actor may be queried");
 if([line containsString:@"action=set"]){
  NSString *value=[[line componentsSeparatedByString:@"speed="].lastObject componentsSeparatedByString:@" "].firstObject;
  speeds[id]=@([value doubleValue]);return @{@"ok":@YES};
 }
 NSCAssert([line containsString:@"action=get"],@"No other native command is allowed");
 NSData *bytes=[NSJSONSerialization dataWithJSONObject:@{@"max_walk_speed":speeds[id],@"default_walk_speed":@190,@"default_sprint_speed":@400} options:0 error:nil];
 return @{@"ok":@YES,@"data":[[NSString alloc]initWithData:bytes encoding:NSUTF8StringEncoding]};
}
static void drain(){while(queue.count){dispatch_block_t b=queue.firstObject;[queue removeObjectAtIndex:0];b();}}
int main(){@autoreleasepool{
 queue=[NSMutableArray new];speeds=[@{@"1":@190,@"2":@200} mutableCopy];
 IZMovementApply(@"1:10:Map",YES,2);
 IZMovementSetOwner(@"2:20:Map");drain();
 NSCAssert(commands==0,@"A stale queued owner must never reach the native API");
 IZMovementApply(@"2:20:Map",YES,2);drain();
 NSCAssert(std::abs(speeds[@"2"].doubleValue-400)<.01,@"The real setter path must precede confirmation");
 NSDictionary *state=IZMovementApply(@"2:20:Map",YES,2);
 NSCAssert([state[@"active"] boolValue],@"Active requires the returned native readback");
 IZMovementApply(@"2:20:Map",NO,2);drain();
 NSCAssert(std::abs(speeds[@"2"].doubleValue-200)<.01,@"Off restores only the captured original");
 IZMovementApply(@"2:20:Map",YES,2);drain();
 speeds[@"2"]=@450;IZMovementSetOwner(nil);drain();
 NSCAssert(speeds[@"2"].intValue==450,@"An intervening engine write must be preserved");
 NSUInteger before=commands;
 state=IZMovementApply(@"invalid:20:Map",YES,2);drain();
 NSCAssert(![state[@"active"] boolValue]&&commands==before,@"Malformed actor IDs never enter a native command");
 puts("PASS: presentation owner cancellation, genuine readback requirement, off restoration and intervening engine writes. No game started.");
}}
