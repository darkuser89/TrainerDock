// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "MHTModule.h"
FOUNDATION_EXPORT NSString *const MHTTrainerStoreDidChangeNotification;
FOUNDATION_EXPORT NSString *const MHTTrainerCatalogAddress;
FOUNDATION_EXPORT BOOL MHTTrainerVersion(NSString *version);
FOUNDATION_EXPORT NSComparisonResult MHTCompareTrainerVersions(NSString *a,NSString *b);
@interface MHTTrainerStore : NSObject
@property(nonatomic,readonly,copy) NSString *rootDirectory;
@property(atomic,readonly,copy) NSDictionary *catalog;
@property(nonatomic,readonly,copy) NSArray<MHTModule *> *modules;
@property(atomic,readonly) BOOL refreshing;
@property(nonatomic,readonly,copy) NSSet<NSString *> *installingIdentifiers;
@property(atomic,readonly,strong) NSError *lastError;
+ (instancetype)sharedStore;
- (instancetype)initWithRootDirectory:(NSString *)directory catalogURL:(NSURL *)url bundledCatalogURL:(NSURL *)bundle;
// Remote catalogs require exact GitHub package URLs and SHA-256; bundled
// metadata may describe a not-yet-published package without download fields.
+ (NSDictionary *)validatedCatalog:(id)value requireDownloads:(BOOL)required error:(NSError **)error;
- (NSArray<MHTModule *> *)modulesWithErrors:(NSMutableArray<NSString *> *)errors;
- (NSArray<NSDictionary *> *)versionsForIdentifier:(NSString *)identifier;
- (NSArray<MHTModule *> *)installedVersionsForIdentifier:(NSString *)identifier;
// Latest downloads for installed trainers only; never reinstall an existing
// release or downgrade a newer local version. Legacy conversion is included.
- (NSArray<NSDictionary *> *)updatesForInstalledTrainers;
- (void)refreshCatalogWithCompletion:(void (^)(NSError *error))completion;
- (void)installVersion:(NSDictionary *)version forIdentifier:(NSString *)identifier completion:(void (^)(MHTModule *module,NSError *error))completion;
// Synchronous local archive boundary for reproducible integration/security tests.
- (MHTModule *)installArchive:(NSURL *)archive version:(NSDictionary *)version forIdentifier:(NSString *)identifier error:(NSError **)error;
- (MHTModule *)importLegacyModule:(MHTModule *)module error:(NSError **)error;
- (BOOL)selectModule:(MHTModule *)module error:(NSError **)error;
- (BOOL)removeModule:(MHTModule *)module protectedRuntimePaths:(NSSet<NSString *> *)paths error:(NSError **)error;
// Tries all installed versions against the selected store profile and actual
// installed original. The exact matching module supplies its own profile.
- (MHTModule *)moduleForIdentifier:(NSString *)identifier profile:(NSDictionary *)profile path:(NSString *)path error:(NSError **)error;
- (MHTModule *)moduleForIdentifier:(NSString *)identifier profile:(NSDictionary *)profile path:(NSString *)path matchingProfile:(NSDictionary **)matchingProfile game:(NSDictionary **)game error:(NSError **)error;
@end
