// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
@interface MHTTrainerBackdrop : NSView
@end
// Explicit Aus/Ein commands backed by native glass buttons, never by drawing.
@interface MHTGlassToggle : NSControl
@property(nonatomic) NSInteger selectedSegment;
@end
NSScrollView *MHTTrainerScroll(NSStackView *list);
@interface MHTFeatureGroup : NSView
@property(nonatomic,readonly) NSButton *header;
@property(nonatomic) BOOL collapsed;
@property(nonatomic,copy) void (^collapseChanged)(BOOL collapsed);
- (instancetype)initWithGroup:(NSDictionary *)group content:(NSView *)content;
@end
