// SPDX-License-Identifier: GPL-3.0-only
#import "MemoryAccess.h"
#import <mach/mach_vm.h>
#include <math.h>
BOOL MTReadMemory(const void *address, void *result, size_t length) {
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
BOOL MTWriteByte(void *object, size_t offset, uint8_t value) { return writeData(object, offset, &value, 1); }
BOOL MTWriteMemory(void *address,const void *bytes,size_t length) {
    return bytes && length>0 && length<=64 && writeData(address,0,bytes,length);
}
BOOL MTWriteFloat(void *object, size_t offset, float value) { return isfinite(value) && writeData(object, offset, &value, sizeof(value)); }
BOOL MTWriteInt(void *object, size_t offset, int32_t value) { return writeData(object, offset, &value, sizeof(value)); }
BOOL MTWritePointer(void *object, size_t offset, void *value) { return writeData(object, offset, &value, sizeof(value)); }
