// SPDX-License-Identifier: GPL-3.0-only
#import "MHTModule.h"
#import "MHTTrainerStore.h"
#import "MHTProtocol.h"
#import "MHTDiscovery.h"
#import "MHTBranding.h"
#import <objc/runtime.h>
#include <math.h>
static void check(BOOL condition,NSString *message);
static NSString *watchedPreferencePrefix;
static NSUInteger preferenceWrites;
static IMP originalPreferenceWrite;
static void countPreferenceWrite(id defaults,SEL selector,id value,NSString *key){
    if([key hasPrefix:watchedPreferencePrefix])preferenceWrites++;
    ((void(*)(id,SEL,id,NSString *))originalPreferenceWrite)(defaults,selector,value,key);
}
static void preferenceHeartbeatTests(void){
    MHTModule *module=[MHTModule new];NSString *identifier=[@"heartbeat-test-" stringByAppendingString:NSUUID.UUID.UUIDString];
    module.manifest=@{@"id":identifier};watchedPreferencePrefix=[@"MHT." stringByAppendingString:identifier];
    Method method=class_getInstanceMethod(NSUserDefaults.class,@selector(setObject:forKey:));
    preferenceWrites=0;originalPreferenceWrite=method_setImplementation(method,(IMP)countPreferenceWrite);
    @try {
        NSDictionary *settings=@{@"glassIntensity":@0.75,@"restore":@YES};
        NSDictionary *selection=@{@"0":@{@"wanted":@YES,@"value":@2}};
        for(NSUInteger i=0;i<300;i++){[module saveSettings:settings];[module saveSelection:selection];}
        check(preferenceWrites==2,@"300 identical heartbeats write settings and selection only once each");
        [module saveSettings:@{@"glassIntensity":@0.25}];[module saveSelection:@{@"0":@{@"wanted":@NO,@"value":@2}}];
        check(preferenceWrites==4,@"Real option and selection changes still persist immediately");
        NSString *key=[watchedPreferencePrefix stringByAppendingString:@".settings"];
        [NSUserDefaults.standardUserDefaults setObject:@{@"glassIntensity":@0.9} forKey:key];
        [module saveSettings:settings];
        check(preferenceWrites==6 && [module.settings[@"glassIntensity"] doubleValue]==0.75,@"External preference changes are observed rather than hidden by a stale cache");
    } @finally {
        method_setImplementation(method,originalPreferenceWrite);
        for(NSString *suffix in @[@".settings",@".selection"])[NSUserDefaults.standardUserDefaults removeObjectForKey:[watchedPreferencePrefix stringByAppendingString:suffix]];
        watchedPreferencePrefix=nil;
    }
}
static void check(BOOL condition,NSString *message){if(!condition){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
static NSString *fixtureBundle(NSString *root,NSString *name,NSString *bundleID){
    NSString *bundle=[root stringByAppendingPathComponent:name],*contents=[bundle stringByAppendingPathComponent:@"Contents"];
    NSString *macOS=[contents stringByAppendingPathComponent:@"MacOS"];
    [NSFileManager.defaultManager createDirectoryAtPath:macOS withIntermediateDirectories:YES attributes:nil error:NULL];
    [@{@"CFBundleIdentifier":bundleID,@"CFBundlePackageType":@"APPL",@"CFBundleExecutable":@"Fixture"} writeToFile:[contents stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
    [@"test fixture, never executable" writeToFile:[macOS stringByAppendingPathComponent:@"Fixture"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    return bundle;
}
static void writeItem(NSString *folder,NSString *name,NSDictionary *item){
    [[NSJSONSerialization dataWithJSONObject:item options:0 error:NULL] writeToFile:[folder stringByAppendingPathComponent:name] atomically:YES];
}
static void epicDiscoveryTests(void){
    NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"MHT-Epic-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    NSString *items=[root stringByAppendingPathComponent:@"manifests"],*install=[root stringByAppendingPathComponent:@"epic"],*bundleID=@"local.mht.same-bundle-fixture";
    [NSFileManager.defaultManager createDirectoryAtPath:items withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *epic=fixtureBundle(install,@"Epic.app",bundleID),*steam=fixtureBundle([root stringByAppendingPathComponent:@"steam"],@"Steam.app",bundleID);
    NSDictionary *steamProfile=@{@"id":@"steam",@"store":@"Steam",@"bundleIdentifier":bundleID,@"executable":@"Fixture",@"launchEnvironment":@{@"SteamAppId":@"1",@"SteamGameId":@"1"}};
    NSDictionary *epicProfile=@{@"id":@"epic",@"store":@"Epic Games Store",@"bundleIdentifier":bundleID,@"executable":@"Fixture",@"epicAppName":@"fixture-app",@"epicNamespace":@"fixture-namespace"};
    MHTModule *module=[MHTModule new];module.directory=root;module.manifest=@{@"id":[@"epic-fixture-" stringByAppendingString:NSUUID.UUID.UUIDString],@"profiles":@[steamProfile,epicProfile],@"features":@[]};
    NSDictionary *item=@{@"AppName":@"fixture-app",@"CatalogNamespace":@"fixture-namespace",@"InstallLocation":install,@"LaunchExecutable":@"Epic.app/Contents/MacOS/Fixture",@"LaunchCommand":@"ignored; never used as arguments"};
    @try {
        writeItem(items,@"valid.item",item);
        NSDictionary *found=MHTFindEpicInstallations(@[module],items,nil);
        check(found.count==1 && [found[MHTInstallationKey(module,epicProfile)] isEqual:epic],@"Epic manifest resolves its exact app and namespace to a confined bundle");
        check(!found[MHTInstallationKey(module,steamProfile)],@"Shared bundle identifier cannot route Epic candidate to Steam");
        check(!MHTApplyInstallations(@[module],@{bundleID:epic}),@"Legacy bundle-only discovery cannot cross stores");
        check(MHTApplyInstallations(@[module],found) && [[module pathForProfile:epicProfile] isEqual:epic] && ![module pathForProfile:steamProfile],@"Applying Epic candidate preserves separate profile paths");
        [module setPath:steam forProfile:steamProfile];
        NSDictionary *replacement=@{MHTInstallationKey(module,epicProfile):@"/private/tmp/stale.app",MHTInstallationKey(module,steamProfile):@"/private/tmp/also-stale.app"};
        check(!MHTApplyInstallations(@[module],replacement) && [[module pathForProfile:steamProfile] isEqual:steam] && [[module pathForProfile:epicProfile] isEqual:epic],@"Late worker result never overwrites either explicit store path");
        NSDictionary *steamEnv=[module environmentForGame:@{@"executable":@"/test/Steam"} profile:steamProfile session:@"test"],*epicEnv=[module environmentForGame:@{@"executable":@"/test/Epic"} profile:epicProfile session:@"test"];
        check([steamEnv[@"SteamAppId"] isEqual:@"1"] && !epicEnv[@"SteamAppId"] && !epicEnv[@"SteamGameId"],@"Epic environment does not inherit Steam identifiers");
        [module setPath:nil forProfile:epicProfile];[module setPath:nil forProfile:steamProfile];
        for(NSString *key in @[@"AppName",@"CatalogNamespace",@"LaunchExecutable"]){
            NSMutableDictionary *bad=[item mutableCopy];bad[key]=@"wrong";writeItem(items,@"valid.item",bad);
            check(!MHTFindEpicInstallations(@[module],items,nil).count,@"Wrong Epic identity or executable is not discovered");
        }
        for(NSString *relative in @[@"../steam/Steam.app/Contents/MacOS/Fixture",@"/absolute/Epic.app/Contents/MacOS/Fixture"]){
            NSMutableDictionary *bad=[item mutableCopy];bad[@"LaunchExecutable"]=relative;writeItem(items,@"valid.item",bad);
            check(!MHTFindEpicInstallations(@[module],items,nil).count,@"Escaping or absolute manifest launch paths rejected");
        }
        [NSFileManager.defaultManager createSymbolicLinkAtPath:[install stringByAppendingPathComponent:@"Escape.app"] withDestinationPath:steam error:NULL];
        NSMutableDictionary *escaped=[item mutableCopy];escaped[@"LaunchExecutable"]=@"Escape.app/Contents/MacOS/Fixture";writeItem(items,@"valid.item",escaped);
        check(!MHTFindEpicInstallations(@[module],items,nil).count,@"Manifest launch symlink cannot escape installation root");
        writeItem(items,@"valid.item",item);NSString *other=fixtureBundle(install,@"Other.app",bundleID);(void)other;
        NSMutableDictionary *duplicate=[item mutableCopy];duplicate[@"LaunchExecutable"]=@"Other.app/Contents/MacOS/Fixture";writeItem(items,@"duplicate.item",duplicate);
        check(!MHTFindEpicInstallations(@[module],items,nil).count,@"Ambiguous matching Epic installations require explicit choice");
        [NSFileManager.defaultManager removeItemAtPath:[items stringByAppendingPathComponent:@"duplicate.item"] error:NULL];
        NSMutableData *oversized=[NSMutableData dataWithLength:1024*1024+1];[oversized writeToFile:[items stringByAppendingPathComponent:@"valid.item"] atomically:YES];
        check(!MHTFindEpicInstallations(@[module],items,nil).count,@"Oversized Epic JSON rejected");
        writeItem(items,@"valid.item",item);check(!MHTFindEpicInstallations(@[module],items,^BOOL{return YES;}).count,@"Epic scan honors cancellation");
        MHTModule *ambiguous=[MHTModule new];ambiguous.manifest=@{@"id":@"launchservices-store-fixture",@"profiles":@[@{@"id":@"s",@"store":@"Steam",@"bundleIdentifier":@"com.apple.finder"},@{@"id":@"e",@"store":@"Epic Games Store",@"bundleIdentifier":@"com.apple.finder"}]};
        check(![ambiguous pathForProfile:ambiguous.profiles.firstObject] && ![ambiguous pathForProfile:ambiguous.profiles.lastObject],@"Shared store identity never uses LaunchServices arbitrary bundle fallback");
    } @finally {
        [module setPath:nil forProfile:epicProfile];[module setPath:nil forProfile:steamProfile];
        [NSFileManager.defaultManager removeItemAtPath:root error:NULL];
    }
}
int main(int argc,const char *argv[]) {@autoreleasepool {
    check(argc==2,@"Module directory or offline catalog argument");
    preferenceHeartbeatTests();
    epicDiscoveryTests();
    NSDictionary *legacy=@{@"MHT.balatro.path.steam-arm64":@"/Games/Balatro.app",@"MHT.balatro.settings":@{@"glassIntensity":@0.73},@"MHT.profile.balatro":@"steam-arm64",@"MHT.balatro.selection":@{@"0":@{@"wanted":@YES}},@"Unrelated":@42};
    NSDictionary *current=@{@"MHT.balatro.settings":@{@"glassIntensity":@0.9},@"TrainerDock.custom":@YES};
    NSDictionary *merged=MHTMergedLegacyPreferences(legacy,current);
    check([merged[@"MHT.balatro.path.steam-arm64"] isEqual:legacy[@"MHT.balatro.path.steam-arm64"]] && [merged[@"MHT.balatro.selection"] isEqual:legacy[@"MHT.balatro.selection"]] && [merged[@"MHT.profile.balatro"] isEqual:@"steam-arm64"],@"Rebranding preserves game paths, profiles and selections");
    check([merged[@"MHT.balatro.settings"] isEqual:current[@"MHT.balatro.settings"]] && !merged[@"Unrelated"] && [merged[@"TrainerDock.custom"] boolValue],@"Migration keeps newer settings and excludes unrelated defaults");
    check([MHTMergedLegacyPreferences(legacy,merged) isEqual:merged] && [MHTMergedLegacyPreferences(@{},@{}) count]==0,@"Migration is repeatable and supports a clean installation");
    MHTModule *glassPolicy=[MHTModule new];glassPolicy.manifest=@{@"id":@"glass-policy-test"};
    NSString *glassKey=@"MHT.glass-policy-test.settings";
    NSDictionary *previous=[NSUserDefaults.standardUserDefaults dictionaryForKey:glassKey];
    @try {
        [NSUserDefaults.standardUserDefaults setObject:@{@"liquidGlass":@NO,@"scale":@1.25,@"restore":@YES} forKey:glassKey];
        check([glassPolicy.settings[@"liquidGlass"] boolValue] && [glassPolicy.settings[@"scale"] doubleValue]==1.25 && [glassPolicy.settings[@"restore"] boolValue],@"Old glass-off preferences migrate without changing other settings");
        [glassPolicy saveSettings:@{@"liquidGlass":@NO,@"scale":@0.8}];
        check([[NSUserDefaults.standardUserDefaults dictionaryForKey:glassKey][@"liquidGlass"] boolValue],@"Saving runtime options cannot disable Liquid Glass");
    } @finally {
        if(previous)[NSUserDefaults.standardUserDefaults setObject:previous forKey:glassKey];else [NSUserDefaults.standardUserDefaults removeObjectForKey:glassKey];
    }
    @try {
        [glassPolicy saveSettings:@{@"glassIntensity":@0.73,@"liquidGlass":@NO}];
        check([glassPolicy.settings[@"glassIntensity"] doubleValue]==0.73 && [glassPolicy.settings[@"liquidGlass"] boolValue],@"Per-trainer intensity persists while glass stays enabled");
        [glassPolicy saveSettings:@{@"glassIntensity":@5}];check([glassPolicy.settings[@"glassIntensity"] doubleValue]==1,@"Saved intensity is bounded");
    } @finally {
        if(previous)[NSUserDefaults.standardUserDefaults setObject:previous forKey:glassKey];else [NSUserDefaults.standardUserDefaults removeObjectForKey:glassKey];
    }
    MHTModule *selectionPolicy=[MHTModule new];
    NSDictionary *feature=@{@"id":@0,@"implemented":@YES,@"oneShot":@NO,@"initial":@2,@"minimum":@0,@"maximum":@10,@"integer":@NO};
    NSString *oldKey=@"MHT.selection-version-test.selection",*newKey=@"MHT.selection-version-test.selection.2";
    id oldSelection=[NSUserDefaults.standardUserDefaults objectForKey:oldKey],newSelection=[NSUserDefaults.standardUserDefaults objectForKey:newKey];
    @try {
        selectionPolicy.manifest=@{@"id":@"selection-version-test",@"features":@[feature]};
        [selectionPolicy saveSelection:@{@"0":@{@"wanted":@YES,@"value":@4}}];
        selectionPolicy.manifest=@{@"id":@"selection-version-test",@"selectionVersion":@"2",@"features":@[feature]};
        check(![selectionPolicy.selection[@"0"][@"wanted"] boolValue]&&[selectionPolicy.selection[@"0"][@"value"] doubleValue]==2,@"A revised catalog cannot reuse an old numeric ID");
        [selectionPolicy saveSelection:@{@"0":@{@"wanted":@YES,@"value":@5}}];
        check([selectionPolicy.selection[@"0"][@"value"] doubleValue]==5&&[[NSUserDefaults.standardUserDefaults dictionaryForKey:oldKey][@"0"][@"value"] doubleValue]==4,@"Revised selection persists independently and preserves old preferences");
    } @finally {
        if(oldSelection)[NSUserDefaults.standardUserDefaults setObject:oldSelection forKey:oldKey];else [NSUserDefaults.standardUserDefaults removeObjectForKey:oldKey];
        if(newSelection)[NSUserDefaults.standardUserDefaults setObject:newSelection forKey:newKey];else [NSUserDefaults.standardUserDefaults removeObjectForKey:newKey];
    }
    MHTModule *discovery=[MHTModule new];NSDictionary *discoveryProfile=@{@"id":@"test",@"bundleIdentifier":@"local.mht.discovery-test"};
    discovery.manifest=@{@"id":@"discovery-path-test",@"profiles":@[discoveryProfile]};
    NSString *pathKey=@"MHT.discovery-path-test.path.test";id previousPath=[NSUserDefaults.standardUserDefaults objectForKey:pathKey];
    @try {
        [discovery setPath:@"/private/tmp/chosen-after-scan.app" forProfile:discoveryProfile];
        check(!MHTApplyInstallations(@[discovery],@{@"local.mht.discovery-test":@"/private/tmp/old-scan-result.app"}) && [[discovery pathForProfile:discoveryProfile] isEqual:@"/private/tmp/chosen-after-scan.app"],@"Deferred discovery cannot overwrite a newly chosen path");
        check(!MHTFindInstallations(@[discovery],nil).count && !MHTFindInstallations(@[discovery],^BOOL{return YES;}).count,@"Known paths and cancellation skip unnecessary discovery");
    } @finally {
        if(previousPath)[NSUserDefaults.standardUserDefaults setObject:previousPath forKey:pathKey];else [NSUserDefaults.standardUserDefaults removeObjectForKey:pathKey];
    }
    check(!MHTDecodeMessage(@"[]") && !MHTDecodeMessage(@"broken") && !MHTDecodeMessage(@42),@"Malformed messages rejected");
    NSString *session=NSUUID.UUID.UUIDString;
    NSMutableDictionary *m=[@{@"version":@1,@"module":@"test",@"session":session,@"pid":@42,@"request":NSUUID.UUID.UUIDString,@"deadline":@102} mutableCopy];
    NSMutableOrderedSet *seen=[NSMutableOrderedSet new];
    check(MHTAcceptCommand(m,@"test",session,42,seen,100),@"Valid request accepted");
    check(!MHTAcceptCommand(m,@"test",session,42,seen,100),@"Replay rejected");
    m[@"request"]=NSUUID.UUID.UUIDString;m[@"deadline"]=@99;check(!MHTAcceptCommand(m,@"test",session,42,seen,100),@"Expired request rejected");
    m[@"deadline"]=@106;check(!MHTAcceptCommand(m,@"test",session,42,seen,100),@"Overlong deadline rejected");
    m[@"deadline"]=@102;
    check(!MHTAcceptCommand(m,@"other",session,42,seen,100) && !MHTAcceptCommand(m,@"test",@"wrong",42,seen,100) && !MHTAcceptCommand(m,@"test",session,43,seen,100),@"Module, session, process isolation");
    m[@"deadline"]=@(NAN);check(!MHTAcceptCommand(m,@"test",session,42,seen,100),@"NaN rejected");
    NSMutableArray *errors=[NSMutableArray new];NSString *input=[NSString stringWithUTF8String:argv[1]];
    NSArray<MHTModule *> *modules;
    if([input.pathExtension isEqual:@"json"]){
        NSError *catalogError=nil;NSDictionary *catalog=[MHTTrainerStore validatedCatalog:[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:input] options:0 error:NULL] requireDownloads:NO error:&catalogError];
        check(catalog!=nil,[NSString stringWithFormat:@"Offline catalog is valid: %@",catalogError]);
        NSMutableArray *metadata=[NSMutableArray new];
        for(NSDictionary *entry in catalog[@"modules"]){
            NSDictionary *latest=[entry[@"versions"] sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return MHTCompareTrainerVersions(b[@"version"],a[@"version"]);}].firstObject;
            MHTModule *module=[MHTModule new];module.manifest=latest[@"manifest"];[metadata addObject:module];
            check(!module.installed && !module.runtimePath,@"Offline catalog cannot introduce a runtime library into the host");
        }
        modules=metadata;
    } else {modules=[MHTModule loadModules:input errors:errors];check(!errors.count && modules.count>0,[NSString stringWithFormat:@"Independent modules load: %@",errors]);}
    // Metadata-only fixtures: no trainer library is loaded or copied.
    NSString *modeRoot=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"MHT-StartMode-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    NSString *fixture=[modeRoot stringByAppendingPathComponent:@"fixture.mhtmodule"];
    [NSFileManager.defaultManager createDirectoryAtPath:fixture withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSData data] writeToFile:[fixture stringByAppendingPathComponent:@"Trainer.dylib"] atomically:YES];
    @try {
        NSArray *cases=@[@{@"launchMode":@"app"},@{@"launchMode":@"executable"},@{@"launchMode":@"epic",@"epicAppName":@"fixture-app",@"epicNamespace":@"fixture-namespace"},@{@"launchMode":@"unknown"},@{@"launchMode":@"epic"},@{@"launchMode":@"epic",@"epicAppName":@"bad/value",@"epicNamespace":@"fixture-namespace"}];
        for(NSUInteger i=0;i<cases.count;i++){
            NSMutableDictionary *profile=[@{@"id":@"fixture",@"name":@"Prüfprofil",@"enabled":@YES,@"store":@"Steam",@"version":@"1",@"bundleIdentifier":@"local.mht.fixture",@"executable":@"Fixture",@"uuids":@[@"00000000-0000-0000-0000-000000000001"]} mutableCopy];[profile addEntriesFromDictionary:cases[i]];
            NSDictionary *testFeature=@{@"id":@0,@"title":@"Prüffunktion",@"binding":@"F1",@"implemented":@YES,@"numeric":@NO,@"oneShot":@NO,@"integer":@NO,@"initial":@0,@"minimum":@0,@"maximum":@1,@"step":@1};
            NSMutableDictionary *manifest=[@{@"schemaVersion":@1,@"id":@"fixture",@"name":@"Prüftrainer",@"version":@"1.0.0",@"profiles":@[profile],@"features":@[testFeature]} mutableCopy];
            NSDictionary *configuration=@{@"schemaVersion":@1,@"app":@{@"name":@"Fixture",@"bundleIdentifier":@"local.mht.fixture",@"version":@"1.0",@"build":@"1"},@"profiles":@[profile]};
            writeItem(fixture,@"Module.json",manifest);writeItem(fixture,@"TrainerConfig.json",configuration);
            NSMutableArray *failures=[NSMutableArray new];NSArray *loaded=[MHTModule loadModules:modeRoot errors:failures];
            check(i<3 ? loaded.count==1 && !failures.count : !loaded.count && failures.count==1,@"Only explicit valid start transports accepted; malformed Epic metadata cannot fall back to direct launch");
        }
    } @finally {[NSFileManager.defaultManager removeItemAtPath:modeRoot error:NULL];}
    NSDictionary *group=@{@"id":@"player",@"title":@"Spieler",@"symbol":@"person",@"features":@[@0,@1]};
    check([MHTModule validFeatureGroups:nil featureCount:2] && [MHTModule validFeatureGroups:@[group] featureCount:2],@"Optional groups preserve old modules and cover native IDs");
    for(id ids in @[@[@0,@0],@[@0],@[@0,@2],@[@0,@1.5],@[@0,@(-1)],@[@0,@"1"]]){
        NSMutableDictionary *bad=[group mutableCopy];bad[@"features"]=ids;
        check(![MHTModule validFeatureGroups:@[bad] featureCount:2],@"Incomplete, duplicate, fractional or unknown feature IDs rejected");
    }
    check(![MHTModule validFeatureGroups:@[group,group] featureCount:2],@"Duplicate groups rejected");
    NSDictionary *counts=@{@"control":@12,@"balatro":@10,@"escape-from-duckov":@35,@"dome-keeper":@10,@"dead-island-2":@26,@"resident-evil-2":@21,@"resident-evil-3":@20,@"resident-evil-4":@36,@"resident-evil-7":@15,@"resident-evil-village":@23,@"lies-of-p":@36,@"cyberpunk-2077":@46,@"robocop":@17,@"crimson-desert":@13};
    for(MHTModule *module in modules){
        check([MHTModule validFeatureGroups:module.featureGroups featureCount:module.features.count],@"All displayed groups cover their native catalog exactly once");
        if(counts[module.identifier])check(module.features.count==[counts[module.identifier] unsignedIntegerValue],[NSString stringWithFormat:@"Correct native catalog: %@ (%lu)",module.identifier,(unsigned long)module.features.count]);
        check(![module inspectPath:@"/private/tmp/does-not-exist.app" profile:module.profiles.firstObject error:NULL],@"Wrong game path rejected");
        NSDictionary *profile=module.profiles.firstObject;
        NSDictionary *env=[module environmentForGame:@{@"executable":@"/test/Game"} profile:profile session:session];
        if(module.installed){check([env[@"MHT_MODULE"] isEqual:module.identifier] && [env[@"MHT_SESSION"] isEqual:session] && [env[@"DYLD_INSERT_LIBRARIES"] isEqual:module.runtimePath],@"Launch environment isolated");
        NSString *key=@"MHT_OPTIONS";
        NSDictionary *overlay=MHTDecodeMessage(env[key]);check(![overlay[@"visible"] boolValue] && [overlay[@"liquidGlass"] boolValue],@"Launch hidden with Liquid Glass always enabled");
        }else check(!env,@"Catalog-only trainers cannot form a launch environment before installation");
        check([profile[@"store"] length]>0,@"Explicit supported store");
    }
    puts("PASS: protocol isolation, replay/deadline rejection, available catalog metadata, game validation and launch configuration.");
}return 0;}
