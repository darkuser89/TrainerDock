// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "GameBridge.h"
#import "OverlaySettings.h"
#import "OverlayShortcuts.h"

@interface RE2OverlayRoot : NSView
@property(nonatomic) BOOL panelVisible;
@property(nonatomic, readonly) NSView *panel;
@property(nonatomic, readonly) NSView *badge;
@property(nonatomic, copy) void (^actionHandler)(RE2TrainerAction);
@property(nonatomic, copy) void (^featureHandler)(RE2Feature);
@property(nonatomic, copy) void (^valueHandler)(RE2Feature, double);
@property(nonatomic, copy) void (^optionsChanged)(NSDictionary *);
@property(nonatomic, readonly) NSDictionary *overlayOptions;
@property(nonatomic, readonly) BOOL wantsMouseInteraction;
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version;
- (void)togglePanel:(id)sender;
- (void)updateState:(RE2TrainerState *)state;
- (void)applyOverlayOptions:(NSDictionary *)options;
- (BOOL)handleEvent:(NSEvent *)event;
- (BOOL)handleMouseEvent:(NSEvent *)event;
@end

BOOL RE2OverlayToggleEvent(NSEvent *event);
