// SPDX-License-Identifier: GPL-3.0-only
#import "MHTTrainerLibrary.h"
#import "MHTTrainerStore.h"
#import "MHTAppearance.h"
#import "MHTGameIcons.h"
#import "MHTTrainerViews.h"

@interface MHTTrainerLibraryAction : NSButton
@property(nonatomic) MHTModule *module;
@property(nonatomic,copy) NSDictionary *version;
@property(nonatomic,copy) NSString *moduleID;
@end
@implementation MHTTrainerLibraryAction @end

@interface MHTTrainerLibrary ()
@property(nonatomic) MHTTrainerStore *store;
@property(nonatomic,copy) NSSet<NSString *> *(^protectedPaths)(void);
@property(nonatomic) NSArray<MHTModule *> *modules,*visibleModules;
@property(nonatomic,copy) NSString *selectedID;
@property(nonatomic) NSTableView *table;
@property(nonatomic) NSSearchField *search;
@property(nonatomic) NSSegmentedControl *scope;
@property(nonatomic) NSTextField *summary,*status;
@property(nonatomic) NSProgressIndicator *progress;
@property(nonatomic) NSButton *refresh;
@property(nonatomic) NSStackView *detail;
@property(nonatomic) id observer;
@end
@implementation MHTTrainerLibrary
- (instancetype)initWithStore:(MHTTrainerStore *)store protectedRuntimePaths:(NSSet<NSString *> *(^)(void))paths {
    NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1000,680) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    if((self=[super initWithWindow:window])){
        _store=store;_protectedPaths=[paths copy];window.title=@"Trainer laden & verwalten";window.minSize=NSMakeSize(840,540);window.releasedWhenClosed=NO;
        window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];window.backgroundColor=NSColor.windowBackgroundColor;
        [window setFrameAutosaveName:@"TrainerDock.TrainerLibrary"];
        NSView *sidebar=[NSView new];NSGlassEffectView *glass=[NSGlassEffectView new];glass.identifier=@"MHT.TrainerLibrary.Glass";glass.style=NSGlassEffectViewStyleRegular;glass.effectIsInteractive=YES;glass.cornerRadius=18;glass.contentView=sidebar;
        _search=[NSSearchField new];_search.placeholderString=@"Trainer suchen";_search.delegate=self;
        _scope=[NSSegmentedControl segmentedControlWithLabels:@[@"Alle",@"Geladen",@"Updates"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(filter:)];_scope.selectedSegment=0;_scope.controlSize=NSControlSizeSmall;
        NSScrollView *scroll=[NSScrollView new];scroll.hasVerticalScroller=YES;scroll.autohidesScrollers=YES;scroll.drawsBackground=NO;scroll.translatesAutoresizingMaskIntoConstraints=NO;
        _table=[NSTableView new];[_table addTableColumn:[[NSTableColumn alloc]initWithIdentifier:@"trainer"]];_table.headerView=nil;_table.rowHeight=60;_table.intercellSpacing=NSMakeSize(0,4);_table.backgroundColor=NSColor.clearColor;_table.style=NSTableViewStyleSourceList;_table.delegate=self;_table.dataSource=self;scroll.documentView=_table;
        _summary=[NSTextField wrappingLabelWithString:@""];_summary.font=[NSFont systemFontOfSize:11];_summary.textColor=NSColor.secondaryLabelColor;
        NSStackView *left=MHTStack(@[MHTLabel(@"Trainer",22,NSFontWeightBold),_summary,_search,_scope,scroll],YES,12);MHTFill(left,sidebar,16);
        left.distribution=NSStackViewDistributionFill;[scroll setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];scroll.identifier=@"MHT.TrainerLibrary.SidebarScroll";
        for(NSView *v in @[_summary,_search,_scope,scroll])[v.widthAnchor constraintEqualToAnchor:left.widthAnchor].active=YES;
        [glass.widthAnchor constraintEqualToConstant:260].active=YES;[scroll.heightAnchor constraintGreaterThanOrEqualToConstant:180].active=YES;
        _detail=MHTStack(@[],YES,14);NSScrollView *details=MHTTrainerScroll(_detail);
        NSStackView *body=MHTStack(@[glass,details],NO,16);body.alignment=NSLayoutAttributeTop;body.identifier=@"MHT.TrainerLibrary.Body";
        [glass.heightAnchor constraintEqualToAnchor:body.heightAnchor].active=YES;[details.heightAnchor constraintEqualToAnchor:body.heightAnchor].active=YES;
        _progress=[NSProgressIndicator new];_progress.style=NSProgressIndicatorStyleSpinning;_progress.controlSize=NSControlSizeSmall;_progress.displayedWhenStopped=NO;
        _status=MHTLabel(@"",11,NSFontWeightRegular);_status.textColor=NSColor.secondaryLabelColor;
        _refresh=[NSButton buttonWithTitle:@"Nach Trainerupdates suchen" target:self action:@selector(refreshCatalog:)];_refresh.bezelStyle=NSBezelStyleGlass;_refresh.image=[NSImage imageWithSystemSymbolName:@"arrow.clockwise" accessibilityDescription:nil];_refresh.imagePosition=NSImageLeading;
        NSStackView *footer=MHTStack(@[_progress,_status,MHTSpacer(),_refresh],NO,10);
        footer.identifier=@"MHT.TrainerLibrary.Footer";
        // Pin both regions to the window. A vertical gravity-area stack can
        // retain natural list heights and leave the lower half inaccessible.
        NSView *content=window.contentView;[content addSubview:body];[content addSubview:footer];
        [NSLayoutConstraint activateConstraints:@[
            [body.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
            [body.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
            [body.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
            [body.bottomAnchor constraintEqualToAnchor:footer.topAnchor constant:-16],
            [footer.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
            [footer.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
            [footer.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-16],
            [footer.heightAnchor constraintEqualToConstant:32]]];
        __weak MHTTrainerLibrary *weakSelf=self;
        _observer=[NSNotificationCenter.defaultCenter addObserverForName:MHTTrainerStoreDidChangeNotification object:store queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;[weakSelf reloadForIdentifier:weakSelf.selectedID];}];
        [self reloadForIdentifier:nil];[window center];
    }return self;
}
- (void)dealloc {if(_observer)[NSNotificationCenter.defaultCenter removeObserver:_observer];}
- (void)reloadForIdentifier:(NSString *)identifier {
    if(identifier.length)self.selectedID=identifier;self.modules=self.store.modules;[self filter:nil];
    BOOL busy=self.store.refreshing || self.store.installingIdentifiers.count>0;self.refresh.enabled=!self.store.refreshing;
    if(busy)[self.progress startAnimation:nil];else [self.progress stopAnimation:nil];
    if(self.store.refreshing)self.status.stringValue=@"Trainerkatalog wird geprüft …";
    else if(self.store.installingIdentifiers.count)self.status.stringValue=@"Trainer wird geladen und geprüft …";
    else if(self.store.lastError)self.status.stringValue=[@"Offline/Fehler · " stringByAppendingString:self.store.lastError.localizedDescription];
}
- (void)controlTextDidChange:(NSNotification *)notification {if(notification.object==self.search)[self filter:nil];}
- (void)filter:(id)sender {
    (void)sender;NSString *query=self.search.stringValue;NSMutableArray *visible=[NSMutableArray new];NSUInteger installed=0,updates=0,migrations=0;
    for(MHTModule *m in self.modules){BOOL has=m.installed;installed+=has;migrations+=m.packageMigrationAvailable;updates+=m.updateAvailable && !m.packageMigrationAvailable;
        if((self.scope.selectedSegment!=1 || has) && (self.scope.selectedSegment!=2 || m.updateAvailable) && (!query.length || [m.name localizedStandardContainsString:query]))[visible addObject:m];}
    self.summary.stringValue=migrations ? [NSString stringWithFormat:@"%lu geladen · %lu Updates\n%lu GitHub-Pakete zur Übernahme",(unsigned long)installed,(unsigned long)updates,(unsigned long)migrations] : [NSString stringWithFormat:@"%lu geladen · %lu Updates",(unsigned long)installed,(unsigned long)updates];self.visibleModules=visible;[self.table reloadData];
    NSInteger selected=0;for(NSUInteger i=0;i<visible.count;i++)if([[visible[i] identifier] isEqual:self.selectedID])selected=i;
    if(visible.count){self.selectedID=[visible[selected] identifier];[self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:selected] byExtendingSelection:NO];}
    else self.selectedID=nil;
    [self renderDetail];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {(void)tableView;return self.visibleModules.count;}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)tableView;(void)column;MHTModule *m=self.visibleModules[row];BOOL installed=m.installed;
    NSTextField *name=MHTLabel(m.name,12,NSFontWeightSemibold),*state=MHTLabel(m.packageMigrationAvailable?@"GitHub-Paket verfügbar":m.updateAvailable?@"Update verfügbar":installed?@"Trainer geladen":@"Zum Download",10,NSFontWeightRegular);state.textColor=m.updateAvailable?NSColor.systemCyanColor:NSColor.secondaryLabelColor;
    NSStackView *text=MHTStack(@[name,state],YES,4);[name.widthAnchor constraintEqualToAnchor:text.widthAnchor].active=YES;[state.widthAnchor constraintEqualToAnchor:text.widthAnchor].active=YES;
    NSTableCellView *cell=[NSTableCellView new];cell.textField=name;MHTFill(MHTStack(@[MHTIconView(MHTGameIcon(m,nil),36,m.name),text],NO,10),cell,6);return cell;
}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {(void)notification;NSInteger row=self.table.selectedRow;if(row>=0 && row<(NSInteger)self.visibleModules.count){self.selectedID=[self.visibleModules[row] identifier];[self renderDetail];}}
- (MHTTrainerLibraryAction *)action:(NSString *)title selector:(SEL)selector {
    MHTTrainerLibraryAction *button=[MHTTrainerLibraryAction new];button.title=title;button.target=self;button.action=selector;button.bezelStyle=NSBezelStyleGlass;button.controlSize=NSControlSizeSmall;return button;
}
- (BOOL)runningIdentifier:(NSString *)identifier {
    NSSet *paths=self.protectedPaths ? self.protectedPaths() : [NSSet set];
    for(MHTModule *m in [self.store installedVersionsForIdentifier:identifier])if([paths containsObject:m.runtimePath])return YES;return NO;
}
- (void)addDetail:(NSView *)view {[self.detail addArrangedSubview:view];[view.widthAnchor constraintEqualToAnchor:self.detail.widthAnchor].active=YES;}
- (void)renderDetail {
    for(NSView *v in self.detail.arrangedSubviews.copy){[self.detail removeArrangedSubview:v];[v removeFromSuperview];}
    MHTModule *selected=nil;for(MHTModule *m in self.modules)if([m.identifier isEqual:self.selectedID]){selected=m;break;}
    if(!selected){[self addDetail:MHTLabel(@"Kein passender Trainer",20,NSFontWeightSemibold)];[self addDetail:MHTLabel(@"Wähle einen anderen Filter oder lade den Katalog neu.",12,NSFontWeightRegular)];return;}
    NSStackView *heading=MHTStack(@[MHTIconView(MHTGameIcon(selected,nil),48,selected.name),MHTLabel(selected.name,23,NSFontWeightBold)],NO,14);[self addDetail:heading];
    NSTextField *hint=[NSTextField wrappingLabelWithString:selected.packageMigrationAvailable ? @"Dein bisheriger Trainer bleibt erhalten. Das einzeln ladbare GitHub-Paket verwendet dieselbe Versionsnummer." : @"Downloads ergänzen deine installierten Trainer. Bisherige Versionen bleiben erhalten."];hint.textColor=NSColor.secondaryLabelColor;[self addDetail:hint];
    NSArray<MHTModule *> *installed=[self.store installedVersionsForIdentifier:selected.identifier];NSArray<NSDictionary *> *versions=[self.store versionsForIdentifier:selected.identifier];BOOL running=[self runningIdentifier:selected.identifier],busy=[self.store.installingIdentifiers containsObject:selected.identifier];
    [self addDetail:MHTLabel(@"Installierte Versionen",14,NSFontWeightSemibold)];
    if(!installed.count)[self addDetail:MHTLabel(@"Für dieses Spiel ist noch kein Trainer geladen.",12,NSFontWeightRegular)];
    for(MHTModule *m in installed){
        BOOL chosen=[m.directory isEqual:selected.directory];
        NSTextField *title=MHTLabel([NSString stringWithFormat:@"Version %@",m.version],13,NSFontWeightSemibold);title.identifier=@"MHT.TrainerVersion.Title";
        NSTextField *origin=MHTLabel([m.installRevision isEqual:m.version] ? @"GitHub-Paket" : @"Übernommener Trainer",11,NSFontWeightRegular);origin.textColor=NSColor.secondaryLabelColor;
        NSMutableOrderedSet *stores=[NSMutableOrderedSet new];for(NSDictionary *p in m.profiles)[stores addObject:[NSString stringWithFormat:@"%@ · Spiel %@",p[@"store"],p[@"gameVersion"] ?: p[@"version"]]];
        NSTextField *subtitle=MHTLabel([stores.array componentsJoinedByString:@" / "],10,NSFontWeightRegular);subtitle.textColor=NSColor.secondaryLabelColor;subtitle.toolTip=subtitle.stringValue;
        NSStackView *labels=MHTStack(@[title,origin,subtitle],YES,5);[labels setHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        for(NSTextField *label in @[title,origin,subtitle]){[label.widthAnchor constraintEqualToAnchor:labels.widthAnchor].active=YES;label.toolTip=label.stringValue;}
        MHTTrainerLibraryAction *activate=[self action:chosen?@"Ausgewählt":@"Verwenden" selector:@selector(selectVersion:)];activate.module=m;activate.enabled=!chosen && !running && !busy;activate.identifier=@"MHT.TrainerVersion.Select";
        MHTTrainerLibraryAction *remove=[self action:@"Löschen" selector:@selector(removeVersion:)];remove.module=m;remove.contentTintColor=NSColor.systemRedColor;remove.enabled=!busy;remove.identifier=@"MHT.TrainerVersion.Delete";
        for(NSButton *button in @[activate,remove])[button setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        if([(self.protectedPaths ? self.protectedPaths() : [NSSet set]) containsObject:m.runtimePath]){remove.enabled=NO;remove.toolTip=@"Diese Version wird gerade von einem Spiel verwendet.";}
        NSStackView *line=MHTStack(@[labels,activate,remove],NO,10);NSBox *card=MHTCard(line,14);card.identifier=@"MHT.TrainerVersion.Installed";[self addDetail:card];
    }
    [self addDetail:MHTLabel(@"Verfügbare Versionen",14,NSFontWeightSemibold)];
    for(NSDictionary *v in versions){
        BOOL present=NO;for(MHTModule *m in installed)if([m.version isEqual:v[@"version"]] && [m.installRevision isEqual:m.version])present=YES;
        NSTextField *title=MHTLabel([NSString stringWithFormat:@"Version %@",v[@"version"]],13,NSFontWeightSemibold);
        BOOL downloadable=[v[@"downloadAvailable"] boolValue];NSString *state=present?@"Bereits installiert":downloadable?[NSByteCountFormatter stringFromByteCount:[v[@"size"] longLongValue] countStyle:NSByteCountFormatterCountStyleFile]:@"Noch nicht veröffentlicht";
        NSTextField *subtitle=MHTLabel(state,10,NSFontWeightRegular);subtitle.textColor=NSColor.secondaryLabelColor;
        MHTTrainerLibraryAction *load=[self action:present?@"Geladen":busy?@"Wird geladen …":@"Herunterladen" selector:@selector(installVersion:)];load.version=v;load.moduleID=selected.identifier;load.enabled=downloadable&&!present&&!busy;load.identifier=@"MHT.TrainerVersion.Download";
        NSBox *card=MHTCard(MHTStack(@[MHTStack(@[title,subtitle],YES,5),MHTSpacer(),load],NO,10),14);card.identifier=@"MHT.TrainerVersion.Available";[self addDetail:card];
    }
    if(!versions.count)[self addDetail:MHTLabel(@"Keine Downloadversion im aktuellen Katalog.",12,NSFontWeightRegular)];
    if(running)[self addDetail:MHTLabel(@"Spiel läuft · Versionswechsel nach dem regulären Spielende möglich.",11,NSFontWeightRegular)];
}
- (void)refreshCatalog:(id)sender {
    (void)sender;__weak MHTTrainerLibrary *weakSelf=self;
    [self.store refreshCatalogWithCompletion:^(NSError *error){MHTTrainerLibrary *owner=weakSelf;if(!owner)return;owner.status.stringValue=error?[@"Katalog nicht erreichbar · " stringByAppendingString:error.localizedDescription]:@"Trainerkatalog ist aktuell.";[owner reloadForIdentifier:owner.selectedID];if(owner.didChange)owner.didChange();}];
}
- (void)installVersion:(MHTTrainerLibraryAction *)sender {
    self.status.stringValue=@"Trainer wird heruntergeladen und geprüft …";__weak MHTTrainerLibrary *weakSelf=self;
    [self.store installVersion:sender.version forIdentifier:sender.moduleID completion:^(MHTModule *module,NSError *error){MHTTrainerLibrary *owner=weakSelf;if(!owner)return;owner.status.stringValue=error.localizedDescription ?: [NSString stringWithFormat:@"%@ · Version %@ ist bereit.",module.name,module.version];[owner reloadForIdentifier:owner.selectedID];if(owner.didChange)owner.didChange();}];
}
- (void)selectVersion:(MHTTrainerLibraryAction *)sender {
    if([self runningIdentifier:sender.module.identifier]){self.status.stringValue=@"Versionswechsel nach dem regulären Spielende möglich.";return;}
    NSError *error=nil;if([self.store selectModule:sender.module error:&error]){self.status.stringValue=[NSString stringWithFormat:@"Version %@ ausgewählt.",sender.module.version];if(self.didChange)self.didChange();}else self.status.stringValue=error.localizedDescription;
    [self reloadForIdentifier:sender.module.identifier];
}
- (void)removeVersion:(MHTTrainerLibraryAction *)sender {
    NSError *error=nil;NSSet *protected=self.protectedPaths ? self.protectedPaths() : [NSSet set];
    if([self.store removeModule:sender.module protectedRuntimePaths:protected error:&error]){self.status.stringValue=[NSString stringWithFormat:@"Version %@ entfernt. Einstellungen und Spielstände bleiben erhalten.",sender.module.version];if(self.didChange)self.didChange();}else self.status.stringValue=error.localizedDescription;
    [self reloadForIdentifier:sender.module.identifier];
}
@end
