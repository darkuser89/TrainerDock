// SPDX-License-Identifier: GPL-3.0-only
// Authorized live-process diagnostics only. Never shipped with the trainer.
#import "ControlEngine.h"
#import "ControlMovement.h"
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static uintptr_t component(uintptr_t owner,uintptr_t vt){uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t count=r<uint32_t>(owner+0x68);if(count<=128)for(uint32_t i=0;i<count;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c)==vt&&r<uintptr_t>(c+0x20)==owner)return c;}return 0;}
extern "C" NSDictionary *MHTControlNativeDiagnostic(uintptr_t core,uintptr_t main,void *server,uintptr_t avatar){
 (void)core;(void)server;uintptr_t health=component(avatar,main+0xe094a8),energy=component(avatar,main+0xdd0438),inventory=component(avatar,main+0xe0a6e0),assist=component(avatar,main+0xe2c698),movement=component(avatar,main+0xe224a0);
 if(!health||!energy||!inventory||!assist||!movement)return @{};
 NSMutableDictionary *out=[@{@"healthReason":@(r<uint32_t>(health+0x5c)),@"energyUnlimited":@(r<uint8_t>(energy+0x139)),@"ammoUnlimited":@(r<uint8_t>(inventory+0x2ac)),@"oneHit":@(r<uint8_t>(assist+0xb0)),@"simulationRate":@(MHTControlSimulationRate())}mutableCopy];
 static NSDictionary *cycles;
 if(!cycles&&!r<uint8_t>(energy+0x139)&&!r<uint8_t>(inventory+0x2ac)&&!r<uint8_t>(assist+0xb0)){
  MHTControlMovement speed;uintptr_t before=r<uintptr_t>(movement+0x30);unsigned successes=0;
  for(unsigned i=0;i<40;i++){if(speed.update(avatar,movement,true,2))successes++;speed.release();if(r<uintptr_t>(movement+0x30)!=before)break;}
  cycles=@{@"successfulCycles":@(successes),@"originalConfigurationRestored":@(r<uintptr_t>(movement+0x30)==before)};
 }
 if(cycles)out[@"movementToggleTest"]=cycles;return out;
}
