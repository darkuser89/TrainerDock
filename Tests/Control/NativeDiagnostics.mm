// SPDX-License-Identifier: GPL-3.0-only
// Session-only native observations. Not linked into a shipped module.
#import "ControlEngine.h"
#include <dlfcn.h>
#include <vector>
#include <set>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static NSString *bytes(uintptr_t p,size_t n){std::vector<uint8_t>b(n);return MHTControlRead(p,b.data(),n)?[[NSData dataWithBytes:b.data() length:n]base64EncodedStringWithOptions:0]:@"";}
static uintptr_t component(uintptr_t owner,NSString *name){uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t count=r<uint32_t>(owner+0x68);if(count>128)return 0;for(uint32_t i=0;i<count;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c+0x20)==owner&&[MHTControlType(c)isEqual:name])return c;}return 0;}
void MTControlDiagnosticFrame(void){static uint64_t frame=0;static float minAmmo=INFINITY;static uint64_t previousAvatar=0;
 if(!MHTControlOnEngineFrame()||++frame%60)return;uintptr_t core=MHTControlCoreImage(),main=MHTControlMainImage();void *server=MHTControlServer();
 uintptr_t session=((uintptr_t(*)(void*))(core+0x19c478))(server),avatar=session?((uintptr_t(*)(void*))(core+0x2c0c10))((void*)session):0;
 if(avatar!=previousAvatar){minAmmo=INFINITY;previousAvatar=avatar;}
 uintptr_t inv=component(avatar,@"GameInventoryComponentState"),player=component(avatar,@"PlayerPropertiesComponentState"),health=component(avatar,@"GameHealthComponentState"),movement=component(avatar,@"MovementSystemComponentState");
 float ammo=r<float>(inv+0x2b8);minAmmo=fminf(minAmmo,ammo);
 struct Position{float x,y,z;};auto getPosition=(Position(*)(void*))dlsym(RTLD_DEFAULT,"_ZNK1r15GameObjectState11getPositionEv");Position pos=avatar&&getPosition?getPosition((void*)avatar):Position{};
 uintptr_t times=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r4Time12sm_instancesE"),clock=r<uintptr_t>(times+8),registry=r<uintptr_t>(main+0xe6fd00);
 NSMutableDictionary *out=[@{@"pid":@(getpid()),@"frame":@(frame),@"onMain":@(NSThread.isMainThread),@"avatar":@(avatar),@"handle":@(r<uint32_t>(avatar+0x20)),@"position":@[@(pos.x),@(pos.y),@(pos.z)],@"ammo":@(ammo),@"minAmmo":@(minAmmo),@"money":@(r<uint64_t>(player+0x38)),@"skill":@(r<int>(player+0x40)),@"clockScale":@(r<float>(clock+0x44)),@"clockData":bytes(clock,160),@"health":@(r<float>(r<uintptr_t>(health+0x50)+0x94)),@"speed":@(r<float>(movement+0x2b4)),@"registryType":MHTControlType(registry),@"registry":@(registry)}mutableCopy];
 uintptr_t recipes=r<uintptr_t>(registry+0x628);uint32_t recipeCount=r<uint32_t>(registry+0x624);out[@"recipeCount"]=@(recipeCount);NSMutableArray *rr=[NSMutableArray new];if(recipeCount<=512)for(uint32_t i=0;i<recipeCount;i++){uintptr_t p=recipes+i*0x110;uint32_t count=r<uint32_t>(p+0xe8);uintptr_t ingredients=r<uintptr_t>(p+0xe0);[rr addObject:@{@"address":@(p),@"bytes":bytes(p,0x110),@"count":@(count),@"ingredients":count<=32?bytes(ingredients,count*32):@""}];}out[@"recipes"]=rr;
 uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE");void *map=(void*)r<uintptr_t>(global);auto resolve=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");
 NSMutableArray *items=[NSMutableArray new];uintptr_t list=r<uintptr_t>(inv+0x38);uint32_t n=r<uint32_t>(inv+0x40);if(n<=512&&map&&resolve)for(uint32_t i=0;i<n;i++){uint64_t gid=r<uint64_t>(list+i*16);uintptr_t p=(uintptr_t)resolve(map,&gid),stack=component(p,@"ItemStackComponentState"),loot=component(p,@"LootDropItemComponentState"),item=component(p,@"coregame::ItemComponentState");if(stack||loot)[items addObject:@{@"gid":@(gid),@"address":@(p),@"stack":@(stack),@"quantity":@(r<int>(stack+0x38)),@"loot":@(loot),@"template":@(r<uint64_t>(loot+0x38)),@"holder":@(r<uint32_t>(item+0x60))}];}out[@"items"]=items;
 NSMutableArray *npcs=[NSMutableArray new];std::set<uintptr_t> seen;uintptr_t node=avatar?avatar+0x38:0;for(int i=0;node&&i<4096;i++){if(!seen.insert(node).second)break;uintptr_t p=node-0x38;NSString *type=MHTControlType(p);if([type isEqual:@"GenericEntityState"]){uintptr_t a=component(p,@"ArmorComponentState"),h=component(p,@"GameHealthComponentState"),f=component(p,@"bonsai::FactionComponentState");if(a||h){NSMutableDictionary *npc=[@{@"address":@(p),@"gid":@(r<uint64_t>(p+0x10)),@"armor":@(a),@"health":@(h),@"faction":@(f),@"factionData":f?bytes(f,128):@""}mutableCopy];if(a){npc[@"armorData"]=bytes(a,192);npc[@"model"]=bytes(r<uintptr_t>(a+0x38),256);}[npcs addObject:npc];}}node=r<uintptr_t>(node+0x10);}out[@"npcs"]=npcs;out[@"objectsScanned"]=@(seen.size());
 // Additional bounded read-only diagnostics can be loaded without another game
 // restart. Keep their code mapped until process exit; never unload live callbacks.
 static NSString *lastName;static std::vector<void*> libraries;static NSDictionary *(*addon)(uintptr_t,uintptr_t,void*,uintptr_t);
 NSString *name=[[NSString stringWithContentsOfFile:@"/private/tmp/mht-control/Addon.txt" encoding:NSUTF8StringEncoding error:NULL]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 if(libraries.size()<8&&name.length<80&&[name hasPrefix:@"Addon-"]&&[name hasSuffix:@".dylib"]&&[name.lastPathComponent isEqual:name]&&![name isEqual:lastName]){lastName=[name copy];void *lib=dlopen([[@"/private/tmp/mht-control" stringByAppendingPathComponent:name]fileSystemRepresentation],RTLD_NOW|RTLD_LOCAL);if(lib){libraries.push_back(lib);addon=(NSDictionary*(*)(uintptr_t,uintptr_t,void*,uintptr_t))dlsym(lib,"MHTControlNativeDiagnostic");}}
 if(addon)out[@"addon"]=addon(core,main,server,avatar)?:@{};
 [[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:@"/private/tmp/mht-control/NativeState.json" options:NSDataWritingAtomic error:NULL];
}
