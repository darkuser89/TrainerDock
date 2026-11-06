// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayInput.h"

static void *pointer(const void *object, size_t offset) {
    void *value=NULL; if (object) DI2ReadMemory((const char *)object+offset,&value,8); return value;
}
@implementation DI2OverlayInput {
    DI2GameAPI _api;
    DI2WeakObject _controller, _viewport;
    BOOL _owned, _starting;
    uint8_t _flags[4], _showBit, _cursorType;
}
- (instancetype)initWithAPI:(DI2GameAPI)api { if ((self=[super init])) _api=api; return self; }
- (BOOL)object:(void *)object type:(void *(*)(void))type {
    void *actual=pointer(object,0x10);
    return object && !((uintptr_t)object&7) && actual && type && _api.valid(object,false)
        && _api.classIsChildOf(actual,type());
}
- (BOOL)readViewport:(void *)viewport flags:(uint8_t *)flags {
    // IgnoreInput, MouseCaptureMode, HideCursorDuringCapture, MouseLockMode.
    return viewport && DI2ReadMemory((char *)viewport+0x329,flags,4)
        && flags[0]<=1 && flags[1]<=4 && flags[2]<=1 && flags[3]<=3;
}
- (void)restoreForCurrentController:(void *)current {
    if (!_owned) return;
    void *controller=_api.weakGet(&_controller),*viewport=_api.weakGet(&_viewport);
    uint8_t flags[4]={0},show=0;
    BOOL ours=[self readViewport:viewport flags:flags] && flags[0]==1 && flags[1]==0 && flags[3]==0;
    // A different input mode installed by a game menu owns the viewport now.
    // Do not force GameOnly or hide that menu's cursor in this case.
    if (ours || _starting) {
        if (ours && controller && controller==current) _api.inputGameOnly(controller);
        for (NSUInteger i=0;i<4;i++) DI2WriteByte(viewport,0x329+i,_flags[i]);
        if (controller && DI2ReadMemory((char *)controller+0x470,&show,1)) {
            DI2WriteByte(controller,0x470,(show&~1u)|_showBit);
            uint8_t cursor=0;
            if (_cursorType==0 && DI2ReadMemory((char *)controller+0x489,&cursor,1) && cursor==1)
                DI2WriteByte(controller,0x489,_cursorType);
        }
    }
    _owned=NO; _starting=NO; memset(&_controller,0,sizeof(_controller)); memset(&_viewport,0,sizeof(_viewport));
}
- (BOOL)updateWorld:(void *)world wanted:(BOOL)wanted {
    BOOL bound=_api.playerController && _api.worldViewport && _api.inputUIOnly && _api.inputGameOnly;
    void *controller=bound && world ? _api.playerController(world,0) : NULL;
    void *viewport=bound && world ? _api.worldViewport(world) : NULL;
    if (![self object:controller type:_api.controllerClass] || ![self object:viewport type:_api.viewportClass]
        || ![self object:pointer(controller,0x2d0) type:_api.localPlayerClass]) controller=NULL;
    if (_owned && (!wanted || !controller || _api.weakGet(&_controller)!=controller || _api.weakGet(&_viewport)!=viewport))
        [self restoreForCurrentController:controller];
    if (!wanted || !controller) return NO;
    uint8_t show=0,cursor=0,flags[4]={0};
    if (!DI2ReadMemory((char *)controller+0x470,&show,1) || !DI2ReadMemory((char *)controller+0x489,&cursor,1)
        || cursor>18 || ![self readViewport:viewport flags:flags]) return NO;
    if (_owned && (flags[0]!=1 || flags[1]!=0 || flags[3]!=0)) {
        [self restoreForCurrentController:controller];
        return (show&1) && cursor!=0;
    }
    if (!_owned) {
        // Menus with an existing cursor keep their focus/input mode untouched.
        if (show&1) return cursor!=0;
        if (flags[0]) return NO; // Loading/cinematic UI belongs to the game.
        memcpy(_flags,flags,4); _showBit=show&1; _cursorType=cursor;
        _api.weakAssign(&_controller,controller); _api.weakAssign(&_viewport,viewport);
        if (_api.weakGet(&_controller)!=controller || _api.weakGet(&_viewport)!=viewport) return NO;
        _owned=YES; _starting=YES;
        BOOL changed=DI2WriteByte(controller,0x470,show|1u);
        if (!cursor) changed=DI2WriteByte(controller,0x489,1) && changed; // EMouseCursor::Default
        if (!changed) { [self restoreForCurrentController:controller]; return NO; }
        // Native UIOnly releases Slate capture/high-precision input and ignores
        // game movement/fire input. A null UWidget leaves AppKit overlay focus alone.
        _api.inputUIOnly(controller,NULL,0); // EMouseLockMode::DoNotLock
    }
    BOOL confirmed=[self readViewport:viewport flags:flags] && flags[0]==1 && flags[1]==0 && flags[3]==0
        && DI2ReadMemory((char *)controller+0x470,&show,1) && (show&1)
        && DI2ReadMemory((char *)controller+0x489,&cursor,1) && cursor!=0;
    if (!confirmed) [self restoreForCurrentController:controller];
    else _starting=NO;
    return confirmed;
}
@end
