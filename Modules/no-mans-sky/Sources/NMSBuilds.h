// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#include <stdint.h>

// Original arm64 identities only. Keys refer to the first supported build;
// every new entry was resolved independently in the corresponding original.
static NSString *const MTNMSOriginalUUID=@"1FABCC98-D6B6-3905-BF1B-823BD5033DA9";
static NSString *const MTNMSUpdatedUUID=@"90ACDF11-4B80-34A5-B802-4F09782742CF";
typedef struct {
    uintptr_t original,updated;
    const char *symbol; // nm spelling; vtable points past the two ABI header words.
    NSUInteger symbolOffset;
} MTNMSNativeBinding;
static const MTNMSNativeBinding MTNMSNativeBindings[]={
    {0x103140dc0,0x103142ee8,"__ZN21cTkInputDeviceManager9LockMouseEv",0},
    {0x103140de0,0x103142f08,"__ZN21cTkInputDeviceManager11UnlockMouseEv",0},
    {0x10035c6b0,0x10035c9c4,"__ZN14cGcPlayerState28GetPrimaryItemForStatForEditE10eStatsType16eInventoryChoice14ItemLookupTypei",0},
    {0x10035cb0c,0x10035ce20,"__ZN14cGcPlayerState26CommitInventoryElementEditERK21sInventoryElementEdit",0},
    {0x100df7834,0x100df882c,"__ZN15cGcPlayerWeapon23GetInventoryItemForEditE11eWeaponMode",0},
    {0x100df7620,0x100df8618,"__ZNK15cGcPlayerWeapon11GetClipSizeEv",0},
    {0x1003539f8,0x100353d0c,"__ZNK15cGcPlayerWeapon7GetAmmoE11eWeaponMode",0},
    {0x10034f4a8,0x10034f7bc,"__ZN15cGcPlayerWeapon7SetAmmoE11eWeaponModei",0},
    {0x10032589c,0x100325bb0,"__ZNK18cGcPlayerInventory9GetHandleE16eInventoryChoicei",0},
    {0x100325b74,0x100325e88,"__ZN18cGcPlayerInventory17GetStoreWriteableERK18cGcInventoryHandle",0},
    {0x1003393a8,0x1003396bc,"__ZN17cGcInventoryStore20GetElementForEditingERK17cGcInventoryIndex",0},
    {0x1002be0dc,0x1002be584,"__ZNK17cGcInventoryStore17GetSlotMaxStorageERK19cGcInventoryElement",0},
    {0x10032648c,0x1003267a0,"__ZN18cGcPlayerInventory19SetInventoryElementERK18cGcInventoryHandleRK19cGcInventoryElement",0},
    {0x10035cc08,0x10035cf1c,"__ZNK14cGcPlayerState16GetMaximumShieldE16eInventoryChoice",0},
    {0x100e1f880,0x100e2082c,"__ZNK9cGcPlayer18GetJetpackTankSizeEv",0},
    {0x10035c390,0x10035c6a4,"__ZNK14cGcPlayerState20GetMaximumShipHealthEv",0},
    {0x100995e04,0x100996a64,"__ZNK17cGcRealityManager14LookUpCostByIDERK4TkIDILm128EE",0},
    {0x101f04670,0x101f05b50,"__ZN14cGcCostProduct4CastERK15cTkClassPointer",0},
    {0x10024826c,0x1002484f8,"__ZNK21cGcDifficultySettings14IsCraftingFreeEv",0},
    {0x102f1ec38,0x102f20b78,"-[MetalKitApplication update]",0},
    {0x10143dc08,0x10143ef78,"-[GainputMacInputView SetMouseCapture:]",0},
    {0x103d8f518,0x103d8f708,"__ZL12pInputSystem",0},
    {0x103697768,0x1036978b8,"__ZTV21cTkInputDeviceManager",16},
};
static inline BOOL MTNMSBuildUUIDSupported(NSString *uuid){
    return [uuid isEqual:MTNMSOriginalUUID] || [uuid isEqual:MTNMSUpdatedUUID];
}
static inline uintptr_t MTNMSPreferredAddress(NSString *uuid,uintptr_t key){
    if(!MTNMSBuildUUIDSupported(uuid))return 0;
    for(NSUInteger i=0;i<sizeof(MTNMSNativeBindings)/sizeof(*MTNMSNativeBindings);i++){
        const MTNMSNativeBinding *binding=&MTNMSNativeBindings[i];
        if(binding->original==key)return [uuid isEqual:MTNMSUpdatedUUID] ? binding->updated : binding->original;
    }
    return 0; // Never reuse another build's address for an unknown binding.
}
