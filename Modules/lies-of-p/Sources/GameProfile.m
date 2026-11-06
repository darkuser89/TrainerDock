// SPDX-License-Identifier: GPL-3.0-only
#import "GameProfile.h"
#import <Security/Security.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach/machine.h>
#include <limits.h>
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
            for(NSString *key in @[@"teamIdentifier",@"version",@"steamAppId"])if(p[key] && ![p[key] isKindOfClass:NSString.class])return fail(error,@"Ungültige Profilmetadaten.");
            if([p[@"steamAppId"] length] && ([p[@"steamAppId"] length]>10 || [p[@"steamAppId"] rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location!=NSNotFound))return fail(error,@"Ungültige Steam-App-ID.");
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
        NSData *data=[file readDataUpToLength:sizeof(struct mach_header_64) error:NULL];struct mach_header_64 h={0};
        if(data.length==sizeof(h))memcpy(&h,data.bytes,sizeof(h));
        if(h.magic==MH_MAGIC_64 && h.cputype==CPU_TYPE_ARM64 && h.filetype==MH_EXECUTE && h.sizeofcmds<=1024*1024 && h.ncmds<=4096){
            NSData *commands=[file readDataUpToLength:h.sizeofcmds error:NULL];
            NSString *uuid=commands.length==h.sizeofcmds ? uuidInCommands(commands.bytes,commands.length,h.ncmds) : nil;
            if(uuid)result=@{@"uuid":uuid,@"architecture":@"arm64"};
        }
    } @catch(NSException *exception){(void)exception;}
    [file closeAndReturnError:NULL];return result;
}
NSDictionary *MTInspectGame(NSString *path,NSDictionary *profile,NSError **error) {
    if(![profile[@"enabled"] boolValue] || !path.isAbsolutePath)return fail(error,@"Profil ist nicht freigegeben oder Pfad fehlt.");
    NSString *canonical=path.stringByStandardizingPath.stringByResolvingSymlinksInPath;
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:[canonical stringByAppendingPathComponent:@"Contents/Info.plist"]] error:NULL];
    if(![info[@"CFBundleIdentifier"] isEqual:profile[@"bundleIdentifier"]] || ![info[@"CFBundleExecutable"] isEqual:profile[@"executable"]])return fail(error,@"Bundle-ID oder Executable passt nicht zum Profil.");
    NSString *executable=[canonical stringByAppendingPathComponent:[@"Contents/MacOS" stringByAppendingPathComponent:profile[@"executable"]]];
    NSDictionary *identity=MTReadExecutableIdentity(executable);
    if(!identity || ![profile[@"uuids"] containsObject:identity[@"uuid"]])return fail(error,@"Spiel-Build/Architektur nicht freigegeben. Vorlage prüft dünne arm64-Mach-O-Dateien.");
    if([profile[@"version"] length] && ![info[@"CFBundleShortVersionString"] isEqual:profile[@"version"]])return fail(error,@"Spielversion weicht vom Profil ab.");
    SecStaticCodeRef code=NULL;OSStatus status=SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:canonical],kSecCSDefaultFlags,&code);
    if(!status)status=SecStaticCodeCheckValidity(code,kSecCSCheckAllArchitectures|kSecCSDoNotValidateResources,NULL);
    if(!status && [profile[@"teamIdentifier"] length]){
        CFDictionaryRef details=NULL;status=SecCodeCopySigningInformation(code,kSecCSSigningInformation,&details);
        NSDictionary *signing=CFBridgingRelease(details);
        if(!status && ![signing[(__bridge NSString *)kSecCodeInfoTeamIdentifier] isEqual:profile[@"teamIdentifier"]])status=errSecCSReqFailed;
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
