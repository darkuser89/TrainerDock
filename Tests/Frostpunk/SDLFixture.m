// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
// Only the native synthetic test executable links these SDL ABI fixtures.
static int visible=1, grabbed[2];
static NSUInteger calls, invalidWindowCalls;
static BOOL alive[2]={YES,YES};
static void *mouseFocus=(void *)1,*keyboardFocus=(void *)1;
static NSInteger windowIndex(void *window){return window==(void *)1?0:window==(void *)2?1:-1;}
static BOOL validWindow(void *window){NSInteger index=windowIndex(window);return index>=0 && alive[index];}
NSUInteger MHTFrostpunkSDLFixtureCallCount(void){return calls;}
NSUInteger MHTFrostpunkSDLFixtureInvalidWindowCalls(void){return invalidWindowCalls;}
void MHTFrostpunkSDLFixtureReset(void *mouse,void *keyboard,int visibility,int firstGrab,int secondGrab){
    mouseFocus=mouse;keyboardFocus=keyboard;visible=visibility;grabbed[0]=firstGrab;grabbed[1]=secondGrab;
    alive[0]=alive[1]=YES;calls=invalidWindowCalls=0;
}
void MHTFrostpunkSDLFixtureSetFocus(void *mouse,void *keyboard){mouseFocus=mouse;keyboardFocus=keyboard;}
void MHTFrostpunkSDLFixtureDestroyWindow(uint32_t identifier){if(identifier>=1 && identifier<=2)alive[identifier-1]=NO;}
int MHTFrostpunkSDLFixtureVisible(void){return visible;}
int MHTFrostpunkSDLFixtureGrab(uint32_t identifier){return identifier>=1 && identifier<=2?grabbed[identifier-1]:-1;}
int SDL_PollEvent(void *event){(void)event;calls++;return 0;}
int SDL_ShowCursor(int toggle){calls++;if(toggle>=0)visible=toggle;return visible;}
void *SDL_GetMouseFocus(void){calls++;return validWindow(mouseFocus)?mouseFocus:NULL;}
void *SDL_GetKeyboardFocus(void){calls++;return validWindow(keyboardFocus)?keyboardFocus:NULL;}
uint32_t SDL_GetWindowID(void *window){calls++;if(!validWindow(window)){invalidWindowCalls++;return 0;}return (uint32_t)windowIndex(window)+1;}
void *SDL_GetWindowFromID(uint32_t identifier){calls++;return identifier>=1 && identifier<=2 && alive[identifier-1]?(void *)(uintptr_t)identifier:NULL;}
int SDL_GetWindowGrab(void *window){calls++;if(!validWindow(window)){invalidWindowCalls++;return -1;}return grabbed[windowIndex(window)];}
void SDL_SetWindowGrab(void *window,int enabled){calls++;if(!validWindow(window)){invalidWindowCalls++;return;}grabbed[windowIndex(window)]=enabled;}
void SDL_WarpMouseInWindow(void *window,int x,int y){(void)window;(void)x;(void)y;calls++;}
