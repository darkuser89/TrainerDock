// SPDX-License-Identifier: GPL-3.0-only
#import "MHTTrainerViews.h"
#import "MHTAppearance.h"
@interface MHTFeatureDocument : NSView @end
@implementation MHTFeatureDocument
- (BOOL)isFlipped{return YES;}
@end
@interface MHTFeatureClip : NSClipView @end
@implementation MHTFeatureClip
- (BOOL)isFlipped{return YES;}
@end
NSScrollView *MHTTrainerScroll(NSStackView *list) {
    NSScrollView *scroll=[NSScrollView new];scroll.identifier=@"MHT.FeatureScroll";scroll.hasVerticalScroller=YES;
    scroll.autohidesScrollers=YES;scroll.drawsBackground=NO;scroll.translatesAutoresizingMaskIntoConstraints=NO;
    scroll.contentView=[MHTFeatureClip new];scroll.contentView.drawsBackground=NO;
    NSView *document=[MHTFeatureDocument new];document.translatesAutoresizingMaskIntoConstraints=NO;scroll.documentView=document;
    [document addSubview:list];
    [NSLayoutConstraint activateConstraints:@[
        [document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor],
        [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [document.heightAnchor constraintGreaterThanOrEqualToAnchor:scroll.contentView.heightAnchor],
        [list.leadingAnchor constraintEqualToAnchor:document.leadingAnchor],
        [list.trailingAnchor constraintEqualToAnchor:document.trailingAnchor],
        [list.topAnchor constraintEqualToAnchor:document.topAnchor],
        [document.bottomAnchor constraintGreaterThanOrEqualToAnchor:list.bottomAnchor]]];
    // Fit the document to the larger of viewport and natural list height. Do not
    // force the list to fill the viewport: that inflates collapsed group cards.
    [list setContentHuggingPriority:751 forOrientation:NSLayoutConstraintOrientationVertical];
    NSLayoutConstraint *fit=[document.heightAnchor constraintEqualToConstant:0];fit.priority=1;fit.active=YES;
    return scroll;
}
@implementation MHTTrainerBackdrop
- (BOOL)isFlipped{return YES;}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSColor *base=[NSColor colorWithSRGBRed:0.045 green:0.055 blue:0.075 alpha:1];[base setFill];NSRectFill(self.bounds);
    BOOL reduce=NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency;
    CGFloat height=MIN(480,NSHeight(self.bounds));NSRect banner=NSMakeRect(0,0,NSWidth(self.bounds),height);
    if(!reduce){
        NSGradient *ambient=[[NSGradient alloc]initWithStartingColor:[NSColor colorWithSRGBRed:0.11 green:0.12 blue:0.19 alpha:1] endingColor:base];[ambient drawInRect:banner angle:15];
    }
    NSGradient *fade=[[NSGradient alloc]initWithColorsAndLocations:[base colorWithAlphaComponent:0.18],0.0,[base colorWithAlphaComponent:0.55],0.40,base,1.0,nil];
    [fade drawInRect:banner angle:90];
}
@end
@interface MHTGlassToggle ()
@property(nonatomic) NSArray<NSButton *> *buttons;
@property(nonatomic) BOOL hasSelection;
@end
@implementation MHTGlassToggle
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])){
        NSMutableArray *buttons=[NSMutableArray new];
        for(NSString *title in @[@"Aus",@"Ein"]){
            NSButton *button=[NSButton buttonWithTitle:title target:self action:@selector(choose:)];
            [button setButtonType:NSButtonTypePushOnPushOff];button.bezelStyle=NSBezelStyleGlass;
            button.borderShape=NSControlBorderShapeCapsule;button.controlSize=NSControlSizeSmall;
            button.font=[NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
            [button.widthAnchor constraintEqualToConstant:42].active=YES;
            [button.heightAnchor constraintEqualToConstant:30].active=YES;
            [buttons addObject:button];
        }
        self.buttons=buttons;
        NSStackView *stack=MHTStack(buttons,NO,4);
        NSGlassEffectContainerView *container=[NSGlassEffectContainerView new];container.spacing=0;container.contentView=stack;
        MHTFill(container,self,0);self.selectedSegment=0;
        self.accessibilityRole=NSAccessibilityGroupRole;
    }return self;
}
- (NSSize)intrinsicContentSize{return NSMakeSize(88,30);}
- (void)setSelectedSegment:(NSInteger)selectedSegment {
    NSInteger value=selectedSegment==1 ? 1 : 0;
    if(self.hasSelection && _selectedSegment==value)return;
    _selectedSegment=value;self.hasSelection=YES;
    for(NSUInteger i=0;i<self.buttons.count;i++){
        NSButton *button=self.buttons[i];button.state=(NSInteger)i==_selectedSegment ? NSControlStateValueOn : NSControlStateValueOff;
        button.bezelColor=(i==1 && _selectedSegment==1) ? NSColor.systemCyanColor : nil;
    }
}
- (void)setEnabled:(BOOL)enabled {if(self.enabled==enabled)return;[super setEnabled:enabled];for(NSButton *button in self.buttons)button.enabled=enabled;}
- (void)setAccessibilityLabel:(NSString *)label {
    [super setAccessibilityLabel:label];
    for(NSButton *button in self.buttons)button.accessibilityLabel=[NSString stringWithFormat:@"%@: %@",label,button.title];
}
- (void)choose:(NSButton *)sender {
    if(!self.enabled)return;
    self.selectedSegment=sender==self.buttons.lastObject ? 1 : 0;
    // Send the composite control: its tag is the stable native feature ID.
    [self sendAction:self.action to:self.target];
}
@end
@interface MHTFeatureGroup ()
@property(nonatomic) NSButton *header;
@property(nonatomic) NSImageView *chevron;
@property(nonatomic) NSView *body;
@end
@implementation MHTFeatureGroup
- (instancetype)initWithGroup:(NSDictionary *)group content:(NSView *)content {
    if((self=[super initWithFrame:NSZeroRect])){
        self.translatesAutoresizingMaskIntoConstraints=NO;self.identifier=[@"MHT.Group." stringByAppendingString:group[@"id"]];
        _header=[NSButton buttonWithTitle:@"" target:self action:@selector(toggle:)];_header.bordered=NO;_header.accessibilityLabel=group[@"title"];_header.identifier=@"MHT.Group.Toggle";
        NSImage *symbol=[NSImage imageWithSystemSymbolName:group[@"symbol"] accessibilityDescription:nil] ?: [NSImage imageWithSystemSymbolName:@"slider.horizontal.3" accessibilityDescription:nil];
        NSImageView *icon=MHTIconView(symbol,18,group[@"title"]);icon.contentTintColor=NSColor.secondaryLabelColor;
        NSTextField *name=MHTLabel(group[@"title"],14,NSFontWeightSemibold);
        NSTextField *count=MHTLabel([NSString stringWithFormat:@"%lu",(unsigned long)[group[@"features"] count]],11,NSFontWeightMedium);count.textColor=NSColor.secondaryLabelColor;
        _chevron=MHTIconView(nil,12,@"Gruppe auf- oder zuklappen");_chevron.contentTintColor=NSColor.secondaryLabelColor;
        NSStackView *heading=MHTStack(@[icon,name,count,MHTSpacer(),_chevron],NO,10);
        // Labels are siblings of the full-width button, so the entire heading is clickable.
        NSView *head=[NSView new];MHTFill(heading,head,16);_header.translatesAutoresizingMaskIntoConstraints=NO;[head addSubview:_header positioned:NSWindowAbove relativeTo:nil];
        [NSLayoutConstraint activateConstraints:@[[_header.leadingAnchor constraintEqualToAnchor:head.leadingAnchor],[_header.trailingAnchor constraintEqualToAnchor:head.trailingAnchor],[_header.topAnchor constraintEqualToAnchor:head.topAnchor],[_header.bottomAnchor constraintEqualToAnchor:head.bottomAnchor],[head.heightAnchor constraintEqualToConstant:52]]];
        NSBox *separator=MHTSeparator();_body=MHTStack(@[separator,content],YES,0);
        [separator.widthAnchor constraintEqualToAnchor:_body.widthAnchor].active=YES;[content.widthAnchor constraintEqualToAnchor:_body.widthAnchor].active=YES;
        NSStackView *stack=MHTStack(@[head,_body],YES,0);stack.detachesHiddenViews=YES;
        [head.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;[_body.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;
        NSBox *card=MHTCard(stack,0);card.fillColor=[NSColor colorWithSRGBRed:0.075 green:0.09 blue:0.115 alpha:0.91];MHTFill(card,self,0);
        self.collapsed=NO;
    }return self;
}
- (void)setCollapsed:(BOOL)collapsed {
    _collapsed=collapsed;self.body.hidden=collapsed;
    self.chevron.image=[NSImage imageWithSystemSymbolName:collapsed ? @"chevron.right" : @"chevron.down" accessibilityDescription:nil];
    self.header.accessibilityValue=collapsed ? @"Eingeklappt" : @"Ausgeklappt";
}
- (void)toggle:(id)sender {
    (void)sender;self.collapsed=!self.collapsed;
    [self.window.contentView layoutSubtreeIfNeeded];
    // A shrinking scroll document must not move the clicked heading out of view.
    [self.header scrollRectToVisible:self.header.bounds];
    if(self.collapseChanged)self.collapseChanged(self.collapsed);
}
@end
