// SPDX-License-Identifier: GPL-3.0-only
// Exercise the real adapter with fixture-only data access and a counted owner
// refresh. No fixture is linked into a TrainerDock runtime or game process.
#import <AppKit/AppKit.h>
#include <map>
#include <vector>
#define MHTControlOnEngineFrame FixtureOnFrame
#define MHTControlRead FixtureRead
#define MHTControlWrite FixtureWrite
#define MHTNativeAdapter MHTControlPerformanceAdapter
#import "../../Modules/control/Sources/NativeAdapter.mm"
#undef MHTNativeAdapter
#undef MHTControlOnEngineFrame
#undef MHTControlRead
#undef MHTControlWrite
static size_t reads,writes,refreshes;
static std::map<uintptr_t,std::vector<uint8_t>> memory;
BOOL FixtureOnFrame(void){return YES;}
BOOL FixtureRead(uintptr_t p,void *out,size_t n){reads++;memset(out,0,n);auto it=memory.find(p);if(it!=memory.end()&&it->second.size()==n)memcpy(out,it->second.data(),n);return YES;}
BOOL FixtureWrite(uintptr_t p,const void *bytes,size_t n){writes++;memory[p]=std::vector<uint8_t>((const uint8_t *)bytes,(const uint8_t *)bytes+n);return YES;}
@interface MHTControlPerformanceAdapter (FrameTest)
- (void)maintain;
@end
@interface CountedControlAdapter : MHTControlPerformanceAdapter @end
@implementation CountedControlAdapter
- (BOOL)refresh{refreshes++;return YES;}
@end
static void check(bool okay,const char *why){if(!okay){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
int main(){@autoreleasepool{
 CountedControlAdapter *adapter=[CountedControlAdapter new];
 for(unsigned i=0;i<20000;i++)[adapter maintain];
 check(!refreshes&&!reads&&!writes,"20,000 idle frames perform no owner discovery, data reads or writes");
 [adapter setValue:@0x10000 forKey:@"avatar"];
 [adapter setValue:@0x20000 forKey:@"resource"];
 MTFeatureState *enabled=[adapter applyFeature:MTFeatureEnergy wanted:YES value:0];
 check(refreshes==1&&enabled.active&&writes==2,"enabling an effect immediately applies and confirms its original two data fields");
 reads=writes=refreshes=0;
 for(unsigned i=0;i<20000;i++)[adapter applyFeature:MTFeatureEnergy wanted:YES value:0];
 check(!refreshes&&!reads&&!writes,"unchanged bridge requests do not rerun all frame-maintained effects");
 for(unsigned i=0;i<200;i++)[adapter maintain];
 check(refreshes==200&&reads>0&&!writes,"active effects retain every-frame owner/readback validation without rewriting unchanged data");
 [adapter applyFeature:MTFeatureEnergy wanted:NO value:0];
 check(![adapter applyFeature:MTFeatureEnergy wanted:NO value:0].active,"turning off releases the effect");
 float value=1;FixtureRead(0x20038,&value,4);check(value==0,"own energy baseline restored on transition");
 reads=writes=refreshes=0;
 for(unsigned i=0;i<20000;i++)[adapter maintain];
 check(!refreshes&&!reads&&!writes,"idle fast path resumes after release");
 puts("PASS: real Control adapter: 40,000 idle frames and 20,000 unchanged setters do no native work; active frames retain validation, skip unchanged writes and restore owned values. Synthetic only.");
}}
