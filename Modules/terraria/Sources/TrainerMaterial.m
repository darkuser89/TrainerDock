// SPDX-License-Identifier: GPL-3.0-only
#import "TrainerMaterial.h"
#import "MHTHiDPI.h"
#import "MHTGlassIntensity.h"
#import <QuartzCore/QuartzCore.h>

@implementation MTTrainerMaterial {
    NSView *_material;
    NSBox *_opaqueBacking;
    CGFloat _radius;
    id _displayObserver;
}
- (instancetype)initWithContentView:(NSView *)content cornerRadius:(CGFloat)radius {
    if((self=[super initWithFrame:content.frame])) {
        _contentView=content;_radius=radius;_liquidGlassEnabled=YES;_glassIntensity=0.5;
        self.identifier=@"TrainerMaterial";
        [self refreshAppearance];
        __weak MTTrainerMaterial *weakSelf=self;
        _displayObserver=[NSWorkspace.sharedWorkspace.notificationCenter
            addObserverForName:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification object:nil
            queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){(void)event;[weakSelf refreshAppearance];}];
    }return self;
}
- (void)dealloc {if(_displayObserver)[NSWorkspace.sharedWorkspace.notificationCenter removeObserver:_displayObserver];}
- (BOOL)isFlipped {return YES;}
- (BOOL)isOpaque {return NO;}
- (BOOL)allowsLiquidGlass {if(@available(macOS 26.0,*))return self.liquidGlassEnabled;return NO;}
- (void)setLiquidGlassEnabled:(BOOL)enabled {_liquidGlassEnabled=enabled;[self refreshAppearance];}
- (void)setGlassIntensity:(CGFloat)value {
    CGFloat normalized=MHTGlassIntensity(@(value));if(_glassIntensity==normalized)return;
    _glassIntensity=normalized;[self updateGlassIntensity];
}
- (void)updateGlassIntensity {
    BOOL opaque=[self reducesTransparency];
    _material.alphaValue=opaque ? 1 : MIN(1,_glassIntensity*2);
    _opaqueBacking.alphaValue=opaque ? 0 : MAX(0,_glassIntensity*2-1);
}
- (BOOL)reducesTransparency {return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast;}
- (void)refreshAppearance {
    BOOL reduced=[self reducesTransparency];
    MTTrainerMaterialMode mode=reduced ? MTTrainerMaterialOpaque : [self allowsLiquidGlass] ? MTTrainerMaterialLiquidGlass : MTTrainerMaterialVibrancy;
    if(_material && mode==_materialMode){[self updateGlassIntensity];return;}
    if(@available(macOS 26.0,*))if([_material isKindOfClass:NSGlassEffectView.class])((NSGlassEffectView *)_material).contentView=nil;
    [_contentView removeFromSuperview];[_material removeFromSuperview];
    _materialMode=mode;_material=nil;
    if(@available(macOS 26.0,*)) {
        if(mode==MTTrainerMaterialLiquidGlass){
            NSGlassEffectView *glass=[[NSGlassEffectView alloc]initWithFrame:self.bounds];
            glass.cornerRadius=_radius;glass.style=NSGlassEffectViewStyleRegular;
            glass.contentView=[[NSView alloc]initWithFrame:glass.bounds];_material=glass;
        }
    }
    if(!_material || mode!=MTTrainerMaterialLiquidGlass){
        if(mode==MTTrainerMaterialVibrancy){
            NSVisualEffectView *blur=[[NSVisualEffectView alloc]initWithFrame:self.bounds];
            blur.material=NSVisualEffectMaterialHUDWindow;blur.blendingMode=NSVisualEffectBlendingModeWithinWindow;
            blur.state=NSVisualEffectStateActive;_material=blur;
        }else{
            _material=[[NSView alloc]initWithFrame:self.bounds];_material.wantsLayer=YES;
            _material.layer.backgroundColor=[NSColor colorWithWhite:0.09 alpha:1].CGColor;
        }
        _material.wantsLayer=YES;_material.layer.cornerRadius=_radius;_material.layer.masksToBounds=YES;

    }
    _material.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    _contentView.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    [self addSubview:_material positioned:NSWindowBelow relativeTo:nil];
    if(!_opaqueBacking){
        _opaqueBacking=[NSBox new];_opaqueBacking.boxType=NSBoxCustom;_opaqueBacking.titlePosition=NSNoTitle;
        _opaqueBacking.borderWidth=0;_opaqueBacking.borderColor=NSColor.clearColor;_opaqueBacking.cornerRadius=_radius;
        _opaqueBacking.fillColor=[NSColor colorWithWhite:0.09 alpha:1];
    }
    [_opaqueBacking removeFromSuperview];[self addSubview:_opaqueBacking positioned:NSWindowAbove relativeTo:_material];
    [self addSubview:_contentView positioned:NSWindowAbove relativeTo:_opaqueBacking];
    [self updateGlassIntensity];[self layout];
}
- (void)layout {
    [super layout];
    NSRect previousFrame=_contentView.frame,previousBounds=_contentView.bounds;
    _material.frame=self.bounds;_opaqueBacking.frame=self.bounds;_contentView.frame=self.bounds;
    NSSize size=_logicalContentSize.width>0 && _logicalContentSize.height>0 ? _logicalContentSize : _material.bounds.size;
    _contentView.bounds=NSMakeRect(0,0,size.width,size.height);
    if(!NSEqualRects(previousFrame,_contentView.frame) || !NSEqualRects(previousBounds,_contentView.bounds))
        MHTInvalidateDrawing(_contentView);
}
- (NSView *)hitTest:(NSPoint)point {
    // Route directly to existing controls, not the material's private subviews.
    if(self.isHiddenOrHasHiddenAncestor || !NSPointInRect([self convertPoint:point fromView:self.superview],self.bounds))return nil;
    return [_contentView hitTest:[_contentView.superview convertPoint:point fromView:self.superview]];
}
@end
