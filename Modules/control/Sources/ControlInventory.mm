// SPDX-License-Identifier: GPL-3.0-only
#import "ControlInventory.h"
#import "ControlEngine.h"
#include <dlfcn.h>
#include <map>
#include <set>
#include <vector>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static uintptr_t component(uintptr_t owner,uintptr_t vtable){
    uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t count=r<uint32_t>(owner+0x68);
    if(count>128)return 0;
    for(uint32_t i=0;i<count;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c)==vtable&&r<uintptr_t>(c+0x20)==owner)return c;}
    return 0;
}
struct Recipe {uintptr_t address,ingredients;uint32_t count;int cost;};
struct Stack {uint64_t gid;uintptr_t item,component,holder;uint32_t ownerHandle;int original,last;};
struct MHTControlInventory::State {
    uintptr_t registry=0,array=0;
    std::vector<Recipe> recipes;
    std::set<uint64_t> ingredients;
    std::map<uint64_t,Stack> stacks;
    bool crafting=false;
};
MHTControlInventory::MHTControlInventory():state(new State){}
MHTControlInventory::~MHTControlInventory()=default;
// All content edits are bounded to the captured registry/array. A load may have
// freed an old content owner; those addresses must never be restored blindly.
void MHTControlInventory::release(){
    if(!MHTControlOnEngineFrame())return;
    auto &s=*state;
    bool same=r<uintptr_t>(MHTControlAddress(MHTControlDatabase))==s.registry
        &&r<uintptr_t>(s.registry+0x628)==s.array&&r<uint32_t>(s.registry+0x624)==s.recipes.size();
    if(s.crafting&&same)for(const Recipe &recipe:s.recipes){
        if(r<uintptr_t>(recipe.address+0xe0)!=recipe.ingredients)continue;
        if(r<int>(recipe.address+0x108)==0)MHTControlWrite(recipe.address+0x108,&recipe.cost,4);
        if(r<uint32_t>(recipe.address+0xe8)==0)MHTControlWrite(recipe.address+0xe8,&recipe.count,4);
    }
    s.crafting=false;
    // Restore stacks only while their exact live GlobalID owner still resolves.
    uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE");
    auto resolve=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");
    void *map=(void*)r<uintptr_t>(global);
    if(map&&resolve)for(const auto &entry:s.stacks){const Stack &v=entry.second;uintptr_t item=(uintptr_t)resolve(map,&v.gid);
        if(item==v.item&&component(item,MHTControlAddress(MHTControlStackVT))==v.component
            &&r<uintptr_t>(v.holder+0x20)==item&&[MHTControlType(v.holder)isEqual:@"coregame::ItemComponentState"]
            &&r<uint32_t>(v.holder+0x60)==v.ownerHandle&&r<int>(v.component+0x38)==v.last)
            MHTControlWrite(v.component+0x38,&v.original,4);
    }
    s.stacks.clear();
}
void MHTControlInventory::discardOwner(){
    // Avatar stacks can already be gone. Registry content has a separate owner.
    state->stacks.clear();release();
}
MHTControlInventoryResult MHTControlInventory::update(uintptr_t avatar,uintptr_t inventory,bool materials,bool freeCraft){
    MHTControlInventoryResult result;if(!MHTControlOnEngineFrame()||!MHTControlEngineIdentity()||!avatar||!inventory)return result;
    auto &s=*state;uintptr_t registry=r<uintptr_t>(MHTControlAddress(MHTControlDatabase)),array=r<uintptr_t>(registry+0x628);uint32_t count=r<uint32_t>(registry+0x624);
    if(registry!=s.registry||array!=s.array||count!=s.recipes.size()){
        release();s.recipes.clear();s.ingredients.clear();s.registry=registry;s.array=array;
        if(count!=72||!array)return result; // All pinned signed store builds have 72 recipes.
        for(uint32_t i=0;i<count;i++){
            uintptr_t p=array+i*0x110,list=r<uintptr_t>(p+0xe0);uint32_t n=r<uint32_t>(p+0xe8);int cost=r<int>(p+0x108);
            if(n>32||cost<0||cost>999999999){s.recipes.clear();s.ingredients.clear();return result;}
            std::vector<uint8_t> bytes(n*32);if(n&&!MHTControlRead(list,bytes.data(),bytes.size())){s.recipes.clear();s.ingredients.clear();return result;}
            for(uint32_t j=0;j<n;j++){uint64_t id=r<uint64_t>(list+j*32);int amount=r<int>(list+j*32+0x18);if(id&&amount>0&&amount<=999999)s.ingredients.insert(id);}
            s.recipes.push_back({p,list,n,cost});
        }
    }
    result.recipesAvailable=s.recipes.size()==72&&!s.ingredients.empty();if(!result.recipesAvailable)return result;
    if(freeCraft){bool ok=true;const uint32_t zero=0;for(const Recipe &recipe:s.recipes){
        if(r<uintptr_t>(recipe.address+0xe0)!=recipe.ingredients){ok=false;continue;}
        ok&=MHTControlWrite(recipe.address+0x108,&zero,4)&&MHTControlWrite(recipe.address+0xe8,&zero,4)
            &&r<int>(recipe.address+0x108)==0&&r<uint32_t>(recipe.address+0xe8)==0;
    }s.crafting=true;result.craftActive=ok;}
    else if(s.crafting)release();
    uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE");void *map=(void*)r<uintptr_t>(global);
    auto resolve=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");
    uintptr_t list=r<uintptr_t>(inventory+0x38);uint32_t n=r<uint32_t>(inventory+0x40),handle=r<uint32_t>(avatar+0x20);
    if(!map||!resolve||n>4096)return result;
    std::set<uint64_t> live;bool materialOK=true;
    for(uint32_t i=0;i<n;i++){
        uint64_t gid=r<uint64_t>(list+i*16);uintptr_t item=(uintptr_t)resolve(map,&gid);
        uintptr_t stack=component(item,MHTControlAddress(MHTControlStackVT)),loot=component(item,MHTControlAddress(MHTControlLootVT));
        if(!stack||!loot||!s.ingredients.count(r<uint64_t>(loot+0x38)))continue;
        // ItemComponentState::getHolder() is the native owner handle at +0x60.
        uintptr_t holder=0,components=r<uintptr_t>(item+0x60);uint32_t cn=r<uint32_t>(item+0x68);
        if(cn<=128)for(uint32_t j=0;j<cn;j++){uintptr_t c=r<uintptr_t>(components+8*j);if(r<uintptr_t>(c+0x20)==item&&[MHTControlType(c)isEqual:@"coregame::ItemComponentState"]){holder=c;break;}}
        int amount=r<int>(stack+0x38);if(!holder||r<uint32_t>(holder+0x60)!=handle||amount<0||amount>999999999)continue;
        result.materialCount++;live.insert(gid);
        if(materials){auto it=s.stacks.find(gid);if(it!=s.stacks.end()&&(it->second.item!=item||it->second.component!=stack||it->second.holder!=holder||it->second.ownerHandle!=handle)){s.stacks.erase(it);it=s.stacks.end();}
            if(it==s.stacks.end())it=s.stacks.emplace(gid,Stack{gid,item,stack,holder,handle,amount,amount}).first;
            int target=MAX(amount,999);materialOK&=MHTControlWrite(stack+0x38,&target,4)&&r<int>(stack+0x38)==target;it->second.last=target;
        }else{auto it=s.stacks.find(gid);if(it!=s.stacks.end()){if(amount==it->second.last)MHTControlWrite(stack+0x38,&it->second.original,4);s.stacks.erase(it);}}
    }
    for(auto it=s.stacks.begin();it!=s.stacks.end();)if(!live.count(it->first))it=s.stacks.erase(it);else ++it;
    result.materialsActive=materials&&result.materialCount&&materialOK;return result;
}
