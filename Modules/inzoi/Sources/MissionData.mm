// SPDX-License-Identifier: GPL-3.0-only
#import "MissionData.h"
#import "LuaEngine.hpp"
#include <mutex>
#include <stdexcept>
namespace {std::mutex mutex;NSDictionary<NSString *,NSDictionary *> *rows;}
BOOL IZMissionDataReady(){std::lock_guard<std::mutex> lock(mutex);return rows.count>0;}
void IZLoadMissionData(){
 if(IZMissionDataReady())return;
 NSDictionary *response=IZPresentationCommand(@"data.table_get_all alias=Mission");
 NSString *text=response[@"data"];
 if(![response[@"ok"] boolValue]||![text isKindOfClass:NSString.class]||text.length>2097152)throw std::runtime_error("Original mission table unavailable");
 id array=[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
 if(![array isKindOfClass:NSArray.class]||![array count]||[array count]>8192)throw std::runtime_error("Original mission table schema differs");
 NSMutableDictionary *parsed=[NSMutableDictionary new];
 for(id entry in array){
  if(![entry isKindOfClass:NSDictionary.class])throw std::runtime_error("Invalid original mission row");
  NSString *key=entry[@"_row_name"];NSArray *conditions=entry[@"conditions"];
  if(![key isKindOfClass:NSString.class]||!key.length||key.length>128||parsed[key]||![conditions isKindOfClass:NSArray.class]||conditions.count>32)throw std::runtime_error("Invalid original mission definition");
  parsed[key]=entry;
 }
 std::lock_guard<std::mutex> lock(mutex);rows=[parsed copy];
}
NSString *IZMissionDefinition(NSString *row){
 if(![row isKindOfClass:NSString.class]||!row.length||row.length>128)throw std::runtime_error("Invalid mission key");
 NSDictionary *definition=nil;{std::lock_guard<std::mutex> lock(mutex);definition=rows[row];}
 if(!definition)throw std::runtime_error("Original mission row not loaded");
 NSData *bytes=[NSJSONSerialization dataWithJSONObject:definition options:0 error:nil];
 if(!bytes||bytes.length>65536)throw std::runtime_error("Original mission row exceeds bound");
 return [[NSString alloc]initWithData:bytes encoding:NSUTF8StringEncoding];
}
