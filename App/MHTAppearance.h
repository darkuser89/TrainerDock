// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
NSTextField *MHTLabel(NSString *text,CGFloat size,NSFontWeight weight);
NSStackView *MHTStack(NSArray<NSView *> *views,BOOL vertical,CGFloat spacing);
void MHTFill(NSView *child,NSView *parent,CGFloat margin);
NSBox *MHTCard(NSView *content,CGFloat inset);
NSImageView *MHTIconView(NSImage *image,CGFloat size,NSString *description);
NSImage *MHTIconAtSize(NSImage *image,CGFloat size);
NSView *MHTSpacer(void);
NSBox *MHTSeparator(void);
