// SPDX-License-Identifier: GPL-3.0-only
// Read-only enumeration of actual loaded loot objects. Never product-linked.
#import "ControlEngine.h"
#include <set>
#include <dlfcn.h>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static uintptr_t component(uintptr_t owner,uintptr_t vt){uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t n=r<uint32_t>(owner+0x68);if(n<=128)for(uint32_t i=0;i<n;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c)==vt&&r<uintptr_t>(c+0x20)==owner)return c;}return 0;}
extern "C" NSDictionary *MHTControlNativeDiagnostic(uintptr_t core,uintptr_t main,void *server,uintptr_t avatar){
 (void)core;(void)server;
 std::set<uint64_t> ingredients;uintptr_t registry=r<uintptr_t>(main+0xe6fd00),recipes=r<uintptr_t>(registry+0x628);uint32_t count=r<uint32_t>(registry+0x624);
 if(count==72)for(uint32_t i=0;i<count;i++){uintptr_t recipe=recipes+i*0x110,list=r<uintptr_t>(recipe+0xe0);uint32_t n=r<uint32_t>(recipe+0xe8);if(n<=32)for(uint32_t j=0;j<n;j++)ingredients.insert(r<uint64_t>(list+j*32));}
 std::set<uintptr_t> seen;uintptr_t node=avatar?avatar+0x38:0;NSMutableArray *items=[NSMutableArray new];unsigned stacks=0,lootCount=0;
 for(unsigned i=0;node&&i<16384;i++){
  if(!seen.insert(node).second)break;uintptr_t object=node-0x38;node=r<uintptr_t>(node+0x10);
  uintptr_t stack=component(object,main+0xe190e8),loot=component(object,main+0xe1e900);stacks+=stack!=0;lootCount+=loot!=0;
  if(!stack||!loot)continue;uint64_t id=r<uint64_t>(loot+0x38);uintptr_t holder=0,list=r<uintptr_t>(object+0x60);uint32_t n=r<uint32_t>(object+0x68);
  if(n<=128)for(uint32_t j=0;j<n;j++){uintptr_t c=r<uintptr_t>(list+8*j);if(r<uintptr_t>(c+0x20)==object&&[MHTControlType(c)isEqual:@"coregame::ItemComponentState"]){holder=c;break;}}
  [items addObject:@{@"gid":@(r<uint64_t>(object+0x10)),@"object":@(object),@"template":@(id),@"recipeIngredient":@(ingredients.count(id)!=0),@"amount":@(r<int>(stack+0x38)),@"holder":@(r<uint32_t>(holder+0x60))}];
 }
 return @{@"scanned":@(seen.size()),@"stacks":@(stacks),@"lootCount":@(lootCount),@"items":items,@"avatarHandle":@(r<uint32_t>(avatar+0x20))};
}
