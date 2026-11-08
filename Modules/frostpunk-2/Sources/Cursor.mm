// SPDX-License-Identifier: GPL-3.0-only
#import "Cursor.hpp"
#import "ThreadInputBindings.h"
extern "C" {
#import "MemoryAccess.h"
}
#import <AppKit/AppKit.h>
#include <array>
#include <climits>
#include <cstring>
#include <stdexcept>

namespace {
using fp::Object;
template<class T> bool load(uintptr_t base,size_t offset,T &out) {
    return base>=4096 && offset<=UINTPTR_MAX-base && fp::read(base+offset,&out,sizeof(out));
}
template<class T> T original(const char *name) {
    uintptr_t address=fp::binding(name);
    if(!address)throw std::runtime_error("Die ursprüngliche Mauszeigeranbindung ist nicht verfügbar.");
    return reinterpret_cast<T>(address);
}
struct API {
    void *(*viewport)(void *)=nullptr;
    void (*capture)(void *,uint8_t)=nullptr;
    void (*lock)(void *,uint8_t)=nullptr;
    void (*hide)(void *,bool)=nullptr;
    void (*precision)(void *,bool,void *)=nullptr;
    void (*cursorLock)(void *,const int32_t *)=nullptr;
    void (*cursorShow)(void *,bool)=nullptr;
    void (*cursorType)(void *,int32_t)=nullptr;
    void (*releaseCapture)(void *,int32_t)=nullptr;
    bool resolve() {
        if(!fp::isBound())return false;
        viewport=original<decltype(viewport)>("contextViewport");
        capture=original<decltype(capture)>("setCapture");
        lock=original<decltype(lock)>("setLock");
        hide=original<decltype(hide)>("setHide");
        precision=original<decltype(precision)>("setPrecision");
        cursorLock=original<decltype(cursorLock)>("cursorLock");
        cursorShow=original<decltype(cursorShow)>("cursorShow");
        cursorType=original<decltype(cursorType)>("cursorType");
        releaseCapture=original<decltype(releaseCapture)>("releaseCapture");
        return true;
    }
};
struct Snapshot {
    uint8_t capture=0,lock=0,hide=0,show=0,visible=0,precision=0,cursorPrecision=0;
    int32_t type=0;
    std::array<int32_t,4> rect{};
};
class CursorLease {
    API api{};
    fp::Weak controllerWeak{},viewportWeak{};
    Object controller{},viewport{};
    uintptr_t application=0,cursor=0,slate=0;
    Snapshot baseline{};
    bool owned=false;
    bool objectsAlive() const { return controllerWeak.get()==controller && viewportWeak.get()==viewport; }
    bool sameNative() const {
        uintptr_t app=0,currentCursor=0,vtable=0;
        return load(fp::binding("macApplicationSlot"),0,app) && app==application
            && load(app,FP_APPLICATION_CURSOR_OFFSET,currentCursor) && currentCursor==cursor
            && load(cursor,0,vtable) && vtable==fp::binding("macCursorVTable");
    }
    bool snapshot(Snapshot &s) const {
        uint8_t show=0;
        return load(viewport.address,FP_VIEWPORT_CAPTURE_OFFSET,s.capture)
            && load(viewport.address,FP_VIEWPORT_LOCK_OFFSET,s.lock)
            && load(viewport.address,FP_VIEWPORT_HIDE_OFFSET,s.hide)
            && load(controller.address,FP_CONTROLLER_SHOW_CURSOR_OFFSET,show)
            && (s.show=show&FP_CONTROLLER_SHOW_CURSOR_MASK,true)
            && load(application,FP_APPLICATION_PRECISION_OFFSET,s.precision)
            && load(cursor,FP_CURSOR_PRECISION_OFFSET,s.cursorPrecision)
            && load(cursor,FP_CURSOR_VISIBLE_OFFSET,s.visible)
            && load(cursor,FP_CURSOR_TYPE_OFFSET,s.type)
            && load(cursor,FP_CURSOR_LOCK_RECT_OFFSET,s.rect);
    }
    bool showBit(uint8_t desired) const {
        uint8_t current=0;
        if(!load(controller.address,FP_CONTROLLER_SHOW_CURSOR_OFFSET,current))return false;
        uint8_t next=(current&~FP_CONTROLLER_SHOW_CURSOR_MASK)|(desired&FP_CONTROLLER_SHOW_CURSOR_MASK);
        return current==next || MTWriteByte((void *)controller.address,FP_CONTROLLER_SHOW_CURSOR_OFFSET,next);
    }
    static bool ownState(const Snapshot &s) {
        return s.capture==0 && s.lock==0 && s.hide==0 && s.precision==0
            && s.cursorPrecision==0 && s.visible==1 && s.type==1
            && s.show==FP_CONTROLLER_SHOW_CURSOR_MASK && s.rect==std::array<int32_t,4>{};
    }
    bool acquire(Object requested) {
        // The exact reflected owner property prevents interpreting an arbitrary UObject
        // as a player controller. This remains valid for the game's controller subclass.
        fp::Property show=fp::property(requested,@"bShowMouseCursor");
        if(![show.type isEqual:@"BoolProperty"] || show.offset+show.boolByteOffset!=FP_CONTROLLER_SHOW_CURSOR_OFFSET
            || show.boolMask!=FP_CONTROLLER_SHOW_CURSOR_MASK)return false;
        fp::Weak pc(requested);if(!(pc.get()==requested))return false;
        Object vp{(uintptr_t)api.viewport((void *)requested.address)};
        if(!vp)return false;
        fp::Weak vw(vp);if(!(vw.get()==vp))return false;
        uintptr_t app=0,cur=0,table=0,st=0,user=0,users=0;
        int32_t count=0;
        if(!load(fp::binding("macApplicationSlot"),0,app) || !load(app,FP_APPLICATION_CURSOR_OFFSET,cur)
            || !load(cur,0,table) || table!=fp::binding("macCursorVTable")
            || !load(fp::binding("slateSlot"),0,st) || !load(st,FP_SLATE_USER_COUNT_OFFSET,count)
            || count<1 || count>64 || !load(st,FP_SLATE_USERS_OFFSET,users) || !load(users,0,user) || !user)return false;
        controller=requested;viewport=vp;controllerWeak=pc;viewportWeak=vw;
        application=app;cursor=cur;slate=st;
        Snapshot s{};int32_t overrideType=0;
        // An engine-enforced custom type cannot be replaced by the default arrow.
        // Refuse before taking control instead of partially applying an unusable UI.
        if(!load(cursor,FP_CURSOR_TYPE_OVERRIDE_OFFSET,overrideType) || (overrideType>=0 && overrideType!=1))return false;
        if(!snapshot(s) || s.capture>4 || s.lock>3 || s.hide>1 || s.precision>1
            || s.cursorPrecision!=s.precision || s.visible>1 || s.type<0 || s.type>32)return false;
        baseline=s;owned=true;return true;
    }
public:
    void release() {
        if(!owned)return;
        // Native cursor state has no UObject lifetime; require its original singleton,
        // exact vtable and both original UObject serials before touching that lease.
        bool alive=objectsAlive(),native=alive&&sameNative();
        Snapshot current{};
        // A changed capture, type, lock or show intent can be a newly opened menu.
        // Do not restore a previous gameplay intent over any observed foreign intent.
        bool intact=native && snapshot(current) && ownState(current);
        if(intact) {
            uint8_t value=0;
            if(load(controller.address,FP_CONTROLLER_SHOW_CURSOR_OFFSET,value) && (value&FP_CONTROLLER_SHOW_CURSOR_MASK))showBit(baseline.show);
            if(load(viewport.address,FP_VIEWPORT_CAPTURE_OFFSET,value)&&value==0)api.capture((void *)viewport.address,baseline.capture);
            if(load(viewport.address,FP_VIEWPORT_LOCK_OFFSET,value)&&value==0)api.lock((void *)viewport.address,baseline.lock);
            if(load(viewport.address,FP_VIEWPORT_HIDE_OFFSET,value)&&value==0)api.hide((void *)viewport.address,baseline.hide!=0);
        }
        if(intact && NSRunningApplication.currentApplication.active) {
            uint8_t precision=0,cursorPrecision=0,visible=0;int32_t type=0;std::array<int32_t,4> rect{};
            if(load(application,FP_APPLICATION_PRECISION_OFFSET,precision)&&precision==0
                && load(cursor,FP_CURSOR_PRECISION_OFFSET,cursorPrecision)&&cursorPrecision==0)
                api.precision((void *)application,baseline.precision!=0,nullptr);
            if(load(cursor,FP_CURSOR_VISIBLE_OFFSET,visible)&&visible==1)api.cursorShow((void *)cursor,baseline.visible!=0);
            if(load(cursor,FP_CURSOR_TYPE_OFFSET,type)&&type==1)api.cursorType((void *)cursor,baseline.type);
            if(load(cursor,FP_CURSOR_LOCK_RECT_OFFSET,rect)&&rect==std::array<int32_t,4>{}
                && baseline.rect[2]>baseline.rect[0] && baseline.rect[3]>baseline.rect[1]
                && baseline.rect[2]<INT_MAX && baseline.rect[3]<INT_MAX) {
                auto originalRect=baseline.rect;originalRect[2]++;originalRect[3]++;
                api.cursorLock((void *)cursor,originalRect.data());
            }
        }
        // No background recapture and no synthetic GameOnly/focus command. The game
        // owns subsequent focus/input-mode decisions after this data lease is released.
        owned=false;controller={};viewport={};controllerWeak={};viewportWeak={};
        application=cursor=slate=0;
    }
    bool set(bool wanted,Object requested) {
        if(!fp::isBound() || !fp::isGameThread())return false;
        if(!wanted || !requested || !NSRunningApplication.currentApplication.active){release();return false;}
        if(!api.resolve())return false;
        if(owned && (!(requested==controller)||!objectsAlive()||!sameNative()))release();
        if(!owned && !acquire(requested))return false;
        if(!objectsAlive()||!sameNative()){release();return false;}
        api.capture((void *)viewport.address,0);api.lock((void *)viewport.address,0);api.hide((void *)viewport.address,false);
        api.releaseCapture((void *)slate,0); // Negative user indices are a native no-op.
        if(!objectsAlive()||!sameNative()){release();return false;}
        api.precision((void *)application,false,nullptr);api.cursorLock((void *)cursor,nullptr);
        api.cursorType((void *)cursor,1);api.cursorShow((void *)cursor,true);
        if(!showBit(FP_CONTROLLER_SHOW_CURSOR_MASK)){release();return false;}
        Snapshot current{};
        bool success=snapshot(current) && ownState(current);
        if(!success)release();return success;
    }
};
CursorLease lease;
}
bool FPSetOverlayMouse(bool wanted,fp::Object controller) {
    if(!fp::isBound() || !fp::isGameThread())return false;
    try{return lease.set(wanted,controller);}catch(const std::exception &){try{lease.release();}catch(const std::exception &){}return false;}
}
