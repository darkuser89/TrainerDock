// SPDX-License-Identifier: GPL-3.0-only
#import "MHTDiscovery.h"
static BOOL text(id value){return [value isKindOfClass:NSString.class] && [value length]>0;}
NSString *MHTInstallationKey(MHTModule *module,NSDictionary *profile){
    return [NSString stringWithFormat:@"profile:%@/%@",module.identifier,profile[@"id"]];
}
static BOOL sharedStoreIdentity(MHTModule *module,NSDictionary *profile){
    for(NSDictionary *other in module.profiles)
        if([other[@"bundleIdentifier"] isEqual:profile[@"bundleIdentifier"]]
           && text(other[@"store"]) && text(profile[@"store"])
           && ![other[@"store"] isEqual:profile[@"store"]])return YES;
    return NO;
}
BOOL MHTIsInstalled(MHTModule *module,NSDictionary *profile) {
    NSString *path=[module pathForProfile:profile];if(!path.length)return NO;
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
    return [info[@"CFBundleIdentifier"] isEqual:profile[@"bundleIdentifier"]];
}
static NSDictionary *smallJSON(NSString *path){
    NSFileHandle *file=[NSFileHandle fileHandleForReadingAtPath:path];
    NSData *data=[file readDataUpToLength:1024*1024+1 error:NULL];[file closeFile];
    if(!data.length || data.length>1024*1024)return nil;
    id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}
static BOOL pathText(id value){
    return text(value) && [value length]<=4096 && [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;
}
static NSString *epicBundle(NSDictionary *item,NSDictionary *profile){
    if(!text(profile[@"epicAppName"]) || ![item[@"AppName"] isEqual:profile[@"epicAppName"]])return nil;
    if(profile[@"epicNamespace"] && ![item[@"CatalogNamespace"] isEqual:profile[@"epicNamespace"]])return nil;
    NSString *location=item[@"InstallLocation"],*relative=item[@"LaunchExecutable"];
    if(!pathText(location) || !location.isAbsolutePath || !pathText(relative) || relative.isAbsolutePath
       || [relative.pathComponents containsObject:@".."] || [relative containsString:@"\\"])return nil;
    NSString *root=location.stringByStandardizingPath.stringByResolvingSymlinksInPath;
    NSString *executable=[root stringByAppendingPathComponent:relative].stringByStandardizingPath.stringByResolvingSymlinksInPath;
    if(![executable hasPrefix:[root stringByAppendingString:@"/"]]
       || ![executable.lastPathComponent isEqual:profile[@"executable"]]
       || ![NSFileManager.defaultManager isReadableFileAtPath:executable])return nil;
    NSString *macOS=executable.stringByDeletingLastPathComponent,*contents=macOS.stringByDeletingLastPathComponent;
    if(![macOS.lastPathComponent isEqual:@"MacOS"] || ![contents.lastPathComponent isEqual:@"Contents"])return nil;
    NSString *bundle=contents.stringByDeletingLastPathComponent;
    if(![bundle hasPrefix:[root stringByAppendingString:@"/"]] && ![bundle isEqual:root])return nil;
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[contents stringByAppendingPathComponent:@"Info.plist"]];
    if(![info[@"CFBundlePackageType"] isEqual:@"APPL"] || ![info[@"CFBundleIdentifier"] isEqual:profile[@"bundleIdentifier"]]
       || ![info[@"CFBundleExecutable"] isEqual:profile[@"executable"]])return nil;
    return bundle;
}
NSDictionary *MHTFindEpicInstallations(NSArray<MHTModule *> *modules,NSString *directory,BOOL (^cancelled)(void)){
    if(!directory.isAbsolutePath || (cancelled && cancelled()))return @{};
    NSMutableDictionary *needed=[NSMutableDictionary new],*candidates=[NSMutableDictionary new];
    for(MHTModule *module in modules)for(NSDictionary *profile in module.profiles)
        if(text(profile[@"epicAppName"]) && ![module pathForProfile:profile].length)
            needed[MHTInstallationKey(module,profile)]=profile;
    if(!needed.count)return @{};
    NSArray *files=[[NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:NULL] sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger examined=0;
    for(NSString *file in files){
        if(cancelled && cancelled())return @{};
        if(++examined>1024)break;
        if(![file.pathExtension isEqual:@"item"])continue;
        NSDictionary *item=smallJSON([directory stringByAppendingPathComponent:file]);if(!item)continue;
        for(NSString *key in needed){
            NSString *bundle=epicBundle(item,needed[key]);if(!bundle)continue;
            if(!candidates[key])candidates[key]=[NSMutableSet new];[candidates[key] addObject:bundle];
        }
    }
    NSMutableDictionary *found=[NSMutableDictionary new];
    for(NSString *key in candidates)if([candidates[key] count]==1)found[key]=[candidates[key] anyObject];
    return found;
}
NSDictionary *MHTFindInstallations(NSArray<MHTModule *> *modules,BOOL (^cancelled)(void)) {
    NSMutableDictionary *needed=[NSMutableDictionary new];
    for(MHTModule *module in modules)for(NSDictionary *profile in module.profiles)
        if(![module pathForProfile:profile].length && [profile[@"bundleIdentifier"] length])needed[MHTInstallationKey(module,profile)]=profile;
    if(!needed.count || (cancelled && cancelled()))return @{};
    NSString *epic=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Epic/EpicGamesLauncher/Data/Manifests"];
    NSMutableDictionary *found=[MHTFindEpicInstallations(modules,epic,cancelled) mutableCopy];
    [needed removeObjectsForKeys:found.allKeys];
    NSString *steam=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Steam"];
    NSMutableOrderedSet *libraries=[NSMutableOrderedSet orderedSetWithObject:steam];
    NSString *vdf=[steam stringByAppendingPathComponent:@"steamapps/libraryfolders.vdf"];
    NSFileHandle *handle=[NSFileHandle fileHandleForReadingAtPath:vdf];
    NSData *bytes=[handle readDataUpToLength:1024*1024 error:NULL];[handle closeFile];
    NSString *contents=bytes ? [[NSString alloc]initWithData:bytes encoding:NSUTF8StringEncoding] : nil;
    NSRegularExpression *paths=[NSRegularExpression regularExpressionWithPattern:@"\"path\"\\s*\"((?:\\\\.|[^\"\\\\])*)\"" options:0 error:NULL];
    for(NSTextCheckingResult *m in [paths matchesInString:contents ?: @"" options:0 range:NSMakeRange(0,contents.length)]) {
        NSString *path=[contents substringWithRange:[m rangeAtIndex:1]];
        path=[path stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
        if(path.isAbsolutePath)[libraries addObject:path];
    }
    NSMutableArray *roots=[NSMutableArray arrayWithObjects:@{@"path":@"/Applications",@"store":@""},@{@"path":[NSHomeDirectory() stringByAppendingPathComponent:@"Applications"],@"store":@""},nil];
    for(NSString *library in libraries)[roots addObject:@{@"path":[library stringByAppendingPathComponent:@"steamapps/common"],@"store":@"Steam"}];
    for(NSDictionary *source in roots){
        if(!needed.count || (cancelled && cancelled()))break;
        NSDirectoryEnumerator *iterator=[NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:source[@"path"]]
            includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsPackageDescendants errorHandler:^BOOL(NSURL *url,NSError *error){(void)url;(void)error;return YES;}];
        NSUInteger count=0;
        for(NSURL *url in iterator){
            if(cancelled && cancelled())return @{};
            if(++count>10000)break;
            if(iterator.level>4){[iterator skipDescendants];continue;}
            NSNumber *isDirectory=nil;[url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];if(!isDirectory.boolValue)continue;
            NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[url.path stringByAppendingPathComponent:@"Contents/Info.plist"]];
            NSString *bundle=info[@"CFBundleIdentifier"];
            if(bundle.length && [info[@"CFBundlePackageType"] isEqual:@"APPL"]){
                for(NSString *key in needed.allKeys){
                    NSDictionary *profile=needed[key];
                    if(text(profile[@"epicAppName"]))continue;
                    BOOL steamProfile=[profile[@"store"] isEqual:@"Steam"],steamSource=[source[@"store"] isEqual:@"Steam"];
                    if(steamProfile!=steamSource || ![profile[@"bundleIdentifier"] isEqual:bundle])continue;
                    found[key]=url.path;[needed removeObjectForKey:key];
                }
                [iterator skipDescendants];if(!needed.count)break;
            }
        }
    }
    return found;
}
BOOL MHTApplyInstallations(NSArray<MHTModule *> *modules,NSDictionary *found) {
    BOOL changed=NO;
    for(MHTModule *module in modules)for(NSDictionary *profile in module.profiles) {
        // Explicit paths are never overwritten, including disconnected external drives.
        if([module pathForProfile:profile].length)continue;
        NSString *path=found[MHTInstallationKey(module,profile)];
        // Accept old unambiguous discovery snapshots without sharing them across stores.
        if(!path && !text(profile[@"epicAppName"]) && !sharedStoreIdentity(module,profile))path=found[profile[@"bundleIdentifier"]];
        if(path.length){[module setPath:path forProfile:profile];changed=YES;}
    }
    return changed;
}
void MHTDiscoverInstallations(NSArray<MHTModule *> *modules) {
    MHTApplyInstallations(modules,MHTFindInstallations(modules,nil));
}
