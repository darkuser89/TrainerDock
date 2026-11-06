// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "GameBridge.h"
#import "OverlaySettings.h"
#import "OverlayShortcuts.h"

@interface DI2OverlayRoot : NSView
@property(nonatomic) BOOL panelVisible;
// panel is the physical material surface; panelContent uses logical coordinates.
@property(nonatomic, readonly) NSView *panel, *panelContent;
@property(nonatomic, readonly) NSView *badge;
@property(nonatomic, copy) void (^actionHandler)(DI2TrainerAction);
@property(nonatomic, copy) void (^featureHandler)(DI2Feature);
@property(nonatomic, copy) void (^valueHandler)(DI2Feature, double);
@property(nonatomic, copy) void (^optionsChanged)(NSDictionary *);
@property(nonatomic, readonly) NSDictionary *overlayOptions;
@property(nonatomic, readonly) BOOL wantsMouseInteraction;
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version;
- (void)togglePanel:(id)sender;
- (void)updateState:(DI2TrainerState *)state;
- (void)applyOverlayOptions:(NSDictionary *)options;
- (BOOL)handleEvent:(NSEvent *)event;
- (BOOL)handleMouseEvent:(NSEvent *)event;
- (void)toggleMouseInteraction;
- (void)refreshHotkeyLabels;
@end

BOOL DI2OverlayToggleEvent(NSEvent *event);
