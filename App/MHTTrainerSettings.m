// SPDX-License-Identifier: GPL-3.0-only
#import "MHTTrainerSettings.h"
#import "MHTAppearance.h"
#import "MHTGameIcons.h"
#import "MHTDiscovery.h"

@interface MHTSettingsDocument : NSView @end
@implementation MHTSettingsDocument
- (BOOL)isFlipped{return YES;}
@end
@interface MHTSettingsClip : NSClipView @end
@implementation MHTSettingsClip
- (BOOL)isFlipped{return YES;}
@end
@interface MHTPathButton : NSButton
@property(nonatomic) MHTModule *trainer;
@property(nonatomic,copy) NSDictionary *profile;
@end
@implementation MHTPathButton @end

@interface MHTTrainerSettings ()
@property(nonatomic) NSArray<MHTModule *> *modules;
@property(nonatomic) NSSearchField *search;
@property(nonatomic) NSTextField *summary;
@property(nonatomic) NSScrollView *scroll;
@property(nonatomic) NSStackView *list;
@end
@implementation MHTTrainerSettings
- (instancetype)initWithModules:(NSArray<MHTModule *> *)modules {
    NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,820,700)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    if((self=[super initWithWindow:window])){
        window.title=@"Trainer & Spielpfade";window.minSize=NSMakeSize(680,500);window.releasedWhenClosed=NO;
        self.modules=modules;
        NSTextField *title=MHTLabel(@"Deine Trainer",23,NSFontWeightBold);
        NSTextField *description=MHTLabel(@"Wähle für jeden Store die passende Spiele-App.",12,NSFontWeightRegular);
        description.textColor=NSColor.secondaryLabelColor;
        NSStackView *titles=MHTStack(@[title,description],YES,5);
        for(NSView *view in @[title,description])[view.widthAnchor constraintEqualToAnchor:titles.widthAnchor].active=YES;
        NSImageView *symbol=MHTIconView([NSImage imageWithSystemSymbolName:@"slider.horizontal.3" accessibilityDescription:nil],36,@"Trainereinstellungen");
        symbol.contentTintColor=NSColor.controlAccentColor;
        NSStackView *heading=MHTStack(@[symbol,titles],NO,14);
        self.summary=MHTLabel(@"",11,NSFontWeightRegular);self.summary.textColor=NSColor.secondaryLabelColor;
        self.search=[NSSearchField new];self.search.placeholderString=@"Trainer suchen";self.search.delegate=self;
        self.search.identifier=@"MHT.Settings.Search";
        [self.search.widthAnchor constraintEqualToConstant:220].active=YES;
        NSStackView *tools=MHTStack(@[self.summary,MHTSpacer(),self.search],NO,14);
        NSStackView *header=MHTStack(@[heading,tools],YES,20);
        for(NSView *view in @[heading,tools])[view.widthAnchor constraintEqualToAnchor:header.widthAnchor].active=YES;
        NSView *headerContainer=[NSView new];MHTFill(header,headerContainer,24);
        self.scroll=[NSScrollView new];self.scroll.hasVerticalScroller=YES;self.scroll.autohidesScrollers=YES;
        self.scroll.drawsBackground=NO;self.scroll.identifier=@"MHT.Settings.Scroll";
        self.scroll.contentView=[MHTSettingsClip new];self.scroll.contentView.drawsBackground=NO;
        MHTSettingsDocument *document=[MHTSettingsDocument new];document.translatesAutoresizingMaskIntoConstraints=NO;
        self.scroll.documentView=document;
        self.list=MHTStack(@[],YES,16);self.list.identifier=@"MHT.Settings.List";MHTFill(self.list,document,24);
        [NSLayoutConstraint activateConstraints:@[
            [document.widthAnchor constraintEqualToAnchor:self.scroll.contentView.widthAnchor],
            [document.leadingAnchor constraintEqualToAnchor:self.scroll.contentView.leadingAnchor],
            [document.topAnchor constraintEqualToAnchor:self.scroll.contentView.topAnchor],
            [document.heightAnchor constraintGreaterThanOrEqualToAnchor:self.scroll.contentView.heightAnchor]]];
        NSTextField *hint=MHTLabel(@"Spielpfade werden automatisch gespeichert.",11,NSFontWeightRegular);hint.textColor=NSColor.secondaryLabelColor;
        NSButton *done=[NSButton buttonWithTitle:@"Fertig" target:self action:@selector(finish:)];done.keyEquivalent=@"\r";
        NSStackView *footer=MHTStack(@[hint,MHTSpacer(),done],NO,12);
        NSView *footerContainer=[NSView new];MHTFill(footer,footerContainer,16);
        NSStackView *body=MHTStack(@[headerContainer,MHTSeparator(),self.scroll,MHTSeparator(),footerContainer],YES,0);
        MHTFill(body,window.contentView,0);
        for(NSView *view in body.arrangedSubviews)[view.widthAnchor constraintEqualToAnchor:body.widthAnchor].active=YES;
        [self.scroll.heightAnchor constraintGreaterThanOrEqualToConstant:180].active=YES;
        [self reloadModules:modules];[window center];
    }return self;
}
- (void)finish:(id)sender{(void)sender;[self.window close];}
- (NSView *)profileRow:(NSDictionary *)profile trainer:(MHTModule *)trainer {
    BOOL installed=MHTIsInstalled(trainer,profile);
    NSTextField *store=MHTLabel(profile[@"store"],12,NSFontWeightSemibold);
    NSTextField *version=MHTLabel([NSString stringWithFormat:@"Version %@",profile[@"gameVersion"] ?: profile[@"version"]],11,NSFontWeightRegular);
    version.textColor=NSColor.secondaryLabelColor;
    NSTextField *state=MHTLabel(installed ? @"Installiert" : @"Pfad fehlt",11,NSFontWeightMedium);
    state.textColor=installed ? NSColor.systemGreenColor : NSColor.secondaryLabelColor;
    NSStackView *metadata=MHTStack(@[store,version,MHTSpacer(),state],NO,10);
    NSString *gamePath=[trainer pathForProfile:profile];
    NSTextField *path=MHTLabel(gamePath.length ? gamePath : @"Noch keine Spiele-App ausgewählt",11,NSFontWeightRegular);
    path.lineBreakMode=NSLineBreakByTruncatingMiddle;path.textColor=NSColor.secondaryLabelColor;path.toolTip=gamePath;
    NSStackView *information=MHTStack(@[metadata,path],YES,7);
    for(NSView *view in @[metadata,path])[view.widthAnchor constraintEqualToAnchor:information.widthAnchor].active=YES;
    MHTPathButton *choose=[MHTPathButton buttonWithTitle:@"Spielpfad wählen …" target:self action:@selector(selectPath:)];
    choose.trainer=trainer;choose.profile=profile;choose.controlSize=NSControlSizeSmall;
    choose.accessibilityLabel=[NSString stringWithFormat:@"%@ · %@: Spielpfad wählen",trainer.name,profile[@"store"]];
    [choose.widthAnchor constraintEqualToConstant:140].active=YES;
    NSStackView *row=MHTStack(@[information,choose],NO,20);
    row.identifier=[@"MHT.Profile." stringByAppendingString:profile[@"id"]];
    return row;
}
- (NSView *)cardForTrainer:(MHTModule *)trainer {
    NSTextField *name=MHTLabel(trainer.name,16,NSFontWeightSemibold);name.toolTip=trainer.name;
    NSString *details=[NSString stringWithFormat:@"%lu Funktionen · %@",(unsigned long)trainer.features.count,trainer.profiles.count==1 ? @"1 Store-Version" : [NSString stringWithFormat:@"%lu Store-Versionen",(unsigned long)trainer.profiles.count]];
    NSTextField *detail=MHTLabel(details,11,NSFontWeightRegular);detail.textColor=NSColor.secondaryLabelColor;
    NSStackView *titles=MHTStack(@[name,detail],YES,4);
    for(NSView *view in @[name,detail])[view.widthAnchor constraintEqualToAnchor:titles.widthAnchor].active=YES;
    NSStackView *heading=MHTStack(@[MHTIconView(MHTGameIcon(trainer,nil),44,trainer.name),titles],NO,12);
    NSStackView *content=MHTStack(@[heading],YES,16);
    [heading.widthAnchor constraintEqualToAnchor:content.widthAnchor].active=YES;
    for(NSDictionary *profile in trainer.profiles){
        NSView *separator=MHTSeparator(),*row=[self profileRow:profile trainer:trainer];
        [content addArrangedSubview:separator];[content addArrangedSubview:row];
        for(NSView *view in @[separator,row])[view.widthAnchor constraintEqualToAnchor:content.widthAnchor].active=YES;
    }
    NSBox *card=MHTCard(content,18);card.identifier=[@"MHT.Trainer." stringByAppendingString:trainer.identifier];return card;
}
- (void)reloadModules:(NSArray<MHTModule *> *)modules {
    self.modules=modules;
    for(NSView *view in self.list.arrangedSubviews.copy){[self.list removeArrangedSubview:view];[view removeFromSuperview];}
    NSString *query=[self.search.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSUInteger shown=0,installed=0;
    for(MHTModule *trainer in modules){
        for(NSDictionary *profile in trainer.profiles)if(MHTIsInstalled(trainer,profile))installed++;
        if(query.length && ![trainer.name localizedStandardContainsString:query])continue;
        NSView *card=[self cardForTrainer:trainer];[self.list addArrangedSubview:card];
        [card.widthAnchor constraintEqualToAnchor:self.list.widthAnchor].active=YES;shown++;
    }
    self.summary.stringValue=query.length ? [NSString stringWithFormat:@"%lu von %lu Trainern",(unsigned long)shown,(unsigned long)modules.count] : [NSString stringWithFormat:@"%lu Trainer · %lu Installationen",(unsigned long)modules.count,(unsigned long)installed];
    if(!shown){
        NSTextField *empty=MHTLabel(@"Keine Trainer gefunden",16,NSFontWeightSemibold);
        NSTextField *hint=MHTLabel(@"Versuche einen anderen Spielnamen.",12,NSFontWeightRegular);hint.textColor=NSColor.secondaryLabelColor;
        [self.list addArrangedSubview:empty];[self.list addArrangedSubview:hint];
    }
    NSView *space=[NSView new];[space setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
    [space.heightAnchor constraintGreaterThanOrEqualToConstant:0].active=YES;[self.list addArrangedSubview:space];
}
- (void)controlTextDidChange:(NSNotification *)notification {
    if(notification.object!=self.search)return;
    [self reloadModules:self.modules];[self.scroll.contentView scrollToPoint:NSZeroPoint];[self.scroll reflectScrolledClipView:self.scroll.contentView];
}
- (void)selectPath:(MHTPathButton *)sender {
    if(!self.choosePath)return;
    __weak MHTTrainerSettings *weakSelf=self;
    self.choosePath(sender.trainer,sender.profile,^{[weakSelf reloadModules:weakSelf.modules];});
}
@end
