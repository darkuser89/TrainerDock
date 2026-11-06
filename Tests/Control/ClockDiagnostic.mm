// SPDX-License-Identifier: GPL-3.0-only
// Native simulation delta candidate; heap vtable data only, no code patching.
#import "ControlEngine.h"
#include <array>
static void (*before)(void*,float);static void **original;static void *owner;static std::array<void*,12> table;static bool installed;
static void update(void *server,float dt){before(server,dt*.5f);}
extern "C" NSDictionary *MHTControlNativeDiagnostic(uintptr_t core,uintptr_t main,void *server,uintptr_t avatar){
 (void)core;(void)main;if(!avatar)return @{};
 NSDictionary *request=[NSDictionary dictionaryWithContentsOfFile:@"/private/tmp/mht-control/ClockRequest.plist"];BOOL enabled=[request[@"enabled"]boolValue];
 if(enabled&&!installed){void **vt=nullptr;if(MHTControlRead((uintptr_t)server,&vt,8)&&MHTControlRead((uintptr_t)vt-16,table.data(),96)){before=(void(*)(void*,float))table[9];table[9]=(void*)&update;original=vt;owner=server;void **pointer=table.data()+2;installed=MHTControlWrite((uintptr_t)server,&pointer,8);}}
 if(!enabled&&installed&&owner==server){void **pointer=nullptr;if(MHTControlRead((uintptr_t)server,&pointer,8)&&pointer==table.data()+2)MHTControlWrite((uintptr_t)server,&original,8);installed=false;}
 return @{@"simulationDeltaHalved":@(installed)};
}
