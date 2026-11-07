// SPDX-License-Identifier: GPL-3.0-only
// Exercise the real launcher with real module metadata; never start a game.
#import "MHTApp.h"
#import "MHTAppearance.h"
#import "MHTTrainerSettings.h"
#import "MHTTrainerViews.h"
@interface MHTApp (LayoutChecks)
- (void)filter:(id)sender;
- (void)refreshInstallation;
@end
// Deliberately blocked identity check, confined to tests; never used to launch.
@interface MHTSlowProfile : MHTModule
@property(nonatomic) dispatch_semaphore_t entered,releaseCheck;
@property(atomic) BOOL usedMainThread;
@property(atomic) BOOL slowFinished;
@end
@implementation MHTSlowProfile
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
@interface MHTLayoutApp : MHTApp
@property(nonatomic) BOOL checksFinished;
@end
@implementation MHTLayoutApp
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application{(void)application;return NO;}
- (void)applicationWillTerminate:(NSNotification *)notification {
    require(self.checksFinished,"UI tests must finish before the application exits");
    [super applicationWillTerminate:notification];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [super applicationDidFinishLaunching:notification];
    checkAsyncInspection(^{dispatch_async(dispatch_get_main_queue(),^{
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
        checkSettings(self);
        printf("PASS: 1x/2x icon representation selection, pixel border, %lu module selections at two window widths and empty search preserve window size. No games launched.\n",(unsigned long)checked);
        self.checksFinished=YES;[NSApp terminate:nil];
    });});
}
@end
int main(void){@autoreleasepool {
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    MHTLayoutApp *app=[MHTLayoutApp new];app.smokeTest=YES;NSApp.delegate=app;[NSApp run];
}return 0;}
