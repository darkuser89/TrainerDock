// SPDX-License-Identifier: GPL-3.0-only
#import "MHTTrainerStore.h"
#import "MHTTrainerArchive.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>
#import <unistd.h>
#import <limits.h>
NSString *const MHTTrainerStoreDidChangeNotification=@"local.trainerdock.store.changed";
NSString *const MHTTrainerCatalogAddress=@"https://github.com/darkuser89/TrainerDock/releases/download/trainer-catalog/catalog.json";
static BOOL SFail(NSError **error,NSString *text){if(error)*error=[NSError errorWithDomain:@"local.trainerdock.store" code:1 userInfo:@{NSLocalizedDescriptionKey:text}];return NO;}
static BOOL SText(id s){return [s isKindOfClass:NSString.class]&&[s length]>0;}
static BOOL SMatch(id s,NSString *pattern){if(!SText(s))return NO;NSRange range=[s rangeOfString:pattern options:NSRegularExpressionSearch];return range.location==0&&range.length==[s length];}
static BOOL SToken(id s){return SMatch(s,@"^[a-z0-9][a-z0-9_-]{0,79}$");}
BOOL MHTTrainerVersion(NSString *s){return SMatch(s,@"^(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})\\.(0|[1-9][0-9]{0,8})$");}
NSComparisonResult MHTCompareTrainerVersions(NSString *a,NSString *b){if(!MHTTrainerVersion(a)||!MHTTrainerVersion(b))return [a compare:b options:NSNumericSearch];NSArray *x=[a componentsSeparatedByString:@"."],*y=[b componentsSeparatedByString:@"."];for(NSUInteger i=0;i<3;i++){long long first=[x[i] longLongValue],second=[y[i] longLongValue];if(first<second)return NSOrderedAscending;if(first>second)return NSOrderedDescending;}return NSOrderedSame;}
static BOOL STransport(NSURL *url){return [url.scheme isEqual:@"https"]&&!url.user.length&&!url.password.length&&!url.port&&[@[@"github.com",@"release-assets.githubusercontent.com",@"objects.githubusercontent.com"] containsObject:url.host.lowercaseString];}
static id SJSON(NSString *path,NSUInteger cap){NSDictionary *a=[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL];if(![a[NSFileType] isEqual:NSFileTypeRegular]||[a[NSFileSize] unsignedLongLongValue]>cap)return nil;NSData *d=[NSData dataWithContentsOfFile:path];return d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;}
static NSString *SCanonical(NSString *s){if(!s.length)return nil;char resolved[PATH_MAX];return realpath(s.fileSystemRepresentation,resolved)?[NSString stringWithUTF8String:resolved]:s.stringByStandardizingPath.stringByResolvingSymlinksInPath;}
static BOOL SPlainDirectory(NSString *s){struct stat a;return !lstat(s.fileSystemRepresentation,&a)&&S_ISDIR(a.st_mode);}
static NSString *SPackageHash(NSString *path){CC_SHA256_CTX context;CC_SHA256_Init(&context);for(NSString *name in @[@"LICENSE",@"Module.json",@"Trainer.dylib",@"TrainerConfig.json"]){NSString *file=[path stringByAppendingPathComponent:name];struct stat metadata;if(lstat(file.fileSystemRepresentation,&metadata)||!S_ISREG(metadata.st_mode)||metadata.st_size<=0||metadata.st_size>64*1024*1024)return nil;NSData *bytes=[NSData dataWithContentsOfFile:file];if(!bytes||bytes.length>64*1024*1024)return nil;NSData *label=[name dataUsingEncoding:NSUTF8StringEncoding];CC_SHA256_Update(&context,label.bytes,(CC_LONG)label.length);CC_SHA256_Update(&context,bytes.bytes,(CC_LONG)bytes.length);}uint8_t digest[32];CC_SHA256_Final(digest,&context);NSMutableString *hex=[NSMutableString new];for(unsigned i=0;i<32;i++)[hex appendFormat:@"%02x",digest[i]];return hex;}
static NSComparisonResult SModuleOrder(MHTModule *a,MHTModule *b){NSComparisonResult order=MHTCompareTrainerVersions(b.version,a.version);if(order!=NSOrderedSame)return order;BOOL aa=MHTTrainerVersion(a.version)&&[a.installRevision isEqual:a.version],bb=MHTTrainerVersion(b.version)&&[b.installRevision isEqual:b.version];if(aa!=bb)return aa?NSOrderedAscending:NSOrderedDescending;return [a.directory compare:b.directory];}
// A bounded ephemeral HTTPS transfer; no authentication data or game traffic.
@interface MHTTrainerFetch : NSObject <NSURLSessionDataDelegate>
@property(nonatomic) NSUInteger maximum;
@property(nonatomic,strong) NSMutableData *bytes;
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,copy) void (^completion)(NSData *,NSError *);
@property(nonatomic,strong) NSError *failure;
+ (void)URL:(NSURL *)url maximum:(NSUInteger)maximum completion:(void (^)(NSData *,NSError *))completion;
@end
@implementation MHTTrainerFetch
+ (void)URL:(NSURL *)url maximum:(NSUInteger)maximum completion:(void (^)(NSData *,NSError *))completion {
    if(!STransport(url)){NSError *error=nil;SFail(&error,@"Das Downloadziel ist nicht zugelassen.");completion(nil,error);return;}
    MHTTrainerFetch *fetch=[self new];fetch.maximum=maximum;fetch.bytes=[NSMutableData new];fetch.completion=completion;
    NSURLSessionConfiguration *configuration=NSURLSessionConfiguration.ephemeralSessionConfiguration;configuration.timeoutIntervalForRequest=30;configuration.timeoutIntervalForResource=120;
    fetch.session=[NSURLSession sessionWithConfiguration:configuration delegate:fetch delegateQueue:nil];NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];[request setValue:@"TrainerDock" forHTTPHeaderField:@"User-Agent"];[[fetch.session dataTaskWithRequest:request] resume];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler{(void)session;(void)task;(void)response;if(STransport(request.URL))completionHandler(request);else{self.failure=[NSError errorWithDomain:@"local.trainerdock.download" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Das Downloadziel ist nicht zugelassen."}];completionHandler(nil);}}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler{(void)session;(void)task;BOOL ok=STransport(response.URL)&&[response isKindOfClass:NSHTTPURLResponse.class]&&((NSHTTPURLResponse *)response).statusCode==200&&(response.expectedContentLength<0||(uint64_t)response.expectedContentLength<=self.maximum);if(!ok)self.failure=[NSError errorWithDomain:@"local.trainerdock.download" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Der GitHub-Download ist nicht verfügbar oder zu groß."}];completionHandler(ok?NSURLSessionResponseAllow:NSURLSessionResponseCancel);}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data{(void)session;if(data.length>self.maximum-self.bytes.length){self.failure=[NSError errorWithDomain:@"local.trainerdock.download" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Der Download überschreitet die erlaubte Größe."}];[task cancel];return;}[self.bytes appendData:data];}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{(void)task;self.completion(self.failure||error?nil:self.bytes,self.failure?:error);[session finishTasksAndInvalidate];self.completion=nil;self.session=nil;}
@end
@interface MHTTrainerStore ()
@property(nonatomic,readwrite,copy) NSString *rootDirectory;
@property(atomic,readwrite,copy) NSDictionary *catalog;
@property(atomic,readwrite) BOOL refreshing;
@property(atomic,readwrite,strong) NSError *lastError;
@property(nonatomic,strong) NSURL *catalogURL;
@property(nonatomic,strong) NSMutableSet<NSString *> *busy;
@property(nonatomic,strong) dispatch_queue_t work;
@end
@implementation MHTTrainerStore
+ (instancetype)sharedStore {static MHTTrainerStore *store;static dispatch_once_t once;dispatch_once(&once,^{store=[[self alloc]initWithRootDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/TrainerDock/Modules"] catalogURL:[NSURL URLWithString:MHTTrainerCatalogAddress] bundledCatalogURL:[NSBundle.mainBundle URLForResource:@"TrainerCatalog" withExtension:@"json"]];});return store;}
- (instancetype)initWithRootDirectory:(NSString *)directory catalogURL:(NSURL *)url bundledCatalogURL:(NSURL *)bundle {
    if((self=[super init])){_rootDirectory=[directory copy];_catalogURL=url;_busy=[NSMutableSet new];_work=dispatch_queue_create("local.trainerdock.store",DISPATCH_QUEUE_SERIAL);_catalog=@{@"schemaVersion":@1,@"moduleABI":@1,@"modules":@[]};
        NSDictionary *bundled=[self.class validatedCatalog:bundle?SJSON(bundle.path,32*1024*1024):nil requireDownloads:NO error:NULL];if(bundled)_catalog=bundled;
        NSDictionary *cached=[self.class validatedCatalog:SJSON([self cachePath],32*1024*1024) requireDownloads:YES error:NULL];if(cached)_catalog=cached;
    }return self;
}
- (NSString *)cachePath{return [self.rootDirectory.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"TrainerCatalog.json"];}
- (NSSet *)installingIdentifiers{@synchronized(self){return [self.busy copy];}}
- (NSArray<MHTModule *> *)modules{return [self modulesWithErrors:nil];}
- (void)notify {dispatch_async(dispatch_get_main_queue(),^{[NSNotificationCenter.defaultCenter postNotificationName:MHTTrainerStoreDidChangeNotification object:self];});}
+ (NSDictionary *)validatedCatalog:(id)value requireDownloads:(BOOL)required error:(NSError **)error {
    if(![value isKindOfClass:NSDictionary.class]||![value[@"schemaVersion"] isEqual:@1]||![value[@"moduleABI"] isEqual:@1]||![value[@"modules"] isKindOfClass:NSArray.class]||[value[@"modules"] count]>512){SFail(error,@"Der Trainerkatalog ist ungültig oder benötigt eine neuere App.");return nil;}
    NSMutableArray *modules=[NSMutableArray new];NSMutableSet *ids=[NSMutableSet new];
    for(id item in value[@"modules"]){if(![item isKindOfClass:NSDictionary.class]||!SToken(item[@"id"])||[ids containsObject:item[@"id"]]||!SText(item[@"name"])||[item[@"name"] length]>160||![item[@"versions"] isKindOfClass:NSArray.class]||![item[@"versions"] count]||[item[@"versions"] count]>256){SFail(error,@"Ungültiger oder doppelter Eintrag im Trainerkatalog.");return nil;}[ids addObject:item[@"id"]];NSMutableArray *versions=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
        for(id entry in item[@"versions"]){BOOL valid=[entry isKindOfClass:NSDictionary.class]&&MHTTrainerVersion(entry[@"version"])&&![seen containsObject:entry[@"version"]]&&[entry[@"moduleABI"] isEqual:@1]&&MHTTrainerVersion(entry[@"minimumLauncherVersion"])&&[MHTModule validManifest:entry[@"manifest"] error:NULL]&&[entry[@"manifest"][@"id"] isEqual:item[@"id"]]&&[entry[@"manifest"][@"version"] isEqual:entry[@"version"]];
            if(!valid){SFail(error,@"Eine Trainerversion besitzt ungültige Metadaten.");return nil;}
            NSString *expected=[NSString stringWithFormat:@"https://github.com/darkuser89/TrainerDock/releases/download/trainer-%@-v%@/%@-%@.zip",item[@"id"],entry[@"version"],item[@"id"],entry[@"version"]];
            BOOL download=[entry[@"url"] isEqual:expected]&&SMatch(entry[@"sha256"],@"^[a-f0-9]{64}$")&&SMatch(entry[@"fingerprint"],@"^[a-f0-9]{64}$")&&[entry[@"size"] isKindOfClass:NSNumber.class]&&[entry[@"size"] doubleValue]==[entry[@"size"] unsignedLongLongValue]&&[entry[@"size"] unsignedLongLongValue]>0&&[entry[@"size"] unsignedLongLongValue]<=64*1024*1024;
            if(required&&!download){SFail(error,@"Ein Trainerdownload ist unvollständig oder stammt aus einer fremden Quelle.");return nil;}
            if(!required&&(entry[@"url"]||entry[@"sha256"]||entry[@"size"])&&!download){SFail(error,@"Die eingebetteten Downloadmetadaten sind ungültig.");return nil;}
            NSMutableDictionary *copy=[entry mutableCopy];copy[@"downloadAvailable"]=@(download&&![entry[@"downloadAvailable"] isEqual:@NO]);[versions addObject:copy];[seen addObject:entry[@"version"]];
        }
        [versions sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return MHTCompareTrainerVersions(b[@"version"],a[@"version"]);}];[modules addObject:@{@"id":item[@"id"],@"name":item[@"name"],@"versions":versions}];
    }
    return @{@"schemaVersion":@1,@"moduleABI":@1,@"modules":modules};
}
- (NSArray<NSDictionary *> *)versionsForIdentifier:(NSString *)identifier{NSDictionary *catalog=self.catalog;for(NSDictionary *item in catalog[@"modules"])if([item[@"id"] isEqual:identifier])return item[@"versions"];return @[];}
- (NSArray<MHTModule *> *)allInstalled:(NSMutableArray<NSString *> *)errors {
    NSMutableArray *all=[NSMutableArray new];NSMutableSet *paths=[NSMutableSet new];NSMutableArray *directories=[NSMutableArray new];
    NSString *standard=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/TrainerDock/Modules"];
    if([self.rootDirectory isEqual:standard]){[directories addObject:MHTModule.moduleDirectory];[directories addObject:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/MHT/Modules"]];}
    [directories addObject:self.rootDirectory];
    for(NSString *folder in directories){
        for(MHTModule *module in [MHTModule loadModules:folder errors:errors])if(![paths containsObject:SCanonical(module.directory)]){[all addObject:module];[paths addObject:SCanonical(module.directory)];}
        if(![folder isEqual:self.rootDirectory])continue;
        for(NSString *identifier in [NSFileManager.defaultManager contentsOfDirectoryAtPath:folder error:NULL])if(SToken(identifier)){
            NSString *game=[folder stringByAppendingPathComponent:identifier];if(!SPlainDirectory(game))continue;
            for(NSString *version in [NSFileManager.defaultManager contentsOfDirectoryAtPath:game error:NULL])if(MHTTrainerVersion(version)||SMatch(version,@"^legacy-[a-f0-9]{16}$")){
                NSString *container=[game stringByAppendingPathComponent:version];if(!SPlainDirectory(container))continue;
                for(MHTModule *module in [MHTModule loadModules:container errors:errors])if([module.identifier isEqual:identifier]&&(!MHTTrainerVersion(version)||[module.version isEqual:version])&&![paths containsObject:SCanonical(module.directory)]){[all addObject:module];[paths addObject:SCanonical(module.directory)];}
            }
        }
    }
    return all;
}
- (NSArray<MHTModule *> *)installedVersionsForIdentifier:(NSString *)identifier {
    NSMutableArray *result=[NSMutableArray new];for(MHTModule *module in [self allInstalled:nil])if([module.identifier isEqual:identifier])[result addObject:module];
    [result sortUsingComparator:^NSComparisonResult(MHTModule *a,MHTModule *b){return SModuleOrder(a,b);}];return result;
}
- (NSArray<MHTModule *> *)modulesWithErrors:(NSMutableArray<NSString *> *)errors {
    NSMutableDictionary *byID=[NSMutableDictionary new];for(MHTModule *module in [[self allInstalled:errors] sortedArrayUsingComparator:^NSComparisonResult(MHTModule *a,MHTModule *b){return SModuleOrder(a,b);}]){
        MHTModule *old=byID[module.identifier];NSString *selected=[NSUserDefaults.standardUserDefaults stringForKey:[@"MHT.TrainerVersion." stringByAppendingString:module.identifier]];
        BOOL chosen=[SCanonical(module.directory) isEqual:selected];
        if(!old||chosen)byID[module.identifier]=module;
    }
    for(NSDictionary *entry in self.catalog[@"modules"]){NSArray *versions=entry[@"versions"];NSDictionary *latest=versions.firstObject;MHTModule *module=byID[entry[@"id"]];if(!module){module=[MHTModule new];module.manifest=latest[@"manifest"];byID[module.identifier]=module;}
        module.catalogVersion=latest;module.updateAvailable=module.installed&&[latest[@"downloadAvailable"] boolValue]&&(MHTCompareTrainerVersions(module.version,latest[@"version"])==NSOrderedAscending||([module.version isEqual:latest[@"version"]]&&![module.installRevision isEqual:latest[@"version"]]));
    }
    return [byID.allValues sortedArrayUsingComparator:^NSComparisonResult(MHTModule *a,MHTModule *b){return [a.name localizedCaseInsensitiveCompare:b.name];}];
}
- (void)refreshCatalogWithCompletion:(void (^)(NSError *))completion {
    @synchronized(self){if(self.refreshing){if(completion)dispatch_async(dispatch_get_main_queue(),^{completion(nil);});return;}self.refreshing=YES;}[self notify];
    [MHTTrainerFetch URL:self.catalogURL maximum:32*1024*1024 completion:^(NSData *data,NSError *networkError){dispatch_async(self.work,^{NSError *error=networkError;NSDictionary *json=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:&error]:nil;NSDictionary *catalog=json?[self.class validatedCatalog:json requireDownloads:YES error:&error]:nil;
        if(catalog){
            for(NSDictionary *item in catalog[@"modules"])for(NSDictionary *version in item[@"versions"])for(NSDictionary *old in [self versionsForIdentifier:item[@"id"]])if([old[@"version"] isEqual:version[@"version"]]&&[old[@"downloadAvailable"] boolValue]&&(![old[@"sha256"] isEqual:version[@"sha256"]]||![old[@"fingerprint"] isEqual:version[@"fingerprint"]]||![old[@"manifest"] isEqual:version[@"manifest"]])){SFail(&error,@"Eine bereits veröffentlichte Trainerversion wurde verändert. Katalog verworfen.");catalog=nil;break;}
        }
        if(catalog&&![self prepareRoot:&error])catalog=nil;
        if(catalog){NSData *bytes=[NSJSONSerialization dataWithJSONObject:catalog options:0 error:&error];NSString *parent=[self cachePath].stringByDeletingLastPathComponent;if([NSFileManager.defaultManager createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]&&[bytes writeToFile:[self cachePath] options:NSDataWritingAtomic error:&error])self.catalog=catalog;}
        self.lastError=error;self.refreshing=NO;[self notify];dispatch_async(dispatch_get_main_queue(),^{if(completion)completion(error);});
    });}];
}
- (BOOL)prepareRoot:(NSError **)error{if(!self.rootDirectory.isAbsolutePath||[self.rootDirectory isEqual:@"/"])return SFail(error,@"Ungültiger Trainerordner.");if(![NSFileManager.defaultManager createDirectoryAtPath:self.rootDirectory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error])return NO;return SPlainDirectory(self.rootDirectory)&&[SCanonical(self.rootDirectory) isEqual:self.rootDirectory] ? YES:SFail(error,@"Der Trainerordner darf keine symbolische Verknüpfung sein.");}
- (BOOL)compatible:(NSDictionary *)version error:(NSError **)error{NSString *host=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0.0";return [version[@"moduleABI"] isEqual:@1]&&MHTTrainerVersion(version[@"minimumLauncherVersion"])&&MHTCompareTrainerVersions(host,version[@"minimumLauncherVersion"])!=NSOrderedAscending?YES:SFail(error,@"Dieser Trainer benötigt eine neuere TrainerDock-Version.");}
- (MHTModule *)moduleAt:(NSString *)path error:(NSError **)error {NSMutableArray *errors=[NSMutableArray new];for(MHTModule *module in [MHTModule loadModules:path.stringByDeletingLastPathComponent errors:errors])if([module.directory isEqual:path])return module;SFail(error,errors.firstObject ?: @"Der installierte Trainer konnte nicht geladen werden.");return nil;}
- (MHTModule *)installArchive:(NSURL *)archive version:(NSDictionary *)version forIdentifier:(NSString *)identifier error:(NSError **)error {
    @synchronized(self){
        if(![version isKindOfClass:NSDictionary.class]||!SToken(identifier)||![self.class validatedCatalog:@{@"schemaVersion":@1,@"moduleABI":@1,@"modules":@[@{@"id":identifier,@"name":@"Trainer",@"versions":@[version]}]} requireDownloads:YES error:error])return nil;
        if(!SToken(identifier)||!MHTTrainerVersion(version[@"version"])||![version[@"manifest"][@"id"] isEqual:identifier]||![self compatible:version error:error]||!MHTTrainerVerifyArchive(archive,version,error)||![self prepareRoot:error])return nil;
        NSString *game=[self.rootDirectory stringByAppendingPathComponent:identifier];if(![NSFileManager.defaultManager createDirectoryAtPath:game withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error]||!SPlainDirectory(game)||![SCanonical(game) isEqual:game]){SFail(error,@"Ungültiger Spieleordner für Trainer.");return nil;}
        NSString *container=[game stringByAppendingPathComponent:version[@"version"]],*package=[container stringByAppendingPathComponent:[identifier stringByAppendingString:@".mhtmodule"]];
        if([NSFileManager.defaultManager fileExistsAtPath:container]){if(!SPlainDirectory(container)||![SCanonical(container) isEqual:container]){SFail(error,@"Ungültiger bestehender Versionsordner.");return nil;}NSDictionary *receipt=SJSON([container stringByAppendingPathComponent:@"Receipt.json"],1024*1024);if([receipt[@"sha256"] isEqual:version[@"sha256"]]&&MHTTrainerValidatePackage([NSURL fileURLWithPath:package],version,identifier,error))return [self moduleAt:package error:error];SFail(error,@"Diese Trainerversion existiert bereits mit anderen oder beschädigten Daten. Sie wurde nicht ersetzt.");return nil;}
        NSString *stage=[self.rootDirectory stringByAppendingPathComponent:[@".install-" stringByAppendingString:NSUUID.UUID.UUIDString]];if(![NSFileManager.defaultManager createDirectoryAtPath:stage withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:error])return nil;
        NSURL *stageURL=[NSURL fileURLWithPath:stage],*candidate=[stageURL URLByAppendingPathComponent:[identifier stringByAppendingString:@".mhtmodule"]],*privateArchive=[stageURL URLByAppendingPathComponent:@"Archive.zip"];MHTModule *result=nil;
        if([NSFileManager.defaultManager copyItemAtURL:archive toURL:privateArchive error:error]&&MHTTrainerVerifyArchive(privateArchive,version,error)&&MHTTrainerExtractArchive(privateArchive,stageURL,identifier,error)&&MHTTrainerValidatePackage(candidate,version,identifier,error)){
            NSData *receipt=[NSJSONSerialization dataWithJSONObject:@{@"sha256":version[@"sha256"],@"fingerprint":version[@"fingerprint"],@"version":version[@"version"]} options:0 error:error];
            if([NSFileManager.defaultManager removeItemAtURL:privateArchive error:error]&&[receipt writeToFile:[stage stringByAppendingPathComponent:@"Receipt.json"] options:NSDataWritingAtomic error:error]&&[NSFileManager.defaultManager moveItemAtPath:stage toPath:container error:error])result=[self moduleAt:package error:error];
        }
        [NSFileManager.defaultManager removeItemAtPath:stage error:NULL];if(result)[self notify];return result;
    }
}
- (void)installVersion:(NSDictionary *)version forIdentifier:(NSString *)identifier completion:(void (^)(MHTModule *,NSError *))completion {
    NSError *failure=nil;if(![version[@"downloadAvailable"] boolValue]||![[self versionsForIdentifier:identifier] containsObject:version]||![self compatible:version error:&failure]){if(!failure)SFail(&failure,@"Diese Trainerversion steht noch nicht als geprüfter Download bereit.");if(completion)dispatch_async(dispatch_get_main_queue(),^{completion(nil,failure);});return;}
    @synchronized(self){if([self.busy containsObject:identifier]){SFail(&failure,@"Für dieses Spiel läuft bereits ein Trainerdownload.");if(completion)dispatch_async(dispatch_get_main_queue(),^{completion(nil,failure);});return;}[self.busy addObject:identifier];}[self notify];
    [MHTTrainerFetch URL:[NSURL URLWithString:version[@"url"]] maximum:[version[@"size"] unsignedIntegerValue] completion:^(NSData *data,NSError *networkError){dispatch_async(self.work,^{NSError *error=networkError;MHTModule *module=nil;NSString *temporary=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"TrainerDock-download-" stringByAppendingString:NSUUID.UUID.UUIDString]];
        if(data&&[NSFileManager.defaultManager createDirectoryAtPath:temporary withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:&error]){NSURL *file=[NSURL fileURLWithPath:[temporary stringByAppendingPathComponent:@"Trainer.zip"]];if([data writeToURL:file options:NSDataWritingAtomic error:&error])module=[self installArchive:file version:version forIdentifier:identifier error:&error];}
        [NSFileManager.defaultManager removeItemAtPath:temporary error:NULL];@synchronized(self){[self.busy removeObject:identifier];}self.lastError=error;[self notify];dispatch_async(dispatch_get_main_queue(),^{if(completion)completion(module,error);});
    });}];
}
- (MHTModule *)importLegacyModule:(MHTModule *)module error:(NSError **)error {
    @synchronized(self){if(!module.installed||!SToken(module.identifier)||![self prepareRoot:error]||!MHTTrainerValidatePackage([NSURL fileURLWithPath:module.directory],@{@"version":module.version,@"manifest":module.manifest},module.identifier,error))return nil;
        NSString *hash=SPackageHash(module.directory);if(!hash){SFail(error,@"Der bisherige Trainer konnte nicht vollständig gelesen werden.");return nil;}
        NSString *game=[self.rootDirectory stringByAppendingPathComponent:module.identifier],*revision=[@"legacy-" stringByAppendingString:[hash substringToIndex:16]];NSString *container=[game stringByAppendingPathComponent:revision],*destination=[container stringByAppendingPathComponent:[module.identifier stringByAppendingString:@".mhtmodule"]];
        if([NSFileManager.defaultManager fileExistsAtPath:container]){if(!SPlainDirectory(game)||![SCanonical(game) isEqual:game]||!SPlainDirectory(container)||![SCanonical(container) isEqual:container]){SFail(error,@"Ungültiger bestehender Versionsordner.");return nil;}if([SPackageHash(destination) isEqual:hash])return [self moduleAt:destination error:error];SFail(error,@"Die übernommene Trainerversion besitzt abweichende Daten.");return nil;}
        if(![NSFileManager.defaultManager createDirectoryAtPath:game withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error]||!SPlainDirectory(game)||![SCanonical(game) isEqual:game])return nil;
        NSString *stage=[self.rootDirectory stringByAppendingPathComponent:[@".import-" stringByAppendingString:NSUUID.UUID.UUIDString]];if(![NSFileManager.defaultManager createDirectoryAtPath:stage withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700} error:error])return nil;
        NSString *copy=[stage stringByAppendingPathComponent:[module.identifier stringByAppendingString:@".mhtmodule"]];BOOL ok=[NSFileManager.defaultManager copyItemAtPath:module.directory toPath:copy error:error]&&[SPackageHash(copy) isEqual:hash]&&MHTTrainerValidatePackage([NSURL fileURLWithPath:copy],@{@"version":module.version,@"manifest":module.manifest},module.identifier,error)&&[NSFileManager.defaultManager moveItemAtPath:stage toPath:container error:error];
        [NSFileManager.defaultManager removeItemAtPath:stage error:NULL];if(!ok)return nil;MHTModule *result=[self moduleAt:destination error:error];[self notify];return result;
    }
}
- (BOOL)selectModule:(MHTModule *)module error:(NSError **)error {BOOL known=NO;for(MHTModule *candidate in [self installedVersionsForIdentifier:module.identifier])if([candidate.directory isEqual:module.directory])known=YES;if(!known)return SFail(error,@"Diese Trainerversion ist nicht installiert.");[NSUserDefaults.standardUserDefaults setObject:SCanonical(module.directory) forKey:[@"MHT.TrainerVersion." stringByAppendingString:module.identifier]];[self notify];return YES;}
static BOOL SInUse(NSString *path,NSError **error){
    NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:@"/usr/sbin/lsof"];task.arguments=@[@"-t",@"-nP",@"--",path];NSPipe *out=[NSPipe pipe],*err=[NSPipe pipe];task.standardOutput=out;task.standardError=err;
    if(![task launchAndReturnError:error])return YES;NSData *data=[out.fileHandleForReading readDataToEndOfFile];NSData *failure=[err.fileHandleForReading readDataToEndOfFile];[task waitUntilExit];if(data.length)return SFail(error,@"Diese Trainerversion wird noch von einem Prozess verwendet. Bitte das Spiel regulär beenden."),YES;
    if(task.terminationStatus>1||failure.length)return SFail(error,@"Die Verwendung der Trainerdatei konnte nicht sicher geprüft werden."),YES;return NO;
}
- (BOOL)removeModule:(MHTModule *)module protectedRuntimePaths:(NSSet<NSString *> *)paths error:(NSError **)error {
    @synchronized(self){NSString *package=SCanonical(module.directory),*root=SCanonical(self.rootDirectory);BOOL known=NO;for(MHTModule *candidate in [self installedVersionsForIdentifier:module.identifier])if([SCanonical(candidate.directory) isEqual:package])known=YES;
        if(!known||![package hasPrefix:[root stringByAppendingString:@"/"]]||![package isEqual:module.directory]||!SPlainDirectory(package))return SFail(error,@"Dieser Trainer kann hier nicht gelöscht werden. Mitgelieferte oder fremde Dateien bleiben erhalten.");
        for(NSString *path in paths)if([SCanonical(path) isEqual:SCanonical(module.runtimePath)])return SFail(error,@"Der Trainer gehört zu einer laufenden Sitzung und kann noch nicht gelöscht werden.");
        if(SInUse(module.runtimePath,error))return NO;
        NSString *parent=package.stringByDeletingLastPathComponent,*container=package;BOOL versioned=[parent.stringByDeletingLastPathComponent.lastPathComponent isEqual:module.identifier]&&(MHTTrainerVersion(parent.lastPathComponent)||SMatch(parent.lastPathComponent,@"^legacy-[a-f0-9]{16}$"));
        if(versioned){NSSet *files=[NSSet setWithArray:[NSFileManager.defaultManager contentsOfDirectoryAtPath:parent error:error] ?: @[]];if(![files isSubsetOfSet:[NSSet setWithArray:@[package.lastPathComponent,@"Receipt.json"]]])return SFail(error,@"Der Versionsordner enthält zusätzliche Dateien und wurde nicht gelöscht.");container=parent;}
        NSString *trash=[root stringByAppendingPathComponent:[@".remove-" stringByAppendingString:NSUUID.UUID.UUIDString]];
        if(![NSFileManager.defaultManager moveItemAtPath:container toPath:trash error:error])return NO;
        NSString *runtimePath=versioned?[[trash stringByAppendingPathComponent:package.lastPathComponent] stringByAppendingPathComponent:@"Trainer.dylib"]:[trash stringByAppendingPathComponent:@"Trainer.dylib"];
        if(SInUse(runtimePath,error)){[NSFileManager.defaultManager moveItemAtPath:trash toPath:container error:NULL];return NO;}
        if(![NSFileManager.defaultManager removeItemAtPath:trash error:error]){[NSFileManager.defaultManager moveItemAtPath:trash toPath:container error:NULL];return NO;}
        NSString *key=[@"MHT.TrainerVersion." stringByAppendingString:module.identifier];if([[NSUserDefaults.standardUserDefaults stringForKey:key] isEqual:package])[NSUserDefaults.standardUserDefaults removeObjectForKey:key];[self notify];return YES;
    }
}
- (MHTModule *)moduleForIdentifier:(NSString *)identifier profile:(NSDictionary *)profile path:(NSString *)path error:(NSError **)error {
    return [self moduleForIdentifier:identifier profile:profile path:path matchingProfile:NULL game:NULL error:error];
}
- (MHTModule *)moduleForIdentifier:(NSString *)identifier profile:(NSDictionary *)profile path:(NSString *)path matchingProfile:(NSDictionary **)matchingProfile game:(NSDictionary **)game error:(NSError **)error {
    if(matchingProfile)*matchingProfile=nil;if(game)*game=nil;
    NSArray *installed=[self installedVersionsForIdentifier:identifier];NSString *selected=[NSUserDefaults.standardUserDefaults stringForKey:[@"MHT.TrainerVersion." stringByAppendingString:identifier]];NSMutableArray *ordered=[installed mutableCopy];
    for(MHTModule *module in installed)if([SCanonical(module.directory) isEqual:selected]){[ordered removeObjectIdenticalTo:module];[ordered insertObject:module atIndex:0];break;}
    NSError *last=nil;for(MHTModule *module in ordered){NSArray *candidates=[module.profiles sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){BOOL aa=[a[@"id"] isEqual:profile[@"id"]],bb=[b[@"id"] isEqual:profile[@"id"]];return aa==bb?NSOrderedSame:aa?NSOrderedAscending:NSOrderedDescending;}];for(NSDictionary *candidate in candidates)if([candidate[@"store"] isEqual:profile[@"store"]]&&[candidate[@"bundleIdentifier"] isEqual:profile[@"bundleIdentifier"]]&&[(candidate[@"architecture"] ?: @"arm64") isEqual:(profile[@"architecture"] ?: @"arm64")]&&[candidate[@"enabled"] boolValue]){
        NSDictionary *found=[module inspectPath:path profile:candidate error:&last];if(found){if(matchingProfile)*matchingProfile=candidate;if(game)*game=found;return module;}
    }}
    if(error)*error=last ?: [NSError errorWithDomain:@"local.trainerdock.store" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Für diesen Spielbuild ist keine passende Trainerversion installiert."}];return nil;
}
@end
