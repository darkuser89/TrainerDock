// SPDX-License-Identifier: GPL-3.0-only
// Only synthetic manifests, process snapshots and URL callbacks. No Epic/game launch.
#import "../../Core/MHTEpicLaunch.m"

static NSUInteger checks=0;
static void check(BOOL condition,NSString *label){checks++;if(!condition){fprintf(stderr,"Epic fixture failed: %s\n",label.UTF8String);exit(1);}}
static BOOL pump(BOOL (^done)(void)){
    NSTimeInterval end=NSDate.date.timeIntervalSince1970+4;
    while(!done()&&NSDate.date.timeIntervalSince1970<end)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    return done();
}
static NSDictionary *fixture(NSString *root){
    NSFileManager *fm=NSFileManager.defaultManager;
    NSString *install=[root stringByAppendingPathComponent:@"install"],*app=[install stringByAppendingPathComponent:@"Fixture.app"],*mac=[app stringByAppendingPathComponent:@"Contents/MacOS"],*manifests=[root stringByAppendingPathComponent:@"manifests"],*state=[root stringByAppendingPathComponent:@"state"];
    [fm createDirectoryAtPath:mac withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL];[fm createDirectoryAtPath:manifests withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL];
    NSString *target=[mac stringByAppendingPathComponent:@"Fixture"],*path=[manifests stringByAppendingPathComponent:@"fixture.item"];
    [@"Synthetic original; never executed by the service tests." writeToFile:target atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    [@{@"CFBundleIdentifier":@"local.trainerdock.synthetic",@"CFBundleExecutable":@"Fixture",@"CFBundlePackageType":@"APPL"}writeToFile:[[app stringByAppendingPathComponent:@"Contents"]stringByAppendingPathComponent:@"Info.plist"] atomically:NO];
    NSDictionary *item=@{@"AppName":@"fixture-app",@"CatalogNamespace":@"fixture-space",@"CatalogItemId":@"fixture-item",@"InstallLocation":install,@"LaunchExecutable":@"Fixture.app/Contents/MacOS/Fixture",@"LaunchCommand":@"",@"bNeedsValidation":@NO,@"Unrelated":@[@1,@2]};
    NSData *original=[NSJSONSerialization dataWithJSONObject:item options:NSJSONWritingPrettyPrinted error:NULL];[original writeToFile:path atomically:NO];
    return @{@"install":install,@"app":app,@"target":target,@"manifests":manifests,@"state":state,@"path":path,@"item":item,@"original":original,
             @"game":@{@"path":app,@"executable":target},@"profile":@{@"epicAppName":@"fixture-app",@"epicNamespace":@"fixture-space",@"bundleIdentifier":@"local.trainerdock.synthetic",@"executable":@"Fixture"},
             @"environment":@{@"MHT_TARGET":target,@"MHT_SESSION":@"synthetic-session",@"DYLD_INSERT_LIBRARIES":@"/private/tmp/own-synthetic-library.dylib"}};
}
static NSDictionary *journalFixture(NSDictionary *f){
    check(EPrivateDirectory(f[@"state"],YES),@"private fixture state");NSString *nonce=@"TrainerDock-Epic-synthetic",*broker=[f[@"install"]stringByAppendingPathComponent:nonce],*config=[broker stringByAppendingString:@".json"],*receipt=[f[@"state"]stringByAppendingPathComponent:[nonce stringByAppendingString:@".receipt"]];
    NSData *own=[@"Own synthetic helper bytes"dataUsingEncoding:NSUTF8StringEncoding],*settings=[@"Own synthetic configuration"dataUsingEncoding:NSUTF8StringEncoding],*mutation=EPatch(f[@"original"],nonce);
    check(EWriteNew(broker,own,0700)&&EWriteNew(config,settings,0600),@"own fixture files");
    NSDictionary *journal=@{@"version":@1,@"nonce":nonce,@"manifest":f[@"path"],@"target":f[@"target"],@"broker":broker,@"config":config,@"receipt":receipt,@"original":[f[@"original"]base64EncodedStringWithOptions:0],@"mutation":[mutation base64EncodedStringWithOptions:0],@"mode":@0600,@"brokerSHA256":EHashData(own),@"configSHA256":EHashData(settings)};
    check(EAtomic([f[@"state"]stringByAppendingPathComponent:@"epic.json"],EEncode(journal),0600)&&EAtomic(f[@"path"],mutation,0600),@"durable fixture journal before mutation");return journal;
}
static MHTEpicLaunchService *service(NSDictionary *f,NSString *broker,BOOL (^client)(void),NSDictionary *(^processes)(void),BOOL (^open)(NSURL *)){
    return [[MHTEpicLaunchService alloc]initWithBrokerURL:[NSURL fileURLWithPath:broker] manifestDirectory:f[@"manifests"] stateDirectory:f[@"state"] clientRunning:client processes:processes openURI:open];
}
static void pureTests(NSDictionary *f){
    NSData *input=[@" \n{\"nested\":{\"LaunchExecutable\":\"keep\"}, \"Launch\\u0045xecutable\" : \"old/path\", \"other\":[1,2]}\n"dataUsingEncoding:NSUTF8StringEncoding];
    NSString *patched=[[NSString alloc]initWithData:EPatch(input,@"own-helper") encoding:NSUTF8StringEncoding];
    check([patched isEqual:@" \n{\"nested\":{\"LaunchExecutable\":\"keep\"}, \"Launch\\u0045xecutable\" : \"own-helper\", \"other\":[1,2]}\n"],@"only one exact original JSON string changes");
    check(!EPatch([@"{\"LaunchExecutable\":\"a\",\"Launch\\u0045xecutable\":\"b\"}"dataUsingEncoding:NSUTF8StringEncoding],@"own"),@"duplicate decoded JSON key rejected");
    check(EFindManifest(f[@"manifests"],f[@"game"],f[@"profile"])!=nil,@"exact manifest identity");
    NSMutableDictionary *wrong=[f[@"profile"]mutableCopy];wrong[@"epicNamespace"]=@"other";check(!EFindManifest(f[@"manifests"],f[@"game"],wrong),@"wrong namespace rejected");
    NSMutableDictionary *item=[f[@"item"]mutableCopy];item[@"LaunchExecutable"]=@"../elsewhere";[EEncode(item)writeToFile:f[@"path"] atomically:NO];check(!EFindManifest(f[@"manifests"],f[@"game"],f[@"profile"]),@"path escape rejected");
    [f[@"original"]writeToFile:f[@"path"] atomically:NO];NSString *duplicate=[f[@"manifests"]stringByAppendingPathComponent:@"duplicate.item"];[f[@"original"]writeToFile:duplicate atomically:NO];check(!EFindManifest(f[@"manifests"],f[@"game"],f[@"profile"]),@"ambiguous manifests rejected");unlink(duplicate.fileSystemRepresentation);
    check(EEnvironment(f[@"environment"],f[@"target"]),@"own trainer environment");NSMutableDictionary *env=[f[@"environment"]mutableCopy];env[@"AUTH_FIXTURE"]=@"synthetic";check(!EEnvironment(env,f[@"target"]),@"external/auth environment rejected");[env removeObjectForKey:@"AUTH_FIXTURE"];env[[NSString stringWithFormat:@"MHT_%CINVALID",(unichar)0]]=@"synthetic";check(!EEnvironment(env,f[@"target"]),@"embedded NUL env name rejected");
    check(EReadBroker(@"/usr/bin/true").length>0,@"root-owned shipped executable readable without executing it");check(!ERead(@"/usr/bin/true",YES,32*1024*1024),@"root-owned executable is not accepted as private metadata");
    NSString *unsafe=[f[@"install"]stringByAppendingPathComponent:@"unsafe"];[NSFileManager.defaultManager createDirectoryAtPath:unsafe withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0755} error:NULL];check(!EBrokerReceipt([unsafe stringByAppendingPathComponent:@"receipt"],@"fixture",@"exec-attempt",YES),@"receipt rejects nonprivate parent");
}
static void recoveryTests(NSDictionary *f,NSString *broker){
    NSDictionary *journal=journalFixture(f);NSString *path=[f[@"state"]stringByAppendingPathComponent:@"epic.json"];
    check(EJournalValid(journal,f[@"state"],f[@"manifests"]),@"recovery journal exact schema");
    for(NSString *key in @[@"original",@"mutation",@"broker",@"config",@"receipt",@"target",@"mode"]){NSMutableDictionary *bad=[journal mutableCopy];bad[key]=@[];check(!EJournalValid(bad,f[@"state"],f[@"manifests"]),@"corrupt array journal field does not throw");}
    for(NSString *key in @[@"original",@"mutation"]){NSMutableDictionary *bad=[journal mutableCopy];bad[key]=@42;check(!EJournalValid(bad,f[@"state"],f[@"manifests"]),@"corrupt numeric Base64 field does not throw");}
    MHTEpicLaunchService *s=service(f,broker,^BOOL{return NO;},^NSDictionary *{return @{};},^BOOL(NSURL *url){(void)url;return NO;});NSError *error=nil;
    int lock=ELock(f[@"state"]);check(lock>=0,@"first transaction owns lock");check(![s recoverPendingTransactions:&error],@"parallel recovery cannot take active transaction lock");check([ERead(f[@"path"],NO,ELimit)isEqual:[[NSData alloc]initWithBase64EncodedString:journal[@"mutation"]options:0]],@"parallel recovery left mutation untouched");close(lock);
    NSData *foreign=[@"{\"external\":true}"dataUsingEncoding:NSUTF8StringEncoding];check(EAtomic(f[@"path"],foreign,0600),@"external metadata fixture");check(![s recoverPendingTransactions:&error]&&[ERead(f[@"path"],NO,ELimit)isEqual:foreign],@"newer external manifest preserved");
    check(EAtomic(f[@"path"],[[NSData alloc]initWithBase64EncodedString:journal[@"mutation"]options:0],0600),@"return synthetic own mutation");
    s.clientRunning=^BOOL{return YES;};check(![s recoverPendingTransactions:&error],@"startup recovery waits for normal Epic exit");
    check([NSFileManager.defaultManager fileExistsAtPath:path]&&[NSFileManager.defaultManager fileExistsAtPath:journal[@"broker"]],@"running client keeps original journal and helper");
    check([ERead(f[@"path"],NO,ELimit)isEqual:[[NSData alloc]initWithBase64EncodedString:journal[@"mutation"]options:0]],@"running client recovery does not race its writable cache");
    s.clientRunning=^BOOL{return NO;};
    s.processes=^NSDictionary *{return @{@123:@{@"path":journal[@"broker"],@"started":@"fixture"}};};check(![s recoverPendingTransactions:&error],@"loaded helper not deleted");check([ERead(f[@"path"],NO,ELimit)isEqual:f[@"original"]],@"loaded helper still restores original metadata");check([NSFileManager.defaultManager fileExistsAtPath:journal[@"broker"]],@"loaded broker preserved");
    s.processes=^NSDictionary *{return @{};};check([s recoverPendingTransactions:&error],@"startup recovery completes after helper is unloaded");check(![NSFileManager.defaultManager fileExistsAtPath:path],@"completed journal removed");
}
static void deferredCleanupTests(NSDictionary *f,NSString *broker){
    NSDictionary *journal=journalFixture(f);NSString *path=[f[@"state"]stringByAppendingPathComponent:@"epic.json"];
    __block BOOL client=YES;__block NSUInteger completed=0;__block NSDictionary *snapshot=@{};
    MHTEpicLaunchService *s=service(f,broker,^BOOL{return client;},^NSDictionary *{return snapshot;},^BOOL(NSURL *url){(void)url;check(NO,@"cleanup never opens a URI or terminates a client");return NO;});
    MHTEpicOperation *operation=[MHTEpicOperation new];operation.journal=journal;operation.journalPath=path;operation.lock=ELock(f[@"state"]);check(operation.lock>=0,@"completed launch transaction lock");
    // Exercise the exact successful finish path without inventing an OS game
    // registration or starting any process. The completion itself may be nil-app.
    operation.completion=^(NSRunningApplication *app,NSError *error){check(!app&&!error&&NSThread.isMainThread,@"successful finish callback is independent of deferred cleanup");completed++;};s.pending=operation;
    dispatch_sync(s.queue,^{[s finish:operation app:nil error:nil];});
    check(pump(^BOOL{return completed==1;}),@"launch completion delivered before Epic closes");
    check([ERead(f[@"path"],NO,ELimit)isEqual:f[@"original"]],@"successful launch immediately restores byte-exact original");
    check([NSFileManager.defaultManager fileExistsAtPath:path]&&[NSFileManager.defaultManager fileExistsAtPath:journal[@"config"]]&&[NSFileManager.defaultManager fileExistsAtPath:journal[@"broker"]],@"successful launch retains complete recovery evidence while Epic runs");
    int contender=ELock(f[@"state"]);check(contender<0,@"deferred transaction still owns interprocess lock");if(contender>=0)close(contender);
    NSMutableDictionary *cached=[EJSON([[NSData alloc]initWithBase64EncodedString:journal[@"mutation"]options:0])mutableCopy];cached[@"bNeedsValidation"]=@YES;NSData *replay=EEncode(cached);
    check(EAtomic(f[@"path"],replay,0600),@"Epic exit cache replay includes own exact nonce and validation flag");
    NSError *error=nil;check(![s recoverPendingTransactions:&error]&&[ERead(f[@"path"],NO,ELimit)isEqual:replay],@"manual recovery does not delete live client recovery journal");
    dispatch_sync(s.queue,^{client=NO;snapshot=@{@123:@{@"path":journal[@"broker"],@"started":@"synthetic-start"}};});
    check(![s recoverPendingTransactions:&error]&&[NSFileManager.defaultManager fileExistsAtPath:path],@"client exit still waits for a mapped helper process");
    contender=ELock(f[@"state"]);check(contender<0,@"running helper keeps deferred transaction lock");if(contender>=0)close(contender);
    dispatch_sync(s.queue,^{snapshot=@{};});
    check(pump(^BOOL{return ![NSFileManager.defaultManager fileExistsAtPath:path];}),@"normal client exit triggers final restoration and cleanup");
    check([ERead(f[@"path"],NO,ELimit)isEqual:f[@"original"]]&&![NSFileManager.defaultManager fileExistsAtPath:journal[@"broker"]]&&![NSFileManager.defaultManager fileExistsAtPath:journal[@"config"]],@"late cached helper assignment and validation flag restored exactly");
    check(completed==1,@"deferred cleanup never duplicates launch completion");
    check([s recoverPendingTransactions:&error],@"deferred lock is released after cleanup");

    // A new service after app exit must also recognize only the exact saved
    // assignment. A game update or another launch assignment is foreign data.
    journal=journalFixture(f);cached=[EJSON([[NSData alloc]initWithBase64EncodedString:journal[@"mutation"]options:0])mutableCopy];cached[@"bNeedsValidation"]=@YES;cached[@"AppVersionString"]=@"foreign-update";
    NSData *foreign=EEncode(cached);check(EAtomic(f[@"path"],foreign,0600),@"foreign update alongside own nonce");
    check(![s recoverPendingTransactions:&error]&&[ERead(f[@"path"],NO,ELimit)isEqual:foreign]&&[NSFileManager.defaultManager fileExistsAtPath:path],@"same nonce never authorizes unrelated metadata changes");
    [cached removeObjectForKey:@"AppVersionString"];cached[@"LaunchExecutable"]=@"TrainerDock-Epic-foreign";foreign=EEncode(cached);check(EAtomic(f[@"path"],foreign,0600),@"foreign helper assignment");
    check(![s recoverPendingTransactions:&error]&&[ERead(f[@"path"],NO,ELimit)isEqual:foreign],@"another nonce is protected");
    cached[@"LaunchExecutable"]=journal[@"nonce"];check(EAtomic(f[@"path"],EEncode(cached),0600),@"exact replay for restart recovery");
    check([s recoverPendingTransactions:&error]&&[ERead(f[@"path"],NO,ELimit)isEqual:f[@"original"]],@"next app startup restores late replay from saved journal");
    journal=journalFixture(f);NSString *duplicate=[NSString stringWithFormat:@"{\"LaunchExecutable\":\"%@\",\"LaunchExecutable\":\"%@\"}",journal[@"nonce"],journal[@"nonce"]];foreign=[duplicate dataUsingEncoding:NSUTF8StringEncoding];check(EAtomic(f[@"path"],foreign,0600),@"duplicate cache-replay fixture");
    check(![s recoverPendingTransactions:&error]&&[ERead(f[@"path"],NO,ELimit)isEqual:foreign],@"duplicate replay keys never authorize restoration");
    cached=[EJSON([[NSData alloc]initWithBase64EncodedString:journal[@"mutation"]options:0])mutableCopy];check(EAtomic(f[@"path"],EEncode(cached),0600),@"same metadata with Epic JSON reserialization");
    check([s recoverPendingTransactions:&error]&&[ERead(f[@"path"],NO,ELimit)isEqual:f[@"original"]],@"formatting-only own replay restores exact original bytes");
}
static void serviceTests(NSDictionary *f,NSString *broker){
    __block NSUInteger opened=0,completed=0;__block NSError *last=nil;
    MHTEpicLaunchService *running=service(f,broker,^BOOL{return YES;},^NSDictionary *{return @{};},^BOOL(NSURL *url){(void)url;opened++;return YES;});
    [running launchGame:f[@"game"] profile:f[@"profile"] environment:f[@"environment"] completion:^(NSRunningApplication *app,NSError *error){check(!app&&error!=nil&&NSThread.isMainThread,@"running Epic rejected on main queue");completed++;}];
    check(opened==0&&completed==1,@"running client never triggers URI or retry");
    __block BOOL acknowledge=NO;__block NSDictionary *snapshot=@{};NSLock *mutex=[NSLock new];
    NSDictionary *(^processes)(void)=^NSDictionary *{[mutex lock];NSDictionary *copy=[snapshot copy];[mutex unlock];return copy;};
    MHTEpicLaunchService *s=service(f,broker,^BOOL{return NO;},processes,^BOOL(NSURL *url){
        opened++;check([url.scheme isEqual:@"com.epicgames.launcher"]&&[url.path.lastPathComponent.stringByRemovingPercentEncoding isEqual:@"fixture-space:fixture-item:fixture-app"],@"exact official Epic URI once");
        if(acknowledge){NSDictionary *journal=EJSON(ERead([f[@"state"]stringByAppendingPathComponent:@"epic.json"],YES,ELimit*3));
            NSDictionary *receipt=@{@"nonce":journal[@"nonce"],@"pid":@123,@"started":@"synthetic-start",@"state":@"exec-attempt"};
            [mutex lock];snapshot=@{@123:@{@"path":journal[@"broker"],@"started":@"synthetic-start"}};[mutex unlock];check(EAtomic(journal[@"receipt"],EEncode(receipt),0600),@"private synthetic acknowledgement");}
        return YES;
    });
    opened=0;completed=0;
    [s launchGame:f[@"game"] profile:f[@"profile"] environment:f[@"environment"] completion:^(NSRunningApplication *app,NSError *error){check(!app&&error!=nil&&NSThread.isMainThread,@"cancel completes exactly on main queue");completed++;last=error;}];
    check(pump(^BOOL{return opened==1;}),@"one synthetic URI callback");check(![ERead(f[@"path"],NO,ELimit)isEqual:f[@"original"]],@"transaction mutation prepared before URI");
    [s cancelPendingLaunch];check([ERead(f[@"path"],NO,ELimit)isEqual:f[@"original"]],@"termination cancel rollback is synchronous before returning");check(pump(^BOOL{return completed==1;}),@"cancel completion delivered once");check(opened==1&&last!=nil,@"cancel never retries");
    acknowledge=YES;opened=0;completed=0;last=nil;
    [s launchGame:f[@"game"] profile:f[@"profile"] environment:f[@"environment"] completion:^(NSRunningApplication *app,NSError *error){check(!app,@"never return client or synthetic broker as game app");completed++;last=error;}];
    check(pump(^BOOL{return opened==1&&[ERead(f[@"path"],NO,ELimit)isEqual:f[@"original"]];}),@"first ack immediately restores manifest before original app registration");
    MHTEpicOperation *operation=s.pending;dispatch_sync(s.queue,^{check(operation.acknowledged&&operation.deadline>NSProcessInfo.processInfo.systemUptime,@"deadline uses monotonic uptime");operation.deadline=NSProcessInfo.processInfo.systemUptime-1;});
    [mutex lock];snapshot=@{};[mutex unlock];check(pump(^BOOL{return completed==1;}),@"expired monotonic deadline completes without real app");check(last!=nil&&opened==1,@"timeout no retry or direct fallback");check([ERead(f[@"path"],NO,ELimit)isEqual:f[@"original"]],@"timeout preserves exact original metadata");
}
int main(int argc,const char **argv){@autoreleasepool{
    check(argc==2,@"own broker path argument");char pattern[]="/private/tmp/trainerdock-epic-native-XXXXXX";char *directory=mkdtemp(pattern);check(directory!=NULL,@"private synthetic test directory");NSString *root=@(directory);
    @try{NSDictionary *f=fixture(root);pureTests(f);recoveryTests(f,@(argv[1]));deferredCleanupTests(f,@(argv[1]));serviceTests(f,@(argv[1]));}
    @finally{[NSFileManager.defaultManager removeItemAtPath:root error:NULL];}
    printf("Epic native service: %lu checks passed; no Epic client or game launched.\n",(unsigned long)checks);
}return 0;}
