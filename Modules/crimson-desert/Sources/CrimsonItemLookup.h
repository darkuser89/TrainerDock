// SPDX-License-Identifier: GPL-3.0-only
// Private implementation; included inside CrimsonNative.mm's binding namespace.
#pragma once
struct ItemBinding {uint16_t inventory=UINT16_MAX,info=UINT16_MAX;int16_t slot=-1;uint64_t number=UINT64_MAX;int64_t count=0;};
void *inventoryComponent(void *actor) {return native<void *(*)(void *)>(0x1d3367c)(actor);}
void *findBoundItem(void *actor,ItemBinding &binding,bool searchNumber) {
    void *component=inventoryComponent(actor);if(!component)return nullptr;
    unsigned inventories=read<uint32_t>(component,0x20);if(inventories>128)return nullptr;
    const ItemBinding requested=binding;ItemBinding found;void *foundItem=nullptr;
    for(unsigned i=0;i<inventories;i++) {
        void *inventory=native<void *(*)(void *,unsigned)>(0x1d34850)(component,i);if(!inventory)continue;
        uint16_t index=read<uint16_t>(inventory,0x10);
        if(requested.inventory!=UINT16_MAX && requested.inventory!=index)continue;
        int slots=read<int16_t>(inventory,8);if(slots<0 || slots>4096)return nullptr;
        for(int slot=0;slot<slots;slot++) {
            void *item=native<void *(*)(void *,int16_t)>(0x1a6a66c)(inventory,slot);
            if(!item || !native<bool(*)(const void *)>(0x1a71ae8)(item))continue;
            if(requested.info!=UINT16_MAX && read<uint16_t>(item,8)!=requested.info)continue;
            uint64_t number=read<uint64_t>(item);
            if(!number || number==UINT64_MAX)continue;
            if(searchNumber && number!=requested.number)continue;
            if(foundItem)return nullptr; // Reject ambiguity across ALL inventories.
            found={index,read<uint16_t>(item,8),(int16_t)slot,number,read<int64_t>(item,0x10)};
            foundItem=item;
        }
    }
    if(foundItem)binding=found;
    return foundItem;
}
void *walletItem(void *actor,ItemBinding &binding) {
    void *infos=native<void *(*)(uint16_t)>(0x1b38c48)(6);
    if(!infos)return nullptr;
    binding.info=read<uint16_t>(infos,buildNumber==450 ? 0xf0 : 0xc8);
    if(binding.info==UINT16_MAX)return nullptr;
    if(buildNumber==466 || buildNumber==476) {
        // The metadata getter returns an inventory KIND (3), not an index.
        // The original dispatcher at 0x1a80ee0 maps that kind to bag index 1;
        // its branch and output store are pinned by CDEntryChecks466.
        if(native<uint16_t(*)()>(0x195676c)()!=3)return nullptr;
        binding.inventory=1;
    } else {
        // Preserve the already verified 450 resolver and its original ABI.
        binding.inventory=native<uint16_t(*)(void *,uint16_t,uint8_t)>(0xf56b88)(actor,binding.info,0);
    }
    if(binding.inventory==UINT16_MAX)return nullptr;
    return findBoundItem(actor,binding,false);
}
