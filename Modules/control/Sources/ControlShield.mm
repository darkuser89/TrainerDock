// SPDX-License-Identifier: GPL-3.0-only
#import "ControlShield.h"
#import "ControlEngine.h"
#include <dlfcn.h>
#include <map>
#include <cmath>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static uintptr_t component(uintptr_t owner,uintptr_t vtable){uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t count=r<uint32_t>(owner+0x68);if(count>128)return 0;for(uint32_t i=0;i<count;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c)==vtable&&r<uintptr_t>(c+0x20)==owner)return c;}return 0;}
namespace {
struct Target {uintptr_t object,armor,model;float previous;};
}
struct MHTControlShield::State {uintptr_t owner=0,node=0;uint64_t gid=0;bool confirmed=false;std::map<uint64_t,Target> targets;};
MHTControlShield::MHTControlShield():state(new State){}
MHTControlShield::~MHTControlShield()=default;
void MHTControlShield::reset(){*state=State{};}
MHTControlShieldResult MHTControlShield::update(uintptr_t avatar,bool wanted){
    MHTControlShieldResult out;if(!wanted||!avatar||!MHTControlOnEngineFrame()||!MHTControlEngineIdentity()){reset();return out;}
    auto &s=*state;uint64_t owner=r<uint64_t>(avatar+0x10);if(s.owner!=avatar||s.gid!=owner){reset();s.owner=avatar;s.gid=owner;s.node=avatar+0x38;}
    // The native implementation does not dereference this; it resolves the target
    // GlobalID and reads the engine's faction hostility matrix (bonsai 1d0014).
    auto aggressive=(bool(*)(void*,const uint64_t*,int))dlsym(RTLD_DEFAULT,"_ZN6bonsai21TargetPickerComponent12isAggressiveERKN1r8GlobalIDEN7content7FactionE");
    uintptr_t factionVT=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZTVN6bonsai21FactionComponentStateE");if(!aggressive||!factionVT)return out;factionVT+=16;
    uintptr_t faction=component(avatar,factionVT);int playerFaction=r<int>(faction+0x40);if(!faction||playerFaction<0||playerFaction>=12)return out;
    uintptr_t entityVT=r<uintptr_t>(avatar);
    // Incremental traversal avoids a full world scan every frame. The native
    // intrusive node is GameObjectState+0x38; node+0x10 links forward.
    for(unsigned i=0;s.node&&i<128;i++){
        uintptr_t node=s.node,object=node-0x38;s.node=r<uintptr_t>(node+0x10);
        if(r<uintptr_t>(object)!=entityVT||object==avatar)continue;
        uintptr_t armor=component(object,MHTControlAddress(MHTControlArmorVT)),model=r<uintptr_t>(armor+0x38);int maximum=r<int>(model+0xb8);float health=r<float>(model+0x94);
        if(!armor||!model||maximum<=0||maximum>100000000||!std::isfinite(health)||health<=0||health>1)continue;
        uint64_t gid=r<uint64_t>(object+0x10);if(!component(object,factionVT)||!aggressive(nullptr,&gid,playerFaction))continue;
        if(s.targets.size()<128&&!s.targets.count(gid))s.targets.emplace(gid,Target{object,armor,model,health});
    }
    if(!s.node)s.node=avatar+0x38;
    uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE");void *map=(void*)r<uintptr_t>(global);
    auto resolve=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");if(!map||!resolve)return out;
    for(auto it=s.targets.begin();it!=s.targets.end();){uint64_t gid=it->first;Target &target=it->second;uintptr_t object=(uintptr_t)resolve(map,&gid);
        if(object!=target.object||component(object,MHTControlAddress(MHTControlArmorVT))!=target.armor||r<uintptr_t>(target.armor+0x38)!=target.model
            ||!aggressive(nullptr,&gid,playerFaction)){it=s.targets.erase(it);continue;}
        float current=r<float>(target.model+0x94);int maximum=r<int>(target.model+0xb8);
        if(!std::isfinite(current)||current<=0||current>1||maximum<=0||maximum>100000000){it=s.targets.erase(it);continue;}
        if(current>0&&current+0.000001f<target.previous){
            // Damage has actually reached a hostile shield. Preserve the owner's
            // body health and let the original Health model emit its death event.
            ((void(*)(void*,float,bool))(MHTControlAddress(MHTControlHealthNormalized)))((void*)target.model,0.f,false);
            current=r<float>(target.model+0x94);if(current==0)s.confirmed=true;
        }
        target.previous=current;++it;
    }
    out.targets=s.targets.size();out.available=out.targets>0;out.confirmed=s.confirmed;return out;
}
