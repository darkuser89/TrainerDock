// SPDX-License-Identifier: GPL-3.0-only
// Explicit local test candidate only. Never included in Build.json or Xcode targets.
#import "NMSAdapter.h"
#import "MemoryAccess.h"
#import <AppKit/AppKit.h>
#import <unistd.h>
#import <dlfcn.h>
static MTNMSAdapter *probe;
static NSString *token;
static void report(NSDictionary *result){
    NSData *data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
    [data writeToFile:@"/private/tmp/mht-no-mans-sky/Result.json" options:NSDataWritingAtomic error:NULL];
}
static NSDictionary *status(void){
    MTGameContext *c=[probe captureContext];
    uintptr_t root=[[probe valueForKey:@"root"] unsignedLongLongValue],parent=0,input=0,view=0,vt=0;
    uintptr_t capture=(uintptr_t)dlsym(RTLD_DEFAULT,"_Z21setEnableCaptureInputb");
    uintptr_t slide=capture-0x102ec8044,window=(uintptr_t)dlsym(RTLD_DEFAULT,"gCurrentWindow");
    ptrdiff_t captureOffset=MTNMSCaptureIvarOffset(NSClassFromString(@"GainputMacInputView"));
    uint8_t values[5]={255,255,255,255,255};
    BOOL valid=root && capture && MTReadMemory((void *)(root+0x971bc8),&parent,8) && parent
        && MTReadMemory((void *)(0x103d8f518+slide),&input,8) && input
        && MTReadMemory((void *)(input+0x1e0),&view,8) && view;
    valid=valid && captureOffset>=0;
    if(valid){
        valid=MTReadMemory((void *)(input+0x231),values,1) && MTReadMemory((void *)(window+0x3d),values+1,1)
            && MTReadMemory((void *)(view+(uintptr_t)captureOffset),values+2,1) && MTReadMemory((void *)(parent+8+0x2c),values+3,1)
            && MTReadMemory((void *)(parent+8+0x20d),values+4,1) && MTReadMemory((void *)(parent+8),&vt,8);
    }
    return @{@"kind":@(c.kind),@"identity":c.identity ?: @"",@"note":c.note ?: @"",@"pid":@(getpid()),@"bound":[probe valueForKey:@"bound"] ?: @NO,
        @"input":@{@"valid":@(valid),@"captureIvarOffset":@(captureOffset),@"active":@(NSApp.isActive),@"inputCapture":@(values[0]),@"windowCapture":@(values[1]),@"rawViewCapture":@(values[2]),
            @"engineLocked":@(values[3]),@"engineShown":@(values[4]),@"deviceVtableMatches":@(vt==0x103697768+slide)}};
}
static void batch(void){
    NSDictionary *context=status();if([context[@"kind"] integerValue]!=MTSessionSolo){report(context);return;}
    // Scalar flags/factors restore their own baselines. No currency or inventory grants.
    NSMutableArray *results=[NSMutableArray new];
    for(NSNumber *n in @[@0,@1,@2,@3,@6,@7,@15,@16,@19,@21,@22]){
        MTFeature feature=n.integerValue;const MTFeatureInfo *info=MTFeatureInfoAt(feature);
        MTFeatureState *on=[probe applyFeature:feature wanted:YES value:info->numeric ? 1.25 : 0];
        BOOL active=on.active;NSString *note=on.note ?: @"";
        MTFeatureState *off=[probe applyFeature:feature wanted:NO value:0];
        [results addObject:@{@"id":n,@"title":info->title,@"active":@(active),@"available":@(on.available),@"off":@(!off.active),@"note":note}];
    }
    [probe releaseEffects];report(@{@"context":context,@"checks":results});
}
__attribute__((constructor)) static void developmentChecks(void){@autoreleasepool{
    if(![NSProcessInfo.processInfo.environment[@"MHT_NMS_DEVELOPMENT"] isEqual:@"1"] || !MTNMSProcessBuildMatches())return;
    token=NSProcessInfo.processInfo.environment[@"MHT_SESSION"];
    dispatch_async(dispatch_get_main_queue(),^{
        probe=[MTNMSAdapter new];
        [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.mht.nms.development" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
            NSData *data=[event.object isKindOfClass:NSString.class] ? [event.object dataUsingEncoding:NSUTF8StringEncoding] : nil;
            NSDictionary *m=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
            if(![m isKindOfClass:NSDictionary.class] || ![m[@"token"] isEqual:token] || [m[@"pid"] intValue]!=getpid())return;
            NSString *action=m[@"action"];
            [probe onGameThread:^{if([action isEqual:@"batch"])batch();else report(status());}];
        }];
        [probe onGameThread:^{report(status());}];
    });
}}
