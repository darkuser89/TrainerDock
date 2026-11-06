// SPDX-License-Identifier: GPL-3.0-only
// Adapted from Mac Trainer Template 1.1.
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, DI2TrainerMaterialMode) {
    DI2TrainerMaterialOpaque, DI2TrainerMaterialVibrancy, DI2TrainerMaterialLiquidGlass
};

// Background opacity is independent of foreground controls.
@interface DI2TrainerMaterial : NSView
@property(nonatomic,readonly) NSView *contentView;
@property(nonatomic,readonly) DI2TrainerMaterialMode materialMode;
@property(nonatomic) BOOL liquidGlassEnabled;
@property(nonatomic) CGFloat glassIntensity;
@property(nonatomic,copy) NSColor *tintColor;
// Scale the content, never the native glass hosting hierarchy.
@property(nonatomic) NSSize logicalContentSize;
- (instancetype)initWithContentView:(NSView *)content cornerRadius:(CGFloat)radius;
- (void)refreshAppearance;
// Separate policy from rendering so the legacy/accessibility paths are testable.
- (BOOL)allowsLiquidGlass;
- (BOOL)reducesTransparency;
@end
