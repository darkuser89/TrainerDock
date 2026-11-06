// SPDX-License-Identifier: GPL-3.0-only
#import "ControlMovement.h"
#import "ControlEngine.h"
#include <array>
#include <vector>
#include <cmath>
#include <dlfcn.h>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
struct alignas(16) Configuration {std::array<uint8_t,4096> bytes;};
// Native readers may briefly retain a configuration address. Retired snapshots
// stay mapped until process exit, bounded to 32 owner changes (128 KiB).
static std::vector<std::unique_ptr<Configuration>> retained;
struct MHTControlMovement::State {uintptr_t avatar=0,movement=0,original=0;uint64_t gid=0;Configuration *copy=nullptr;bool installed=false;std::array<float,5> baseline{};};
MHTControlMovement::MHTControlMovement():state(new State){}
MHTControlMovement::~MHTControlMovement()=default;
static constexpr uintptr_t offsets[]={0x1c,0x3c,0x58,0x70,0xf8};
void MHTControlMovement::release(){
    if(!MHTControlOnEngineFrame())return;auto &s=*state;
    uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE");void *map=(void*)r<uintptr_t>(global);
    auto resolve=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");
    if(s.copy&&map&&resolve&&(uintptr_t)resolve(map,&s.gid)==s.avatar&&r<uintptr_t>(s.movement+0x20)==s.avatar
        &&r<uintptr_t>(s.movement)==MHTControlAddress(MHTControlMovementVT)&&r<uintptr_t>(s.movement+0x30)==(uintptr_t)s.copy->bytes.data())
        MHTControlWrite(s.movement+0x30,&s.original,8);
    s.installed=false;
}
bool MHTControlMovement::update(uintptr_t avatar,uintptr_t movement,bool wanted,double factor){
    if(!MHTControlOnEngineFrame()||!MHTControlEngineIdentity())return false;
    if(!wanted){release();return false;}
    if(!avatar||!movement||!std::isfinite(factor)||factor<1||factor>4)return false;
    auto &s=*state;if(s.avatar!=avatar||s.movement!=movement||s.gid!=r<uint64_t>(avatar+0x10)){release();s=State{};}
    if(!s.copy){if(retained.size()>=32)return false;uintptr_t original=r<uintptr_t>(movement+0x30);auto copy=std::make_unique<Configuration>();
        if(!MHTControlRead(original,copy->bytes.data(),copy->bytes.size()))return false;
        for(size_t i=0;i<5;i++){float value=r<float>(original+offsets[i]);if(!std::isfinite(value)||value<.01f||value>100)return false;s.baseline[i]=value;}
        s.avatar=avatar;s.gid=r<uint64_t>(avatar+0x10);s.movement=movement;s.original=original;s.copy=copy.get();retained.push_back(std::move(copy));
    }
    uintptr_t current=r<uintptr_t>(movement+0x30),pointer=(uintptr_t)s.copy->bytes.data();
    if(current!=s.original&&current!=pointer){release();s=State{};return false;}
    if(!s.installed){
        if(current!=s.original||!MHTControlRead(s.original,s.copy->bytes.data(),s.copy->bytes.size()))return false;
        for(size_t i=0;i<5;i++){float value=r<float>(s.original+offsets[i]);if(!std::isfinite(value)||value<.01f||value>100)return false;s.baseline[i]=value;}
    }
    for(size_t i=0;i<5;i++){float value=s.baseline[i]*(float)factor;memcpy(s.copy->bytes.data()+offsets[i],&value,4);}
    // Original content is unchanged. Only this avatar's state points at the
    // private snapshot consumed by MovementSystem's native update functions.
    s.installed=MHTControlWrite(movement+0x30,&pointer,8)&&r<uintptr_t>(movement+0x30)==pointer;return s.installed;
}
