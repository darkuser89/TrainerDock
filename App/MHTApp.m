// SPDX-License-Identifier: GPL-3.0-only
#import "MHTApp.h"
#import "MHTModule.h"
#import "MHTDiscovery.h"
#import "MHTEpicLaunch.h"
#import "MHTProtocol.h"
#import "GameIdentity.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "MHTGameIcons.h"
#import "MHTAppearance.h"
#import "MHTTrainerSettings.h"
#import "MHTMenu.h"
#import "MHTTrainerViews.h"
#import "MHTUpdater.h"
#import "MHTTrainerStore.h"
#import "MHTTrainerLibrary.h"
static NSButton *button(NSString *title,id target,SEL action) {return [NSButton buttonWithTitle:title target:target action:action];}
@interface MHTSession : NSObject
@property(nonatomic) NSRunningApplication *app;
@property(nonatomic) NSTask *task;
@property(nonatomic,readonly) BOOL running;
@property(nonatomic,readonly) pid_t processIdentifier;
@property(nonatomic,copy) NSString *token;
@property(nonatomic,copy) NSDictionary *profile,*state,*options;
@property(nonatomic) double receivedAt,startedAt;
@property(nonatomic) BOOL launching;
@property(nonatomic) NSMutableDictionary<NSString *,NSDictionary *> *pending;
@property(nonatomic) MHTModule *module;
@property(nonatomic,copy) NSString *runtimePath;
@end
@implementation MHTSession
- (instancetype)init{if((self=[super init]))_pending=[NSMutableDictionary new];return self;}
- (BOOL)running{return self.task ? self.task.running : self.app && !self.app.terminated;}
- (pid_t)processIdentifier{return self.task ? self.task.processIdentifier : self.app.processIdentifier;}
@end
@interface MHTRow : NSObject
@property(nonatomic) MHTGlassToggle *toggle;
@property(nonatomic) NSStepper *stepper;
@property(nonatomic) NSButton *run;
@property(nonatomic) NSTextField *value,*note,*state;
@end
@implementation MHTRow @end

@interface MHTApp () <NSToolbarDelegate,NSSearchFieldDelegate>
@property(nonatomic) NSWindow *window,*settingsWindow;
@property(nonatomic) MHTTrainerSettings *trainerSettings;
@property(nonatomic) NSArray<MHTModule *> *modules,*visibleModules;
@property(nonatomic) MHTModule *selected;
@property(nonatomic) NSTableView *table;
@property(nonatomic) NSSplitViewController *split;
@property(nonatomic) NSSearchField *search;
@property(nonatomic) NSSegmentedControl *libraryFilter;
@property(nonatomic) NSTextField *libraryCount;
@property(nonatomic) NSImageView *gameIcon;
@property(nonatomic) MHTTrainerBackdrop *backdrop;
@property(nonatomic) NSGlassEffectView *libraryGlass;
@property(nonatomic) NSMutableArray<MHTFeatureGroup *> *groups;
@property(nonatomic) NSButton *allModules,*start,*restore,*showOverlay,*allOff,*pathButton;
@property(nonatomic) NSPopUpButton *profiles;
@property(nonatomic) NSTextField *titleLabel,*subtitle,*compatibilityNoteLabel,*status;
@property(nonatomic) NSStackView *detail,*featureList;
@property(nonatomic) NSMutableArray<MHTRow *> *rows;
@property(nonatomic) NSMutableDictionary<NSString *,MHTSession *> *sessions;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) id stateObserver;
@property(nonatomic) NSOperationQueue *inspectionQueue,*discoveryQueue;
@property(nonatomic) NSUInteger inspectionGeneration;
@property(nonatomic) MHTUpdater *updater;
@property(nonatomic) MHTEpicLaunchService *epicLauncher;
@property(nonatomic) MHTTrainerStore *trainerStore;
@property(nonatomic) MHTTrainerLibrary *trainerLibrary;
@property(nonatomic) id trainerStoreObserver;
@property(nonatomic) NSButton *trainerUpdates,*trainerDownload;
@property(nonatomic) NSTextField *trainerVersionLabel;
@property(nonatomic) NSProgressIndicator *trainerProgress;
@end
@implementation MHTApp
- (NSDictionary *)profile {return self.profiles.indexOfSelectedItem>=0 && self.profiles.indexOfSelectedItem<(NSInteger)self.selected.profiles.count ? self.selected.profiles[self.profiles.indexOfSelectedItem] : self.selected.profiles.firstObject;}
- (MHTSession *)session{return self.sessions[self.selected.identifier];}
- (BOOL)live:(MHTSession *)s{return s.running && s.receivedAt>0 && NSDate.date.timeIntervalSince1970-s.receivedAt<2.5;}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;MHTInstallMenus(self);self.sessions=[NSMutableDictionary new];NSMutableArray *errors=[NSMutableArray new];
    self.epicLauncher=[[MHTEpicLaunchService alloc]initWithBrokerURL:[NSBundle.mainBundle.executableURL.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"TrainerDockEpicBroker"]];
    if(!self.smokeTest){NSError *recoveryError=nil;if(![self.epicLauncher recoverPendingTransactions:&recoveryError] && recoveryError)[errors addObject:recoveryError.localizedDescription];}
    if(!self.trainerStore)self.trainerStore=MHTTrainerStore.sharedStore;
    self.modules=[self.trainerStore modulesWithErrors:errors];
    if(!self.smokeTest){
        __weak MHTApp *weakApp=self;
        self.updater=[[MHTUpdater alloc]initWithRunningGames:^BOOL{return [weakApp hasRunningGames];}];
        [self.updater start];
    }
    self.inspectionQueue=[NSOperationQueue new];self.inspectionQueue.maxConcurrentOperationCount=1;self.inspectionQueue.qualityOfService=NSQualityOfServiceUserInitiated;self.inspectionQueue.name=@"MHT.ProfilePreview";
    self.discoveryQueue=[NSOperationQueue new];self.discoveryQueue.maxConcurrentOperationCount=1;self.discoveryQueue.qualityOfService=NSQualityOfServiceUtility;self.discoveryQueue.name=@"MHT.Discovery";
    self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1160,800) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"TrainerDock";self.window.subtitle=@"Spielebibliothek";self.window.minSize=NSMakeSize(980,680);self.window.releasedWhenClosed=NO;
    self.window.toolbarStyle=NSWindowToolbarStyleUnified;self.window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    // Keep the system titlebar backing. A clear window background also clears
    // unified titlebar chrome and can make its title and traffic lights vanish.
    self.window.backgroundColor=NSColor.windowBackgroundColor;self.window.opaque=YES;
    self.split=[NSSplitViewController new];self.split.splitView.dividerStyle=NSSplitViewDividerStyleThin;
    NSViewController *sidebarController=[NSViewController new],*detailController=[NSViewController new];
    NSView *sidebar=[NSView new];sidebarController.view=[NSView new];
    self.libraryGlass=[NSGlassEffectView new];self.libraryGlass.identifier=@"MHT.Library.Glass";
    self.libraryGlass.style=NSGlassEffectViewStyleRegular;self.libraryGlass.cornerRadius=20;
    self.libraryGlass.effectIsInteractive=YES;self.libraryGlass.contentView=sidebar;
    // A single native glass surface contains search, filters and the whole library.
    // No opaque sidebar fill or additional blur obscures the system material.
    MHTFill(self.libraryGlass,sidebarController.view,6);
    self.backdrop=[MHTTrainerBackdrop new];detailController.view=self.backdrop;
    NSSplitViewItem *sidebarItem=[NSSplitViewItem sidebarWithViewController:sidebarController];sidebarItem.minimumThickness=240;sidebarItem.maximumThickness=340;sidebarItem.preferredThicknessFraction=0.245;sidebarItem.canCollapse=YES;
    [self.split addSplitViewItem:sidebarItem];[self.split addSplitViewItem:[NSSplitViewItem splitViewItemWithViewController:detailController]];
    self.window.contentViewController=self.split;
    NSToolbar *toolbar=[[NSToolbar alloc]initWithIdentifier:@"MHT.Library"];toolbar.delegate=self;toolbar.displayMode=NSToolbarDisplayModeIconOnly;toolbar.allowsUserCustomization=NO;self.window.toolbar=toolbar;
    NSTextField *brand=MHTLabel(@"Bibliothek",23,NSFontWeightBold);
    self.libraryCount=MHTLabel(@"",11,NSFontWeightRegular);self.libraryCount.textColor=NSColor.secondaryLabelColor;
    self.trainerUpdates=button(@"Trainer laden & verwalten …",self,@selector(openTrainerLibrary:));self.trainerUpdates.bezelStyle=NSBezelStyleGlass;self.trainerUpdates.controlSize=NSControlSizeSmall;self.trainerUpdates.identifier=@"MHT.TrainerUpdates";
    self.search=[NSSearchField new];self.search.placeholderString=@"Spiele suchen";self.search.delegate=self;self.search.controlSize=NSControlSizeRegular;
    self.allModules=[NSButton checkboxWithTitle:@"Alle Trainer anzeigen" target:self action:@selector(filter:)];
    self.libraryFilter=[NSSegmentedControl segmentedControlWithLabels:@[@"Installiert",@"Alle Trainer"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(filter:)];self.libraryFilter.selectedSegment=0;self.libraryFilter.controlSize=NSControlSizeSmall;
    NSScrollView *list=[NSScrollView new];list.hasVerticalScroller=YES;list.drawsBackground=NO;list.translatesAutoresizingMaskIntoConstraints=NO;list.autohidesScrollers=YES;
    self.table=[[NSTableView alloc]initWithFrame:NSZeroRect];NSTableColumn *column=[[NSTableColumn alloc]initWithIdentifier:@"game"];[self.table addTableColumn:column];self.table.headerView=nil;self.table.rowHeight=62;self.table.intercellSpacing=NSMakeSize(0,4);self.table.backgroundColor=NSColor.clearColor;self.table.style=NSTableViewStyleSourceList;self.table.delegate=self;self.table.dataSource=self;self.table.columnAutoresizingStyle=NSTableViewUniformColumnAutoresizingStyle;list.documentView=self.table;
    NSButton *settings=button(@"Trainer & Spielpfade …",self,@selector(openSettings:));settings.image=[NSImage imageWithSystemSymbolName:@"slider.horizontal.3" accessibilityDescription:nil];settings.imagePosition=NSImageLeading;settings.bordered=NO;settings.alignment=NSTextAlignmentLeft;
    NSStackView *left=MHTStack(@[brand,self.libraryCount,self.trainerUpdates,self.search,self.libraryFilter,list,settings],YES,12);MHTFill(left,sidebar,16);
    for(NSView *view in @[self.trainerUpdates,self.search,self.libraryFilter,list,settings])[view.widthAnchor constraintEqualToAnchor:left.widthAnchor].active=YES;
    [list.heightAnchor constraintGreaterThanOrEqualToConstant:180].active=YES;[left setCustomSpacing:2 afterView:brand];[left setCustomSpacing:18 afterView:self.libraryCount];
    self.detail=MHTStack(@[],YES,16);MHTFill(self.detail,detailController.view,26);
    __weak MHTApp *weakSelf=self;
    self.stateObserver=[NSDistributedNotificationCenter.defaultCenter addObserverForName:MHTStateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){[weakSelf receive:MHTDecodeMessage(n.object)];}];
    self.trainerStoreObserver=[NSNotificationCenter.defaultCenter addObserverForName:MHTTrainerStoreDidChangeNotification object:self.trainerStore queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;[weakSelf reloadTrainerModules];}];
    self.timer=[NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t){(void)t;[weakSelf tick];}];
    BOOL hasInstalledGame=NO;for(MHTModule *module in self.modules)for(NSDictionary *profile in module.profiles)hasInstalledGame|=MHTIsInstalled(module,profile);
    if(!hasInstalledGame){self.allModules.state=NSControlStateValueOn;self.libraryFilter.selectedSegment=1;}
    [self filter:nil];[self.window center];[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
    if(errors.count){NSAlert *alert=[NSAlert new];alert.messageText=@"Einige Trainer konnten nicht geladen werden";alert.informativeText=[errors componentsJoinedByString:@"\n"];[alert beginSheetModalForWindow:self.window completionHandler:nil];}
    if(self.smokeTest){self.allModules.state=NSControlStateValueOn;self.libraryFilter.selectedSegment=1;[self filter:nil];}
    [self discoverInstallations];
    [self updateTrainerSummary];
    if(!self.smokeTest)[self checkTrainerUpdates:nil];
}
- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {(void)toolbar;return @[@"sidebar",NSToolbarFlexibleSpaceItemIdentifier,@"trainers",@"refresh",@"settings"];}
- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {return [self toolbarAllowedItemIdentifiers:toolbar];}
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)identifier willBeInsertedIntoToolbar:(BOOL)flag {
    (void)toolbar;(void)flag;NSToolbarItem *item=[[NSToolbarItem alloc]initWithItemIdentifier:identifier];
    NSString *symbol=@"slider.horizontal.3";
    if([identifier isEqual:@"sidebar"]){symbol=@"sidebar.left";item.label=@"Seitenleiste";item.target=self.split;item.action=@selector(toggleSidebar:);}
    else if([identifier isEqual:@"trainers"]){symbol=@"square.and.arrow.down";item.label=@"Trainer laden & verwalten";item.target=self;item.action=@selector(openTrainerLibrary:);}
    else if([identifier isEqual:@"refresh"]){symbol=@"arrow.clockwise";item.label=@"Trainer & Spiele neu laden";item.target=self;item.action=@selector(rescan:);}
    else {item.label=@"Trainer & Spielpfade";item.target=self;item.action=@selector(openSettings:);}
    item.image=[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:item.label];item.toolTip=item.label;return item;
}
- (void)controlTextDidChange:(NSNotification *)notification {if(notification.object==self.search)[self filter:nil];}
- (void)filter:(id)sender {
    if(sender==self.libraryFilter)self.allModules.state=self.libraryFilter.selectedSegment==1 ? NSControlStateValueOn : NSControlStateValueOff;
    NSString *previous=self.selected.identifier,*query=[self.search.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];NSMutableArray *visible=[NSMutableArray new];
    NSUInteger installedCount=0;
    for(MHTModule *m in self.modules){BOOL installed=NO;for(NSDictionary *p in m.profiles)installed|=MHTIsInstalled(m,p);if(installed)installedCount++;
        if((installed || self.allModules.state==NSControlStateValueOn) && (!query.length || [m.name localizedStandardContainsString:query]))[visible addObject:m];}
    self.libraryCount.stringValue=query.length ? [NSString stringWithFormat:@"%lu Treffer",(unsigned long)visible.count] : [NSString stringWithFormat:@"%lu Spiele · %lu Trainer",(unsigned long)installedCount,(unsigned long)self.modules.count];
    self.visibleModules=visible;[self.table reloadData];NSInteger index=0;
    for(NSUInteger i=0;i<visible.count;i++)if([[visible[i] identifier] isEqual:previous])index=(NSInteger)i;
    if(visible.count){[self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];if(self.selected!=visible[index]){self.selected=visible[index];[self renderDetail];}}
    else {self.selected=nil;[self renderDetail];}
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView{(void)tableView;return self.visibleModules.count;}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)tableView;(void)column;MHTModule *m=self.visibleModules[row];NSMutableOrderedSet *stores=[NSMutableOrderedSet new];BOOL installed=NO;
    for(NSDictionary *p in m.profiles){[stores addObject:p[@"store"] ?: @"Unbekannt"];installed|=MHTIsInstalled(m,p);}
    NSTextField *name=MHTLabel(m.name,12,NSFontWeightSemibold);name.toolTip=m.name;
    NSString *caption=installed ? [stores.array componentsJoinedByString:@" / "] : @"Spiel nicht installiert";
    if(!m.installed)caption=[caption stringByAppendingString:@" · Trainer laden"];
    else if(m.updateAvailable)caption=[caption stringByAppendingString:m.packageMigrationAvailable ? @" · GitHub-Paket" : @" · Trainerupdate"];
    NSTextField *small=MHTLabel(caption,10,NSFontWeightRegular);small.textColor=m.updateAvailable ? NSColor.systemCyanColor : NSColor.secondaryLabelColor;
    NSStackView *texts=MHTStack(@[name,small],YES,4);[texts setContentCompressionResistancePriority:249 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [name.widthAnchor constraintEqualToAnchor:texts.widthAnchor].active=YES;[small.widthAnchor constraintEqualToAnchor:texts.widthAnchor].active=YES;
    NSStackView *v=MHTStack(@[MHTIconView(MHTGameIcon(m,nil),40,m.name),texts],NO,10);NSTableCellView *cell=[NSTableCellView new];cell.textField=name;MHTFill(v,cell,6);return cell;
}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;NSInteger row=self.table.selectedRow;if(row<0 || row>=(NSInteger)self.visibleModules.count)return;
    if(self.selected==self.visibleModules[row])return;
    self.selected=self.visibleModules[row];[self renderDetail];
}
- (void)renderDetail {
    self.inspectionGeneration++;[self.inspectionQueue cancelAllOperations];
    for(NSView *view in self.detail.arrangedSubviews.copy){[self.detail removeArrangedSubview:view];[view removeFromSuperview];}
    self.rows=[NSMutableArray new];self.groups=[NSMutableArray new];self.profiles=nil;self.gameIcon=nil;self.start=nil;self.status=nil;self.trainerVersionLabel=nil;self.trainerDownload=nil;self.trainerProgress=nil;
    if(!self.selected){
        BOOL searching=self.search.stringValue.length>0;
        NSImageView *icon=MHTIconView([NSImage imageWithSystemSymbolName:searching ? @"magnifyingglass" : @"gamecontroller" accessibilityDescription:nil],56,@"Bibliothek");icon.contentTintColor=NSColor.tertiaryLabelColor;
        NSTextField *empty=[NSTextField wrappingLabelWithString:searching ? @"Versuche einen anderen Spielnamen oder zeige alle Trainer an." : @"Wähle unter „Trainer & Spielpfade“ deine Spiele-Apps aus, um deine Bibliothek einzurichten."];empty.textColor=NSColor.secondaryLabelColor;
        [self.detail addArrangedSubview:icon];[self.detail addArrangedSubview:MHTLabel(searching ? @"Keine Spiele gefunden" : @"Deine Spiele. Deine Trainer.",25,NSFontWeightBold)];
        [self.detail addArrangedSubview:empty];[self.detail addArrangedSubview:button(@"Trainer laden & verwalten …",self,@selector(openTrainerLibrary:))];[self.detail addArrangedSubview:button(@"Spielpfade einrichten …",self,@selector(openSettings:))];return;
    }
    self.titleLabel=MHTLabel(self.selected.name,28,NSFontWeightBold);self.titleLabel.toolTip=self.selected.name;
    self.subtitle=MHTLabel(@"",12,NSFontWeightRegular);self.subtitle.textColor=NSColor.secondaryLabelColor;
    self.compatibilityNoteLabel=MHTLabel(@"",12,NSFontWeightSemibold);self.compatibilityNoteLabel.textColor=NSColor.systemRedColor;self.compatibilityNoteLabel.hidden=YES;
    NSStackView *titles=MHTStack(@[self.titleLabel,self.subtitle,self.compatibilityNoteLabel],YES,8);
    [titles setContentHuggingPriority:249 forOrientation:NSLayoutConstraintOrientationHorizontal];[titles setContentCompressionResistancePriority:249 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self.titleLabel.widthAnchor constraintEqualToAnchor:titles.widthAnchor].active=YES;[self.subtitle.widthAnchor constraintEqualToAnchor:titles.widthAnchor].active=YES;
    [self.compatibilityNoteLabel.widthAnchor constraintEqualToAnchor:titles.widthAnchor].active=YES;
    self.gameIcon=MHTIconView(MHTGameIcon(self.selected,nil),76,self.selected.name);
    self.start=button(@"Spielen",self,@selector(startGame:));self.start.bezelStyle=NSBezelStyleGlass;self.start.borderShape=NSControlBorderShapeCapsule;self.start.controlSize=NSControlSizeLarge;self.start.font=[NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];self.start.bezelColor=NSColor.systemCyanColor;self.start.image=[NSImage imageWithSystemSymbolName:@"play.fill" accessibilityDescription:nil];self.start.imagePosition=NSImageLeading;self.start.accessibilityLabel=@"Spiel mit Trainer starten";self.start.toolTip=@"Das ausgewählte Spiel mit seinem Trainer starten";
    [self.start.widthAnchor constraintEqualToConstant:164].active=YES;[self.start.heightAnchor constraintEqualToConstant:46].active=YES;
    NSStackView *hero=MHTStack(@[self.gameIcon,titles,self.start],NO,16);[self.detail addArrangedSubview:hero];[hero.widthAnchor constraintEqualToAnchor:self.detail.widthAnchor].active=YES;
    [self.detail setCustomSpacing:22 afterView:hero];
    self.profiles=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];self.profiles.target=self;self.profiles.action=@selector(profileChanged:);self.profiles.controlSize=NSControlSizeSmall;
    [self.profiles.widthAnchor constraintEqualToConstant:210].active=YES;
    NSInteger selectedIndex=0;NSString *saved=[NSUserDefaults.standardUserDefaults stringForKey:[@"MHT.profile." stringByAppendingString:self.selected.identifier]];
    for(NSUInteger i=0;i<self.selected.profiles.count;i++){
        NSDictionary *profile=self.selected.profiles[i];
        NSString *note=profile[@"compatibilityNote"],*caption=[NSString stringWithFormat:@"%@ · Version %@",profile[@"store"],profile[@"gameVersion"] ?: profile[@"version"]];
        [self.profiles addItemWithTitle:note.length ? [caption stringByAppendingFormat:@" · %@",note] : caption];
        if(note.length){
            NSMenuItem *item=self.profiles.lastItem;NSMutableAttributedString *title=[[NSMutableAttributedString alloc]initWithString:item.title];
            [title addAttribute:NSForegroundColorAttributeName value:NSColor.systemRedColor range:NSMakeRange(title.length-note.length,note.length)];item.attributedTitle=title;item.toolTip=item.title;
        }
        if([profile[@"id"] isEqual:saved] || (!saved && MHTIsInstalled(self.selected,profile)))selectedIndex=(NSInteger)i;
    }
    [self.profiles selectItemAtIndex:selectedIndex];
    self.pathButton=button(@"Spielpfad …",self,@selector(chooseSelectedPath:));self.pathButton.controlSize=NSControlSizeSmall;
    self.restore=[NSButton checkboxWithTitle:@"Auswahl beim Start laden" target:self action:@selector(settingsChanged:)];self.restore.state=[self.selected.settings[@"restore"] boolValue];self.restore.font=[NSFont systemFontOfSize:11];self.restore.toolTip=@"Dauerschalter nach dem Laden wiederherstellen. Einmalaktionen werden nie automatisch ausgeführt.";
    NSStackView *settings=MHTStack(@[self.profiles,MHTSpacer(),self.restore,self.pathButton],NO,12);
    NSBox *settingsCard=MHTCard(settings,14);settingsCard.fillColor=[NSColor colorWithWhite:0.08 alpha:0.8];[self.detail addArrangedSubview:settingsCard];[settingsCard.widthAnchor constraintEqualToAnchor:self.detail.widthAnchor].active=YES;
    self.trainerVersionLabel=MHTLabel(@"",11,NSFontWeightRegular);self.trainerVersionLabel.textColor=NSColor.secondaryLabelColor;
    self.trainerProgress=[NSProgressIndicator new];self.trainerProgress.style=NSProgressIndicatorStyleSpinning;self.trainerProgress.controlSize=NSControlSizeSmall;self.trainerProgress.displayedWhenStopped=NO;
    self.trainerDownload=button(@"Trainer laden",self,@selector(downloadSelectedTrainer:));self.trainerDownload.bezelStyle=NSBezelStyleGlass;self.trainerDownload.controlSize=NSControlSizeSmall;self.trainerDownload.identifier=@"MHT.TrainerDownload";
    NSButton *versions=button(@"Versionen …",self,@selector(openTrainerLibrary:));versions.bezelStyle=NSBezelStyleGlass;versions.controlSize=NSControlSizeSmall;versions.identifier=@"MHT.TrainerVersions";
    NSStackView *distribution=MHTStack(@[self.trainerVersionLabel,MHTSpacer(),self.trainerProgress,self.trainerDownload,versions],NO,10);[self.detail addArrangedSubview:distribution];[distribution.widthAnchor constraintEqualToAnchor:self.detail.widthAnchor].active=YES;
    NSTextField *count=MHTLabel([NSString stringWithFormat:@"%lu Gruppen · %lu Funktionen",(unsigned long)self.selected.featureGroups.count,(unsigned long)self.selected.features.count],11,NSFontWeightRegular);count.textColor=NSColor.secondaryLabelColor;
    NSButton *collapse=button(@"Gruppen ein-/ausklappen",self,@selector(toggleGroups:));collapse.bordered=NO;collapse.font=[NSFont systemFontOfSize:11];collapse.contentTintColor=NSColor.secondaryLabelColor;
    NSStackView *featureHeading=MHTStack(@[MHTLabel(@"Trainer",16,NSFontWeightSemibold),count,MHTSpacer(),collapse],NO,10);[self.detail addArrangedSubview:featureHeading];[featureHeading.widthAnchor constraintEqualToAnchor:self.detail.widthAnchor].active=YES;
    [self.detail setCustomSpacing:10 afterView:featureHeading];
    self.featureList=MHTStack(@[],YES,14);NSScrollView *scroll=MHTTrainerScroll(self.featureList);
    [self.detail addArrangedSubview:scroll];[scroll.widthAnchor constraintEqualToAnchor:self.detail.widthAnchor].active=YES;[scroll.heightAnchor constraintGreaterThanOrEqualToConstant:180].active=YES;
    NSDictionary *selection=self.selected.selection;NSMutableDictionary<NSNumber *,NSView *> *containers=[NSMutableDictionary new];
    // Keep rows in native ID order even when sections reorder their presentation.
    for(NSDictionary *f in self.selected.features){
        NSInteger i=[f[@"id"] integerValue];MHTRow *row=[MHTRow new];
        NSTextField *name=MHTLabel(f[@"title"],13,NSFontWeightMedium);name.toolTip=f[@"detail"];
        row.state=MHTLabel(@"",10,NSFontWeightMedium);
        row.note=MHTLabel(f[@"detail"] ?: @"",10,NSFontWeightRegular);row.note.textColor=NSColor.secondaryLabelColor;row.note.toolTip=f[@"detail"];
        NSStackView *notes=MHTStack(@[row.state,row.note],NO,8);[row.state setContentCompressionResistancePriority:750 forOrientation:NSLayoutConstraintOrientationHorizontal];
        NSStackView *texts=MHTStack(@[name,notes],YES,6);[texts setContentHuggingPriority:249 forOrientation:NSLayoutConstraintOrientationHorizontal];[texts setContentCompressionResistancePriority:249 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [name.widthAnchor constraintEqualToAnchor:texts.widthAnchor].active=YES;[notes.widthAnchor constraintEqualToAnchor:texts.widthAnchor].active=YES;
        NSTextField *shortcut=MHTLabel(f[@"shortcut"] ?: @"",10,NSFontWeightMedium);shortcut.font=[NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightMedium];shortcut.textColor=NSColor.secondaryLabelColor;shortcut.alignment=NSTextAlignmentCenter;shortcut.toolTip=f[@"shortcut"];
        NSBox *badge=MHTCard(shortcut,6);badge.cornerRadius=8;badge.fillColor=[NSColor colorWithWhite:0.18 alpha:0.55];badge.borderColor=NSColor.clearColor;[badge.widthAnchor constraintEqualToConstant:68].active=YES;badge.hidden=![f[@"shortcut"] length];
        NSMutableArray *controls=[NSMutableArray arrayWithObject:texts];
        NSView *valueSlot=[NSView new];valueSlot.translatesAutoresizingMaskIntoConstraints=NO;[valueSlot.widthAnchor constraintEqualToConstant:110].active=YES;
        if([f[@"numeric"] boolValue]){
            row.value=[[NSTextField alloc]initWithFrame:NSZeroRect];row.value.font=[NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium];row.value.alignment=NSTextAlignmentRight;row.value.tag=i;row.value.target=self;row.value.action=@selector(valueChanged:);row.value.controlSize=NSControlSizeSmall;row.value.bezelStyle=NSTextFieldRoundedBezel;
            NSNumberFormatter *formatter=[NSNumberFormatter new];formatter.numberStyle=NSNumberFormatterDecimalStyle;formatter.locale=NSLocale.currentLocale;formatter.maximumFractionDigits=[f[@"integer"] boolValue] ? 0 : 6;formatter.allowsFloats=![f[@"integer"] boolValue];formatter.lenient=NO;row.value.formatter=formatter;
            row.value.doubleValue=[selection[[f[@"id"] stringValue]][@"value"] doubleValue];row.value.accessibilityLabel=[f[@"title"] stringByAppendingString:@" – Wert"];
            row.value.toolTip=[NSString stringWithFormat:@"%@ bis %@ · Eingabe übernimmt",f[@"minimum"],f[@"maximum"]];
            row.stepper=[NSStepper new];row.stepper.minValue=[f[@"minimum"] doubleValue];row.stepper.maxValue=[f[@"maximum"] doubleValue];row.stepper.increment=MAX(0.000001,[f[@"step"] doubleValue]);row.stepper.doubleValue=row.value.doubleValue;row.stepper.valueWraps=NO;row.stepper.controlSize=NSControlSizeSmall;row.stepper.tag=i;row.stepper.target=self;row.stepper.action=@selector(stepValue:);row.stepper.accessibilityLabel=[f[@"title"] stringByAppendingString:@" – Wert ändern"];
            NSStackView *editor=MHTStack(@[row.value,row.stepper],NO,5);MHTFill(editor,valueSlot,0);
        }
        [controls addObject:valueSlot];
        NSControl *action=nil;
        if([f[@"oneShot"] boolValue]){row.run=button(@"Anwenden",self,@selector(featureAction:));row.run.controlSize=NSControlSizeSmall;row.run.tag=i;row.run.accessibilityLabel=[f[@"title"] stringByAppendingString:@" anwenden"];action=row.run;}
        else {row.toggle=[MHTGlassToggle new];row.toggle.target=self;row.toggle.action=@selector(featureAction:);row.toggle.tag=i;row.toggle.selectedSegment=0;row.toggle.accessibilityLabel=f[@"title"];action=row.toggle;}
        NSStackView *actionSlot=MHTStack(@[MHTSpacer(),action],NO,0);[actionSlot.widthAnchor constraintEqualToConstant:88].active=YES;[controls addObject:actionSlot];
        NSStackView *shortcutSlot=MHTStack(@[badge],NO,0);[shortcutSlot.widthAnchor constraintEqualToConstant:68].active=YES;[controls addObject:shortcutSlot];
        NSStackView *line=MHTStack(controls,NO,12);NSView *container=[NSView new];container.identifier=[NSString stringWithFormat:@"MHT.Feature.%ld",(long)i];MHTFill(line,container,14);[container.heightAnchor constraintEqualToConstant:76].active=YES;
        containers[f[@"id"]]=container;[self.rows addObject:row];
    }
    NSString *collapseKey=[@"MHT.collapsedGroups." stringByAppendingString:self.selected.identifier];
    NSDictionary *collapsed=[NSUserDefaults.standardUserDefaults dictionaryForKey:collapseKey] ?: @{};
    for(NSDictionary *group in self.selected.featureGroups){
        NSStackView *body=MHTStack(@[],YES,0);
        for(NSNumber *featureID in group[@"features"]){NSView *row=containers[featureID];[body addArrangedSubview:row];[row.widthAnchor constraintEqualToAnchor:body.widthAnchor].active=YES;}
        MHTFeatureGroup *section=[[MHTFeatureGroup alloc]initWithGroup:group content:body];section.collapsed=[collapsed[group[@"id"]] boolValue];
        section.collapseChanged=^(BOOL value){NSMutableDictionary *saved=[[NSUserDefaults.standardUserDefaults dictionaryForKey:collapseKey] mutableCopy] ?: [NSMutableDictionary new];saved[group[@"id"]]=@(value);[NSUserDefaults.standardUserDefaults setObject:saved forKey:collapseKey];};
        [self.featureList addArrangedSubview:section];[section.widthAnchor constraintEqualToAnchor:self.featureList.widthAnchor].active=YES;[self.groups addObject:section];
    }
    self.status=MHTLabel(@"",11,NSFontWeightRegular);self.status.textColor=NSColor.secondaryLabelColor;
    self.showOverlay=button(@"Trainer öffnen",self,@selector(showOverlay:));self.showOverlay.controlSize=NSControlSizeSmall;self.showOverlay.image=[NSImage imageWithSystemSymbolName:@"rectangle.on.rectangle" accessibilityDescription:nil];self.showOverlay.imagePosition=NSImageLeading;
    self.allOff=button(@"Alles aus",self,@selector(disableAll:));self.allOff.controlSize=NSControlSizeSmall;
    NSStackView *footer=MHTStack(@[self.status,MHTSpacer(),self.showOverlay,self.allOff],NO,12);[self.detail addArrangedSubview:footer];[footer.widthAnchor constraintEqualToAnchor:self.detail.widthAnchor].active=YES;[self.status setContentCompressionResistancePriority:249 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self refreshInstallation];[self updateRows];[self updateTrainerSummary];
}
- (void)toggleGroups:(id)sender {
    (void)sender;BOOL collapse=NO;for(MHTFeatureGroup *group in self.groups)if(!group.collapsed)collapse=YES;
    for(MHTFeatureGroup *group in self.groups)if(group.collapsed!=collapse)[group.header performClick:nil];
}
- (void)stepValue:(NSStepper *)sender {
    MHTRow *row=self.rows[sender.tag];row.value.doubleValue=sender.doubleValue;[self valueChanged:row.value];
}
- (void)profileChanged:(id)sender {
    (void)sender;[NSUserDefaults.standardUserDefaults setObject:self.profile[@"id"] forKey:[@"MHT.profile." stringByAppendingString:self.selected.identifier]];[self refreshInstallation];
}
- (void)discoverInstallations {
    [self.discoveryQueue cancelAllOperations];NSArray *modules=self.modules;
    NSBlockOperation *operation=[NSBlockOperation new];__weak NSBlockOperation *weakOperation=operation;__weak MHTApp *weakSelf=self;
    [operation addExecutionBlock:^{@autoreleasepool {
        NSBlockOperation *work=weakOperation;if(!work || work.cancelled)return;
        NSDictionary *found=MHTFindInstallations(modules,^BOOL{return work.cancelled;});
        if(work.cancelled)return;
        dispatch_async(dispatch_get_main_queue(),^{
            MHTApp *app=weakSelf;if(!app || work.cancelled || app.modules!=modules)return;
            if(MHTApplyInstallations(modules,found)){
                MHTResetGameIcons();[app filter:nil];[app refreshInstallation];[app.table reloadData];
                [app.trainerSettings reloadModules:modules];
            }
        });
    }}];[self.discoveryQueue addOperation:operation];
}
- (NSSet<NSString *> *)protectedRuntimePaths {
    NSMutableSet *paths=[NSMutableSet new];for(MHTSession *session in self.sessions.allValues)if((session.launching || session.running) && session.runtimePath.length)[paths addObject:session.runtimePath];return paths;
}
- (void)updateTrainerSummary {
    NSUInteger updates=0,migrations=0;for(MHTModule *module in self.modules){migrations+=module.packageMigrationAvailable;updates+=module.updateAvailable && !module.packageMigrationAvailable;}
    self.trainerUpdates.title=updates ? [NSString stringWithFormat:@"%lu Trainerupdates verfügbar …",(unsigned long)updates] : migrations ? [NSString stringWithFormat:@"%lu GitHub-Pakete verfügbar …",(unsigned long)migrations] : @"Trainer laden & verwalten …";
    self.trainerUpdates.contentTintColor=updates || migrations ? NSColor.systemCyanColor : nil;
    MHTModule *module=self.selected;if(!module)return;
    BOOL busy=[self.trainerStore.installingIdentifiers containsObject:module.identifier];
    if(busy)[self.trainerProgress startAnimation:nil];else [self.trainerProgress stopAnimation:nil];
    self.trainerVersionLabel.stringValue=busy ? @"Trainer wird geladen und geprüft …" : !module.installed ? @"Trainer noch nicht geladen" : module.packageMigrationAvailable ? [NSString stringWithFormat:@"Trainer %@ · GitHub-Paket zur Übernahme verfügbar",module.version] : module.updateAvailable ? [NSString stringWithFormat:@"Trainer %@ · Update %@ verfügbar",module.installationLabel,module.catalogVersion[@"version"]] : [NSString stringWithFormat:@"Trainer %@ · Installiert",module.installationLabel];
    self.trainerVersionLabel.toolTip=self.trainerStore.lastError ? [@"Offline · " stringByAppendingString:self.trainerStore.lastError.localizedDescription] : @"Bisherige Trainerversionen bleiben bei Updates erhalten.";
    self.trainerDownload.hidden=module.installed && !module.updateAvailable && !busy;
    self.trainerDownload.title=busy ? @"Wird geladen …" : module.packageMigrationAvailable ? @"GitHub-Paket laden" : module.installed ? @"Update laden" : @"Trainer laden";
    self.trainerDownload.enabled=!busy && [module.catalogVersion[@"downloadAvailable"] boolValue];
    if(!module.installed){self.start.title=busy ? @"Wird geladen …" : @"Trainer laden";self.start.accessibilityLabel=@"Nur Trainer herunterladen";self.start.toolTip=@"Lädt den Trainer. Das Spiel wird dabei nicht gestartet.";self.start.image=[NSImage imageWithSystemSymbolName:@"arrow.down.circle" accessibilityDescription:nil];}
}
- (void)reloadTrainerModules {
    NSMutableArray *errors=[NSMutableArray new],*modules=[NSMutableArray new];
    for(MHTModule *module in [self.trainerStore modulesWithErrors:errors]){
        MHTSession *session=self.sessions[module.identifier];
        if((session.launching || session.running) && session.module){session.module.catalogVersion=module.catalogVersion;session.module.updateAvailable=module.updateAvailable;[modules addObject:session.module];}
        else [modules addObject:module];
    }
    // A running backend keeps its exact immutable feature catalog even when a
    // catalog refresh or a new download changes the selected disk version.
    for(MHTSession *session in self.sessions.allValues)if((session.launching || session.running) && session.module){BOOL found=NO;for(MHTModule *m in modules)found|=[m.identifier isEqual:session.module.identifier];if(!found)[modules addObject:session.module];}
    self.modules=modules;[self filter:nil];[self updateTrainerSummary];[self refreshInstallation];[self updateRows];[self.trainerSettings reloadModules:self.modules];
    if(errors.count && self.status)self.status.stringValue=[errors componentsJoinedByString:@" · "];
}
- (void)openTrainerLibrary:(id)sender {
    (void)sender;if(!self.trainerLibrary){__weak MHTApp *weakSelf=self;self.trainerLibrary=[[MHTTrainerLibrary alloc]initWithStore:self.trainerStore protectedRuntimePaths:^NSSet<NSString *> *{return [weakSelf protectedRuntimePaths] ?: [NSSet set];}];self.trainerLibrary.didChange=^{[weakSelf reloadTrainerModules];};}
    [self.trainerLibrary reloadForIdentifier:self.selected.identifier];[self.trainerLibrary showWindow:nil];[self.trainerLibrary.window makeKeyAndOrderFront:nil];
}
- (void)checkTrainerUpdates:(id)sender {
    (void)sender;__weak MHTApp *weakSelf=self;
    [self.trainerStore refreshCatalogWithCompletion:^(NSError *error){MHTApp *app=weakSelf;if(!app)return;[app reloadTrainerModules];if(error && app.status)app.status.stringValue=@"Offline · Bereits geladene Trainer bleiben verfügbar.";}];
    [self updateTrainerSummary];
}
- (void)downloadSelectedTrainer:(id)sender {
    (void)sender;MHTModule *module=self.selected;if(!module || [self.trainerStore.installingIdentifiers containsObject:module.identifier])return;
    if(![module.catalogVersion[@"downloadAvailable"] boolValue]){self.status.stringValue=@"Dieser Trainer ist noch nicht zum Download veröffentlicht.";return;}
    NSString *identifier=module.identifier;self.status.stringValue=@"Trainer wird heruntergeladen und geprüft …";__weak MHTApp *weakSelf=self;
    [self.trainerStore installVersion:module.catalogVersion forIdentifier:identifier completion:^(MHTModule *installed,NSError *error){MHTApp *app=weakSelf;if(!app)return;[app reloadTrainerModules];if([app.selected.identifier isEqual:identifier])app.status.stringValue=error.localizedDescription ?: [NSString stringWithFormat:@"Trainer %@ ist bereit. Mit „Spielen“ startest du das Spiel.",installed.version];}];[self updateTrainerSummary];
}
- (void)refreshInstallation {
    self.inspectionGeneration++;[self.inspectionQueue cancelAllOperations];
    if(!self.selected)return;
    MHTModule *module=self.selected;NSDictionary *profile=self.profile;NSString *path=[module pathForProfile:profile];
    self.gameIcon.image=MHTIconAtSize(MHTGameIcon(module,profile),76);
    self.subtitle.stringValue=[NSString stringWithFormat:@"%@ · %@",profile[@"store"],MHTIsInstalled(module,profile) ? @"Installiert" : @"Nicht installiert"];
    NSString *note=profile[@"compatibilityNote"];
    self.compatibilityNoteLabel.stringValue=note ?: @"";self.compatibilityNoteLabel.hidden=!note.length;self.compatibilityNoteLabel.toolTip=note;
    self.pathButton.toolTip=path ?: @"Spiele-App wählen";
    BOOL running=self.session.running || [NSRunningApplication runningApplicationsWithBundleIdentifier:profile[@"bundleIdentifier"]].count>0;
    self.start.title=module.installed ? @"Spielen" : @"Trainer laden";self.start.enabled=NO;self.profiles.enabled=!self.session.launching && !self.session.running;
    if(self.session.launching || running){
        self.status.stringValue=self.session.launching ? @"Spielstart wird angefordert …" : [self live:self.session] ? self.session.state[@"message"] ?: @"Trainer verbunden." : @"Spiel läuft. Warte auf die Trainerverbindung …";
        return;
    }
    if(!module.installed && self.trainerStore){
        self.start.enabled=![self.trainerStore.installingIdentifiers containsObject:module.identifier] && [module.catalogVersion[@"downloadAvailable"] boolValue];
        self.status.stringValue=self.start.enabled ? @"Trainer laden · Das Spiel wird dabei nicht gestartet." : @"Dieser Trainer ist noch nicht zum Download veröffentlicht.";[self updateTrainerSummary];return;
    }
    self.status.stringValue=@"Spiel-Build wird geprüft …";
    NSUInteger generation=self.inspectionGeneration;
    NSBlockOperation *operation=[NSBlockOperation new];__weak NSBlockOperation *weakOperation=operation;__weak MHTApp *weakSelf=self;
    [operation addExecutionBlock:^{@autoreleasepool {
        NSBlockOperation *work=weakOperation;if(!work || work.cancelled)return;
        NSError *error=nil;NSDictionary *game=nil;MHTModule *compatible=module;
        if(self.trainerStore)compatible=[self.trainerStore moduleForIdentifier:module.identifier profile:profile path:path matchingProfile:NULL game:&game error:&error];
        else game=[module inspectPath:path profile:profile error:&error];
        if(work.cancelled)return;
        dispatch_async(dispatch_get_main_queue(),^{
            MHTApp *app=weakSelf;
            if(!app || work.cancelled || generation!=app.inspectionGeneration || app.selected!=module || ![app.profile isEqual:profile])return;
            BOOL nowRunning=app.session.running || app.session.launching || [NSRunningApplication runningApplicationsWithBundleIdentifier:profile[@"bundleIdentifier"]].count>0;
            app.start.enabled=game && !nowRunning;
            app.status.stringValue=nowRunning ? @"Spiel läuft. Warte auf die Trainerverbindung …" : game ? ![compatible.directory isEqual:module.directory] ? [NSString stringWithFormat:@"Bereit · Passende installierte Trainerversion %@ wird verwendet.",compatible.version] : @"Bereit · geprüfter Spiel-Build. ⌘ ^ öffnet den Trainer im Spiel." : error.localizedDescription ?: @"Bitte Spielpfad wählen.";
        });
    }}];[self.inspectionQueue addOperation:operation];
}
- (void)choosePathForModule:(MHTModule *)module profile:(NSDictionary *)profile completion:(void (^)(void))completion {
    NSOpenPanel *panel=[NSOpenPanel openPanel];panel.allowedContentTypes=@[UTTypeApplicationBundle,UTTypeFolder];panel.canChooseDirectories=YES;panel.canChooseFiles=YES;panel.allowsMultipleSelection=NO;panel.message=[NSString stringWithFormat:@"%@ · %@ · Spiele-App oder Installationsordner wählen",module.name,profile[@"store"]];
    [panel beginSheetModalForWindow:self.settingsWindow.isVisible ? self.settingsWindow : self.window completionHandler:^(NSModalResponse result){
        if(result==NSModalResponseOK){
            NSError *error=nil;
            if([module inspectPath:panel.URL.path profile:profile error:&error]){[module setPath:panel.URL.path forProfile:profile];completion();}
            else {NSAlert *alert=[NSAlert new];alert.messageText=@"Diese Spiele-App passt nicht zum Trainer";alert.informativeText=error.localizedDescription;[alert runModal];}
        }
    }];
}
- (void)chooseSelectedPath:(id)sender {(void)sender;[self choosePathForModule:self.selected profile:self.profile completion:^{[self filter:nil];[self refreshInstallation];[self.table reloadData];}];}
- (void)settingsChanged:(id)sender {
    (void)sender;NSMutableDictionary *options=[self.selected.settings mutableCopy];options[@"liquidGlass"]=@YES;options[@"restore"]=@(self.restore.state==NSControlStateValueOn);[self.selected saveSettings:options];
    if([self live:self.session]){NSMutableDictionary *live=[self.session.options mutableCopy] ?: [options mutableCopy];live[@"liquidGlass"]=options[@"liquidGlass"];self.session.options=live;[self send:@{@"action":@"overlay",@"options":live}];}
}
- (void)startGame:(id)sender {
    (void)sender;if(!self.selected || self.session.launching)return;
    if(self.session.running){self.status.stringValue=@"Das ausgewählte Spiel läuft bereits.";return;}
    if(!self.selected.installed){[self downloadSelectedTrainer:sender];return;}
    MHTModule *module=self.selected;NSDictionary *profile=self.profile;NSError *error=nil;
    NSString *path=[module pathForProfile:profile];
    NSDictionary *game=nil;
    if(self.trainerStore){NSDictionary *matchingProfile=nil;MHTModule *compatible=[self.trainerStore moduleForIdentifier:module.identifier profile:profile path:path matchingProfile:&matchingProfile game:&game error:&error];
        if(!compatible){self.status.stringValue=error.localizedDescription ?: @"Keine installierte Trainerversion passt zu diesem Spiel-Build.";return;}
        profile=matchingProfile;module=compatible;
        if(!profile){self.status.stringValue=@"Das Storeprofil fehlt in dieser Trainerversion.";return;}
        if(![self.selected.directory isEqual:module.directory] && ![self.trainerStore selectModule:module error:&error]){self.status.stringValue=error.localizedDescription;return;}
        // Resolver instances are freshly validated even for the same disk path.
        // Bind displayed rows and all subsequent readback to that exact instance.
        self.selected=module;[NSUserDefaults.standardUserDefaults setObject:profile[@"id"] forKey:[@"MHT.profile." stringByAppendingString:module.identifier]];[self renderDetail];
    }
    if(!self.trainerStore)game=[module inspectPath:path profile:profile error:&error];
    if(!game){self.status.stringValue=error.localizedDescription;return;}
    if(MTExecutableIsRunning(game[@"executable"])){self.status.stringValue=@"Bitte die laufende Spielinstanz regulär beenden.";return;}
    for(NSRunningApplication *running in NSWorkspace.sharedWorkspace.runningApplications)
        for(NSDictionary *p in module.profiles)if([running.bundleIdentifier isEqual:p[@"bundleIdentifier"]] || [running.bundleURL.URLByResolvingSymlinksInPath.path isEqual:game[@"path"]]){self.status.stringValue=@"Bitte die laufende Spielinstanz regulär beenden.";return;}
    if([profile[@"store"] isEqual:@"Steam"] && ![NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.valvesoftware.steam"].count){self.status.stringValue=@"Bitte Steam öffnen und dann erneut starten.";return;}
    if(![NSFileManager.defaultManager isReadableFileAtPath:module.runtimePath]){self.status.stringValue=@"Die Trainerbibliothek fehlt. Bitte diese Trainerversion erneut herunterladen.";return;}
    MHTSession *session=[MHTSession new];session.module=module;session.runtimePath=module.runtimePath;session.token=NSUUID.UUID.UUIDString;session.profile=profile;session.launching=YES;session.startedAt=NSDate.date.timeIntervalSince1970;
    NSMutableDictionary *options=[module.settings mutableCopy];options[@"visible"]=@NO;session.options=options;self.sessions[module.identifier]=session;
    if([profile[@"launchMode"] isEqual:@"epic"]){
        [self refreshInstallation];
        [self.epicLauncher launchGame:game profile:profile environment:[module environmentForGame:game profile:profile session:session.token] completion:^(NSRunningApplication *app,NSError *failure){
            if(self.sessions[module.identifier]!=session)return;
            session.launching=NO;session.app=app;session.startedAt=NSDate.date.timeIntervalSince1970;
            if(!app){[self.sessions removeObjectForKey:module.identifier];if(self.selected==module){[self refreshInstallation];self.status.stringValue=failure.localizedDescription ?: @"Epic-Spielstart fehlgeschlagen.";}}
            else if(self.selected==module){[self refreshInstallation];if(failure)self.status.stringValue=failure.localizedDescription;}
        }];
        return;
    }
    if([profile[@"launchMode"] isEqual:@"executable"]){
        NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:game[@"executable"]];task.currentDirectoryURL=[NSURL fileURLWithPath:game[@"workingDirectory"] ?: game[@"path"]];
        NSMutableDictionary *environment=[NSProcessInfo.processInfo.environment mutableCopy];[environment addEntriesFromDictionary:[module environmentForGame:game profile:profile session:session.token]];task.environment=environment;
        task.standardOutput=NSFileHandle.fileHandleWithNullDevice;task.standardError=NSFileHandle.fileHandleWithNullDevice;
        session.task=task;BOOL launched=[task launchAndReturnError:&error];session.launching=NO;
        if(!launched){[self.sessions removeObjectForKey:module.identifier];[self refreshInstallation];self.status.stringValue=error.localizedDescription ?: @"Spielstart fehlgeschlagen.";}
        else [self refreshInstallation];
        return;
    }
    NSWorkspaceOpenConfiguration *config=[NSWorkspaceOpenConfiguration configuration];config.createsNewApplicationInstance=YES;config.activates=YES;config.environment=[module environmentForGame:game profile:profile session:session.token];
    [self refreshInstallation];
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:game[@"path"]] configuration:config completionHandler:^(NSRunningApplication *app,NSError *failure){dispatch_async(dispatch_get_main_queue(),^{
        session.launching=NO;session.app=app;
        if(!app || failure){[self.sessions removeObjectForKey:module.identifier];if(self.selected==module){[self refreshInstallation];self.status.stringValue=failure.localizedDescription ?: @"Spielstart fehlgeschlagen.";}}
        else if(self.selected==module)[self refreshInstallation];
    });}];
}
- (void)send:(NSDictionary *)command {
    MHTSession *s=self.session;if(![self live:s])return;
    NSString *request=NSUUID.UUID.UUIDString;NSMutableDictionary *message=[command mutableCopy];
    [message addEntriesFromDictionary:@{@"version":@1,@"module":self.selected.identifier,@"session":s.token,@"pid":@(s.processIdentifier),@"request":request,@"deadline":@(NSDate.date.timeIntervalSince1970+2),@"context":s.state[@"context"] ?: @0}];
    NSMutableDictionary *pending=[command mutableCopy];pending[@"sentAt"]=@(NSDate.date.timeIntervalSince1970);s.pending[request]=pending;
    MHTPost(MHTCommandNotification,message);[self updateRows];
}
- (void)featureAction:(NSControl *)sender {
    NSDictionary *f=self.selected.features[sender.tag];MHTSession *s=self.session;NSString *key=[f[@"id"] stringValue];
    BOOL wanted=[sender isKindOfClass:MHTGlassToggle.class] && ((MHTGlassToggle *)sender).selectedSegment==1;
    if([self live:s]){
        [self send:[f[@"oneShot"] boolValue] ? @{@"action":@"run",@"feature":f[@"id"]} : @{@"action":@"set",@"feature":f[@"id"],@"wanted":@(wanted)}];
    } else if(!s || !s.running){
        NSMutableDictionary *selection=[self.selected.selection mutableCopy];NSMutableDictionary *entry=[selection[key] mutableCopy];entry[@"wanted"]=@(wanted);selection[key]=entry;[self.selected saveSelection:selection];[self updateRows];
    }
}
- (void)valueChanged:(NSTextField *)sender {
    NSDictionary *f=self.selected.features[sender.tag];NSNumber *parsed=[sender.objectValue isKindOfClass:NSNumber.class] ? sender.objectValue : nil;double value=parsed ? parsed.doubleValue : NAN;
    if(!isfinite(value) || value<[f[@"minimum"] doubleValue] || value>[f[@"maximum"] doubleValue] || ([f[@"integer"] boolValue] && floor(value)!=value)){
        self.status.stringValue=[NSString stringWithFormat:@"Gültiger Wert: %@ bis %@%@",f[@"minimum"],f[@"maximum"],[f[@"integer"] boolValue] ? @" (ganze Zahl)" : @""];NSBeep();return;
    }
    if([self live:self.session])[self send:@{@"action":@"value",@"feature":f[@"id"],@"value":@(value)}];
    else {NSMutableDictionary *selection=[self.selected.selection mutableCopy];NSString *key=[f[@"id"] stringValue];NSMutableDictionary *entry=[selection[key] mutableCopy];entry[@"value"]=@(value);selection[key]=entry;[self.selected saveSelection:selection];}
}
- (void)showOverlay:(id)sender {(void)sender;NSMutableDictionary *options=[self.session.options mutableCopy];options[@"visible"]=@YES;options[@"mouse"]=@YES;options[@"liquidGlass"]=@YES;self.session.options=options;[self send:@{@"action":@"overlay",@"options":options}];}
- (void)disableAll:(id)sender {
    (void)sender;NSMutableDictionary *selection=[self.selected.selection mutableCopy];for(NSString *key in selection.allKeys){NSMutableDictionary *entry=[selection[key] mutableCopy];entry[@"wanted"]=@NO;selection[key]=entry;}[self.selected saveSelection:selection];
    [self send:@{@"action":@"disableAll"}];[self updateRows];
}
- (void)receive:(NSDictionary *)message {
    if(![message[@"module"] isKindOfClass:NSString.class])return;
    MHTSession *s=self.sessions[message[@"module"]];
    if(!s || !s.running || !MHTMatchesSession(message,message[@"module"],s.token,s.processIdentifier))return;
    NSDictionary *state=message[@"state"];if(![state isKindOfClass:NSDictionary.class] || ![state[@"features"] isKindOfClass:NSArray.class])return;
    MHTModule *module=s.module;
    if([state[@"features"] count]!=module.features.count)return;
    s.state=state;s.receivedAt=NSDate.date.timeIntervalSince1970;
    if([state[@"overlay"] isKindOfClass:NSDictionary.class]){NSMutableDictionary *options=[state[@"overlay"] mutableCopy];options[@"liquidGlass"]=@YES;s.options=options;NSMutableDictionary *settings=[module.settings mutableCopy];[settings addEntriesFromDictionary:options];[module saveSettings:settings];}
    NSString *request=message[@"request"];if([request isKindOfClass:NSString.class] && request.length)[s.pending removeObjectForKey:request];
    if([state[@"selectionWritable"] boolValue]){
        NSMutableDictionary *selection=[NSMutableDictionary new];for(NSDictionary *row in state[@"features"]){if(![row isKindOfClass:NSDictionary.class] || ![row[@"id"] isKindOfClass:NSNumber.class])return;selection[[row[@"id"] stringValue]]=@{@"wanted":row[@"wanted"] ?: @NO,@"value":row[@"value"] ?: @0};}[module saveSelection:selection];
    }
    if(module==self.selected){self.status.stringValue=[message[@"error"] length] ? message[@"error"] : state[@"message"] ?: @"Trainer verbunden.";[self updateRows];}
}
- (void)updateRows {
    if(!self.selected)return;MHTSession *s=self.session;BOOL live=[self live:s],running=s.launching || s.running,installed=self.selected.installed;
    NSDictionary *selection=self.selected.selection;NSArray *states=s.state[@"features"];
    for(NSUInteger i=0;i<self.rows.count;i++){
        MHTRow *row=self.rows[i];NSDictionary *f=self.selected.features[i],*state=live && i<states.count ? states[i] : selection[[f[@"id"] stringValue]];
        BOOL available=live && [s.state[@"ready"] boolValue] && [state[@"available"] boolValue],pending=NO;
        for(NSDictionary *command in s.pending.allValues)if([command[@"feature"] isEqual:f[@"id"]])pending=YES;
        row.run.enabled=installed && [f[@"implemented"] boolValue] && !pending && available;
        row.toggle.enabled=installed && [f[@"implemented"] boolValue] && !pending && (live ? available : !running && ![f[@"oneShot"] boolValue]);
        if(![f[@"oneShot"] boolValue])row.toggle.selectedSegment=[state[@"wanted"] boolValue] ? 1 : 0;
        row.value.enabled=installed && [f[@"implemented"] boolValue] && !pending && (live ? available : !running);
        if(row.value && self.window.firstResponder!=row.value.currentEditor && row.value.doubleValue!=[state[@"value"] doubleValue])row.value.doubleValue=[state[@"value"] doubleValue];
        row.stepper.enabled=row.value.enabled;if(row.value && row.stepper.doubleValue!=row.value.doubleValue)row.stepper.doubleValue=row.value.doubleValue;
        NSString *status=!installed ? @"Trainer laden" : ![f[@"implemented"] boolValue] ? @"Nicht verfügbar" : live ? [state[@"active"] boolValue] ? @"Aktiv" : [state[@"wanted"] boolValue] ? @"Wartet" : @"Aus" : running ? @"Verbinde …" : [state[@"wanted"] boolValue] ? @"Vorgemerkt" : @"Aus";
        if(![row.state.stringValue isEqual:status])row.state.stringValue=status;
        NSColor *color=live && [state[@"active"] boolValue] ? NSColor.systemGreenColor : NSColor.secondaryLabelColor;
        if(![row.state.textColor isEqual:color])row.state.textColor=color;
        NSString *note=live ? state[@"note"] ?: @"" : f[@"detail"] ?: @"";
        if(![row.note.stringValue isEqual:note]){row.note.stringValue=note;row.note.toolTip=note;}
    }
    self.showOverlay.enabled=live;self.allOff.enabled=installed && (live || !running);
}
- (void)tick {
    double now=NSDate.date.timeIntervalSince1970;
    for(NSString *key in self.sessions.allKeys.copy){MHTSession *s=self.sessions[key];
        if(!s.launching && !s.running){[self.sessions removeObjectForKey:key];if([key isEqual:self.selected.identifier]){[self reloadTrainerModules];}}
        for(NSString *request in s.pending.allKeys.copy)if(now-[s.pending[request][@"sentAt"] doubleValue]>3){[s.pending removeObjectForKey:request];if([key isEqual:self.selected.identifier])self.status.stringValue=@"Keine Bestätigung. Einmalaktionen werden nicht automatisch wiederholt.";}
    }
    MHTSession *s=self.session;if(s.running && ![self live:s] && now-s.startedAt>10)self.status.stringValue=@"Trainerverbindung fehlt. Spiel regulär beenden und mit TrainerDock neu starten.";
    if(s)[self updateRows];
}
- (void)rescan:(id)sender {(void)sender;MHTResetGameIcons();[self reloadTrainerModules];[self discoverInstallations];[self checkTrainerUpdates:nil];}
- (void)openSettings:(id)sender {
    (void)sender;
    if(!self.trainerSettings){
        self.trainerSettings=[[MHTTrainerSettings alloc]initWithModules:self.modules];self.settingsWindow=self.trainerSettings.window;
        __weak MHTApp *weakSelf=self;
        self.trainerSettings.choosePath=^(MHTModule *module,NSDictionary *profile,dispatch_block_t completion){
            [weakSelf choosePathForModule:module profile:profile completion:^{
                MHTResetGameIcons();[weakSelf filter:nil];[weakSelf refreshInstallation];[weakSelf.table reloadData];completion();
            }];
        };
    }
    [self.trainerSettings reloadModules:self.modules];[self.trainerSettings showWindow:nil];
    [self.settingsWindow makeKeyAndOrderFront:nil];
}
- (void)showLibrary:(id)sender {
    (void)sender;[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application{(void)application;for(MHTSession *s in self.sessions.allValues)if(s.launching || s.running)return NO;return YES;}
- (BOOL)hasRunningGames {
    for(MHTSession *session in self.sessions.allValues)if(session.launching || session.running)return YES;
    NSMutableSet *identifiers=[NSMutableSet new];
    for(MHTModule *module in self.modules)for(NSDictionary *profile in module.profiles)if([profile[@"bundleIdentifier"] length])[identifiers addObject:profile[@"bundleIdentifier"]];
    for(NSString *identifier in identifiers)if([NSRunningApplication runningApplicationsWithBundleIdentifier:identifier].count)return YES;
    return NO;
}
- (void)checkForUpdates:(id)sender {[self.updater checkForUpdates:sender];}
- (void)toggleAutomaticChecks:(id)sender {[self.updater toggleAutomaticChecks:sender];}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if(item.action==@selector(checkForUpdates:) || item.action==@selector(toggleAutomaticChecks:))return [self.updater validateUserInterfaceItem:item];
    return YES;
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visible{(void)application;if(!visible)[self.window makeKeyAndOrderFront:nil];return YES;}
- (void)applicationWillTerminate:(NSNotification *)notification{(void)notification;[self.epicLauncher cancelPendingLaunch];[self.timer invalidate];[self.inspectionQueue cancelAllOperations];[self.discoveryQueue cancelAllOperations];if(self.stateObserver)[NSDistributedNotificationCenter.defaultCenter removeObserver:self.stateObserver];if(self.trainerStoreObserver)[NSNotificationCenter.defaultCenter removeObserver:self.trainerStoreObserver];}
@end
