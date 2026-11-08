// SPDX-License-Identifier: GPL-3.0-only
// Real inventory implementation, with test-only bounded memory. No game starts.
#import <Foundation/Foundation.h>
#include <vector>
#define MHTControlRead InventoryRead
#define MHTControlWrite InventoryWrite
#define MHTControlAddress InventoryAddress
#define MHTControlOnEngineFrame InventoryFrame
#define MHTControlEngineIdentity InventoryIdentity
#define MHTControlType InventoryType
#define MHTControlInventory InventoryPerformanceImplementation
#import "../../Modules/control/Sources/ControlInventory.mm"
#undef MHTControlInventory
#undef MHTControlRead
#undef MHTControlWrite
#undef MHTControlAddress
#undef MHTControlOnEngineFrame
#undef MHTControlEngineIdentity
#undef MHTControlType
static size_t reads,writes,queries;
static std::vector<std::pair<uintptr_t,size_t>> ranges;
static uintptr_t registrySlot;
BOOL InventoryRead(uintptr_t p,void *out,size_t n){reads++;for(auto range:ranges)if(p>=range.first&&p-range.first<=range.second&&n<=range.second-(p-range.first)){memcpy(out,(void*)p,n);return YES;}memset(out,0,n);return NO;}
BOOL InventoryWrite(uintptr_t p,const void *bytes,size_t n){writes++;for(auto range:ranges)if(p>=range.first&&p-range.first<=range.second&&n<=range.second-(p-range.first)){memcpy((void*)p,bytes,n);return YES;}return NO;}
uintptr_t InventoryAddress(MHTControlSymbol s){queries++;return s==MHTControlDatabase?(uintptr_t)&registrySlot:0;}
BOOL InventoryFrame(void){queries++;return YES;}
BOOL InventoryIdentity(void){queries++;return YES;}
NSString *InventoryType(uintptr_t p){(void)p;return @"";}
template<class T>static void put(std::vector<uint8_t>&v,size_t offset,T value){memcpy(v.data()+offset,&value,sizeof(value));}
static void check(bool okay,const char *why){if(!okay){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
int main(){@autoreleasepool{
 InventoryPerformanceImplementation inventory;
 for(unsigned i=0;i<20000;i++)inventory.update(1,2,false,false,false);
 check(!reads&&!writes&&!queries,"idle frame path performs no native inventory or recipe queries");
 std::vector<uint8_t> registry(0x640),recipes(72*0x110),ingredients(72*32);
 registrySlot=(uintptr_t)registry.data();
 ranges={{(uintptr_t)&registrySlot,sizeof(registrySlot)},{registrySlot,registry.size()},
   {(uintptr_t)recipes.data(),recipes.size()},{(uintptr_t)ingredients.data(),ingredients.size()}};
 put(registry,0x624,uint32_t(72));put(registry,0x628,(uintptr_t)recipes.data());
 for(unsigned i=0;i<72;i++){put(recipes,i*0x110+0xe0,(uintptr_t)ingredients.data()+i*32);put(recipes,i*0x110+0xe8,uint32_t(1));put(recipes,i*0x110+0x108,int(10));put(ingredients,i*32,uint64_t(i+1));put(ingredients,i*32+0x18,int(1));}
 auto first=inventory.update(1,2,false,true,false);
 check(first.recipesAvailable&&first.craftActive&&writes==144,"first craft enable validates and changes the 72 original recipe pairs");
 reads=writes=0;
 for(unsigned i=0;i<200;i++)check(inventory.update(1,2,false,true,false).craftActive,"active recipe values stay validated");
 check(!writes&&reads==200*(72+3),"unchanged recipes use exactly one bounded snapshot each plus three registry reads, with no redundant readbacks or writes");
 inventory.update(1,2,false,false,false);check(writes==144,"off transition restores every own recipe pair");
 for(unsigned i=0;i<72;i++){uint32_t count=0;int cost=0;memcpy(&count,recipes.data()+i*0x110+0xe8,4);memcpy(&cost,recipes.data()+i*0x110+0x108,4);check(count==1&&cost==10,"exact recipe baseline restored");}
 check(inventory.update(1,2,false,true,false).craftActive,"second lease acquires valid recipes");
 put(recipes,0xe0,(uintptr_t)ingredients.data()+32);put(recipes,0xe8,uint32_t(5));put(recipes,0x108,int(17));
 writes=0;check(!inventory.update(1,2,false,true,false).craftActive&&!writes,"a changed ingredient owner invalidates confirmation without touching foreign recipe fields");
 inventory.update(1,2,false,false,false);uint32_t foreignCount=0;int foreignCost=0;
 memcpy(&foreignCount,recipes.data()+0xe8,4);memcpy(&foreignCost,recipes.data()+0x108,4);
 check(writes==142&&foreignCount==5&&foreignCost==17,"off restores the 71 still-owned pairs and preserves the changed foreign recipe");
 reads=writes=queries=0;
 for(unsigned i=0;i<20000;i++)inventory.update(1,2,false,false,false);
 check(!reads&&!writes&&!queries,"idle native work remains zero after release");
 puts("PASS: real Control inventory: 40,000 idle frames do zero native work; recipe discovery, conditional active writes and complete owned restoration. Synthetic only.");
}}
