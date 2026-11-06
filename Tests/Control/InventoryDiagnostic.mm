// SPDX-License-Identifier: GPL-3.0-only
// Actual native recipe check before/after a reversible in-memory change.
#import "ControlEngine.h"
#import "ControlInventory.h"
#include <vector>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
extern "C" NSDictionary *MHTControlNativeDiagnostic(uintptr_t core,uintptr_t main,void *server,uintptr_t avatar){
 (void)core;(void)server;static NSDictionary *result;if(result||!avatar)return result;
 uintptr_t inv=0,list=r<uintptr_t>(avatar+0x60);uint32_t n=r<uint32_t>(avatar+0x68);if(n>128)return @{};
 for(uint32_t i=0;i<n;i++){uintptr_t c=r<uintptr_t>(list+i*8);if(r<uintptr_t>(c)==main+0xe0a6e0&&r<uintptr_t>(c+0x20)==avatar)inv=c;}if(!inv)return @{};
 uintptr_t registry=r<uintptr_t>(main+0xe6fd00),recipes=r<uintptr_t>(registry+0x628),ids=r<uintptr_t>(registry+0x630);if(r<uint32_t>(registry+0x624)!=72||!recipes||!ids)return @{};
 struct Resource {uint64_t id;uintptr_t cached;uint32_t generation;uint8_t lock;uint8_t padding[3];};
 Resource recipe{r<uint64_t>(ids),0,0,0,{}};
 auto query=(bool(*)(Resource*,void*))(main+0x4cc9f0);
 int cost=r<int>(recipes+0x108);uint32_t count=r<uint32_t>(recipes+0xe8);
 bool before=query(&recipe,nullptr);
 MHTControlInventory candidate;auto changed=candidate.update(avatar,inv,false,true);bool after=query(&recipe,nullptr);
 int changedCost=r<int>(recipes+0x108);uint32_t changedCount=r<uint32_t>(recipes+0xe8);
 candidate.release();bool restored=query(&recipe,nullptr);
 result=@{@"nativeBefore":@(before),@"nativeAfter":@(after),@"nativeRestored":@(restored),@"costBefore":@(cost),@"ingredientsBefore":@(count),@"costAfter":@(changedCost),@"ingredientsAfter":@(changedCount),@"costRestored":@(r<int>(recipes+0x108)),@"ingredientsRestored":@(r<uint32_t>(recipes+0xe8)),@"recipesAvailable":@(changed.recipesAvailable),@"craftActive":@(changed.craftActive),@"ownedMaterials":@(changed.materialCount),@"resolvedRecipe":@(recipe.cached==recipes)};return result;
}
