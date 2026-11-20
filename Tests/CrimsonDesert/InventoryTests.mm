// SPDX-License-Identifier: GPL-3.0-only
// Real product lookup against synthetic inventory memory; no game or effects.
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <vector>
#include <array>
#include <type_traits>
static unsigned buildNumber=466;
static uint16_t moneyInventory=3;
static uint16_t moneyInventoryFor(){return moneyInventory;}
static uint16_t legacyInventoryFor(void *,uint16_t,uint8_t){return 1;}
using Bytes=std::array<uint8_t,256>;
static Bytes component{},infos{},bagA{},bagB{},itemA{},itemB{};
static std::vector<void *> bags,itemsA,itemsB;
template<typename T> static T read(const void *p,size_t offset=0){T value{};memcpy(&value,(const uint8_t *)p+offset,sizeof(value));return value;}
template<typename T> static void put(Bytes &b,size_t offset,T value){memcpy(b.data()+offset,&value,sizeof(value));}
static void *componentFor(void *){return component.data();}
static void *inventoryFor(void *,unsigned i){return bags.at(i);}
static void *itemFor(void *bag,int16_t slot){return (bag==bagA.data()?itemsA:itemsB).at(slot);}
static bool valid(const void *item){return read<uint64_t>(item)!=UINT64_MAX;}
static void *infoFor(uint16_t type){if(type!=6)abort();return infos.data();}
template<typename T> static T native(uintptr_t key){
    if constexpr(std::is_same_v<T,decltype(&componentFor)>){if(key!=0x1d3367c)abort();return componentFor;}
    else if constexpr(std::is_same_v<T,decltype(&inventoryFor)>){if(key!=0x1d34850)abort();return inventoryFor;}
    else if constexpr(std::is_same_v<T,decltype(&itemFor)>){if(key!=0x1a6a66c)abort();return itemFor;}
    else if constexpr(std::is_same_v<T,decltype(&valid)>){if(key!=0x1a71ae8)abort();return valid;}
    else if constexpr(std::is_same_v<T,decltype(&infoFor)>){if(key!=0x1b38c48)abort();return infoFor;}
    else if constexpr(std::is_same_v<T,decltype(&moneyInventoryFor)>){if(key!=0x195676c)abort();return moneyInventoryFor;}
    else if constexpr(std::is_same_v<T,decltype(&legacyInventoryFor)>){if(key!=0xf56b88 || buildNumber!=450)abort();return legacyInventoryFor;}
    else static_assert(!sizeof(T),"Unbound native signature; crashing helper must never run.");
}
#include "../../Modules/crimson-desert/Sources/CrimsonItemLookup.h"
static void require(bool value){if(!value)abort();}
int main(){
    bags={bagA.data(),bagB.data()};itemsA={itemA.data()};itemsB={itemB.data()};
    put<uint32_t>(component,0x20,2);put<int16_t>(bagA,8,1);put<int16_t>(bagB,8,1);
    put<uint16_t>(bagA,0x10,7);put<uint16_t>(bagB,0x10,1);
    put<uint64_t>(itemA,0,100);put<uint64_t>(itemB,0,200);
    put<uint16_t>(itemA,8,50);put<uint16_t>(itemB,8,42);put<int64_t>(itemB,0x10,125);
    put<uint16_t>(infos,0xc8,42);put<uint16_t>(infos,0xf0,42);
    ItemBinding binding;require(walletItem(nullptr,binding)==itemB.data() && binding.inventory==1 && binding.count==125);
    buildNumber=476;binding={};require(walletItem(nullptr,binding)==itemB.data() && binding.inventory==1 && binding.count==125);
    ItemBinding previous=binding;put<uint64_t>(itemB,0,201);require(!findBoundItem(nullptr,binding,true));require(binding.number==previous.number);
    put<uint64_t>(itemB,0,200);put<uint16_t>(itemA,8,42);binding={};require(walletItem(nullptr,binding)==itemB.data());
    ItemBinding wildcard;wildcard.info=42;require(!findBoundItem(nullptr,wildcard,false));
    itemsB.push_back(itemA.data());put<int16_t>(bagB,8,2);binding={};require(!walletItem(nullptr,binding) && binding.number==UINT64_MAX);
    itemsB.pop_back();put<int16_t>(bagB,8,1);
    moneyInventory=4;binding={};require(!walletItem(nullptr,binding));moneyInventory=3;
    put<uint16_t>(itemA,8,50);buildNumber=450;binding={};require(walletItem(nullptr,binding)==itemB.data());
    put<int16_t>(bagB,8,-1);binding={};require(!walletItem(nullptr,binding));
    put<int16_t>(bagB,8,4097);binding={};require(!walletItem(nullptr,binding));
    put<uint32_t>(component,0x20,129);binding={};require(!walletItem(nullptr,binding));
    puts("PASS: real wallet lookup, all three builds, separate bank money, ambiguous targets, owner/item change, corrupt bounds; removed helper unreachable.");
}
