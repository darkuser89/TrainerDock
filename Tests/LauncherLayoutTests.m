// SPDX-License-Identifier: GPL-3.0-only
// Exercise the real launcher with isolated metadata fixtures; never start a game.
#import "MHTApp.h"
#import "MHTAppearance.h"
#import "MHTTrainerSettings.h"
#import "MHTTrainerViews.h"
#import "MHTTrainerStore.h"
#import "MHTTrainerLibrary.h"
@interface MHTApp (LayoutChecks)
- (void)filter:(id)sender;
- (void)refreshInstallation;
- (void)startGame:(id)sender;
- (void)reloadTrainerModules;
- (NSSet<NSString *> *)protectedRuntimePaths;
@end
// Deliberately blocked identity check, confined to tests; never used to launch.
@interface MHTSlowProfile : MHTModule
@property(nonatomic) dispatch_semaphore_t entered,releaseCheck;
@property(atomic) BOOL usedMainThread;
@property(atomic) BOOL slowFinished;
@end
@implementation MHTSlowProfile
- (BOOL)installed{return YES;}
- (NSString *)pathForProfile:(NSDictionary *)profile {(void)profile;return @"/private/tmp/mht-async-fixture-does-not-exist.app";}
- (NSDictionary *)inspectPath:(NSString *)path profile:(NSDictionary *)profile error:(NSError **)error {
    (void)path;self.usedMainThread|=NSThread.isMainThread;
    if([profile[@"id"] isEqual:@"slow"]){
        dispatch_semaphore_signal(self.entered);dispatch_semaphore_wait(self.releaseCheck,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC));
        self.slowFinished=YES;
        return @{@"path":path};
    }
    if(error)*error=[NSError errorWithDomain:@"MHT.Async.Test" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Aktuelles Profil abgelehnt"}];
    return nil;
}
@end
static void layout(NSWindow *window) {
    [window.contentView layoutSubtreeIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    [window.contentView layoutSubtreeIfNeeded];
}
static BOOL sameSize(NSSize a,NSSize b){return fabs(a.width-b.width)<1 && fabs(a.height-b.height)<1;}
static void require(BOOL ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static NSArray<NSView *> *descendants(NSView *view) {
    NSMutableArray *result=[NSMutableArray arrayWithObject:view];
    for(NSView *child in view.subviews)[result addObjectsFromArray:descendants(child)];
    return result;
}
static void checkAsyncInspection(dispatch_block_t completion) {
    MHTSlowProfile *module=[MHTSlowProfile new];module.entered=dispatch_semaphore_create(0);module.releaseCheck=dispatch_semaphore_create(0);
    module.manifest=@{@"id":@"async-test",@"profiles":@[@{@"id":@"slow",@"store":@"Test",@"bundleIdentifier":@"local.mht.async-test"},@{@"id":@"fast",@"store":@"Test",@"bundleIdentifier":@"local.mht.async-test"}]};
    MHTApp *app=[MHTApp new];[app setValue:module forKey:@"selected"];[app setValue:[NSMutableDictionary new] forKey:@"sessions"];
    NSPopUpButton *profiles=[NSPopUpButton new];[profiles addItemsWithTitles:@[@"Slow",@"Fast"]];[profiles selectItemAtIndex:0];[app setValue:profiles forKey:@"profiles"];
    [app setValue:[NSImageView new] forKey:@"gameIcon"];[app setValue:MHTLabel(@"",12,NSFontWeightRegular) forKey:@"subtitle"];
    [app setValue:[NSButton new] forKey:@"pathButton"];NSButton *start=[NSButton new];[app setValue:start forKey:@"start"];
    NSTextField *status=MHTLabel(@"",12,NSFontWeightRegular);[app setValue:status forKey:@"status"];
    NSOperationQueue *queue=[NSOperationQueue new];queue.maxConcurrentOperationCount=1;[app setValue:queue forKey:@"inspectionQueue"];
    [app refreshInstallation];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        require(dispatch_semaphore_wait(module.entered,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC))==0,"identity inspection starts on its worker");
        dispatch_async(dispatch_get_main_queue(),^{
            require(!module.slowFinished && !module.usedMainThread && !start.enabled,"UI remains responsive while the identity worker is blocked");
            [profiles selectItemAtIndex:1];[app refreshInstallation];dispatch_semaphore_signal(module.releaseCheck);
            NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
            [NSTimer scheduledTimerWithTimeInterval:0.01 repeats:YES block:^(NSTimer *timer){
                // Keep this isolated controller alive until its callback arrives.
                NSTextField *currentStatus=[app valueForKey:@"status"];
                if(![currentStatus.stringValue isEqual:@"Aktuelles Profil abgelehnt"] && deadline.timeIntervalSinceNow>0)return;
                [timer invalidate];
                require([currentStatus.stringValue isEqual:@"Aktuelles Profil abgelehnt"] && !start.enabled && !module.usedMainThread,"stale successful checks cannot enable a different profile");
                [queue cancelAllOperations];
                puts("PASS: blocked identity worker leaves UI responsive; cancelled/stale results cannot enable a different profile. No games launched.");
                completion();
            }];
        });
    });
}
@interface MHTToggleCheck : NSObject
@property(nonatomic) NSUInteger calls;
@property(nonatomic) NSInteger feature,selection;
- (void)changed:(MHTGlassToggle *)sender;
@end
@implementation MHTToggleCheck
- (void)changed:(MHTGlassToggle *)sender {self.calls++;self.feature=sender.tag;self.selection=sender.selectedSegment;}
@end
static void checkGlassToggle(void) {
    MHTGlassToggle *toggle=[MHTGlassToggle new];MHTToggleCheck *target=[MHTToggleCheck new];
    toggle.tag=17;toggle.target=target;toggle.action=@selector(changed:);toggle.accessibilityLabel=@"Testfunktion";
    NSMutableArray<NSButton *> *buttons=[NSMutableArray new];
    for(NSView *view in descendants(toggle))if([view isKindOfClass:NSButton.class])[buttons addObject:(NSButton *)view];
    require(buttons.count==2,"glass toggle contains two native controls");
    NSButton *off=nil,*on=nil;
    for(NSButton *button in buttons){
        require(button.bezelStyle==NSBezelStyleGlass && button.borderShape==NSControlBorderShapeCapsule,"Aus/Ein uses native capsule glass bezels");
        if([button.title isEqual:@"Aus"])off=button;else if([button.title isEqual:@"Ein"])on=button;
    }
    toggle.selectedSegment=1;toggle.selectedSegment=0;
    require(target.calls==0,"runtime readback updates never send trainer commands");
    [on performClick:nil];require(target.calls==1 && target.feature==17 && target.selection==1,"Ein sends the stable composite feature ID once");
    [on performClick:nil];require(target.calls==2 && target.selection==1,"Ein is explicit and stays on when clicked again");
    [off performClick:nil];require(target.calls==3 && target.selection==0,"Aus explicitly clears the same feature");
    toggle.enabled=NO;[on performClick:nil];require(target.calls==3 && !off.enabled && !on.enabled,"disabled glass controls cannot send actions");
}
static void checkSettings(MHTApp *app) {
    [app openSettings:nil];
    MHTTrainerSettings *controller=[app valueForKey:@"trainerSettings"];
    NSWindow *window=controller.window;[window orderOut:nil];
    NSScrollView *scroll=[controller valueForKey:@"scroll"];
    NSStackView *list=[controller valueForKey:@"list"];
    NSArray<MHTModule *> *trainers=[app valueForKey:@"modules"];
    NSUInteger profileCount=0;for(MHTModule *trainer in trainers)profileCount+=trainer.profiles.count;
    for(NSArray *dimensions in @[@[@680,@500],@[@820,@700],@[@980,@800]]){
        [window setContentSize:NSMakeSize([dimensions[0] doubleValue],[dimensions[1] doubleValue])];layout(window);
        NSSize expected=window.frame.size;
        NSUInteger cards=0,buttons=0;
        NSView *lastCard=nil;
        for(NSView *view in descendants(window.contentView)){
            if([view.identifier hasPrefix:@"MHT.Trainer."]){
                cards++;lastCard=view;require(view.frame.size.width>400,"settings card must have usable width");
                require(fabs(view.frame.origin.x)<1,"cards align within the padded list");
            }
            if([view isKindOfClass:NSTextField.class]){
                NSTextField *label=(NSTextField *)view;
                if([label.stringValue containsString:@"Funktionen ·"] || [label.stringValue isEqual:@"Wähle für jeden Store die passende Spiele-App."]){
                    CGFloat needed=[label.stringValue sizeWithAttributes:@{NSFontAttributeName:label.font}].width;
                    require(NSWidth(label.bounds)>=needed,"settings descriptions use available width without needless truncation");
                }
            }
            if([view isKindOfClass:NSButton.class] && ((NSButton *)view).action==NSSelectorFromString(@"selectPath:")){
                buttons++;
                NSRect rect=[view convertRect:view.bounds toView:scroll.documentView];
                require(NSMinX(rect)>=23 && NSMaxX(rect)<=NSWidth(scroll.documentView.bounds)-23,"path buttons stay inside document margins");
            }
        }
        require(cards==trainers.count && buttons==profileCount,"each trainer and store has its own card and path action");
        require(NSHeight(scroll.documentView.bounds)>NSHeight(scroll.contentView.bounds),"trainer list must scroll vertically");
        CGFloat documentHeight=NSHeight(scroll.documentView.bounds);
        [scroll.documentView scrollPoint:NSMakePoint(0,documentHeight-NSHeight(scroll.contentView.bounds))];layout(window);
        require(scroll.contentView.bounds.origin.y>100,"last trainer is reachable by scrolling");
        NSRect last=[lastCard convertRect:lastCard.bounds toView:scroll.documentView];
        require(NSMaxY(last)<=NSMaxY(scroll.documentView.visibleRect)+1,"last trainer card is fully reachable");
        require(fabs(NSHeight(scroll.documentView.bounds)-documentHeight)<1,"scrolling must not grow the document");
        require(sameSize(expected,window.frame.size),"settings content must not resize its window");
        [scroll.documentView scrollPoint:NSZeroPoint];
    }
    NSSearchField *search=[controller valueForKey:@"search"];
    NSSize expected=window.frame.size;
    search.stringValue=@"Dead Island";
    [controller controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:search]];layout(window);
    NSUInteger cards=0,buttons=0;
    for(NSView *view in descendants(list)){
        if([view.identifier hasPrefix:@"MHT.Trainer."])cards++;
        if([view isKindOfClass:NSButton.class] && ((NSButton *)view).action==NSSelectorFromString(@"selectPath:"))buttons++;
    }
    require(cards==1 && buttons==2,"trainer search retains both separate Dead Island store profiles");
    __block NSMutableSet *chosen=[NSMutableSet new];
    void (^original)(MHTModule *,NSDictionary *,dispatch_block_t)=controller.choosePath;
    controller.choosePath=^(MHTModule *trainer,NSDictionary *profile,dispatch_block_t completion){
        require([trainer.identifier isEqual:@"dead-island-2"],"path action routes to the selected trainer");
        [chosen addObject:profile[@"id"]];completion();
    };
    for(NSView *view in descendants(list))if([view isKindOfClass:NSButton.class] && ((NSButton *)view).action==NSSelectorFromString(@"selectPath:"))[(NSButton *)view performClick:nil];
    require(chosen.count==2,"each store button routes to its own profile without writing a path");controller.choosePath=original;
    search.stringValue=@"no-matching-trainer";[controller controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:search]];layout(window);
    require(sameSize(expected,window.frame.size),"empty trainer search preserves settings size");
    search.stringValue=@"";[controller controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:search]];layout(window);
    // Hidden-window stress sizes above may exceed a CI display. AppKit fits an
    // oversized window on showing it; test restoration with a user-selectable size.
    [window setContentSize:NSMakeSize(680,500)];[window center];layout(window);
    expected=window.frame.size;
    [window close];[app openSettings:nil];layout(window);
    if(!sameSize(expected,window.frame.size))fprintf(stderr,"Settings restoration: expected %.0fx%.0f, actual %.0fx%.0f\n",expected.width,expected.height,window.frame.size.width,window.frame.size.height);
    require(sameSize(expected,window.frame.size),"reopening settings preserves the chosen window size");[window close];
    NSMenu *menu=NSApp.mainMenu;
    NSMenuItem *settings=[menu.itemArray.firstObject.submenu itemWithTitle:@"Einstellungen …"];
    require([settings.keyEquivalent isEqual:@","] && settings.target==app,"native settings shortcut targets the launcher");
    NSMenuItem *reload=[[menu itemWithTitle:@"Trainer"].submenu itemWithTitle:@"Trainer & Spiele neu laden"];
    require([reload.keyEquivalent isEqual:@"r"] && reload.target==app,"trainer reload menu targets the launcher");
    puts("PASS: trainer settings at three sizes, scroll reachability, per-store path routing, search, window restoration and native menus. No paths written or games launched.");
}
static void checkIcons(void) {
    NSImage *source=[[NSImage alloc]initWithSize:NSMakeSize(32,32)];
    for(NSNumber *pixels in @[@32,@256]){
        NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:pixels.integerValue pixelsHigh:pixels.integerValue bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [source addRepresentation:rep];
    }
    for(NSNumber *points in @[@36,@40,@76]){
        NSImageView *view=MHTIconView(source,points.doubleValue,@"HiDPI fixture");
        if(view.image==source || view.image.representations.count!=2 || view.image.size.width!=points.doubleValue || source.size.width!=32){
            fprintf(stderr,"FAIL: icon size must preserve source and resolution representations\n");exit(1);
        }
        for(NSNumber *density in @[@1,@2]){
            NSInteger pixels=points.integerValue*density.integerValue;
            NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:pixels pixelsHigh:pixels bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
            [NSGraphicsContext saveGraphicsState];NSGraphicsContext.currentContext=context;
            CGContextScaleCTM(context.CGContext,density.doubleValue,density.doubleValue);
            NSImageRep *best=[view.image bestRepresentationForRect:NSMakeRect(0,0,points.doubleValue,points.doubleValue) context:context hints:nil];
            if(best.pixelsWide<pixels){fprintf(stderr,"FAIL: icon chooses an undersized representation\n");exit(1);}
            [NSGraphicsContext restoreGraphicsState];
        }
    }
}
// Catalog fixtures are metadata only. No runtime or fake cheat is ever built.
@interface MHTLayoutStore : MHTTrainerStore
@property(nonatomic) NSUInteger downloadRequests;
@property(nonatomic) NSArray<MHTModule *> *layoutVersions;
@property(nonatomic) NSArray<MHTModule *> *batchModules;
@property(nonatomic) NSArray<NSDictionary *> *batchCandidates;
@property(nonatomic) NSMutableArray<NSDictionary *> *batchCalls;
@property(nonatomic) NSMutableArray *batchCompletions;
@property(nonatomic) NSUInteger batchRefreshes;
@property(nonatomic) NSError *batchRefreshError;
@end
@implementation MHTLayoutStore
- (NSArray<MHTModule *> *)modules {return self.batchModules ?: super.modules;}
- (NSArray<NSDictionary *> *)updatesForInstalledTrainers {return self.batchModules ? self.batchCandidates : super.updatesForInstalledTrainers;}
- (void)refreshCatalogWithCompletion:(void (^)(NSError *))completion {
    if(!self.batchModules){[super refreshCatalogWithCompletion:completion];return;}
    self.batchRefreshes++;dispatch_async(dispatch_get_main_queue(),^{completion(self.batchRefreshError);});
}
- (NSArray<NSDictionary *> *)versionsForIdentifier:(NSString *)identifier {
    for(MHTModule *module in self.batchModules)if([module.identifier isEqual:identifier])return @[module.catalogVersion];
    return [super versionsForIdentifier:identifier];
}
- (NSArray<MHTModule *> *)installedVersionsForIdentifier:(NSString *)identifier {
    for(MHTModule *module in self.batchModules)if([module.identifier isEqual:identifier])return @[module];
    if(self.layoutVersions && [self.layoutVersions.firstObject.identifier isEqual:identifier])return self.layoutVersions;
    return [super installedVersionsForIdentifier:identifier];
}
- (void)installVersion:(NSDictionary *)version forIdentifier:(NSString *)identifier completion:(void (^)(MHTModule *,NSError *))completion {
    if(self.batchModules){[self.batchCalls addObject:@{@"id":identifier,@"version":version}];[self.batchCompletions addObject:[completion copy]];return;}
    (void)version;(void)identifier;self.downloadRequests++;
    completion(nil,[NSError errorWithDomain:@"MHT.Layout" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Absichtlicher Downloadfehler im UI-Test"}]);
}
@end
@interface MHTInstalledLayoutModule : MHTModule @end
@implementation MHTInstalledLayoutModule
- (BOOL)installed{return YES;}
@end
static void checkTrainerManagerLayout(MHTTrainerLibrary *manager,MHTLayoutStore *store) {
    MHTModule *metadata=store.modules.firstObject;
    MHTModule *legacy=[MHTInstalledLayoutModule new],*download=[MHTInstalledLayoutModule new];
    legacy.manifest=metadata.manifest;download.manifest=metadata.manifest;
    legacy.directory=[NSString stringWithFormat:@"/private/tmp/ui-only/%@/legacy-0000000000000001/%@.mhtmodule",metadata.identifier,metadata.identifier];
    download.directory=[NSString stringWithFormat:@"/private/tmp/ui-only/%@/1.0.0/%@.mhtmodule",metadata.identifier,metadata.identifier];
    legacy.catalogVersion=metadata.catalogVersion;legacy.updateAvailable=YES;
    require(legacy.packageMigrationAvailable && !download.packageMigrationAvailable,"same-version legacy conversion is distinct from a trainer version update");
    NSMutableDictionary *newer=[metadata.catalogVersion mutableCopy];newer[@"version"]=@"1.0.1";legacy.catalogVersion=newer;
    require(!legacy.packageMigrationAvailable,"a newer trainer version remains a real update");legacy.catalogVersion=metadata.catalogVersion;
    for(NSNumber *hasInstalled in @[@YES,@NO]){
    store.layoutVersions=hasInstalled.boolValue ? @[download,legacy] : nil;[manager reloadForIdentifier:metadata.identifier];
    for(NSValue *value in @[[NSValue valueWithSize:NSMakeSize(840,540)],[NSValue valueWithSize:NSMakeSize(1000,680)],[NSValue valueWithSize:NSMakeSize(1160,1000)]]){
        NSSize size=value.sizeValue;[manager.window setContentSize:size];layout(manager.window);
        NSView *content=manager.window.contentView,*body=nil,*footer=nil;NSScrollView *list=nil;
        NSUInteger titles=0;BOOL imported=NO,github=NO;
        for(NSView *view in descendants(content)){
            if([view.identifier isEqual:@"MHT.TrainerLibrary.Body"])body=view;
            if([view.identifier isEqual:@"MHT.TrainerLibrary.Footer"])footer=view;
            if([view.identifier isEqual:@"MHT.TrainerLibrary.SidebarScroll"])list=(NSScrollView *)view;
            if([view.identifier isEqual:@"MHT.TrainerVersion.Title"]){NSTextField *title=(NSTextField *)view;titles++;if(NSWidth(title.bounds)<title.intrinsicContentSize.width-1){for(NSView *ancestor=title;ancestor;ancestor=ancestor.superview)fprintf(stderr,"%s %s frame=%s bounds=%s\n",NSStringFromClass(ancestor.class).UTF8String,ancestor.identifier.UTF8String,NSStringFromRect(ancestor.frame).UTF8String,NSStringFromRect(ancestor.bounds).UTF8String);fprintf(stderr,"natural %.1f; manager %.1fx%.1f\n",title.intrinsicContentSize.width,NSWidth(content.bounds),NSHeight(content.bounds));}require(NSWidth(title.bounds)>=title.intrinsicContentSize.width-1,"installed version titles have their full natural text width");}
            if([view isKindOfClass:NSTextField.class]){NSString *text=((NSTextField *)view).stringValue;imported|=[text isEqual:@"Übernommener Trainer"];github|=[text isEqual:@"GitHub-Paket"];}
        }
        require(body && footer && list,"manager exposes both window regions and its game viewport");
        NSRect bounds=[footer convertRect:footer.bounds toView:content];CGFloat edge=content.isFlipped?NSHeight(content.bounds)-NSMaxY(bounds):NSMinY(bounds);
        require(fabs(edge-16)<1 && fabs(NSHeight(footer.bounds)-32)<1,"manager footer stays at the actual bottom edge at every height");
        NSButton *updateAll=[manager valueForKey:@"updateAll"],*refresh=[manager valueForKey:@"refresh"];
        NSRect updateFrame=[updateAll convertRect:updateAll.bounds toView:content],refreshFrame=[refresh convertRect:refresh.bounds toView:content];
        require(NSContainsRect(content.bounds,updateFrame) && NSContainsRect(content.bounds,refreshFrame) && !NSIntersectsRect(updateFrame,refreshFrame),"both update actions remain inside the smallest manager window without overlap");
        require(NSWidth(updateAll.bounds)>=updateAll.intrinsicContentSize.width-1,"bulk-update button retains its complete German title");
        require(NSHeight(body.bounds)>=NSHeight(content.bounds)-81,"manager body fills the available window instead of ending halfway down");
        require(NSHeight(list.bounds)>NSHeight(content.bounds)*0.5,"game list viewport grows with tall windows");
        require(titles==(hasInstalled.boolValue ? 3u : 1u),"installed and download-only cards expose every version title");
        if(hasInstalled.boolValue)require(imported && github,"installed cards separate version numbers from their legacy/GitHub origin");
    }
    }
    store.layoutVersions=nil;[manager reloadForIdentifier:metadata.identifier];
}
static void awaitBatch(BOOL (^condition)(void)) {
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:5];
    while(!condition() && deadline.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
    require(condition(),"bulk update reaches its expected asynchronous state");
}
static void checkBatchUpdates(MHTTrainerLibrary *manager,MHTLayoutStore *store) {
    NSDictionary *manifest=store.modules.firstObject.manifest;NSMutableArray *modules=[NSMutableArray new],*candidates=[NSMutableArray new];
    for(NSString *identifier in @[@"batch-alpha",@"batch-beta",@"batch-gamma"]){
        MHTModule *module=[MHTInstalledLayoutModule new];NSMutableDictionary *copy=[manifest mutableCopy];copy[@"id"]=identifier;copy[@"name"]=identifier;
        module.manifest=copy;module.directory=[@"/private/tmp/ui-only/1.0.0/" stringByAppendingString:[identifier stringByAppendingString:@".mhtmodule"]];
        NSMutableDictionary *next=[copy mutableCopy];next[@"version"]=@"1.0.1";
        module.catalogVersion=@{@"version":@"1.0.1",@"manifest":next,@"downloadAvailable":@YES};module.updateAvailable=YES;
        [modules addObject:module];[candidates addObject:@{@"id":identifier,@"name":identifier,@"version":module.catalogVersion}];
    }
    store.batchModules=modules;store.batchCandidates=candidates;store.batchCalls=[NSMutableArray new];store.batchCompletions=[NSMutableArray new];
    // An empty visible filter must not narrow "all installed" to visible rows.
    NSSearchField *search=[manager valueForKey:@"search"];search.stringValue=@"not-visible";[manager reloadForIdentifier:nil];
    NSButton *button=[manager valueForKey:@"updateAll"],*refresh=[manager valueForKey:@"refresh"];
    require(button.enabled,"installed trainers enable the bulk update action");[button performClick:nil];
    require(!button.enabled && !refresh.enabled,"bulk operation disables duplicate starts and catalog races");
    [NSApp sendAction:button.action to:button.target from:button];
    for(NSUInteger i=0;i<3;i++){
        awaitBatch(^BOOL{return store.batchCalls.count==i+1;});
        require(store.batchRefreshes==1 && store.batchCompletions.count==1,"one catalog refresh and one download at a time");
        require([store.batchCalls[i][@"id"] isEqual:candidates[i][@"id"]],"batch uses all installed candidates independently of filters");
        require([[(NSTextField *)[manager valueForKey:@"status"] stringValue] containsString:[NSString stringWithFormat:@"%lu von 3",(unsigned long)i+1]],"batch reports current item and total");
        void (^completion)(MHTModule *,NSError *)=store.batchCompletions.firstObject;[store.batchCompletions removeObjectAtIndex:0];
        completion(i?modules[i]:nil,i?nil:[NSError errorWithDomain:@"MHT.Layout" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Absichtlicher Sammeldownloadfehler"}]);
    }
    awaitBatch(^BOOL{return ![[manager valueForKey:@"updatingAll"] boolValue];});
    NSTextField *status=[manager valueForKey:@"status"];
    require([status.stringValue containsString:@"2 aktualisiert"] && [status.stringValue containsString:@"1 fehlgeschlagen"] && [status.toolTip containsString:@"batch-alpha"],"failed download is reported with details while subsequent updates finish");
    store.batchCandidates=@[];[button performClick:nil];awaitBatch(^BOOL{return ![[manager valueForKey:@"updatingAll"] boolValue];});
    require(store.batchCalls.count==3 && [status.stringValue isEqual:@"Alle installierten Trainer sind aktuell."],"current installed trainers cause no download");
    store.batchRefreshError=[NSError errorWithDomain:@"MHT.Layout" code:2 userInfo:@{NSLocalizedDescriptionKey:@"Absichtlicher Katalogfehler"}];
    store.batchCandidates=candidates;[button performClick:nil];awaitBatch(^BOOL{return ![[manager valueForKey:@"updatingAll"] boolValue];});
    require(store.batchCalls.count==3 && [status.stringValue containsString:@"Katalog nicht erreichbar"],"failed refresh stops the batch instead of using stale metadata");
    store.batchModules=nil;store.batchRefreshError=nil;store.batchCompletions=nil;search.stringValue=@"";[manager reloadForIdentifier:nil];
    require(!button.enabled,"without installed trainers the bulk button is disabled");
    puts("PASS: sequential updates of all installed trainers, filter independence, progress, duplicate guard, continued partial failures and catalog/no-update cases. No network or games.");
}
static MHTLayoutStore *fixtureStore(NSString *root) {
    NSMutableArray *modules=[NSMutableArray new];
    for(NSUInteger game=0;game<20;game++){
        NSString *identifier=game==0 ? @"dead-island-2" : [NSString stringWithFormat:@"layout-fixture-%lu",(unsigned long)game];
        NSString *name=game==0 ? @"Dead Island 2" : [NSString stringWithFormat:@"Layout-Test %02lu",(unsigned long)game];
        NSMutableArray *features=[NSMutableArray new],*groups=[NSMutableArray new],*profiles=[NSMutableArray new];
        for(NSUInteger i=0;i<12;i++)[features addObject:@{@"id":@(i),@"title":[NSString stringWithFormat:@"Lange deutsche Testfunktion %lu",(unsigned long)i],@"detail":@"Nur synthetische Darstellung, keine Spielanbindung.",@"binding":@"test.only",@"implemented":@YES,@"numeric":@(i%2),@"oneShot":@(i%3==2),@"integer":@YES,@"initial":@10,@"minimum":@0,@"maximum":@1000,@"step":@1,@"shortcut":@"⇧F12"}];
        for(NSUInteger i=0;i<3;i++)[groups addObject:@{@"id":[NSString stringWithFormat:@"group-%lu",(unsigned long)i],@"title":[NSString stringWithFormat:@"Testgruppe %lu",(unsigned long)i],@"symbol":@"slider.horizontal.3",@"features":@[@(i*4),@(i*4+1),@(i*4+2),@(i*4+3)]}];
        for(NSUInteger i=0;i<(game==0?2:1);i++)[profiles addObject:@{@"id":[NSString stringWithFormat:@"test-%lu",(unsigned long)i],@"name":@"Synthetisches Testprofil",@"store":i==0?@"Steam":@"Mac App Store",@"version":@"1.0",@"enabled":@NO,@"bundleIdentifier":[@"local.trainerdock.layout." stringByAppendingString:identifier],@"defaultPaths":@[]}];
        NSDictionary *manifest=@{@"schemaVersion":@1,@"id":identifier,@"name":name,@"version":@"1.0.0",@"profiles":profiles,@"features":features,@"groups":groups};
        require([MHTModule validManifest:manifest error:NULL],"synthetic module metadata validates");require(MHTTrainerVersion(@"1.0.0"),"trainer semantic version validates");
        NSDictionary *version=@{@"version":@"1.0.0",@"moduleABI":@1,@"minimumLauncherVersion":@"1.0.0",@"manifest":manifest};
        [modules addObject:@{@"id":identifier,@"name":name,@"versions":@[version]}];
    }
    [NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *catalog=[root stringByAppendingPathComponent:@"Bootstrap.json"];
    NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"schemaVersion":@1,@"moduleABI":@1,@"modules":modules} options:0 error:NULL];
    require([data writeToFile:catalog atomically:YES],"isolated catalog fixture is written outside source and build products");
    NSError *catalogError=nil;require([MHTTrainerStore validatedCatalog:[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] requireDownloads:NO error:&catalogError]!=nil,catalogError.localizedDescription.UTF8String ?: "catalog fixture validates");
    MHTLayoutStore *store=[[MHTLayoutStore alloc]initWithRootDirectory:[root stringByAppendingPathComponent:@"Modules"] catalogURL:nil bundledCatalogURL:[NSURL fileURLWithPath:catalog]];
    require(store.modules.count==20,"metadata-only catalog loads without runtime modules");return store;
}
static void checkTrainerDistribution(MHTApp *app) {
    MHTLayoutStore *store=[app valueForKey:@"trainerStore"];MHTModule *selected=[app valueForKey:@"selected"];
    require(!selected.installed && ![store installedVersionsForIdentifier:selected.identifier].count,"launcher starts with no downloaded runtimes");
    NSButton *start=[app valueForKey:@"start"];
    require([start.title isEqual:@"Trainer laden"] && !start.enabled,"unpublished metadata has an explicit disabled download action");
    NSArray *rows=[app valueForKey:@"rows"];for(id row in rows){NSControl *toggle=[row valueForKey:@"toggle"],*value=[row valueForKey:@"value"];require(!toggle.enabled && !value.enabled,"remote features are displayed but cannot pretend to control a game");}
    NSMutableDictionary *download=[selected.catalogVersion mutableCopy];download[@"downloadAvailable"]=@YES;selected.catalogVersion=download;
    [app startGame:nil];require(store.downloadRequests==1 && ![[app valueForKey:@"sessions"] count],"start without a runtime requests only one trainer download and never a game start");
    require([[(NSTextField *)[app valueForKey:@"status"] stringValue] containsString:@"Absichtlicher Downloadfehler"],"download failure is shown without an automatic retry or game launch");
    [app openTrainerLibrary:nil];MHTTrainerLibrary *manager=[app valueForKey:@"trainerLibrary"];[manager.window orderOut:nil];layout(manager.window);
    NSUInteger glasses=0,available=0;for(NSView *view in descendants(manager.window.contentView)){glasses+=[view.identifier isEqual:@"MHT.TrainerLibrary.Glass"];available+=[view.identifier isEqual:@"MHT.TrainerVersion.Available"];}
    require(glasses==1 && available==1,"trainer manager presents native glass and individual available versions");
    NSTableView *table=[manager valueForKey:@"table"];require(table.numberOfRows==20,"manager lists downloads independently of installed games");
    NSSegmentedControl *scope=[manager valueForKey:@"scope"];scope.selectedSegment=1;[scope sendAction:scope.action to:scope.target];require(table.numberOfRows==0,"downloaded filter is empty without installed trainer packages");
    NSSize expected=manager.window.frame.size;scope.selectedSegment=0;[scope sendAction:scope.action to:scope.target];layout(manager.window);require(sameSize(expected,manager.window.frame.size),"trainer filtering preserves user window size");
    checkTrainerManagerLayout(manager,store);
    checkBatchUpdates(manager,store);
    NSMutableDictionary *sessions=[app valueForKey:@"sessions"];MHTModule *bound=[app valueForKey:@"selected"];
    id session=[NSClassFromString(@"MHTSession") new];[session setValue:bound forKey:@"module"];[session setValue:@YES forKey:@"launching"];[session setValue:@"/private/tmp/layout-only-bound-runtime" forKey:@"runtimePath"];sessions[bound.identifier]=session;
    [app reloadTrainerModules];require([app valueForKey:@"selected"]==bound,"catalog refresh retains the exact module and feature catalog of an active launch");require([[app protectedRuntimePaths] containsObject:@"/private/tmp/layout-only-bound-runtime"],"running session exposes its exact runtime path to deletion protection");
    [sessions removeObjectForKey:bound.identifier];[app reloadTrainerModules];require([app valueForKey:@"selected"]!=bound,"ended sessions release their bound version for normal library selection");
    NSMenu *trainerMenu=[NSApp.mainMenu itemWithTitle:@"Trainer"].submenu;require([trainerMenu itemWithTitle:@"Trainer laden & verwalten …"].target==app && [trainerMenu itemWithTitle:@"Nach Trainerupdates suchen"].target==app,"native menu exposes trainer downloads and separate update checks");
    puts("PASS: empty-install catalog, disabled remote controls, explicit download-only start, German error and native version manager. No games or network requests.");
}
@interface MHTLayoutApp : MHTApp
@property(nonatomic) BOOL checksFinished;
@property(nonatomic,copy) NSString *fixtureRoot;
@end
@implementation MHTLayoutApp
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application{(void)application;return NO;}
- (void)applicationWillTerminate:(NSNotification *)notification {
    require(self.checksFinished,"UI tests must finish before the application exits");
    [super applicationWillTerminate:notification];
    [NSFileManager.defaultManager removeItemAtPath:self.fixtureRoot error:NULL];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.fixtureRoot=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"TrainerDockUILayout-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    [self setValue:fixtureStore(self.fixtureRoot) forKey:@"trainerStore"];
    [super applicationDidFinishLaunching:notification];
    // Run the checks from a run-loop callback so nested asynchronous waits can
    // drain the main queue; libdispatch does not reenter its own main callback.
    checkAsyncInspection(^{[NSTimer scheduledTimerWithTimeInterval:.001 repeats:NO block:^(NSTimer *timer){(void)timer;
        checkIcons();checkGlassToggle();
        NSWindow *window=[self valueForKey:@"window"];[window orderOut:nil];
        NSGlassEffectView *glass=[self valueForKey:@"libraryGlass"];
        require([glass isKindOfClass:NSGlassEffectView.class] && glass.contentView && glass.effectIsInteractive,"library uses one interactive native Liquid Glass surface");
        require(window.opaque && window.backgroundColor.alphaComponent==1 && window.toolbar && [window.title isEqual:@"TrainerDock"],"native titlebar keeps its system backing, toolbar and TrainerDock title above the glass library");
        NSBox *card=MHTCard([NSView new],0);[window.contentView addSubview:card];
        [card viewDidChangeBackingProperties];
        if(fabs(card.borderWidth*window.backingScaleFactor-1)>0.00001){fprintf(stderr,"FAIL: card border is not one backing pixel\n");exit(1);}
        [card removeFromSuperview];
        NSTableView *table=[self valueForKey:@"table"];NSUInteger checked=0;
        for(NSNumber *width in @[@1160,@980]){
            [window setContentSize:NSMakeSize(width.doubleValue,760)];layout(window);
            NSSize expected=window.frame.size;
            NSSplitViewController *split=[self valueForKey:@"split"];
            CGFloat sidebarWidth=split.splitViewItems.firstObject.viewController.view.bounds.size.width;
            if(fabs(expected.width-width.doubleValue)>1){fprintf(stderr,"FAIL: content expands window to %.0f instead of %.0f\n",expected.width,width.doubleValue);exit(1);}
            for(NSInteger row=0;row<table.numberOfRows;row++){
                [table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];layout(window);
                MHTModule *module=[self valueForKey:@"selected"];
                for(NSView *view in descendants(window.contentView)){
                    if([view isKindOfClass:NSButton.class])require(![((NSButton *)view).title isEqual:@"Liquid Glass im Spiel"],"Liquid Glass is permanent, without a redundant checkbox");
                    if([view isKindOfClass:NSTextField.class])require(![((NSTextField *)view).stringValue hasPrefix:@"/Volumes/"],"main view does not display the long installation path");
                }
                NSButton *start=[self valueForKey:@"start"];
                require(start.bezelStyle==NSBezelStyleGlass && start.borderShape==NSControlBorderShapeCapsule,"Spielen uses the native Liquid Glass button");
                NSArray<MHTFeatureGroup *> *groups=[self valueForKey:@"groups"];
                require(groups.count==module.featureGroups.count,"module metadata supplies all group headings");
                NSArray *rows=[self valueForKey:@"rows"];
                require(rows.count==module.features.count,"group ordering preserves every native feature");
                for(NSUInteger i=0;i<rows.count;i++){
                    NSControl *action=[rows[i] valueForKey:@"toggle"] ?: [rows[i] valueForKey:@"run"];
                    require(action.tag==(NSInteger)i,"grouped actions retain native IDs");
                    NSControl *value=[rows[i] valueForKey:@"value"];
                    require(!value || value.tag==(NSInteger)i,"numeric editors retain native IDs");
                }
                MHTFeatureGroup *group=groups.firstObject;BOOL wasCollapsed=group.collapsed;
                CGFloat before=NSHeight(group.frame);
                [group.header performClick:nil];layout(window);
                require(group.collapsed!=wasCollapsed,"heading toggles the complete group");
                require(group.collapsed ? NSHeight(group.frame)<before-40 : NSHeight(group.frame)>before+40,"collapsing physically removes the group's rows from layout");
                require(NSHeight(group.header.visibleRect)>=NSHeight(group.header.bounds)-1,"clicked group heading remains visible after collapsing");
                require(sameSize(window.frame.size,expected),"collapsing a group preserves window size");
                [group.header performClick:nil];layout(window);
                require(group.collapsed==wasCollapsed,"expanding a group restores its presentation");
                NSStackView *features=[self valueForKey:@"featureList"];
                [self filter:nil];
                require(features==[self valueForKey:@"featureList"],"filtering an unchanged selection reuses its existing view");
                if(row==0){
                    NSMutableArray *was=[NSMutableArray new];
                    for(MHTFeatureGroup *section in groups){[was addObject:@(section.collapsed)];if(!section.collapsed)[section.header performClick:nil];}
                    layout(window);
                    NSClipView *clip=features.enclosingScrollView.contentView;
                    NSRect first=[groups.firstObject convertRect:groups.firstObject.bounds toView:clip];
                    require(clip.isFlipped && features.enclosingScrollView.documentView.isFlipped && NSMinY(first)>=-1 && NSMinY(first)<2,"short collapsed lists stay at the top without empty space above them");
                    for(MHTFeatureGroup *section in groups)require(NSHeight(section.frame)<60,"collapsed cards keep their natural heading height instead of filling the viewport");
                    for(NSUInteger i=0;i<groups.count;i++)if(groups[i].collapsed!=[was[i] boolValue])[groups[i].header performClick:nil];
                    layout(window);
                }
                for(NSView *view in descendants(features))if([view.identifier hasPrefix:@"MHT.Feature."]){
                    NSRect bounds=[view convertRect:view.bounds toView:features];
                    require(NSWidth(bounds)>400 && NSMinX(bounds)>=-1 && NSMaxX(bounds)<=NSWidth(features.bounds)+1,"feature rows fit their scroll document");
                }
                if(!sameSize(window.frame.size,expected)){fprintf(stderr,"FAIL: module %ld resizes window %.0fx%.0f -> %.0fx%.0f\n",(long)row,expected.width,expected.height,window.frame.size.width,window.frame.size.height);exit(1);}
                if(fabs(split.splitViewItems.firstObject.viewController.view.bounds.size.width-sidebarWidth)>1){fprintf(stderr,"FAIL: module selection changes sidebar width\n");exit(1);}
                checked++;
            }
            NSSearchField *search=[self valueForKey:@"search"];search.stringValue=@"no-matching-game";[self filter:nil];layout(window);
            if(!sameSize(window.frame.size,expected)){fprintf(stderr,"FAIL: empty search resizes window\n");exit(1);}
            search.stringValue=@"";[self filter:nil];layout(window);
            if(!sameSize(window.frame.size,expected)){fprintf(stderr,"FAIL: restored library resizes window\n");exit(1);}
        }
        checkSettings(self);checkTrainerDistribution(self);
        printf("PASS: 1x/2x icon representation selection, pixel border, %lu module selections at two window widths and empty search preserve window size. No games launched.\n",(unsigned long)checked);
        self.checksFinished=YES;[NSApp terminate:nil];
    }];});
}
@end
int main(void){@autoreleasepool {
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    MHTLayoutApp *app=[MHTLayoutApp new];app.smokeTest=YES;NSApp.delegate=app;[NSApp run];
}return 0;}
