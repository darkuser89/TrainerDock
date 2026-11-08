// SPDX-License-Identifier: GPL-3.0-only
// Standalone synthetic executable. It is never part of the delivered module.
#import <AppKit/AppKit.h>
#import "MHTProtocol.h"
#import <dlfcn.h>
int main(void){@autoreleasepool{
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    if(!dlsym(RTLD_DEFAULT,"MHTDSBuildMatches")){fprintf(stderr,"FAIL: trainer was not the inserted library\n");return 1;}
    NSDictionary *profile=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:NSProcessInfo.processInfo.environment[@"TD_STARTUP_PROFILE"]] options:0 error:NULL];
    BOOL(*identity)(NSDictionary *,NSString *)=dlsym(RTLD_DEFAULT,"MTCurrentProcessMatches");
    if(!identity || !identity(profile,NSProcessInfo.processInfo.environment[@"MHT_TARGET"])){fprintf(stderr,"FAIL: inserted identity check cannot identify its actual executable bundle\n");return 1;}
    NSMutableDictionary *wrong=[profile mutableCopy];wrong[@"bundleIdentifier"]=@"unrelated.bundle";
    if(identity(wrong,NSProcessInfo.processInfo.environment[@"MHT_TARGET"])){fprintf(stderr,"FAIL: wrong bundle accepted\n");return 1;}
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:.1];
    while(deadline.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    BOOL(*matches)(void)=dlsym(RTLD_DEFAULT,"MHTDSBuildMatches");
    if(matches()){fprintf(stderr,"FAIL: fixture cannot authorize the original game binding\n");return 1;}
    puts("PASS: exact executable/bundle identity works when inserted first, with no external runtime configuration; wrong bundle and original game binding reject this unrelated fixture. No game started.");
}return 0;}
