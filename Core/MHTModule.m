// SPDX-License-Identifier: GPL-3.0-only
#import "MHTModule.h"
#import "GameIdentity.h"
#import "MHTGlassIntensity.h"
#include <math.h>
static BOOL text(id v){return [v isKindOfClass:NSString.class] && [v length]>0;}
static BOOL token(id v){return text(v) && [v rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"] invertedSet]].location==NSNotFound;}
static BOOL number(id v){return [v isKindOfClass:NSNumber.class] && isfinite([v doubleValue]);}
@implementation MHTModule
- (NSString *)identifier{return self.manifest[@"id"];}
- (NSString *)name{return self.manifest[@"name"];}
- (NSArray *)profiles{return self.manifest[@"profiles"];}
- (NSArray *)features{return self.manifest[@"features"];}
- (NSArray *)featureGroups {
    if(self.manifest[@"groups"])return self.manifest[@"groups"];
    NSMutableArray *ids=[NSMutableArray new];for(NSDictionary *f in self.features)[ids addObject:f[@"id"]];
    return @[@{@"id":@"trainer",@"title":@"Trainer",@"symbol":@"slider.horizontal.3",@"features":ids}];
}
+ (BOOL)validFeatureGroups:(id)groups featureCount:(NSUInteger)count {
    if(!groups)return YES; // Existing third-party modules keep a single section.
    if(![groups isKindOfClass:NSArray.class] || ![groups count] || [groups count]>count)return NO;
    NSMutableSet *names=[NSMutableSet new],*seen=[NSMutableSet new];
    for(id group in groups){
        if(![group isKindOfClass:NSDictionary.class] || !token(group[@"id"]) || [names containsObject:group[@"id"]]
           || !text(group[@"title"]) || [group[@"title"] length]>80 || !text(group[@"symbol"]) || [group[@"symbol"] length]>80
           || ![group[@"features"] isKindOfClass:NSArray.class] || ![group[@"features"] count])return NO;
        [names addObject:group[@"id"]];
        for(id feature in group[@"features"]){
            if(!number(feature) || [feature doubleValue]!=[feature integerValue] || [feature integerValue]<0
               || [feature unsignedIntegerValue]>=count || [seen containsObject:feature])return NO;
            [seen addObject:feature];
        }
    }
    return seen.count==count;
}
+ (NSString *)moduleDirectory {
    NSString *bundled=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Modules"];
    BOOL directory=NO;
    if([NSFileManager.defaultManager fileExistsAtPath:bundled isDirectory:&directory] && directory)return bundled;
    return [NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Modules"];
}
+ (NSArray<MHTModule *> *)availableModules:(NSMutableArray<NSString *> *)errors {
    NSMutableDictionary *byID=[NSMutableDictionary new];
    for(MHTModule *module in [self loadModules:self.moduleDirectory errors:errors])byID[module.identifier]=module;
    // Read the old location first; TrainerDock modules take precedence by ID.
    for(NSString *folder in @[@"MHT",@"TrainerDock"]) {
        NSString *user=[NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Application Support/%@/Modules",folder]];
        for(MHTModule *module in [self loadModules:user errors:errors])byID[module.identifier]=module;
    }
    return [byID.allValues sortedArrayUsingComparator:^NSComparisonResult(MHTModule *a,MHTModule *b){return [a.name localizedCaseInsensitiveCompare:b.name];}];
}
+ (NSArray<MHTModule *> *)loadModules:(NSString *)directory errors:(NSMutableArray<NSString *> *)errors {
    NSMutableArray *modules=[NSMutableArray new];NSMutableSet *ids=[NSMutableSet new];
    NSArray *files=[[NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:NULL] sortedArrayUsingSelector:@selector(compare:)];
    for(NSString *file in files){
        if(![file.pathExtension isEqual:@"mhtmodule"])continue;
        NSString *dir=[directory stringByAppendingPathComponent:file];
        NSData *data=[NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@"Module.json"]];
        id m=data.length<=1024*1024 ? [NSJSONSerialization JSONObjectWithData:data ?: [NSData data] options:0 error:NULL] : nil;
        BOOL valid=[m isKindOfClass:NSDictionary.class] && [m[@"schemaVersion"] isEqual:@1] && token(m[@"id"])
            && text(m[@"name"]) && text(m[@"version"])
            && (!m[@"selectionVersion"] || (token(m[@"selectionVersion"]) && [m[@"selectionVersion"] length]<=64))
            && [m[@"profiles"] isKindOfClass:NSArray.class] && [m[@"profiles"] count]>0
            && [m[@"features"] isKindOfClass:NSArray.class] && [m[@"features"] count]>0 && [m[@"features"] count]<=128;
        if(valid){
            valid=[self validFeatureGroups:m[@"groups"] featureCount:[m[@"features"] count]];
            for(id profile in m[@"profiles"]){
                if(![profile isKindOfClass:NSDictionary.class]){valid=NO;continue;}
                if(!text(profile[@"store"]) || !text(profile[@"version"]))valid=NO;
                if(profile[@"compatibilityNote"] && (!text(profile[@"compatibilityNote"]) || [profile[@"compatibilityNote"] length]>120))valid=NO;
                for(NSString *key in @[@"epicAppName",@"epicNamespace"])
                    if(profile[key] && (!token(profile[key]) || [profile[key] length]>256))valid=NO;
                if(profile[@"epicNamespace"] && !profile[@"epicAppName"])valid=NO;
                if(profile[@"launchMode"] && ![@[@"app",@"executable",@"epic"] containsObject:profile[@"launchMode"]])valid=NO;
                if([profile[@"launchMode"] isEqual:@"epic"] && (!token(profile[@"epicAppName"]) || !token(profile[@"epicNamespace"])))valid=NO;
            }
            NSUInteger i=0;
            for(id f in m[@"features"]){
                if(![f isKindOfClass:NSDictionary.class] || ![f[@"id"] isEqual:@(i++)] || !text(f[@"title"]) || !text(f[@"binding"])) {valid=NO;break;}
                for(NSString *key in @[@"implemented",@"numeric",@"oneShot",@"integer",@"initial",@"minimum",@"maximum",@"step"])
                    if(!number(f[key]))valid=NO;
                if([f[@"numeric"] boolValue] && ([f[@"minimum"] doubleValue]>[f[@"maximum"] doubleValue]
                   || [f[@"initial"] doubleValue]<[f[@"minimum"] doubleValue] || [f[@"initial"] doubleValue]>[f[@"maximum"] doubleValue]))valid=NO;
            }
        }
        MHTModule *module=[MHTModule new];module.directory=dir;module.manifest=m;
        NSError *error=nil;NSDictionary *config=valid ? MTLoadConfiguration(module.configurationPath,&error) : nil;
        if(!valid || [ids containsObject:m[@"id"]] || !config || ![config[@"profiles"] isEqual:m[@"profiles"]]
           || ![NSFileManager.defaultManager isReadableFileAtPath:module.runtimePath]) {
            [errors addObject:[NSString stringWithFormat:@"%@: ungültiger oder unvollständiger Trainer%@",file,error ? [@" · " stringByAppendingString:error.localizedDescription] : @""]];continue;
        }
        [ids addObject:module.identifier];[modules addObject:module];
    }
    return [modules sortedArrayUsingComparator:^NSComparisonResult(MHTModule *a,MHTModule *b){return [a.name localizedCaseInsensitiveCompare:b.name];}];
}
- (NSString *)runtimePath{return [self.directory stringByAppendingPathComponent:@"Trainer.dylib"];}
- (NSString *)configurationPath{return [self.directory stringByAppendingPathComponent:@"TrainerConfig.json"];}
- (NSString *)key:(NSString *)suffix{return [NSString stringWithFormat:@"MHT.%@.%@",self.identifier,suffix];}
- (NSString *)pathForProfile:(NSDictionary *)profile {
    NSString *path=[NSUserDefaults.standardUserDefaults stringForKey:[self key:[@"path." stringByAppendingString:profile[@"id"]]]];
    if(path.length)return path;
    // LaunchServices has one arbitrary answer for a shared bundle identifier.
    // Epic and Steam installations must instead be discovered per profile.
    if(text(profile[@"epicAppName"]))return nil;
    for(NSDictionary *other in self.profiles)
        if([other[@"bundleIdentifier"] isEqual:profile[@"bundleIdentifier"]]
           && text(other[@"store"]) && text(profile[@"store"])
           && ![other[@"store"] isEqual:profile[@"store"]])return nil;
    return [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:profile[@"bundleIdentifier"]].path;
}
- (void)setPath:(NSString *)path forProfile:(NSDictionary *)profile {
    NSString *key=[self key:[@"path." stringByAppendingString:profile[@"id"]]];
    if(path.length)[NSUserDefaults.standardUserDefaults setObject:path forKey:key];else [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
}
- (NSDictionary *)settings {
    NSDictionary *saved=[NSUserDefaults.standardUserDefaults dictionaryForKey:[self key:@"settings"]];
    NSMutableDictionary *s=[@{@"liquidGlass":@YES,@"scale":@0.9,@"position":@"top-left",@"draggable":@YES,@"visible":@NO,@"mouse":@YES,@"badge":@NO,@"restore":@NO} mutableCopy];
    if(saved)[s addEntriesFromDictionary:saved];s[@"liquidGlass"]=@YES;s[@"glassIntensity"]=@(MHTGlassIntensity(s[@"glassIntensity"]));return s;
}
- (void)saveSettings:(NSDictionary *)settings {
    NSMutableDictionary *options=[settings mutableCopy];options[@"liquidGlass"]=@YES;options[@"glassIntensity"]=@(MHTGlassIntensity(options[@"glassIntensity"]));
    [NSUserDefaults.standardUserDefaults setObject:options forKey:[self key:@"settings"]];
}
- (NSString *)selectionPreferenceKey {
    NSString *version=self.manifest[@"selectionVersion"];
    return [self key:token(version) ? [@"selection." stringByAppendingString:version] : @"selection"];
}
- (NSDictionary *)selection {
    NSDictionary *saved=[NSUserDefaults.standardUserDefaults dictionaryForKey:self.selectionPreferenceKey];
    NSMutableDictionary *rows=[NSMutableDictionary new];
    for(NSDictionary *f in self.features){
        NSString *key=[f[@"id"] stringValue];NSDictionary *s=[saved[key] isKindOfClass:NSDictionary.class] ? saved[key] : @{};
        double value=number(s[@"value"]) ? [s[@"value"] doubleValue] : [f[@"initial"] doubleValue];
        if(value<[f[@"minimum"] doubleValue] || value>[f[@"maximum"] doubleValue] || ([f[@"integer"] boolValue] && floor(value)!=value))value=[f[@"initial"] doubleValue];
        rows[key]=@{@"wanted":@(![f[@"oneShot"] boolValue] && [f[@"implemented"] boolValue] && number(s[@"wanted"]) && [s[@"wanted"] boolValue]),@"value":@(value)};
    }return rows;
}
- (void)saveSelection:(NSDictionary *)selection{[NSUserDefaults.standardUserDefaults setObject:selection forKey:self.selectionPreferenceKey];}
- (NSDictionary *)inspectPath:(NSString *)path profile:(NSDictionary *)profile error:(NSError **)error {
    return MTInspectGame(path,profile,error);
}
- (NSDictionary *)environmentForGame:(NSDictionary *)game profile:(NSDictionary *)profile session:(NSString *)session {
    NSMutableDictionary *e=[@{@"DYLD_INSERT_LIBRARIES":self.runtimePath,@"MHT_MODULE":self.identifier,@"MHT_SESSION":session,
        @"MHT_TARGET":game[@"executable"],@"MHT_CONFIG":self.configurationPath,@"MHT_PROFILE":profile[@"id"]} mutableCopy];
    if([game[@"libraryDirectory"] isKindOfClass:NSString.class])e[@"DYLD_LIBRARY_PATH"]=game[@"libraryDirectory"];
    NSDictionary *custom=[profile[@"launchEnvironment"] isKindOfClass:NSDictionary.class] ? profile[@"launchEnvironment"] : @{};
    // Module environment may provide distribution-specific identifiers, but cannot replace the common protocol.
    for(NSString *key in custom)if(![key hasPrefix:@"MHT_"] && ![key hasPrefix:@"DYLD_"] && [custom[key] isKindOfClass:NSString.class])e[key]=custom[key];
    NSMutableDictionary *options=[self.settings mutableCopy];options[@"visible"]=@NO;
    NSData *data=[NSJSONSerialization dataWithJSONObject:options options:0 error:NULL];
    e[@"MHT_OPTIONS"]=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSMutableDictionary *entries=[NSMutableDictionary new];NSDictionary *selection=self.selection;
    for(NSDictionary *f in self.features){
        NSMutableDictionary *entry=[selection[[f[@"id"] stringValue]] mutableCopy];
        if(![options[@"restore"] boolValue] || [f[@"oneShot"] boolValue])entry[@"wanted"]=@NO;
        entries[[f[@"id"] stringValue]]=entry;
    }
    data=[NSJSONSerialization dataWithJSONObject:@{@"features":entries} options:0 error:NULL];
    e[@"MHT_SELECTION"]=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return e;
}
@end
