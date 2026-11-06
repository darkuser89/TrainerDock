// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, MTTrainerMaterialMode) {
    MTTrainerMaterialOpaque, MTTrainerMaterialVibrancy, MTTrainerMaterialLiquidGlass
};

// Background opacity is independent of foreground controls.
@interface MTTrainerMaterial : NSView
@property(nonatomic,readonly) NSView *contentView;
@property(nonatomic,readonly) MTTrainerMaterialMode materialMode;
// Scale the content, never the native glass hosting hierarchy.
@property(nonatomic) NSSize logicalContentSize;
@property(nonatomic) BOOL liquidGlassEnabled;
@property(nonatomic) CGFloat glassIntensity;
- (instancetype)initWithContentView:(NSView *)content cornerRadius:(CGFloat)radius;
- (void)refreshAppearance;
// Separate policy from rendering so the legacy/accessibility paths are testable.
- (BOOL)allowsLiquidGlass;
- (BOOL)reducesTransparency;
@end
