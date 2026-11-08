// SPDX-License-Identifier: GPL-3.0-only
#import "MHTTrainerArchive.h"
#import "MHTModule.h"
#import "GameIdentity.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <archive.h>
#import <archive_entry.h>
#import <mach-o/loader.h>
#import <mach/machine.h>
#import <sys/stat.h>
#import <sys/xattr.h>
#import <fcntl.h>
#import <unistd.h>
#include <math.h>
static BOOL AFail(NSError **error,NSString *message){if(error)*error=[NSError errorWithDomain:@"local.trainerdock.archive" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return NO;}
static BOOL regular(NSString *path,uint64_t maximum){struct stat s;return !lstat(path.fileSystemRepresentation,&s)&&S_ISREG(s.st_mode)&&s.st_size>0&&(uint64_t)s.st_size<=maximum;}
BOOL MHTTrainerVerifyArchive(NSURL *archive,NSDictionary *version,NSError **error){
    struct stat s;if(lstat(archive.fileSystemRepresentation,&s)||!S_ISREG(s.st_mode)||s.st_size<=0||(uint64_t)s.st_size>64*1024*1024||(uint64_t)s.st_size!=[version[@"size"] unsignedLongLongValue])return AFail(error,@"Die Größe des Trainerpakets stimmt nicht.");
    NSInputStream *stream=[NSInputStream inputStreamWithURL:archive];[stream open];CC_SHA256_CTX context;CC_SHA256_Init(&context);uint8_t bytes[65536],digest[CC_SHA256_DIGEST_LENGTH];NSInteger n;
    while((n=[stream read:bytes maxLength:sizeof(bytes)])>0)CC_SHA256_Update(&context,bytes,(CC_LONG)n);
    [stream close];if(n<0)return AFail(error,@"Das Trainerpaket konnte nicht gelesen werden.");CC_SHA256_Final(digest,&context);
    NSMutableString *hex=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[hex appendFormat:@"%02x",digest[i]];
    return [hex isEqual:version[@"sha256"]] || AFail(error,@"Die SHA-256-Prüfsumme des Trainerpakets stimmt nicht.");
}
BOOL MHTTrainerExtractArchive(NSURL *archive,NSURL *destination,NSString *identifier,NSError **error){
    NSString *root=[identifier stringByAppendingString:@".mhtmodule"];
    NSSet *allowed=[NSSet setWithArray:@[@"Module.json",@"TrainerConfig.json",@"Trainer.dylib",@"LICENSE"]];
    struct archive *reader=archive_read_new();archive_read_support_format_zip(reader);
    BOOL ok=archive_read_open_filename(reader,archive.fileSystemRepresentation,65536)==ARCHIVE_OK;
    NSMutableSet *seen=[NSMutableSet new];NSUInteger entries=0;uint64_t total=0;int status=ARCHIVE_FATAL;struct archive_entry *entry=NULL;
    while(ok&&(status=archive_read_next_header(reader,&entry))==ARCHIVE_OK){
        const char *raw=archive_entry_pathname_utf8(entry);NSString *path=raw?[NSString stringWithUTF8String:raw]:nil;
        if(!path.length||path.isAbsolutePath||[path containsString:@"\\"]||archive_entry_symlink(entry)||archive_entry_hardlink(entry)||++entries>5){ok=NO;break;}
        while([path hasSuffix:@"/"])path=[path substringToIndex:path.length-1];
        NSArray *parts=[path componentsSeparatedByString:@"/"];mode_t type=archive_entry_filetype(entry);
        BOOL directory=parts.count==1&&[parts[0] isEqual:root]&&type==AE_IFDIR;
        BOOL file=parts.count==2&&[parts[0] isEqual:root]&&[allowed containsObject:parts[1]]&&type==AE_IFREG;
        if((!directory&&!file)||[seen containsObject:path.lowercaseString]){ok=NO;break;}[seen addObject:path.lowercaseString];
        NSURL *target=[destination URLByAppendingPathComponent:path];
        if(directory){ok=[NSFileManager.defaultManager createDirectoryAtURL:target withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:error];continue;}
        la_int64_t size=archive_entry_size(entry);if(size<=0||size>64*1024*1024){ok=NO;break;}
        if(![NSFileManager.defaultManager createDirectoryAtURL:target.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:error]){ok=NO;break;}
        int fd=open(target.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,[parts[1] isEqual:@"Trainer.dylib"]?0755:0644);
        if(fd<0){ok=NO;break;}uint8_t bytes[65536];la_ssize_t n;uint64_t written=0;
        while((n=archive_read_data(reader,bytes,sizeof(bytes)))>0){total+=(uint64_t)n;written+=(uint64_t)n;if(total>128*1024*1024||written>(uint64_t)size){ok=NO;break;}ssize_t at=0;while(at<n){ssize_t count=write(fd,bytes+at,(size_t)(n-at));if(count<=0){ok=NO;break;}at+=count;}if(!ok)break;}
        close(fd);if(n<0||written!=(uint64_t)size)ok=NO;
    }
    archive_read_free(reader);
    if(!ok||status!=ARCHIVE_EOF)return AFail(error,@"Das Trainerarchiv enthält ungültige, doppelte oder beschädigte Einträge.");
    NSURL *package=[destination URLByAppendingPathComponent:root];NSArray *contents=[NSFileManager.defaultManager contentsOfDirectoryAtPath:package.path error:error];
    if(![[NSSet setWithArray:contents ?: @[]] isEqual:allowed])return AFail(error,@"Das Trainerpaket ist unvollständig.");
    // Keep operating-system download attributes rather than stripping quarantine.
    char value[4096];ssize_t length=getxattr(archive.fileSystemRepresentation,"com.apple.quarantine",value,sizeof(value),0,0);
    if(length>0&&setxattr(package.fileSystemRepresentation,"com.apple.quarantine",value,(size_t)length,0,0))return AFail(error,@"Die Downloadattribute konnten nicht übernommen werden.");
    return YES;
}
static BOOL runtime(NSString *path,NSString *architecture,NSError **error){
    if(!regular(path,64*1024*1024))return AFail(error,@"Die Trainerbibliothek fehlt oder ist ungültig.");
    NSData *data=[NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:error];if(data.length<sizeof(struct mach_header_64))return AFail(error,@"Die Trainerbibliothek ist beschädigt.");
    struct mach_header_64 h;memcpy(&h,data.bytes,sizeof(h));cpu_type_t cpu=[architecture isEqual:@"x86_64"]?CPU_TYPE_X86_64:CPU_TYPE_ARM64;
    if(h.magic!=MH_MAGIC_64||h.cputype!=cpu||h.filetype!=MH_DYLIB||!h.ncmds||h.ncmds>4096||h.sizeofcmds>1024*1024||h.sizeofcmds>data.length-sizeof(h))return AFail(error,@"Die Trainerarchitektur passt nicht zum Profil.");
    const uint8_t *at=(const uint8_t*)data.bytes+sizeof(h),*end=at+h.sizeofcmds;BOOL minimum=NO,seenMinimum=NO;
    NSOperatingSystemVersion os=NSProcessInfo.processInfo.operatingSystemVersion;uint32_t host=((uint32_t)os.majorVersion<<16)|((uint32_t)os.minorVersion<<8)|(uint32_t)os.patchVersion;
    for(uint32_t i=0;i<h.ncmds;i++){
        if((size_t)(end-at)<sizeof(struct load_command))return AFail(error,@"Ungültige Mach-O-Ladetabelle.");struct load_command c;memcpy(&c,at,sizeof(c));if(c.cmdsize<sizeof(c)||c.cmdsize>(size_t)(end-at))return AFail(error,@"Ungültige Mach-O-Ladetabelle.");
        if(c.cmd==LC_BUILD_VERSION){if(c.cmdsize<sizeof(struct build_version_command)||seenMinimum)return AFail(error,@"Mehrdeutige Mindestversion im Trainer.");seenMinimum=YES;struct build_version_command b;memcpy(&b,at,sizeof(b));minimum=b.platform==PLATFORM_MACOS&&b.minos>=0x1b0000&&b.minos<=host;}
        at+=c.cmdsize;
    }
    if(at!=end||!minimum)return AFail(error,@"Der Trainer benötigt eine andere macOS-Version.");
    SecStaticCodeRef code=NULL;OSStatus result=SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:path],kSecCSDefaultFlags,&code);
    if(result==errSecSuccess){result=SecStaticCodeCheckValidity(code,kSecCSStrictValidate|kSecCSCheckAllArchitectures,NULL);CFRelease(code);}
    return result==errSecSuccess||AFail(error,@"Das Code-Siegel der Trainerbibliothek ist beschädigt.");
}
BOOL MHTTrainerValidatePackage(NSURL *package,NSDictionary *version,NSString *identifier,NSError **error){
    struct stat s;if(lstat(package.fileSystemRepresentation,&s)||!S_ISDIR(s.st_mode)||![package.lastPathComponent isEqual:[identifier stringByAppendingString:@".mhtmodule"]])return AFail(error,@"Ungültiger Trainerordner.");
    NSSet *allowed=[NSSet setWithArray:@[@"Module.json",@"TrainerConfig.json",@"Trainer.dylib",@"LICENSE"]];NSArray *files=[NSFileManager.defaultManager contentsOfDirectoryAtPath:package.path error:error];if(![[NSSet setWithArray:files ?: @[]] isEqual:allowed])return AFail(error,@"Das Trainerpaket enthält unerwartete Dateien.");
    for(NSString *file in allowed)if(!regular([package.path stringByAppendingPathComponent:file],[file isEqual:@"Trainer.dylib"]?64*1024*1024:1024*1024))return AFail(error,@"Ungültige Datei im Trainerpaket.");
    NSDictionary *manifest=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[package URLByAppendingPathComponent:@"Module.json"]] options:0 error:error];
    if(![MHTModule validManifest:manifest error:error]||![manifest[@"id"] isEqual:identifier]||![manifest[@"version"] isEqual:version[@"version"]]||(version[@"manifest"]&&![manifest isEqual:version[@"manifest"]]))return AFail(error,@"Das Trainerpaket passt nicht zu den Katalogmetadaten.");
    NSDictionary *config=MTLoadConfiguration([package.path stringByAppendingPathComponent:@"TrainerConfig.json"],error);
    if(!config||![config[@"profiles"] isEqual:manifest[@"profiles"]]||![config[@"app"][@"version"] isEqual:manifest[@"version"]])return AFail(error,@"Die Trainerkonfiguration passt nicht zum Paket.");
    NSString *architecture=nil;for(NSDictionary *profile in manifest[@"profiles"]){NSString *next=profile[@"architecture"] ?: @"arm64";if(architecture&&![architecture isEqual:next])return AFail(error,@"Mehrdeutige Profilarchitektur.");architecture=next;}
    return runtime([package.path stringByAppendingPathComponent:@"Trainer.dylib"],architecture,error);
}
