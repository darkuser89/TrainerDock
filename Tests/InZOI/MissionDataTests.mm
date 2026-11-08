// SPDX-License-Identifier: GPL-3.0-only
// No game process: tests the parser with a synthetic malformed table and,
// optionally, original rows read through the authorized live diagnostic API.
#import <Foundation/Foundation.h>
#import "MissionData.h"
#import "LuaEngine.hpp"
#include <exception>
static NSString *payload;
id IZPresentationCommand(NSString *command){NSCAssert([command isEqual:@"data.table_get_all alias=Mission"],@"Only the original read-only table query is allowed");return @{@"ok":@YES,@"data":payload};}
int main(int argc,const char **argv){@autoreleasepool{
 payload=@"[{\"_row_name\":\"Duplicate\",\"conditions\":[]},{\"_row_name\":\"Duplicate\",\"conditions\":[]}]";
 bool rejected=false;try{IZLoadMissionData();}catch(const std::exception &){rejected=true;}
 NSCAssert(rejected&&!IZMissionDataReady(),@"A malformed table must never become available");
 payload=argc==2?[NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:nil]:@"[{\"_row_name\":\"Ambition_Seeker_1_1\",\"conditions\":[{\"conditionType\":\"BuyObject\",\"goalCount\":1}]}]";
 NSCAssert(payload,@"Explicit test input must exist");
 IZLoadMissionData();NSCAssert(IZMissionDataReady(),@"Only validated original rows become available");
 NSDictionary *row=[NSJSONSerialization JSONObjectWithData:[IZMissionDefinition(@"Ambition_Seeker_1_1") dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
 NSCAssert([row[@"_row_name"] isEqual:@"Ambition_Seeker_1_1"]&&[row[@"conditions"] count]>0,@"Exact row identity and native conditions must survive the thread boundary");
 rejected=false;try{IZMissionDefinition(@"Missing");}catch(const std::exception &){rejected=true;}
 NSCAssert(rejected,@"Missing original rows never receive replacement definitions");
 puts("PASS: mission cache schema, duplicate rejection, exact row identity and missing-row rejection. No game started.");
}}
