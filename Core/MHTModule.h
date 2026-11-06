// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
@interface MHTModule : NSObject
@property(nonatomic,copy) NSDictionary *manifest;
@property(nonatomic,copy) NSString *directory;
@property(nonatomic,readonly) NSString *identifier;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSArray<NSDictionary *> *profiles;
@property(nonatomic,readonly) NSArray<NSDictionary *> *features;
// Presentation only; feature IDs and the native catalog remain unchanged.
@property(nonatomic,readonly) NSArray<NSDictionary *> *featureGroups;
+ (BOOL)validFeatureGroups:(id)groups featureCount:(NSUInteger)count;
+ (NSArray<MHTModule *> *)loadModules:(NSString *)directory errors:(NSMutableArray<NSString *> *)errors;
+ (NSString *)moduleDirectory;
+ (NSArray<MHTModule *> *)availableModules:(NSMutableArray<NSString *> *)errors;
- (NSString *)runtimePath;
- (NSString *)configurationPath;
- (NSString *)pathForProfile:(NSDictionary *)profile;
- (void)setPath:(NSString *)path forProfile:(NSDictionary *)profile;
- (NSDictionary *)settings;
- (void)saveSettings:(NSDictionary *)settings;
- (NSDictionary *)selection;
- (void)saveSelection:(NSDictionary *)selection;
- (NSDictionary *)inspectPath:(NSString *)path profile:(NSDictionary *)profile error:(NSError **)error;
- (NSDictionary *)environmentForGame:(NSDictionary *)game profile:(NSDictionary *)profile session:(NSString *)session;
@end
