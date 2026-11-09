// SPDX-License-Identifier: GPL-3.0-only
// Exercises the product effect/ownership paths with a synthetic IL2CPP boundary.
#import <Foundation/Foundation.h>
#include <map>
#include <string>
#include <vector>
#include <cassert>
#include <cstring>
#include <stdexcept>
#include "../../Modules/prodeus/Sources/ProdeusEngine.hpp"
namespace fixture {
struct Type {std::string name;int kind;};
struct Field {std::string name;Type *type;bool isStatic=false;};
struct Klass {std::string name;std::map<std::string,Field> fields;};
struct Obj {Klass *klass;std::map<std::string,double> numbers;std::map<std::string,void *> refs;};
struct Method {std::string name;};
static Type boolType{"System.Boolean",2},integer{"System.Int32",8},floating{"System.Single",12},reference{"System.Object",18};
static Klass player{"PlayerEntity",{}},controller{"PlayerControllerFirstPerson",{}},nav{"PlayerNavFirstPerson",{}},info{"GameInfo",{}},input{"InputManager",{}},time{"Time",{}},array{"System.Int32[]",{}},upgrade{"UpgradeItem",{}},network{"NetworkManager",{}},weapon{"FPWStateMachine",{}},weaponsArray{"FPWStateMachine[]",{}};
static Obj p{&player,{{"health",100},{"armor",50},{"alive",1}},{}},c{&controller,{{"haveDoubleJump",0}},{}},n{&nav,{{"canDoubleJump",0},{"jumpCoolDownTimer",.5}},{}},gameObject{&info,{},{}},in{&input,{},{}},clockObject{&time,{{"scale",1}}, {}};
static std::map<std::string,bool> flags;static std::map<std::string,Method> methods;
static std::map<uintptr_t,void *> handles;static uintptr_t next=0;static unsigned writes=0,calls=0,searches=0;
struct IntArray {Obj object;int32_t values[6];};
struct ReferenceArray {Obj object;void *values[6];};
static Obj w0{&weapon,{{"weaponIndex",0},{"clipSize",12},{"ammoClip",7}},{}},w1{&weapon,{{"weaponIndex",1},{"clipSize",4},{"ammoClip",2}}, {}};
static bool frame=true;
static Klass *named(const char *name){for(Klass *k:{&player,&controller,&nav,&info,&input,&time,&array,&upgrade,&network,&weapon,&weaponsArray})if(k->name==name)return k;return nullptr;}
static void field(Klass& k,const char *name,Type *type,bool s=false){k.fields.emplace(name,Field{name,type,s});}
static void setup(){for(Klass *k:{&player,&controller,&nav,&info,&input})field(*k,"instance",&reference,true);for(const char *name:{"inRoom","isCoopMP","isVersusMP","isSoloVersusMP","isTeamVersusMP","editorMode"})field(info,name,&boolType,true);field(player,"health",&integer);field(player,"armor",&integer);field(player,"alive",&boolType);field(controller,"haveDoubleJump",&boolType);field(controller,"updateHud",&boolType);field(controller,"currentWeapon",&integer);for(const char *name:{"weaponIndex","clipSize","ammoClip"})field(weapon,name,&integer);field(nav,"canDoubleJump",&boolType);field(nav,"jumpCoolDownTimer",&floating);field(upgrade,"doubleJump",&integer,true);c.refs={{"playerEntity",&p},{"playerNav",&n}};p.refs={{"playerController",&c}};w0.refs={{"player",&c},{"playerEntity",&p}};w1.refs=w0.refs;}
}
namespace prodeus {
API api={};
Class klass(const char *,const char *,const char *name){return fixture::named(name);}
Method method(Class,const char *name,int){auto& m=fixture::methods[name];m.name=name;return &m;}
Field field(Class c,const char *name){if(!c)return nullptr;auto& f=((fixture::Klass *)c)->fields;auto i=f.find(name);return i==f.end()?nullptr:&i->second;}
std::string typeName(const void *t){return ((const fixture::Type *)t)->name;}
Object reference(Object o,const char *name){if(!o)return nullptr;auto& refs=((fixture::Obj *)o)->refs;auto i=refs.find(name);return i==refs.end()?nullptr:i->second;}
bool boolean(Object o,const char *name){if(!o)throw std::runtime_error("null fixture owner");return ((fixture::Obj *)o)->numbers[name]!=0;}
void boolean(Object o,const char *name,bool value){((fixture::Obj *)o)->numbers[name]=value;fixture::writes++;}
Object call(Method m,Object,const std::vector<Object>&){fixture::calls++;static double result;result=fixture::flags[((const fixture::Method *)m)->name];return &result;}
double number(Object o){return *(double *)o;}
Object numericCall(Method m,Object object,const std::vector<double>& values){fixture::calls++;static double result;std::string name=((const fixture::Method *)m)->name;if(name=="SetHealth")((fixture::Obj *)object)->numbers["health"]=values.at(0),fixture::writes++;else if(name=="SetArmor")((fixture::Obj *)object)->numbers["armor"]=values.at(0),fixture::writes++;else if(name=="get_timeScale")result=fixture::clockObject.numbers["scale"];else if(name=="set_timeScale")fixture::clockObject.numbers["scale"]=values.at(0),fixture::writes++;else if(name=="GiveUpgradeItem"){((fixture::Obj *)object)->numbers["haveDoubleJump"]=1;fixture::writes++;}else if(name=="get_GamePaused")result=fixture::flags["paused"];else if(name=="get_InRoom" || name=="get_OfflineMode")result=fixture::flags[name];else result=0;return &result;}
bool alive(Object o){return o!=nullptr;}
Root::Root(Object o,bool weak){reset(o,weak);}Root::~Root(){reset();}Root::Root(Root&& other)noexcept:handle(other.handle){other.handle=0;}Root& Root::operator=(Root&& other)noexcept{if(this!=&other){reset();handle=other.handle;other.handle=0;}return *this;}Object Root::get()const{return handle?fixture::handles[handle]:nullptr;}void Root::reset(Object o,bool){if(handle)fixture::handles.erase(handle);handle=o?++fixture::next:0;if(o)fixture::handles[handle]=o;}
}
extern "C" BOOL PREnsureLoop(void){return YES;}extern "C" BOOL PRInFrame(void){return fixture::frame;}extern "C" BOOL PREnqueue(dispatch_block_t){return YES;}extern "C" NSDictionary *PRLoopDiagnostics(void){return @{};}extern "C" void PRSetFrameHandler(dispatch_block_t){}
#include "../../Modules/prodeus/Sources/ProdeusEffects.mm"
static void bindFixture(){using namespace fixture;prodeus::api.objectClass=[](void *o)->void *{return ((Obj *)o)->klass;};prodeus::api.domainGet=[]()->void *{return &gameObject;};prodeus::api.fieldFlags=[](void *f){return ((fixture::Field *)f)->isStatic?0x10:0;};prodeus::api.fieldType=[](void *f)->const void *{return ((fixture::Field *)f)->type;};prodeus::api.typeKind=[](const void *t){return ((const Type *)t)->kind;};prodeus::api.fieldRead=[](void *o,void *f,void *out){auto& member=*(fixture::Field *)f;double n=((Obj *)o)->numbers[member.name];if(member.type->kind==2){bool v=n!=0;memcpy(out,&v,1);}else if(member.type->kind==8){int32_t v=(int32_t)n;memcpy(out,&v,4);}else{float v=(float)n;memcpy(out,&v,4);}};prodeus::api.fieldWrite=[](void *o,void *f,void *v){auto& member=*(fixture::Field *)f;double n=member.type->kind==2?*(bool *)v:member.type->kind==8?*(int32_t *)v:*(float *)v;((Obj *)o)->numbers[member.name]=n;writes++;};prodeus::api.staticRead=[](void *f,void *out){auto& member=*(fixture::Field *)f;if(member.name=="instance"){Obj *v=nullptr;if(f==&player.fields.at("instance"))v=&p;if(f==&controller.fields.at("instance"))v=&c;if(f==&nav.fields.at("instance"))v=&n;if(f==&info.fields.at("instance"))v=&gameObject;if(f==&input.fields.at("instance"))v=&in;memcpy(out,&v,sizeof(v));}else if(member.type->kind==8){int32_t v=1;memcpy(out,&v,4);}else{bool v=flags[member.name];memcpy(out,&v,1);}};prodeus::api.methodFlags=[](const void *method,uint32_t *)->uint32_t{std::string name=((const fixture::Method *)method)->name;return name=="SetHealth" || name=="SetArmor" || name=="GiveUpgradeItem" ? 0 : 0x10;};prodeus::api.arrayLength=[](void *)->uintptr_t{return 6;};prodeus::api.elementClass=[](void *klass)->void *{return klass==&weaponsArray?(void *)&weapon:(void *)&integer;};prodeus::api.valueType=[](void *klass){return klass!=&weapon;};prodeus::api.parent=[](void *)->void *{return nullptr;};prodeus::api.classType=[](void *t)->const void *{return t;};prodeus::api.valueSize=[](void *,uint32_t *)->int32_t{return 4;};prodeus::api.arrayHeader=[]()->uint32_t{return offsetof(IntArray,values);};}
int main(){@autoreleasepool{using namespace fixture;setup();bindFixture();
 // Idle frames do not traverse state, box identities or touch game values.
 unsigned beforeCalls=calls;tick();assert(calls==beforeCalls && writes==0 && searches==0);
 assert(solo());flags["inRoom"]=true;assert(solo());flags["inRoom"]=false;for(const char *f:{"isCoopMP","isVersusMP","isSoloVersusMP","isTeamVersusMP","editorMode"}){flags[f]=true;assert(!solo());flags[f]=false;}flags["get_IsMultiplayer"]=true;assert(!solo());flags["get_IsMultiplayer"]=false;flags["get_InRoom"]=true;assert(!solo());flags["get_OfflineMode"]=true;flags["get_IsMultiplayer"]=true;assert(solo());flags["isCoopMP"]=true;assert(!solo());flags["isCoopMP"]=false;flags["get_InRoom"]=false;flags["get_OfflineMode"]=false;flags["get_IsMultiplayer"]=false;assert(solo());
 std::vector<FieldLease> leases;leaseField(&c,"haveDoubleJump",1,leases);assert(boolean(&c,"haveDoubleJump"));unsigned w=writes;leaseField(&c,"haveDoubleJump",1,leases);assert(writes==w);restoreFields(leases);assert(!boolean(&c,"haveDoubleJump"));
 leaseField(&n,"jumpCoolDownTimer",0,leases);n.numbers["jumpCoolDownTimer"]=.2;restoreFields(leases);assert(n.numbers["jumpCoolDownTimer"]==.2); // foreign changes survive
 IntArray a{{&array,{},{}},{3,4,5,6,7,8}};std::vector<ArrayLease> slots;leaseSlot(&a,2,100,slots);assert(a.values[2]==100);w=writes;leaseSlot(&a,2,100,slots);assert(writes==w);restoreArrays(slots);assert(a.values[2]==5);leaseSlot(&a,2,100,slots);a.values[2]=25;restoreArrays(slots);assert(a.values[2]==25);
 bool threw=false;try{arraySlot(&a,6);}catch(const std::exception&){threw=true;}assert(threw);
 // Context transition releases owned changes, clears intent and never writes a new owner.
 state().context=capture();state().wanted[2]=true;leaseField(&c,"haveDoubleJump",1,state().jumps);flags["isCoopMP"]=true;refresh();assert(state().context.kind==0 && !state().wanted[2] && !boolean(&c,"haveDoubleJump"));flags["isCoopMP"]=false;
 state().context=capture();NSDictionary *health=PREffect(0,YES,0);assert([health[@"active"] boolValue] && p.numbers["health"]==200);unsigned stableWrites=writes;uintptr_t stableHandles=next;for(int poll=0;poll<30;poll++){health=PREffect(0,YES,0);assert([health[@"active"] boolValue]);}assert(writes==stableWrites && next==stableHandles);tick();assert(writes==stableWrites && searches==0);PREffect(0,NO,0);
 state().context=capture();state().wanted[12]=true;state().values[12]=2;apply(12);assert(clockObject.numbers["scale"]==2);flags["paused"]=true;clockObject.numbers["scale"]=0;apply(12);assert(clockObject.numbers["scale"]==0);state().wanted[12]=false;apply(12);assert(clockObject.numbers["scale"]==0);flags["paused"]=false;
 // No-reload follows the live weapon, restores only its own clip, and rejects alien owners.
 ReferenceArray live{{&weaponsArray,{},{}},{&w0,&w1,nullptr,nullptr,nullptr,nullptr}};c.refs["fpwInstances"]=&live;c.numbers["currentWeapon"]=0;state().context=capture();state().wanted[11]=true;apply(11);assert(w0.numbers["ammoClip"]==12 && state().active[11]);unsigned clipWrites=writes;apply(11);assert(writes==clipWrites);c.numbers["currentWeapon"]=1;apply(11);assert(w0.numbers["ammoClip"]==7 && w1.numbers["ammoClip"]==4);w1.numbers["ammoClip"]=3;state().wanted[11]=false;apply(11);assert(w1.numbers["ammoClip"]==3);state().wanted[11]=true;w1.refs["player"]=nullptr;apply(11);assert(!state().active[11] && w1.numbers["ammoClip"]==3);state().wanted[11]=false;
 // An explicit permanent upgrade must survive releasing the temporary jump lease.
 state().context=capture();c.numbers["haveDoubleJump"]=0;state().wanted[2]=true;leaseField(&c,"haveDoubleJump",1,state().jumps);NSString *grant=PROneShot(8,0);assert([grant containsString:@"zurückgelesen"]);state().wanted[2]=false;apply(2);assert(prodeus::boolean(&c,"haveDoubleJump"));
 frame=false;assert([PREffect(0,YES,0)[@"available"] boolValue]==NO);assert([PROneShot(3,0) containsString:@"Keine gültige"]);frame=true;
 puts("PASS: Prodeus actual product idle path, SP/MP/editor guards, owned writes, foreign changes, arrays, pause-aware speed and off-thread rejection; no game started.");
}}
