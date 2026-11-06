// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT BOOL MTReadMemory(const void *address,void *result,size_t length);
FOUNDATION_EXPORT BOOL MTWriteMemory(void *address,const void *bytes,size_t length);
FOUNDATION_EXPORT BOOL MTWriteByte(void *object,size_t offset,uint8_t value);
FOUNDATION_EXPORT BOOL MTWriteFloat(void *object,size_t offset,float value);
FOUNDATION_EXPORT BOOL MTWriteInt(void *object,size_t offset,int32_t value);
FOUNDATION_EXPORT BOOL MTWritePointer(void *object,size_t offset,void *value);
