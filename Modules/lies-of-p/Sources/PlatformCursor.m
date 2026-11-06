// SPDX-License-Identifier: GPL-3.0-only
#import "PlatformCursor.h"
static BOOL sameOwner(MTPlatformCursorState a,MTPlatformCursorState b) {
    return a.application && a.cursor && a.reference && a.application==b.application && a.cursor==b.cursor && a.reference==b.reference;
}
@implementation MTPlatformCursorLease {
    MTPlatformCursorState (^_read)(void);
    BOOL (^_apply)(MTPlatformCursorState,MTPlatformCursorOperation,int32_t);
    MTPlatformCursorState _original;
    BOOL _owned,_conflicted;
}
- (instancetype)initWithRead:(MTPlatformCursorState (^)(void))read apply:(BOOL (^)(MTPlatformCursorState,MTPlatformCursorOperation,int32_t))apply {
    if((self=[super init])){_read=[read copy];_apply=[apply copy];}return self;
}
- (BOOL)show {
    if(_conflicted)return NO;
    MTPlatformCursorState current=_read();
    if(_owned && !sameOwner(_original,current)){[self restore:NO];current=_read();}
    if(!current.application || !current.cursor || !current.reference || !current.hasDefaultShape || current.type<0 || current.type>14 || current.overrideType < -1 || current.overrideType>14)return NO;
    BOOL acquired=!_owned;
    if(acquired){_original=current;_owned=YES;}
    else if(current.overrideType!=1){_conflicted=YES;return NO;}
    if((current.overrideType!=1 && !_apply(_original,MTPlatformCursorOverride,1)) ||
       ((acquired || current.type!=1 || !current.hasShape) && !_apply(_original,MTPlatformCursorType,1)) ||
       ((acquired || !current.visible) && !_apply(_original,MTPlatformCursorVisibility,1))){[self restore:YES];return NO;}
    current=_read();
    return sameOwner(_original,current) && current.overrideType==1 && current.type==1 && current.visible && current.hasShape && current.free;
}
- (void)restore:(BOOL)restoreAppearance {
    if(_owned){
        MTPlatformCursorState current=_read();
        if(sameOwner(_original,current) && current.overrideType==1){
            // Release our force first; a later game menu keeps its current appearance.
            if(_apply(_original,MTPlatformCursorOverride,_original.overrideType) && restoreAppearance){
                if(current.type==1)_apply(_original,MTPlatformCursorType,_original.type);
                if(current.visible)_apply(_original,MTPlatformCursorVisibility,_original.visible);
            }
        }
    }
    _owned=NO;_conflicted=NO;_original=(MTPlatformCursorState){0};
}
@end
