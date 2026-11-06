// SPDX-License-Identifier: GPL-3.0-only
#import "ProbeRequest.h"
int main(void){@autoreleasepool{
 NSCAssert(!MTControlReadProbeRequest(nil),@"Missing request must be harmless");
 for(NSString *s in @[@"",@"{",@"[]",@"null",@"{\"serial\":1,\"wanted\":[]}",@"{\"serial\":\"1\",\"wanted\":{}}",@"{\"serial\":1,\"wanted\":{\"ammo\":null}}",@"{\"serial\":1,\"wanted\":{},\"money\":[]}"])
  NSCAssert(!MTControlReadProbeRequest([s dataUsingEncoding:NSUTF8StringEncoding]),@"Invalid request must be harmless: %@",s);
 NSData *good=[@"{\"serial\":1,\"wanted\":{\"ammo\":true}}" dataUsingEncoding:NSUTF8StringEncoding];
 NSCAssert([MTControlReadProbeRequest(good)[@"wanted"][@"ammo"]boolValue],@"Valid request");
 NSCAssert(!MTControlReadProbeRequest([NSMutableData dataWithLength:8193]),@"Bound request size");
 for(NSString *s in @[@"{\"serial\":1,\"wanted\":{},\"values\":[]}",@"{\"serial\":1,\"wanted\":{},\"values\":{\"0\":null}}",@"{\"serial\":1,\"wanted\":{},\"actions\":{}}",@"{\"serial\":1,\"wanted\":{},\"actions\":[null]}",@"{\"serial\":1,\"wanted\":{},\"actions\":[12]}",@"{\"serial\":1,\"wanted\":{},\"visible\":[]}"])
  NSCAssert(!MTControlReadProbeRequest([s dataUsingEncoding:NSUTF8StringEncoding]),@"Malformed optional fields are harmless: %@",s);
 puts("Control probe missing/malformed/type/size request checks passed");
}return 0;}
