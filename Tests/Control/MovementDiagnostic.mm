// SPDX-License-Identifier: GPL-3.0-only
// Reversible native configuration candidate in the authorized live test.
#import "ControlEngine.h"
#include <array>
#include <dlfcn.h>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
extern "C" NSDictionary *MHTControlNativeDiagnostic(uintptr_t core,uintptr_t main,void *server,uintptr_t avatar){
 (void)core;(void)server;static uintptr_t owner,original,movement;alignas(16)static std::array<uint8_t,4096> snapshot;static bool installed;
 if(!avatar)return @{};
 if(!movement){uintptr_t list=r<uintptr_t>(avatar+0x60);uint32_t count=r<uint32_t>(avatar+0x68);if(count>128)return @{};for(uint32_t i=0;i<count;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c)==main+0xe224a0&&r<uintptr_t>(c+0x20)==avatar)movement=c;}owner=avatar;}
 if(owner!=avatar)return @{@"ownerChanged":@YES};
 if(!original){original=r<uintptr_t>(movement+0x30);if(!MHTControlRead(original,snapshot.data(),snapshot.size()))return @{@"readFailed":@YES};}
 NSDictionary *request=[NSDictionary dictionaryWithContentsOfFile:@"/private/tmp/mht-control/MovementRequest.plist"];
 BOOL enabled=[request[@"enabled"]boolValue];
 if(enabled&&!installed){for(uintptr_t offset:{0x1c,0x3c,0x58,0x70,0xf8}){float value=r<float>(original+offset);if(value>.01f&&value<100){value*=2;memcpy(snapshot.data()+offset,&value,4);}}uintptr_t pointer=(uintptr_t)snapshot.data();installed=MHTControlWrite(movement+0x30,&pointer,8);}
 if(!enabled&&installed&&r<uintptr_t>(movement+0x30)==(uintptr_t)snapshot.data()){MHTControlWrite(movement+0x30,&original,8);installed=false;}
 return @{@"installed":@(installed),@"configuration":@(r<uintptr_t>(movement+0x30)),@"original":@(original),@"nativeLimit":@(r<float>(movement+0x2b4)),@"originalCombat":@(r<float>(original+0x1c)),@"snapshotCombat":@(r<float>((uintptr_t)snapshot.data()+0x1c))};
}
