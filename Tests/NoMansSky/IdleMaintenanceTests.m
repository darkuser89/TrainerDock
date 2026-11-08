// SPDX-License-Identifier: GPL-3.0-only
// Private renamed implementation lets this test link alongside product objects.
#define MTNMSAdapter NMSPerformanceAdapter
#define MTNMSValue NMSPerformanceValue
#define MTNMSReadOnly NMSPerformanceReadOnly
#define MTNMSProcessBuildMatches NMSPerformanceBuildMatches
#define MTNMSCaptureIvarOffset NMSPerformanceCaptureIvarOffset
#define MTNMSSessionKind NMSPerformanceSessionKind
#define MTNMSPrepareRecharge NMSPerformancePrepareRecharge
#import "../../Modules/no-mans-sky/Sources/NMSAdapter.m"
#undef MTNMSAdapter
#undef MTNMSValue
#undef MTNMSReadOnly
#undef MTNMSProcessBuildMatches
#undef MTNMSCaptureIvarOffset
#undef MTNMSSessionKind
#undef MTNMSPrepareRecharge
#include <sys/mman.h>
#include <unistd.h>
static NSUInteger contextQueries;
@interface CountedNMSAdapter : NMSPerformanceAdapter @end
@implementation CountedNMSAdapter
- (MTGameContext *)captureContext{contextQueries++;MTGameContext *c=[MTGameContext new];c.kind=MTSessionLoading;return c;}
@end
static void check(BOOL okay,const char *why){if(!okay){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
static BOOL *array(id owner,const char *name){Ivar field=class_getInstanceVariable(NMSPerformanceAdapter.class,name);check(field!=NULL,"original adapter field exists");return (BOOL *)((uint8_t *)(__bridge void *)owner+ivar_getOffset(field));}
int main(void){@autoreleasepool{
 CountedNMSAdapter *adapter=[CountedNMSAdapter new];[adapter setValue:@YES forKey:@"bound"];onFrame=YES;
 BOOL *wanted=array(adapter,"_wantedCache"),*confirmed=array(adapter,"_confirmed");
 for(unsigned i=0;i<20000;i++)[adapter maintainFrameEffects];
 check(!contextQueries,"idle frames do not rediscover the player");
 const MTFeature pollOnly[]={MTFeatureItems,MTFeatureCrafting,MTFeatureDamage,MTFeatureShipHeat,MTFeatureInfiniteUnits,MTFeatureGameSpeed,MTFeatureAtlasLocks,MTFeatureInfiniteNanites,MTFeatureInfiniteQuicksilver};
 for(NSUInteger i=0;i<sizeof(pollOnly)/sizeof(*pollOnly);i++){wanted[pollOnly[i]]=YES;confirmed[pollOnly[i]]=YES;}
 for(unsigned i=0;i<20000;i++)[adapter maintainFrameEffects];
 check(!contextQueries,"poll-only options cannot cause empty frame-level context discovery");
 wanted[MTFeatureShield]=confirmed[MTFeatureShield]=YES;[adapter maintainFrameEffects];
 check(contextQueries==1,"a real frame-maintained option still validates the native context immediately");
 onFrame=NO;
 size_t page=(size_t)getpagesize();uint8_t *flag=mmap(NULL,page,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
 check(flag!=MAP_FAILED,"private data page allocated");*flag=1;check(!mprotect(flag,page,PROT_READ),"only fixture data protected");
 NMSPerformanceValue *lease=[[NMSPerformanceValue alloc]initWithAddress:flag size:1];uint8_t target=1;
 for(unsigned i=0;i<10000;i++)check([lease applyBytes:&target readOnly:NO],"matching native bytes do not require another write");
 target=0;check(![lease applyBytes:&target readOnly:NO]&&*flag==1,"a changed value on read-only data remains rejected");
 check(!mprotect(flag,page,PROT_READ|PROT_WRITE),"fixture data writable again");check([lease releaseValue]&&*flag==1,"idempotent lease keeps its original baseline");munmap(flag,page);
 puts("PASS: real NMS adapter: 40,000 idle/poll-only frames avoid player discovery; genuine frame maintenance keeps context validation. Synthetic only.");
}return 0;}
