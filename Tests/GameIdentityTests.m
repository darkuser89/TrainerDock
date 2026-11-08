// SPDX-License-Identifier: GPL-3.0-only
// Synthetic headers only; no installed game is changed or executed.
#import "GameIdentity.h"
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <mach/machine.h>
#import <libkern/OSByteOrder.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach-o/dyld.h>
static void check(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static NSData *thin(cpu_type_t cpu) {
    struct mach_header_64 h={.magic=MH_MAGIC_64,.cputype=cpu,.filetype=MH_EXECUTE,.ncmds=1,.sizeofcmds=sizeof(struct uuid_command)};
    struct uuid_command u={.cmd=LC_UUID,.cmdsize=sizeof(struct uuid_command)};
    [[[NSUUID alloc]initWithUUIDString:@"11111111-2222-3333-8444-555555555555"] getUUIDBytes:u.uuid];
    NSMutableData *data=[NSMutableData dataWithBytes:&h length:sizeof(h)];[data appendBytes:&u length:sizeof(u)];return data;
}
static NSMutableData *fat(BOOL wide) {
    NSMutableData *data=[NSMutableData dataWithLength:1024];uint8_t *b=data.mutableBytes;
    OSWriteBigInt32(b,0,wide ? FAT_MAGIC_64 : FAT_MAGIC);OSWriteBigInt32(b,4,2);
    NSUInteger stride=wide ? 32 : 20;
    for(NSUInteger i=0;i<2;i++){
        NSUInteger p=8+i*stride;OSWriteBigInt32(b,p,i ? CPU_TYPE_ARM64 : CPU_TYPE_X86_64);
        if(wide){OSWriteBigInt64(b,p+8,256+i*256);OSWriteBigInt64(b,p+16,56);}
        else {OSWriteBigInt32(b,p+8,256+i*256);OSWriteBigInt32(b,p+12,56);}
        NSData *slice=thin(i ? CPU_TYPE_ARM64 : CPU_TYPE_X86_64);memcpy(b+256+i*256,slice.bytes,slice.length);
    }return data;
}
static NSDictionary *chunk(NSString *relative,NSData *data,NSUInteger offset,NSUInteger length){
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256((const uint8_t *)data.bytes+offset,(CC_LONG)length,digest);
    NSMutableString *hash=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[hash appendFormat:@"%02x",digest[i]];
    return @{@"path":relative,@"fileSize":@(data.length),@"offset":@(offset),@"length":@(length),@"sha256":hash};
}
static void originalIntegrity(NSString *directory){
    NSString *bundle=[directory stringByAppendingPathComponent:@"Fixture.app"];
    NSString *exe=@"Contents/MacOS/Fixture",*plist=@"Contents/Info.plist";
    check([NSFileManager.defaultManager createDirectoryAtPath:[bundle stringByAppendingPathComponent:@"Contents/MacOS"] withIntermediateDirectories:YES attributes:nil error:nil],"fixture bundle");
    NSData *binary=thin(CPU_TYPE_ARM64);
    NSDictionary *info=@{@"CFBundleIdentifier":@"local.mht.fixture",@"CFBundleExecutable":@"Fixture",@"CFBundleShortVersionString":@"1"};
    NSData *metadata=[NSPropertyListSerialization dataWithPropertyList:info format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    [binary writeToFile:[bundle stringByAppendingPathComponent:exe] atomically:YES];[metadata writeToFile:[bundle stringByAppendingPathComponent:plist] atomically:YES];
    NSDictionary *first=chunk(exe,binary,0,24),*last=chunk(exe,binary,24,binary.length-24),*wholeInfo=chunk(plist,metadata,0,metadata.length);
    NSMutableDictionary *profile=[@{@"enabled":@YES,@"bundleIdentifier":info[@"CFBundleIdentifier"],@"executable":@"Fixture",@"version":@"1",@"uuids":@[@"11111111-2222-3333-8444-555555555555"],
        @"signatureScope":@"sha256-original",@"integrityApproval":@"user-confirmed-steam-original",@"integrityFiles":@[exe,plist],@"fileChecks":@[last,first,wholeInfo]} mutableCopy];
    check([MTInspectGame(bundle,profile,nil)[@"integrityMode"] isEqual:@"sha256-original"],"approved original with complete unordered chunks accepted");
    NSDictionary *valid=[profile copy];
    profile[@"fileChecks"]=@[first,wholeInfo];check(!MTInspectGame(bundle,profile,nil),"partial file rejected");
    profile[@"fileChecks"]=@[first,last,last,wholeInfo];check(!MTInspectGame(bundle,profile,nil),"overlap rejected");
    profile[@"fileChecks"]=@[first,last];check(!MTInspectGame(bundle,profile,nil),"missing Info.plist hash rejected");
    profile[@"fileChecks"]=@[];check(!MTInspectGame(bundle,profile,nil),"empty checks rejected");
    [profile setDictionary:valid];profile[@"integrityFiles"]=@[exe,plist,plist];check(!MTInspectGame(bundle,profile,nil),"duplicate required file rejected");
    [profile setDictionary:valid];[profile removeObjectForKey:@"integrityApproval"];check(!MTInspectGame(bundle,profile,nil),"missing explicit approval marker rejected");
    [profile setDictionary:valid];profile[@"version"]=@"2";check(!MTInspectGame(bundle,profile,nil),"version mismatch rejected");
    [profile setDictionary:valid];[profile removeObjectForKey:@"signatureScope"];check(!MTInspectGame(bundle,profile,nil),"normal profile still requires signature");
    [profile setDictionary:valid];NSMutableData *mutated=[binary mutableCopy];((uint8_t *)mutated.mutableBytes)[8]^=1;
    [mutated writeToFile:[bundle stringByAppendingPathComponent:exe] atomically:YES];check(!MTInspectGame(bundle,profile,nil),"single changed original byte rejected");
    [binary writeToFile:[bundle stringByAppendingPathComponent:exe] atomically:YES];
    NSString *outside=[directory stringByAppendingPathComponent:@"outside"];[binary writeToFile:outside atomically:YES];
    [NSFileManager.defaultManager removeItemAtPath:[bundle stringByAppendingPathComponent:exe] error:nil];
    check([NSFileManager.defaultManager createSymbolicLinkAtPath:[bundle stringByAppendingPathComponent:exe] withDestinationPath:outside error:nil],"fixture symlink");
    check(!MTInspectGame(bundle,profile,nil),"symlink outside bundle rejected");
}
static void wrapperIntegrity(NSString *directory){
    NSString *bundle=[directory stringByAppendingPathComponent:@"Wrapped.app"],*exe=@"Contents/MacOS/Native",*wrapper=@"Contents/MacOS/Start",*plist=@"Contents/Info.plist";
    NSString *libs=[bundle stringByAppendingPathComponent:@"Contents/MacOS/libs"];
    [NSFileManager.defaultManager createDirectoryAtPath:libs withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *binary=thin(CPU_TYPE_ARM64),*script=[@"#!/bin/sh\nexec ./Native\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *metadata=[NSPropertyListSerialization dataWithPropertyList:@{@"CFBundleIdentifier":@"local.mht.wrapper",@"CFBundleExecutable":@"Start",@"CFBundleShortVersionString":@"1"} format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    [binary writeToFile:[bundle stringByAppendingPathComponent:exe] atomically:YES];[script writeToFile:[bundle stringByAppendingPathComponent:wrapper] atomically:YES];[metadata writeToFile:[bundle stringByAppendingPathComponent:plist] atomically:YES];
    NSMutableDictionary *p=[@{@"enabled":@YES,@"bundleIdentifier":@"local.mht.wrapper",@"executable":@"Native",@"bundleExecutable":@"Start",@"launchMode":@"executable",@"workingDirectory":@"Contents/MacOS",@"libraryDirectory":@"Contents/MacOS/libs",@"version":@"1",@"uuids":@[@"11111111-2222-3333-8444-555555555555"],@"signatureScope":@"sha256-original",@"integrityApproval":@"user-confirmed-steam-original",@"integrityFiles":@[exe,wrapper,plist],@"fileChecks":@[chunk(exe,binary,0,binary.length),chunk(wrapper,script,0,script.length),chunk(plist,metadata,0,metadata.length)]} mutableCopy];
    NSDictionary *valid=[p copy],*game=MTInspectGame(bundle,p,nil);
    check([game[@"executable"] isEqual:[bundle stringByAppendingPathComponent:exe]] && [game[@"libraryDirectory"] isEqual:libs],"verified native entry and confined original directories");
    p[@"integrityFiles"]=@[exe,plist];p[@"fileChecks"]=@[chunk(exe,binary,0,binary.length),chunk(plist,metadata,0,metadata.length)];check(!MTInspectGame(bundle,p,nil),"unhashed original wrapper rejected");
    [p setDictionary:valid];p[@"workingDirectory"]=@"../outside";check(!MTInspectGame(bundle,p,nil),"escaping working directory rejected");
    [p setDictionary:valid];p[@"libraryDirectory"]=@"/tmp";check(!MTInspectGame(bundle,p,nil),"absolute library directory rejected");
    [p setDictionary:valid];[NSFileManager.defaultManager removeItemAtPath:libs error:nil];[NSFileManager.defaultManager createSymbolicLinkAtPath:libs withDestinationPath:directory error:nil];check(!MTInspectGame(bundle,p,nil),"escaping library symlink rejected");
}
int main(void){@autoreleasepool {
    char own[PATH_MAX];uint32_t ownLength=sizeof(own);check(!_NSGetExecutablePath(own,&ownLength) && MTExecutableIsRunning(@(own)),"native process detection includes unregistered command-line executable");
    check(!MTExecutableIsRunning(@"/nonexistent/trainerdock-game"),"absent process path is not running");
    NSString *directory=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"MHT-Identity-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    check([NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:NO attributes:nil error:NULL],"temporary fixture directory");
    NSString *path=[directory stringByAppendingPathComponent:@"Game"];
    @try {
        [thin(CPU_TYPE_ARM64) writeToFile:path atomically:YES];check(MTReadExecutableIdentity(path)!=nil,"thin arm64 identity remains supported");
        [thin(CPU_TYPE_X86_64) writeToFile:path atomically:YES];check(!MTReadExecutableIdentity(path),"Intel-only image is rejected");
        for(NSNumber *wide in @[@NO,@YES]){
            NSMutableData *valid=fat(wide.boolValue);[valid writeToFile:path atomically:YES];
            check([MTReadExecutableIdentity(path)[@"uuid"] isEqual:@"11111111-2222-3333-8444-555555555555"],"arm64 slice selected from universal image");
            NSMutableData *bad=[valid mutableCopy];uint8_t *b=bad.mutableBytes;NSUInteger second=8+(wide.boolValue ? 32 : 20);
            OSWriteBigInt32(b,second,CPU_TYPE_X86_64);[bad writeToFile:path atomically:YES];check(!MTReadExecutableIdentity(path),"missing arm64 slice is rejected");
            bad=[valid mutableCopy];b=bad.mutableBytes;OSWriteBigInt32(b,8,CPU_TYPE_ARM64);[bad writeToFile:path atomically:YES];check(!MTReadExecutableIdentity(path),"duplicate arm64 slices are rejected");
            bad=[valid mutableCopy];b=bad.mutableBytes;
            if(wide.boolValue)OSWriteBigInt64(b,second+8,256);else OSWriteBigInt32(b,second+8,256);
            [bad writeToFile:path atomically:YES];check(!MTReadExecutableIdentity(path),"overlapping slices are rejected");
            bad=[valid mutableCopy];b=bad.mutableBytes;
            if(wide.boolValue)OSWriteBigInt64(b,second+16,UINT64_MAX);else OSWriteBigInt32(b,second+12,UINT32_MAX);
            [bad writeToFile:path atomically:YES];check(!MTReadExecutableIdentity(path),"overflowing slice length is rejected");
        }
        [[NSData dataWithBytes:"bad" length:3] writeToFile:path atomically:YES];check(!MTReadExecutableIdentity(path),"truncated file is rejected");
        originalIntegrity(directory);
        wrapperIntegrity(directory);
    }@finally {[NSFileManager.defaultManager removeItemAtPath:directory error:NULL];}
    puts("PASS: thin/universal arm64 UUIDs, 32/64-bit fat tables, Intel rejection, truncation, overlap, duplicate slices and overflow.");
    puts("PASS: exact-original full coverage, changed bytes, missing approval, gaps, overlaps, metadata, escaping symlinks and preserved signature requirement.");
}return 0;}
