// SPDX-License-Identifier: GPL-3.0-only
// Real store, signatures and filesystem boundaries; fixtures never enter products.
#import "MHTTrainerStore.h"
#import "MHTTrainerArchive.h"
#import <sys/mman.h>
#import <fcntl.h>
#import <unistd.h>
static void check(BOOL value,NSString *message){if(!value){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
static NSDictionary *json(NSString *path){return [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:NULL];}
int main(int argc,const char *argv[]){@autoreleasepool{
 check(argc==2,@"one private fixture directory");NSString *base=@(argv[1]);NSDictionary *fixtures=json([base stringByAppendingPathComponent:@"Fixtures.json"]);NSString *identifier=fixtures[@"id"];
 NSURL *bundle=[NSURL fileURLWithPath:[base stringByAppendingPathComponent:@"Catalog.json"]];NSString *root=[base stringByAppendingPathComponent:@"User/Modules"];
 MHTTrainerStore *store=[[MHTTrainerStore alloc]initWithRootDirectory:root catalogURL:[NSURL URLWithString:@"http://not-allowed.invalid/catalog"] bundledCatalogURL:bundle];
 check(store.modules.count==1&&!store.modules.firstObject.installed,@"metadata-only app shows catalog without loading runtime");
 NSArray *versions=[store versionsForIdentifier:identifier];check(versions.count==2&&[versions[0][@"version"] isEqual:@"1.0.1"],@"numeric versions sorted newest first");
 NSDictionary *first=versions[1],*second=versions[0];NSError *error=nil;
 MHTModule *old=[store installArchive:[NSURL fileURLWithPath:[base stringByAppendingPathComponent:@"old.zip"]] version:first forIdentifier:identifier error:&error];
 check(old&&old.installed&&store.modules.firstObject.updateAvailable,[NSString stringWithFormat:@"valid signed old package installed with update notice: %@",error]);
 NSData *oldBytes=[NSData dataWithContentsOfFile:old.runtimePath];
 MHTModule *new=[store installArchive:[NSURL fileURLWithPath:[base stringByAppendingPathComponent:@"new.zip"]] version:second forIdentifier:identifier error:&error];
 check(new&&[NSFileManager.defaultManager fileExistsAtPath:old.runtimePath]&&[oldBytes isEqual:[NSData dataWithContentsOfFile:old.runtimePath]],@"new version keeps old bytes and directories");
 check([store installedVersionsForIdentifier:identifier].count==2,@"both versions selectable");
 check([store selectModule:old error:&error]&&[store.modules.firstObject.directory isEqual:old.directory],@"explicit older selection persists");
 MHTTrainerStore *offline=[[MHTTrainerStore alloc]initWithRootDirectory:root catalogURL:nil bundledCatalogURL:nil];
 check([offline.modules.firstObject.directory isEqual:old.directory],[NSString stringWithFormat:@"installed old version remains usable offline without catalog: old=%@ offline=%@ preference=%@",old.directory,offline.modules.firstObject.directory,[NSUserDefaults.standardUserDefaults stringForKey:[@"MHT.TrainerVersion." stringByAppendingString:identifier]]]);
 NSDictionary *actualProfile=nil,*game=nil;
 MHTModule *matched=[store moduleForIdentifier:identifier profile:new.profiles[0] path:[base stringByAppendingPathComponent:@"OldGame.app"] matchingProfile:&actualProfile game:&game error:&error];
 check([matched.directory isEqual:old.directory]&&[actualProfile[@"id"] isEqual:@"steam-old.1.0"]&&game,@"exact original build selects old version even when profile IDs differ");
 matched=[store moduleForIdentifier:identifier profile:new.profiles[0] path:[base stringByAppendingPathComponent:@"NewGame.app"] matchingProfile:&actualProfile game:&game error:&error];
 check([matched.directory isEqual:new.directory]&&[actualProfile[@"id"] isEqual:@"steam-new.1.0"],@"new original build selects its actual supported profile");
 NSMutableDictionary *foreign=[new.profiles[0] mutableCopy];foreign[@"store"]=@"Mac App Store";
 check(![store moduleForIdentifier:identifier profile:foreign path:[base stringByAppendingPathComponent:@"OldGame.app"] error:&error],@"matching never crosses store identities");
 check(![store removeModule:old protectedRuntimePaths:[NSSet setWithObject:old.runtimePath] error:&error],@"running session path cannot be removed");
 int fd=open(old.runtimePath.fileSystemRepresentation,O_RDONLY);check(fd>=0,@"fixture runtime readable");void *mapped=mmap(NULL,oldBytes.length,PROT_READ,MAP_PRIVATE,fd,0);close(fd);check(mapped!=MAP_FAILED,@"fixture runtime mapped without executing any code");
 check(![store removeModule:old protectedRuntimePaths:[NSSet set] error:&error]&&[NSFileManager.defaultManager fileExistsAtPath:old.runtimePath],@"actual mapped file protects externally used version");munmap(mapped,oldBytes.length);
 check([store removeModule:old protectedRuntimePaths:[NSSet set] error:&error]&&![NSFileManager.defaultManager fileExistsAtPath:old.directory]&&new.installed,[NSString stringWithFormat:@"delete removes only requested unused version: %@",error]);
 NSArray *legacy=[MHTModule loadModules:[base stringByAppendingPathComponent:@"Legacy"] errors:[NSMutableArray new]];
 check(legacy.count==1,@"legacy fixture recognized");MHTModule *imported=[store importLegacyModule:legacy[0] error:&error];
 check(imported&&[imported.installRevision hasPrefix:@"legacy-"]&&[imported.version isEqual:new.version]&&![imported.directory isEqual:new.directory]&&((MHTModule *)legacy[0]).installed,@"legacy import preserves source and same-version download independently");
 check([store.modules.firstObject.directory isEqual:new.directory],@"equal-version numeric download is the deterministic default after legacy import");
 check([store selectModule:imported error:&error]&&[store.modules.firstObject.directory isEqual:imported.directory]&&store.modules.firstObject.updateAvailable,@"explicit legacy selection stays selected and offers verified numeric package update");
 check([store selectModule:new error:&error],@"numeric package can be reselected explicitly");
 check([store importLegacyModule:legacy[0] error:&error]&&[store installedVersionsForIdentifier:identifier].count==2,@"repeated import is content-idempotent");
 NSString *extra=[imported.directory.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Foreign.txt"];[@"user data" writeToFile:extra atomically:YES encoding:NSUTF8StringEncoding error:NULL];
 check(![store removeModule:imported protectedRuntimePaths:[NSSet set] error:&error],@"foreign files in version container remain protected");[NSFileManager.defaultManager removeItemAtPath:extra error:NULL];
 check([store removeModule:imported protectedRuntimePaths:[NSSet set] error:&error]&&new.installed,@"delete imported version preserves current numeric version");
 for(NSDictionary *bad in fixtures[@"badArchives"]){NSError *failure=nil;check(![store installArchive:[NSURL fileURLWithPath:[base stringByAppendingPathComponent:bad[@"file"]]] version:bad[@"entry"] forIdentifier:identifier error:&failure]&&failure,[NSString stringWithFormat:@"malicious archive rejected: %@",bad[@"file"]]);}
 check(new.installed&&[store installedVersionsForIdentifier:identifier].count==1,@"failed downloads/installations never replace existing versions");
 for(id bad in fixtures[@"badCatalogs"])check(![MHTTrainerStore validatedCatalog:bad requireDownloads:YES error:&error],@"malformed/foreign catalog rejected");
 NSDictionary *metadata=fixtures[@"metadataOnly"];check([MHTTrainerStore validatedCatalog:metadata requireDownloads:NO error:&error]&&![MHTTrainerStore validatedCatalog:metadata requireDownloads:YES error:&error],@"unpublished local metadata is not a fabricated download");
 MHTTrainerStore *metadataStore=[[MHTTrainerStore alloc]initWithRootDirectory:[base stringByAppendingPathComponent:@"Empty/Modules"] catalogURL:nil bundledCatalogURL:[NSURL fileURLWithPath:[base stringByAppendingPathComponent:@"MetadataOnly.json"]]];
 check(![metadataStore.modules.firstObject.catalogVersion[@"downloadAvailable"] boolValue],@"unpublished metadata explicitly disables download");
 __block BOOL refreshed=NO;[store refreshCatalogWithCompletion:^(NSError *failure){check(failure!=nil,@"invalid source refresh fails safely");refreshed=YES;}];
 NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];while(!refreshed&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
 check(refreshed&&store.modules.count==1&&new.installed,@"refresh failure retains existing offline catalog and trainer");
 [NSUserDefaults.standardUserDefaults removeObjectForKey:[@"MHT.TrainerVersion." stringByAppendingString:identifier]];
 puts("PASS: signed versioned packages, offline metadata, old/new build resolution, retained versions, legacy collisions, mapped/session deletion guards, archive/catalog attacks and failure rollback. No games started or runtime code loaded.");
}return 0;}
