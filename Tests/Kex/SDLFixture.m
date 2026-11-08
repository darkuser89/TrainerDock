// SPDX-License-Identifier: GPL-3.0-only
// Link-only original SDL stand-ins for synthetic executables. Never product code.
void SDL_GL_SwapWindow(void *window){(void)window;}
int SDL_SetRelativeMouseMode(int enabled){(void)enabled;return 0;}
int SDL_GetRelativeMouseMode(void){return 0;}
int SDL_ShowCursor(int toggle){(void)toggle;return 1;}
void SDL_SetWindowGrab(void *window,int enabled){(void)window;(void)enabled;}
int SDL_GetWindowGrab(void *window){(void)window;return 0;}
void SDL_WarpMouseInWindow(void *window,int x,int y){(void)window;(void)x;(void)y;}

void *SDL_GL_GetProcAddress(const char *name){(void)name;return 0;}
