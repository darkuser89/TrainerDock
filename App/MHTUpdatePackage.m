// SPDX-License-Identifier: GPL-3.0-only
#import "MHTUpdatePackage.h"
#import "MHTTrainerStore.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/Security.h>
#import <archive.h>
#import <archive_entry.h>
#import <sys/stat.h>
#import <sys/xattr.h>
#import <libproc.h>
#import <signal.h>
#import <fcntl.h>
#import <unistd.h>
static NSString *const assetName=@"TrainerDock-macOS-arm64.zip";
static BOOL fail(NSError **error,NSString *message){if(error)*error=[NSError errorWithDomain:@"TrainerDock.Update" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];return NO;}
static BOOL matches(NSString *value,NSString *pattern){return [value isKindOfClass:NSString.class] && [value rangeOfString:pattern options:NSRegularExpressionSearch].location!=NSNotFound;}
NSDictionary *MHTNewRelease(NSDictionary *json,NSString *current,NSError **error){
    if(![json isKindOfClass:NSDictionary.class] || ![json[@"assets"] isKindOfClass:NSArray.class] ||
       !matches(json[@"tag_name"],@"^v[0-9]{1,9}\\.[0-9]{1,9}\\.[0-9]{1,9}$") ||
       ![json[@"draft"] isKindOfClass:NSNumber.class] || ![json[@"prerelease"] isKindOfClass:NSNumber.class]){
        fail(error,@"GitHub hat keine gültigen Release-Daten geliefert.");return nil;
    }
    if([json[@"draft"] boolValue] || [json[@"prerelease"] boolValue])return nil;
    NSString *version=[json[@"tag_name"] substringFromIndex:1];
    if([version compare:current options:NSNumericSearch]!=NSOrderedDescending)return nil;
    NSString *expected=[NSString stringWithFormat:@"https://github.com/darkuser89/TrainerDock/releases/download/%@/%@",json[@"tag_name"],assetName];
    NSDictionary *found=nil;
    for(id value in json[@"assets"]){
        if(![value isKindOfClass:NSDictionary.class] || ![value[@"name"] isEqual:assetName])continue;
        if(found || ![value[@"browser_download_url"] isEqual:expected] || !matches(value[@"digest"],@"^sha256:[a-fA-F0-9]{64}$") ||
           ![value[@"size"] isKindOfClass:NSNumber.class] || [value[@"size"] longLongValue]<=0 || [value[@"size"] longLongValue]>200*1024*1024){
            fail(error,@"Das GitHub-Updatepaket oder seine SHA-256-Prüfsumme ist ungültig.");return nil;
        }
        found=@{@"version":version,@"url":expected,@"sha256":[[value[@"digest"] substringFromIndex:7] lowercaseString],@"size":value[@"size"]};
    }
    if(!found)fail(error,@"Dieses Release enthält kein passendes Updatepaket.");
    return found;
}
BOOL MHTVerifyUpdateArchive(NSURL *url,NSDictionary *release,NSError **error){
    NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:error];
    if(!attributes)return NO;
    if(![attributes[NSFileType] isEqual:NSFileTypeRegular] || [attributes[NSFileSize] unsignedLongLongValue]!=[release[@"size"] unsignedLongLongValue])return fail(error,@"Die Größe des Updatepakets stimmt nicht.");
    NSInputStream *stream=[NSInputStream inputStreamWithURL:url];[stream open];CC_SHA256_CTX context;CC_SHA256_Init(&context);
    uint8_t buffer[65536],digest[CC_SHA256_DIGEST_LENGTH];NSInteger count;
    while((count=[stream read:buffer maxLength:sizeof(buffer)])>0)CC_SHA256_Update(&context,buffer,(CC_LONG)count);
    [stream close];if(count<0)return fail(error,@"Das Updatepaket konnte nicht gelesen werden.");CC_SHA256_Final(digest,&context);
    NSMutableString *hex=[NSMutableString new];for(NSUInteger i=0;i<sizeof(digest);i++)[hex appendFormat:@"%02x",digest[i]];
    return [hex isEqual:release[@"sha256"]] || fail(error,@"SHA-256 stimmt nicht überein. Das Update wurde verworfen.");
}
BOOL MHTExtractUpdate(NSURL *url,NSURL *directory,NSError **error){
    // Extract ourselves: no archive paths, links, special files or permissions are trusted.
    struct archive *reader=archive_read_new();archive_read_support_format_zip(reader);
    BOOL ok=archive_read_open_filename(reader,url.fileSystemRepresentation,65536)==ARCHIVE_OK;
    NSMutableSet *seen=[NSMutableSet new];uint64_t total=0;NSUInteger entries=0;struct archive_entry *entry=NULL;int status=ARCHIVE_FATAL;
    while(ok && (status=archive_read_next_header(reader,&entry))==ARCHIVE_OK){
        const char *raw=archive_entry_pathname_utf8(entry);NSString *name=raw ? [NSString stringWithUTF8String:raw] : nil;
        NSArray *parts=[name componentsSeparatedByString:@"/"];
        if(!name.length || name.isAbsolutePath || [name containsString:@"\\"] || [parts containsObject:@".."] || [parts containsObject:@"."] || ++entries>20000){ok=NO;break;}
        if([parts.firstObject isEqual:@"__MACOSX"]){archive_read_data_skip(reader);continue;}
        if(![parts.firstObject isEqual:@"TrainerDock.app"] || archive_entry_symlink(entry) || archive_entry_hardlink(entry)){ok=NO;break;}
        mode_t type=archive_entry_filetype(entry);
        if(type!=AE_IFREG && type!=AE_IFDIR){ok=NO;break;}
        while([name hasSuffix:@"/"])name=[name substringToIndex:name.length-1];
        if([seen containsObject:name]){ok=NO;break;}[seen addObject:name];
        NSURL *target=[directory URLByAppendingPathComponent:name];
        if(type==AE_IFDIR){ok=[NSFileManager.defaultManager createDirectoryAtURL:target withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:error];continue;}
        if(archive_entry_size(entry)<0 || archive_entry_size(entry)>1000000000){ok=NO;break;}
        ok=[NSFileManager.defaultManager createDirectoryAtURL:target.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755} error:error];if(!ok)break;
        int fd=open(target.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,archive_entry_perm(entry)&0111 ? 0755 : 0644);
        if(fd<0){ok=NO;break;}
        uint8_t buffer[65536];la_ssize_t count;uint64_t actual=0;
        while((count=archive_read_data(reader,buffer,sizeof(buffer)))>0){
            total+=(uint64_t)count;actual+=(uint64_t)count;
            if(total>1000000000 || actual>(uint64_t)archive_entry_size(entry)){ok=NO;break;}
            ssize_t written=0;while(written<count){ssize_t n=write(fd,buffer+written,(size_t)(count-written));if(n<=0){ok=NO;break;}written+=n;}if(!ok)break;
        }
        close(fd);if(count<0 || actual!=(uint64_t)archive_entry_size(entry))ok=NO;
    }
    archive_read_free(reader);
    if(!ok || status!=ARCHIVE_EOF)return fail(error,@"Das Updatearchiv enthält ungültige oder beschädigte Einträge.");
    // Preserve any quarantine information attached by the download/system; never remove it.
    char quarantine[4096];ssize_t length=getxattr(url.fileSystemRepresentation,"com.apple.quarantine",quarantine,sizeof(quarantine),0,0);
    if(length>0 && setxattr([[directory URLByAppendingPathComponent:@"TrainerDock.app"] fileSystemRepresentation],"com.apple.quarantine",quarantine,(size_t)length,0,0))return fail(error,@"Die Downloadattribute konnten nicht übernommen werden.");
    return YES;
}
BOOL MHTValidateUpdateApp(NSURL *app,NSString *version,NSError **error){
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfURL:[app URLByAppendingPathComponent:@"Contents/Info.plist"]];
    if(![info[@"CFBundleIdentifier"] isEqual:@"local.trainerdock.launcher"] || ![info[@"CFBundleExecutable"] isEqual:@"TrainerDock"] ||
       ![info[@"CFBundleShortVersionString"] isEqual:version] || ![info[@"LSMinimumSystemVersion"] isEqual:@"27.0"] ||
       ![NSFileManager.defaultManager isExecutableFileAtPath:[app URLByAppendingPathComponent:@"Contents/MacOS/TrainerDock"].path])return fail(error,@"Die heruntergeladene App passt nicht zu diesem Update.");
    NSURL *catalogURL=[app URLByAppendingPathComponent:@"Contents/Resources/TrainerCatalog.json"];
    NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:catalogURL.path error:NULL];
    if(attributes){
        if(![attributes[NSFileType] isEqual:NSFileTypeRegular] || [attributes[NSFileSize] unsignedLongLongValue]>8*1024*1024)
            return fail(error,@"Der Trainerkatalog des Updates ist ungültig.");
        NSData *data=[NSData dataWithContentsOfURL:catalogURL];
        id catalog=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        // This is an app-update boundary, not the current host's trainer ABI
        // gate: a newer app may intentionally add support for a newer ABI.
        if(![catalog isKindOfClass:NSDictionary.class] || ![catalog[@"schemaVersion"] isEqual:@1]
           || ![catalog[@"moduleABI"] isKindOfClass:NSNumber.class] || [catalog[@"moduleABI"] integerValue]<1
           || ![catalog[@"modules"] isKindOfClass:NSArray.class] || [catalog[@"modules"] count]>512)
            return fail(error,@"Der Trainerkatalog des Updates ist ungültig.");
    }else{
        NSArray *modules=[NSFileManager.defaultManager contentsOfDirectoryAtURL:[app URLByAppendingPathComponent:@"Contents/Resources/Modules"] includingPropertiesForKeys:nil options:0 error:NULL];
        BOOL legacy=NO;for(NSURL *module in modules)if([module.pathExtension isEqual:@"mhtmodule"]){legacy=YES;break;}
        if(!legacy)return fail(error,@"Das Update enthält weder Trainerkatalog noch gültige Altstruktur.");
    }
    SecStaticCodeRef code=NULL;OSStatus result=SecStaticCodeCreateWithPath((__bridge CFURLRef)app,kSecCSDefaultFlags,&code);
    if(result==errSecSuccess){result=SecStaticCodeCheckValidity(code,kSecCSStrictValidate|kSecCSCheckAllArchitectures|kSecCSCheckNestedCode,NULL);CFRelease(code);}
    // Only structural integrity of the existing ad-hoc code seal; no signing identity/key required.
    return result==errSecSuccess || fail(error,@"Das Update ist unvollständig oder beschädigt.");
}
BOOL MHTSwapUpdate(NSURL *current,NSURL *candidate,NSError **error){
    if(renameatx_np(AT_FDCWD,current.fileSystemRepresentation,AT_FDCWD,candidate.fileSystemRepresentation,RENAME_SWAP)==0)return YES;
    return fail(error,@"Die App konnte nicht ausgetauscht werden. Bitte TrainerDock in einen beschreibbaren Ordner verschieben.");
}
BOOL MHTPreserveBundledTrainers(NSURL *current,NSString *storeDirectory,NSError **error){
    NSMutableArray *errors=[NSMutableArray new];
    NSArray<MHTModule *> *modules=[MHTModule loadModules:[current URLByAppendingPathComponent:@"Contents/Resources/Modules"].path errors:errors];
    if(errors.count)return fail(error,@"Vorhandene Trainer konnten nicht sicher übernommen werden. Die bisherige App bleibt erhalten.");
    MHTTrainerStore *store=[[MHTTrainerStore alloc]initWithRootDirectory:storeDirectory catalogURL:nil bundledCatalogURL:nil];
    for(MHTModule *module in modules)if(![store importLegacyModule:module error:error])return NO;
    return YES;
}
static BOOL runningGames(NSArray *identifiers){for(NSString *identifier in identifiers)if([NSRunningApplication runningApplicationsWithBundleIdentifier:identifier].count)return YES;return NO;}
static BOOL launch(NSURL *app){
    __block BOOL done=NO,ok=NO;NSWorkspaceOpenConfiguration *configuration=[NSWorkspaceOpenConfiguration configuration];configuration.activates=YES;configuration.createsNewApplicationInstance=YES;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:app configuration:configuration completionHandler:^(NSRunningApplication *application,NSError *error){ok=application!=nil && error==nil;done=YES;}];
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:20];while(!done && deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done && ok;
}
int MHTApplyUpdate(NSString *planPath){@autoreleasepool{
    NSURL *planURL=[NSURL fileURLWithPath:planPath],*stage=planURL.URLByDeletingLastPathComponent;
    NSDictionary *plan=[NSDictionary dictionaryWithContentsOfURL:planURL];struct stat attributes;
    if(!plan || lstat(stage.fileSystemRepresentation,&attributes) || !S_ISDIR(attributes.st_mode) || attributes.st_uid!=getuid() || (attributes.st_mode&0077) ||
       ![stage.lastPathComponent hasPrefix:@".TrainerDock-update-"] || ![plan[@"games"] isKindOfClass:NSArray.class] || ![plan[@"destination"] isKindOfClass:NSString.class])return 2;
    NSURL *current=[NSURL fileURLWithPath:plan[@"destination"]],*candidate=[stage URLByAppendingPathComponent:@"TrainerDock.app"];
    if(![stage.URLByDeletingLastPathComponent.path isEqual:current.URLByDeletingLastPathComponent.path] || ![current.pathExtension isEqual:@"app"])return 2;
    pid_t parent=[plan[@"pid"] intValue];char path[PROC_PIDPATHINFO_MAXSIZE];
    if(parent<=1 || !proc_pidpath(parent,path,sizeof(path)) || ![[NSString stringWithUTF8String:path] isEqual:[current URLByAppendingPathComponent:@"Contents/MacOS/TrainerDock"].path])return 2;
    NSError *error=nil;
    if(!MHTValidateUpdateApp(candidate,plan[@"version"],&error))return 2;
    if(![@"ready" writeToURL:[stage URLByAppendingPathComponent:@"Ready"] atomically:YES encoding:NSUTF8StringEncoding error:&error])return 2;
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:60];while(kill(parent,0)==0 && deadline.timeIntervalSinceNow>0)[NSThread sleepForTimeInterval:0.1];
    if(kill(parent,0)==0)return 2; // No force quit, ever.
    NSString *trainerStore=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/TrainerDock/Modules"];
    if(runningGames(plan[@"games"]) || !MHTPreserveBundledTrainers(current,trainerStore,&error) || !MHTSwapUpdate(current,candidate,&error)){
        launch(current);[NSFileManager.defaultManager removeItemAtURL:stage error:nil];return 1;
    }
    if(!launch(current)){
        // Atomic rollback leaves the previously working complete app in place.
        if(!MHTSwapUpdate(current,candidate,&error))return 1;
        launch(current);[NSFileManager.defaultManager removeItemAtURL:stage error:nil];return 1;
    }
    [NSFileManager.defaultManager removeItemAtURL:stage error:nil];return 0;
}}
