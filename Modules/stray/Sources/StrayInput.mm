// SPDX-License-Identifier: GPL-3.0-only
#import "StrayInput.hpp"
#import "StrayEngine.hpp"
#import <AppKit/AppKit.h>
#include <array>
#include <climits>
#include <cstring>
namespace {
#ifdef STRAY_INPUT_TESTING
extern bool inputFixtureActive;
static bool appActive(){return inputFixtureActive;}
#else
static bool appActive(){return NSRunningApplication.currentApplication.active;}
#endif
struct Signature {const char *name;uint8_t bytes[16];};
static const Signature signatures[]={
 {"inputSetPrecision",{0x01,0x20,0x02,0x39,0x00,0x04,0x40,0xf9,0x01,0x00,0x00,0x14,0xff,0x43,0x01,0xd1}},
 {"inputCursorShow",{0x01,0x40,0x04,0x39,0xac,0xef,0xff,0x17,0xe9,0x23,0xbb,0x6d,0xf8,0x5f,0x01,0xa9}},
 {"inputCursorLock",{0xe9,0x23,0xbb,0x6d,0xf8,0x5f,0x01,0xa9,0xf6,0x57,0x02,0xa9,0xf4,0x4f,0x03,0xa9}},
 {"inputCursorType",{0xff,0x03,0x01,0xd1,0xf6,0x57,0x01,0xa9,0xf4,0x4f,0x02,0xa9,0xfd,0x7b,0x03,0xa9}},
 {"inputSetCapture",{0x08,0x48,0x4d,0x39,0x1f,0x01,0x01,0x6b,0x40,0x00,0x00,0x54,0x01,0x48,0x0d,0x39}},
 {"inputSetLock",{0x08,0x50,0x4d,0x39,0x1f,0x01,0x01,0x6b,0x40,0x00,0x00,0x54,0x01,0x50,0x0d,0x39}},
 {"inputSetHide",{0x08,0x4c,0x4d,0x39,0x1f,0x01,0x01,0x6b,0x40,0x00,0x00,0x54,0x01,0x4c,0x0d,0x39}},
 {"inputReleaseCapture",{0xff,0x43,0x01,0xd1,0xf6,0x57,0x02,0xa9,0xf4,0x4f,0x03,0xa9,0xfd,0x7b,0x04,0xa9}},
 {"inputWorldViewport",{0xfd,0x7b,0xbf,0xa9,0xfd,0x03,0x00,0x91,0xe1,0x03,0x00,0xaa,0xc8,0xf3,0x00,0x90}},
};
template<class T>bool load(uintptr_t base,size_t offset,T &value){return base>=4096&&offset<=UINTPTR_MAX-base&&st::read(base+offset,&value,sizeof(value));}
template<class T>T original(const char *name){return reinterpret_cast<T>(st::binding(name));}
struct API {
 void *(*viewport)(void *)=nullptr;
 void(*capture)(void *,uint8_t)=nullptr;
 void(*lock)(void *,uint8_t)=nullptr;
 void(*hide)(void *,bool)=nullptr;
 void(*precision)(void *,bool,const void *)=nullptr;
 void(*show)(void *,bool)=nullptr;
 void(*type)(void *,int32_t)=nullptr;
 void(*clip)(void *,const int32_t *)=nullptr;
 void(*release)(void *,int32_t)=nullptr;
 bool resolve(){
  if(!st::isBound())return false;
#ifndef STRAY_INPUT_TESTING
  for(const Signature &s:signatures){uint8_t actual[16];uintptr_t address=st::binding(s.name);if(!address||!st::read(address,actual,sizeof(actual))||memcmp(actual,s.bytes,sizeof(actual)))return false;}
#endif
  viewport=original<decltype(viewport)>("inputWorldViewport");capture=original<decltype(capture)>("inputSetCapture");
  lock=original<decltype(lock)>("inputSetLock");hide=original<decltype(hide)>("inputSetHide");precision=original<decltype(precision)>("inputSetPrecision");
  show=original<decltype(show)>("inputCursorShow");type=original<decltype(type)>("inputCursorType");clip=original<decltype(clip)>("inputCursorLock");release=original<decltype(release)>("inputReleaseCapture");
  return true;
 }
};
struct Snapshot {
 uint8_t capture=0,lock=0,hide=0,show=0,visible=0,precision=0,cursorPrecision=0;
 int32_t type=0;std::array<int32_t,4> rect{};
};
class InputLease {
 API api{};bool owned=false;
 st::Object controller{},world{},viewport{};
 st::Weak controllerWeak{},worldWeak{},viewportWeak{};
 uintptr_t application=0,cursor=0,slate=0;
 Snapshot baseline{};
 bool alive()const{return controllerWeak.get()==controller&&worldWeak.get()==world&&viewportWeak.get()==viewport;}
 bool native()const{
  uintptr_t app=0,current=0,table=0,s=0;
  return load(st::binding("inputMacApplication"),0,app)&&app==application&&load(app,8,current)&&current==cursor
   &&load(cursor,0,table)&&table==st::binding("inputMacCursorVTable")&&load(st::binding("inputSlate"),0,s)&&s==slate;
 }
 bool snapshot(Snapshot &s)const{
  uint8_t flags=0;
  return load(viewport.address,0x352,s.capture)&&load(viewport.address,0x354,s.lock)&&load(viewport.address,0x353,s.hide)
   &&load(controller.address,0x440,flags)&&(s.show=flags&1,true)&&load(application,0x88,s.precision)
   &&load(cursor,0x111,s.cursorPrecision)&&load(cursor,0x110,s.visible)&&load(cursor,8,s.type)&&load(cursor,0x100,s.rect);
 }
 static bool ours(const Snapshot &s){return !s.capture&&!s.lock&&!s.hide&&s.show==1&&!s.precision&&!s.cursorPrecision&&s.visible==1&&s.type==1&&s.rect==std::array<int32_t,4>{};}
 bool showBit(uint8_t desired)const{
  uint8_t current=0;if(!load(controller.address,0x440,current))return false;
  uint8_t next=(current&~1)|(desired&1);return next==current||st::write(controller.address+0x440,&next,1);
 }
 bool acquire(st::Object pc,st::Object w){
  if(!pc||!w)return false;
  st::Property show=st::property(pc,@"bShowMouseCursor");
  if(![show.type isEqual:@"BoolProperty"]||show.offset+show.boolByteOffset!=0x440||show.boolMask!=1)return false;
  st::Weak pcWeak(pc),wWeak(w);if(pcWeak.get()!=pc||wWeak.get()!=w)return false;
  st::Object vp{(uintptr_t)api.viewport((void *)w.address)};st::Weak vpWeak(vp);
  uintptr_t ownerWorld=0;if(!vp||vpWeak.get()!=vp||!load(vp.address,0x70,ownerWorld)||ownerWorld!=w.address)return false;
  uintptr_t app=0,cur=0,table=0,sl=0,users=0,first=0;int32_t count=0,overrideType=0;
  if(!load(st::binding("inputMacApplication"),0,app)||!load(app,8,cur)||!load(cur,0,table)||table!=st::binding("inputMacCursorVTable")
    ||!load(cur,0x120,overrideType)||(overrideType>=0&&overrideType!=1)||!load(st::binding("inputSlate"),0,sl)
    ||!load(sl,0x2d8,count)||count<1||count>64||!load(sl,0x2d0,users)||!load(users,0,first)||first<4096)return false;
  controller=pc;world=w;viewport=vp;controllerWeak=pcWeak;worldWeak=wWeak;viewportWeak=vpWeak;
  application=app;cursor=cur;slate=sl;
  Snapshot s{};if(!snapshot(s)||s.capture>4||s.lock>3||s.hide>1||s.precision>1||s.cursorPrecision!=s.precision||s.visible>1||s.type<0||s.type>32)return false;
  baseline=s;owned=true;return true;
 }
public:
 bool hasLease()const{return owned;}
 void release(){
  if(!owned)return;
  Snapshot s{};bool intact=alive()&&native()&&snapshot(s)&&ours(s);
  // Restore only this lease's untouched values. A menu or another owner may
  // have established a different capture intent while the trainer was open.
  if(intact){showBit(baseline.show);api.capture((void *)viewport.address,baseline.capture);api.lock((void *)viewport.address,baseline.lock);api.hide((void *)viewport.address,baseline.hide!=0);}
  // Never physically recapture the mouse in another application.
  if(intact&&appActive()){
   api.precision((void *)application,baseline.precision!=0,nullptr);api.show((void *)cursor,baseline.visible!=0);api.type((void *)cursor,baseline.type);
   if(baseline.rect[2]>baseline.rect[0]&&baseline.rect[3]>baseline.rect[1]&&baseline.rect[2]<INT_MAX&&baseline.rect[3]<INT_MAX){auto r=baseline.rect;r[2]++;r[3]++;api.clip((void *)cursor,r.data());}
  }
  owned=false;controller={};world={};viewport={};controllerWeak={};worldWeak={};viewportWeak={};application=cursor=slate=0;
 }
 bool apply(bool wanted){
  if(!st::isBound()||!st::isGameThread())return false;
  if(!wanted||!appActive()){release();return false;}
  if(!api.viewport&&!api.resolve())return false;
  st::Object pc=st::playerController(),w=st::world();
  if(owned&&(!alive()||!native()||pc!=controller||w!=world))release();
  if(!owned&&!acquire(pc,w))return false;
  if(!alive()||!native())return false;
  api.capture((void *)viewport.address,0);api.lock((void *)viewport.address,0);api.hide((void *)viewport.address,false);
  api.release((void *)slate,0);
  if(!alive()||!native()){release();return false;}
  api.precision((void *)application,false,nullptr);api.clip((void *)cursor,nullptr);api.show((void *)cursor,true);api.type((void *)cursor,1);
  if(!showBit(1)){release();return false;}
  Snapshot s{};bool success=snapshot(s)&&ours(s);if(!success)release();return success;
 }
};
InputLease lease;
}
bool STSetOverlayInteraction(bool wanted){
 // Closed overlays without a lease have no native work, including no thread,
 // object or metadata queries. The single transition to closed still restores.
 if(!wanted&&!lease.hasLease())return false;
 if(!st::isBound()||!st::isGameThread())return false;
 try{return lease.apply(wanted);}catch(const std::exception &){try{lease.release();}catch(const std::exception &){}return false;}
}
