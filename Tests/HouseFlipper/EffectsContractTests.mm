// SPDX-License-Identifier: GPL-3.0-only
// Synthetic Mono boundary; includes and executes the actual product effect paths.
#import <Foundation/Foundation.h>
#include "../../Modules/house-flipper/Sources/HouseFlipperMono.hpp"
#include <map>
#include <array>
#include <cassert>
#include <cstring>
namespace fixture {
struct Field {std::string name;int kind;};
struct Klass {std::string name;Klass *parent=nullptr;std::map<std::string,Field> fields;};
struct Obj {Klass *klass;std::map<std::string,double> numbers;std::map<std::string,void *> refs;};
struct Method {uint32_t token;};
static Klass manager{"GameManager",nullptr,{}},player{"PlayerController",nullptr,{}},progress{"PlayerProgress",nullptr,{}},moneyBase{"Money",nullptr,{}},money{"MoneyProgress",&moneyBase,{}},skills{"Skills",nullptr,{}},category{"SkillCategory",nullptr,{}},info{"SkillInfo",nullptr,{}};
static Obj g{&manager,{{"wasGameStarted",1}},{}},p{&player,{},{}},pr{&progress,{},{}},cash{&money,{{"_money",1234.75}},{}},s{&skills,{}, {}};
static std::array<Obj,11> cats,infos;
static std::map<uint32_t,void *> roots;static uint32_t next=0;static unsigned reads=0,writes=0,calls=0,setterCalls=0,availabilityCalls=0;static bool frame=true,denyReadback=false;
static Method singleton{0x06022B28},setter{0x06004D06},available{0x06020398};
static Klass *named(const char *name){for(Klass *k:{&manager,&player,&progress,&moneyBase,&money,&skills,&category,&info})if(k->name==name)return k;throw std::runtime_error("Unknown synthetic class");}
static void setup(){manager.fields.emplace("wasGameStarted",Field{"wasGameStarted",2});moneyBase.fields.emplace("_money",Field{"_money",13});category.fields.emplace("enabled",Field{"enabled",2});category.fields.emplace("numberOfPerksAvailable",Field{"numberOfPerksAvailable",8});category.fields.emplace("skillType",Field{"skillType",8});info.fields.emplace("skillType",Field{"skillType",8});g.refs["player"]=&p;p.refs["progress"]=&pr;pr.refs={{"moneyProgress",&cash},{"skills",&s}};static const char *names[]={"cleaning","demolition","painting","building","design","negotiation","handyman","gardener","farmer","architect","restaurateur"};for(size_t i=0;i<cats.size();++i){infos[i]={&info,{{"skillType",(double)i}}, {}};cats[i]={&category,{{"enabled",1},{"_liveAvailable",1},{"skillType",(double)i},{"numberOfPerksAvailable",(double)(i%3)}},{{"playerProgress",&pr},{"skillInfo",&infos[i]}}};s.refs[names[i]]=&cats[i];}}
}
namespace hf {
API api={};
void *domain(){return &fixture::g;}
Klass type(const char *,const char *name,const char *){return fixture::named(name);}
Field field(Klass c,const char *name){for(auto *k=(fixture::Klass *)c;k;k=k->parent){auto i=k->fields.find(name);if(i!=k->fields.end())return &i->second;}throw std::runtime_error("Unknown synthetic field");}
Method typedMethod(Klass c,const char *name,const char *result,std::initializer_list<const char *> parameters,bool isStatic){assert(c==&fixture::manager && strcmp(name,"get_Instance")==0 && strcmp(result,"Code.GameManagers.GameManager")==0 && !parameters.size() && isStatic);return &fixture::singleton;}
Method tokenMethod(Klass c,uint32_t token,const char *result,std::initializer_list<const char *> parameters,bool isStatic){if(token==0x06020398){assert(c==&fixture::category && strcmp(result,"System.Boolean")==0 && !parameters.size() && !isStatic);return &fixture::available;}assert(c==&fixture::moneyBase && token==0x06004D06 && strcmp(result,"System.Void")==0 && parameters.size()==1 && strcmp(*parameters.begin(),"System.Double")==0 && !isStatic);return &fixture::setter;}
Object call(Method method,Object owner,std::vector<void *> args){fixture::calls++;if(method==&fixture::singleton)return &fixture::g;if(method==&fixture::available){fixture::availabilityCalls++;static uint8_t result;result=((fixture::Obj *)owner)->numbers["_liveAvailable"]!=0;return &result;}assert(method==&fixture::setter && owner && args.size()==1);fixture::setterCalls++;fixture::writes++;if(!fixture::denyReadback)((fixture::Obj *)owner)->numbers["_money"]=*(double *)args[0];return nullptr;}
double unboxNumber(Object object,int kind){assert(kind==2);return *(uint8_t *)object!=0;}
double number(Object object,Klass,const char *name){fixture::reads++;return ((fixture::Obj *)object)->numbers[name];}
int scalarKind(Field f){return ((fixture::Field *)f)->kind;}
std::vector<uint8_t> numeric(Field f,double n){int k=scalarKind(f);std::vector<uint8_t> bytes(k==13?8:k==8?4:1);if(k==13)memcpy(bytes.data(),&n,8);else if(k==8){int32_t v=(int32_t)n;memcpy(bytes.data(),&v,4);}else bytes[0]=n!=0;return bytes;}
std::vector<uint8_t> read(Object o,Klass,Field f){fixture::reads++;return numeric(f,((fixture::Obj *)o)->numbers[((fixture::Field *)f)->name]);}
void write(Object o,Klass,Field f,const std::vector<uint8_t>& bytes){fixture::writes++;if(fixture::denyReadback)return;double n;if(scalarKind(f)==8){int32_t v;memcpy(&v,bytes.data(),4);n=v;}else memcpy(&n,bytes.data(),8);((fixture::Obj *)o)->numbers[((fixture::Field *)f)->name]=n;}
Object ref(Object o,Klass,const char *name){fixture::reads++;if(!o)throw std::runtime_error("Null synthetic reference");auto& r=((fixture::Obj *)o)->refs;auto i=r.find(name);return i==r.end()?nullptr:i->second;}
}
extern "C" BOOL HFInFrame(){return fixture::frame;}
extern "C" BOOL HFEnsureLoop(){return YES;}
extern "C" void HFSetFrameHandler(dispatch_block_t){}
#include "../../Modules/house-flipper/Sources/HouseFlipperEffects.mm"
static void bindFixture(){using namespace fixture;hf::api.objectClass=[](void *o)->void *{return ((Obj *)o)->klass;};hf::api.parent=[](void *k)->void *{return ((fixture::Klass *)k)->parent;};hf::api.flags=[](void *)->uint32_t{return 0;};hf::api.strong=[](void *o,int)->uint32_t{uint32_t h=++next;roots[h]=o;return h;};hf::api.weak=hf::api.strong;hf::api.target=[](uint32_t h)->void *{auto i=roots.find(h);return i==roots.end()?nullptr:i->second;};hf::api.freeHandle=[](uint32_t h){roots.erase(h);};}
int main(){@autoreleasepool{using namespace fixture;setup();bindFixture();
 // Idle frames have no managed callback, field search, reads or writes.
 tick();assert(!reads && !writes && !calls);
 assert([HFInspect()[@"kind"] intValue]==2);
 auto result=HFEffect(0,YES,0);assert([result[@"active"] boolValue] && cash.numbers["_money"]==1000000000.0 && setterCalls==1);
 unsigned stableWrites=writes;uint32_t stableHandles=next;for(int i=0;i<30;++i)HFEffect(0,YES,0);assert(writes==stableWrites && next==stableHandles);tick();assert(writes==stableWrites && next==stableHandles);
 cash.numbers["_money"]-=125.25;tick();assert(cash.numbers["_money"]==1000000000.0 && setterCalls==2);
 HFEffect(0,NO,0);assert(cash.numbers["_money"]==1234.75 && setterCalls==3);
 // High foreign values are never reduced, including when releasing the feature.
 HFEffect(0,YES,0);cash.numbers["_money"]=1000000050.5;tick();HFEffect(0,NO,0);assert(cash.numbers["_money"]==1000000050.5);
 cash.numbers["_money"]=700;HFEffect(0,YES,0);cash.numbers["_money"]=650;HFEffect(0,NO,0);assert(cash.numbers["_money"]==650);
 // Original dynamic availability overrides stale snapshots/null legacy backlinks.
 cats[0].numbers["enabled"]=0;cats[0].refs["playerProgress"]=nullptr;cats[10].numbers["_liveAvailable"]=0;infos[9].numbers["skillType"]=99;
 result=HFEffect(1,YES,0);assert([result[@"active"] boolValue]);for(size_t i=0;i<9;++i)assert(cats[i].numbers["numberOfPerksAvailable"]==9);assert(cats[9].numbers["numberOfPerksAvailable"]==0 && cats[10].numbers["numberOfPerksAvailable"]==1);
 stableWrites=writes;stableHandles=next;unsigned stableAvailability=availabilityCalls;for(int i=0;i<30;++i){HFEffect(1,YES,0);tick();}assert(writes==stableWrites && next==stableHandles && availabilityCalls==stableAvailability);
 cats[0].numbers["numberOfPerksAvailable"]=8;tick();assert(cats[0].numbers["numberOfPerksAvailable"]==9);HFEffect(1,NO,0);for(size_t i=0;i<9;++i)assert(cats[i].numbers["numberOfPerksAvailable"]==(double)(i%3));
 HFEffect(1,YES,0);cats[1].numbers["numberOfPerksAvailable"]=17;tick();HFRelease();assert(cats[1].numbers["numberOfPerksAvailable"]==17);
 // Replacing a category within the same progress releases its old owned points.
 Obj replacement{&fixture::category,{{"enabled",0},{"_liveAvailable",1},{"skillType",0},{"numberOfPerksAvailable",2}},{{"playerProgress",nullptr},{"skillInfo",&infos[0]}}};HFEffect(1,YES,0);s.refs["cleaning"]=&replacement;tick();assert(cats[0].numbers["numberOfPerksAvailable"]==0 && replacement.numbers["numberOfPerksAvailable"]==9 && state().leases.size()<=11);HFEffect(1,NO,0);assert(replacement.numbers["numberOfPerksAvailable"]==2);s.refs["cleaning"]=&cats[0];
 // Owner changes clear old intent and restore only guarded owned values.
 cash.numbers["_money"]=432.125;HFEffect(0,YES,0);g.refs["player"]=nullptr;tick();assert(!state().wanted[0] && !state().active[0] && cash.numbers["_money"]==432.125);g.refs["player"]=&p;
 // A setter that rejects the value cannot report success.
 denyReadback=true;result=HFEffect(0,YES,0);assert(![result[@"active"] boolValue]);denyReadback=false;HFRelease();
 // Main menu and off-thread delivery must never write player values.
 g.numbers["wasGameStarted"]=0;stableWrites=writes;result=HFEffect(0,YES,0);assert(![result[@"available"] boolValue] && writes==stableWrites);g.numbers["wasGameStarted"]=1;frame=false;assert(![HFEffect(0,YES,0)[@"available"] boolValue] && HFPlayerForInput()==nullptr);frame=true;
 HFRelease();reads=writes=calls=0;tick();assert(!reads && !writes && !calls);
 puts("PASS: House Flipper actual product money setter/Double precision, all enabled perk categories, readback rejection, ownership/foreign changes, idle and unchanged polls; no game started.");
}}
