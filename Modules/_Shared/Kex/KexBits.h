// SPDX-License-Identifier: GPL-3.0-only
#import "MemoryAccess.h"
typedef struct {BOOL held,baseline;} KEXBitState;
static inline BOOL KEXApplyBit(void *object,size_t offset,uint32_t mask,BOOL wanted,KEXBitState *state){
 if(!object || !state || !mask || (mask&(mask-1)) || (uintptr_t)object>UINTPTR_MAX-offset)return NO;
 uint32_t value=0;if(!MTReadMemory((uint8_t *)object+offset,&value,4))return NO;
 if(wanted){if(!state->held)*state=(KEXBitState){YES,(value&mask)!=0};value|=mask;}
 else{if(!state->held)return YES;if(!(value&mask)){*state=(KEXBitState){0};return YES;}value=state->baseline ? value|mask : value&~mask;}
 uint32_t actual=0;BOOL ok=MTWriteInt(object,offset,(int32_t)value) && MTReadMemory((uint8_t *)object+offset,&actual,4) && (actual&mask)==(value&mask);
 if(ok && !wanted)*state=(KEXBitState){0};return ok;
}
