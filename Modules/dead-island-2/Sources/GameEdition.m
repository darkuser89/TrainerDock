// SPDX-License-Identifier: GPL-3.0-only
#import "GameEdition.h"
#import <mach-o/loader.h>
#import <mach/machine.h>

DI2GameEdition DI2EditionForKey(NSString *key) {
    return [key isEqualToString:@"mas"] ? DI2EditionMAS : [key isEqualToString:@"steam"] ? DI2EditionSteam : DI2EditionUnknown;
}
NSString *DI2EditionKey(DI2GameEdition edition) { return edition==DI2EditionMAS ? @"mas" : edition==DI2EditionSteam ? @"steam" : @""; }
NSString *DI2EditionTitle(DI2GameEdition edition) { return edition==DI2EditionMAS ? @"Mac App Store" : edition==DI2EditionSteam ? @"Steam" : @"Unbekannt"; }
NSString *DI2EditionBundleID(DI2GameEdition edition) { return edition==DI2EditionMAS ? @"com.plaion.DeadIsland2Usk" : edition==DI2EditionSteam ? @"com.plaion.DeadIsland2" : @""; }
NSString *DI2SteamDefaultPathFromRoot(NSString *steamRoot) {
    NSString *suffix=@"steamapps/common/Dead Island 2/DeadIsland2.app";
    NSString *fallback=[steamRoot stringByAppendingPathComponent:suffix];
    NSMutableOrderedSet<NSString *> *libraries=[NSMutableOrderedSet orderedSetWithObject:steamRoot];
    NSString *configuration=[steamRoot stringByAppendingPathComponent:@"steamapps/libraryfolders.vdf"];
    NSFileHandle *file=[NSFileHandle fileHandleForReadingFromURL:[NSURL fileURLWithPath:configuration] error:NULL];
    NSData *data=[file readDataUpToLength:1024*1024+1 error:NULL]; [file closeAndReturnError:NULL];
    NSString *text=data && data.length<=1024*1024 ? [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (text) {
        NSRegularExpression *paths=[NSRegularExpression regularExpressionWithPattern:@"\"path\"\\s*\"((?:\\\\.|[^\"\\\\])*)\"" options:0 error:NULL];
        for (NSTextCheckingResult *match in [paths matchesInString:text options:0 range:NSMakeRange(0,text.length)]) {
            NSString *path=[text substringWithRange:[match rangeAtIndex:1]];
            path=[[path stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""] stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
            if (path.isAbsolutePath) [libraries addObject:path.stringByStandardizingPath];
        }
    }
    for (NSString *library in libraries) {
        NSString *candidate=[library stringByAppendingPathComponent:suffix]; BOOL directory=NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:candidate isDirectory:&directory] && directory) return candidate;
    }
    return fallback;
}
NSString *DI2EditionDefaultPath(DI2GameEdition edition) {
    return edition==DI2EditionMAS ? @"/Applications/DeadIsland2.app"
        : edition==DI2EditionSteam ? DI2SteamDefaultPathFromRoot([NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Steam"]) : @"";
}
NSString *DI2EditionUUID(DI2GameEdition edition) {
    return edition==DI2EditionMAS ? @"33AE24EE-5FDC-379A-BD9E-8B1BDE36B6EC"
        : edition==DI2EditionSteam ? @"9EB36C68-45E5-3C11-B465-FFD49164B1DA" : @"";
}
DI2GameEdition DI2EditionForUUID(const uint8_t *uuid) {
    if (!uuid) return DI2EditionUnknown;
    static const uint8_t mas[16]={0x33,0xae,0x24,0xee,0x5f,0xdc,0x37,0x9a,0xbd,0x9e,0x8b,0x1b,0xde,0x36,0xb6,0xec};
    static const uint8_t steam[16]={0x9e,0xb3,0x6c,0x68,0x45,0xe5,0x3c,0x11,0xb4,0x65,0xff,0xd4,0x91,0x64,0xb1,0xda};
    return !memcmp(uuid,mas,16) ? DI2EditionMAS : !memcmp(uuid,steam,16) ? DI2EditionSteam : DI2EditionUnknown;
}
static NSDictionary *failure(NSError **error, NSString *reason) {
    if (error) *error=[NSError errorWithDomain:@"local.deadisland2.trainer.installation" code:1 userInfo:@{NSLocalizedDescriptionKey:reason}];
    return nil;
}
NSDictionary *DI2InspectGame(NSString *path, DI2GameEdition edition, NSError **error) {
    if (edition==DI2EditionUnknown || ![path isKindOfClass:NSString.class] || !path.isAbsolutePath)
        return failure(error,@"Bitte eine Spiele-App für die gewählte Version auswählen.");
    NSString *canonical=path.stringByStandardizingPath.stringByResolvingSymlinksInPath;
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:[canonical stringByAppendingPathComponent:@"Contents/Info.plist"]] error:NULL];
    if (![info[@"CFBundleIdentifier"] isEqual:DI2EditionBundleID(edition)] || ![info[@"CFBundleExecutable"] isEqual:@"DeadIsland2"])
        return failure(error,[NSString stringWithFormat:@"Keine passende %@-Installation gefunden.",DI2EditionTitle(edition)]);
    NSString *executable=[canonical stringByAppendingPathComponent:@"Contents/MacOS/DeadIsland2"];
    NSFileHandle *file=[NSFileHandle fileHandleForReadingFromURL:[NSURL fileURLWithPath:executable] error:NULL];
    if (!file) return failure(error,@"Die ausführbare Spiele-Datei ist nicht lesbar.");
    DI2GameEdition actual=DI2EditionUnknown;
    @try {
        NSData *data=[file readDataUpToLength:sizeof(struct mach_header_64) error:NULL];
        struct mach_header_64 header={0};
        if (data.length==sizeof(header)) memcpy(&header,data.bytes,sizeof(header));
        if (header.magic==MH_MAGIC_64 && header.filetype==MH_EXECUTE && header.cputype==CPU_TYPE_ARM64 && header.sizeofcmds<=1024*1024 && header.ncmds<=4096) {
            NSData *commands=[file readDataUpToLength:header.sizeofcmds error:NULL]; size_t offset=0;
            BOOL complete=commands.length==header.sizeofcmds;
            for (uint32_t i=0;commands.length==header.sizeofcmds && i<header.ncmds;i++) {
                struct load_command command={0};
                if (offset>commands.length || sizeof(command)>commands.length-offset) { complete=NO; break; }
                memcpy(&command,(const uint8_t *)commands.bytes+offset,sizeof(command));
                if (command.cmdsize<sizeof(command) || command.cmdsize>commands.length-offset) { complete=NO; break; }
                if (command.cmd==LC_UUID && command.cmdsize==sizeof(struct uuid_command)) {
                    struct uuid_command uuid={0};memcpy(&uuid,(const uint8_t *)commands.bytes+offset,sizeof(uuid));
                    actual=DI2EditionForUUID(uuid.uuid);
                }
                offset+=command.cmdsize;
            }
            if (!complete || offset!=commands.length) actual=DI2EditionUnknown;
        }
    } @catch (NSException *exception) { (void)exception; actual=DI2EditionUnknown; }
    [file closeFile];
    if (actual!=edition) return failure(error,@"Dieser Spiel-Build ist nicht freigegeben. Unterstützt werden die geprüften arm64-Builds 0.6.4.");
    if (edition==DI2EditionSteam && ![NSFileManager.defaultManager isReadableFileAtPath:[canonical stringByAppendingPathComponent:@"Contents/MacOS/libsteam_api.dylib"]])
        return failure(error,@"Die Steam-Bibliothek fehlt in der gewählten Installation.");
    return @{@"path":canonical,@"executable":executable,@"edition":DI2EditionKey(edition),@"version":info[@"CFBundleShortVersionString"] ?: @"?",@"uuid":DI2EditionUUID(edition)};
}
