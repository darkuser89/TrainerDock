// SPDX-License-Identifier: GPL-3.0-only
#import "MHTUpdater.h"
#import "MHTUpdatePackage.h"
#import <sys/stat.h>
#import <unistd.h>
static NSString *const automaticKey=@"TrainerDock.AutomaticUpdates";
static NSString *const checkedKey=@"TrainerDock.LastUpdateCheck";
@interface MHTUpdater () <NSURLSessionDownloadDelegate>
@property(nonatomic,copy) BOOL (^runningGames)(void);
@property(nonatomic) NSURLSession *session;
@property(nonatomic) NSURLSessionTask *task;
@property(nonatomic) NSTimer *checkTimer,*waitTimer;
@property(nonatomic) NSDictionary *candidateRelease;
@property(nonatomic) NSURL *stage;
@property(nonatomic) NSPanel *panel;
@property(nonatomic) NSProgressIndicator *progress;
@property(nonatomic) NSTextField *status;
@property(nonatomic) BOOL busy,pendingInstall,extracting,handingOff;
@property(nonatomic) NSUInteger generation;
@end
@implementation MHTUpdater
- (instancetype)initWithRunningGames:(BOOL (^)(void))runningGames {
    if((self=[super init])){
        self.runningGames=runningGames;
        [NSUserDefaults.standardUserDefaults registerDefaults:@{automaticKey:@YES}];
        NSURLSessionConfiguration *configuration=NSURLSessionConfiguration.ephemeralSessionConfiguration;
        configuration.timeoutIntervalForRequest=30;configuration.timeoutIntervalForResource=600;
        configuration.HTTPAdditionalHeaders=@{@"User-Agent":@"TrainerDock-Updater",@"Accept":@"application/vnd.github+json",@"X-GitHub-Api-Version":@"2022-11-28"};
        self.session=[NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    }return self;
}
- (void)start {
    __weak MHTUpdater *weakSelf=self;
    self.checkTimer=[NSTimer scheduledTimerWithTimeInterval:3600 repeats:YES block:^(NSTimer *timer){(void)timer;[weakSelf automaticCheck];}];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{[weakSelf automaticCheck];});
}
- (void)automaticCheck {
    if(![NSUserDefaults.standardUserDefaults boolForKey:automaticKey] || self.busy)return;
    NSDate *last=[NSUserDefaults.standardUserDefaults objectForKey:checkedKey];
    if([last isKindOfClass:NSDate.class] && [last timeIntervalSinceNow]>-24*3600)return;
    [self check:NO];
}
- (BOOL)installationDeferred{return self.pendingInstall;}
- (void)checkForUpdates:(id)sender{(void)sender;[self check:YES];}
- (void)toggleAutomaticChecks:(id)sender{(void)sender;[NSUserDefaults.standardUserDefaults setBool:![NSUserDefaults.standardUserDefaults boolForKey:automaticKey] forKey:automaticKey];}
- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
    if(item.action==@selector(checkForUpdates:))return !self.busy;
    if(item.action==@selector(toggleAutomaticChecks:)){
        if([(id)item isKindOfClass:NSMenuItem.class])[(NSMenuItem *)item setState:[NSUserDefaults.standardUserDefaults boolForKey:automaticKey] ? NSControlStateValueOn : NSControlStateValueOff];return YES;
    }return NO;
}
- (void)message:(NSString *)title detail:(NSString *)detail {
    NSAlert *alert=[NSAlert new];alert.messageText=title;alert.informativeText=detail ?: @"";[alert addButtonWithTitle:@"OK"];
    [alert runModal];
}
- (void)check:(BOOL)manual {
    if(self.busy)return;self.busy=YES;NSUInteger generation=++self.generation;
    NSURL *url=[NSURL URLWithString:@"https://api.github.com/repos/darkuser89/TrainerDock/releases/latest"];
    __weak MHTUpdater *weakSelf=self;
    self.task=[self.session dataTaskWithURL:url completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            MHTUpdater *self=weakSelf;if(!self || generation!=self.generation)return;
            self.busy=NO;self.task=nil;NSError *failure=error;NSDictionary *release=nil;
            if(!failure && [(NSHTTPURLResponse *)response statusCode]!=200)failure=[NSError errorWithDomain:@"TrainerDock.Update" code:1 userInfo:@{NSLocalizedDescriptionKey:@"GitHub ist gerade nicht erreichbar. Bitte später erneut versuchen."}];
            if(!failure && data.length<=2*1024*1024){
                id json=[NSJSONSerialization JSONObjectWithData:data options:0 error:&failure];
                if(!failure)release=MHTNewRelease(json,NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"],&failure);
            }else if(!failure)failure=[NSError errorWithDomain:@"TrainerDock.Update" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Die GitHub-Antwort ist zu groß."}];
            if(failure){if(manual)[self message:@"Updateprüfung fehlgeschlagen" detail:failure.localizedDescription];return;}
            [NSUserDefaults.standardUserDefaults setObject:NSDate.date forKey:checkedKey];
            if(!release){if(manual)[self message:@"TrainerDock ist aktuell" detail:[NSString stringWithFormat:@"Version %@ ist installiert.",NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]]];return;}
            NSAlert *alert=[NSAlert new];alert.messageText=[NSString stringWithFormat:@"TrainerDock %@ ist verfügbar",release[@"version"]];
            alert.informativeText=@"App und Trainer gemeinsam herunterladen und installieren? TrainerDock wird anschließend neu gestartet.";
            [alert addButtonWithTitle:@"Laden und installieren"];[alert addButtonWithTitle:@"Später"];
            if([alert runModal]==NSAlertFirstButtonReturn)[self download:release];
        });
    }];[self.task resume];
}
- (void)showProgress {
    self.panel=[[NSPanel alloc]initWithContentRect:NSMakeRect(0,0,420,130) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];self.panel.title=@"TrainerDock aktualisieren";
    self.status=[NSTextField labelWithString:@"Update wird geladen …"];self.status.frame=NSMakeRect(20,82,380,22);[self.panel.contentView addSubview:self.status];
    self.progress=[[NSProgressIndicator alloc]initWithFrame:NSMakeRect(20,56,380,16)];self.progress.indeterminate=NO;self.progress.minValue=0;self.progress.maxValue=1;[self.panel.contentView addSubview:self.progress];
    NSButton *cancel=[NSButton buttonWithTitle:@"Abbrechen" target:self action:@selector(cancel:)];cancel.frame=NSMakeRect(290,12,110,30);cancel.keyEquivalent=@"\e";[self.panel.contentView addSubview:cancel];
    [self.panel center];[self.panel makeKeyAndOrderFront:nil];
}
- (void)download:(NSDictionary *)release {
    NSURL *destination=NSBundle.mainBundle.bundleURL.URLByResolvingSymlinksInPath;
    NSString *pattern=[destination.URLByDeletingLastPathComponent.path stringByAppendingPathComponent:@".TrainerDock-update-XXXXXX"];
    char *buffer=strdup(pattern.fileSystemRepresentation);char *created=mkdtemp(buffer);
    if(created)self.stage=[NSURL fileURLWithFileSystemRepresentation:created isDirectory:YES relativeToURL:nil];free(buffer);
    if(!self.stage){[self message:@"Update kann nicht installiert werden" detail:@"Bitte TrainerDock zuerst in einen beschreibbaren Ordner verschieben, zum Beispiel Programme im eigenen Benutzerordner."];return;}
    self.busy=YES;self.candidateRelease=release;[self showProgress];
    self.task=[self.session downloadTaskWithURL:[NSURL URLWithString:release[@"url"]]];[self.task resume];
}
- (void)cancel:(id)sender {
    (void)sender;if(self.handingOff)return;++self.generation;[self.task cancel];self.task=nil;[self.waitTimer invalidate];self.waitTimer=nil;self.pendingInstall=NO;self.busy=NO;
    [self.panel close];self.panel=nil;
    // The download/extraction completion owns cleanup while background work is in flight.
    BOOL extracting=self.extracting;self.extracting=NO;
    if(self.stage && !extracting)[NSFileManager.defaultManager removeItemAtURL:self.stage error:nil];
    self.stage=nil;self.candidateRelease=nil;
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    (void)session;(void)task;(void)response;NSString *host=request.URL.host.lowercaseString;
    BOOL allowed=[request.URL.scheme isEqual:@"https"] && [@[@"github.com",@"api.github.com",@"release-assets.githubusercontent.com",@"objects.githubusercontent.com"] containsObject:host];
    completionHandler(allowed ? request : nil);
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)bytes totalBytesWritten:(int64_t)total totalBytesExpectedToWrite:(int64_t)expected {
    (void)session;(void)bytes;(void)expected;
    dispatch_async(dispatch_get_main_queue(),^{if(task!=self.task)return;if(total>[self.candidateRelease[@"size"] longLongValue]){[task cancel];return;}self.progress.doubleValue=(double)total/[self.candidateRelease[@"size"] doubleValue];});
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:(NSURL *)location {
    (void)session;
    // URLSession removes location after this callback: finish validation/extraction here, off main.
    __block NSDictionary *release=nil;__block NSURL *stage=nil;__block NSUInteger generation=0;
    dispatch_sync(dispatch_get_main_queue(),^{if(task==self.task){release=self.candidateRelease;stage=self.stage;generation=self.generation;self.extracting=YES;self.status.stringValue=@"Update wird geprüft …";}});
    if(!stage)return;NSError *error=nil;NSURL *archive=[stage URLByAppendingPathComponent:@"Update.zip"];
    BOOL ok=[(NSHTTPURLResponse *)task.response statusCode]==200 && [NSFileManager.defaultManager moveItemAtURL:location toURL:archive error:&error];
    if(ok)ok=MHTVerifyUpdateArchive(archive,release,&error) && MHTExtractUpdate(archive,stage,&error) && MHTValidateUpdateApp([stage URLByAppendingPathComponent:@"TrainerDock.app"],release[@"version"],&error);
    [NSFileManager.defaultManager removeItemAtURL:archive error:nil];
    dispatch_async(dispatch_get_main_queue(),^{
        if(generation!=self.generation || task!=self.task){[NSFileManager.defaultManager removeItemAtURL:stage error:nil];return;}
        self.task=nil;self.extracting=NO;
        if(!ok){[self finishWithError:error.localizedDescription ?: @"Das Update konnte nicht geladen werden."];return;}
        [self scheduleInstallation];
    });
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    (void)session;if(!error)return;
    dispatch_async(dispatch_get_main_queue(),^{if(task!=self.task)return;self.task=nil;[self finishWithError:error.localizedDescription];});
}
- (void)finishWithError:(NSString *)message {
    [self.waitTimer invalidate];self.waitTimer=nil;self.pendingInstall=NO;self.busy=NO;self.handingOff=NO;self.candidateRelease=nil;
    [self.panel close];self.panel=nil;if(self.stage)[NSFileManager.defaultManager removeItemAtURL:self.stage error:nil];self.stage=nil;
    if(message)[self message:@"Update nicht installiert" detail:message];
}
- (void)scheduleInstallation {
    if(self.runningGames && self.runningGames()){
        self.pendingInstall=YES;self.status.stringValue=@"Bereit · wartet auf das Ende deiner Spiele";
        __weak MHTUpdater *weakSelf=self;self.waitTimer=[NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer){MHTUpdater *self=weakSelf;if(!self){[timer invalidate];return;}if(self.runningGames && self.runningGames())return;[timer invalidate];self.waitTimer=nil;self.pendingInstall=NO;[self install];}];return;
    }[self install];
}
- (void)install {
    if(self.runningGames && self.runningGames()){[self scheduleInstallation];return;}
    self.handingOff=YES;for(NSView *view in self.panel.contentView.subviews)if([view isKindOfClass:NSButton.class])[(NSButton *)view setEnabled:NO];
    self.status.stringValue=@"TrainerDock wird neu gestartet …";
    NSURL *stage=self.stage,*app=NSBundle.mainBundle.bundleURL.URLByResolvingSymlinksInPath,*helper=[stage URLByAppendingPathComponent:@"Updater"],*plan=[stage URLByAppendingPathComponent:@"Plan.plist"];
    NSMutableSet *games=[NSMutableSet new];
    NSArray *roots=@[[app URLByAppendingPathComponent:@"Contents/Resources/Modules"],[app.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Modules"],
        [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/TrainerDock/Modules"]],
        [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/MHT/Modules"]]];
    for(NSURL *root in roots)for(NSURL *module in [NSFileManager.defaultManager contentsOfDirectoryAtURL:root includingPropertiesForKeys:nil options:0 error:nil]){
        NSData *data=[NSData dataWithContentsOfURL:[module URLByAppendingPathComponent:@"Module.json"]];id json=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if(![json isKindOfClass:NSDictionary.class] || ![json[@"profiles"] isKindOfClass:NSArray.class])continue;
        for(id profile in json[@"profiles"])if([profile isKindOfClass:NSDictionary.class] && [profile[@"bundleIdentifier"] isKindOfClass:NSString.class])[games addObject:profile[@"bundleIdentifier"]];
    }
    NSError *error=nil;
    NSDictionary *document=@{@"destination":app.path,@"version":self.candidateRelease[@"version"],@"pid":@(getpid()),@"games":games.allObjects};
    if(![NSFileManager.defaultManager copyItemAtURL:NSBundle.mainBundle.executableURL toURL:helper error:&error] || ![document writeToURL:plan error:&error]){[self finishWithError:error.localizedDescription];return;}
    chmod(plan.fileSystemRepresentation,0600);
    NSTask *installer=[NSTask new];installer.executableURL=helper;installer.arguments=@[@"--apply-update",plan.path];installer.standardOutput=NSFileHandle.fileHandleWithNullDevice;installer.standardError=NSFileHandle.fileHandleWithNullDevice;
    if(![installer launchAndReturnError:&error]){[self finishWithError:error.localizedDescription];return;}
    NSUInteger generation=self.generation;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
        NSURL *ready=[stage URLByAppendingPathComponent:@"Ready"];NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
        while(installer.running && ![NSFileManager.defaultManager fileExistsAtPath:ready.path] && deadline.timeIntervalSinceNow>0)[NSThread sleepForTimeInterval:0.05];
        BOOL ok=[NSFileManager.defaultManager fileExistsAtPath:ready.path];
        dispatch_async(dispatch_get_main_queue(),^{if(generation!=self.generation)return;if(ok){[NSApp terminate:nil];}else [self finishWithError:@"Der Updatehelfer konnte nicht gestartet werden."];});
    });
}
@end
