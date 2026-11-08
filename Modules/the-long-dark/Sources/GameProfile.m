// SPDX-License-Identifier: GPL-3.0-only
#import "GameProfile.h"
#import <Security/Security.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <mach-o/dyld.h>
#import <mach/machine.h>
#import <libkern/OSByteOrder.h>
#import <CommonCrypto/CommonDigest.h>
#include <sys/stat.h>
#include <limits.h>
#include <math.h>
static id fail(NSError **error,NSString *reason) {if(error)*error=[NSError errorWithDomain:@"local.mactrainer.profile" code:1 userInfo:@{NSLocalizedDescriptionKey:reason}];return nil;}
static BOOL string(id value) {return [value isKindOfClass:NSString.class] && [value length]>0;}
NSDictionary *MTLoadConfiguration(NSString *path,NSError **error) {
    if(!string(path))return fail(error,@"Konfigurationspfad fehlt.");
    NSData *data=[NSData dataWithContentsOfFile:path];
    if(!data || data.length>1024*1024)return fail(error,@"Konfiguration fehlt oder ist zu groß.");
    id root=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if(![root isKindOfClass:NSDictionary.class] || ![root[@"schemaVersion"] isEqual:@1] || ![root[@"app"] isKindOfClass:NSDictionary.class] || ![root[@"profiles"] isKindOfClass:NSArray.class])return fail(error,@"Ungültige Konfigurationsstruktur.");
    for(NSString *key in @[@"name",@"bundleIdentifier",@"version",@"build"])if(!string(root[@"app"][key]))return fail(error,@"App-Metadaten fehlen.");
    NSMutableSet *ids=[NSMutableSet new];
    for(id p in root[@"profiles"]){
        if(![p isKindOfClass:NSDictionary.class] || !string(p[@"id"]) || !string(p[@"name"]) || ![p[@"enabled"] isKindOfClass:NSNumber.class] || [ids containsObject:p[@"id"]])return fail(error,@"Profilkennung fehlt oder ist doppelt.");
        [ids addObject:p[@"id"]];
        if([p[@"enabled"] boolValue]){
            if(!string(p[@"bundleIdentifier"]) || !string(p[@"executable"]) || ![p[@"uuids"] isKindOfClass:NSArray.class] || ![p[@"uuids"] count])return fail(error,@"Aktive Profile benötigen Bundle-ID, Executable und geprüfte UUIDs.");
            if([p[@"executable"] containsString:@"/"])return fail(error,@"Executable muss ein Dateiname sein.");
            for(id uuid in p[@"uuids"])if(!string(uuid) || ![[NSUUID alloc]initWithUUIDString:uuid])return fail(error,@"Ungültige UUID im aktiven Profil.");
            for(NSString *key in @[@"teamIdentifier",@"version"])if(p[key] && ![p[key] isKindOfClass:NSString.class])return fail(error,@"Ungültige Profilmetadaten.");
        }
    }return root;
}
NSDictionary *MTFindProfile(NSDictionary *configuration,NSString *identifier) {for(NSDictionary *p in configuration[@"profiles"])if([p[@"id"] isEqual:identifier])return p;return nil;}
static NSString *uuidInCommands(const uint8_t *bytes,NSUInteger size,uint32_t count) {
    NSUInteger offset=0;NSString *result=nil;
    for(uint32_t i=0;i<count;i++){
        struct load_command c={0};if(offset>size || sizeof(c)>size-offset)return nil;memcpy(&c,bytes+offset,sizeof(c));
        if(c.cmdsize<sizeof(c) || c.cmdsize>size-offset)return nil;
        if(c.cmd==LC_UUID){if(c.cmdsize!=sizeof(struct uuid_command) || result)return nil;struct uuid_command u;memcpy(&u,bytes+offset,sizeof(u));result=[[NSUUID alloc]initWithUUIDBytes:u.uuid].UUIDString;}
        offset+=c.cmdsize;
    }return offset==size ? result : nil;
}
NSDictionary *MTReadExecutableIdentity(NSString *path) {
    NSFileHandle *file=[NSFileHandle fileHandleForReadingFromURL:[NSURL fileURLWithPath:path] error:NULL];if(!file)return nil;
    NSDictionary *result=nil;
    @try {
        struct stat attributes={0};if(fstat(file.fileDescriptor,&attributes) || attributes.st_size<32)@throw [NSException exceptionWithName:@"InvalidExecutable" reason:nil userInfo:nil];
        uint64_t sliceSize=(uint64_t)attributes.st_size,sliceOffset=0;
        NSData *data=[file readDataUpToLength:sizeof(struct mach_header_64) error:NULL];struct mach_header_64 h={0};
        const uint8_t *bytes=data.bytes;
        uint32_t magic=data.length>=4 ? OSReadBigInt32(bytes,0) : 0;
        if(magic==FAT_MAGIC || magic==FAT_MAGIC_64){
            uint32_t count=OSReadBigInt32(bytes,4);NSUInteger stride=magic==FAT_MAGIC_64 ? 32 : 20;
            if(!count || count>32)@throw [NSException exceptionWithName:@"InvalidFatTable" reason:nil userInfo:nil];
            [file seekToOffset:8 error:NULL];NSData *table=[file readDataUpToLength:count*stride error:NULL];
            if(table.length!=count*stride)@throw [NSException exceptionWithName:@"TruncatedFatTable" reason:nil userInfo:nil];
            bytes=table.bytes;BOOL found=NO;NSMutableArray *ranges=[NSMutableArray new];
            for(uint32_t i=0;i<count;i++){
                const uint8_t *entry=bytes+i*stride;
                uint64_t offset=magic==FAT_MAGIC_64 ? OSReadBigInt64(entry,8) : OSReadBigInt32(entry,8);
                uint64_t length=magic==FAT_MAGIC_64 ? OSReadBigInt64(entry,16) : OSReadBigInt32(entry,12);
                if(offset<8+count*stride || length<32 || offset>(uint64_t)attributes.st_size || length>(uint64_t)attributes.st_size-offset)@throw [NSException exceptionWithName:@"InvalidFatSlice" reason:nil userInfo:nil];
                for(NSArray *range in ranges)if(offset<[range[0] unsignedLongLongValue]+[range[1] unsignedLongLongValue] && [range[0] unsignedLongLongValue]<offset+length)@throw [NSException exceptionWithName:@"OverlappingFatSlices" reason:nil userInfo:nil];
                [ranges addObject:@[@(offset),@(length)]];
                if(OSReadBigInt32(entry,0)==CPU_TYPE_ARM64){if(found)@throw [NSException exceptionWithName:@"AmbiguousArmSlice" reason:nil userInfo:nil];found=YES;sliceOffset=offset;sliceSize=length;}
            }
            if(!found)@throw [NSException exceptionWithName:@"MissingArmSlice" reason:nil userInfo:nil];
            [file seekToOffset:sliceOffset error:NULL];data=[file readDataUpToLength:sizeof(h) error:NULL];
        }
        if(data.length==sizeof(h))memcpy(&h,data.bytes,sizeof(h));
        if(h.magic==MH_MAGIC_64 && h.cputype==CPU_TYPE_ARM64 && h.filetype==MH_EXECUTE && h.sizeofcmds<=1024*1024 && h.ncmds<=4096 && h.sizeofcmds<=sliceSize-sizeof(h)){
            NSData *commands=[file readDataUpToLength:h.sizeofcmds error:NULL];
            NSString *uuid=commands.length==h.sizeofcmds ? uuidInCommands(commands.bytes,commands.length,h.ncmds) : nil;
            if(uuid)result=@{@"uuid":uuid,@"architecture":@"arm64"};
        }
    } @catch(NSException *exception){(void)exception;}
    [file closeAndReturnError:NULL];return result;
}
static BOOL checkResources(NSString *bundle,NSDictionary *profile) {
    if(!profile[@"fileChecks"])return YES;
    BOOL exact=[profile[@"signatureScope"] isEqual:@"sha256-original"];
    if(![profile[@"fileChecks"] isKindOfClass:NSArray.class] || [profile[@"fileChecks"] count]>64)return NO;
    NSMutableDictionary<NSString *,NSMutableArray<NSDictionary *> *> *coverage=[NSMutableDictionary new];
    for(id check in profile[@"fileChecks"]){
        if(![check isKindOfClass:NSDictionary.class])return NO;
        NSString *relative=check[@"path"],*hash=check[@"sha256"];
        if(!string(relative) || relative.isAbsolutePath || [relative.pathComponents containsObject:@".."] || ![hash isKindOfClass:NSString.class] || hash.length!=64)return NO;
        for(NSString *key in @[@"fileSize",@"offset",@"length"])if(![check[key] isKindOfClass:NSNumber.class] || [check[key] doubleValue]<0 || !isfinite([check[key] doubleValue]) || floor([check[key] doubleValue])!=[check[key] doubleValue])return NO;
        uint64_t length=[check[@"length"] unsignedLongLongValue],offset=[check[@"offset"] unsignedLongLongValue],size=[check[@"fileSize"] unsignedLongLongValue];
        if(!length || length>8*1024*1024 || offset>size || length>size-offset)return NO;
        NSString *path=[[bundle stringByAppendingPathComponent:relative] stringByResolvingSymlinksInPath];
        if(![path hasPrefix:[bundle stringByAppendingString:@"/"]])return NO;
        NSFileHandle *file=[NSFileHandle fileHandleForReadingAtPath:path];if(!file)return NO;
        BOOL valid=NO;
        @try {
            struct stat attributes={0};
            if(!fstat(file.fileDescriptor,&attributes) && S_ISREG(attributes.st_mode) && (uint64_t)attributes.st_size==size && [file seekToOffset:offset error:NULL]){
                NSData *data=[file readDataUpToLength:(NSUInteger)length error:NULL];unsigned char digest[CC_SHA256_DIGEST_LENGTH];
                if(data.length==length){CC_SHA256(data.bytes,(CC_LONG)data.length,digest);NSMutableString *actual=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[actual appendFormat:@"%02x",digest[i]];valid=[actual isEqual:hash.lowercaseString];}
            }
        }@catch(NSException *exception){(void)exception;}
        [file closeAndReturnError:NULL];if(!valid)return NO;
        if(!coverage[relative])coverage[relative]=[NSMutableArray new];
        [coverage[relative] addObject:check];
    }
    if(exact){
        // An explicit per-profile exception requires whole files, including the
        // original executable and Info.plist. Partial sampling is insufficient.
        if(![profile[@"integrityApproval"] isEqual:@"user-confirmed-steam-original"]
           || ![profile[@"integrityFiles"] isKindOfClass:NSArray.class]
           || [profile[@"integrityFiles"] count]<2 || [profile[@"integrityFiles"] count]>32)return NO;
        NSSet *required=[NSSet setWithArray:profile[@"integrityFiles"]];
        NSString *main=[@"Contents/MacOS" stringByAppendingPathComponent:profile[@"executable"]];
        if(required.count!=[profile[@"integrityFiles"] count] || ![required containsObject:@"Contents/Info.plist"]
           || ![required containsObject:main] || ![required isEqual:[NSSet setWithArray:coverage.allKeys]])return NO;
        for(NSString *path in required){
            if(!string(path))return NO;
            NSArray *chunks=[coverage[path] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"offset"] compare:b[@"offset"]];}];
            uint64_t position=0,size=[chunks.firstObject[@"fileSize"] unsignedLongLongValue];
            for(NSDictionary *chunk in chunks){
                if([chunk[@"fileSize"] unsignedLongLongValue]!=size || [chunk[@"offset"] unsignedLongLongValue]!=position)return NO;
                position+=[chunk[@"length"] unsignedLongLongValue];
            }
            if(!size || position!=size)return NO;
        }
    }
    return YES;
}
NSDictionary *MTInspectGame(NSString *path,NSDictionary *profile,NSError **error) {
    if(![profile[@"enabled"] boolValue] || !path.isAbsolutePath)return fail(error,@"Profil ist nicht freigegeben oder Pfad fehlt.");
    NSString *canonical=path.stringByStandardizingPath.stringByResolvingSymlinksInPath;
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:[canonical stringByAppendingPathComponent:@"Contents/Info.plist"]] error:NULL];
    if(![info[@"CFBundleIdentifier"] isEqual:profile[@"bundleIdentifier"]] || ![info[@"CFBundleExecutable"] isEqual:profile[@"executable"]])return fail(error,@"Bundle-ID oder Executable passt nicht zum Profil.");
    NSString *executable=[canonical stringByAppendingPathComponent:[@"Contents/MacOS" stringByAppendingPathComponent:profile[@"executable"]]];
    NSDictionary *identity=MTReadExecutableIdentity(executable);
    if(!identity || ![profile[@"uuids"] containsObject:identity[@"uuid"]])return fail(error,@"Spiel-Build/Architektur nicht freigegeben. Keine passende arm64-Identität.");
    if(!checkResources(canonical,profile))return fail(error,@"Spielressourcen weichen vom freigegebenen Build ab.");
    if([profile[@"version"] length] && ![info[@"CFBundleShortVersionString"] isEqual:profile[@"version"]])return fail(error,@"Spielversion weicht vom Profil ab.");
    BOOL sliceSignature=[profile[@"signatureScope"] isEqual:@"arm64-executable"];
    BOOL exactOriginal=[profile[@"signatureScope"] isEqual:@"sha256-original"];
    if(profile[@"signatureScope"] && !sliceSignature && !exactOriginal)return fail(error,@"Unbekannte Signaturprüfung im Profil.");
    if(exactOriginal){
        if(![profile[@"fileChecks"] count])return fail(error,@"Originalfreigabe benötigt vollständige Dateiprüfungen.");
        return @{@"path":canonical,@"executable":executable,@"uuid":identity[@"uuid"],@"integrityMode":@"sha256-original"};
    }
    if(sliceSignature && (!string(profile[@"signatureIdentifier"]) || ![profile[@"signatureCDHash"] isKindOfClass:NSString.class] || [profile[@"signatureCDHash"] length]!=40 || ![profile[@"fileChecks"] count]))return fail(error,@"Ausführbares Profil benötigt Original-Signaturidentität und Ressourcenprüfung.");
    SecStaticCodeRef code=NULL;OSStatus status;
    if(sliceSignature){
        NSDictionary *attributes=@{(__bridge NSString *)kSecCodeAttributeArchitecture:@"arm64"};
        status=SecStaticCodeCreateWithPathAndAttributes((__bridge CFURLRef)[NSURL fileURLWithPath:executable],kSecCSDefaultFlags,(__bridge CFDictionaryRef)attributes,&code);
    }else status=SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:canonical],kSecCSDefaultFlags,&code);
    if(!status)status=SecStaticCodeCheckValidity(code,(sliceSignature ? 0 : kSecCSCheckAllArchitectures)|kSecCSDoNotValidateResources,NULL);
    if(!status && ([profile[@"teamIdentifier"] length] || sliceSignature)){
        CFDictionaryRef details=NULL;status=SecCodeCopySigningInformation(code,kSecCSSigningInformation,&details);
        NSDictionary *signing=CFBridgingRelease(details);
        if(!status && [profile[@"teamIdentifier"] length] && ![signing[(__bridge NSString *)kSecCodeInfoTeamIdentifier] isEqual:profile[@"teamIdentifier"]])status=errSecCSReqFailed;
        if(!status && sliceSignature){
            NSData *hash=signing[(__bridge NSString *)kSecCodeInfoUnique];NSMutableString *actual=[NSMutableString new];
            for(NSUInteger i=0;i<hash.length;i++)[actual appendFormat:@"%02x",((const uint8_t *)hash.bytes)[i]];
            if(![signing[(__bridge NSString *)kSecCodeInfoIdentifier] isEqual:profile[@"signatureIdentifier"]] || ![actual isEqual:[profile[@"signatureCDHash"] lowercaseString]])status=errSecCSReqFailed;
        }
    }
    if(code)CFRelease(code);
    if(status)return fail(error,[NSString stringWithFormat:@"Originalsignatur nicht bestätigt (%d).",(int)status]);
    return @{@"path":canonical,@"executable":executable,@"uuid":identity[@"uuid"]};
}
BOOL MTCurrentProcessMatches(NSDictionary *profile,NSString *target) {
    if(![profile[@"enabled"] boolValue] || !target.isAbsolutePath)return NO;
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:profile[@"bundleIdentifier"]])return NO;
    uint32_t size=PATH_MAX;char raw[PATH_MAX],actual[PATH_MAX],expected[PATH_MAX];
    if(_NSGetExecutablePath(raw,&size) || !realpath(raw,actual) || !realpath(target.fileSystemRepresentation,expected) || strcmp(actual,expected))return NO;
    if(![[NSString stringWithUTF8String:actual].lastPathComponent isEqual:profile[@"executable"]])return NO;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *h=(const void *)_dyld_get_image_header(i);
        if(h && h->filetype==MH_EXECUTE){
            if(h->magic!=MH_MAGIC_64 || h->cputype!=CPU_TYPE_ARM64 || h->sizeofcmds>1024*1024 || h->ncmds>4096)return NO;
            NSString *uuid=uuidInCommands((const uint8_t *)(h+1),h->sizeofcmds,h->ncmds);
            return uuid && [profile[@"uuids"] containsObject:uuid];
        }
    }return NO;
}
