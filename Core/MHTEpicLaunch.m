// SPDX-License-Identifier: GPL-3.0-only
#import "MHTEpicLaunch.h"
#import <CommonCrypto/CommonDigest.h>
#include <mach-o/dyld.h>
#include <libproc.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits.h>
#include <errno.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static NSString *const EDomain=@"local.trainerdock.epic-launch";
static NSUInteger const ELimit=1024*1024;
static NSError *EError(NSString *message){return [NSError errorWithDomain:EDomain code:1 userInfo:@{NSLocalizedDescriptionKey:message}];}
static BOOL EFail(NSError **error,NSString *message){if(error)*error=EError(message);return NO;}
static BOOL EText(id value){return [value isKindOfClass:NSString.class]&&[value length]&&[value length]<=4096&&[value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static BOOL EToken(id value){if(!EText(value)||[value length]>256)return NO;NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-"];return [value rangeOfCharacterFromSet:allowed.invertedSet].location==NSNotFound;}
static BOOL ECanonical(NSString *path){char full[PATH_MAX];return EText(path)&&path.isAbsolutePath&&realpath(path.fileSystemRepresentation,full)&&[path isEqualToString:@(full)];}
static BOOL EPrivateDirectory(NSString *path,BOOL create){
    if(create && ![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:NULL])return NO;
    struct stat s;return ECanonical(path)&&!lstat(path.fileSystemRepresentation,&s)&&S_ISDIR(s.st_mode)&&s.st_uid==getuid()&&!(s.st_mode&077);
}
static NSData *EReadFile(NSString *path,BOOL private,NSUInteger limit,BOOL rootAllowed){
    if(!EText(path))return nil;int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);if(fd<0)return nil;struct stat s;
    if(fstat(fd,&s)||!S_ISREG(s.st_mode)||(s.st_uid!=getuid()&&!(rootAllowed&&s.st_uid==0))||(private&&(s.st_mode&077))||s.st_size<=0||(uint64_t)s.st_size>limit){close(fd);return nil;}
    NSMutableData *data=[NSMutableData dataWithLength:(NSUInteger)s.st_size];NSUInteger offset=0;
    while(offset<data.length){ssize_t count=read(fd,(char *)data.mutableBytes+offset,data.length-offset);if(count<0&&errno==EINTR)continue;if(count<=0){close(fd);return nil;}offset+=(NSUInteger)count;}
    close(fd);return data;
}
static NSData *ERead(NSString *path,BOOL private,NSUInteger limit){return EReadFile(path,private,limit,NO);}
static NSData *EReadBroker(NSString *path){return EReadFile(path,NO,32*1024*1024,YES);}
static NSDictionary *EJSON(NSData *data){if(!data.length)return nil;id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];return [value isKindOfClass:NSDictionary.class]?value:nil;}
static NSData *EEncode(NSDictionary *value){return [NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];}
static NSString *EHashData(NSData *data){if(!data)return nil;unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,hash);NSMutableString *result=[NSMutableString new];for(NSUInteger i=0;i<sizeof(hash);i++)[result appendFormat:@"%02x",hash[i]];return result;}
static NSString *EHash(NSString *path){
    int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);if(fd<0)return nil;struct stat s;
    if(fstat(fd,&s)||!S_ISREG(s.st_mode)){close(fd);return nil;}
    CC_SHA256_CTX c;CC_SHA256_Init(&c);unsigned char bytes[65536],hash[CC_SHA256_DIGEST_LENGTH];ssize_t count;
    while((count=read(fd,bytes,sizeof(bytes)))!=0){if(count<0&&errno==EINTR)continue;if(count<0){close(fd);return nil;}CC_SHA256_Update(&c,bytes,(CC_LONG)count);}
    close(fd);CC_SHA256_Final(hash,&c);NSMutableString *result=[NSMutableString new];for(NSUInteger i=0;i<sizeof(hash);i++)[result appendFormat:@"%02x",hash[i]];return result;
}
static BOOL ESyncDirectory(NSString *path){int fd=open(path.fileSystemRepresentation,O_RDONLY|O_DIRECTORY|O_NOFOLLOW);if(fd<0)return NO;BOOL ok=fsync(fd)==0;close(fd);return ok;}
static BOOL EWriteNew(NSString *path,NSData *data,mode_t mode){
    if(!data)return NO;int fd=open(path.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,mode);if(fd<0)return NO;BOOL ok=YES;NSUInteger offset=0;
    while(offset<data.length){ssize_t count=write(fd,(const char *)data.bytes+offset,data.length-offset);if(count<0&&errno==EINTR)continue;if(count<=0){ok=NO;break;}offset+=(NSUInteger)count;}
    ok=fsync(fd)==0&&ok;close(fd);return ok;
}
static BOOL EAtomic(NSString *path,NSData *data,mode_t mode){
    NSString *temporary=[path.stringByDeletingLastPathComponent stringByAppendingPathComponent:[@".trainerdock-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    BOOL ok=EWriteNew(temporary,data,mode);if(ok)ok=rename(temporary.fileSystemRepresentation,path.fileSystemRepresentation)==0;
    if(ok)ok=ESyncDirectory(path.stringByDeletingLastPathComponent);unlink(temporary.fileSystemRepresentation);return ok;
}
static NSString *EStarted(pid_t pid){struct proc_bsdinfo info;int count=proc_pidinfo(pid,PROC_PIDTBSDINFO,0,&info,sizeof(info));if(count!=sizeof(info))return nil;return [NSString stringWithFormat:@"%llu:%llu",info.pbi_start_tvsec,info.pbi_start_tvusec];}
static NSDictionary<NSNumber *,NSDictionary *> *EProcesses(void){
    int size=proc_listallpids(NULL,0);if(size<=0)return nil;NSMutableData *data=[NSMutableData dataWithLength:(NSUInteger)(size+512)*sizeof(pid_t)];
    int count=proc_listallpids(data.mutableBytes,(int)data.length);if(count<=0||(NSUInteger)count>=data.length/sizeof(pid_t))return nil;
    NSMutableDictionary *found=[NSMutableDictionary new];pid_t *pids=data.mutableBytes;
    for(int i=0;i<count;i++){char path[PROC_PIDPATHINFO_MAXSIZE];if(proc_pidpath(pids[i],path,sizeof(path))<=0)continue;NSString *started=EStarted(pids[i]);if(started)found[@(pids[i])]=@{@"path":@(path),@"started":started};}return found;
}
static BOOL EHasPath(NSDictionary *processes,NSString *path,pid_t except){if(!processes)return YES;for(NSNumber *pid in processes)if(pid.intValue!=except&&[processes[pid][@"path"]isEqual:path])return YES;return NO;}
static BOOL EClientRunning(void){
    if([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.epicgames.EpicGamesLauncher"].count)return YES;
    NSDictionary *processes=EProcesses();if(!processes)return YES;
    for(NSDictionary *process in processes.allValues)if([@"EpicGamesLauncher-Mac-Shipping"isEqual:[process[@"path"]lastPathComponent]])return YES;return NO;
}
// Parse only top-level JSON token boundaries. NSJSONSerialization validates the
// complete document; duplicate top-level keys are rejected before changing bytes.
static void EWhite(const unsigned char *b,NSUInteger n,NSUInteger *i){while(*i<n&&(b[*i]==' '||b[*i]=='\n'||b[*i]=='\r'||b[*i]=='\t'))(*i)++;}
static BOOL EStringEnd(const unsigned char *b,NSUInteger n,NSUInteger *i){if(*i>=n||b[*i]!='"')return NO;(*i)++;while(*i<n){unsigned char c=b[(*i)++];if(c=='"')return YES;if(c=='\\'){if(*i>=n)return NO;(*i)++;}}return NO;}
static BOOL EValueEnd(const unsigned char *b,NSUInteger n,NSUInteger *i){
    if(*i>=n)return NO;if(b[*i]=='"')return EStringEnd(b,n,i);
    if(b[*i]=='{'||b[*i]=='['){NSUInteger depth=0;while(*i<n){unsigned char c=b[*i];if(c=='"'){if(!EStringEnd(b,n,i))return NO;continue;}(*i)++;if(c=='{'||c=='['){if(++depth>64)return NO;}if(c=='}'||c==']'){if(!depth)return NO;if(!--depth)return YES;}}return NO;}
    NSUInteger start=*i;while(*i<n&&b[*i]!=','&&b[*i]!='}')(*i)++;return *i>start;
}
static NSData *EPatch(NSData *original,NSString *replacement){
    NSDictionary *object=EJSON(original);if(![object[@"LaunchExecutable"]isKindOfClass:NSString.class])return nil;
    const unsigned char *b=original.bytes;NSUInteger n=original.length,i=0;EWhite(b,n,&i);if(i>=n||b[i++]!='{')return nil;
    NSMutableSet *keys=[NSMutableSet new];NSRange range=NSMakeRange(NSNotFound,0);
    while(i<n){EWhite(b,n,&i);if(i<n&&b[i]=='}')break;NSUInteger start=i;if(!EStringEnd(b,n,&i))return nil;
        NSMutableData *wrapped=[NSMutableData dataWithBytes:"[" length:1];[wrapped appendData:[original subdataWithRange:NSMakeRange(start,i-start)]];[wrapped appendBytes:"]" length:1];
        NSArray *array=[NSJSONSerialization JSONObjectWithData:wrapped options:0 error:NULL];NSString *key=[array isKindOfClass:NSArray.class]?array.firstObject:nil;
        if(![key isKindOfClass:NSString.class]||[keys containsObject:key])return nil;[keys addObject:key];EWhite(b,n,&i);if(i>=n||b[i++]!=':')return nil;EWhite(b,n,&i);start=i;if(!EValueEnd(b,n,&i))return nil;
        if([key isEqual:@"LaunchExecutable"])range=NSMakeRange(start,i-start);EWhite(b,n,&i);if(i<n&&b[i]==','){i++;continue;}if(i<n&&b[i]=='}')break;return nil;
    }
    if(range.location==NSNotFound)return nil;NSData *encoded=[NSJSONSerialization dataWithJSONObject:@[replacement] options:0 error:NULL];if(encoded.length<2)return nil;
    NSMutableData *patched=[original mutableCopy];[patched replaceBytesInRange:range withBytes:(const char *)encoded.bytes+1 length:encoded.length-2];return patched;
}
static BOOL EEnvironment(NSDictionary *environment,NSString *target){
    if(![environment isKindOfClass:NSDictionary.class]||!environment.count||environment.count>32||![environment[@"MHT_TARGET"]isEqual:target]||!EText(environment[@"DYLD_INSERT_LIBRARIES"]))return NO;
    NSString *nul=[NSString stringWithFormat:@"%C",(unichar)0];
    for(id key in environment){id value=environment[key];if(![key isKindOfClass:NSString.class]||![value isKindOfClass:NSString.class]||![key length]||[key length]>128||[value length]>8192||[key containsString:@"="]||[key containsString:nul]||[value containsString:nul]||(![key hasPrefix:@"MHT_"]&&![key isEqual:@"DYLD_INSERT_LIBRARIES"]&&![key isEqual:@"DYLD_LIBRARY_PATH"]))return NO;}return YES;
}
static NSDictionary *EFindManifest(NSString *directory,NSDictionary *game,NSDictionary *profile){
    if(!EToken(profile[@"epicAppName"])||!EToken(profile[@"epicNamespace"])||!ECanonical(game[@"path"])||!ECanonical(game[@"executable"]))return nil;
    NSArray *names=[NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:NULL];if(names.count>1024)return nil;NSDictionary *found=nil;
    for(NSString *name in names){if(![name.pathExtension isEqual:@"item"])continue;NSString *path=[directory stringByAppendingPathComponent:name];if(!ECanonical(path))continue;NSData *bytes=ERead(path,NO,ELimit);NSDictionary *item=EJSON(bytes);
        if(![item[@"AppName"]isEqual:profile[@"epicAppName"]]||![item[@"CatalogNamespace"]isEqual:profile[@"epicNamespace"]])continue;
        NSString *root=item[@"InstallLocation"],*relative=item[@"LaunchExecutable"];if(!ECanonical(root)||!EText(relative)||relative.isAbsolutePath||[relative.pathComponents containsObject:@".."]||[relative containsString:@"\\"]||!EToken(item[@"CatalogItemId"])||![item[@"LaunchCommand"]isEqual:@""])return nil;
        NSString *target=[root stringByAppendingPathComponent:relative];NSString *macOS=target.stringByDeletingLastPathComponent,*contents=macOS.stringByDeletingLastPathComponent,*bundle=contents.stringByDeletingLastPathComponent;
        NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[contents stringByAppendingPathComponent:@"Info.plist"]];
        if(![target isEqual:game[@"executable"]]||!ECanonical(target)||![macOS.lastPathComponent isEqual:@"MacOS"]||![contents.lastPathComponent isEqual:@"Contents"]||![bundle isEqual:game[@"path"]]||![bundle.stringByDeletingLastPathComponent isEqual:root]||![info[@"CFBundleIdentifier"]isEqual:profile[@"bundleIdentifier"]]||![info[@"CFBundleExecutable"]isEqual:profile[@"executable"]])return nil;
        if(found||!EPatch(bytes,@"probe-validation"))return nil;found=@{@"manifest":path,@"original":bytes,@"root":root,@"item":item};
    }return found;
}
static BOOL ERestore(NSDictionary *journal,NSError **error){
    NSData *original=[[NSData alloc]initWithBase64EncodedString:journal[@"original"] options:0],*mutation=[[NSData alloc]initWithBase64EncodedString:journal[@"mutation"] options:0];
    NSData *current=ERead(journal[@"manifest"],NO,ELimit);if(!original.length||!mutation.length||!current)return EFail(error,@"Die Epic-Wiederherstellung benötigt eine Prüfung; das Journal bleibt erhalten.");
    if([current isEqual:original])return YES;if(![current isEqual:mutation])return EFail(error,@"Epic hat die Startmetadaten inzwischen geändert. Die neueren Daten und das Wiederherstellungsjournal bleiben erhalten.");
    if(!EAtomic(journal[@"manifest"],original,[journal[@"mode"]unsignedShortValue]))return EFail(error,@"Die ursprünglichen Epic-Startmetadaten konnten nicht wiederhergestellt werden.");return YES;
}
static BOOL EJournalValid(NSDictionary *journal,NSString *state,NSString *manifests){
    if(![journal[@"version"]isEqual:@1]||!EToken(journal[@"nonce"])||![journal[@"nonce"]hasPrefix:@"TrainerDock-Epic-"])return NO;
    for(NSString *key in @[@"original",@"mutation",@"brokerSHA256",@"configSHA256"])if(![journal[key]isKindOfClass:NSString.class]||[journal[key]length]>ELimit*2)return NO;
    for(NSString *key in @[@"manifest",@"broker",@"config",@"receipt",@"target"])if(!EText(journal[key])||![journal[key]isAbsolutePath])return NO;
    if(![journal[@"manifest"]stringByDeletingLastPathComponent]||![[journal[@"manifest"]stringByDeletingLastPathComponent]isEqual:manifests]||![[journal[@"manifest"]pathExtension]isEqual:@"item"]||![[journal[@"receipt"]stringByDeletingLastPathComponent]isEqual:state]||![[journal[@"receipt"]lastPathComponent]isEqual:[journal[@"nonce"]stringByAppendingString:@".receipt"]]||![[journal[@"broker"]lastPathComponent]isEqual:journal[@"nonce"]]||![journal[@"config"]isEqual:[journal[@"broker"]stringByAppendingString:@".json"]])return NO;
    NSData *original=[[NSData alloc]initWithBase64EncodedString:journal[@"original"] options:0],*mutation=[[NSData alloc]initWithBase64EncodedString:journal[@"mutation"] options:0];NSDictionary *item=EJSON(original);
    if(!EText(item[@"InstallLocation"])||!EText(item[@"LaunchExecutable"])||[item[@"LaunchExecutable"]isAbsolutePath]||[[item[@"LaunchExecutable"]pathComponents]containsObject:@".."]||![item[@"LaunchCommand"]isEqual:@""])return NO;
    if(!original.length||original.length>ELimit||!mutation.length||mutation.length>ELimit||![EPatch(original,journal[@"nonce"])isEqual:mutation]||![item[@"InstallLocation"]isEqual:[journal[@"broker"]stringByDeletingLastPathComponent]]||![[item[@"InstallLocation"]stringByAppendingPathComponent:item[@"LaunchExecutable"]]isEqual:journal[@"target"]])return NO;
    return [journal[@"mode"]isKindOfClass:NSNumber.class]&&[journal[@"mode"]unsignedIntegerValue]<=0777;
}
static BOOL ECleanup(NSDictionary *journal,NSString *journalPath,NSDictionary *processes,NSError **error){
    if(!processes||EHasPath(processes,journal[@"broker"],0))return EFail(error,@"Der Epic-Starthelfer läuft noch. Bitte den Start abwarten; kein zweiter Start wurde ausgeführt.");
    for(NSString *key in @[@"broker",@"config"]){NSString *path=journal[key];struct stat s;if(lstat(path.fileSystemRepresentation,&s)){if(errno==ENOENT)continue;return EFail(error,@"Der Epic-Starthelfer konnte nicht bereinigt werden.");}
        if(!S_ISREG(s.st_mode)||s.st_uid!=getuid()||![EHash(path)isEqual:journal[[key stringByAppendingString:@"SHA256"]]])return EFail(error,@"Eine eigene Epic-Helferdatei wurde verändert; sie bleibt zur Prüfung erhalten.");
        if(unlink(path.fileSystemRepresentation))return EFail(error,@"Der Epic-Starthelfer konnte nicht bereinigt werden.");}
    NSString *receipt=journal[@"receipt"];struct stat s;if(!lstat(receipt.fileSystemRepresentation,&s)){if(!S_ISREG(s.st_mode)||s.st_uid!=getuid()||(s.st_mode&077)||unlink(receipt.fileSystemRepresentation))return EFail(error,@"Die Epic-Startbestätigung konnte nicht bereinigt werden.");}
    if(!ESyncDirectory([journal[@"broker"]stringByDeletingLastPathComponent])||unlink(journalPath.fileSystemRepresentation)||!ESyncDirectory(journalPath.stringByDeletingLastPathComponent))return EFail(error,@"Das Epic-Wiederherstellungsjournal bleibt zur Prüfung erhalten.");return YES;
}
static int ELock(NSString *state){
    if(!EPrivateDirectory(state,YES))return -1;NSString *path=[state stringByAppendingPathComponent:@"epic.lock"];int fd=open(path.fileSystemRepresentation,O_RDWR|O_CREAT|O_NOFOLLOW,0600);if(fd<0)return -1;struct stat s;
    if(fstat(fd,&s)||!S_ISREG(s.st_mode)||s.st_uid!=getuid()||(s.st_mode&077)||flock(fd,LOCK_EX|LOCK_NB)){close(fd);return -1;}return fd;
}

@interface MHTEpicOperation : NSObject
@property(copy) void (^completion)(NSRunningApplication *,NSError *);
@property(copy) NSDictionary *game;
@property(copy) NSDictionary *profile;
@property(copy) NSDictionary *environment;
@property(copy) NSDictionary *journal;
@property(copy) NSString *journalPath;
@property(strong) dispatch_source_t timer;
@property int lock;
@property BOOL finished;
@property BOOL cancelled;
@property BOOL acknowledged;
@property BOOL checkingApp;
@property NSTimeInterval deadline;
@end
@implementation MHTEpicOperation
- (instancetype)init{if((self=[super init]))_lock=-1;return self;}
- (void)dealloc{if(_lock>=0)close(_lock);}
@end

@interface MHTEpicLaunchService ()
@property(copy) NSURL *brokerURL;
@property(copy) NSString *stateDirectory;
@property(copy) NSString *manifestDirectory;
@property(strong) dispatch_queue_t queue;
@property(strong) MHTEpicOperation *pending;
@property(copy) BOOL (^clientRunning)(void);
@property(copy) NSDictionary *(^processes)(void);
@property(copy) BOOL (^openURI)(NSURL *);
@end
@implementation MHTEpicLaunchService
- (instancetype)initWithBrokerURL:(NSURL *)url{
    NSString *support=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"TrainerDock/Launch"];
    NSString *manifests=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Epic/EpicGamesLauncher/Data/Manifests"];
    return [self initWithBrokerURL:url manifestDirectory:manifests stateDirectory:support clientRunning:^BOOL{return EClientRunning();} processes:^NSDictionary *{return EProcesses();} openURI:^BOOL(NSURL *uri){return [NSWorkspace.sharedWorkspace openURL:uri];}];
}
// Dependency seams are used only by synthetic fixtures. Product initialization
// above always selects native process identities and the official URL handler.
- (instancetype)initWithBrokerURL:(NSURL *)url manifestDirectory:(NSString *)manifests stateDirectory:(NSString *)state clientRunning:(BOOL (^)(void))client processes:(NSDictionary *(^)(void))processes openURI:(BOOL (^)(NSURL *))open{
    if((self=[super init])){_brokerURL=[url copy];_manifestDirectory=[manifests copy];_stateDirectory=[state copy];_clientRunning=[client copy];_processes=[processes copy];_openURI=[open copy];_queue=dispatch_queue_create("local.trainerdock.epic-launch",DISPATCH_QUEUE_SERIAL);}return self;
}
- (BOOL)recoverLocked:(NSError **)error{
    NSString *path=[self.stateDirectory stringByAppendingPathComponent:@"epic.json"];struct stat s;if(lstat(path.fileSystemRepresentation,&s))return errno==ENOENT?YES:EFail(error,@"Das Epic-Wiederherstellungsjournal ist nicht lesbar.");
    NSDictionary *journal=EJSON(ERead(path,YES,ELimit*3));if(!EJournalValid(journal,self.stateDirectory,self.manifestDirectory))return EFail(error,@"Das Epic-Wiederherstellungsjournal passt nicht zu dieser Installation und bleibt erhalten.");
    return ERestore(journal,error)&&ECleanup(journal,path,self.processes(),error);
}
- (BOOL)recoverPendingTransactions:(NSError **)error{
    NSAssert(NSThread.isMainThread,@"Epic API requires the main queue");if(self.pending)return EFail(error,@"Ein Epic-Start wird bereits vorbereitet.");int lock=ELock(self.stateDirectory);if(lock<0)return EFail(error,@"Ein anderer TrainerDock-Start ist aktiv oder die private Startablage ist nicht zugänglich.");BOOL ok=[self recoverLocked:error];close(lock);return ok;
}
- (void)finish:(MHTEpicOperation *)operation app:(NSRunningApplication *)app error:(NSError *)error{
    if(operation.finished)return;operation.finished=YES;if(operation.timer){dispatch_source_cancel(operation.timer);operation.timer=nil;}
    NSError *cleanup=nil;if(operation.journal&&(!ERestore(operation.journal,&cleanup)||!ECleanup(operation.journal,operation.journalPath,self.processes(),&cleanup)))error=cleanup;
    if(operation.lock>=0){close(operation.lock);operation.lock=-1;}
    dispatch_async(dispatch_get_main_queue(),^{if(self.pending==operation)self.pending=nil;void(^completion)(NSRunningApplication *,NSError *)=operation.completion;operation.completion=nil;if(completion)completion(app,error);});
}
- (void)tick:(MHTEpicOperation *)operation{
    if(operation.finished)return;if(operation.cancelled){[self finish:operation app:nil error:EError(@"Der Epic-Start wurde abgebrochen; kein weiterer Start wurde ausgeführt.")];return;}
    NSDictionary *receipt=EJSON(ERead(operation.journal[@"receipt"],YES,16384));
    if(receipt){
        NSNumber *pid=receipt[@"pid"];NSString *started=receipt[@"started"];
        if(![receipt[@"nonce"]isEqual:operation.journal[@"nonce"]]||![pid isKindOfClass:NSNumber.class]||pid.intValue<=0||!EText(started)||![@[@"exec-attempt",@"exec-failed"]containsObject:receipt[@"state"]]){[self finish:operation app:nil error:EError(@"Die Epic-Startbestätigung passt nicht zum angeforderten Start.")];return;}
        NSError *error=nil;if(!operation.acknowledged){if(!ERestore(operation.journal,&error)){[self finish:operation app:nil error:error];return;}operation.acknowledged=YES;}
        if([receipt[@"state"]isEqual:@"exec-failed"]){[self finish:operation app:nil error:EError(@"Der Epic-Starthelfer konnte das unveränderte Originalspiel nicht starten.")];return;}
        NSDictionary *process=self.processes()[pid];
        if(process&&![process[@"started"]isEqual:started]){[self finish:operation app:nil error:EError(@"Die Epic-Prozesskennung wurde inzwischen wiederverwendet; kein weiterer Start wurde ausgeführt.")];return;}
        if([process[@"path"]isEqual:operation.game[@"executable"]]&&!operation.checkingApp){
            operation.checkingApp=YES;dispatch_async(dispatch_get_main_queue(),^{
                NSRunningApplication *app=[NSRunningApplication runningApplicationWithProcessIdentifier:pid.intValue];
                BOOL exact=app&&!app.terminated&&[app.executableURL.URLByResolvingSymlinksInPath.path isEqual:operation.game[@"executable"]]&&[app.bundleURL.URLByResolvingSymlinksInPath.path isEqual:operation.game[@"path"]]&&[app.bundleIdentifier isEqual:operation.profile[@"bundleIdentifier"]];
                dispatch_async(self.queue,^{operation.checkingApp=NO;if(exact&&!operation.finished&&!operation.cancelled)[self finish:operation app:app error:nil];});
            });
        }
    }
    if(NSProcessInfo.processInfo.systemUptime>=operation.deadline){BOOL running=EHasPath(self.processes(),operation.game[@"executable"],0);[self finish:operation app:nil error:EError(running?@"Das Originalspiel läuft, ist aber noch nicht als App registriert. Bitte diese Instanz prüfen; es wurde keine zweite gestartet.":@"Epic hat den Trainerstart nicht rechtzeitig bestätigt. Bitte Epic Games Launcher regulär beenden und den Start erneut auswählen.")];}
}
- (void)prepare:(MHTEpicOperation *)operation{
    NSError *error=nil;operation.lock=ELock(self.stateDirectory);if(operation.lock<0||![self recoverLocked:&error]){[self finish:operation app:nil error:error?:EError(@"Ein anderer Epic-Start ist aktiv oder die Startablage ist nicht zugänglich.")];return;}
    if(operation.cancelled){[self finish:operation app:nil error:EError(@"Der Epic-Start wurde abgebrochen.")];return;}
    NSDictionary *manifest=EFindManifest(self.manifestDirectory,operation.game,operation.profile);
    if(!manifest||!EEnvironment(operation.environment,operation.game[@"executable"])||EHasPath(self.processes(),operation.game[@"executable"],0)){[self finish:operation app:nil error:EError(@"Epic-Installation oder Trainerumgebung passt nicht zum geprüften Profil, oder das Spiel läuft bereits.")];return;}
    NSData *broker=EReadBroker(self.brokerURL.path);NSString *sha=EHash(operation.game[@"executable"]);
    if(!broker.length||!sha.length){[self finish:operation app:nil error:EError(@"Der native Epic-Starthelfer oder das Originalspiel ist nicht lesbar.")];return;}
    NSString *nonce=[@"TrainerDock-Epic-"stringByAppendingString:NSUUID.UUID.UUIDString],*brokerPath=[manifest[@"root"]stringByAppendingPathComponent:nonce],*configPath=[brokerPath stringByAppendingString:@".json"],*receipt=[self.stateDirectory stringByAppendingPathComponent:[nonce stringByAppendingString:@".receipt"]];
    NSData *config=EEncode(@{@"target":operation.game[@"executable"],@"targetSHA256":sha,@"environment":operation.environment,@"receipt":receipt,@"expires":@(NSDate.date.timeIntervalSince1970+100),@"nonce":nonce});
    NSData *mutation=EPatch(manifest[@"original"],nonce);struct stat original;
    if(config.length>65536||!config||!mutation||lstat([manifest[@"manifest"]fileSystemRepresentation],&original)){[self finish:operation app:nil error:EError(@"Die private Epic-Starttransaktion konnte nicht vorbereitet werden.")];return;}
    NSDictionary *journal=@{@"version":@1,@"manifest":manifest[@"manifest"],@"original":[manifest[@"original"]base64EncodedStringWithOptions:0],@"mutation":[mutation base64EncodedStringWithOptions:0],@"mode":@(original.st_mode&0777),@"broker":brokerPath,@"config":configPath,@"receipt":receipt,@"nonce":nonce,@"target":operation.game[@"executable"],@"brokerSHA256":EHashData(broker),@"configSHA256":EHashData(config)};
    operation.journalPath=[self.stateDirectory stringByAppendingPathComponent:@"epic.json"];
    if(!EAtomic(operation.journalPath,EEncode(journal),0600)){[self finish:operation app:nil error:EError(@"Das private Epic-Wiederherstellungsjournal konnte nicht gesichert werden.")];return;}operation.journal=journal;
    if(!EWriteNew(brokerPath,broker,0700)||!EWriteNew(configPath,config,0600)||!ESyncDirectory(manifest[@"root"])||![ERead(manifest[@"manifest"],NO,ELimit)isEqual:manifest[@"original"]]||!EAtomic(manifest[@"manifest"],mutation,original.st_mode&0777)){[self finish:operation app:nil error:EError(@"Epic-Startmetadaten wurden verändert oder der Starthelfer konnte nicht vorbereitet werden.")];return;}
    NSString *ids=[NSString stringWithFormat:@"%@:%@:%@",operation.profile[@"epicNamespace"],manifest[@"item"][@"CatalogItemId"],operation.profile[@"epicAppName"]];NSString *encoded=[ids stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];NSURL *uri=[NSURL URLWithString:[NSString stringWithFormat:@"com.epicgames.launcher://apps/%@?action=launch&silent=true",encoded]];
    operation.deadline=NSProcessInfo.processInfo.systemUptime+90;
    operation.timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,self.queue);dispatch_source_set_timer(operation.timer,dispatch_time(DISPATCH_TIME_NOW,0),100*NSEC_PER_MSEC,20*NSEC_PER_MSEC);
    __weak MHTEpicLaunchService *weakSelf=self;dispatch_source_set_event_handler(operation.timer,^{[weakSelf tick:operation];});dispatch_resume(operation.timer);
    dispatch_async(dispatch_get_main_queue(),^{
        if(self.pending!=operation||operation.cancelled)return;
        BOOL closed=!self.clientRunning();BOOL opened=closed&&uri&&self.openURI(uri);
        if(!opened)dispatch_async(self.queue,^{[self finish:operation app:nil error:EError(closed?@"Der offizielle Epic-Start konnte nicht angefordert werden.":@"Bitte Epic Games Launcher regulär beenden und den Trainerstart erneut auswählen.")];});
    });
}
- (void)launchGame:(NSDictionary *)game profile:(NSDictionary *)profile environment:(NSDictionary<NSString *,NSString *> *)environment completion:(void (^)(NSRunningApplication *,NSError *))completion{
    NSAssert(NSThread.isMainThread,@"Epic API requires the main queue");
    if(self.pending||self.clientRunning()){completion(nil,EError(self.pending?@"Ein Epic-Start wird bereits vorbereitet.":@"Bitte Epic Games Launcher regulär beenden und den Trainerstart erneut auswählen."));return;}
    MHTEpicOperation *operation=[MHTEpicOperation new];operation.game=[game copy];operation.profile=[profile copy];operation.environment=[environment copy];operation.completion=[completion copy];self.pending=operation;dispatch_async(self.queue,^{[self prepare:operation];});
}
- (void)cancelPendingLaunch{NSAssert(NSThread.isMainThread,@"Epic API requires the main queue");MHTEpicOperation *operation=self.pending;if(operation)dispatch_sync(self.queue,^{operation.cancelled=YES;[self finish:operation app:nil error:EError(@"Der Epic-Start wurde abgebrochen. Die ursprünglichen Startmetadaten werden wiederhergestellt.")];});}
@end

static BOOL EBrokerReceipt(NSString *path,NSString *nonce,NSString *state,BOOL create){
    if(!EText(path)||!path.isAbsolutePath||!EPrivateDirectory(path.stringByDeletingLastPathComponent,NO))return NO;
    int fd=open(path.fileSystemRepresentation,O_WRONLY|O_NOFOLLOW|(create?(O_CREAT|O_EXCL):0),0600);if(fd<0)return NO;struct stat s;
    if(fstat(fd,&s)||!S_ISREG(s.st_mode)||s.st_uid!=getuid()||(s.st_mode&077)||ftruncate(fd,0)){close(fd);return NO;}
    NSString *started=EStarted(getpid());NSData *data=started?EEncode(@{@"nonce":nonce,@"pid":@(getpid()),@"started":started,@"state":state}):nil;
    BOOL ok=data&&write(fd,data.bytes,data.length)==(ssize_t)data.length&&fsync(fd)==0;close(fd);return ok;
}
int MHTEpicBrokerMain(int argc,char **argv){@autoreleasepool{
    uint32_t size=PATH_MAX;char own[PATH_MAX],canonical[PATH_MAX];if(_NSGetExecutablePath(own,&size)||!realpath(own,canonical))return 70;
    NSDictionary *config=EJSON(ERead([@(canonical)stringByAppendingString:@".json"],YES,65536));NSString *target=config[@"target"],*nonce=config[@"nonce"];
    NSNumber *expires=config[@"expires"];NSDictionary *environment=config[@"environment"];
    if(!EToken(nonce)||![expires isKindOfClass:NSNumber.class]||expires.doubleValue<NSDate.date.timeIntervalSince1970||expires.doubleValue>NSDate.date.timeIntervalSince1970+180||!ECanonical(target)||![EHash(target)isEqual:config[@"targetSHA256"]]||!EEnvironment(environment,target)||EHasPath(EProcesses(),target,getpid()))return 70;
    // The original Epic argv is never examined, logged, or serialized.
    for(NSString *key in environment)if(setenv(key.UTF8String,[environment[key]UTF8String],1))return 70;
    if(!EBrokerReceipt(config[@"receipt"],nonce,@"exec-attempt",YES))return 70;argv[0]=(char *)target.fileSystemRepresentation;(void)argc;execv(argv[0],argv);
    int failure=errno;EBrokerReceipt(config[@"receipt"],nonce,@"exec-failed",NO);return failure==ENOENT?72:71;
}}
