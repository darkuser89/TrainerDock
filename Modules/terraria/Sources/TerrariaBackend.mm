// SPDX-License-Identifier: GPL-3.0-only
#include "Mono.hpp"
#import "TerrariaBackend.h"
#import "TrainerFeatures.h"
#include <array>
#include <map>
#include <mutex>
#include <cstring>
#include <cmath>
#include <pthread.h>
namespace {
using namespace tr;
struct Slot {Root owner;Klass klass=nullptr;Field field=nullptr;std::vector<uint8_t> original,last;bool touched=false;int itemType=-1,feature=-1;};
struct State {
 std::array<bool,MTFeatureCount>wanted{},active{};std::array<double,MTFeatureCount>values{};std::array<NSString *,MTFeatureCount>notes{};
 std::map<std::string,Slot>slots;std::map<int,int>weaponDamage;Root player,inventory,callback;bool bound=false,ready=false,mouse=false,mouseHeld=false,oldVisible=false,oldBlock=false;
 Root mousePlayer;bool oldInterface=false;pthread_t thread={};bool observed=false;uint64_t frames=0;std::string identity;NSString *failure=@"Warte auf Terraria.";
 bool lightHeld=false;int oldLightMode=0;size_t lightCells=0;bool recipesHeld=false;Root recipeArray;std::vector<int>recipeOriginal,recipeLast;int oldRecipeCount=0,lastRecipeCount=0,applying=-1;
};
State& state(){static auto p=new State;return *p;}
thread_local bool inFrame=false;std::mutex pendingLock;NSMutableArray<dispatch_block_t> *pending;
Klass mainType(){return type("Terraria","Main");}
double n(Object o,const char *name){return number(o,o?api.objectClass(o):mainType(),name);}
Object r(Object o,const char *name){return ref(o,o?api.objectClass(o):mainType(),name);}
std::vector<Object> array(Object a,size_t limit){std::vector<Object> out;if(!a)return out;auto count=api.arrayLength(a);if(count>limit)throw std::runtime_error("Original array exceeds bound");for(size_t i=0;i<count;i++){Object o=nullptr;memcpy(&o,api.arrayAddress(a,8,i),8);out.push_back(o);}return out;}
int itemType(Object o){try{return (int)number(o,api.objectClass(o),"type");}catch(const std::exception&){return -1;}}
Slot& lease(Object o,Klass k,const char *name,int fingerprint=-1){auto &s=state();std::string key=std::to_string((uintptr_t)o)+":"+std::to_string(fingerprint)+":"+std::to_string((uintptr_t)k)+":"+name;
 auto it=s.slots.find(key);if(it==s.slots.end() && o){for(auto candidate=s.slots.begin();candidate!=s.slots.end();++candidate)if(candidate->second.owner.get()==o && candidate->second.klass==k && candidate->second.field==field(k,name) && candidate->second.itemType==fingerprint){it=candidate;break;}}if(it==s.slots.end()){Slot v;v.klass=k;v.field=field(k,name);v.original=read(o,k,v.field);v.last=v.original;v.itemType=fingerprint;v.feature=s.applying;if(o)v.owner.reset(o,true);it=s.slots.emplace(key,std::move(v)).first;}it->second.touched=true;return it->second;}
void own(Object o,Klass k,const char *name,double value,int fingerprint=-1){auto &v=lease(o,k,name,fingerprint);auto bytes=numeric(v.field,value);write(o,k,v.field,bytes);if(read(o,k,v.field)!=bytes)throw std::runtime_error("Original field readback differs");v.last=bytes;}
void own(Object o,const char *name,double v,int fingerprint=-1){own(o,o?api.objectClass(o):mainType(),name,v,fingerprint);}
void restore(bool all=false){auto &slots=state().slots;for(auto it=slots.begin();it!=slots.end();){auto &v=it->second;if(all || !v.touched){Object o=v.owner.get();try{if((!v.owner.handle || o) && (v.itemType<0 || itemType(o)==v.itemType) && read(o,v.klass,v.field)==v.last)write(o,v.klass,v.field,v.original);}catch(const std::exception&){}it=slots.erase(it);}else ++it;}}
void recipesOff(){auto &s=state();if(!s.recipesHeld)return;Object a=s.recipeArray.get();if(a && api.arrayLength(a)==s.recipeLast.size()){
 for(size_t i=0;i<s.recipeLast.size();i++){auto p=api.arrayAddress(a,4,i);int current=0;memcpy(&current,p,4);if(current==s.recipeLast[i])memcpy(p,&s.recipeOriginal[i],4);}}
 if(n(nullptr,"numAvailableRecipes")==s.lastRecipeCount){auto f=field(mainType(),"numAvailableRecipes");write(nullptr,mainType(),f,numeric(f,s.oldRecipeCount));}
 s.recipesHeld=false;s.recipeArray.reset();s.recipeOriginal.clear();s.recipeLast.clear();call(method(type("Terraria","Recipe"),"UpdateRecipeList",0));}
void lightOff(){auto &s=state();if(!s.lightHeld)return;auto k=type("Terraria","Lighting");int mode=s.oldLightMode;call(method(k,"set_Mode",1),nullptr,{&mode});Object engine=ref(nullptr,k,"_activeEngine");if(engine)call(method(api.objectClass(engine),"Clear",0),engine);auto f=field(mainType(),"renderNow");write(nullptr,mainType(),f,numeric(f,1));s.lightHeld=false;s.lightCells=0;}
void release(){restore(true);try{recipesOff();lightOff();}catch(const std::exception&){}state().active.fill(false);}
bool refresh(){auto &s=state();auto m=mainType();bool valid=!n(nullptr,"gameMenu") && !n(nullptr,"dedServ");Object p=nullptr,inv=nullptr;
 if(valid){int index=(int)n(nullptr,"myPlayer");auto players=array(r(nullptr,"player"),1024);if(index>=0 && (size_t)index<players.size())p=players[index];valid=p && n(p,"active") && !n(p,"dead");if(valid)inv=r(p,"inventory");valid=valid&&inv;}
 int world=valid?(int)unboxNumber(call(method(m,"get_worldID",0))):0;
 std::string id=valid?std::to_string(world)+":"+std::to_string((int)n(nullptr,"netMode"))+":"+std::to_string((uintptr_t)p)+":"+std::to_string((uintptr_t)inv):"loading";
 if(id!=s.identity || (valid && (s.player.get()!=p || s.inventory.get()!=inv))){release();s.weaponDamage.clear();s.player.reset(valid?p:nullptr,true);s.inventory.reset(valid?inv:nullptr,true);s.identity=id;}
 s.ready=valid;return valid;
}
void apply(int f){auto &s=state();Object p=s.player.get();switch(f){
 case MTFeatureGod:own(p,"immune",1);own(p,"immuneTime",300);own(p,"immuneNoBlink",1);own(p,"noKnockback",1);own(p,"noFallDmg",1);break;
 case MTFeatureHealth:own(p,"statLife",n(p,"statLifeMax2"));break;
 case MTFeatureMana:own(p,"statMana",n(p,"statManaMax2"));break;
 case MTFeatureBreath:own(p,"breath",n(p,"breathMax"));own(p,"breathCD",0);break;
 case MTFeatureFlight:{double wings=n(p,"wingTimeMax"),rocket=n(p,"rocketTimeMax");if((n(p,"wingsLogic")<=0 || wings<=0) && (n(p,"rocketBoots")<=0 || rocket<=0))throw std::runtime_error("Flügel oder Raketenstiefel ausrüsten.");own(p,"wingTime",wings);own(p,"rocketTime",rocket);break;}
 case MTFeatureGhost:own(p,"ghost",1);break;
 case MTFeatureItems:{int count=0;for(Object item:array(s.inventory.get(),256)){if(!item)continue;int t=itemType(item);if(t<=0 || n(item,"stack")<=0)continue;{double max=n(item,"maxStack");if(max<1 || max>999999)throw std::runtime_error("Original stack limit invalid");own(item,"stack",max,t);count++;}}
 if(!count)throw std::runtime_error("Keine eigenen Gegenstände.");break;}
 case MTFeatureDamage:{int count=0;for(Object item:array(s.inventory.get(),256)){if(!item)continue;int t=itemType(item);if(t<=0 || n(item,"stack")<=0 || n(item,"damage")<=0 || n(item,"ammo")!=0 || n(item,"consumable"))continue;
  auto c=api.objectClass(item);uint8_t prefix=0;Field pf=field(c,"prefix");if(api.kind(api.fieldType(pf))!=5)throw std::runtime_error("Original prefix byte ABI differs");api.read(item,pf,&prefix);int key=t*256+prefix;int damage=(int)n(item,"damage");
  if(damage!=1000000)s.weaponDamage[key]=damage;
  auto original=s.weaponDamage.find(key);if(original==s.weaponDamage.end())continue;
  auto &v=lease(item,c,"damage",t);v.original=numeric(v.field,original->second);own(item,"damage",1000000,t);count++;
 }if(!count)throw std::runtime_error("Nicht verbrauchbare eigene Waffe ins Inventar nehmen.");break;}
 case MTFeatureLight:{auto k=type("Terraria","Lighting");if(!s.lightHeld){s.oldLightMode=(int)unboxNumber(call(method(k,"get_Mode",0)));s.lightHeld=true;}int color=3;if(unboxNumber(call(method(k,"get_Mode",0)))!=3)call(method(k,"set_Mode",1),nullptr,{&color});Object engine=ref(nullptr,k,"_activeEngine");s.lightCells=0;
 for(const char *name:{"_activeLightMap","_workingLightMap"}){Object map=ref(engine,api.objectClass(engine),name),colors=ref(map,api.objectClass(map),"_colors");uintptr_t count=api.arrayLength(colors);if(count<1 || count>2000000)throw std::runtime_error("Original light map bounds differ");
  float white[3]={1,1,1};for(uintptr_t i=0;i<count;i++)memcpy(api.arrayAddress(colors,12,i),white,12);float result[3];memcpy(result,api.arrayAddress(colors,12,count-1),12);if(memcmp(result,white,12))throw std::runtime_error("Light map readback differs");s.lightCells+=count;}
 own(p,"nightVision",1);break;}
 case MTFeatureRecipes:{Object a=r(nullptr,"availableRecipe");size_t count=api.arrayLength(a);int recipes=(int)number(nullptr,type("Terraria","Recipe"),"numRecipes");if(count>100000 || recipes<1 || (size_t)recipes>count)throw std::runtime_error("Original recipe bounds differ");
 if(!s.recipesHeld || s.recipeArray.get()!=a){recipesOff();s.recipeArray.reset(a,true);s.recipeOriginal.resize(count);s.recipeLast.resize(count);memcpy(s.recipeOriginal.data(),api.arrayAddress(a,4,0),count*4);s.recipeLast=s.recipeOriginal;s.oldRecipeCount=(int)n(nullptr,"numAvailableRecipes");s.recipesHeld=true;}
 for(int i=0;i<recipes;i++){memcpy(api.arrayAddress(a,4,i),&i,4);s.recipeLast[i]=i;}s.lastRecipeCount=recipes;own(nullptr,"numAvailableRecipes",recipes);break;}
 case MTFeatureTime:{auto &time=lease(nullptr,mainType(),"time");write(nullptr,mainType(),time.field,time.original);time.last=time.original;auto &day=lease(nullptr,mainType(),"dayTime");write(nullptr,mainType(),day.field,day.original);day.last=day.original;break;}
 case MTFeatureSpeed:{if(n(nullptr,"gamePaused"))throw std::runtime_error("Pausiert; Tempo bleibt vorgemerkt.");own(nullptr,"FrameSkipMode",1);Object game=r(nullptr,"instance");auto &v=lease(game,api.objectClass(game),"INTERNAL_targetElapsedTime");if(typeName(api.fieldType(v.field))!="System.TimeSpan")throw std::runtime_error("Original FNA timespan differs");int64_t ticks=0;memcpy(&ticks,v.original.data(),8);ticks=(int64_t)llround(ticks/s.values[f]);if(ticks<10000 || ticks>10000000)throw std::runtime_error("Original FNA tick range differs");std::vector<uint8_t>b(8);memcpy(b.data(),&ticks,8);write(game,api.objectClass(game),v.field,b);if(read(game,api.objectClass(game),v.field)!=b)throw std::runtime_error("FNA clock readback differs");v.last=b;break;}
 default:throw std::runtime_error("Unknown feature");}
}
void tick(){auto &s=state();@autoreleasepool{
 if(!s.observed){s.thread=pthread_self();s.observed=true;}if(!pthread_equal(s.thread,pthread_self()))return;inFrame=true;s.frames++;
 @try{try{
  if(refresh()){for(auto &v:s.slots)v.second.touched=false;for(int f=0;f<MTFeatureCount;f++){s.active[f]=false;s.notes[f]=nil;if(!s.wanted[f])continue;try{s.applying=f;apply(f);s.active[f]=true;s.notes[f]=@"Native Wirkung zurückgelesen.";}catch(const std::exception& e){s.notes[f]=@(e.what());for(auto &slot:s.slots)if(slot.second.feature==f)slot.second.touched=false;if(f==MTFeatureLight)lightOff();if(f==MTFeatureRecipes)recipesOff();}}s.applying=-1;restore();if(!s.wanted[MTFeatureLight])lightOff();if(!s.wanted[MTFeatureRecipes])recipesOff();}
  if(s.mouse)TRMouse(YES);
  NSArray<dispatch_block_t> *work;{std::lock_guard<std::mutex> guard(pendingLock);work=pending.copy;[pending removeAllObjects];}for(dispatch_block_t job in work)job();
 }catch(const std::exception& e){s.failure=@(e.what());s.active.fill(false);}}@catch(NSException *e){s.failure=e.reason;}
 inFrame=false;
}}
bool bootstrap(){auto &s=state();if(s.bound)return true;if(!bind() || !api.root())return false;if(!api.attach(api.root()))return false;
 for(auto spec:{std::pair{"Terraria","6D97EEC3-CF49-43D4-BABA-712C3E4443CF"},std::pair{"FNA","E53843E6-4CD4-419F-8A19-1B6B97E2011E"},std::pair{"mscorlib","9B98D4B5-790E-4339-B39F-4E5620F6B824"}}){void *original=tr::image(spec.first);if(!original)return false;const char *g=api.guid(original);if(!g || strcasecmp(g,spec.second))throw std::runtime_error("Original assembly MVID differs");}
 auto m=mainType();if(!r(nullptr,"instance"))return false;
 auto action=type("System","Action","mscorlib"),marshal=type("System.Runtime.InteropServices","Marshal","mscorlib");Object reflected=api.typeObject(api.root(),api.classType(action));void *pointer=(void *)&tick;
 Root callback(call(method(marshal,"GetDelegateForFunctionPointer",2),nullptr,{&pointer,reflected}));if(!callback.get())return false;
 call(method(m,"add_OnTickForThirdPartySoftwareOnly",1),nullptr,{callback.get()});s.callback=std::move(callback);s.bound=true;s.failure=@"Originaler Terraria-Update-Rückruf registriert.";return true;
}
}
BOOL TREnqueue(dispatch_block_t work){if(!work)return NO;static dispatch_once_t once;dispatch_once(&once,^{pending=[NSMutableArray new];});try{if(!bootstrap())return NO;}catch(const std::exception& e){state().failure=@(e.what());return NO;}std::lock_guard<std::mutex> guard(pendingLock);if(pending.count>=64)return NO;[pending addObject:[work copy]];return YES;}
BOOL TRInFrame(){return inFrame && state().observed && pthread_equal(state().thread,pthread_self());}
NSDictionary *TRInspect(){if(!TRInFrame())return @{@"kind":@0,@"identity":@"unavailable",@"note":state().failure};try{refresh();}catch(const std::exception& e){state().ready=false;state().failure=@(e.what());}auto &s=state();return @{@"kind":@(s.ready?(n(nullptr,"netMode")?3:2):1),@"identity":@(s.identity.c_str()),@"note":s.ready?@"Originale lokale Terraria-Anbindung bestätigt.":s.failure};}
NSDictionary *TREffect(NSInteger f,BOOL wanted,double v){if(!TRInFrame() || f<0 || f>=MTFeatureCount || !std::isfinite(v))return @{};const auto *info=MTFeatureInfoAt((MTFeature)f);if(info->numeric && (v<info->minimum || v>info->maximum))return @{};auto &s=state();s.wanted[f]=wanted;s.values[f]=v;return @{@"available":@(info->implemented && (!wanted || !s.notes[f] || s.active[f])),@"active":@(wanted&&s.active[f]),@"note":s.notes[f] ?: info->detail};}
void TRRelease(){if(TRInFrame()){state().wanted.fill(false);release();}}
BOOL TRMouse(BOOL wanted){if(!TRInFrame())return NO;auto &s=state();try{Object game=r(nullptr,"instance");if(!game)return NO;auto k=api.objectClass(game);if(wanted){if(!s.mouseHeld){s.oldVisible=unboxNumber(call(method(k,"get_IsMouseVisible",0),game),2);s.oldBlock=n(nullptr,"blockMouse");s.mousePlayer.reset(s.player.get(),true);s.oldInterface=s.player.get()?n(s.player.get(),"mouseInterface"):false;s.mouseHeld=true;}uint8_t yes=1;call(method(k,"set_IsMouseVisible",1),game,{&yes});auto f=field(mainType(),"blockMouse");write(nullptr,mainType(),f,numeric(f,1));if(Object p=s.player.get()){auto c=api.objectClass(p);auto member=field(c,"mouseInterface");write(p,c,member,numeric(member,1));}s.mouse=true;return unboxNumber(call(method(k,"get_IsMouseVisible",0),game),2);}if(s.mouseHeld){uint8_t old=s.oldVisible;call(method(k,"set_IsMouseVisible",1),game,{&old});auto f=field(mainType(),"blockMouse");if(n(nullptr,"blockMouse"))write(nullptr,mainType(),f,numeric(f,s.oldBlock));if(Object p=s.mousePlayer.get()){auto c=api.objectClass(p);auto member=field(c,"mouseInterface");if(number(p,c,"mouseInterface"))write(p,c,member,numeric(member,s.oldInterface));}s.mouseHeld=false;s.mousePlayer.reset();}s.mouse=false;}catch(const std::exception& e){s.failure=@(e.what());}return NO;}
NSDictionary *TRValues(){if(!TRInFrame())return @{};auto &s=state();NSMutableDictionary *d=[@{@"context":TRInspect(),@"frames":@(s.frames),@"nativeCallback":@(s.bound),@"ownedFields":@(s.slots.size()),@"lightCells":@(s.lightCells)} mutableCopy];NSMutableArray *a=[NSMutableArray new];for(int i=0;i<MTFeatureCount;i++)[a addObject:@{@"id":@(i),@"wanted":@(s.wanted[i]),@"active":@(s.active[i]),@"note":s.notes[i] ?: @""}];d[@"features"]=a;if(s.ready){Object p=s.player.get();for(const char *field:{"statLife","statLifeMax2","statMana","statManaMax2","breath","breathMax","wingTime","wingTimeMax","rocketTime","ghost","immuneTime"})d[@(field)]=@(n(p,field));d[@"time"]=@(n(nullptr,"time"));d[@"dayTime"]=@(n(nullptr,"dayTime"));d[@"recipes"]=@(n(nullptr,"numAvailableRecipes"));NSMutableArray *items=[NSMutableArray new];int i=0;for(Object item:array(s.inventory.get(),256)){if(item && itemType(item)>0)[items addObject:@{@"slot":@(i),@"type":@(itemType(item)),@"stack":@(n(item,"stack")),@"maxStack":@(n(item,"maxStack")),@"damage":@(n(item,"damage"))}];i++;}d[@"items"]=items;}return d;}
