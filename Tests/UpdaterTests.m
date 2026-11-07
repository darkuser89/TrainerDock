// SPDX-License-Identifier: GPL-3.0-only
#import "MHTUpdater.h"
#import "MHTUpdatePackage.h"
#import <archive.h>
#import <archive_entry.h>
@interface MHTUpdater (Checks)
- (void)scheduleInstallation;
- (void)install;
- (void)cancel:(id)sender;
@end
@interface UpdateProbe : MHTUpdater
@property(nonatomic) NSUInteger installs;
@end
@implementation UpdateProbe
- (void)install{self.installs++;}
@end
static void check(BOOL valid,const char *message){if(!valid){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static NSDictionary *release(void){return @{@"tag_name":@"v1.1.0",@"draft":@NO,@"prerelease":@NO,@"assets":@[@{@"name":@"TrainerDock-macOS-arm64.zip",@"browser_download_url":@"https://github.com/darkuser89/TrainerDock/releases/download/v1.1.0/TrainerDock-macOS-arm64.zip",@"digest":@"sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",@"size":@3}]};}
static void zip(NSURL *url,NSString *name,BOOL link){
    struct archive *writer=archive_write_new();archive_write_set_format_zip(writer);check(archive_write_open_filename(writer,url.fileSystemRepresentation)==ARCHIVE_OK,"create archive fixture");
    struct archive_entry *entry=archive_entry_new();archive_entry_set_pathname(entry,name.UTF8String);archive_entry_set_filetype(entry,link ? AE_IFLNK : AE_IFREG);archive_entry_set_perm(entry,0644);archive_entry_set_size(entry,link ? 0 : 3);
    if(link)archive_entry_set_symlink(entry,"/tmp");
    check(archive_write_header(writer,entry)==ARCHIVE_OK,"write fixture entry");if(!link)check(archive_write_data(writer,"abc",3)==3,"write fixture data");archive_entry_free(entry);archive_write_close(writer);archive_write_free(writer);
}
int main(int argc,const char *argv[]){@autoreleasepool{
    [NSApplication sharedApplication];NSError *error=nil;
    NSDictionary *new=MHTNewRelease(release(),@"1.0.9",&error);check(new && !error,"new stable release");
    check(!MHTNewRelease(release(),@"1.1.0",NULL) && !MHTNewRelease(release(),@"1.10.0",NULL),"no equal version or downgrade");
    NSMutableDictionary *draft=[release() mutableCopy];draft[@"prerelease"]=@YES;check(!MHTNewRelease(draft,@"1.0.0",NULL),"ignore prerelease");draft[@"prerelease"]=@NO;draft[@"draft"]=@YES;check(!MHTNewRelease(draft,@"1.0.0",NULL),"ignore draft");
    for(NSString *key in @[@"digest",@"browser_download_url",@"size"]){
        NSMutableDictionary *invalid=[release() mutableCopy],*asset=[invalid[@"assets"][0] mutableCopy];asset[key]=[key isEqual:@"size"] ? (id)@0 : (id)@"https://elsewhere.invalid/file.zip";invalid[@"assets"]=@[asset];
        check(!MHTNewRelease(invalid,@"1.0.0",NULL),"reject foreign download, bad size or missing hash");
    }
    check(!MHTNewRelease((id)NSNull.null,@"1.0.0",NULL),"reject malformed API response");
    NSURL *root=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    check([NSFileManager.defaultManager createDirectoryAtURL:root withIntermediateDirectories:NO attributes:nil error:&error],"temporary test directory");
    NSURL *archive=[root URLByAppendingPathComponent:@"Update.zip"],*extract=[root URLByAppendingPathComponent:@"Extract"];
    [@"abc" writeToURL:archive atomically:YES encoding:NSUTF8StringEncoding error:NULL];check(MHTVerifyUpdateArchive(archive,new,&error),"valid SHA-256");
    [@"abd" writeToURL:archive atomically:YES encoding:NSUTF8StringEncoding error:NULL];check(!MHTVerifyUpdateArchive(archive,new,NULL),"corrupted archive rejected before extraction");
    NSArray *names=@[@"TrainerDock.app/Contents/test",@"../outside",@"/absolute",@"TrainerDock.app/../outside",@"Other.app/test",@"TrainerDock.app/link"];
    for(NSUInteger i=0;i<names.count;i++){
        zip(archive,names[i],i==names.count-1);BOOL valid=MHTExtractUpdate(archive,extract,NULL);check(valid==(i==0),"safe extraction rejects traversal, foreign roots and symlinks");
        if(i==0)check([[NSString stringWithContentsOfURL:[extract URLByAppendingPathComponent:names[i]] encoding:NSUTF8StringEncoding error:NULL] isEqual:@"abc"],"extracted exact bytes");
        [NSFileManager.defaultManager removeItemAtURL:extract error:NULL];
    }
    check(!MHTValidateUpdateApp(root,@"1.1.0",NULL),"reject missing app identity and trainers");
    if(argc==3){
        NSURL *package=[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        check(MHTExtractUpdate(package,extract,&error),error.localizedDescription.UTF8String ?: "real release extraction");
        check(MHTValidateUpdateApp([extract URLByAppendingPathComponent:@"TrainerDock.app"],[NSString stringWithUTF8String:argv[2]],&error),error.localizedDescription.UTF8String ?: "real release validation");
    }
    NSURL *current=[root URLByAppendingPathComponent:@"Current.app"],*candidate=[root URLByAppendingPathComponent:@"New.app"];
    for(NSURL *url in @[current,candidate])[NSFileManager.defaultManager createDirectoryAtURL:url withIntermediateDirectories:NO attributes:nil error:NULL];
    [@"old" writeToURL:[current URLByAppendingPathComponent:@"value"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [@"new" writeToURL:[candidate URLByAppendingPathComponent:@"value"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    check(MHTSwapUpdate(current,candidate,&error),"atomic app exchange");check([[NSString stringWithContentsOfURL:[current URLByAppendingPathComponent:@"value"] encoding:NSUTF8StringEncoding error:NULL] isEqual:@"new"],"new version installed");
    check(MHTSwapUpdate(current,candidate,&error),"atomic rollback");check([[NSString stringWithContentsOfURL:[current URLByAppendingPathComponent:@"value"] encoding:NSUTF8StringEncoding error:NULL] isEqual:@"old"],"old version restored");
    __block BOOL running=YES;UpdateProbe *updater=[[UpdateProbe alloc]initWithRunningGames:^BOOL{return running;}];
    [updater scheduleInstallation];check(updater.installationDeferred && !updater.installs,"running game defers installation");
    running=NO;NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];while(!updater.installs && deadline.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    check(updater.installs==1 && !updater.installationDeferred,"regular game end resumes once");
    running=YES;[updater scheduleInstallation];[updater cancel:nil];running=NO;[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.1]];
    check(updater.installs==1 && !updater.installationDeferred,"cancelled update cannot install later");
    [NSFileManager.defaultManager removeItemAtURL:root error:NULL];
    puts("PASS: release/version validation, checksum corruption, secure ZIP extraction, atomic exchange/rollback, game deferral and cancellation. No network or games launched.");
}return 0;}
