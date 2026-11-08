// SPDX-License-Identifier: GPL-3.0-only
// Opt-in real GitHub boundary test. Never accesses the user's trainer store.
#import "MHTTrainerStore.h"
#import <sys/stat.h>
#import <limits.h>
#import <unistd.h>
static void fail(NSString *message){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}
static void waitFor(BOOL *finished,NSTimeInterval timeout){NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:timeout];while(!*finished&&deadline.timeIntervalSinceNow>0)[NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];if(!*finished)fail(@"Zeitlimit für GitHub-Prüfung erreicht.");}
int main(int argc,const char *argv[]){@autoreleasepool{
 if(argc<3||argc>4||strcmp(argv[1],"--tmp-test")){fprintf(stderr,"usage: DownloadSmoke --tmp-test /private/tmp/TrainerDock-download-smoke-UNIQUE [trainer-id]\n");return 2;}
 NSString *base=@(argv[2]),*identifier=argc==4?@(argv[3]):@"balatro";char parent[PATH_MAX];
 if(![base.stringByDeletingLastPathComponent isEqual:@"/private/tmp"]||![base.lastPathComponent hasPrefix:@"TrainerDock-download-smoke-"]||base.lastPathComponent.length<=strlen("TrainerDock-download-smoke-")||!realpath(base.stringByDeletingLastPathComponent.fileSystemRepresentation,parent)||strcmp(parent,"/private/tmp"))fail(@"Nur ein frischer eigener Prüfpfad direkt unter /private/tmp ist zulässig.");
 struct stat original;if(!lstat(base.fileSystemRepresentation,&original)||errno!=ENOENT)fail(@"Der Prüfpfad muss neu und noch nicht vorhanden sein.");
 NSError *error=nil;if(![NSFileManager.defaultManager createDirectoryAtPath:base withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:&error])fail(error.localizedDescription);
 NSString *root=[base stringByAppendingPathComponent:@"Modules"];MHTTrainerStore *store=[[MHTTrainerStore alloc]initWithRootDirectory:root catalogURL:[NSURL URLWithString:MHTTrainerCatalogAddress] bundledCatalogURL:nil];
 __block BOOL finished=NO;__block NSError *failure=nil;
 [store refreshCatalogWithCompletion:^(NSError *value){failure=value;finished=YES;}];waitFor(&finished,160);if(failure)fail(failure.localizedDescription);
 NSDictionary *version=[store versionsForIdentifier:identifier].firstObject;if(![version[@"downloadAvailable"] boolValue])fail(@"Der gewählte Trainer hat keinen veröffentlichten geprüften Download.");
 __block MHTModule *installed=nil;finished=NO;[store installVersion:version forIdentifier:identifier completion:^(MHTModule *module,NSError *value){installed=module;failure=value;finished=YES;}];waitFor(&finished,180);if(failure||!installed.installed||![installed.manifest isEqual:version[@"manifest"]])fail(failure.localizedDescription?:@"Installierte Metadaten weichen vom GitHub-Katalog ab.");
 if(![installed.directory hasPrefix:[root stringByAppendingString:@"/"]]||[store installedVersionsForIdentifier:identifier].count!=1)fail(@"Die Installation liegt außerhalb des isolierten Prüfbestands.");
 NSString *package=installed.directory;if(![store removeModule:installed protectedRuntimePaths:[NSSet set] error:&error]||[NSFileManager.defaultManager fileExistsAtPath:package]||[store installedVersionsForIdentifier:identifier].count)fail(error.localizedDescription?:@"Die isolierte Version wurde nicht vollständig entfernt.");
 // Catalog metadata intentionally remains visible after deleting the local module.
 NSArray *remaining=[NSFileManager.defaultManager contentsOfDirectoryAtPath:root error:&error];for(NSString *entry in remaining){NSString *path=[root stringByAppendingPathComponent:entry];if([NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:NULL].count)fail(@"Der isolierte Prüfbestand ist nicht leer.");}
 if(![NSFileManager.defaultManager removeItemAtPath:base error:&error])fail(error.localizedDescription);
 printf("PASS: official GitHub catalog, %s %s download, SHA-256, code seal, manifest, isolated install/delete and cleanup. No game or trainer runtime executed.\n",identifier.UTF8String,[version[@"version"] UTF8String]);
}return 0;}
