// SPDX-License-Identifier: GPL-3.0-only
#import "Overlay.h"
#import "TrainerMaterial.h"
#import "MHTGlassIntensity.h"
#import "MHTHiDPI.h"
#import "MHTOverlayHost.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>

// Keep all geometry manual: the game's window can be resized from its GameThread.
static NSColor *orange(void) { return [NSColor colorWithRed:1 green:0.52 blue:0.18 alpha:1]; }
static NSColor *green(void) { return [NSColor colorWithRed:0.35 green:0.84 blue:0.56 alpha:1]; }
static void label(NSString *value, NSRect box, CGFloat size, NSColor *color, BOOL bold, BOOL wrap) {
    NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];
    style.lineBreakMode=wrap ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail;
    [value drawInRect:MHTPixelAlignedTextRect(box) withAttributes:@{NSFontAttributeName:bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size],NSForegroundColorAttributeName:color,NSParagraphStyleAttributeName:style}];
}
static NSString *number(double value, BOOL integer) { return integer ? [NSString stringWithFormat:@"%.0f",value] : [NSString stringWithFormat:@"%.4g",value]; }
@class DI2FeatureRow;
@interface DI2OverlayRoot ()
- (void)activateFeature:(DI2Feature)feature;
- (void)editFeature:(DI2Feature)feature;
- (void)adjustFeature:(DI2Feature)feature direction:(int)direction;
- (void)hoverFeature:(DI2Feature)feature;
- (void)headerClick:(NSPoint)point;
- (void)drawPanel:(NSRect)bounds;
- (void)beginDraggingAt:(NSPoint)point;
- (void)dragTo:(NSPoint)point;
- (void)endDragging;
- (void)refreshPresentation;
@end
@interface DI2FeatureRow : NSView
@property(nonatomic) DI2Feature feature;
@property(nonatomic, weak) DI2OverlayRoot *owner;
@property(nonatomic, strong) DI2FeatureState *state;
@property(nonatomic) BOOL ready;
- (void)updateState:(DI2FeatureState *)state ready:(BOOL)ready;
- (void)invalidateShortcutPresentation;
@end
@implementation DI2FeatureRow {
    BOOL _hasPresentation;
}
- (void)invalidateShortcutPresentation { _hasPresentation=NO; }
- (void)updateState:(DI2FeatureState *)state ready:(BOOL)ready {
    DI2FeatureState *old=self.state;
    BOOL noteChanged=!(old.note==state.note || [old.note isEqualToString:state.note]);
    BOOL changed=!_hasPresentation || self.ready!=ready || old.available!=state.available
        || old.wanted!=state.wanted || old.active!=state.active || old.value!=state.value || noteChanged;
    if(!changed)return;
    BOOL accessibilityChanged=!_hasPresentation || self.ready!=ready
        || old.wanted!=state.wanted || old.active!=state.active;
    const DI2FeatureInfo *info=DI2FeatureInfoAt(self.feature);
    if(!_hasPresentation || noteChanged)
        self.toolTip=[NSString stringWithFormat:@"%@ (%@)\n%@",info->title,DI2HotkeyAt(self.feature).label,state.note ?: info->detail];
    // Copy only presentation values, never retain a mutable bridge object as
    // the row's previous-state comparison. Hidden updates retain only _state.
    DI2FeatureState *snapshot=[DI2FeatureState new];
    snapshot.available=state.available;snapshot.wanted=state.wanted;snapshot.active=state.active;
    snapshot.value=state.value;snapshot.note=state.note;
    self.state=snapshot;self.ready=ready;_hasPresentation=YES;
    if(accessibilityChanged) {
        self.accessibilityLabel=[NSString stringWithFormat:@"%@ · %@ · %@",info->title,DI2HotkeyAt(self.feature).label,
            !info->implemented ? @"nicht verfügbar" : state.active ? @"an" : state.wanted ? @"wartet" : @"aus"];
        self.accessibilityValue=@(state.wanted); self.accessibilityEnabled=ready && info->implemented;
    }
    [self setNeedsDisplay:YES];
}
- (void)resetCursorRects {
    [super resetCursorRects]; if (self.owner.wantsMouseInteraction) [self addCursorRect:self.bounds cursor:NSCursor.arrowCursor];
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { (void)event; return YES; }
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self=[super initWithFrame:frame])) { self.accessibilityElement=YES; self.accessibilityRole=NSAccessibilityCheckBoxRole; }
    return self;
}
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *area in self.trackingAreas.copy) [self removeTrackingArea:area];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways owner:self userInfo:nil]];
}
- (void)mouseEntered:(NSEvent *)event { (void)event; [self.owner hoverFeature:self.feature]; }
- (void)mouseExited:(NSEvent *)event { (void)event; [self.owner hoverFeature:-1]; }
- (void)drawRect:(NSRect)dirty {
    (void)dirty;
    const DI2FeatureInfo *info=DI2FeatureInfoAt(self.feature);
    CGFloat width=self.bounds.size.width, toggle=width-28;
    CGFloat value=width-(self.feature==DI2FeatureMoney ? 105 : 85), valueWidth=self.feature==DI2FeatureMoney ? 63 : 43;
    if (self.feature%2==0) { [[NSColor colorWithWhite:1 alpha:0.025] setFill]; NSRectFillUsingOperation(self.bounds,NSCompositingOperationSourceOver); }
    NSColor *color=info->implemented ? (self.ready ? NSColor.whiteColor : [NSColor colorWithWhite:0.55 alpha:1]) : [NSColor colorWithWhite:0.4 alpha:1];
    label(DI2HotkeyAt(self.feature).label,NSMakeRect(3,4,56,15),8,[NSColor colorWithWhite:0.78 alpha:1],NO,NO);
    label(info->title,NSMakeRect(60,3,(info->numeric ? value-71 : toggle-65),16),10,color,NO,NO);
    if (info->numeric) {
        label(@"−",NSMakeRect(value-11,2,12,16),11,orange(),YES,NO);
        label(number(self.state.value,self.feature==DI2FeatureMoney),NSMakeRect(value,4,valueWidth,15),9.5,orange(),NO,NO);
        label(@"+",NSMakeRect(value+valueWidth+1,2,12,16),11,orange(),YES,NO);
    }
    NSRect pill=NSMakeRect(toggle,4,25,13);
    [(self.state.active ? green() : self.state.wanted ? orange() : [NSColor colorWithWhite:0.22 alpha:1]) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:pill xRadius:6.5 yRadius:6.5] fill];
    if (!info->implemented) label(@"—",NSMakeRect(toggle+7,2,15,15),10,NSColor.grayColor,YES,NO);
    else if (info->oneShot) label(@"GO",NSMakeRect(toggle+4,4,21,12),8,self.ready && self.state.available ? NSColor.whiteColor : NSColor.grayColor,YES,NO);
    else {
        [NSColor.whiteColor setFill];
        NSRect knob=NSMakeRect(toggle+(self.state.wanted ? 14 : 2),6,9,9);
        [[NSBezierPath bezierPathWithOvalInRect:knob] fill];
    }
}
- (void)mouseDown:(NSEvent *)event {
    const DI2FeatureInfo *info=DI2FeatureInfoAt(self.feature);
    if (!info->implemented || !self.ready) return;
    NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];
    CGFloat value=self.bounds.size.width-(self.feature==DI2FeatureMoney ? 105 : 85), valueWidth=self.feature==DI2FeatureMoney ? 63 : 43;
    if (info->numeric && point.x>=value-11 && point.x<value+valueWidth+13) {
        if (point.x<value) [self.owner adjustFeature:self.feature direction:-1];
        else if (point.x>=value+valueWidth+1) [self.owner adjustFeature:self.feature direction:1];
        else [self.owner editFeature:self.feature];
    } else [self.owner activateFeature:self.feature];
}
- (BOOL)accessibilityPerformPress {
    if (!self.ready || !DI2FeatureInfoAt(self.feature)->implemented) return NO;
    dispatch_async(dispatch_get_main_queue(),^{ [self.owner activateFeature:self.feature]; }); return YES;
}
@end
@interface DI2OverlaySurface : NSView
@property(nonatomic, weak) DI2OverlayRoot *owner;
@end
@implementation DI2OverlaySurface
- (void)resetCursorRects {
    [super resetCursorRects]; if (self.owner.wantsMouseInteraction) [self addCursorRect:self.bounds cursor:NSCursor.arrowCursor];
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { (void)event; return YES; }
- (void)drawRect:(NSRect)dirty { (void)dirty; [self.owner drawPanel:self.bounds]; }
- (void)mouseDown:(NSEvent *)event {
    NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];
    if (point.y<=25 && point.x<431) [self.owner beginDraggingAt:[self.owner convertPoint:event.locationInWindow fromView:nil]];
    else [self.owner headerClick:point];
}
- (void)mouseDragged:(NSEvent *)event { [self.owner dragTo:[self.owner convertPoint:event.locationInWindow fromView:nil]]; }
- (void)mouseUp:(NSEvent *)event { (void)event; [self.owner endDragging]; }
@end
@interface DI2OverlayBadge : NSView
@property(nonatomic, weak) DI2OverlayRoot *owner;
@end
@implementation DI2OverlayBadge
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (void)drawRect:(NSRect)dirty {
    (void)dirty; [[NSColor colorWithWhite:0.08 alpha:0.93] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:5 yRadius:5] fill];
    label([@"DI2 · " stringByAppendingString:DI2HotkeyAt(DI2HotkeyPanel).label],NSMakeRect(8,4,82,16),9,orange(),YES,NO);
}
- (void)mouseDown:(NSEvent *)event { (void)event; [self.owner togglePanel:nil]; }
- (BOOL)accessibilityPerformPress { dispatch_async(dispatch_get_main_queue(),^{ [self.owner togglePanel:nil]; }); return YES; }
@end
@implementation DI2OverlayRoot {
    DI2OverlaySurface *_panel;
    DI2TrainerMaterial *_material;
    DI2OverlayBadge *_badge;
    NSArray<DI2FeatureRow *> *_rows;
    DI2TrainerState *_state;
    NSString *_gameVersion, *_editText;
    NSInteger _editingFeature, _hover;
    BOOL _folded, _selectAll;
    CGFloat _scale;
    NSDictionary *_options;
    MHTGlassSlider *_glassSlider;
    BOOL _dragging, _dragMoved;
    __weak NSView *_mouseTarget;
    BOOL _mouseSequence;
    NSPoint _dragStart, _dragOrigin;
    NSString *_lastStatus, *_lastDetail;
    NSNumber *_lastCash;
    NSUInteger _lastActiveCount;
    BOOL _hasPresentation, _lastMouseActive;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (BOOL)acceptsFirstResponder { return NO; }
- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];self.needsLayout=YES;
    MHTInvalidateDrawing(_panel);MHTInvalidateDrawing(_badge);
}
- (NSView *)panel { return _material; }
- (NSView *)panelContent { return _panel; }
- (NSView *)badge { return _badge; }
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version {
    if (!(self=[super initWithFrame:frame])) return nil;
    _gameVersion=version; _editingFeature=-1; _hover=-1; _options=DI2NormalizeOverlayOptions(nil); _scale=0.9;
    self.identifier=@"DI2TrainerOverlay"; self.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    self.wantsLayer=YES; self.layer.backgroundColor=NSColor.clearColor.CGColor; self.layer.zPosition=100000;
    self.accessibilityElement=YES; self.accessibilityRole=NSAccessibilityGroupRole;
    self.accessibilityLabel=[NSString stringWithFormat:@"Dead Island 2 Trainer. %@: Overlay. %@: alle Schalter aus.",DI2HotkeyAt(DI2HotkeyPanel).label,DI2HotkeyAt(DI2HotkeyDisableAll).label];
    _panel=[[DI2OverlaySurface alloc] initWithFrame:NSZeroRect]; _panel.owner=self; _panel.wantsLayer=YES;
    _panel.toolTip=@"Titelleiste ziehen: Overlay verschieben. Beim Verbergen bleiben Cheats aktiv.";
    _material=[[DI2TrainerMaterial alloc]initWithContentView:_panel cornerRadius:14];
    _material.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    [self addSubview:_material];
    NSMutableArray *rows=[NSMutableArray new];
    for (NSInteger i=0;i<DI2FeatureCount;i++) {
        DI2FeatureRow *row=[[DI2FeatureRow alloc] initWithFrame:NSMakeRect(8+(i/13)*266,48+(i%13)*21,258,20)]; row.feature=i; row.owner=self;
        row.toolTip=[NSString stringWithFormat:@"%@ (%@)\n%@",DI2FeatureInfoAt(i)->title,DI2HotkeyAt(i).label,DI2FeatureInfoAt(i)->detail];
        [_panel addSubview:row]; [rows addObject:row];
    }
    _glassSlider=[[MHTGlassSlider alloc]initWithFrame:NSZeroRect];
    __weak DI2OverlayRoot *glassOwner=self;
    _glassSlider.valueChanged=^(double value){
        DI2OverlayRoot *owner=glassOwner;if(!owner)return;
        NSMutableDictionary *options=[owner->_options mutableCopy];options[@"glassIntensity"]=@(value);
        owner->_options=DI2NormalizeOverlayOptions(options);owner->_material.glassIntensity=value;
        [owner notifyOptionsChanged];
    };
    [_panel addSubview:_glassSlider];
    _rows=rows;
    _badge=[[DI2OverlayBadge alloc] initWithFrame:NSMakeRect(12,12,96,24)]; _badge.owner=self;
    _badge.accessibilityElement=YES; _badge.accessibilityRole=NSAccessibilityButtonRole; _badge.accessibilityLabel=@"Trainer einblenden: Befehl und Zirkumflex";
    [self addSubview:_badge]; self.panelVisible=YES; [self updateState:[DI2TrainerState new]]; [self layout]; return self;
}
- (void)layout {
    [super layout];
    CGFloat height=_folded ? 44 : 392;
    CGFloat margin=MIN(12,MAX(0,MIN(self.bounds.size.width,self.bounds.size.height)*0.1));
    CGFloat scale=MAX(0.001,MIN(_scale,MIN(MAX(1,self.bounds.size.width-2*margin)/540,MAX(1,self.bounds.size.height-2*margin)/height)));
    NSPoint unit=NSMakePoint([_options[@"x"] doubleValue],[_options[@"y"] doubleValue]);
    NSString *position=_options[@"position"];
    if (![position isEqualToString:@"free"]) {
        unit.x=[position hasSuffix:@"right"] ? 1 : [position isEqualToString:@"center"] ? 0.5 : 0;
        unit.y=[position hasPrefix:@"bottom"] ? 1 : [position isEqualToString:@"center"] ? 0.5 : 0;
    }
    CGFloat availableX=MAX(0,self.bounds.size.width-2*margin-540*scale),availableY=MAX(0,self.bounds.size.height-2*margin-height*scale);
    _material.frame=MHTPixelAlignedFrame(self,NSMakeRect(margin+unit.x*availableX,margin+unit.y*availableY,540*scale,height*scale));
    _material.bounds=NSMakeRect(0,0,NSWidth(_material.frame),NSHeight(_material.frame));
    _material.logicalContentSize=NSMakeSize(540,height);[_material layout];
    for (NSInteger i=0;i<DI2FeatureCount;i++) {
        if(_rows[i].hidden!=_folded)_rows[i].hidden=_folded;
    }
    _glassSlider.frame=NSMakeRect(_panel.bounds.size.width-210,height-25,198,18);_glassSlider.hidden=_folded;
    _badge.frame=MHTPixelAlignedFrame(self,NSMakeRect(margin+unit.x*MAX(0,self.bounds.size.width-2*margin-96),margin+unit.y*MAX(0,self.bounds.size.height-2*margin-24),96,24));
}
- (void)drawPanel:(NSRect)bounds {
    (void)bounds; // The shared native material owns the background and edge.
    label(@"DEAD ISLAND 2",NSMakeRect(10,7,112,18),12,orange(),YES,NO);
    label(@"TRAINER",NSMakeRect(126,9,55,14),9,NSColor.whiteColor,YES,NO);
    label(@"−",NSMakeRect(438,6,18,19),13,NSColor.whiteColor,YES,NO);
    label(@"+",NSMakeRect(468,6,18,19),13,NSColor.whiteColor,YES,NO);
    label(_folded ? @"▸" : @"▾",NSMakeRect(493,6,18,19),13,NSColor.whiteColor,YES,NO);
    label(@"×",NSMakeRect(519,6,18,19),13,NSColor.whiteColor,YES,NO);
    NSUInteger active=0; for (DI2FeatureState *feature in _state.features) if (feature.active) active++;
    NSString *summary=[NSString stringWithFormat:@"%@ · %@ · %lu aktiv · Geld %@ | %@ +1.000 · %@ +10.000 · %@ aus",_gameVersion,_state.status,(unsigned long)active,_state.cash ?: @"—",DI2HotkeyAt(DI2HotkeyCash1000).label,DI2HotkeyAt(DI2HotkeyCash10000).label,DI2HotkeyAt(DI2HotkeyDisableAll).label];
    label(summary,NSMakeRect(10,27,520,15),9,[NSColor colorWithWhite:0.82 alpha:1],NO,NO);
    if (_folded) return;
    [[NSColor colorWithWhite:1 alpha:0.1] setFill]; NSRectFillUsingOperation(MHTOnePixelVerticalRect(NSMakeRect(270,47,0.5,272)),NSCompositingOperationSourceOver);
    if (_editingFeature>=0) {
        label([NSString stringWithFormat:@"%@ = %@▏  · Enter übernehmen · Esc abbrechen",DI2FeatureInfoAt(_editingFeature)->title,_editText],NSMakeRect(10,326,520,31),10,orange(),YES,YES);
    } else {
        NSString *detail=_hover>=0 ? _state.features[_hover].note : _state.message;
        label(detail ?: @"",NSMakeRect(10,326,520,27),9.5,[NSColor colorWithWhite:0.79 alpha:1],NO,YES);
    }
    NSString *mouseState=!self.wantsMouseInteraction ? @"Spiel" : _state.overlayMouseActive ? @"frei" : @"wartet";
    label([NSString stringWithFormat:@"%@ Overlay · %@ Maus %@ · Esc schließen · Titelleiste ziehen · v0.6.9",DI2HotkeyAt(DI2HotkeyPanel).label,DI2HotkeyAt(DI2HotkeyMouse).label,mouseState],NSMakeRect(10,354,520,12),8,[NSColor colorWithWhite:0.78 alpha:1],NO,NO);
}
- (void)headerClick:(NSPoint)point {
    if (point.y>25) return;
    if (point.x>=512) [self togglePanel:nil];
    else if (point.x>=486) { _folded=!_folded; [self layout]; }
    else if (point.x>=461) { _scale=MIN(1.3,_scale+0.1); [self layout]; [self notifyOptionsChanged]; }
    else if (point.x>=431) { _scale=MAX(0.7,_scale-0.1); [self layout]; [self notifyOptionsChanged]; }
    [_panel setNeedsDisplay:YES];
}
- (void)setPanelVisible:(BOOL)visible {
    _panelVisible=visible; _material.hidden=!visible; _badge.hidden=visible || ![_options[@"badge"] boolValue];
    if (!visible) { _editingFeature=-1; _dragging=NO; }
    else {[self refreshPresentation];[_panel setNeedsDisplay:YES];}
    [self setNeedsDisplay:YES];
    [self.window invalidateCursorRectsForView:_panel];
}
- (BOOL)wantsMouseInteraction { return self.panelVisible && [_options[@"mouse"] boolValue]; }
- (void)togglePanel:(id)sender {
    (void)sender;
    if (!self.panelVisible) {
        NSMutableDictionary *options=[self.overlayOptions mutableCopy];
        options[@"visible"]=@YES; options[@"mouse"]=@YES;
        [self applyOverlayOptions:options];
    } else self.panelVisible=NO;
    [self notifyOptionsChanged];
}
- (void)toggleMouseInteraction {
    NSMutableDictionary *options=[self.overlayOptions mutableCopy]; options[@"mouse"]=@(![_options[@"mouse"] boolValue]);
    [self applyOverlayOptions:options]; [self notifyOptionsChanged];
}
- (NSDictionary *)overlayOptions {
    NSMutableDictionary *result=[_options mutableCopy]; result[@"visible"]=@(self.panelVisible); result[@"scale"]=@(_scale);
    return DI2NormalizeOverlayOptions(result);
}
- (void)applyOverlayOptions:(NSDictionary *)options {
    _options=DI2NormalizeOverlayOptions(options); _material.liquidGlassEnabled=[_options[@"liquidGlass"] boolValue]; _material.glassIntensity=[_options[@"glassIntensity"] doubleValue];_glassSlider.doubleValue=_material.glassIntensity; _scale=[_options[@"scale"] doubleValue];
    _dragging=NO; self.panelVisible=[_options[@"visible"] boolValue]; [self layout];
    [_panel setNeedsDisplay:YES];
}
- (void)notifyOptionsChanged {
    _options=self.overlayOptions;
    if (self.optionsChanged) self.optionsChanged(_options);
}
- (void)beginDraggingAt:(NSPoint)point {
    _dragging=self.panelVisible && [_options[@"draggable"] boolValue]; _dragMoved=NO;
    _dragStart=point; _dragOrigin=_material.frame.origin;
}
- (void)dragTo:(NSPoint)point {
    if (!_dragging) return;
    CGFloat dx=point.x-_dragStart.x,dy=point.y-_dragStart.y;
    if (!_dragMoved && fabs(dx)+fabs(dy)<3) return;
    _dragMoved=YES;
    CGFloat margin=MIN(12,MAX(0,MIN(self.bounds.size.width,self.bounds.size.height)*0.1));
    CGFloat width=MAX(0,self.bounds.size.width-2*margin-_material.frame.size.width);
    CGFloat height=MAX(0,self.bounds.size.height-2*margin-_material.frame.size.height);
    NSMutableDictionary *options=[self.overlayOptions mutableCopy]; options[@"position"]=@"free";
    options[@"x"]=@(width>0 ? MIN(1,MAX(0,(_dragOrigin.x+dx-margin)/width)) : 0);
    options[@"y"]=@(height>0 ? MIN(1,MAX(0,(_dragOrigin.y+dy-margin)/height)) : 0);
    _options=options; [self layout];
}
- (void)endDragging {
    BOOL changed=_dragging && _dragMoved; _dragging=NO; _dragMoved=NO;
    if (changed) [self notifyOptionsChanged];
}
- (void)updateState:(DI2TrainerState *)state {
    _state=state;
    if(self.panelVisible)[self refreshPresentation];
}
- (void)refreshPresentation {
    if(!_state)return;
    DI2TrainerState *state=_state;
    NSUInteger active=0;
    for (NSInteger i=0;i<DI2FeatureCount;i++) {
        [_rows[i] updateState:state.features[i] ready:state.ready];
        if(state.features[i].active)active++;
    }
    NSString *status=state.status ?: @"", *detail=(_hover>=0 ? state.features[_hover].note : state.message) ?: @"";
    if(!_hasPresentation || ![_lastStatus isEqual:status] || ![_lastDetail isEqual:detail]
        || !(_lastCash==state.cash || [_lastCash isEqual:state.cash])
        || _lastActiveCount!=active || _lastMouseActive!=state.overlayMouseActive) {
        _hasPresentation=YES; _lastStatus=[status copy]; _lastDetail=[detail copy];
        _lastCash=[state.cash copy]; _lastActiveCount=active; _lastMouseActive=state.overlayMouseActive;
        [_panel setNeedsDisplay:YES];
    }
}
- (void)hoverFeature:(DI2Feature)feature { _hover=feature; [_panel setNeedsDisplay:YES]; }
- (void)refreshHotkeyLabels {
    for(NSInteger i=0;i<DI2FeatureCount;i++) {
        _rows[i].toolTip=[NSString stringWithFormat:@"%@ (%@)\n%@",DI2FeatureInfoAt(i)->title,DI2HotkeyAt(i).label,DI2FeatureInfoAt(i)->detail];
        [_rows[i] invalidateShortcutPresentation];
    }
    self.accessibilityLabel=[NSString stringWithFormat:@"Dead Island 2 Trainer. %@: Overlay. %@: alle Schalter aus.",DI2HotkeyAt(DI2HotkeyPanel).label,DI2HotkeyAt(DI2HotkeyDisableAll).label];
    [self updateState:_state];[_panel setNeedsDisplay:YES];[_badge setNeedsDisplay:YES];
}
- (void)activateFeature:(DI2Feature)feature {
    const DI2FeatureInfo *info=DI2FeatureInfoAt(feature);
    if (!_state.ready || !info || !info->implemented) return;
    if (self.featureHandler) self.featureHandler(feature);
    else if (self.actionHandler) {
        if (feature==DI2FeatureGod) self.actionHandler(DI2TrainerHealth);
        if (feature==DI2FeatureStamina) self.actionHandler(DI2TrainerStamina);
        if (feature==DI2FeatureAmmo) self.actionHandler(DI2TrainerAmmo);
    }
}
- (void)editFeature:(DI2Feature)feature {
    if (!_state.ready || !DI2FeatureInfoAt(feature)->implemented) return;
    _editingFeature=feature; _editText=number(_state.features[feature].value,feature==DI2FeatureMoney); _selectAll=YES;
    self.panelVisible=YES; _folded=NO; [self layout]; [_panel setNeedsDisplay:YES];
}
- (void)adjustFeature:(DI2Feature)feature direction:(int)direction {
    const DI2FeatureInfo *info=DI2FeatureInfoAt(feature);
    double value=MIN(info->maximum,MAX(info->minimum,_state.features[feature].value+direction*info->step));
    if (self.valueHandler) self.valueHandler(feature,value);
}
- (BOOL)handleEvent:(NSEvent *)event {
    if (DI2OverlayToggleEvent(event)) { [self togglePanel:nil]; return YES; }
    if (event.type!=NSEventTypeKeyDown) return NO;
    if (!event.isARepeat && DI2ShortcutForEvent(event)==DI2ShortcutMouse) { [self toggleMouseInteraction]; return YES; }
    NSEventModifierFlags flags=event.modifierFlags&DI2HotkeyModifierMask();
    NSInteger hotkey=DI2HotkeyForEvent(event);
    if(!event.isARepeat && hotkey==DI2HotkeyDisableAll) {
        _editingFeature=-1;
        if(self.actionHandler)self.actionHandler(DI2TrainerDisableAll);
        [_panel setNeedsDisplay:YES];return YES;
    }
    if (event.keyCode==53 && !flags && _editingFeature<0 && self.wantsMouseInteraction) {
        self.panelVisible=NO; [self notifyOptionsChanged]; return YES;
    }
    if (_editingFeature>=0) {
        if (event.keyCode==53 && !flags) _editingFeature=-1;
        else if ((event.keyCode==36 || event.keyCode==76) && !flags) {
            NSScanner *scanner=[NSScanner scannerWithString:[_editText stringByReplacingOccurrencesOfString:@"," withString:@"."]];
            scanner.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            double value=0; const DI2FeatureInfo *info=DI2FeatureInfoAt(_editingFeature);
            if ([scanner scanDouble:&value] && scanner.isAtEnd && isfinite(value) && value>=info->minimum && value<=info->maximum && (_editingFeature!=DI2FeatureMoney || floor(value)==value)) {
                if (self.valueHandler) self.valueHandler(_editingFeature,value); _editingFeature=-1;
            }
        } else if (flags==NSEventModifierFlagCommand && event.keyCode==0) _selectAll=YES;
        else if (event.keyCode==51 && !flags) { _editText=_selectAll ? @"" : [_editText substringToIndex:_editText.length ? _editText.length-1 : 0]; _selectAll=NO; }
        else if (!(event.modifierFlags & (NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption))) {
            NSString *characters=event.charactersIgnoringModifiers ?: @"";
            if (characters.length && [characters rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789.,"].invertedSet].location==NSNotFound && _editText.length<16) {
                _editText=_selectAll ? characters : [_editText stringByAppendingString:characters]; _selectAll=NO;
            } else return NO;
        } else return NO;
        [_panel setNeedsDisplay:YES]; return YES;
    }
    if (event.isARepeat)return NO;
    if (hotkey==DI2HotkeyCash1000 || hotkey==DI2HotkeyCash10000 || hotkey==DI2HotkeyDisableAll) {
        if ((_state.ready || hotkey==DI2HotkeyDisableAll) && self.actionHandler) self.actionHandler(hotkey==DI2HotkeyCash1000 ? DI2TrainerCash1000 : hotkey==DI2HotkeyCash10000 ? DI2TrainerCash10000 : DI2TrainerDisableAll);
        return YES;
    }
    if(hotkey>=0 && hotkey<DI2FeatureCount) { [self activateFeature:hotkey];return YES; }
    return NO;
}
- (BOOL)handleMouseEvent:(NSEvent *)event {
    event=MHTOverlayMouseEvent(event,self.window);
    if(!event)return NO;
    if (event.type==NSEventTypeLeftMouseDown) {
        _mouseTarget=nil; _mouseSequence=NO;
        NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];
        NSView *target=self.wantsMouseInteraction ? [_material hitTest:point] : nil;
        if (!target && !_badge.hidden) target=[_badge hitTest:point];
        if (!target) return NO;
        _mouseTarget=target; _mouseSequence=YES;
        [target mouseDown:event];
        return YES;
    }
    if (!_mouseSequence || (event.type!=NSEventTypeLeftMouseDragged && event.type!=NSEventTypeLeftMouseUp)) return NO;
    NSView *target=_mouseTarget;
    if (target && !target.isHiddenOrHasHiddenAncestor && [target isDescendantOf:self]
        && (self.wantsMouseInteraction || target==_badge)) {
        if (event.type==NSEventTypeLeftMouseDragged) [target mouseDragged:event];
        else [target mouseUp:event];
    }
    // Consume the complete sequence, even after closing the panel or dragging
    // outside it. The same click must never also fire a weapon in the game.
    if (event.type==NSEventTypeLeftMouseUp) { _mouseTarget=nil; _mouseSequence=NO; }
    return YES;
}
- (NSView *)hitTest:(NSPoint)point {
    NSView *hit=[super hitTest:point];
    if (hit==self || (!self.wantsMouseInteraction && [hit isDescendantOf:_material])) return nil;
    return hit;
}
@end
BOOL DI2OverlayToggleEvent(NSEvent *event) {
    return event.type==NSEventTypeKeyDown && !event.isARepeat && DI2ShortcutForEvent(event)==DI2ShortcutPanel;
}
