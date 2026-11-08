// SPDX-License-Identifier: GPL-3.0-only
// Exercises the production metadata byte guard, not a gameplay simulation.
#include "StrayMetadataGuard.hpp"
#include <cstdio>
#include <cstdlib>
namespace {
void check(bool value,const char *text){if(!value){fprintf(stderr,"FAIL: %s\n",text);exit(1);}}
}
int main(){
 uint8_t metadata[0x100]{};size_t reads=0;bool readable=true;
 auto read=[&](uintptr_t at,void *out,size_t n){reads++;if(!readable||at<0x1000||n>sizeof(metadata)||at-0x1000>sizeof(metadata)-n)return false;memcpy(out,metadata+(at-0x1000),n);return true;};
 st::detail::MetadataGuard<24> heads;st::detail::MetadataGuard<0x50> descriptor;st::detail::MetadataGuard<8> type;
 check(heads.capture(0x1000,read)&&descriptor.capture(0x1020,read)&&type.capture(0x1080,read),"original metadata snapshots are captured");
 size_t start=reads;for(size_t n=0;n<20000;n++)check(heads.matches(read)&&descriptor.matches(read)&&type.matches(read),"unchanged metadata remains valid");
 check(reads-start==60000,"cache validation is bounded to the native head, selected descriptor and type rather than every field");
 metadata[0x10]=1;check(!heads.matches(read),"a changed native field-list head invalidates the cached owner");metadata[0x10]=0;
 metadata[0x20+0x4c]=1;check(!descriptor.matches(read),"a changed native field offset rejects access");metadata[0x20+0x4c]=0;
 metadata[0x20+0x40]=1;check(!descriptor.matches(read),"changed native property flags reject access");metadata[0x20+0x40]=0;
 metadata[0x80]=1;check(!type.matches(read),"a changed native FFieldClass rejects typed access");metadata[0x80]=0;
 readable=false;check(!heads.matches(read)&&!descriptor.matches(read),"an unreadable or expired metadata allocation never becomes a cache hit");
 puts("PASS: bounded production metadata guards reject changed heads, offsets, flags, field types and unreadable memory. No game started.");
}
