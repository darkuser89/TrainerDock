// SPDX-License-Identifier: GPL-3.0-only
// Synthetic writable-data page and narrow native API. No game is started.
#import <Foundation/Foundation.h>
#import <sys/mman.h>
#import <unistd.h>
#import "RoboCopAdapter.h"
#define MHT_OVERLAY_WINDOW_CHECKS_ONLY 1
#import "../OverlayRuntimeWindowTests.m"
// Matches the private data-lease descriptor's ABI, not a game structure.
typedef struct {size_t offset;uint8_t kind,mode;double value;} LeaseField;
@interface RCRoboCopAdapter (LeaseContract)
- (BOOL)modify:(MTFeature)feature owner:(void *)owner fields:(const LeaseField *)fields count:(size_t)count;
- (void)releaseLeases:(MTFeature)feature;
@end
static void *fixture;
static BOOL onThread(void){return YES;}
static void assign(RCWeak *weak,const void *owner){NSCAssert(owner==fixture,@"Only the synthetic page is owned");*weak=(RCWeak){1,1};}
static void *resolve(const RCWeak *weak){return weak->index==1&&weak->serial==1?fixture:NULL;}
int main(void){@autoreleasepool{
 size_t page=(size_t)sysconf(_SC_PAGESIZE);fixture=mmap(NULL,page,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
 NSCAssert(fixture!=MAP_FAILED,@"Anonymous test page");
 RCNativeAPI api={.valid=YES,.isGameThread=onThread,.weakAssign=assign,.weakGet=resolve};
 RCRoboCopAdapter *adapter=[[RCRoboCopAdapter alloc]initWithAPI:api];
 LeaseField field={0,0,0,10};*(float *)fixture=5;
 NSCAssert([adapter modify:MTFeatureMovement owner:fixture fields:&field count:1]&&*(float *)fixture==10,@"First lease writes and reads back");
 NSCAssert(mprotect(fixture,page,PROT_READ)==0,@"Only the synthetic page becomes read-only");
 for(int i=0;i<1000;i++)NSCAssert([adapter modify:MTFeatureMovement owner:fixture fields:&field count:1],@"Stable leases require readback but never a redundant write");
 NSCAssert(mprotect(fixture,page,PROT_READ|PROT_WRITE)==0,@"Restore synthetic page permissions");
 field.value=20;NSCAssert([adapter modify:MTFeatureMovement owner:fixture fields:&field count:1]&&*(float *)fixture==20,@"A changed requested target still writes");
 [adapter releaseLeases:MTFeatureMovement];NSCAssert(*(float *)fixture==5,@"Off restores own original");
 NSCAssert([adapter modify:MTFeatureMovement owner:fixture fields:&field count:1],@"New lease applies");
 *(float *)fixture=23;
 NSCAssert(![adapter modify:MTFeatureMovement owner:fixture fields:&field count:1]&&*(float *)fixture==23,@"Foreign writes are rejected and preserved");
 munmap(fixture,page);fixture=NULL;
 puts("PASS: 1,000 stable native leases without writes, changed targets, off restoration and foreign edits. Synthetic page only; no game started.");
 MHTCheckRuntimeWindows();
}}
