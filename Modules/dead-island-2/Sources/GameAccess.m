// SPDX-License-Identifier: GPL-3.0-only
#import "GameAccess.h"
#import "GameEdition.h"
#import <mach/mach.h>
#import <mach/mach_vm.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <math.h>

BOOL DI2ReadMemory(const void *address, void *result, size_t length) {
    if (!address || !result || !length) return NO;
    mach_vm_size_t actual = 0;
    return mach_vm_read_overwrite(mach_task_self(), (mach_vm_address_t)address, length,
        (mach_vm_address_t)result, &actual) == KERN_SUCCESS && actual == length;
}
static BOOL writeData(void *object, size_t offset, const void *bytes, size_t length) {
    if (!object || (uintptr_t)object > UINTPTR_MAX - offset) return NO;
    // Only an already writable data page is eligible. Never change protections.
    mach_vm_address_t address = (mach_vm_address_t)object + offset, region = address;
    mach_vm_size_t size = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t port = MACH_PORT_NULL;
    kern_return_t result = mach_vm_region(mach_task_self(), &region, &size,
        VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &port);
    if (port) mach_port_deallocate(mach_task_self(), port);
    if (result || region > address || length > size - (address - region) || !(info.protection & VM_PROT_WRITE)) return NO;
    return mach_vm_write(mach_task_self(), address, (vm_offset_t)bytes, (mach_msg_type_number_t)length) == KERN_SUCCESS;
}
BOOL DI2WriteByte(void *object, size_t offset, uint8_t value) { return writeData(object, offset, &value, 1); }
BOOL DI2WriteFloat(void *object, size_t offset, float value) { return isfinite(value) && writeData(object, offset, &value, sizeof(value)); }
BOOL DI2WriteInt(void *object, size_t offset, int32_t value) { return writeData(object, offset, &value, sizeof(value)); }
BOOL DI2WritePointer(void *object, size_t offset, void *value) { return writeData(object, offset, &value, sizeof(value)); }

BOOL DI2LoadGameAPI(DI2GameAPI *api) {
    memset(api, 0, sizeof(*api));
    const struct mach_header_64 *header = NULL;
    intptr_t slide = 0;
    // Inserted libraries can precede the executable in dyld's image array.
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header *candidate = _dyld_get_image_header(i);
        if (candidate && candidate->filetype == MH_EXECUTE) {
            header = (const void *)candidate;
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }
    if (!header || header->magic != MH_MAGIC_64 || header->cputype != CPU_TYPE_ARM64) return NO;
    BOOL matched = NO;
    uintptr_t cursor = (uintptr_t)(header + 1), end = cursor + header->sizeofcmds;
    for (uint32_t i = 0; i < header->ncmds && cursor + sizeof(struct load_command) <= end; i++) {
        const struct load_command *command = (const void *)cursor;
        if (command->cmdsize < sizeof(*command) || command->cmdsize > end - cursor) return NO;
        if (command->cmd == LC_UUID && command->cmdsize == sizeof(struct uuid_command))
            matched = DI2EditionForUUID(((const struct uuid_command *)command)->uuid)!=DI2EditionUnknown;
        cursor += command->cmdsize;
    }
    if (!matched) return NO;
    // Both allowlisted builds have byte-identical __text, __DATA_CONST,__const
    // and __DATA,__data sections. All 95 bindings are shared and checked on both.
    // No instruction hooks, code writes or executable allocations. Crafting uses
    // private per-instance dispatch tables; the native tables remain read-only.
#define BIND(field, address) api->field = (__typeof__(api->field))((uintptr_t)(address##ULL) + slide)
    BIND(world, 0x1073e9de8); // GWorld
    BIND(gameThreadCall, 0x102b02e64); // GameThreadCall(block, NSArray*, bool)
    BIND(playerCharacter, 0x1044e0170); // UGameplayStatics::GetPlayerCharacter
    BIND(standalone, 0x1045c503c); // UKismetSystemLibrary::IsStandalone
    BIND(valid, 0x102d92c98); // UObjectBase::IsValidLowLevelFast
    BIND(classIsChildOf, 0x1045b7950); // UKismetMathLibrary::ClassIsChildOf
    BIND(playerClass, 0x1024b8e88); // ADIPlayerCharacter::StaticClass
    BIND(inventoryClass, 0x1024988f0); // UDIInventoryComponent::StaticClass
    BIND(healthClass, 0x102769ca8); // USimpleHealthComponent::StaticClass
    BIND(staminaClass, 0x10280c484); // UPlayerStaminaComponent::StaticClass
    BIND(physicalSlotClass, 0x1027ded2c); // UPhysicalSlot::StaticClass (held main-hand slot, not UPaperDollSlot)
    BIND(equippableClass, 0x10248ce74); // UEquippableComponent::StaticClass
    BIND(rangedClass, 0x102855b98); // ARangedWeaponItemActor::StaticClass
    BIND(modulesClass, 0x10285bb3c); // URangedWeaponModulesComponent::StaticClass
    BIND(clipClass, 0x10238c018); // UClipAmmoHandlerBase::StaticClass
    BIND(component, 0x1041bce18); // AActor::GetComponentByClass
    BIND(inventory, 0x101e896cc); // ADIPlayerCharacter::GetInventory
    BIND(count, 0x105129ec4); // UInventoryComponent::GetItemArchetypeCount
    BIND(addCash, 0x101d7ff4c); // UDIInventoryComponent::AddCash (returns actual amount)
    BIND(name, 0x102bdb344); // FName::FName(char16_t const*, EFindName)
    BIND(addGod, 0x1018003cc); // USimpleHealthComponent::AddGodModeReason
    BIND(removeGod, 0x1018003f8); // USimpleHealthComponent::RemoveGodModeReason
    BIND(fillHealth, 0x1017ffe24); // USimpleHealthComponent::SetHealthAsFraction
    BIND(stamina, 0x101c82024); // UStaminaComponent::GetStamina
    BIND(maxStamina, 0x101c853e4); // UStaminaComponent::GetMaxStamina
    BIND(setStamina, 0x101c84014); // UStaminaComponent::SetStamina
    BIND(weakAssign, 0x102dba090); // FWeakObjectPtr::operator=(UObject const*)
    BIND(weakGet, 0x102dba274); // FWeakObjectPtr::Get
    BIND(ammoHandler, 0x101c3a5a4); // URangedWeaponModulesComponent::GetSelectedAmmoHandler
    BIND(ammo, 0x101c49b28); // UClipAmmoHandlerBase::GetCurrentAmmo
    BIND(capacity, 0x101c49b68); // UClipAmmoHandlerBase::GetAmmoCapacity
    BIND(setAmmo, 0x101c4a578); // UClipAmmoHandlerBase::RequestSetAmmo
    BIND(playerController, 0x1044dfffc); // __ZN16UGameplayStatics19GetPlayerControllerEPK7UObjecti
    BIND(meleeClass, 0x1026e88d4); // __ZN21AMeleeWeaponItemActor11StaticClassEv
    BIND(meleeAttributesClass, 0x1026e581c); // __ZN31UMeleeWeaponAttributesComponent11StaticClassEv
    BIND(attributeClass, 0x10236fd00); // __ZN18UAttributeInstance11StaticClassEv
    BIND(damageableClass, 0x10245bfa8); // __ZN20UDamageableComponent11StaticClassEv
    BIND(furyClass, 0x10252b47c); // __ZN20UFuryValuesComponent11StaticClassEv
    BIND(throwClass, 0x1028497d4); // __ZN24UQuickThrowSlotComponent11StaticClassEv
    BIND(progressionClass, 0x102806a24); // __ZN27UPlayerProgressionComponent11StaticClassEv
    BIND(levelsClass, 0x1028076fc); // __ZN24UPlayerProgressionLevels11StaticClassEv
    BIND(spreadClass, 0x1028aba04); // __ZN22UStandardSpreadHandler11StaticClassEv
    BIND(recoilClass, 0x10285e548); // __ZN22UStandardRecoilHandler11StaticClassEv
    BIND(addDurability, 0x101dddec8); // __ZN21AMeleeWeaponItemActor27AddInfiniteDurabilityReasonE5FName
    BIND(removeDurability, 0x101dddef4); // __ZN21AMeleeWeaponItemActor30RemoveInfiniteDurabilityReasonE5FName
    BIND(repair, 0x101ddcf70); // __ZN21AMeleeWeaponItemActor34AuthoritySetCurrentDurabilityToMaxEv
    BIND(durabilityLoss, 0x101dd7a58); // AMeleeWeaponItemActor::DurabilityLossPerHit
    BIND(setIncomingDamage, 0x1017e1fd0); // __ZN20UDamageableComponent25SetGlobalDamageMultiplierEf
    BIND(getGameSpeed, 0x1044e059c); // __ZN16UGameplayStatics21GetGlobalTimeDilationEPK7UObject
    BIND(setGameSpeed, 0x1044e05e4); // __ZN16UGameplayStatics21SetGlobalTimeDilationEPK7UObjectf
    BIND(damageAttribute, 0x101b9217c); // __ZN31UMeleeWeaponAttributesComponent26GetDamageAttributeInstanceEv
    BIND(forceAttribute, 0x101b921cc); // __ZN31UMeleeWeaponAttributesComponent25GetForceAttributeInstanceEv
    BIND(getAttribute, 0x10168d36c); // __ZNK18UAttributeInstance18GetCurrentRawValueEv
    BIND(setAttribute, 0x10168d374); // __ZN18UAttributeInstance18SetCurrentRawValueEf
    BIND(spreadHandler, 0x101c3e5a0); // __ZNK29URangedWeaponModulesComponent24GetSelectedSpreadHandlerEv
    BIND(recoilHandler, 0x101c3fda8); // __ZNK29URangedWeaponModulesComponent24GetSelectedRecoilHandlerEv
    BIND(resetCurveballs, 0x101c334d0); // __ZN24UQuickThrowSlotComponent17ResetAllCooldownsEv
    BIND(setInfiniteFury, 0x101ec69a0); // __ZN20UFuryValuesComponent38ServerSetIsInfiniteFury_ImplementationEb
    BIND(getFury, 0x101ec5220); // __ZN20UFuryValuesComponent14GetCurrentFuryEv
    BIND(addFury, 0x101ec6468); // __ZN20UFuryValuesComponent13IncrementFuryEfP15UFuryGainSource
    BIND(removeCash, 0x101d8008c); // __ZN21UDIInventoryComponent10RemoveCashEi
    BIND(getXP, 0x101ef4d10); // __ZNK27UPlayerProgressionComponent5GetXPEv
    BIND(getLevel, 0x10223eb80); // __ZNK27UPlayerProgressionComponent8GetLevelEv
    BIND(maxLevel, 0x101ef5dc0); // __ZNK27UPlayerProgressionComponent11GetMaxLevelEv
    BIND(xpForLevel, 0x101ef4ea0); // __ZNK24UPlayerProgressionLevels13GetXPForLevelEi
    BIND(addXP, 0x101ef53a0); // __ZN27UPlayerProgressionComponent5AddXPEi5FName
    BIND(ignorePlayers, 0x1072c07b0);
    BIND(aiManager, 0x101537a78);
    BIND(aiManagerClass, 0x10237256c);
    BIND(playerStateClass, 0x104c959ec);
    BIND(updateIgnorePlayers, 0x101538e3c);
    BIND(setIgnorePlayer, 0x101538498);
    BIND(modifiableClass, 0x102750614);
    BIND(movementDefinitionClass, 0x102754d6c);
    BIND(currentMovementValue, 0x1022ad950);
    BIND(addMovementModifier, 0x1022ac198);
    BIND(removeMovementModifier, 0x1022abc1c);
    BIND(updateMovementModifier, 0x1022ae5f4);
    BIND(containerClass, 0x102497d88);
    BIND(categoryClass, 0x1051e3260);
    BIND(itemActorClass, 0x1024680d8);
    BIND(archetypeClass, 0x102467ef0);
    BIND(nameString, 0x102bdcdc0);
    BIND(addItem, 0x1051270c8);
    BIND(recipeClass, 0x102458eac);
    BIND(ingredientsClass, 0x1024588c8);
    BIND(objectsOfClass, 0x102db5da4);
    BIND(freeMemory, 0x102a57e08);
    BIND(zeroCraftingCost, 0x10245c674);
    BIND(controllerClass, 0x101312b4c);
    BIND(localPlayerClass, 0x104c0d390);
    BIND(viewportClass, 0x104b1bda8);
    BIND(worldViewport, 0x104a800c0);
    BIND(inputUIOnly, 0x103f46018);
    BIND(inputGameOnly, 0x103f4654c);
    api->ingredientVTables[0]=(void *)(0x1065321d0ULL+16+slide);
    api->ingredientVTables[1]=(void *)(0x1065324b8ULL+16+slide);
    api->ingredientVTables[2]=(void *)(0x1066a1c28ULL+16+slide);
#undef BIND
    return YES;
}
