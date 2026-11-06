// SPDX-License-Identifier: GPL-3.0-only
#import "MHTAppearance.h"
@interface MHTCardBox : NSBox @end
@implementation MHTCardBox
- (void)updatePixelBorder {
    CGFloat scale=self.window.backingScaleFactor;
    self.borderWidth=1.0/MAX(1,scale);
    self.needsDisplay=YES;
}
- (void)viewDidMoveToWindow {[super viewDidMoveToWindow];[self updatePixelBorder];}
- (void)viewDidChangeBackingProperties {[super viewDidChangeBackingProperties];[self updatePixelBorder];}
@end
NSTextField *MHTLabel(NSString *text,CGFloat size,NSFontWeight weight) {
    NSTextField *v=[NSTextField labelWithString:text ?: @""];v.font=[NSFont systemFontOfSize:size weight:weight];
    v.lineBreakMode=NSLineBreakByTruncatingTail;
    // Long module descriptions yield to the user's window width, never grow it.
    [v setContentCompressionResistancePriority:249 forOrientation:NSLayoutConstraintOrientationHorizontal];
    return v;
}
NSStackView *MHTStack(NSArray<NSView *> *views,BOOL vertical,CGFloat spacing) {
    NSStackView *s=[NSStackView stackViewWithViews:views];s.orientation=vertical ? NSUserInterfaceLayoutOrientationVertical : NSUserInterfaceLayoutOrientationHorizontal;
    s.alignment=vertical ? NSLayoutAttributeLeading : NSLayoutAttributeCenterY;
    if(!vertical)s.distribution=NSStackViewDistributionFill;
    s.spacing=spacing;s.translatesAutoresizingMaskIntoConstraints=NO;return s;
}
void MHTFill(NSView *child,NSView *parent,CGFloat margin) {
    child.translatesAutoresizingMaskIntoConstraints=NO;[parent addSubview:child];
    [NSLayoutConstraint activateConstraints:@[[child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor constant:margin],
        [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:-margin],
        [child.topAnchor constraintEqualToAnchor:parent.topAnchor constant:margin],
        [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor constant:-margin]]];
}
NSBox *MHTCard(NSView *content,CGFloat inset) {
    NSBox *box=[MHTCardBox new];box.boxType=NSBoxCustom;box.titlePosition=NSNoTitle;
    box.cornerRadius=14;box.borderWidth=0.5;
    box.fillColor=NSColor.controlBackgroundColor;box.borderColor=[NSColor.separatorColor colorWithAlphaComponent:0.35];
    box.contentViewMargins=NSZeroSize;box.translatesAutoresizingMaskIntoConstraints=NO;
    MHTFill(content,box.contentView,inset);return box;
}
NSImage *MHTIconAtSize(NSImage *image,CGFloat size) {
    // Preserve all icns/vector representations, selecting them for this point
    // size. Never flatten the cached source to a 1x bitmap or mutate its size.
    NSImage *sizedImage=[image copy];sizedImage.size=NSMakeSize(size,size);return sizedImage;
}
NSImageView *MHTIconView(NSImage *image,CGFloat size,NSString *description) {
    NSImageView *view=[NSImageView new];view.image=MHTIconAtSize(image,size);view.imageScaling=NSImageScaleProportionallyUpOrDown;
    view.translatesAutoresizingMaskIntoConstraints=NO;view.accessibilityLabel=description;
    [NSLayoutConstraint activateConstraints:@[[view.widthAnchor constraintEqualToConstant:size],[view.heightAnchor constraintEqualToConstant:size]]];return view;
}
NSView *MHTSpacer(void) {
    NSView *v=[NSView new];[v setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];return v;
}
NSBox *MHTSeparator(void) {
    NSBox *v=[NSBox new];v.boxType=NSBoxSeparator;return v;
}
