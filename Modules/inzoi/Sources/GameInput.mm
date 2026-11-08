// SPDX-License-Identifier: GPL-3.0-only
#import "GameInput.hpp"
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
extern "C" {
#import "MemoryAccess.h"
}
#include <cstring>
namespace {
uintptr_t relocation=0;bool checked=false,valid=false;
bool read(uintptr_t a,void *p,size_t n){return a>=4096&&n<=1048576&&n<=UINTPTR_MAX-a&&MTReadMemory((const void *)a,p,n);}
bool bind(){
 if(checked)return valid;checked=true;
 for(uint32_t i=0;i<_dyld_image_count();i++){
  auto h=(const mach_header_64 *)_dyld_get_image_header(i);if(!h||h->magic!=MH_MAGIC_64||h->filetype!=MH_EXECUTE)continue;
  if(h->cputype!=CPU_TYPE_ARM64||h->sizeofcmds>1048576||h->ncmds>4096)return false;
  bool exact=false;const uint8_t *p=(const uint8_t *)(h+1),*end=p+h->sizeofcmds;
  for(uint32_t j=0;j<h->ncmds;j++){if(p+sizeof(load_command)>end)return false;auto c=(const load_command *)p;if(c->cmdsize<sizeof(*c)||c->cmdsize>(size_t)(end-p))return false;if(c->cmd==LC_UUID&&c->cmdsize==sizeof(uuid_command))exact=[[[NSUUID alloc]initWithUUIDBytes:((const uuid_command *)c)->uuid].UUIDString isEqual:@"B1AA1CC2-C72B-3D8A-AC90-1E8C9155E519"];p+=c->cmdsize;}
  if(!exact)return false;relocation=_dyld_get_image_vmaddr_slide(i);
  // Original SetHighPrecisionMouseMode writes app+0xa0; its cursor setter uses
  // cursor+0x111. Original Show writes +0x110; Lock(nullptr) zeros +0x100..10f.
  const uint8_t setter[]={0x01,0x80,0x02,0x39,0x00,0x04,0x40,0xf9,0x01,0x00,0x00,0x14};uint8_t actual[12];
  valid=read(0x1012e58c8+relocation,actual,12)&&!memcmp(actual,setter,12);return valid;
 }return false;
}
}
bool IZMouseIsFree(){
 if(!bind())return false;
 uintptr_t app=0,cursor=0,table=0;uint8_t precision=1,cursorPrecision=1;int32_t rect[4]={};
 if(!read(0x112dc4a58+relocation,&app,8)||!read(app+8,&cursor,8)||!read(cursor,&table,8)||table!=0x110e73910+relocation)return false;
 if(!read(app+0xa0,&precision,1)||!read(cursor+0x111,&cursorPrecision,1)||!read(cursor+0x100,rect,sizeof(rect)))return false;
 return !precision&&!cursorPrecision&&!rect[0]&&!rect[1]&&!rect[2]&&!rect[3];
}
