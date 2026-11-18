// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "GameBridge.h"
#import "OverlaySettings.h"
#import "OverlayShortcuts.h"

@interface MTOverlayRoot : NSView
@property(nonatomic) BOOL panelVisible;
@property(nonatomic, readonly) NSView *panel;
@property(nonatomic, readonly) NSView *badge;
@property(nonatomic, copy) void (^actionHandler)(MTTrainerAction);
@property(nonatomic, copy) void (^featureHandler)(MTFeature);
@property(nonatomic, copy) void (^valueHandler)(MTFeature, double);
@property(nonatomic, copy) void (^optionsChanged)(NSDictionary *);
@property(nonatomic, readonly) NSDictionary *overlayOptions;
@property(nonatomic, readonly) BOOL wantsMouseInteraction;
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version;
- (void)togglePanel:(id)sender;
- (void)updateState:(MTTrainerState *)state;
- (void)applyOverlayOptions:(NSDictionary *)options;
- (BOOL)handleEvent:(NSEvent *)event;
- (BOOL)handleMouseEvent:(NSEvent *)event;
@end

BOOL MTOverlayToggleEvent(NSEvent *event);
