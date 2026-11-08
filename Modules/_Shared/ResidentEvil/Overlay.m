// SPDX-License-Identifier: GPL-3.0-only
#import "Overlay.h"
#import "MHTOverlayHost.h"
#import "TrainerMaterial.h"
#import "MHTGlassIntensity.h"
#import "MHTHiDPI.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>

// Keep all geometry manual: the game's window can be resized from its GameThread.
// Game identity is local to this complete trainer, never the launcher bundle name.
static NSString *gameTitle(void) { return RE2IsRE8Game() ? @"Resident Evil Village" : RE2IsRE7Game() ? @"Resident Evil 7" : RE2IsRE4Game() ? @"Resident Evil 4" : RE2IsRE3Game() ? @"Resident Evil 3" : @"Resident Evil 2"; }
static NSColor *orange(void) { return [NSColor colorWithRed:1 green:0.52 blue:0.18 alpha:1]; }
static NSColor *green(void) { return [NSColor colorWithRed:0.35 green:0.84 blue:0.56 alpha:1]; }
static void label(NSString *value, NSRect box, CGFloat size, NSColor *color, BOOL bold, BOOL wrap) {
    NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];
    style.lineBreakMode=wrap ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail;
    [value drawInRect:MHTPixelAlignedTextRect(box) withAttributes:@{NSFontAttributeName:bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size],NSForegroundColorAttributeName:color,NSParagraphStyleAttributeName:style}];
}
static NSString *number(double value, BOOL integer) { return integer ? [NSString stringWithFormat:@"%.0f",value] : [NSString stringWithFormat:@"%.4g",value]; }
static CGFloat titleWidth(const RE2FeatureInfo *info, CGFloat rowWidth) {
    return info->numeric ? rowWidth-(info->integer ? 105 : 85)-62 : rowWidth-84;
}
static CGFloat rowHeight(const RE2FeatureInfo *info) {
    NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];style.lineBreakMode=NSLineBreakByWordWrapping;
    NSRect text=[info->title boundingRectWithSize:NSMakeSize(titleWidth(info,258),CGFLOAT_MAX)
                                        options:NSStringDrawingUsesLineFragmentOrigin
                                     attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:10],NSParagraphStyleAttributeName:style}];
    return MAX(20,ceil(text.size.height)+6);
}
@class RE2FeatureRow;
@interface RE2OverlayRoot ()
- (void)activateFeature:(RE2Feature)feature;
- (void)editFeature:(RE2Feature)feature;
- (void)adjustFeature:(RE2Feature)feature direction:(int)direction;
- (void)hoverFeature:(RE2Feature)feature;
- (void)headerClick:(NSPoint)point;
- (void)drawPanel:(NSRect)bounds;
- (void)beginDraggingAt:(NSPoint)point;
- (void)dragTo:(NSPoint)point;
- (void)endDragging;
- (void)refreshPresentation;
@end
@interface RE2FeatureRow : NSView
@property(nonatomic) RE2Feature feature;
@property(nonatomic, weak) RE2OverlayRoot *owner;
@property(nonatomic, strong) RE2FeatureState *state;
@property(nonatomic) BOOL ready;
@end
@implementation RE2FeatureRow
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
    const RE2FeatureInfo *info=RE2FeatureInfoAt(self.feature);
    CGFloat width=self.bounds.size.width, toggle=width-28;
    CGFloat value=width-(info->integer ? 105 : 85), valueWidth=info->integer ? 63 : 43;
    CGFloat center=(self.bounds.size.height-20)/2;
    if (self.feature%2==0) { [[NSColor colorWithWhite:1 alpha:0.025] setFill]; NSRectFillUsingOperation(self.bounds,NSCompositingOperationSourceOver); }
    NSColor *color=info->implemented ? (self.ready ? NSColor.whiteColor : [NSColor colorWithWhite:0.55 alpha:1]) : [NSColor colorWithWhite:0.4 alpha:1];
    label(info->shortcut,NSMakeRect(3,center+4,47,15),8.5,[NSColor colorWithWhite:0.78 alpha:1],NO,NO);
    label(info->title,NSMakeRect(51,3,titleWidth(info,width),self.bounds.size.height-6),10,color,NO,YES);
    if (info->numeric) {
        label(@"−",NSMakeRect(value-11,center+2,12,16),11,orange(),YES,NO);
        label(number(self.state.value,info->integer),NSMakeRect(value,center+4,valueWidth,15),9.5,orange(),NO,NO);
        label(@"+",NSMakeRect(value+valueWidth+1,center+2,12,16),11,orange(),YES,NO);
    }
    NSRect pill=NSMakeRect(toggle,center+4,25,13);
    [(self.state.active ? green() : self.state.wanted ? orange() : [NSColor colorWithWhite:0.22 alpha:1]) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:pill xRadius:6.5 yRadius:6.5] fill];
    if (!info->implemented) label(@"—",NSMakeRect(toggle+7,center+2,15,15),10,NSColor.grayColor,YES,NO);
    else if (info->oneShot) label(@"Los",NSMakeRect(toggle+4,center+4,21,12),8,self.ready && self.state.available ? NSColor.whiteColor : NSColor.grayColor,YES,NO);
    else {
        [NSColor.whiteColor setFill];
        NSRect knob=NSMakeRect(toggle+(self.state.wanted ? 14 : 2),center+6,9,9);
        [[NSBezierPath bezierPathWithOvalInRect:knob] fill];
    }
}
- (void)mouseDown:(NSEvent *)event {
    const RE2FeatureInfo *info=RE2FeatureInfoAt(self.feature);
    if (!info->implemented || !self.ready) return;
    NSPoint point=[self convertPoint:event.locationInWindow fromView:nil];
    CGFloat value=self.bounds.size.width-(info->integer ? 105 : 85), valueWidth=info->integer ? 63 : 43;
    if (info->numeric && point.x>=value-11 && point.x<value+valueWidth+13) {
        if (point.x<value) [self.owner adjustFeature:self.feature direction:-1];
        else if (point.x>=value+valueWidth+1) [self.owner adjustFeature:self.feature direction:1];
        else [self.owner editFeature:self.feature];
    } else [self.owner activateFeature:self.feature];
}
- (BOOL)accessibilityPerformPress {
    if (!self.ready || !RE2FeatureInfoAt(self.feature)->implemented) return NO;
    dispatch_async(dispatch_get_main_queue(),^{ [self.owner activateFeature:self.feature]; }); return YES;
}
@end
@interface RE2OverlaySurface : NSView
@property(nonatomic, weak) RE2OverlayRoot *owner;
@end
@implementation RE2OverlaySurface
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
@interface RE2OverlayBadge : NSView
@property(nonatomic, weak) RE2OverlayRoot *owner;
@end
@implementation RE2OverlayBadge
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (void)drawRect:(NSRect)dirty {
    (void)dirty; [[NSColor colorWithWhite:0.08 alpha:0.93] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:5 yRadius:5] fill];
    label([RE2GameShortName() stringByAppendingString:@" · ⌘ ^"],NSMakeRect(8,4,82,16),10,orange(),YES,NO);
}
- (void)mouseDown:(NSEvent *)event { (void)event; [self.owner togglePanel:nil]; }
- (BOOL)accessibilityPerformPress { dispatch_async(dispatch_get_main_queue(),^{ [self.owner togglePanel:nil]; }); return YES; }
@end
@implementation RE2OverlayRoot {
    RE2OverlaySurface *_panel;
    MTTrainerMaterial *_material;
    RE2OverlayBadge *_badge;
    NSArray<RE2FeatureRow *> *_rows;
    RE2TrainerState *_state;
    NSString *_gameVersion, *_editText;
    NSInteger _editingFeature, _hover;
    BOOL _folded, _selectAll;
    CGFloat _scale, _rowsHeight;
    NSDictionary *_options;
    MHTGlassSlider *_glassSlider;
    BOOL _dragging, _dragMoved;
    __weak NSView *_mouseTarget;
    BOOL _mouseSequence;
    NSPoint _dragStart, _dragOrigin;
    CGFloat _rowHeights[RE2FeatureCapacity];
    NSString *_renderedStatus,*_renderedMessage;
    NSUInteger _renderedActive;
    BOOL _renderedMouse,_hasPresentation;
}
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return NO; }
- (BOOL)acceptsFirstResponder { return NO; }
- (void)viewDidChangeBackingProperties {
    [super viewDidChangeBackingProperties];self.needsLayout=YES;
    MHTInvalidateDrawing(_panel);MHTInvalidateDrawing(_badge);
}
- (NSView *)panel { return _material; }
- (NSView *)badge { return _badge; }
- (instancetype)initWithFrame:(NSRect)frame version:(NSString *)version {
    if (!(self=[super initWithFrame:frame])) return nil;
    _gameVersion=version; _editingFeature=-1; _hover=-1; _options=RE2NormalizeOverlayOptions(nil); _scale=0.9;
    self.identifier=@"RE2TrainerOverlay"; self.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    self.wantsLayer=YES; self.layer.backgroundColor=NSColor.clearColor.CGColor; self.layer.zPosition=100000;
    self.accessibilityElement=YES; self.accessibilityRole=NSAccessibilityGroupRole;
    self.accessibilityLabel=[gameTitle() stringByAppendingString:@". Befehl und Zirkumflex: Trainerfenster. ⇧F9: alle Schalter aus."];
    _panel=[[RE2OverlaySurface alloc] initWithFrame:NSZeroRect]; _panel.owner=self; _panel.wantsLayer=YES;
    _panel.toolTip=@"Titelleiste ziehen: Trainerfenster verschieben. ⌘ ^: verbergen/anzeigen; Funktionen bleiben aktiv.";
    _material=[[MTTrainerMaterial alloc]initWithContentView:_panel cornerRadius:14];
    _material.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];[self addSubview:_material];
    NSMutableArray *rows=[NSMutableArray new];
    NSInteger perColumn=(NSInteger)ceil(RE2ActiveFeatureCount()/2.0);CGFloat columnHeights[2]={0,0};
    for (NSInteger i=0;i<RE2ActiveFeatureCount();i++) {
        RE2FeatureRow *row=[[RE2FeatureRow alloc] initWithFrame:NSZeroRect]; row.feature=i; row.owner=self;
        row.toolTip=[NSString stringWithFormat:@"%@ (%@)\n%@",RE2FeatureInfoAt(i)->title,RE2FeatureInfoAt(i)->shortcut,RE2FeatureInfoAt(i)->detail];
        [_panel addSubview:row]; [rows addObject:row];
        _rowHeights[i]=rowHeight(RE2FeatureInfoAt(i));columnHeights[i/perColumn]+=_rowHeights[i]+1;
    }
    _rowsHeight=MAX(columnHeights[0],columnHeights[1]);
    _glassSlider=[[MHTGlassSlider alloc]initWithFrame:NSZeroRect];
    __weak RE2OverlayRoot *glassOwner=self;
    _glassSlider.valueChanged=^(double value){
        RE2OverlayRoot *owner=glassOwner;if(!owner)return;
        NSMutableDictionary *options=[owner->_options mutableCopy];options[@"glassIntensity"]=@(value);
        owner->_options=RE2NormalizeOverlayOptions(options);owner->_material.glassIntensity=value;
        [owner notifyOptionsChanged];
    };
    [_panel addSubview:_glassSlider];
    _rows=rows;
    _badge=[[RE2OverlayBadge alloc] initWithFrame:NSMakeRect(12,12,96,24)]; _badge.owner=self;
    _badge.accessibilityElement=YES; _badge.accessibilityRole=NSAccessibilityButtonRole; _badge.accessibilityLabel=@"Trainer einblenden: Befehl und Zirkumflex";
    [self addSubview:_badge]; self.panelVisible=NO; [self updateState:[RE2TrainerState new]]; [self layout]; return self;
}
- (void)layout {
    [super layout];
    NSInteger perColumn=(NSInteger)ceil(RE2ActiveFeatureCount()/2.0);
    CGFloat height=_folded ? 44 : 157+_rowsHeight;
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
    _material.bounds=NSMakeRect(0,0,_material.frame.size.width,_material.frame.size.height);
    _material.logicalContentSize=NSMakeSize(540,height);[_material layout];
    CGFloat columnY[2]={48,48};
    for (NSInteger i=0;i<RE2ActiveFeatureCount();i++) {
        NSInteger column=i/perColumn;CGFloat h=_rowHeights[i];
        _rows[i].frame=NSMakeRect(8+column*266,columnY[column],258,h); _rows[i].hidden=_folded;
        columnY[column]+=h+1;
    }
    _glassSlider.frame=NSMakeRect(_panel.bounds.size.width-210,height-25,198,18);_glassSlider.hidden=_folded;
    _badge.frame=MHTPixelAlignedFrame(self,NSMakeRect(margin+unit.x*MAX(0,self.bounds.size.width-2*margin-96),margin+unit.y*MAX(0,self.bounds.size.height-2*margin-24),96,24));
}
- (void)drawPanel:(NSRect)bounds {
    (void)bounds; // The native material owns the background and its edge.
    label(gameTitle(),NSMakeRect(10,7,420,18),12,orange(),YES,NO);
    label(@"−",NSMakeRect(438,6,18,19),13,NSColor.whiteColor,YES,NO);
    label(@"+",NSMakeRect(468,6,18,19),13,NSColor.whiteColor,YES,NO);
    label(_folded ? @"▸" : @"▾",NSMakeRect(493,6,18,19),13,NSColor.whiteColor,YES,NO);
    label(@"×",NSMakeRect(519,6,18,19),13,NSColor.whiteColor,YES,NO);
    NSUInteger active=0; for (RE2FeatureState *feature in _state.features) if (feature.active) active++;
    NSString *summary=[NSString stringWithFormat:@"%@ · %@ · %lu aktiv · ⇧F9 alles aus",_gameVersion,_state.status,(unsigned long)active];
    label(summary,NSMakeRect(10,27,520,15),9,[NSColor colorWithWhite:0.82 alpha:1],NO,NO);
    if (_folded) return;
    [[NSColor colorWithWhite:1 alpha:0.1] setFill]; NSRectFillUsingOperation(MHTOnePixelVerticalRect(NSMakeRect(270,47,0.5,_rowsHeight)),NSCompositingOperationSourceOver);
    if (_editingFeature>=0) {
        label([NSString stringWithFormat:@"%@ = %@▏  · Eingabe übernehmen · Esc abbrechen",RE2FeatureInfoAt(_editingFeature)->title,_editText],NSMakeRect(10,54+_rowsHeight,520,42),10,orange(),YES,YES);
    } else {
        NSString *detail=_hover>=0 ? [NSString stringWithFormat:@"%@: %@",RE2FeatureInfoAt(_hover)->title,RE2FeatureInfoAt(_hover)->detail] : _state.message;
        label(detail ?: @"",NSMakeRect(10,54+_rowsHeight,520,42),9.5,[NSColor colorWithWhite:0.79 alpha:1],NO,YES);
    }
    NSString *mouseState=!self.wantsMouseInteraction ? @"Spiel" : _state.overlayMouseActive ? @"frei" : @"wartet";
    label([NSString stringWithFormat:@"⌘ ^ Öffnen / Schließen · Maus automatisch %@ · Esc schließen · %@",mouseState,RE2GameVersionLabel()],NSMakeRect(10,103+_rowsHeight,520,12),8,[NSColor colorWithWhite:0.78 alpha:1],NO,NO);
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
- (BOOL)wantsMouseInteraction { return self.panelVisible; }
- (void)togglePanel:(id)sender { (void)sender; self.panelVisible=!self.panelVisible; [self notifyOptionsChanged]; }
- (NSDictionary *)overlayOptions {
    NSMutableDictionary *result=[_options mutableCopy]; result[@"visible"]=@(self.panelVisible); result[@"scale"]=@(_scale);
    return RE2NormalizeOverlayOptions(result);
}
- (void)applyOverlayOptions:(NSDictionary *)options {
    _options=RE2NormalizeOverlayOptions(options); _material.liquidGlassEnabled=[_options[@"liquidGlass"] boolValue]; _material.glassIntensity=[_options[@"glassIntensity"] doubleValue];_glassSlider.doubleValue=_material.glassIntensity; _scale=[_options[@"scale"] doubleValue];
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
- (void)updateState:(RE2TrainerState *)state {
    _state=state;
    if(self.panelVisible)[self refreshPresentation];
}
- (void)refreshPresentation {
    if(!_state)return;
    RE2TrainerState *state=_state;NSUInteger active=0;
    for (NSInteger i=0;i<RE2ActiveFeatureCount();i++) {
        RE2FeatureRow *row=_rows[i];RE2FeatureState *next=state.features[i],*old=row.state;
        active+=next.active;
        if(old && row.ready==state.ready && old.available==next.available && old.wanted==next.wanted
            && old.active==next.active && old.value==next.value && (old.note==next.note || [old.note isEqualToString:next.note]))continue;
        // Store an independent presentation snapshot, even if a caller mutates
        // its state instance in place. Hidden UI keeps only the latest state.
        RE2FeatureState *copy=[RE2FeatureState new];copy.available=next.available;copy.wanted=next.wanted;
        copy.active=next.active;copy.value=next.value;copy.note=next.note;
        row.state=copy; row.ready=state.ready;
        row.accessibilityLabel=[NSString stringWithFormat:@"%@ · %@ · %@",RE2FeatureInfoAt(i)->title,RE2FeatureInfoAt(i)->shortcut,!RE2FeatureInfoAt(i)->implemented ? @"nicht verfügbar" : row.state.active ? @"an" : row.state.wanted ? @"wartet" : @"aus"];
        row.accessibilityValue=@(row.state.wanted); row.accessibilityEnabled=state.ready && RE2FeatureInfoAt(i)->implemented;
        row.toolTip=[NSString stringWithFormat:@"%@ (%@)\n%@%@",RE2FeatureInfoAt(i)->title,RE2FeatureInfoAt(i)->shortcut,RE2FeatureInfoAt(i)->detail,row.state.wanted && row.state.note.length ? [@"\nStatus: " stringByAppendingString:row.state.note] : @""];
        [row setNeedsDisplay:YES];
    }
    if(!_hasPresentation || _renderedActive!=active || _renderedMouse!=state.overlayMouseActive
        || !(_renderedStatus==state.status || [_renderedStatus isEqualToString:state.status])
        || !(_renderedMessage==state.message || [_renderedMessage isEqualToString:state.message])){
        _hasPresentation=YES;_renderedActive=active;_renderedMouse=state.overlayMouseActive;
        _renderedStatus=[state.status copy];_renderedMessage=[state.message copy];[_panel setNeedsDisplay:YES];
    }
}
- (void)hoverFeature:(RE2Feature)feature { _hover=feature; [_panel setNeedsDisplay:YES]; }
- (void)activateFeature:(RE2Feature)feature {
    const RE2FeatureInfo *info=RE2FeatureInfoAt(feature);
    if (!_state.ready || !info || !info->implemented) return;
    if (self.featureHandler) self.featureHandler(feature);

}
- (void)editFeature:(RE2Feature)feature {
    if (!_state.ready || !RE2FeatureInfoAt(feature)->implemented) return;
    _editingFeature=feature; _editText=number(_state.features[feature].value,RE2FeatureInfoAt(feature)->integer); _selectAll=YES;
    self.panelVisible=YES; _folded=NO; [self layout]; [_panel setNeedsDisplay:YES];
}
- (void)adjustFeature:(RE2Feature)feature direction:(int)direction {
    const RE2FeatureInfo *info=RE2FeatureInfoAt(feature);
    double value=MIN(info->maximum,MAX(info->minimum,_state.features[feature].value+direction*info->step));
    if (self.valueHandler) self.valueHandler(feature,value);
}
- (BOOL)handleEvent:(NSEvent *)event {
    if (RE2OverlayToggleEvent(event)) { [self togglePanel:nil]; return YES; }
    if (event.type!=NSEventTypeKeyDown) return NO;
    if (event.keyCode==53 && _editingFeature<0 && self.wantsMouseInteraction) {
        self.panelVisible=NO; [self notifyOptionsChanged]; return YES;
    }
    if (_editingFeature>=0) {
        if (event.keyCode==53) _editingFeature=-1;
        else if (event.keyCode==36 || event.keyCode==76) {
            NSScanner *scanner=[NSScanner scannerWithString:[_editText stringByReplacingOccurrencesOfString:@"," withString:@"."]];
            scanner.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            double value=0; const RE2FeatureInfo *info=RE2FeatureInfoAt(_editingFeature);
            if ([scanner scanDouble:&value] && scanner.isAtEnd && isfinite(value) && value>=info->minimum && value<=info->maximum && (!info->integer || floor(value)==value)) {
                if (self.valueHandler) self.valueHandler(_editingFeature,value); _editingFeature=-1;
            }
        } else if ((event.modifierFlags & NSEventModifierFlagCommand) && event.keyCode==0) _selectAll=YES;
        else if (event.keyCode==51) { _editText=_selectAll ? @"" : [_editText substringToIndex:_editText.length ? _editText.length-1 : 0]; _selectAll=NO; }
        else if (!(event.modifierFlags & (NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption))) {
            NSString *characters=event.charactersIgnoringModifiers ?: @"";
            if (characters.length && [characters rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789.,"].invertedSet].location==NSNotFound && _editText.length<16) {
                _editText=_selectAll ? characters : [_editText stringByAppendingString:characters]; _selectAll=NO;
            }
        }
        [_panel setNeedsDisplay:YES]; return YES;
    }
    if (event.isARepeat || (event.modifierFlags & (NSEventModifierFlagCommand|NSEventModifierFlagControl))) return NO;
    NSUInteger modifiers=((event.modifierFlags & NSEventModifierFlagShift) ? 1 : 0) | ((event.modifierFlags & NSEventModifierFlagOption) ? 2 : 0);
    if (modifiers==1 && event.keyCode==101) { if (self.actionHandler) self.actionHandler(RE2TrainerDisableAll); return YES; }
    for (NSInteger i=0;i<RE2ActiveFeatureCount();i++) {
        const RE2FeatureInfo *info=RE2FeatureInfoAt(i);
        if (event.keyCode==info->key && modifiers==info->modifiers) { [self activateFeature:i]; return YES; }
    }
    return NO;
}
- (BOOL)handleMouseEvent:(NSEvent *)event {
    event=MHTOverlayMouseEvent(event,self.window);
    if (!event) return NO;
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
    if (hit==self || (!self.wantsMouseInteraction && [hit isDescendantOf:_panel])) return nil;
    return hit;
}
@end
BOOL RE2OverlayToggleEvent(NSEvent *event) {
    return event.type==NSEventTypeKeyDown && !event.isARepeat && RE2ShortcutForEvent(event)==RE2ShortcutPanel;
}
