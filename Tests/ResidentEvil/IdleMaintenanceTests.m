// SPDX-License-Identifier: GPL-3.0-only
// Executes the product adapters with counted, test-only engine access. No game.
#import <AppKit/AppKit.h>
#import "RE2Adapter.h"
#import "RE3Adapter.h"
#import "RE4Adapter.h"
#import "RE7Adapter.h"
#import "RE8Adapter.h"
#import "RE2Engine.h"
static NSUInteger nativeQueries,localQueries,effectCalls;
@interface CountedREEngine : MTRE2Engine @end
@implementation CountedREEngine
- (BOOL)isGameThread{nativeQueries++;return YES;}
- (void *)singletonAt:(uintptr_t)slot{(void)slot;nativeQueries++;return NULL;}
@end
@interface RE4NativeAdapter (PerformanceTest)
- (void)frame4;
@end
@interface RE7NativeAdapter (PerformanceTest)
- (void)frame7;
@end
@interface RE8NativeAdapter (PerformanceTest)
- (void)frame8;
- (void)inspectMerc8;
@end
@interface CountedRE4Adapter : RE4NativeAdapter @end
@implementation CountedRE4Adapter
- (BOOL)local4{localQueries++;return YES;}
@end
@interface CountedRE7Adapter : RE7NativeAdapter @end
@implementation CountedRE7Adapter
- (BOOL)local7{localQueries++;return YES;}
- (RE2FeatureState *)applyFeature:(RE2Feature)f wanted:(BOOL)wanted value:(double)value{(void)f;(void)wanted;(void)value;effectCalls++;return [RE2FeatureState new];}
@end
@interface CountedRE8Adapter : RE8NativeAdapter @end
@implementation CountedRE8Adapter
- (BOOL)local8{localQueries++;return YES;}
- (RE2FeatureState *)applyFeature:(RE2Feature)f wanted:(BOOL)wanted value:(double)value{(void)f;(void)wanted;(void)value;effectCalls++;return [RE2FeatureState new];}
@end
static void check(BOOL okay,const char *why){if(!okay){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
int main(void){@autoreleasepool{
 CountedREEngine *engine=[CountedREEngine new];
 NSArray *adapters=@[[RE2NativeAdapter new],[RE3NativeAdapter new],[CountedRE4Adapter new],[CountedRE7Adapter new],[CountedRE8Adapter new]];
 NSArray *engineKeys=@[@"engine",@"e",@"e4",@"e7",@"e8"];
 for(NSUInteger i=0;i<adapters.count;i++)[adapters[i] setValue:engine forKey:engineKeys[i]];
 nativeQueries=0;
 for(unsigned i=0;i<20000;i++)for(id adapter in adapters)check(![adapter setOverlayInteraction:NO],"closed unowned mouse lease remains inactive");
 check(nativeQueries==0,"100,000 closed-overlay polls do not resolve native HID or thread state");
 CountedRE4Adapter *re4=adapters[2];CountedRE7Adapter *re7=adapters[3];CountedRE8Adapter *re8=adapters[4];
 for(unsigned i=0;i<20000;i++){[re4 frame4];[re7 frame7];[re8 frame8];}
 check(localQueries==0&&nativeQueries==0&&!effectCalls,"60,000 idle RE4/7/8 frames do not traverse gameplay graphs or discover portals");
 NSMutableDictionary *wanted7=[re7 valueForKey:@"wanted7"],*wanted8=[re8 valueForKey:@"wanted8"];
 wanted7[@0]=@0;wanted8[@0]=@0;
 for(unsigned i=0;i<200;i++){[re7 frame7];[re8 frame8];}
 check(localQueries==400&&effectCalls==400,"requested effects retain original per-frame context and effect dispatch");
 [wanted7 removeAllObjects];[wanted8 removeAllObjects];
 localQueries=effectCalls=0;
 [re8 setValue:@(CFAbsoluteTimeGetCurrent()+5) forKey:@"timeVerifyAt8"];
 [re8 frame8];check(localQueries==1&&!effectCalls,"a pending verification is not discarded by the idle gate");
 [re8 setValue:@0 forKey:@"timeVerifyAt8"];
 [re8 setValue:@(CFAbsoluteTimeGetCurrent()+5) forKey:@"mercGoalDiscoveryUntil8"];
 [re8 frame8];check(localQueries==2&&!effectCalls,"explicit goal discovery can progress without repeating its one-shot");
 [re8 setValue:@0 forKey:@"mercGoalDiscoveryUntil8"];
 NSMutableArray *pending=[NSMutableArray arrayWithObject:@1];[re8 setValue:pending forKey:@"mercPending8"];
 [re8 inspectMerc8];check([re8 valueForKey:@"mercPending8"]==pending,"expired discovery pauses its bounded cursor instead of restarting large scenes");
 localQueries=0;[re8 frame8];check(!localQueries,"discovery expiry returns to the native idle path");
 puts("PASS: real RE adapters: 100,000 closed-input polls and 60,000 idle frames do no native discovery; active and pending work remain dispatched. Synthetic only.");
}return 0;}
