// SPDX-License-Identifier: GPL-3.0-only
// Session-only checks against the product's actual native inventory helper.
// Not linked into any shipped trainer. Requests/reports remain outside the code.
#import "ControlEngine.h"
#import "ControlInventory.h"
#include <dlfcn.h>
#include <memory>
#include <vector>
static NSString *const directory=@"/private/tmp/mht-control";
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static uintptr_t component(uintptr_t owner,NSString *type){uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t n=r<uint32_t>(owner+0x68);if(n<=128)for(uint32_t i=0;i<n;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c+0x20)==owner&&[MHTControlType(c)isEqual:type])return c;}return 0;}
static NSArray *snapshot(uintptr_t inventory){
 uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE"),map=r<uintptr_t>(global);
 auto resolve=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");
 NSMutableArray *out=[NSMutableArray new];uintptr_t list=r<uintptr_t>(inventory+0x38);uint32_t count=r<uint32_t>(inventory+0x40);
 if(!map||!resolve||count>4096)return out;
 for(uint32_t i=0;i<count;i++){uint64_t gid=r<uint64_t>(list+i*16);uintptr_t object=(uintptr_t)resolve((void*)map,&gid),stack=component(object,@"ItemStackComponentState"),loot=component(object,@"LootDropItemComponentState"),item=component(object,@"coregame::ItemComponentState");
  if(!loot)continue;[out addObject:@{@"gid":@(gid),@"object":@(object),@"stack":@(stack),@"amount":@(r<int>(stack+0x38)),@"template":@(r<uint64_t>(loot+0x38)),@"holder":@(r<uint32_t>(item+0x60))}];
 }
 return out;
}
static void frame(){@autoreleasepool{
 static std::unique_ptr<MHTControlInventory> candidate;static uintptr_t previousAvatar;static uint64_t previousID;static NSUInteger previousPhase=NSNotFound;static NSArray *before;static NSDictionary *refill;
 NSMutableDictionary *out=[@{@"pid":@(getpid()),@"nativeThread":@(MHTControlOnEngineFrame())}mutableCopy];
 if(!MHTControlEngineIdentity()||!MHTControlOnEngineFrame()){out[@"status"]=@"unsupported";return;}
 uintptr_t core=MHTControlCoreImage();void *server=MHTControlServer();uintptr_t session=server?((uintptr_t(*)(void*))(core+0x19c478))(server):0,avatar=session?((uintptr_t(*)(void*))(core+0x2c0c10))((void*)session):0;
 uint64_t owner=r<uint64_t>(avatar+0x10);uintptr_t inventory=component(avatar,@"GameInventoryComponentState");
 NSDictionary *request=[NSDictionary dictionaryWithContentsOfFile:[directory stringByAppendingPathComponent:@"MaterialRequest.plist"]];NSUInteger phase=[request[@"phase"]unsignedIntegerValue];
 if(previousAvatar!=avatar||previousID!=owner){if(candidate)candidate->discardOwner();previousAvatar=avatar;previousID=owner;before=nil;refill=nil;previousPhase=NSNotFound;}
 if(!candidate)candidate=std::make_unique<MHTControlInventory>();
 out[@"avatar"]=@(avatar);out[@"avatarHandle"]=@(r<uint32_t>(avatar+0x20));out[@"inventory"]=@(inventory);out[@"phase"]=@(phase);
 if(avatar&&inventory){
  if(phase==1&&previousPhase!=1)before=snapshot(inventory);
  // A separate explicit request tests a consumed unit on the same owned stack.
  if(phase==3&&previousPhase!=3){NSArray *items=snapshot(inventory);for(NSDictionary *item in items){uintptr_t stack=[item[@"stack"]unsignedLongLongValue];int amount=[item[@"amount"]intValue];if(stack&&amount==999&&[item[@"holder"]unsignedIntValue]==r<uint32_t>(avatar+0x20)){int reduced=998;BOOL wrote=MHTControlWrite(stack+0x38,&reduced,4);refill=@{@"gid":item[@"gid"],@"before":@(amount),@"consumed":@(r<int>(stack+0x38)),@"wrote":@(wrote)};break;}}}
  if(phase==2)candidate->release();
  auto result=candidate->update(avatar,inventory,phase==1||phase==3,false);
  out[@"materialCount"]=@(result.materialCount);out[@"active"]=@(result.materialsActive);out[@"recipesAvailable"]=@(result.recipesAvailable);out[@"items"]=snapshot(inventory);out[@"before"]=before?:@[];out[@"refill"]=refill?:@{};
 }
 previousPhase=phase;
 [[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:[directory stringByAppendingPathComponent:@"MaterialState.json"] options:NSDataWritingAtomic error:NULL];
}}
__attribute__((constructor))static void start(){dispatch_async(dispatch_get_main_queue(),^{[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){(void)timer;MHTControlSchedule(^{frame();});}];});}
