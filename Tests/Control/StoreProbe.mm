// SPDX-License-Identifier: GPL-3.0-only
// Read-only store compatibility check. Never linked into a product module.
#import <AppKit/AppKit.h>
#import <os/log.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dlfcn.h>
static NSString *imageUUID(const mach_header_64 *h){if(!h||h->magic!=MH_MAGIC_64)return @"";const load_command *c=(const load_command*)(h+1);for(uint32_t i=0;i<h->ncmds;i++){if(c->cmdsize<sizeof(load_command))break;if(c->cmd==LC_UUID)return [[NSUUID alloc]initWithUUIDBytes:((const uuid_command*)c)->uuid].UUIDString;c=(const load_command*)((const char*)c+c->cmdsize);}return @"";}
__attribute__((constructor))static void check(){@autoreleasepool{
 dispatch_async(dispatch_get_main_queue(),^{
  NSString *report=[NSTemporaryDirectory()stringByAppendingPathComponent:[NSString stringWithFormat:@"MHT-Control-StoreProbe-%d.json",getpid()]];
  [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification *event){(void)event;[NSFileManager.defaultManager removeItemAtPath:report error:NULL];}];
  static NSUInteger count;[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){
   NSMutableArray *images=[NSMutableArray new];for(uint32_t i=0;i<_dyld_image_count();i++){NSString *path=@(_dyld_get_image_name(i));if([@[@"Control Ultimate Edition",@"coregame.dylib",@"app.dylib",@"bonsai.dylib",@"rl.dylib",@"Trainer.dylib"]containsObject:path.lastPathComponent])[images addObject:@{@"name":path.lastPathComponent,@"uuid":imageUUID((const mach_header_64*)_dyld_get_image_header(i))}];}
   auto identity=(BOOL(*)(void))dlsym(RTLD_DEFAULT,"MHTControlEngineIdentity");
   NSDictionary *out=@{@"pid":@(getpid()),@"bundle":NSBundle.mainBundle.bundleIdentifier?:@"",@"runtimeLoaded":@(identity!=nullptr),@"nativeIdentity":@(identity&&identity()),@"images":images};
   NSString *path=report;
   BOOL written=[[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:path options:NSDataWritingAtomic error:NULL];
   if(!count)os_log(OS_LOG_DEFAULT,"TrainerDock Control store probe pid=%d runtime=%d identity=%d report=%{public}s written=%d",getpid(),identity!=nullptr,identity&&identity(),path.UTF8String,written);
   if(++count>=10)[timer invalidate];
  }];
 });
}}
