// SPDX-License-Identifier: GPL-3.0-only
// Executes the real build gate against synthetic headers/code bytes only.
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <cstring>
static NSMutableData *testImage;
static uint32_t CDTestImageCount(void) {return 1;}
static const mach_header *CDTestImageHeader(uint32_t index) {return index==0 ? (const mach_header *)testImage.bytes : nullptr;}
#define _dyld_image_count CDTestImageCount
#define _dyld_get_image_header CDTestImageHeader
#include "../../Modules/crimson-desert/Sources/CrimsonNative.mm"
#undef _dyld_image_count
#undef _dyld_get_image_header
extern "C" BOOL MTReadMemory(const void *pointer,void *out,size_t size) {
    uintptr_t base=(uintptr_t)testImage.bytes,p=(uintptr_t)pointer;
    if(p<base || p-base>testImage.length || size>testImage.length-(p-base))return NO;
    memcpy(out,pointer,size);return YES;
}
extern "C" BOOL MTWriteMemory(void *,const void *,size_t) {return NO;}
static void require(bool ok) {if(!ok)abort();}
static void prepare(unsigned build) {
    checked=false;supported=false;buildNumber=0;imageBase=0;
    memset(testImage.mutableBytes,0,sizeof(mach_header_64)+sizeof(uuid_command));
    auto *header=(mach_header_64 *)testImage.mutableBytes;
    *header={MH_MAGIC_64,CPU_TYPE_ARM64,CPU_SUBTYPE_ARM64_ALL,MH_EXECUTE,1,sizeof(uuid_command),0,0};
    auto *uuid=(uuid_command *)(header+1);uuid->cmd=LC_UUID;uuid->cmdsize=sizeof(*uuid);
    memcpy(uuid->uuid,build==476 ? CDExpectedUUID476 : build==466 ? CDExpectedUUID466 : CDExpectedUUID,16);
    if(build==476)for(const auto &entry:CDEntryChecks476)memcpy((uint8_t *)header+entry.offset,entry.bytes,32);
    else if(build==466)for(const auto &entry:CDEntryChecks466)memcpy((uint8_t *)header+entry.offset,entry.bytes,32);
    else for(const auto &entry:CDEntryChecks)memcpy((uint8_t *)header+entry.offset,entry.bytes,32);
}
int main(void) {@autoreleasepool {
    bool defaultConstructor=false;
    for(const auto &entry:CDEntryChecks466)if(entry.key==0x1f97c9c){
        uint32_t words[4];memcpy(words,entry.bytes,sizeof(words));
        require(words[0]==0xf900181f && words[1]==0x52800248 && words[2]==0x79000008 && words[3]==0xd65f03c0);
        defaultConstructor=true; // Four leaf instructions, no second argument.
    }
    require(defaultConstructor);
    testImage=[NSMutableData dataWithLength:0x5000000];
    prepare(450);require(CDCorrectBuild() && buildNumber==450);
    require(address(0x3fd062c)==imageBase+0x3fd062c);
    prepare(466);require(CDCorrectBuild() && buildNumber==466);
    for(const auto &entry:CDEntryChecks466)require(address(entry.key)==imageBase+entry.offset);
    for(const auto &entry:CDGlobals466)require(address(entry.key)==imageBase+entry.offset);
    require(CDOffset466(0xf56b88)==0 && CDOffset466(0x442e5e4)==0 && CDOffset466(0x195676c)==0x1969b0c && CDOffset466(0xdeadbeef)==0);
    prepare(476);require(CDCorrectBuild() && buildNumber==476);
    for(const auto &entry:CDEntryChecks476)require(address(entry.key)==imageBase+entry.offset);
    for(const auto &entry:CDGlobals476)require(address(entry.key)==imageBase+entry.offset);
    require(CDOffset476(0xf56b88)==0 && CDOffset476(0x442e5e4)==0 && CDOffset476(0x195676c)==0x196c5c4 && CDOffset476(0xdeadbeef)==0);
    for(const auto &entry:CDEntryChecks476) {
        prepare(476);((uint8_t *)testImage.mutableBytes)[entry.offset]^=1;require(!CDCorrectBuild());
    }
    // Every individual instruction guard must reject corruption independently.
    for(const auto &entry:CDEntryChecks466) {
        prepare(466);((uint8_t *)testImage.mutableBytes)[entry.offset]^=1;require(!CDCorrectBuild());
    }
    prepare(466);((uuid_command *)((mach_header_64 *)testImage.mutableBytes+1))->uuid[0]^=1;require(!CDCorrectBuild());
    prepare(466);((mach_header_64 *)testImage.mutableBytes)->cputype=CPU_TYPE_X86_64;require(!CDCorrectBuild());
    prepare(466);((mach_header_64 *)testImage.mutableBytes)->sizeofcmds=0;require(!CDCorrectBuild());
    prepare(476);((uuid_command *)((mach_header_64 *)testImage.mutableBytes+1))->uuid[0]^=1;require(!CDCorrectBuild());
    prepare(476);((mach_header_64 *)testImage.mutableBytes)->cputype=CPU_TYPE_X86_64;require(!CDCorrectBuild());
    prepare(476);((mach_header_64 *)testImage.mutableBytes)->sizeofcmds=0;require(!CDCorrectBuild());
    NSLog(@"PASS: three exact original build gates, 150 individually corrupted relocated guards, unknown UUID/CPU/header; no game started.");
    return 0;
}}
