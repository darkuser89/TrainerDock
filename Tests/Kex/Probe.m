// SPDX-License-Identifier: GPL-3.0-only
// Test-only original state inspection and a reversible original ammo-consumption trial.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <unistd.h>
#import "MemoryAccess.h"
static id observer;
static BOOL readAt(void *p,size_t offset,void *out,size_t n){return p && MTReadMemory((uint8_t *)p+offset,out,n);}
__attribute__((constructor)) static void start(void){@autoreleasepool{
 NSString *token=NSProcessInfo.processInfo.environment[@"MHT_SESSION"];if(!token.length)return;
 dispatch_async(dispatch_get_main_queue(),^{
  observer=[NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.trainerdock.kex.test" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
   if(![event.object isKindOfClass:NSString.class] || [event.object length]>4096)return;
   NSDictionary *request=event.object ? [NSJSONSerialization JSONObjectWithData:[event.object dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL] : nil;
   if(![request[@"token"] isEqual:token] || [request[@"pid"] intValue]!=getpid() || [request[@"deadline"] doubleValue]<NSDate.date.timeIntervalSince1970)return;
   void (*enqueue)(dispatch_block_t)=dlsym(RTLD_DEFAULT,"KEXEnqueue");NSDictionary *(*inspect)(void)=dlsym(RTLD_DEFAULT,"KEXInspect");if(!enqueue || !inspect)return;
   enqueue(^{@autoreleasepool{
    NSMutableDictionary *result=[inspect() mutableCopy];BOOL second=[NSProcessInfo.processInfo.environment[@"MHT_MODULE"] isEqual:@"turok-2"];
    void **slot=dlsym(RTLD_MAIN_ONLY,"_ZN7kexGame6cLocalE"),*local=NULL,*player=NULL,*puppet=NULL,*ammo=NULL;
    if(readAt(slot,0,&local,8) && local){
     if(second)player=(uint8_t *)local+0x141c8;
     else{void **ps=dlsym(RTLD_MAIN_ONLY,"_ZN7kexGame7cPlayerE");readAt(ps,0,&player,8);}
     readAt(player,second ? 0x110 : 0x68,&puppet,8);
     if(puppet){if(second){float hp=0;readAt(puppet,0x6c,&hp,4);result[@"health"]=@(hp);}else{int16_t hp=0;readAt(puppet,0x134,&hp,2);result[@"health"]=@(hp);}}
     uint32_t god=0,inf=0;readAt(puppet,second ? 0x1f0 : 0x3b4,&god,4);readAt(local,second ? 0x1412c : 0x28320,&inf,4);result[@"godBit"]=@((god&8)!=0);result[@"ammoBit"]=@((inf&4)!=0);
     uint32_t index=0,count=0;void *list=NULL;readAt(player,second ? 0x178 : 0xbc,&index,4);readAt(player,second ? 0x168 : 0x78,&count,4);readAt(player,second ? 0x160 : 0x70,&list,8);
     if([result[@"kind"] integerValue]==2 && list && index<count && count<128){
      if(second)readAt(list,32*index+16,&ammo,8);
      else{void *weapon=NULL;readAt(list,8*index,&weapon,8);void *(*get)(void*)=dlsym(RTLD_MAIN_ONLY,"_ZN15kexPlayerWeapon7GetAmmoEv");if(weapon && get)ammo=get(weapon);}
     }
     int32_t before=0;if(readAt(ammo,0,&before,4)){
      result[@"ammo"]=@(before);
      if([request[@"action"] isEqual:@"ammoTrial"] && before>0 && [result[@"kind"] integerValue]==2){
       void (*consume)(void*,int)=dlsym(RTLD_MAIN_ONLY,"_ZN9kexPlayer11ConsumeAmmoEi");
       void (*give)(void*,void*,int)=dlsym(RTLD_MAIN_ONLY,second ? "_ZN9kexPlayer8GiveAmmoEPNS_6ammo_tEi" : "_ZN9kexPlayer8GiveAmmoEP10ammoInfo_ti");
       if(consume && give){consume(player,1);int32_t after=0,restored=0;readAt(ammo,0,&after,4);if(after==before-1)give(player,ammo,1);readAt(ammo,0,&restored,4);result[@"before"]=@(before);result[@"after"]=@(after);result[@"restored"]=@(restored);}
      }
     }
    }
    NSDictionary *reply=@{@"token":token,@"id":request[@"id"] ?: @"",@"result":result};NSData *data=[NSJSONSerialization dataWithJSONObject:reply options:0 error:NULL];
    [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"local.trainerdock.kex.reply" object:[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding] userInfo:nil deliverImmediately:YES];
   }});
  }];
 });
}}
