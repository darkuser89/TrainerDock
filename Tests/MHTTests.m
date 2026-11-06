// SPDX-License-Identifier: GPL-3.0-only
#import "MHTModule.h"
#import "MHTProtocol.h"
#import "MHTDiscovery.h"
#import "MHTBranding.h"
#include <math.h>
static void check(BOOL condition,NSString *message){if(!condition){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
int main(int argc,const char *argv[]) {@autoreleasepool {
    check(argc==2,@"Module directory argument");
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
    NSMutableArray *errors=[NSMutableArray new];NSArray<MHTModule *> *modules=[MHTModule loadModules:[NSString stringWithUTF8String:argv[1]] errors:errors];
    check(!errors.count && modules.count>0,[NSString stringWithFormat:@"Independent modules load: %@",errors]);
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
        check([env[@"MHT_MODULE"] isEqual:module.identifier] && [env[@"MHT_SESSION"] isEqual:session] && [env[@"DYLD_INSERT_LIBRARIES"] isEqual:module.runtimePath],@"Launch environment isolated");
        NSString *key=@"MHT_OPTIONS";
        NSDictionary *overlay=MHTDecodeMessage(env[key]);check(![overlay[@"visible"] boolValue] && [overlay[@"liquidGlass"] boolValue],@"Launch hidden with Liquid Glass always enabled");
        check([profile[@"store"] length]>0,@"Explicit supported store");
    }
    puts("PASS: protocol isolation, replay/deadline rejection, all native catalogs, game validation and launch configuration.");
}return 0;}
