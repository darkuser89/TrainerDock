// SPDX-License-Identifier: GPL-3.0-only
#import "MHTDiscovery.h"
BOOL MHTIsInstalled(MHTModule *module,NSDictionary *profile) {
    NSString *path=[module pathForProfile:profile];if(!path.length)return NO;
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
    return [info[@"CFBundleIdentifier"] isEqual:profile[@"bundleIdentifier"]];
}
NSDictionary *MHTFindInstallations(NSArray<MHTModule *> *modules,BOOL (^cancelled)(void)) {
    NSMutableSet *needed=[NSMutableSet new];
    for(MHTModule *module in modules)for(NSDictionary *profile in module.profiles)
        if(![module pathForProfile:profile].length && [profile[@"bundleIdentifier"] length])[needed addObject:profile[@"bundleIdentifier"]];
    if(!needed.count || (cancelled && cancelled()))return @{};
    NSString *steam=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Steam"];
    NSMutableOrderedSet *libraries=[NSMutableOrderedSet orderedSetWithObject:steam];
    NSString *vdf=[steam stringByAppendingPathComponent:@"steamapps/libraryfolders.vdf"];
    NSFileHandle *handle=[NSFileHandle fileHandleForReadingAtPath:vdf];
    NSData *bytes=[handle readDataUpToLength:1024*1024 error:NULL];[handle closeFile];
    NSString *text=bytes ? [[NSString alloc]initWithData:bytes encoding:NSUTF8StringEncoding] : nil;
    NSRegularExpression *paths=[NSRegularExpression regularExpressionWithPattern:@"\"path\"\\s*\"((?:\\\\.|[^\"\\\\])*)\"" options:0 error:NULL];
    for(NSTextCheckingResult *m in [paths matchesInString:text ?: @"" options:0 range:NSMakeRange(0,text.length)]) {
        NSString *path=[text substringWithRange:[m rangeAtIndex:1]];
        path=[path stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
        if(path.isAbsolutePath)[libraries addObject:path];
    }
    NSMutableArray *roots=[NSMutableArray arrayWithObjects:@"/Applications",[NSHomeDirectory() stringByAppendingPathComponent:@"Applications"],nil];
    for(NSString *library in libraries)[roots addObject:[library stringByAppendingPathComponent:@"steamapps/common"]];
    NSMutableDictionary *found=[NSMutableDictionary new];
    for(NSString *root in roots){
        if(!needed.count || (cancelled && cancelled()))break;
        NSDirectoryEnumerator *iterator=[NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:root]
            includingPropertiesForKeys:@[NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsPackageDescendants errorHandler:^BOOL(NSURL *url,NSError *error){(void)url;(void)error;return YES;}];
        NSUInteger count=0;
        for(NSURL *url in iterator){
            if(cancelled && cancelled())return @{};
            if(++count>10000)break;
            if(iterator.level>4){[iterator skipDescendants];continue;}
            NSNumber *directory=nil;[url getResourceValue:&directory forKey:NSURLIsDirectoryKey error:NULL];if(!directory.boolValue)continue;
            NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[url.path stringByAppendingPathComponent:@"Contents/Info.plist"]];
            NSString *bundle=info[@"CFBundleIdentifier"];
            if(bundle.length && [info[@"CFBundlePackageType"] isEqual:@"APPL"]){
                if([needed containsObject:bundle]){found[bundle]=url.path;[needed removeObject:bundle];}
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
        if(![module pathForProfile:profile].length && found[profile[@"bundleIdentifier"]]){
            [module setPath:found[profile[@"bundleIdentifier"]] forProfile:profile];changed=YES;
        }
    }
    return changed;
}
void MHTDiscoverInstallations(NSArray<MHTModule *> *modules) {
    MHTApplyInstallations(modules,MHTFindInstallations(modules,nil));
}
