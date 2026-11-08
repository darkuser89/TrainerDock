// SPDX-License-Identifier: GPL-3.0-only
// Test-owned pages prove the product ledger skips writes only after validation.
#import <AppKit/AppKit.h>
#import "RE2Adapter.h"
#import "RE2EffectLedger.h"
#include <sys/mman.h>
#include <unistd.h>
static void check(BOOL okay,const char *why){if(!okay){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
int main(void){@autoreleasepool{
 RE2NativeAdapter *adapter=[RE2NativeAdapter new];
 size_t page=(size_t)getpagesize();uint32_t *value=mmap(NULL,page,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
 check(value!=MAP_FAILED,"private fixture page allocated");*value=7;
 check(!mprotect(value,page,PROT_READ),"only the test-owned page becomes read-only");
 uint32_t target=7;NSData *wanted=[NSData dataWithBytes:&target length:4];
 for(unsigned i=0;i<10000;i++)check([adapter applyBytes:wanted object:value offset:0 owner:nil global:YES feature:RE2FeatureHealth],"already matching bytes confirm without a writable-page request");
 target=9;check(![adapter applyBytes:[NSData dataWithBytes:&target length:4] object:value offset:0 owner:nil global:YES feature:RE2FeatureHealth]&&*value==7,"a genuine change on read-only data remains rejected");
 [adapter releaseFeature:RE2FeatureHealth];check(*value==7,"failed writes do not cause foreign baseline restoration");
 check(!mprotect(value,page,PROT_READ|PROT_WRITE),"fixture page writable again");
 check([adapter applyBytes:[NSData dataWithBytes:&target length:4] object:value offset:0 owner:nil global:YES feature:RE2FeatureHealth]&&*value==9,"genuine writable change is still applied and read back");
 [adapter releaseFeature:RE2FeatureHealth];check(*value==7,"own baseline restored");
 check([adapter applyBytes:[NSData dataWithBytes:&target length:4] object:value offset:0 owner:nil global:YES feature:RE2FeatureHealth],"new owned change");
 *value=13;[adapter releaseFeature:RE2FeatureHealth];check(*value==13,"a later foreign change remains protected");
 munmap(value,page);
 puts("PASS: real shared RE ledger: 10,000 matching-value confirmations need no write permission; changed values still require writable data and preserve ownership/restoration. Synthetic only.");
}return 0;}
