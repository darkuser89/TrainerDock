// SPDX-License-Identifier: GPL-3.0-only
#import "ControlCombat.h"
#import "ControlEngine.h"
#include <dlfcn.h>
#include <map>
#include <cmath>
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
static uintptr_t component(uintptr_t owner,uintptr_t vt){uintptr_t list=r<uintptr_t>(owner+0x60);uint32_t n=r<uint32_t>(owner+0x68);if(n<=128)for(uint32_t i=0;i<n;i++){uintptr_t c=r<uintptr_t>(list+8*i);if(r<uintptr_t>(c)==vt&&r<uintptr_t>(c+0x20)==owner)return c;}return 0;}
namespace {
struct Target {uintptr_t object,component,model;float previous;};
}
struct MHTControlCombat::State {uintptr_t avatar=0,node=0;uint64_t gid=0;bool confirmed=false;std::map<uint64_t,Target> targets;};
MHTControlCombat::MHTControlCombat():state(new State){}
MHTControlCombat::~MHTControlCombat()=default;
void MHTControlCombat::reset(){*state=State{};}
MHTControlCombatResult MHTControlCombat::update(uintptr_t avatar,bool wanted){
    MHTControlCombatResult out;if(!wanted||!avatar||!MHTControlOnEngineFrame()||!MHTControlEngineIdentity()){reset();return out;}
    auto &s=*state;uint64_t owner=r<uint64_t>(avatar+0x10);if(s.avatar!=avatar||s.gid!=owner){reset();s.avatar=avatar;s.gid=owner;s.node=avatar+0x38;}
    auto hostile=(bool(*)(void*,const uint64_t*,int))dlsym(RTLD_DEFAULT,"_ZN6bonsai21TargetPickerComponent12isAggressiveERKN1r8GlobalIDEN7content7FactionE");
    uintptr_t fv=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZTVN6bonsai21FactionComponentStateE");if(!hostile||!fv)return out;fv+=16;
    uintptr_t faction=component(avatar,fv);int team=r<int>(faction+0x40);if(!faction||team<0||team>=12)return out;
    uintptr_t entityVT=r<uintptr_t>(avatar);
    for(unsigned i=0;s.node&&i<128;i++){
        uintptr_t object=s.node-0x38;s.node=r<uintptr_t>(s.node+0x10);
        if(object==avatar||r<uintptr_t>(object)!=entityVT)continue;
        uintptr_t health=component(object,MHTControlAddress(MHTControlHealthVT)),model=r<uintptr_t>(health+0x50);float amount=r<float>(model+0x94);int maximum=r<int>(model+0xb8);
        if(!health||!model||maximum<=0||maximum>100000000||!std::isfinite(amount)||amount<=0||amount>1)continue;
        uint64_t gid=r<uint64_t>(object+0x10);if(!component(object,fv)||!hostile(nullptr,&gid,team))continue;
        if(s.targets.size()<128&&!s.targets.count(gid))s.targets.emplace(gid,Target{object,health,model,amount});
    }
    if(!s.node)s.node=avatar+0x38;
    uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE");void *map=(void*)r<uintptr_t>(global);
    auto resolve=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");if(!map||!resolve)return out;
    for(auto it=s.targets.begin();it!=s.targets.end();){uint64_t gid=it->first;Target &t=it->second;uintptr_t object=(uintptr_t)resolve(map,&gid);
        if(object!=t.object||component(object,MHTControlAddress(MHTControlHealthVT))!=t.component||r<uintptr_t>(t.component+0x50)!=t.model||!hostile(nullptr,&gid,team)){it=s.targets.erase(it);continue;}
        float current=r<float>(t.model+0x94);int maximum=r<int>(t.model+0xb8);
        if(!std::isfinite(current)||current<=0||current>1||maximum<=0||maximum>100000000){it=s.targets.erase(it);continue;}
        // React only to damage that the original simulation has accepted.
        // Friendlies, untouched enemies and fully absorbed shield hits remain unchanged.
        if(current>0&&current+0.000001f<t.previous){((void(*)(void*,float,bool))(MHTControlAddress(MHTControlHealthNormalized)))((void*)t.model,0.f,false);current=r<float>(t.model+0x94);if(current==0)s.confirmed=true;}
        t.previous=current;++it;
    }
    out.targets=s.targets.size();out.available=out.targets>0;out.confirmed=s.confirmed;return out;
}
