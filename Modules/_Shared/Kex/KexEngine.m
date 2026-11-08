// SPDX-License-Identifier: GPL-3.0-only
#import "KexEngine.h"
#import "GameProfile.h"
#import "MemoryAccess.h"
#import "KexBits.h"
#import "KexFog.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <math.h>
// Original SDL imports. Interposition only redirects the game's existing calls;
// no executable bytes or page protections are modified.
extern void SDL_GL_SwapWindow(void *window);
extern int SDL_SetRelativeMouseMode(int enabled);
extern int SDL_GetRelativeMouseMode(void);
extern int SDL_ShowCursor(int toggle);
extern void SDL_SetWindowGrab(void *window,int enabled);
extern int SDL_GetWindowGrab(void *window);
extern void SDL_WarpMouseInWindow(void *window,int x,int y);
static NSMutableArray<dispatch_block_t> *jobs;
static BOOL prepared,inFrame,mouseWanted,mouseLease;
static void **localSlot,*sdlWindow;
#if !KEX_TUROK2
static void **playerSlot;
#endif
static int oldRelative,oldVisible,oldGrab;
static uint64_t frames;
#if KEX_TUROK2
static NSString *const profileID=@"steam-x86_64-20961743",*const imageUUID=@"AB442E80-6C9C-3FB0-9653-B349C088C250";
static const size_t stateOffset=0xc,playerOffset=0x141c8,puppetOffset=0x110,flagsOffset=0x1f0,ammoOffset=0x1412c;
#else
static NSString *const profileID=@"steam-x86_64-18198095",*const imageUUID=@"73B01170-3775-359F-B17C-867D13F2FB26";
static const size_t stateOffset=0x24,puppetOffset=0x68,flagsOffset=0x3b4,ammoOffset=0x28320;
#endif
static BOOL readAt(const void *object,size_t offset,void *out,size_t size){return object && (uintptr_t)object<=UINTPTR_MAX-offset && MTReadMemory((const uint8_t *)object+offset,out,size);}
static BOOL originalAddress(void *symbol){Dl_info info={};if(!symbol || !dladdr(symbol,&info))return NO;const struct mach_header_64 *h=info.dli_fbase;return h && h->filetype==MH_EXECUTE && h->cputype==CPU_TYPE_X86_64;}
static void prepare(void){
 if(prepared || !NSThread.isMainThread)return;
 NSDictionary *config=MTLoadConfiguration(NSProcessInfo.processInfo.environment[@"MHT_CONFIG"],NULL),*profile=MTFindProfile(config,profileID);
 if(![NSProcessInfo.processInfo.environment[@"MHT_PROFILE"] isEqual:profileID] || ![profile[@"uuids"] containsObject:imageUUID] || !MTCurrentProcessMatches(profile,NSProcessInfo.processInfo.environment[@"MHT_TARGET"]))return;
 localSlot=dlsym(RTLD_MAIN_ONLY,"_ZN7kexGame6cLocalE");
#if !KEX_TUROK2
 playerSlot=dlsym(RTLD_MAIN_ONLY,"_ZN7kexGame7cPlayerE");
 if(!originalAddress(playerSlot))return;
#endif
 if(!originalAddress(localSlot))return;
 jobs=[NSMutableArray new];prepared=YES;
}
typedef struct {void *local,*player,*puppet;BOOL playing;} Owner;
static Owner owner(void){
 Owner o={0};if(!prepared || !readAt(localSlot,0,&o.local,8) || !o.local)return o;
#if KEX_TUROK2
 uint8_t state=0;if(!readAt(o.local,stateOffset,&state,1))return (Owner){0};o.playing=state==2;o.player=(uint8_t *)o.local+playerOffset;
#else
 int32_t state=0;if(!readAt(o.local,stateOffset,&state,4) || !readAt(playerSlot,0,&o.player,8))return (Owner){0};o.playing=state==2;
#endif
 if(!readAt(o.player,puppetOffset,&o.puppet,8))o.puppet=NULL;
 // The authoritative local-player chain is the lifetime handle; never retain an
 // old actor through a load or dereference it after this chain changes.
 return o;
}
typedef struct {void *local,*player,*puppet;KEXBitState bit;} OwnedBit;
static OwnedBit bits[2];
static void releaseBit(NSInteger feature,Owner o){
 OwnedBit *b=&bits[feature];
 if(b->bit.held && o.local==b->local && (feature==1 || (o.player==b->player && o.puppet==b->puppet))){
  void *object=feature==0 ? o.puppet : o.local;size_t offset=feature==0 ? flagsOffset : ammoOffset;uint32_t value=0,mask=feature==0 ? 8 : 4;
  (void)value;KEXApplyBit(object,offset,mask,NO,&b->bit);
 }
 *b=(OwnedBit){0};
}
void KEXRelease(void){if(!inFrame)return;Owner o=owner();for(NSInteger i=0;i<2;i++)releaseBit(i,o);KEXFogSet(NO);}
NSDictionary *KEXInspect(void){
 if(!inFrame || !prepared)return @{@"kind":@0,@"identity":@"unsupported",@"note":@"Warte auf den originalen Spielrückruf."};
 Owner o=owner();BOOL live=o.playing && o.puppet;
 if(live){
#if KEX_TUROK2
  float hp=0;live=readAt(o.puppet,0x6c,&hp,4) && isfinite(hp) && hp>0 && hp<100000;
#else
  int16_t hp=0;live=readAt(o.puppet,0x134,&hp,2) && hp>0;
#endif
 }
 return @{@"kind":live ? @2 : @1,@"identity":[NSString stringWithFormat:@"%p:%p:%p:%d",o.local,o.player,o.puppet,live],@"note":live ? @"Eigene Spielfigur und originaler Spielrückruf bestätigt." : @"Menü oder Ladepause; wartet auf die eigene Spielfigur.",@"frames":@(frames)};
}
NSDictionary *KEXEffect(NSInteger feature,BOOL wanted){
 if(!inFrame || feature<0 || feature>2 || [KEXInspect()[@"kind"] integerValue]!=2)return @{@"available":@NO,@"active":@NO,@"note":@"Kein gültiger Spielkontext."};
 if(feature==2){BOOL active=KEXFogSet(wanted);return @{@"available":@YES,@"active":@(active),@"note":!wanted ? @"Originaler Nebel wieder freigegeben." : active ? @"Nebelwerte am Renderer gesetzt und zurückgelesen." : @"Warte auf bestätigte Nebelparameter im Renderer."};}
 Owner o=owner();OwnedBit *b=&bits[feature];
 if(b->bit.held && (b->local!=o.local || b->player!=o.player || b->puppet!=o.puppet))releaseBit(feature,o);
 void *object=feature==0 ? o.puppet : o.local;size_t offset=feature==0 ? flagsOffset : ammoOffset;uint32_t value=0,mask=feature==0 ? 8 : 4;
 if(!readAt(object,offset,&value,4))return @{@"available":@NO,@"active":@NO,@"note":@"Originalzustand nicht lesbar."};
 if(!wanted){releaseBit(feature,o);return @{@"available":@YES,@"active":@NO,@"note":@"Eigener Schutz ausgeschaltet."};}
 if(!b->bit.held){b->local=o.local;b->player=o.player;b->puppet=o.puppet;}
 BOOL ok=KEXApplyBit(object,offset,mask,YES,&b->bit);
 return @{@"available":@YES,@"active":@(ok),@"note":ok ? @"Originaler Schutz gesetzt und zurückgelesen." : @"Originalzustand hat den Auftrag nicht bestätigt."};
}
static void cursorState(BOOL wanted){
 BOOL enabled=wanted && NSApp.isActive && sdlWindow;
 if(enabled && !mouseLease){oldRelative=SDL_GetRelativeMouseMode();oldVisible=SDL_ShowCursor(-1);oldGrab=SDL_GetWindowGrab(sdlWindow);mouseLease=YES;}
 if(enabled){SDL_SetRelativeMouseMode(0);SDL_SetWindowGrab(sdlWindow,0);SDL_ShowCursor(1);}
 else if(mouseLease){
  // A newly opened engine menu owns a free cursor; do not recapture it.
  Owner o=owner();if(o.playing && NSApp.isActive){SDL_SetRelativeMouseMode(oldRelative);SDL_SetWindowGrab(sdlWindow,oldGrab);SDL_ShowCursor(oldVisible);}mouseLease=NO;
 }
}
BOOL KEXMouse(BOOL wanted){if(!inFrame)return NO;mouseWanted=wanted;cursorState(wanted);return mouseLease && !SDL_GetRelativeMouseMode();}
void KEXEnqueue(dispatch_block_t work){prepare();if(prepared && work && jobs.count<64)[jobs addObject:[work copy]];}
static void hookedSwap(void *window){
 if(prepared && NSThread.isMainThread && originalAddress(__builtin_return_address(0))){
  @autoreleasepool{sdlWindow=window;inFrame=YES;frames++;NSArray *pending=jobs.copy;[jobs removeAllObjects];for(dispatch_block_t work in pending)work();cursorState(mouseWanted);inFrame=NO;}
 }
 SDL_GL_SwapWindow(window);
}
static int hookedRelative(int enabled){if(mouseLease && NSApp.isActive){oldRelative=enabled;return SDL_SetRelativeMouseMode(0);}return SDL_SetRelativeMouseMode(enabled);}
static int hookedShow(int toggle){if(toggle>=0 && mouseLease && NSApp.isActive){oldVisible=toggle;return SDL_ShowCursor(1);}return SDL_ShowCursor(toggle);}
static void hookedGrab(void *window,int enabled){if(mouseLease && window==sdlWindow)oldGrab=enabled;SDL_SetWindowGrab(window,mouseLease && NSApp.isActive ? 0 : enabled);}
static void hookedWarp(void *window,int x,int y){if(!mouseLease || !NSApp.isActive)SDL_WarpMouseInWindow(window,x,y);}
__attribute__((used,section("__DATA,__interpose"))) static const struct {const void *replacement,*original;} interpositions[]={
 {(const void *)hookedSwap,(const void *)SDL_GL_SwapWindow},
 {(const void *)hookedRelative,(const void *)SDL_SetRelativeMouseMode},
 {(const void *)hookedShow,(const void *)SDL_ShowCursor},
 {(const void *)hookedGrab,(const void *)SDL_SetWindowGrab},
 {(const void *)hookedWarp,(const void *)SDL_WarpMouseInWindow}
};
