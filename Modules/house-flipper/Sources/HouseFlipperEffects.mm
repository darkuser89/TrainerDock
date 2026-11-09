// SPDX-License-Identifier: GPL-3.0-only
#import "HouseFlipperEffects.h"
#import "HouseFlipperLoop.h"
#include "HouseFlipperMono.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <sstream>
namespace {
using namespace hf;
constexpr double moneyMinimum=1000000000.0;
constexpr int perkMinimum=9;
constexpr std::array<const char *,11> categories={"cleaning","demolition","painting","building","design","negotiation","handyman","gardener","farmer","architect","restaurateur"};
struct Context {Object player=nullptr,progress=nullptr,money=nullptr,skills=nullptr;int kind=1;std::string identity="menu";};
struct Lease {Root owner;Field field=nullptr;double before=0,last=0;bool money=false,owned=false;};
// Reuse a bounded rooted snapshot; unchanged polls/frames allocate no GC handles.
struct CategoryCache {Root owner,info;bool available=false;};
struct Backend {Context context;Root manager,player,progress,money,skills;std::array<CategoryCache,11> categoryOwners;std::array<bool,2> wanted{},active{};std::vector<Lease> leases;NSString *failure=nil;NSTimer *retry=nil;};
Backend& state(){static Backend *b=new Backend;return *b;}
Klass game(const char *name){return type("",name);}
bool is(Object o,Klass expected){if(!o || !expected)return false;for(Klass k=api.objectClass(o);k;k=api.parent(k))if(k==expected)return true;return false;}
Object reference(Object o,Klass owner,const char *name,Klass expected){Object r=ref(o,owner,name);if(r && !is(r,expected))throw std::runtime_error("Ursprünglicher Referenztyp stimmt nicht überein.");return r;}
Field scalar(Klass k,const char *name,int expected){Field f=field(k,name);if(!f || scalarKind(f)!=expected || (api.flags(f)&0x10))throw std::runtime_error("Ursprünglicher Feldtyp stimmt nicht überein.");return f;}
double current(Object o,Field f){auto bytes=read(o,api.objectClass(o),f);if(scalarKind(f)==13){if(bytes.size()!=sizeof(double))throw std::runtime_error("Ungültiger Geldwert.");double v;memcpy(&v,bytes.data(),sizeof(v));return v;}if(scalarKind(f)==8){if(bytes.size()!=sizeof(int32_t))throw std::runtime_error("Ungültiger Punktewert.");int32_t v;memcpy(&v,bytes.data(),sizeof(v));return v;}throw std::runtime_error("Nicht unterstützter ursprünglicher Wertetyp.");}
void set(Object o,Field f,double value,bool money){if(money){if(!std::isfinite(value) || value<0)throw std::runtime_error("Ungültiger Geldbetrag.");/* The verified Money setter is nonvirtual and raises the original currency event. */Method setter=tokenMethod(game("Money"),0x06004D06,"System.Void",{"System.Double"},false);double v=value;call(setter,o,{&v});}else write(o,api.objectClass(o),f,numeric(f,value));}
void retain(Root& root,Object object){if(root.get()!=object)root.reset(object);}
Context capture(){Context c;Backend& b=state();Klass manager=type("Code.GameManagers","GameManager");Method getter=typedMethod(manager,"get_Instance","Code.GameManagers.GameManager",{},true);retain(b.manager,call(getter));if(!b.manager.get())return c;Field started=scalar(manager,"wasGameStarted",2);auto startedValue=read(b.manager.get(),manager,started);if(startedValue.size()!=1 || !startedValue[0])return c;retain(b.player,reference(b.manager.get(),manager,"player",type("Assets.Code.Player","PlayerController")));if(!b.player.get())return c;retain(b.progress,reference(b.player.get(),api.objectClass(b.player.get()),"progress",game("PlayerProgress")));if(!b.progress.get())return c;retain(b.money,reference(b.progress.get(),game("PlayerProgress"),"moneyProgress",game("MoneyProgress")));retain(b.skills,reference(b.progress.get(),game("PlayerProgress"),"skills",game("Skills")));if(!b.money.get() || !b.skills.get())return c;scalar(game("Money"),"_money",13);c.player=b.player.get();c.progress=b.progress.get();c.money=b.money.get();c.skills=b.skills.get();c.kind=2;std::ostringstream id;id<<domain()<<'/'<<c.player<<'/'<<c.progress<<'/'<<c.money<<'/'<<c.skills;c.identity=id.str();return c;}
void restore(bool moneyOnly){Backend& b=state();for(auto i=b.leases.begin();i!=b.leases.end();){if(i->money!=moneyOnly){++i;continue;}Root owner(i->owner.get());if(owner.get() && i->owned && current(owner.get(),i->field)==i->last)set(owner.get(),i->field,i->before,i->money);i=b.leases.erase(i);}if(!moneyOnly)for(auto& category:b.categoryOwners){category.owner.reset();category.info.reset();category.available=false;}}
void restoreCategory(Object previous){Backend& b=state();for(auto i=b.leases.begin();i!=b.leases.end();){if(i->money || i->owner.get()!=previous){++i;continue;}if(previous && i->owned && current(previous,i->field)==i->last)set(previous,i->field,i->before,false);i=b.leases.erase(i);}}
void release(){restore(true);restore(false);state().active.fill(false);}
void refresh(){Backend& b=state();Context c=capture();if(c.identity!=b.context.identity){release();b.wanted.fill(false);}b.context=std::move(c);if(b.context.kind!=2){release();b.wanted.fill(false);b.player.reset();b.progress.reset();b.money.reset();b.skills.reset();}}
bool minimum(Object owner,Field f,double target,bool money){Backend& b=state();double now=current(owner,f);if(!std::isfinite(now) || now<0)throw std::runtime_error("Das Spiel liefert einen ungültigen Ressourcenwert.");auto it=std::find_if(b.leases.begin(),b.leases.end(),[&](const Lease& l){return l.owner.get()==owner && l.field==f;});if(it==b.leases.end()){Lease l;l.owner.reset(owner,true);l.field=f;l.before=now;l.last=now;l.money=money;b.leases.push_back(std::move(l));it=std::prev(b.leases.end());}else if(now>it->last){it->before=now;it->owned=false;}if(now<target){set(owner,f,target,money);it->last=target;it->owned=true;}else it->last=now;return current(owner,f)>=target;}
// PerksView 0x060367C3 filters its tabs through this original getter. The
// serialized `enabled` snapshot and unused playerProgress backlink are not its
// authority. Active progress -> Skills -> category plus typed SkillInfo is.
Object category(size_t index,bool refreshAvailability){
    Backend& b=state();auto& slot=b.categoryOwners[index];
    Klass k=type("Assets.Code.Player_progress","SkillCategory");
    Klass infoClass=type("Empyrean.HouseFlipper.Tablet.PerkView","SkillInfo");
    Object o=reference(b.skills.get(),game("Skills"),categories[index],k);
    Object info=o?reference(o,k,"skillInfo",infoClass):nullptr;
    bool changed=slot.owner.get()!=o || slot.info.get()!=info;
    if(changed){restoreCategory(slot.owner.get());retain(slot.owner,o);retain(slot.info,info);slot.available=false;}
    if(!slot.owner.get() || !slot.info.get())return nullptr;
    scalar(k,"numberOfPerksAvailable",8);
    if(scalarKind(field(k,"skillType"))!=8 || scalarKind(field(infoClass,"skillType"))!=8
       || number(slot.owner.get(),k,"skillType")!=number(slot.info.get(),infoClass,"skillType")){
        restoreCategory(slot.owner.get());slot.available=false;return nullptr;
    }
    if(changed || refreshAvailability){
        Method available=tokenMethod(k,0x06020398,"System.Boolean",{},false);
        bool confirmed=unboxNumber(call(available,slot.owner.get()),2)!=0;
        if(!confirmed && slot.available)restoreCategory(slot.owner.get());
        slot.available=confirmed;
    }
    return slot.available?slot.owner.get():nullptr;
}
void apply(NSInteger feature){Backend& b=state();b.active[feature]=false;if(!b.wanted[feature]){restore(feature==0);return;}if(b.context.kind!=2)return;if(!b.progress.get() || !b.money.get() || !b.skills.get())return;if(feature==0)b.active[0]=minimum(b.money.get(),scalar(game("Money"),"_money",13),moneyMinimum,true);else{bool ok=true;size_t count=0;for(size_t i=0;i<categories.size();++i){if(Object c=category(i,false)){++count;ok=minimum(c,scalar(api.objectClass(c),"numberOfPerksAvailable",8),perkMinimum,false)&&ok;}}b.active[1]=count>0&&ok;}}
void tick(){if(!HFInFrame())return;Backend& b=state();if(std::none_of(b.wanted.begin(),b.wanted.end(),[](bool v){return v;}) && b.leases.empty())return;try{refresh();for(NSInteger f=0;f<2;++f)if(b.wanted[f])apply(f);b.failure=nil;}catch(const std::exception& e){b.failure=@(e.what());b.wanted.fill(false);try{release();}catch(...){}b.active.fill(false);}}
NSDictionary *failed(NSString *note){return @{@"available":@NO,@"active":@NO,@"note":note};}
}
void HFStartBackend(){Backend& b=state();HFSetFrameHandler(^{tick();});if(!b.retry){b.retry=[NSTimer timerWithTimeInterval:.5 repeats:YES block:^(NSTimer *timer){(void)timer;HFEnsureLoop();}];[NSRunLoop.mainRunLoop addTimer:b.retry forMode:NSRunLoopCommonModes];}HFEnsureLoop();}
NSDictionary *HFInspect(){if(!HFInFrame())return @{@"kind":@0,@"identity":@"off-thread",@"note":@"Kein nativer Unity-Rückruf."};try{refresh();Backend& b=state();if(b.context.kind==2 && b.wanted[1])for(size_t i=0;i<categories.size();++i)(void)category(i,true);return @{@"kind":@(b.context.kind),@"identity":@(b.context.identity.c_str()),@"note":b.failure?:(b.context.kind==2?@"Aktueller Spieler und Fortschritt bestätigt.":@"Warte auf einen geladenen Spielstand.")};}catch(const std::exception& e){return @{@"kind":@0,@"identity":@"binding-error",@"note":@(e.what())};}}
NSDictionary *HFEffect(NSInteger f,BOOL wanted,double value){(void)value;if(!HFInFrame() || f<0 || f>=2)return failed(@"Ungültige native Zustellung.");try{refresh();Backend& b=state();bool available=b.context.kind==2;bool next=wanted&&available;bool changed=b.wanted[f]!=next;b.wanted[f]=next;if(changed)apply(f);return @{@"available":@(available),@"active":@(b.active[f]),@"note":available?(b.active[f]?@"Ressource im Spiel zurückgelesen.":wanted?@"Warte auf einen geeigneten Spielzustand.":@"Aus."):@"Warte auf einen geladenen Spielstand."};}catch(const std::exception& e){return failed(@(e.what()));}}
void HFRelease(){if(!HFInFrame())return;Backend& b=state();b.wanted.fill(false);try{release();}catch(const std::exception& e){b.failure=@(e.what());b.active.fill(false);}}
void *HFPlayerForInput(){if(!HFInFrame())return nullptr;try{refresh();return state().player.get();}catch(...){return nullptr;}}
NSDictionary *HFValues(){if(!HFInFrame())return @{};try{refresh();Backend& b=state();NSMutableDictionary *v=[@{@"kind":@(b.context.kind),@"identity":@(b.context.identity.c_str())} mutableCopy];if(b.context.kind==2){v[@"money"]=@(current(b.money.get(),scalar(game("Money"),"_money",13)));NSMutableDictionary *perks=[NSMutableDictionary new];for(size_t i=0;i<categories.size();++i)if(Object c=category(i,true))perks[@(categories[i])]=@(current(c,scalar(api.objectClass(c),"numberOfPerksAvailable",8)));v[@"perks"]=perks;v[@"enabledCategories"]=@(perks.count);}return v;}catch(const std::exception& e){return @{@"error":@(e.what())};}}
