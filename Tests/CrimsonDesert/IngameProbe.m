// SPDX-License-Identifier: GPL-3.0-only
// Explicit local test helper; never included in the product runtime.
#import "CrimsonNative.h"
__attribute__((constructor)) static void beginProbe(void) {
    @autoreleasepool {
        const char *path=getenv("MT_CRIMSON_PROBE_OUTPUT");
        if(!path) return;
        NSString *output=@(path);
        BOOL matched=CDCorrectBuild();
        NSData *loaded=[NSJSONSerialization dataWithJSONObject:@{@"stage":matched ? @"Library loaded; waiting for native game timer" : @"Build mismatch",@"buildMatched":@(matched),@"pid":@(NSProcessInfo.processInfo.processIdentifier)} options:NSJSONWritingPrettyPrinted error:NULL];
        [loaded writeToFile:output options:NSDataWritingAtomic error:NULL];
        if(!matched) return;
        dispatch_async(dispatch_get_main_queue(),^{
            __block unsigned samples=0;
            __block NSInteger lastCommand=0;
            __block NSDictionary *commandResult=@{};
            NSTimer *timer=[NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *t) {
                if(samples++>=3600) {[t invalidate];CDOnGameThread(^{CDReleaseEffects();});return;}
                CDOnGameThread(^{
                    NSData *commandData=[NSData dataWithContentsOfFile:[output stringByAppendingString:@".command.json"]];
                    NSDictionary *command=commandData ? [NSJSONSerialization JSONObjectWithData:commandData options:0 error:NULL] : nil;
                    if([command isKindOfClass:NSDictionary.class] && [command[@"sequence"] isKindOfClass:NSNumber.class] && [command[@"sequence"] integerValue]>lastCommand) {
                        lastCommand=[command[@"sequence"] integerValue];
                        BOOL queued=NO;
                        BOOL currentProcess=[command[@"pid"] isKindOfClass:NSNumber.class] && [command[@"pid"] intValue]==NSProcessInfo.processInfo.processIdentifier;
                        if(currentProcess && [command[@"stat"] isKindOfClass:NSNumber.class] && [command[@"ratio"] isKindOfClass:NSNumber.class] && [command[@"actorKey"] isKindOfClass:NSNumber.class])
                            queued=CDSetPlayerStatRatio([command[@"stat"] unsignedIntValue],[command[@"ratio"] doubleValue],[command[@"actorKey"] unsignedIntValue]);
                        if(currentProcess && [command[@"overlay"] isKindOfClass:NSNumber.class]) queued=CDSetOverlayInteraction([command[@"overlay"] boolValue]);
                        if(currentProcess && [command[@"feature"] isKindOfClass:NSNumber.class] && [command[@"wanted"] isKindOfClass:NSNumber.class] && [command[@"value"] isKindOfClass:NSNumber.class])queued=CDRequestEffect([command[@"feature"] unsignedIntValue],[command[@"wanted"] boolValue],[command[@"value"] doubleValue],[command[@"actorKey"] unsignedIntValue]);
                        commandResult=@{@"sequence":@(lastCommand),@"queued":@(queued)};
                    }
                    NSMutableDictionary *snapshot=[CDReadPlayer() mutableCopy];
                    snapshot[@"command"]=commandResult;
                    snapshot[@"sample"]=@(samples);
                    snapshot[@"pid"]=@(NSProcessInfo.processInfo.processIdentifier);
                    NSData *data=[NSJSONSerialization dataWithJSONObject:snapshot options:NSJSONWritingPrettyPrinted error:NULL];
                    if(data) [data writeToFile:output options:NSDataWritingAtomic error:NULL];
                });
            }];
            [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
        });
    }
}
