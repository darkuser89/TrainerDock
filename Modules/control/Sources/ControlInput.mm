// SPDX-License-Identifier: GPL-3.0-only
#import "ControlInput.h"
#import "ControlEngine.h"
#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <atomic>
#include <array>
static std::atomic<bool> requested{false},ready{false},scheduled{false};
static void *mouseOwner;
static void **beforeTable;
static std::array<void*,13> table;
static void(*setVisible)(void*,bool);
static void(*setMode)(void*,int);
static int(*getMode)(void*);
static bool(*getVisible)(void*);
static std::atomic<bool> lastVisible;
static std::atomic<int> lastMode;
static void visibleHook(void *mouse,bool visible){lastVisible=visible;setVisible(mouse,requested.load()?true:visible);}
static void modeHook(void *mouse,int mode){lastMode=mode;setMode(mouse,requested.load()?0:mode);}
static void update(){NSCAssert(NSThread.isMainThread,@"Control input belongs to AppKit's thread");BOOL wanted=requested.load()&&NSApp.isActive;
 if(!wanted){if(mouseOwner){void **current=nullptr;if(MHTControlRead((uintptr_t)mouseOwner,&current,8)&&current==table.data()+2){__atomic_store_n((void***)mouseOwner,beforeTable,__ATOMIC_RELEASE);setMode(mouseOwner,lastMode);setVisible(mouseOwner,lastVisible);}mouseOwner=nullptr;}ready=false;return;}
 if(!MHTControlEngineIdentity()){ready=false;return;}
 uintptr_t window=0;MHTControlRead(MHTControlAddress(MHTControlWindow),&window,8);if(!window)return;
 void *mouse=((void*(*)(void*))(MHTControlAddress(MHTControlMouse)))((void*)window);
 if(!mouse||![MHTControlType((uintptr_t)mouse)isEqual:@"app::MouseMacos"]){ready=false;return;}
 if(mouseOwner&&mouseOwner!=mouse){ready=false;return;}
 if(!mouseOwner){
  setVisible=(void(*)(void*,bool))dlsym(RTLD_DEFAULT,"_ZN3app10MouseMacos10setVisibleEb");setMode=(void(*)(void*,int))dlsym(RTLD_DEFAULT,"_ZN3app10MouseMacos13setMotionModeENS_14MouseInterface10MotionModeE");getMode=(int(*)(void*))dlsym(RTLD_DEFAULT,"_ZN3app10MouseMacos13getMotionModeEv");getVisible=(bool(*)(void*))dlsym(RTLD_DEFAULT,"_ZNK3app10MouseMacos10getVisibleEv");
  void **original=(void**)dlsym(RTLD_DEFAULT,"_ZTVN3app10MouseMacosE");void **vptr=nullptr;
  if(!setVisible||!setMode||!getMode||!getVisible||!original||!MHTControlRead((uintptr_t)mouse,&vptr,8)||vptr!=original+2||!MHTControlRead((uintptr_t)original,table.data(),sizeof(table)))return;
  if(table[4]!=(void*)setMode||table[6]!=(void*)setVisible)return;
  lastVisible=getVisible(mouse);lastMode=getMode(mouse);if(lastMode<0||lastMode>2)return;
  beforeTable=vptr;table[4]=(void*)&modeHook;table[6]=(void*)&visibleHook;mouseOwner=mouse;__atomic_store_n((void***)mouse,table.data()+2,__ATOMIC_RELEASE);
 }
 setMode(mouse,0);setVisible(mouse,true);[NSCursor.arrowCursor set];ready=getMode(mouse)==0&&getVisible(mouse);
}
BOOL MHTControlOverlayInteraction(BOOL wanted){requested=wanted;if(!scheduled.exchange(true)){dispatch_async(dispatch_get_main_queue(),^{update();scheduled=false;});}return wanted&&ready.load();}
