// SPDX-License-Identifier: GPL-3.0-only
// Synthetic native-memory fixtures only; no game or original executable is loaded.
#import "Cursor.hpp"
#import "ThreadInputBindings.h"
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <cassert>
#include <array>
#include <cstring>
#include <string>
#include <vector>
namespace {
std::array<uint8_t,2048> pc{},vp{},app{},cursor{},slate{},users{};
bool foreground=true,gameThread=true,pcAlive=true,vpAlive=true;
int releases=0;
uintptr_t appPointer=(uintptr_t)app.data(),slatePointer=(uintptr_t)slate.data();
constexpr uintptr_t cursorVTable=0x12345678;
template<class T>void store(uintptr_t a,size_t o,T value){std::memcpy((void *)(a+o),&value,sizeof(value));}
template<class T>T get(uintptr_t a,size_t o){T v{};std::memcpy(&v,(void *)(a+o),sizeof(v));return v;}
void *viewport(void *){return vp.data();}
void capture(void *,uint8_t v){vp[FP_VIEWPORT_CAPTURE_OFFSET]=v;}
void lock(void *,uint8_t v){vp[FP_VIEWPORT_LOCK_OFFSET]=v;}
void hide(void *,bool v){vp[FP_VIEWPORT_HIDE_OFFSET]=v;}
void precision(void *,bool v,void *){app[FP_APPLICATION_PRECISION_OFFSET]=v;cursor[FP_CURSOR_PRECISION_OFFSET]=v;}
void cursorLock(void *,const int32_t *r){std::array<int32_t,4> value{};if(r){std::memcpy(value.data(),r,sizeof(value));value[2]--;value[3]--;}store((uintptr_t)cursor.data(),FP_CURSOR_LOCK_RECT_OFFSET,value);}
void show(void *,bool v){cursor[FP_CURSOR_VISIBLE_OFFSET]=v;}
void type(void *,int32_t v){store((uintptr_t)cursor.data(),FP_CURSOR_TYPE_OFFSET,v);}
void release(void *,int32_t user){assert(user==0);releases++;}
BOOL active(id,SEL){return foreground;}
void reset(){pc.fill(0);vp.fill(0);app.fill(0);cursor.fill(0);slate.fill(0);users.fill(0);foreground=gameThread=pcAlive=vpAlive=true;releases=0;
 pc[FP_CONTROLLER_SHOW_CURSOR_OFFSET]=0x80;vp[FP_VIEWPORT_CAPTURE_OFFSET]=2;vp[FP_VIEWPORT_LOCK_OFFSET]=1;vp[FP_VIEWPORT_HIDE_OFFSET]=1;
 store((uintptr_t)app.data(),FP_APPLICATION_CURSOR_OFFSET,(uintptr_t)cursor.data());app[FP_APPLICATION_PRECISION_OFFSET]=1;
 store((uintptr_t)cursor.data(),0,cursorVTable);store((uintptr_t)cursor.data(),FP_CURSOR_TYPE_OVERRIDE_OFFSET,int32_t{-1});cursor[FP_CURSOR_PRECISION_OFFSET]=1;cursor[FP_CURSOR_VISIBLE_OFFSET]=0;type(nullptr,4);
 store((uintptr_t)cursor.data(),FP_CURSOR_LOCK_RECT_OFFSET,std::array<int32_t,4>{10,20,100,200});
 store((uintptr_t)slate.data(),FP_SLATE_USER_COUNT_OFFSET,int32_t{1});store((uintptr_t)slate.data(),FP_SLATE_USERS_OFFSET,(uintptr_t)users.data());store((uintptr_t)users.data(),0,(uintptr_t)users.data()+64);
}
}
namespace fp {
bool isBound(){return true;}bool isGameThread(){return gameThread;}
bool read(uintptr_t p,void *out,size_t size){
 for(auto &v:{&pc,&vp,&app,&cursor,&slate,&users}){uintptr_t a=(uintptr_t)v->data();if(p>=a && p-a<=v->size() && size<=v->size()-(p-a)){std::memcpy(out,(void*)p,size);return true;}}
 for(auto v:{&appPointer,&slatePointer})if(p==(uintptr_t)v&&size==8){std::memcpy(out,v,size);return true;}
 return false;
}
Weak::Weak(Object o){index=o.address==(uintptr_t)pc.data()?1:o.address==(uintptr_t)vp.data()?2:0;serial=index?1:0;}
Object Weak::get()const{if(!serial)return {};if(index==1&&pcAlive)return {(uintptr_t)pc.data()};if(index==2&&vpAlive)return {(uintptr_t)vp.data()};return {};}
Property property(Object,NSString *){Property p;p.type=@"BoolProperty";p.offset=FP_CONTROLLER_SHOW_CURSOR_OFFSET;p.boolMask=1;return p;}
uintptr_t binding(const char *key){std::string n(key);
 if(n=="contextViewport")return (uintptr_t)&viewport;if(n=="setCapture")return (uintptr_t)&capture;if(n=="setLock")return (uintptr_t)&lock;if(n=="setHide")return (uintptr_t)&hide;
 if(n=="setPrecision")return (uintptr_t)&precision;if(n=="cursorLock")return (uintptr_t)&cursorLock;if(n=="cursorShow")return (uintptr_t)&show;if(n=="cursorType")return (uintptr_t)&type;if(n=="releaseCapture")return (uintptr_t)&release;
 if(n=="macApplicationSlot")return (uintptr_t)&appPointer;if(n=="macCursorVTable")return cursorVTable;if(n=="slateSlot")return (uintptr_t)&slatePointer;return 0;
}
}
extern "C" BOOL MTWriteByte(void *o,size_t offset,uint8_t value){store((uintptr_t)o,offset,value);return YES;}
int main(){@autoreleasepool{
 Method method=class_getInstanceMethod(NSRunningApplication.class,@selector(isActive));assert(method);IMP previous=method_setImplementation(method,(IMP)active);
 reset();fp::Object controller{(uintptr_t)pc.data()};
 assert(FPSetOverlayMouse(true,controller));assert(releases==1);assert(pc[FP_CONTROLLER_SHOW_CURSOR_OFFSET]==0x81);assert(cursor[FP_CURSOR_VISIBLE_OFFSET]==1);
 // Repeat does not replace the original baseline. Other controller bits survive.
 pc[FP_CONTROLLER_SHOW_CURSOR_OFFSET]|=0x20;assert(FPSetOverlayMouse(true,controller));assert(releases==2);
 assert(!FPSetOverlayMouse(false,controller));assert(pc[FP_CONTROLLER_SHOW_CURSOR_OFFSET]==0xa0);assert(vp[FP_VIEWPORT_CAPTURE_OFFSET]==2&&vp[FP_VIEWPORT_LOCK_OFFSET]==1&&vp[FP_VIEWPORT_HIDE_OFFSET]==1);
 assert(app[FP_APPLICATION_PRECISION_OFFSET]==1&&cursor[FP_CURSOR_PRECISION_OFFSET]==1&&cursor[FP_CURSOR_VISIBLE_OFFSET]==0);assert(get<int32_t>((uintptr_t)cursor.data(),FP_CURSOR_TYPE_OFFSET)==4);
 assert((get<std::array<int32_t,4>>((uintptr_t)cursor.data(),FP_CURSOR_LOCK_RECT_OFFSET)==std::array<int32_t,4>{10,20,100,200}));
 // An engine/menu change after takeover remains untouched on release.
 reset();assert(FPSetOverlayMouse(true,controller));vp[FP_VIEWPORT_CAPTURE_OFFSET]=4;type(nullptr,7);assert(!FPSetOverlayMouse(false,controller));assert(vp[FP_VIEWPORT_CAPTURE_OFFSET]==4&&get<int32_t>((uintptr_t)cursor.data(),8)==7);assert(pc[FP_CONTROLLER_SHOW_CURSOR_OFFSET]==0x81&&cursor[FP_CURSOR_VISIBLE_OFFSET]==1);
 // Lost UObject serials prevent writes through obsolete owners or native leases.
 reset();assert(FPSetOverlayMouse(true,controller));pcAlive=false;assert(!FPSetOverlayMouse(false,controller));assert(app[FP_APPLICATION_PRECISION_OFFSET]==0&&pc[FP_CONTROLLER_SHOW_CURSOR_OFFSET]==0x81);
 // Focus loss releases data while preserving physical freedom in the background.
 reset();assert(FPSetOverlayMouse(true,controller));foreground=false;assert(!FPSetOverlayMouse(false,controller));assert(app[FP_APPLICATION_PRECISION_OFFSET]==0);assert((get<std::array<int32_t,4>>((uintptr_t)cursor.data(),FP_CURSOR_LOCK_RECT_OFFSET)==std::array<int32_t,4>{}));
 reset();store((uintptr_t)cursor.data(),FP_CURSOR_TYPE_OVERRIDE_OFFSET,int32_t{7});assert(!FPSetOverlayMouse(true,controller));assert(releases==0&&vp[FP_VIEWPORT_CAPTURE_OFFSET]==2);
 reset();gameThread=false;assert(!FPSetOverlayMouse(true,controller));assert(releases==0&&app[FP_APPLICATION_PRECISION_OFFSET]==1);
 method_setImplementation(method,previous);puts("PASS: synthetic cursor lease restoration, owner lifetime, foreign state, focus and thread boundaries; no game executed.");
}return 0;}
