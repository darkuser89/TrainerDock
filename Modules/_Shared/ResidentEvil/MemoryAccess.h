// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
BOOL MTReadMemory(const void *address,void *result,size_t length);
BOOL MTWriteByte(void *object,size_t offset,uint8_t value);
BOOL MTWriteFloat(void *object,size_t offset,float value);
BOOL MTWriteInt(void *object,size_t offset,int32_t value);
BOOL MTWriteUInt64(void *object,size_t offset,uint64_t value);
BOOL MTWritePointer(void *object,size_t offset,void *value);
