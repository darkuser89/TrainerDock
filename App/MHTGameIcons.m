// SPDX-License-Identifier: GPL-3.0-only
#import "MHTGameIcons.h"
#import "MHTDiscovery.h"
static NSCache<NSString *,NSImage *> *iconCache(void) {
    static NSCache *cache;static dispatch_once_t once;
    dispatch_once(&once,^{cache=[NSCache new];cache.countLimit=48;});return cache;
}
NSImage *MHTGameIcon(MHTModule *module,NSDictionary *preferredProfile) {
    NSMutableArray *profiles=[NSMutableArray new];
    if(preferredProfile)[profiles addObject:preferredProfile];
    for(NSDictionary *profile in module.profiles)if(![profile isEqual:preferredProfile])[profiles addObject:profile];
    for(NSDictionary *profile in profiles){
        if(!MHTIsInstalled(module,profile))continue;
        NSString *path=[module pathForProfile:profile].stringByResolvingSymlinksInPath;
        NSImage *icon=[iconCache() objectForKey:path];
        if(!icon){
            // Steam also distributes valid application bundles without .app.
            if(![path.pathExtension isEqual:@"app"]){
                NSDictionary *info=[NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
                NSString *name=info[@"CFBundleIconFile"];
                if([name isKindOfClass:NSString.class] && name.length && [name isEqual:name.lastPathComponent]){
                    if(!name.pathExtension.length)name=[name stringByAppendingPathExtension:@"icns"];
                    icon=[[NSImage alloc]initWithContentsOfFile:[[path stringByAppendingPathComponent:@"Contents/Resources"] stringByAppendingPathComponent:name]];
                }
            }
            if(!icon)icon=[NSWorkspace.sharedWorkspace iconForFile:path];
            if(icon)[iconCache() setObject:icon forKey:path];
        }
        if(icon)return icon;
    }
    return [NSImage imageWithSystemSymbolName:@"gamecontroller" accessibilityDescription:@"Spiel nicht installiert"];
}
void MHTResetGameIcons(void){[iconCache() removeAllObjects];}
