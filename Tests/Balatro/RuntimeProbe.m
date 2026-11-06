// SPDX-License-Identifier: GPL-3.0-only
// Development-only in-game observer. Never listed among product sources.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <AppKit/AppKit.h>
static FILE *stream;
static void (*enqueue)(dispatch_block_t);
static NSDictionary *(*inspect)(void);
static void dump(void){
 if(!enqueue || !inspect)return;
 static BOOL reported=NO;if(!reported){reported=YES;for(NSWindow *w in NSApp.windows)fprintf(stream,"BALATRO_UI active=%d window=%s visible=%d key=%d ignoresMouse=%d frame=%s\n",NSApp.isActive,NSStringFromClass(w.class).UTF8String,w.isVisible,w.isKeyWindow,w.ignoresMouseEvents,NSStringFromRect(w.frame).UTF8String);fflush(stream);}
 enqueue(^{@autoreleasepool{NSData *data=[NSJSONSerialization dataWithJSONObject:inspect() options:NSJSONWritingSortedKeys error:NULL];fprintf(stream,"BALATRO_NATIVE %.*s\n",(int)data.length,(const char *)data.bytes);fflush(stream);}});
}
__attribute__((constructor)) static void start(void){
 stream=fopen("/private/tmp/mht-balatro/runtime-probe.log","w");if(!stream)return;
 enqueue=dlsym(RTLD_DEFAULT,"BAEnqueue");inspect=dlsym(RTLD_DEFAULT,"BAInspect");
 dispatch_async(dispatch_get_main_queue(),^{NSTimer *timer=[NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *t){(void)t;dump();}];[NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];});
}
