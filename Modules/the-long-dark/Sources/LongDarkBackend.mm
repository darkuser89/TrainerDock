// SPDX-License-Identifier: GPL-3.0-only
#import "LongDarkBackend.h"
#import "UnityLoop.h"
#import "TrainerFeatures.h"
#include "IL2CPP.hpp"
#include "NativeFields.hpp"
#include "SaveGuard.hpp"
#include <array>
#include <map>
#include <set>
#include <cmath>
#include <cstring>
#include <algorithm>
namespace {
using namespace tld;
tld::Class type(const char *name,const char *space="",const char *image="Assembly-CSharp.dll"){auto k=klass(image,space,name);if(!k)throw std::runtime_error(std::string("Ursprüngliche Klasse fehlt: ")+space+"."+name);return k;}
Object invoke(Object o,const char *name){if(!o)throw std::runtime_error("Der ursprüngliche Besitzer fehlt.");return call(method(api.objectClass(o),name,0),o);}
Object component(const char *getter){return call(method(type("GameManager"),getter,0),nullptr);}
Object staticReference(tld::Class k,const char *name){auto f=field(k,name);if(!f || !(api.fieldFlags(f)&0x10) || api.valueType(api.typeClass(api.fieldType(f))))throw std::runtime_error("Die ursprüngliche statische Referenzanbindung weicht ab.");Object o=nullptr;api.staticRead(f,&o);return o;}
struct Slot {
 Root owner,originalReference,lastReference; tld::Class klass=nullptr;Field member=nullptr;std::vector<uint8_t> original,last;bool touched=false;std::set<NSInteger> contributors;
};
struct Backend {
 std::array<bool,MTFeatureCount> wanted{},active{},available{};
 std::array<double,MTFeatureCount> values{};
 std::array<NSString *,MTFeatureCount> notes{};
 std::map<std::string,Slot> slots;NSInteger applying=-1;double lastTick=0;
 Root player,inventory,saveCondition,savePlayer;std::vector<Root> items;double gearRefresh=0;std::string identity;bool ready=false;NSString *failure=@"Spielstand laden.";
 bool mouse=false,mouseHeld=false,oldVisible=false,oldIgnore=false;int oldLock=0;double oldCursorState=0,lastCursorState=0;
 double timeBase=1,timeLast=1;bool timeHeld=false,flyHeld=false;Root flyCamera;
};
Backend& state(){static auto b=new Backend;return *b;}
std::string slotKey(Object o,tld::Class k,const char *name){return std::to_string((uintptr_t)o)+":"+std::to_string((uintptr_t)k)+":"+name;}
std::vector<uint8_t> numeric(Field f,double n){auto boxed=boxNumber(api.fieldType(f),n);Root root(boxed);std::vector<uint8_t> data(fieldSize(f));memcpy(data.data(),api.unbox(boxed),data.size());return data;}
double scalar(Object o,const char *name,tld::Class k=nullptr){if(!k)k=api.objectClass(o);Field f=field(k,name);auto bytes=read(o,f);Root boxed(api.box(api.typeClass(api.fieldType(f)),bytes.data()));return number(boxed.get());}
void setScalar(Object o,const char *name,double n){Field f=field(api.objectClass(o),name);write(o,f,numeric(f,n));if(std::fabs(scalar(o,name)-n)>std::max(0.001,std::fabs(n)*0.000001))throw std::runtime_error("Die Ressourcenrücklesung weicht ab.");}
Slot& lease(Object o,tld::Class k,const char *name){auto &b=state();auto key=slotKey(o,k,name);auto it=b.slots.find(key);if(it==b.slots.end()){
 Slot s;s.klass=k;s.member=field(k,name);s.original=read(o,s.member);s.last=s.original;if(!api.valueType(api.typeClass(api.fieldType(s.member)))){Object original=nullptr;memcpy(&original,s.original.data(),8);s.originalReference.reset(original);}if(o)s.owner.reset(o,true);it=b.slots.emplace(key,std::move(s)).first;}
 it->second.touched=true;it->second.contributors.insert(b.applying);return it->second;}
void own(Object o,tld::Class k,const char *name,double n,bool multiply=false){Slot &s=lease(o,k,name);if(multiply){Root boxed(api.box(api.typeClass(api.fieldType(s.member)),s.original.data()));n*=number(boxed.get());}
 auto bytes=numeric(s.member,n);if(read(o,s.member)!=bytes)write(o,s.member,bytes);if(read(o,s.member)!=bytes)throw std::runtime_error("Die Rücklesung des eigenen Feldwerts weicht ab.");s.last=std::move(bytes);}
void own(Object o,const char *name,double n,bool multiply=false){own(o,api.objectClass(o),name,n,multiply);}
void ownReference(Object o,const char *name,Object value){auto &s=lease(o,api.objectClass(o),name);if(api.valueType(api.typeClass(api.fieldType(s.member))))throw std::runtime_error("Ein Referenzfeld wurde erwartet.");
 std::vector<uint8_t> bytes(sizeof(Object));memcpy(bytes.data(),&value,sizeof(value));s.lastReference.reset(value);if(read(o,s.member)!=bytes)write(o,s.member,bytes);if(read(o,s.member)!=bytes)throw std::runtime_error("Die Referenzrücklesung weicht ab.");s.last=bytes;}
void ownEmptyArray(Object o,const char *name){auto &s=lease(o,api.objectClass(o),name);auto arrayClass=api.typeClass(api.fieldType(s.member));auto element=api.elementClass(arrayClass);if(!element)throw std::runtime_error("Ein ursprüngliches Listenfeld wurde erwartet.");
 if(!s.lastReference.get() || api.arrayLength(s.lastReference.get())!=0){Root empty(api.arrayNew(element,0));ownReference(o,name,empty.get());}else ownReference(o,name,s.lastReference.get());}
double enumValue(const char *typeName,const char *name){auto k=type(typeName);auto bytes=read(nullptr,field(k,name));Root value(api.box(k,bytes.data()));return number(value.get());}
Object blueprintManager(){return call(method(type("BlueprintManager","TLD.Gear"),"get_Instance",0),nullptr);}
void exitFly(){auto &b=state();if(b.flyHeld){try{Object camera=staticReference(type("FlyMode"),"m_Camera");if(camera==b.flyCamera.get() && alive(camera) && number(call(method(type("CameraDebugMode"),"get_IsFly",0),nullptr)))call(method(type("FlyMode"),"Exit",0),nullptr);}catch(const std::exception&){}b.flyHeld=false;b.flyCamera.reset();}}
void ownWeight(Object o,const char *name,double kg){auto &s=lease(o,api.objectClass(o),name);if(typeName(api.fieldType(s.member))!="TLD.IntBackedUnit.ItemWeight")throw std::runtime_error("Der ursprüngliche Gewichtsdatentyp wurde erwartet.");
 auto weightClass=api.typeClass(api.fieldType(s.member));Root weight(numericCall(method(weightClass,"FromKilograms",1),nullptr,{kg}));
 if(!weight.get() || api.objectClass(weight.get())!=weightClass)throw std::runtime_error("Die ursprüngliche Gewichtsumrechnung ist fehlgeschlagen.");
 std::vector<uint8_t> bytes(fieldSize(s.member));memcpy(bytes.data(),api.unbox(weight.get()),bytes.size());if(read(o,s.member)!=bytes)write(o,s.member,bytes);if(read(o,s.member)!=bytes)throw std::runtime_error("Die Gewichtsrücklesung weicht ab.");s.last=std::move(bytes);}
void finishSlots(bool all=false){auto &slots=state().slots;for(auto it=slots.begin();it!=slots.end();){auto &s=it->second;if(all || !s.touched){
 Object o=s.owner.get();try{if((api.fieldFlags(s.member)&0x10 || alive(o)) && read(o,s.member)==s.last)write(o,s.member,s.original);}catch(const std::exception&){}
 it=slots.erase(it);}else{++it;}}}
void release(){TLDReleaseSaveGuard();state().saveCondition.reset();state().savePlayer.reset();exitFly();finishSlots(true);state().active.fill(false);}
bool refresh(){auto &b=state();Object p=component("GetPlayerManagerComponent"),inv=component("GetInventoryComponent"),condition=component("GetConditionComponent");
 std::string scene=text(staticReference(type("GameManager"),"m_ActiveScene"));
 bool ready=alive(p) && alive(inv) && alive(condition) && boolean(p,"m_StartHasBeenCalled") && !boolean(p,"m_SceneTransitionStarted") && scene!="" && scene.find("MainMenu")==std::string::npos && scene!="Empty" && scalar(condition,"m_CurrentHP")>0 && !getNumber(p,"PlayerIsDead");
 std::string id=ready ? scene+":"+std::to_string((uintptr_t)p)+":"+std::to_string((uintptr_t)inv):"loading";
 if(id!=b.identity || (ready && (b.player.get()!=p || b.inventory.get()!=inv))){release();b.items.clear();b.gearRefresh=0;b.player.reset(ready?p:nullptr,true);b.inventory.reset(ready?inv:nullptr,true);b.identity=id;}
 b.ready=ready;b.failure=ready?@"Originale lokale Spielanbindung bestätigt.":@"Spielstand laden; wartet auf gültige Spielfigur.";return ready;}
void cure(const char *getter,const char *test){Object o=component(getter);if(!alive(o))throw std::runtime_error("Die Leidenskomponente fehlt.");if(getNumber(o,test)!=0)call(method(api.objectClass(o),"Cure",0),o);if(getNumber(o,test)!=0)throw std::runtime_error("Die Heilung des Leidens wurde nicht bestätigt.");}
Object uniStorm(){Object tod=component("GetTimeOfDayComponent");return reference(tod,"m_WeatherSystem");}
void weather(int selected){const char *names[]={"LightSnow","HeavySnow","Blizzard","Clear","Cloudy","LightFog","DenseFog"};if(selected<0 || selected>6)throw std::runtime_error("Ungültiges Wetter.");
 Field f=field(type("WeatherStage"),names[selected]);auto bytes=read(nullptr,f);Root enumValue(api.box(type("WeatherStage"),bytes.data()));Object u=uniStorm();
 Root duration(boxNumber(api.parameterType(method(api.objectClass(u),"SetWeatherStage",3),1),0)),instant(boxNumber(api.parameterType(method(api.objectClass(u),"SetWeatherStage",3),2),1));
 call(method(api.objectClass(u),"SetWeatherStage",3),u,{enumValue.get(),duration.get(),instant.get()});
 if(getNumber(u,"GetWeatherStage")!=number(enumValue.get()))throw std::runtime_error("Der Wetterwechsel ist noch nicht bestätigt.");}
void setHour(double hour){Object tod=component("GetTimeOfDayComponent");Method m=method(api.objectClass(tod),"SetNormalizedTime",1);if(!m)throw std::runtime_error("Die ursprüngliche Zeitänderungsfunktion fehlt.");numericCall(m,tod,{hour/24.0});if(std::fabs(getNumber(tod,"GetNormalizedTime")-hour/24.0)>.002)throw std::runtime_error("Die Zeitrücklesung weicht ab.");}
std::vector<Object> gear(){auto &b=state();double now=NSDate.date.timeIntervalSinceReferenceDate;
 if(now-b.gearRefresh>.25){b.items.clear();auto owned=list(reference(b.inventory.get(),"m_Items"));if(owned.empty())owned=findObjects(type("GearItem"),true);for(Object o:owned)if(alive(o) && api.objectClass(o)==type("GearItem") && boolean(o,"m_InPlayerInventory"))b.items.emplace_back(o,true);b.gearRefresh=now;}
 std::vector<Object> result;for(auto &r:b.items)if(alive(r.get()) && boolean(r.get(),"m_InPlayerInventory"))result.push_back(r.get());return result;}
Object addGear(const char *name,int count){
 Object p=state().player.get();Method m=method(api.objectClass(p),"AddItemCONSOLE",3);
 if(!m || typeName(api.parameterType(m,0))!="System.String")throw std::runtime_error("Die ursprüngliche Ausrüstungserstellung weicht von der geprüften Anbindung ab.");
 Root label(api.stringNew(name)),units(boxNumber(api.parameterType(m,1),count)),condition(boxNumber(api.parameterType(m,2),1));
 Object added=call(m,p,{label.get(),units.get(),condition.get()});
 if(!alive(added) || !boolean(added,"m_InPlayerInventory"))throw std::runtime_error(std::string("Inventarzugang nicht bestätigt: ")+name);
 state().gearRefresh=0;return added;
}
void liquidFloor(Object o,const char *name,double liters){
 auto &s=lease(o,api.objectClass(o),name);auto k=api.typeClass(api.fieldType(s.member));
 if(typeName(api.fieldType(s.member))!="TLD.IntBackedUnit.ItemLiquidVolume")throw std::runtime_error("Die ursprüngliche Flüssigkeitseinheit weicht ab.");
 Root baseline(api.box(k,s.original.data())),floor(numericCall(method(k,"FromLiters",1),nullptr,{liters}));
 Root value(call(method(k,"Max",2),nullptr,{baseline.get(),floor.get()}));
 std::vector<uint8_t> bytes(fieldSize(s.member));memcpy(bytes.data(),api.unbox(value.get()),bytes.size());write(o,s.member,bytes);
 if(read(o,s.member)!=bytes)throw std::runtime_error("Die Rücklesung der Flüssigkeitsmenge weicht ab.");s.last=std::move(bytes);
}
void protectCurrentSave(){
 auto k=type("SaveGameSystem");double id=scalar(nullptr,"m_CurrentGameId",k);
 Object slots=staticReference(type("SaveGameSlots"),"m_SaveSlots");std::vector<std::string> paths;
 // Some original platform adapters are absent from the loaded macOS image.
 // Protect its optional download directory only when that actual adapter exists.
 std::string cloud;auto cloudClass=klass("Assembly-CSharp.dll","","SteamCloudManagerPC");
 if(cloudClass)if(Method download=method(cloudClass,"GetDownloadDirectory",0))cloud=text(call(download,nullptr));
 for(Object slot:list(slots,64))if(scalar(slot,"m_GameId")==id){
  Object name=reference(slot,"m_InternalName");std::string label=text(name);if(label.empty() || label.find('/')!=std::string::npos || label.find("..")!=std::string::npos)throw std::runtime_error("Der ursprüngliche Speicherplatzname ist ungültig.");
  std::string path=text(call(method(type("SaveGameDataPC"),"GetFullPath",1),nullptr,{name}));if(path.empty())throw std::runtime_error("Der ursprüngliche Spielstandpfad ist nicht verfügbar.");paths.push_back(path);
  if(!cloud.empty())paths.push_back(std::string([[NSString stringWithUTF8String:cloud.c_str()] stringByAppendingPathComponent:[NSString stringWithUTF8String:label.c_str()]].fileSystemRepresentation));
 }
 Object c=component("GetConditionComponent");Field hp=field(api.objectClass(c),"m_CurrentHP");if(!alive(c) || fieldSize(hp)!=4 || api.typeKind(api.fieldType(hp))!=12)throw std::runtime_error("Das ursprüngliche Gesundheitsfeld weicht ab.");
 Object p=state().player.get();Field mode=field(api.objectClass(p),"m_ControlMode");if(fieldSize(mode)!=4)throw std::runtime_error("Der ursprüngliche Steuerungsmodus weicht ab.");
 state().saveCondition.reset(c);state().savePlayer.reset(p);TLDProtectSaves(paths,(uintptr_t)c+api.fieldOffset(hp),(uintptr_t)p+api.fieldOffset(mode),(int)enumValue("PlayerControlMode","Dead"));
 if(!TLDProtectedSaveCount())throw std::runtime_error("Kein aktuell gespeicherter Lauf zum Schützen verfügbar.");
}
void apply(NSInteger f){auto &b=state();double v=b.values[f];Object p=b.player.get();
 switch(f){
 case MTFeatureHealth:{Object c=component("GetConditionComponent");own(c,"m_Invulnerable",1);setScalar(c,"m_CurrentHP",getNumber(c,"GetAdjustedMaxHP"));break;}
 case MTFeatureFreezing:setScalar(component("GetFreezingComponent"),"m_CurrentFreezing",0);break;
 case MTFeatureFatigue:setScalar(component("GetFatigueComponent"),"m_CurrentFatigue",0);break;
 case MTFeatureThirst:setScalar(component("GetThirstComponent"),"m_CurrentThirst",0);break;
 case MTFeatureHunger:{Object h=component("GetHungerComponent");setScalar(h,"m_CurrentReserveCalories",getNumber(h,"GetAdjustedMaxReserveCalories"));break;}
 case MTFeatureInfection:cure("GetInfectionComponent","HasInfection");cure("GetInfectionRiskComponent","HasInfectionRisk");break;
 case MTFeatureSurvivalDrain:{Object mode=invoke(component("GetExperienceModeManagerComponent"),"GetCurrentExperienceMode");for(const char *n:{"m_CalorieBurnScale","m_ThirstRateScale","m_FreezingRateScale","m_FatigueRateScale"})own(mode,n,v,true);break;}
 case MTFeatureStamina:{Object m=component("GetPlayerMovementComponent");own(nullptr,type("PlayerMovement"),"m_UnlimitedSprint",1);setScalar(m,"m_SprintStamina",getNumber(m,"get_CurrentMaxStamina"));break;}
 case MTFeatureStaminaDrain:own(component("GetPlayerMovementComponent"),"m_SprintStaminaUsagePerSecond",v,true);break;
 case MTFeatureWrist:{Object o=component("GetSprainedWristComponent");own(o,"m_IsNoSprainWristForced",1);cure("GetSprainedWristComponent","HasSprainedWrist");break;}
 case MTFeatureAnkle:{Object o=component("GetSprainedAnkleComponent");own(component("GetPlayerMovementComponent"),"m_ForceNoRandomSprain",1);own(o,"m_ChanceSprainAfterFall",0);cure("GetSprainedAnkleComponent","HasSprainedAnkle");break;}
 case MTFeaturePain:cure("GetSprainPainComponent","HasSprainPain");cure("GetHeadacheComponent","HasHeadache");break;
 case MTFeatureDamageTaken:{Object broken=component("GetBrokenBody");own(broken,"m_DamageMultiplier",v);own(broken,"<HasAffliction>k__BackingField",1);break;}
 case MTFeatureItemUses:{unsigned count=0;for(Object o:gear()){
  if(Object stack=reference(o,"m_StackableItem")){auto &entry=lease(stack,api.objectClass(stack),"m_Units");Root initial(api.box(api.typeClass(api.fieldType(entry.member)),entry.original.data()));own(stack,"m_Units",std::max(2.0,number(initial.get())));count++;}
  if(Object use=reference(o,"m_DegradeOnUse")){own(use,"m_DegradeHP",0);count++;}
  if(Object food=reference(o,"m_FoodItem")){double capacity=getNumber(component("GetHungerComponent"),"GetAdjustedMaxReserveCalories");own(food,"m_MustConsumeAll",0);own(food,"m_CaloriesRemaining",std::max(scalar(food,"m_CaloriesTotal"),capacity)+1);count++;}
  if(Object water=reference(o,"m_WaterSupply")){liquidFloor(water,"m_VolumeInLiters",2);count++;}
  if(Object liquid=reference(o,"m_LiquidItem")){liquidFloor(liquid,"m_Liquid",2);count++;}
 }if(!count)throw std::runtime_error("Kein wiederverwendbarer Stapel oder Werkzeug im Inventar verfügbar.");break;}
 case MTFeatureKeepDeathSave:protectCurrentSave();break;
 case MTFeatureWeight:{Object inv=b.inventory.get();own(inv,"m_ForceOverrideWeight",1);ownWeight(inv,"m_OverridedWeight",0);break;}
 case MTFeatureCapacity:{Object e=component("GetEncumberComponent");for(const char *n:{"m_MaxCarryCapacity","m_MaxCarryCapacityWhenExhausted","m_NoSprintCarryCapacity","m_NoWalkCarryCapacity"})ownWeight(e,n,v);break;}
 case MTFeatureDurability:case MTFeatureWear:{auto items=gear();if(items.empty())throw std::runtime_error("Keine eigene Inventarausrüstung verfügbar.");for(Object o:items){
  if(f==MTFeatureDurability){own(o,"m_HaltDecay",1);Slot &s=lease(o,api.objectClass(o),"m_CurrentHP");auto current=read(o,s.member);Root a(api.box(api.typeClass(api.fieldType(s.member)),current.data())),baseline(api.box(api.typeClass(api.fieldType(s.member)),s.original.data()));if(number(a.get())<number(baseline.get())){write(o,s.member,s.original);s.last=s.original;}else{s.last=current;}}
  else if(!b.wanted[MTFeatureDurability])own(o,"m_DecayScalar",v,true);else throw std::runtime_error("Der Haltbarkeitsschutz hat Vorrang vor dem Verschleiß.");
 }break;}
 case MTFeatureEasyCraft:{auto blueprints=list(invoke(blueprintManager(),"GetAllBlueprints"));if(blueprints.empty())throw std::runtime_error("Die Baupläne sind noch nicht geladen.");
 for(Object bp:blueprints){for(const char *n:{"m_RequiredGear","m_RequiredPowder","m_RequiredLiquid"})ownEmptyArray(bp,n);ownReference(bp,"m_RequiredTool",nullptr);own(bp,"m_RequiresLight",0);own(bp,"m_RequiresLitFire",0);own(bp,"m_RequiredCraftingLocation",enumValue("CraftingLocation","Anywhere"));}break;}
 case MTFeaturePredators:{unsigned count=0;for(Object region:findObjects(type("SpawnRegion"))){if(!getNumber(region,"IsPredator"))continue;
 for(const char *difficulty:{"Pilgrim","Voyageur","Stalker","Interloper"}){
  for(const char *period:{"Day","Night"}){std::string name=std::string("m_MaxSimultaneousSpawns")+period+difficulty;auto &entry=lease(region,api.objectClass(region),name.c_str());Root original(api.box(api.typeClass(api.fieldType(entry.member)),entry.original.data()));own(region,name.c_str(),std::min(40.0,std::ceil(number(original.get())*v)));}
  std::string name=std::string("m_MaxRespawnsPerDay")+difficulty;own(region,name.c_str(),v,true);
 }count++;}
 if(!count)throw std::runtime_error("Keine aktive Raubtierregion verfügbar.");break;}
 case MTFeatureFly:{auto mode=type("CameraDebugMode");if(number(call(method(mode,"get_IsLock",0),nullptr)))throw std::runtime_error("Die ursprüngliche Kamerasperre ist aktiv.");
 if(!number(call(method(mode,"get_IsFly",0),nullptr))){call(method(type("ConsoleManager"),"CONSOLE_fly",0),nullptr);if(!number(call(method(mode,"get_IsFly",0),nullptr)))throw std::runtime_error("Der ursprüngliche Flugmodus ist nicht bestätigt.");b.flyHeld=true;b.flyCamera.reset(staticReference(type("FlyMode"),"m_Camera"),true);}break;}
 case MTFeatureInstantCraft:{auto panels=findObjects(type("Panel_Crafting"));if(panels.empty())throw std::runtime_error("Bitte das Herstellungsmenü öffnen.");for(Object o:panels){own(o,"m_CraftingDisplayTimeSeconds",.01);Object operation=reference(o,"m_CraftingOperation");if(operation && getNumber(operation,"get_InProgress"))own(operation,"m_RealTimeDuration",.01);}break;}
 case MTFeatureInvisible:own(p,"m_Ghost",1);if(!getNumber(p,"PlayerIsInvisibleToAi"))throw std::runtime_error("Die ursprüngliche Unsichtbarkeit ist nicht bestätigt.");break;
 case MTFeatureGameSpeed:{auto time=type("Time","UnityEngine","UnityEngine.CoreModule.dll");double now=number(call(method(time,"get_timeScale",0),nullptr));if(now>0){if(!b.timeHeld){b.timeBase=now;b.timeHeld=true;}numericCall(method(time,"set_timeScale",1),nullptr,{v});b.timeLast=v;if(std::fabs(number(call(method(time,"get_timeScale",0),nullptr))-v)>.001)throw std::runtime_error("Die Rücklesung des Zeitfaktors weicht ab.");}else throw std::runtime_error("Pausiert; die gewünschte Geschwindigkeit bleibt vorgemerkt.");break;}
 case MTFeatureFreezeTime:own(component("GetTimeOfDayComponent"),"m_LockedTOD",1);break;
 case MTFeatureNoBlizzard:own(nullptr,type("WeatherTransition"),"m_SuppressBlizzards",1);if(getNumber(component("GetWeatherComponent"),"IsBlizzard"))weather(3);break;
 case MTFeatureNight:setHour(0);own(component("GetTimeOfDayComponent"),"m_LockedTOD",1);break;
 case MTFeatureIceAge:own(component("GetWeatherComponent"),"m_LockedAirTemperature",v);numericCall(method(api.objectClass(component("GetWeatherComponent")),"LockAirTemperature",1),component("GetWeatherComponent"),{v});break;
 case MTFeatureAmmo:{unsigned count=0;for(Object o:gear())if(Object gun=reference(o,"m_GunItem")){double max=scalar(gun,"m_ClipSize"),now=getNumber(gun,"NumRoundsInClip");if(max<1 || max>100)throw std::runtime_error("Die ursprüngliche Magazingrenze ist ungültig.");if(now<max)numericCall(method(api.objectClass(gun),"AddRoundsToClip",2),gun,{max-now,100});if(getNumber(gun,"NumRoundsInClip")!=max)throw std::runtime_error("Das Auffüllen des Magazins wurde nicht bestätigt.");count++;}if(!count)throw std::runtime_error("Keine eigene Schusswaffe vorhanden.");break;}
 case MTFeatureOneHit:{unsigned count=0;for(Object o:gear())if(Object gun=reference(o,"m_GunItem")){own(gun,"m_DamageHP",1000000);count++;}if(!count)throw std::runtime_error("Keine eigene Schusswaffe vorhanden.");break;}
 case MTFeatureNoJam:own(nullptr,type("GunItem"),"m_ForceNoJam",1);break;
 case MTFeatureSuperSpeed:case MTFeatureMoveSpeed:case MTFeatureCrouchSpeed:{Object fps=staticReference(type("GameManager"),"m_vpFPSPlayer"),controller=reference(fps,"Controller");bool crouched=boolean(component("GetPlayerMovementComponent"),"m_IsCrouching");
 double factor=b.wanted[MTFeatureSuperSpeed]?3:1;if(!crouched && b.wanted[MTFeatureMoveSpeed])factor*=b.values[MTFeatureMoveSpeed];if(crouched && b.wanted[MTFeatureCrouchSpeed])factor*=b.values[MTFeatureCrouchSpeed];
 own(controller,"MotorAcceleration",factor,true);own(controller,"MotorVelocityMax",factor,true);break;}
 default:throw std::runtime_error("Die native Wirkung ist nicht implementiert.");
 }
}
void restoreTime(){auto &b=state();if(!b.timeHeld || b.wanted[MTFeatureGameSpeed])return;auto k=type("Time","UnityEngine","UnityEngine.CoreModule.dll");double n=number(call(method(k,"get_timeScale",0),nullptr));if(n<=0)return;if(std::fabs(n-b.timeLast)<.001)numericCall(method(k,"set_timeScale",1),nullptr,{b.timeBase});b.timeHeld=false;}
void frame(){auto &b=state();try{
 TLDObserveSaveGuard();if(b.mouse)TLDMouse(YES);double now=NSDate.date.timeIntervalSinceReferenceDate;if(now-b.lastTick<.1)return;b.lastTick=now;
 if(!refresh())return;for(auto &entry:b.slots){entry.second.touched=false;entry.second.contributors.clear();}
 for(NSInteger i=0;i<MTFeatureCount;i++){b.active[i]=false;b.available[i]=MTFeatureInfoAt((MTFeature)i)->implemented;b.notes[i]=nil;
  if(!b.wanted[i] || MTFeatureInfoAt((MTFeature)i)->oneShot || !MTFeatureInfoAt((MTFeature)i)->implemented)continue;
  try{b.applying=i;apply(i);b.active[i]=true;b.notes[i]=@"Native Wirkung zurückgelesen.";}catch(const std::exception& e){b.available[i]=false;b.notes[i]=@(e.what());for(auto &entry:b.slots){entry.second.contributors.erase(i);entry.second.touched=!entry.second.contributors.empty();}}
 }
 b.applying=-1;finishSlots();if(!b.wanted[MTFeatureKeepDeathSave]){TLDReleaseSaveGuard();b.saveCondition.reset();b.savePlayer.reset();}restoreTime();if(!b.wanted[MTFeatureFly])exitFly();
 }catch(const std::exception& e){b.failure=@(e.what());b.active.fill(false);}}
}
void TLDStartBackend(){dispatch_async(dispatch_get_main_queue(),^{TLDEnsureLoop();TLDSetFrameHandler(^{frame();});[NSTimer scheduledTimerWithTimeInterval:.5 repeats:YES block:^(NSTimer *t){(void)t;TLDEnsureLoop();}];});}
NSDictionary *TLDInspect(){if(!TLDInFrame())return @{@"kind":@0,@"identity":@"unavailable"};try{refresh();}catch(const std::exception& e){state().ready=false;state().failure=@(e.what());}return @{@"kind":@(state().ready?2:1),@"identity":@(state().identity.c_str()),@"note":state().failure};}
NSDictionary *TLDEffect(NSInteger f,BOOL wanted,double value){if(!TLDInFrame() || f<0 || f>=MTFeatureCount)return @{};auto &b=state();auto info=MTFeatureInfoAt((MTFeature)f);if(!std::isfinite(value) || (info->numeric && (value<info->minimum || value>info->maximum || (info->integer && floor(value)!=value))))return @{};
 if(f==MTFeatureKeepDeathSave && !wanted){TLDClearSaveGuard();b.saveCondition.reset();b.savePlayer.reset();}
 b.wanted[f]=wanted && info->implemented && !info->oneShot;b.values[f]=value;
 return @{@"available":@(info->implemented && (b.available[f] || !wanted)),@"active":@(b.active[f] && b.wanted[f]),@"note":b.notes[f] ?: info->detail};}
void TLDRelease(){if(!TLDInFrame())return;state().wanted.fill(false);release();try{restoreTime();}catch(const std::exception&){};}
NSString *TLDOneShot(NSInteger f,double value){if(!TLDInFrame() || !state().ready)return @"Gültigen Spielstand laden.";
 const MTFeatureInfo *info=MTFeatureInfoAt((MTFeature)f);
 if(!info || !info->implemented || !info->oneShot || !std::isfinite(value) || (info->numeric && (value<info->minimum || value>info->maximum || (info->integer && floor(value)!=value))))return @"Aktion nicht freigegeben oder Wert ungültig.";
 try{
 switch(f){
 case MTFeatureRoulette:{bool wrist=arc4random_uniform(2)!=0;Object affliction=component(wrist?"GetSprainedWristComponent":"GetSprainedAnkleComponent");const char *name=wrist?"SprainedWristStart":"SprainedAnkleStart";auto m=method(api.objectClass(affliction),name,2);Root cause(api.stringNew("TrainerDock")),options(boxNumber(api.parameterType(m,1),0));call(m,affliction,{cause.get(),options.get()});if(!getNumber(affliction,wrist?"HasSprainedWrist":"HasSprainedAnkle"))throw std::runtime_error("Das Leiden wurde nicht bestätigt.");return wrist?@"Zufälliges Leiden: Handgelenksverstauchung.":@"Zufälliges Leiden: Knöchelverstauchung.";}
 case MTFeatureDayTime:if(value<0 || value>=24)throw std::runtime_error("Ungültige Uhrzeit.");setHour(value);break;
 case MTFeatureWeather:if(value<0 || value>6 || floor(value)!=value)throw std::runtime_error("Ungültiges Wetter.");weather((int)value);break;
 case MTFeatureSkills:{Object s=component("GetSkillsManager");int count=(int)getNumber(s,"GetNumSkills");if(count<1 || count>32)throw std::runtime_error("Ungültige Anzahl von Fähigkeiten.");for(int i=0;i<count;i++){Root skill(numericCall(method(api.objectClass(s),"GetSkillFromIndex",1),s,{(double)i}));double max=getNumber(skill.get(),"GetMaxPoints");numericCall(method(api.objectClass(skill.get()),"SetPoints",2),skill.get(),{max,0});if(getNumber(skill.get(),"GetPoints")!=max)throw std::runtime_error("Die Fähigkeitsrücklesung weicht ab.");}break;}
 case MTFeatureBlueprints:{Object manager=call(method(type("BlueprintManager","TLD.Gear"),"get_Instance",0),nullptr);auto blueprints=list(invoke(manager,"GetAllBlueprints"));if(blueprints.empty())throw std::runtime_error("Die Baupläne sind noch nicht geladen.");for(Object bp:blueprints){call(method(api.objectClass(manager),"UnlockSilent",1),manager,{bp});if(getNumber(bp,"get_Locked"))throw std::runtime_error("Der Bauplan bleibt gesperrt.");}break;}
 case MTFeatureHealAll:{unsigned count=0;auto gm=type("GameManager");void *it=nullptr;while(Method m=api.methods(gm,&it)){std::string n=api.methodName(m);if(n.rfind("Get",0)!=0 || n.find("Component")==std::string::npos || api.parameterCount(m))continue;uint32_t flags=0;if(!(api.methodFlags(m,&flags)&0x10))continue;auto resultClass=api.typeClass(api.returnType(m));if(!resultClass || api.valueType(resultClass) || (!method(resultClass,"Cure",0) && !method(resultClass,"CureAll",0)))continue;Object o=call(m,nullptr);if(!alive(o))continue;Method cureMethod=method(api.objectClass(o),"Cure",0);if(!cureMethod)cureMethod=method(api.objectClass(o),"CureAll",0);if(!cureMethod)continue;call(cureMethod,o);count++;}if(!count || getNumber(component("GetConditionComponent"),"HasAffliction"))throw std::runtime_error("Nicht alle Leiden konnten bestätigt geheilt werden.");break;}
 case MTFeatureAurora:{Object a=component("GetAuroraManager");numericCall(method(api.objectClass(a),"ForceAuroraNextOpportunity",3),a,{1,1,1});if(!boolean(a,"m_ForceAuroraNextOpportunity") && !getNumber(a,"AuroraIsActive"))throw std::runtime_error("Die Aurora-Anforderung wurde nicht bestätigt.");return @"Aurora angefordert; benötigt eine geeignete Nachtgelegenheit.";}
 case MTFeatureWeapons:{
  const char *weapons[]={"GEAR_Rifle","GEAR_Revolver","GEAR_FlareGun","GEAR_Bow","GEAR_Knife","GEAR_KnifeImprovised","GEAR_Hatchet","GEAR_HatchetImprovised","GEAR_NoiseMaker"};
  unsigned count=0;for(const char *name:weapons){addGear(name,1);count++;}
  for(const char *name:{"GEAR_RifleAmmoSingle","GEAR_RevolverAmmoSingle","GEAR_FlareGunAmmoSingle","GEAR_Arrow","GEAR_ArrowHardened"})addGear(name,10);
  return [NSString stringWithFormat:@"%u Waffen/Werkzeuge und passende Munition im Originalinventar bestätigt.",count];}
 case MTFeatureQuickSave:{auto gm=type("GameManager");
  if(!number(numericCall(method(gm,"AllowedToSave",1),nullptr,{0})))throw std::runtime_error("Das Spiel erlaubt momentan kein Speichern.");
  if(text(call(method(type("SaveGameSystem"),"GetCurrentSaveName",0),nullptr)).empty())throw std::runtime_error("Kein ursprünglicher Speicherplatz vorhanden.");
  call(method(gm,"SaveGameAndDisplayHUDMessage",0),nullptr);
  return @"Originale Speicherung angefordert; Abschluss und Speichersymbol steuert das Spiel.";}
 default:throw std::runtime_error("Die native Aktion ist nicht implementiert.");
 }
 return @"Originale Aktion ausgeführt und zurückgelesen.";
 }catch(const std::exception& e){return [NSString stringWithFormat:@"Nicht bestätigt: %s",e.what()];}}
BOOL TLDMouse(BOOL wanted){if(!TLDInFrame())return NO;auto &b=state();b.mouse=wanted;
 try{auto c=type("Cursor","UnityEngine","UnityEngine.CoreModule.dll"),input=type("InputManager");auto get=[&](const char *n){return number(call(method(c,n,0),nullptr));};auto set=[&](const char *n,double v){numericCall(method(c,n,1),nullptr,{v});};
 Field ignore=field(input,"s_IgnoreInput");
 if(!wanted){if(b.mouseHeld){auto bytes=numeric(ignore,b.oldIgnore?1:0);write(nullptr,ignore,bytes);Field cursorState=field(input,"m_CursorState");if(scalar(nullptr,"m_CursorState",input)==b.lastCursorState)write(nullptr,cursorState,numeric(cursorState,b.oldCursorState));set("set_visible",b.oldVisible?1:0);set("set_lockState",b.oldLock);}b.mouseHeld=false;return NO;}
 if(!b.mouseHeld){b.oldVisible=get("get_visible")!=0;b.oldLock=(int)get("get_lockState");b.oldIgnore=scalar(nullptr,"s_IgnoreInput",input)!=0;b.oldCursorState=scalar(nullptr,"m_CursorState",input);b.mouseHeld=true;}
 write(nullptr,ignore,numeric(ignore,1));numericCall(method(input,"ShowCursor",1),nullptr,{1});b.lastCursorState=scalar(nullptr,"m_CursorState",input);set("set_lockState",0);set("set_visible",1);
 return scalar(nullptr,"s_IgnoreInput",input)==1 && get("get_visible")==1 && get("get_lockState")==0;
 }catch(const std::exception& e){b.failure=@(e.what());return NO;}}
NSDictionary *TLDValues(){if(!TLDInFrame())return @{};auto &b=state();NSMutableDictionary *d=[@{@"context":TLDInspect(),@"loop":TLDLoopDiagnostics()} mutableCopy];
 NSMutableArray *features=[NSMutableArray new];for(NSInteger i=0;i<MTFeatureCount;i++)[features addObject:@{@"id":@(i),@"wanted":@(b.wanted[i]),@"active":@(b.active[i]),@"note":b.notes[i] ?: @""}];d[@"features"]=features;d[@"protectedSaves"]=@(TLDProtectedSaveCount());d[@"blockedSaveDeletes"]=@(TLDBlockedSaveDeletes());
 NSMutableArray *slots=[NSMutableArray new];for(auto &entry:b.slots){auto &s=entry.second;[slots addObject:@{@"key":@(entry.first.c_str()),@"field":@(api.fieldName(s.member)),@"original":[NSData dataWithBytes:s.original.data() length:s.original.size()].description,@"last":[NSData dataWithBytes:s.last.data() length:s.last.size()].description}];}d[@"ownedFields"]=slots;
 try{auto k=type("Time","UnityEngine","UnityEngine.CoreModule.dll");d[@"timeScale"]=@(number(call(method(k,"get_timeScale",0),nullptr)));}catch(const std::exception&){}

 if(!b.ready)return d;
 try{d[@"inventoryGearCount"]=@(gear().size());d[@"timeOfDay"]=@(getNumber(component("GetTimeOfDayComponent"),"GetNormalizedTime")*24);d[@"weatherStage"]=@(getNumber(component("GetWeatherComponent"),"GetWeatherStage"));d[@"temperature"]=@(getNumber(component("GetWeatherComponent"),"GetCurrentTemperature"));}catch(const std::exception& e){d[@"readError"]=@(e.what());}
 for(auto pair:{std::pair{"GetConditionComponent","m_CurrentHP"},{"GetFreezingComponent","m_CurrentFreezing"},{"GetFatigueComponent","m_CurrentFatigue"},{"GetHungerComponent","m_CurrentReserveCalories"},{"GetThirstComponent","m_CurrentThirst"},{"GetPlayerMovementComponent","m_SprintStamina"}}){try{d[@(pair.second)]=@(scalar(component(pair.first),pair.second));}catch(const std::exception& e){d[@(pair.second)]=@(e.what());}}
 return d;}
