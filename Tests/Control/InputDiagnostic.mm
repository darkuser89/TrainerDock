// SPDX-License-Identifier: GPL-3.0-only
#import "ControlEngine.h"
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
extern "C" NSDictionary *MHTControlNativeDiagnostic(uintptr_t core,uintptr_t main,void *server,uintptr_t avatar){
 (void)main;(void)server;(void)avatar;uintptr_t window=r<uintptr_t>(core+0xb85960);if(!window)return @{};
 uintptr_t mouse=(uintptr_t)((void*(*)(void*))(core+0x19f1e0))((void*)window);
 return @{@"type":MHTControlType(mouse),@"mode":@(r<int>(mouse+8)),@"visible":@(r<uint8_t>(r<uintptr_t>(mouse+0x40)+0x148)),@"buttonMask":@(r<uint32_t>(mouse+0xc))};
}
