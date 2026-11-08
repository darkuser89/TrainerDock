// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "LiesOfPAdapter.h"
#import <sys/mman.h>
#import <unistd.h>
// Invoke the real data-lease implementation on this test's own anonymous page.
// No executable game or original binding is present in this process.
@interface LOPGameAdapter (LeaseContract)
- (BOOL)write:(NSString *)key owner:(uintptr_t)owner base:(uintptr_t)base stat:(uint8_t)stat offset:(size_t)offset bytes:(const void *)bytes length:(size_t)length;
@end
int main(void){@autoreleasepool{
 NSCAssert(MTFeatureCount==36&&MTFeatureHealth==0,@"No master option in native catalog");
 LOPGameAdapter *adapter=[LOPGameAdapter new];NSCAssert([adapter captureContext].kind==MTSessionUnsupported,@"Unrelated executable cannot access native game bindings");
 for(NSInteger i=0;i<MTFeatureCount;i++){
  const MTFeatureInfo *f=MTFeatureInfoAt(i);NSCAssert(![f->title containsString:@"Trainer aktivieren"],@"Removed action cannot be displayed");
  MTFeatureState *s=[adapter applyFeature:i wanted:YES value:f->initial];NSCAssert(!s.available&&!s.active,@"Removing the master preserves real process/context checks");
 }
 __block BOOL done=NO;[adapter onGameThread:^{done=YES;}];NSDate *until=[NSDate dateWithTimeIntervalSinceNow:1];while(!done&&until.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.01]];NSCAssert(done,@"Unsupported process completes without pretending to be the GameThread");
 [adapter releaseEffects];puts("Lies of P catalog/native context checks passed");
 size_t page=(size_t)sysconf(_SC_PAGESIZE);void *fixture=mmap(NULL,page,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
 NSCAssert(fixture!=MAP_FAILED,@"Anonymous test page");
 float before=5,target=10;memcpy(fixture,&before,4);
 NSCAssert([adapter write:@"fixture/lease" owner:0 base:(uintptr_t)fixture stat:0 offset:0 bytes:&target length:4],@"First lease writes and reads back");
 NSCAssert(mprotect(fixture,page,PROT_READ)==0,@"Only the synthetic page becomes read-only");
 for(int i=0;i<1000;i++)NSCAssert([adapter write:@"fixture/lease" owner:0 base:(uintptr_t)fixture stat:0 offset:0 bytes:&target length:4],@"Unchanged leases only read back; they never require another write");
 NSCAssert(mprotect(fixture,page,PROT_READ|PROT_WRITE)==0,@"Restore synthetic page permissions");
 float foreign=11;memcpy(fixture,&foreign,4);
 NSCAssert(![adapter write:@"fixture/lease" owner:0 base:(uintptr_t)fixture stat:0 offset:0 bytes:&target length:4] && *(float *)fixture==foreign,@"Foreign changes remain rejected and preserved");
 munmap(fixture,page);puts("PASS: 1,000 stable native leases without writes; foreign edits preserved. Synthetic page only; no game started.");
}return 0;}
