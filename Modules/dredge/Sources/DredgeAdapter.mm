// SPDX-License-Identifier: GPL-3.0-only
#import "DredgeAdapter.h"
#import "DredgeNative.h"
#include "DredgeMono.hpp"
#include "DredgeHarvestTypes.hpp"
#include "DredgeSalePrice.hpp"
#include <array>
#include <map>
#include <memory>
#include <algorithm>
#include <cmath>
#include <cstring>
namespace {
using namespace dr;
using Bytes=std::vector<uint8_t>;
struct Lease {Root owner;Klass klass=nullptr;Field field=nullptr;Bytes original,last;int feature=-1;bool isStatic=false,saleCompensation=false;};
struct RodLease {Root data,array;dredge::HarvestTypeLease first;bool touched=false;};
struct Context {
 Root manager,player,save,config,stats,controller,time,items,grid,ui,research;
 bool ready=false;std::string identity;NSString *note=@"Warte auf einen geladenen DREDGE-Spielstand.";
};
struct State {
 Context context;std::array<bool,MTFeatureCount>wanted{},active{};std::array<double,MTFeatureCount>values{};
 std::array<NSString *,MTFeatureCount>notes{};std::vector<Lease> leases;
 Root equipmentStats,researchPart,researchGrid;bool equipmentHeld=false;
 std::vector<RodLease> rods;
 CFAbsoluteTime nextScan=0;bool forceScan=true;uint64_t frames=0,scans=0;
 bool moneyHeld=false;Root moneySave;Bytes moneyOriginal,moneyLast;
 bool speedHeld=false;float speedOriginal=1,speedLast=1;
 Root definitionsOwner;std::map<std::string,Root> definitions;
};
Klass cls(Object object){if(!object)throw std::runtime_error("Der ursprüngliche Besitzer fehlt.");return api.objectClass(object);}
Object r(Object object,const char *name){return ref(object,cls(object),name);}
double n(Object object,const char *name){return number(object,cls(object),name);}
bool is(Object object,const char *name){if(!object)return false;Klass target=type("",name);for(Klass k=cls(object);k;k=api.parent(k))if(k==target)return true;return false;}
Object getter(Object object,const char *name,const char *result){return call(typedMethod(cls(object),name,result,{},false),object);}
std::vector<Root> list(Object object,size_t limit=4096){
 std::vector<Root> out;if(!object)return out;Klass k=cls(object);
 int count=(int)unboxNumber(call(typedMethod(k,"get_Count","System.Int32",{},false),object));
 if(count<0||(size_t)count>limit)throw std::runtime_error("Die ursprüngliche Liste überschreitet die geprüfte Grenze.");
 Method get=method(k,"get_Item",1);void *sig=api.signature(get),*iter=nullptr;
 if(typeName(api.params(sig,&iter))!="System.Int32")throw std::runtime_error("Die ursprüngliche Listenindexart weicht ab.");
 int kind=api.kind(api.returnType(sig));if(kind!=18&&kind!=21&&kind!=28)throw std::runtime_error("Die ursprüngliche Liste enthält keine Referenzobjekte.");
 out.reserve((size_t)count);for(int i=0;i<count;i++){Object item=call(get,object,{&i});if(item)out.emplace_back(item);}
 return out;
}
Object itemData(State& s,Object item){
 Object cached=r(item,"_itemData");if(cached)return cached;
 Object owner=s.context.items.get();if(!owner)return nullptr;
 if(s.definitionsOwner.get()!=owner||s.definitions.empty()){
  s.definitions.clear();s.definitionsOwner.reset(owner,true);
  for(auto &entry:list(r(owner,"allItems"),4096)){std::string key=text(r(entry.get(),"id"));if(!key.empty())s.definitions.emplace(key,Root(entry.get(),true));}
 }
 auto entry=s.definitions.find(text(r(item,"id")));return entry==s.definitions.end()?nullptr:entry->second.get();
}
Bytes decimal(double value){
 if(!std::isfinite(value)||std::abs(value)>1e12)throw std::runtime_error("Der Geldbetrag liegt außerhalb des geprüften Bereichs.");
 Object boxed=call(typedMethod(type("System","Decimal","mscorlib"),"op_Explicit","System.Decimal",{"System.Double"},true),nullptr,{&value});
 if(!boxed||typeName(api.classType(cls(boxed)))!="System.Decimal")throw std::runtime_error("Die ursprüngliche Dezimaldarstellung weicht ab.");
 uint32_t align=0;if(api.valueSize(cls(boxed),&align)!=16)throw std::runtime_error("Die ursprüngliche Dezimalgröße weicht ab.");
 Bytes bytes(16);memcpy(bytes.data(),api.unbox(boxed),16);return bytes;
}
double decimalValue(const Bytes& bytes){
 if(bytes.size()!=16)throw std::runtime_error("Ungültige Dezimaldarstellung.");
 Object result=call(typedMethod(type("System","Decimal","mscorlib"),"ToDouble","System.Double",{"System.Decimal"},true),nullptr,{(void *)bytes.data()});return unboxNumber(result,13);
}
Bytes funds(Object save){Object boxed=getter(save,"get_Funds","System.Decimal");uint32_t align=0;if(!boxed||api.valueSize(cls(boxed),&align)!=16)throw std::runtime_error("Der ursprüngliche Geldwert fehlt.");Bytes bytes(16);memcpy(bytes.data(),api.unbox(boxed),16);return bytes;}
void changeFunds(Object manager,const Bytes& delta){call(typedMethod(cls(manager),"AddFunds","System.Void",{"System.Decimal"},false),manager,{(void *)delta.data()});}
Lease& lease(State& s,int feature,Object owner,const char *name,Klass staticClass=nullptr){
 Klass k=owner?cls(owner):staticClass;Field f=field(k,name);
 for(auto &slot:s.leases)if(slot.feature==feature&&slot.field==f&&slot.owner.get()==owner&&slot.isStatic==!owner)return slot;
 if(s.leases.size()>=4096)throw std::runtime_error("Die Grenze eigener Feldänderungen ist erreicht.");
 Lease slot;slot.owner.reset(owner,true);slot.klass=k;slot.field=f;slot.feature=feature;slot.isStatic=!owner;slot.original=read(owner,k,f);slot.last=slot.original;
 s.leases.push_back(std::move(slot));return s.leases.back();
}
void ownBytes(State& s,int feature,Object owner,const char *name,const Bytes& target,Klass staticClass=nullptr){
 Lease& slot=lease(s,feature,owner,name,staticClass);Bytes current=read(owner,slot.klass,slot.field);
 if(current!=target)write(owner,slot.klass,slot.field,target);
 if(read(owner,slot.klass,slot.field)!=target)throw std::runtime_error("Die native Wirkung konnte nicht zurückgelesen werden.");slot.last=target;
}
void own(State& s,int feature,Object owner,const char *name,double value,Klass staticClass=nullptr){Klass k=owner?cls(owner):staticClass;ownBytes(s,feature,owner,name,numeric(field(k,name),value),staticClass);}
void multiply(State& s,int feature,Object owner,const char *name,double factor){
 Lease& slot=lease(s,feature,owner,name);double original=0;if(scalarKind(slot.field)!=12||slot.original.size()!=4)throw std::runtime_error("Ein ursprünglicher Fließkommafaktor wurde erwartet.");float value;memcpy(&value,slot.original.data(),4);original=value;
 if(!std::isfinite(original)||original<=0)throw std::runtime_error("Der ursprüngliche Faktor ist nicht gültig.");own(s,feature,owner,name,original*factor);
}
void restore(State& s,int feature=-1){
 for(auto it=s.leases.begin();it!=s.leases.end();){if(feature>=0&&it->feature!=feature){++it;continue;}
  try{Object owner=it->owner.get();if((owner||it->isStatic)&&read(owner,it->klass,it->field)==it->last)write(owner,it->klass,it->field,it->original);}catch(...){ }
  it=s.leases.erase(it);
 }
}
char *rodElement(const RodLease& slot){
 Object data=slot.data.get(),array=slot.array.get();
 if(!data||!array||r(data,"harvestableTypes")!=array)throw std::runtime_error("Der ursprüngliche Rutenbesitzer hat gewechselt.");
 Field member=field(cls(data),"harvestableTypes");
 if(typeName(api.fieldType(member))!="HarvestableType[]"||typeName(api.classType(cls(array)))!="HarvestableType[]")throw std::runtime_error("Die ursprüngliche Fangtyp-Anordnung weicht ab.");
 uintptr_t count=api.arrayLength(array);if(count<1||count>64)throw std::runtime_error("Die ursprüngliche Rutenfangtyp-Grenze weicht ab.");
 char *first=api.arrayAddress(array,4,0),*last=api.arrayAddress(array,4,count-1);
 if(!first||(uintptr_t)first%alignof(int32_t)||(uintptr_t)first>UINTPTR_MAX-(count-1)*4||last!=first+(count-1)*4)throw std::runtime_error("Die ursprüngliche Fangtyp-Speicheranordnung weicht ab.");
 return first;
}
int32_t rodRead(const RodLease& slot){int32_t value;memcpy(&value,rodElement(slot),4);return value;}
void rodWrite(const RodLease& slot,int32_t value){memcpy(rodElement(slot),&value,4);}
void rodsOff(State& s){for(auto &slot:s.rods)try{slot.first.release([&]{return rodRead(slot);},[&](int32_t value){rodWrite(slot,value);});}catch(...){ }s.rods.clear();}
void refreshEquipmentPromptIfIdle(State& s){
 Object ui=s.context.ui.get();if(!ui||!n(ui,"<IsHarvesting>k__BackingField"))return;
 Object view=r(ui,"harvestMinigameView");if(!view||!r(view,"currentPOI"))return;Object minigame=r(view,"activeMinigame");
 if(!minigame||!n(minigame,"isGameRunning"))call(typedMethod(cls(view),"RefreshHarvestTarget","System.Void",{},false),view);
}
void equipmentOff(State& s){
 rodsOff(s);
 if(s.equipmentHeld)try{if(Object stats=s.equipmentStats.get()){call(typedMethod(cls(stats),"CalculateRodStats","System.Void",{},false),stats);refreshEquipmentPromptIfIdle(s);}}catch(...){ }
 s.equipmentHeld=false;s.equipmentStats.reset();
}
void researchOff(State& s){
 // Remove only our unspent instance, never another research part or progress.
 try{Object part=s.researchPart.get(),grid=s.researchGrid.get();if(part&&grid){for(auto &entry:list(r(grid,"spatialItems"),4096))if(entry.get()==part){
   uint8_t notify=1;call(typedMethod(cls(grid),"RemoveObjectFromGridData","System.Void",{"SpatialItemInstance","System.Boolean"},false),grid,{part,&notify});
   // Removal updates the grid, but DREDGE caches research counts separately.
   // Recompute through the original method; never fabricate the cached count.
   if(Object helper=s.context.research.get())call(typedMethod(cls(helper),"UpdatePartCount","System.Void",{},false),helper);
   break;
  }}}catch(...){ }
 s.researchPart.reset();s.researchGrid.reset();
}
void moneyOff(State& s){
 try{Object save=s.moneySave.get(),manager=s.context.manager.get();if(s.moneyHeld&&save&&manager&&s.context.save.get()==save&&funds(save)==s.moneyLast)changeFunds(manager,decimal(decimalValue(s.moneyOriginal)-decimalValue(s.moneyLast)));}catch(...){ }
 s.moneyHeld=false;s.moneySave.reset();s.moneyOriginal.clear();s.moneyLast.clear();
}
void speedOff(State& s){
 if(s.speedHeld)try{Klass time=type("UnityEngine","Time","UnityEngine.CoreModule");double current=unboxNumber(call(typedMethod(time,"get_timeScale","System.Single",{},true)),12);
  if(std::abs(current-s.speedLast)<.0001)call(typedMethod(time,"set_timeScale","System.Void",{"System.Single"},true),nullptr,{&s.speedOriginal});
 }catch(...){ }
 s.speedHeld=false;
}
void off(State& s,int feature){
 std::vector<Root> saleOwners;
 if(feature==MTFeatureSellPrice)for(auto &slot:s.leases)if(slot.feature==feature&&!slot.saleCompensation)if(Object owner=slot.owner.get())saleOwners.emplace_back(owner);
 restore(s,feature);
 if(feature==MTFeatureSellPrice)for(auto &owner:saleOwners)try{
  if(s.context.grid.get())for(auto &entry:list(r(s.context.grid.get(),"activeActionHandlers"),64))if(entry.get()==owner.get()){
   call(typedMethod(cls(owner.get()),"CheckSellAllValidity","System.Void",{},false),owner.get());
   call(typedMethod(cls(owner.get()),"OnFocusedGridCellChanged","System.Void",{},false),owner.get());break;
  }
 }catch(...){ }
 if(feature==MTFeatureEquipment)equipmentOff(s);
 if(feature==MTFeatureResearch)researchOff(s);
 if(feature==MTFeatureMoney)moneyOff(s);
 if(feature==MTFeatureGameSpeed)speedOff(s);
 s.active[feature]=false;
}
void release(State& s){restore(s);equipmentOff(s);researchOff(s);moneyOff(s);speedOff(s);s.active.fill(false);s.forceScan=true;s.definitions.clear();s.definitionsOwner.reset();}
bool refresh(State& s){
 auto &c=s.context;Object manager=ref(nullptr,type("","GameManager"),"Instance");
 Object player=manager?r(manager,"<Player>k__BackingField"):nullptr;
 Object save=manager?getter(manager,"get_SaveData","SaveData"):nullptr;
 bool ready=manager&&player&&save&&n(manager,"<IsPlaying>k__BackingField")&&n(player,"<IsAlive>k__BackingField");
 if(c.manager.get()!=manager||c.player.get()!=player||c.save.get()!=save){release(s);c.manager.reset(manager,true);c.player.reset(player,true);c.save.reset(save,true);s.forceScan=true;}
 c.ready=ready;
 if(!ready){if(!s.leases.empty()||s.equipmentHeld||s.researchPart.get()||s.moneyHeld)release(s);c.note=@"Warte auf einen geladenen, lebenden Spieler.";return false;}
 c.config.reset(getter(manager,"get_GameConfigData","GameConfigData"),true);c.stats.reset(r(manager,"<PlayerStats>k__BackingField"),true);c.controller.reset(r(player,"_controller"),true);
 c.time.reset(r(manager,"<Time>k__BackingField"),true);c.items.reset(r(manager,"_itemManager"),true);c.grid.reset(r(manager,"<GridManager>k__BackingField"),true);c.ui.reset(r(manager,"<UI>k__BackingField"),true);c.research.reset(r(manager,"<ResearchHelper>k__BackingField"),true);
 char identity[128];snprintf(identity,sizeof(identity),"dredge:%p:%p:%p",manager,player,save);c.identity=identity;c.note=@"Originaler DREDGE-Spielzustand bestätigt.";return true;
}
bool equipment(State& s){Object stats=s.context.stats.get();if(!stats)return false;bool ok=true,changed=false;
 // The original minigame separately inspects installed rods' actual type
 // arrays. PlayerStats' capability sets alone do not bypass that second gate.
 Object ui=s.context.ui.get(),view=ui?r(ui,"harvestMinigameView"):nullptr;
 Object target=view?r(view,"itemDataToHarvest"):nullptr;
 bool fishing=ui&&n(ui,"<IsHarvesting>k__BackingField")&&target&&((int)n(target,"itemSubtype")==1);
 if(fishing){
  int32_t required=(int32_t)n(target,"harvestableType");
  for(auto &slot:s.rods)slot.touched=false;
  Object inventory=getter(s.context.save.get(),"get_Inventory","SerializableGrid");
  if(inventory)for(auto &entry:list(r(inventory,"spatialItems"),4096)){
   Object instance=entry.get(),data=itemData(s,instance);if(!data||((int)n(data,"itemSubtype")!=4))continue;
   if(unboxNumber(getter(instance,"GetIsOnDamagedCell","System.Boolean"),2))continue;
   Object array=r(data,"harvestableTypes");if(!array)continue;
   auto found=std::find_if(s.rods.begin(),s.rods.end(),[&](const RodLease& slot){return slot.data.get()==data&&slot.array.get()==array;});
   if(found==s.rods.end()){if(s.rods.size()>=128)throw std::runtime_error("Die Grenze eigener Rutenänderungen ist erreicht.");RodLease slot;slot.data.reset(data,true);slot.array.reset(array,true);s.rods.push_back(std::move(slot));found=std::prev(s.rods.end());}
   found->touched=true;changed|=rodRead(*found)!=required;found->first.apply(required,[&]{return rodRead(*found);},[&](int32_t value){rodWrite(*found,value);});
  }
  for(auto it=s.rods.begin();it!=s.rods.end();)if(!it->touched){try{it->first.release([&]{return rodRead(*it);},[&](int32_t value){rodWrite(*it,value);});}catch(...){ }it=s.rods.erase(it);}else ++it;
  ok=unboxNumber(call(typedMethod(cls(view),"HasUndamagedEquipment","System.Boolean",{},false),view),2)!=0;
 }else rodsOff(s);
 for(const char *name:{"<HarvestableTypes>k__BackingField","<AdvancedHarvestableTypes>k__BackingField"}){Object set=r(stats,name);if(!set)return false;Klass k=cls(set);Method contains=typedMethod(k,"Contains","System.Boolean",{"HarvestableType"},false),add=typedMethod(k,"Add","System.Boolean",{"HarvestableType"},false);
  for(int32_t kind=1;kind<=10;kind++){if(!unboxNumber(call(contains,set,{&kind}),2)){call(add,set,{&kind});changed=true;}ok&=unboxNumber(call(contains,set,{&kind}),2)!=0;}}
 if(fishing&&changed){
  // Original equipment-change notification rebuilds the prompt and prepares
  // the minigame. Do that only for a real capability change before a run.
  refreshEquipmentPromptIfIdle(s);
 }
 s.equipmentStats.reset(stats,true);s.equipmentHeld=true;return ok;
}
bool harvest(State& s){Object ui=s.context.ui.get();if(!ui)return false;Object view=r(ui,"harvestMinigameView");if(!view)return false;Object minigame=r(view,"activeMinigame");if(!minigame||!n(minigame,"isGameRunning"))return false;
 Field f=field(cls(minigame),"progress");auto target=numeric(f,1);if(read(minigame,cls(minigame),f)!=target)write(minigame,cls(minigame),f,target);return read(minigame,cls(minigame),f)==target;
}
bool research(State& s){Object helper=s.context.research.get(),save=s.context.save.get(),items=s.context.items.get();if(!helper||!save||!items)return false;
 Object data=r(helper,"researchItemData");if(!data)return false;Object id=r(data,"id"),storage=getter(save,"get_Storage","SerializableGrid"),inventory=getter(save,"get_Inventory","SerializableGrid");if(!id||!storage)return false;
 // Actual item identity is read from the original research definition.
 std::string expected=text(id);bool present=false;
 for(Object grid:{inventory,storage})if(grid)for(auto &part:list(r(grid,"spatialItems"),4096))if(text(r(part.get(),"id"))==expected){present=true;break;}
 if(!present){uint8_t notify=1;Object result=call(typedMethod(cls(items),"AddItemById","ItemInstance",{"System.String","SerializableGrid","System.Boolean"},false),items,{id,storage,&notify});if(result){s.researchPart.reset(result,true);s.researchGrid.reset(storage,true);}}
 call(typedMethod(cls(helper),"UpdatePartCount","System.Void",{},false),helper);
 return unboxNumber(getter(helper,"get_TotalPartCount","System.Int32"))>0;
}
bool scanItems(State& s,int feature){Object save=s.context.save.get();if(!save)return false;bool found=false;
 for(const char *getterName:{"get_Inventory","get_Storage","get_TrawlNet"}){
  Object grid=getter(save,getterName,"SerializableGrid");if(!grid)continue;
  for(const char *listName:{"spatialItems","spatialUnderlayItems"})for(auto &entry:list(r(grid,listName),4096)){
   Object item=entry.get();if(feature==MTFeatureInfection){if(is(item,"FishItemInstance")){own(s,feature,item,"isInfected",0);found=true;}continue;}
   Object data=itemData(s,item);if(!data||!is(data,"DeployableItemData"))continue;
   int subtype=(int)n(data,"itemSubtype");if((feature==MTFeatureNets&&subtype!=512)||(feature==MTFeaturePots&&subtype!=256))continue;
   double maximum=unboxNumber(getter(data,"get_MaxDurabilityDays","System.Single"),12);if(!std::isfinite(maximum)||maximum<=0||maximum>100000)continue;
   own(s,feature,item,"durability",maximum);found=true;
  }
 }
 if(feature==MTFeaturePots)for(auto &entry:list(r(save,"serializedCrabPotPOIs"),512)){
  Object pot=entry.get();Object data=r(pot,"deployableItemData");if(!data)continue;double maximum=unboxNumber(getter(data,"get_MaxDurabilityDays","System.Single"),12);
  if(std::isfinite(maximum)&&maximum>0&&maximum<100000){own(s,feature,pot,"durability",maximum);found=true;}
 }
 return found;
}
void refreshSale(Object handler){
 call(typedMethod(cls(handler),"CheckSellAllValidity","System.Void",{},false),handler);
 call(typedMethod(cls(handler),"OnFocusedGridCellChanged","System.Void",{},false),handler);
}
struct SalePlan {Root data;double correction=1;};
void restoreSaleCompensations(State& s,const std::vector<SalePlan>& plans){
 for(auto it=s.leases.begin();it!=s.leases.end();){
  if(it->feature!=MTFeatureSellPrice||!it->saleCompensation){++it;continue;}
  Object owner=it->owner.get();bool keep=owner&&std::any_of(plans.begin(),plans.end(),[&](const SalePlan &p){return p.data.get()==owner;});
  if(keep){++it;continue;}
  if(owner&&read(owner,it->klass,it->field)==it->last)write(owner,it->klass,it->field,it->original);
  it=s.leases.erase(it);
 }
}
bool sales(State& s){
 Object grid=s.context.grid.get();if(!grid)return false;
 std::vector<Root> handlers;for(auto &entry:list(r(grid,"activeActionHandlers"),64))if(is(entry.get(),"SellModeActionHandler"))handlers.emplace_back(entry.get());
 std::vector<SalePlan> plans;std::vector<Root> candidates;
 for(const char *name:{"get_Inventory","get_Storage","get_TrawlNet"})if(Object inventory=getter(s.context.save.get(),name,"SerializableGrid")){
  for(const char *field:{"spatialItems","spatialUnderlayItems"})for(auto &item:list(r(inventory,field),4096))candidates.emplace_back(item.get());
 }
 Object focused=getter(grid,"GetCurrentlyFocusedObject","GridObject");if(focused)if(Object item=getter(focused,"get_SpatialItemInstance","SpatialItemInstance"))candidates.emplace_back(item);
 bool changed=false;
 for(auto &entry:handlers){
  Object handler=entry.get();Lease &slot=lease(s,MTFeatureSellPrice,handler,"sellValueModifier");
  if(slot.original.size()!=4||scalarKind(slot.field)!=12)throw std::runtime_error("Ungültiger ursprünglicher Verkaufspreistyp.");
  float original;memcpy(&original,slot.original.data(),4);double correction=dredge::resaleCorrection(original);
  if(correction==1)continue;
  for(auto &item:candidates){
   Object data=itemData(s,item.get());if(!data||((int)n(data,"itemSubtype")==1))continue;
   uint8_t bulk=0;if(!unboxNumber(call(typedMethod(cls(handler),"DoesStoreAcceptThisItem","System.Boolean",{"SpatialItemData","System.Boolean"},false),handler,{data,&bulk}),2))continue;
   auto found=std::find_if(plans.begin(),plans.end(),[&](const SalePlan &p){return p.data.get()==data;});
   if(found!=plans.end()){if(found->correction!=correction)throw std::runtime_error("Widersprüchliche Händlerpreise; keine fremden Preiswerte verändert.");continue;}
   SalePlan plan;plan.data.reset(data,true);plan.correction=correction;plans.push_back(std::move(plan));
  }
 }
 size_t before=s.leases.size();restoreSaleCompensations(s,plans);changed=before!=s.leases.size();
 for(auto &plan:plans){
  Object data=plan.data.get();Bytes flag=lease(s,MTFeatureSellPrice,data,"hasSellOverride").original;
  Bytes originalOverride=lease(s,MTFeatureSellPrice,data,"sellOverrideValue").original;
  Bytes original=flag[0]?originalOverride:read(data,cls(data),field(cls(data),"value"));
  Bytes ratio=decimal(plan.correction);Object value=call(typedMethod(type("System","Decimal","mscorlib"),"op_Multiply","System.Decimal",{"System.Decimal","System.Decimal"},true),nullptr,{original.data(),ratio.data()});
  uint32_t alignment=0;if(!value||api.valueSize(cls(value),&alignment)!=16)throw std::runtime_error("Ursprüngliche Wiederverkaufsdarstellung weicht ab.");
  Bytes target(16);memcpy(target.data(),api.unbox(value),16);
  changed|=read(data,cls(data),field(cls(data),"sellOverrideValue"))!=target||!n(data,"hasSellOverride");
  ownBytes(s,MTFeatureSellPrice,data,"sellOverrideValue",target);lease(s,MTFeatureSellPrice,data,"sellOverrideValue").saleCompensation=true;
  own(s,MTFeatureSellPrice,data,"hasSellOverride",1);lease(s,MTFeatureSellPrice,data,"hasSellOverride").saleCompensation=true;
 }
 for(auto &entry:handlers){
  Object handler=entry.get();float original;Bytes baseline=lease(s,MTFeatureSellPrice,handler,"sellValueModifier").original;memcpy(&original,baseline.data(),4);
  float target=(float)dredge::saleModifier(original,s.values[MTFeatureSellPrice]);bool handlerChanged=n(handler,"sellValueModifier")!=target;
  own(s,MTFeatureSellPrice,handler,"sellValueModifier",target);
  if(handlerChanged||changed)refreshSale(handler);
 }
 return !handlers.empty();
}
bool upgrades(State& s){Object manager=r(s.context.manager.get(),"_upgradeManager");if(!manager)return false;bool found=false;
 for(auto &entry:list(r(manager,"allUpgradeData"),512)){
  Object upgrade=entry.get();ownBytes(s,MTFeatureUpgrades,upgrade,"monetaryCost",decimal(0));
  for(auto &cost:list(r(upgrade,"upgradeCost"),512))own(s,MTFeatureUpgrades,cost.get(),"num",0);
  for(auto &cost:list(r(upgrade,"itemCost"),512))own(s,MTFeatureUpgrades,cost.get(),"count",0);
  found=true;
 }return found;
}
void pulse(State& s){if(!DRInFrame())return;s.frames++;
 bool work=std::any_of(s.wanted.begin(),s.wanted.end(),[](bool on){return on;});
 if(!work)return; // No owner lookup, inventory, recipe or scene scan in idle frames.
 if(!s.context.ready)return;
 try{Object manager=ref(nullptr,type("","GameManager"),"Instance");
  if(manager!=s.context.manager.get()||r(manager,"<Player>k__BackingField")!=s.context.player.get()||!n(manager,"<IsPlaying>k__BackingField")||!n(s.context.player.get(),"<IsAlive>k__BackingField")){release(s);s.context.ready=false;return;}
 }catch(...){release(s);s.context.ready=false;return;}
 CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();bool scan=s.forceScan||now>=s.nextScan;s.forceScan=false;if(scan){s.nextScan=now+.25;s.scans++;
  s.leases.erase(std::remove_if(s.leases.begin(),s.leases.end(),[](const Lease& slot){return !slot.isStatic&&!slot.owner.get();}),s.leases.end());
 }
 for(int f=0;f<MTFeatureCount;f++){
  if(!s.wanted[f])continue;if((f==MTFeatureMoney||f==MTFeatureSellPrice||f==MTFeatureEquipment||f==MTFeatureInfection||f==MTFeatureNets||f==MTFeaturePots||f==MTFeatureResearch||f==MTFeatureUpgrades)&&!scan)continue;
  try{bool active=false;Object config=s.context.config.get();
   switch(f){
    case MTFeatureGod:own(s,f,s.context.player.get(),"<IsGodModeEnabled>k__BackingField",1);own(s,f,s.context.player.get(),"<IsImmuneModeEnabled>k__BackingField",1);active=true;break;
    case MTFeatureMoney:{Object save=s.context.save.get(),manager=s.context.manager.get();Bytes current=funds(save);double amount=decimalValue(current);
     if(amount<9999999){
      // Capture the latest original change before our write. Merely observing
      // an external reward above the minimum never makes that reward our own.
      if(!s.moneyHeld||current!=s.moneyLast){s.moneySave.reset(save,true);s.moneyOriginal=current;s.moneyHeld=true;}
      changeFunds(manager,decimal(9999999-amount));s.moneyLast=funds(save);current=s.moneyLast;
     }
     active=decimalValue(current)>=9999999;break;}
    case MTFeatureSellPrice:active=sales(s);break;
    case MTFeatureEquipment:active=equipment(s);break;
    case MTFeatureHarvest:active=harvest(s);break;
    case MTFeatureSpoil:own(s,f,config,"freshnessLossPerDay",0);active=true;break;
    case MTFeatureInfection:own(s,f,config,"itemInfectionSpreadChance",0);own(s,f,config,"darkSplashInfectionChance",0);(void)scanItems(s,f);active=true;break;
    case MTFeatureNets:case MTFeaturePots:active=scanItems(s,f);break;
    case MTFeatureResearch:active=research(s);break;
    case MTFeatureUpgrades:active=upgrades(s);break;
    case MTFeatureMovement:multiply(s,f,s.context.controller.get(),"_baseMovementModifier",s.values[f]);active=true;break;
    case MTFeatureGameSpeed:{Klass time=type("UnityEngine","Time","UnityEngine.CoreModule");auto get=typedMethod(time,"get_timeScale","System.Single",{},true),set=typedMethod(time,"set_timeScale","System.Void",{"System.Single"},true);
     float target=(float)s.values[f];double current=unboxNumber(call(get),12);if(n(s.context.manager.get(),"<IsPaused>k__BackingField")){s.notes[f]=@"Pausiert; Tempo bleibt vorgemerkt.";active=false;break;}
     // Unity's Time is native-backed, so preserve its accessor and own baseline separately.
     if(!s.speedHeld){s.speedOriginal=(float)current;s.speedHeld=true;}
     if(current!=target)call(set,nullptr,{&target});s.speedLast=target;active=std::abs(unboxNumber(call(get),12)-target)<.0001;break;}
    case MTFeatureFreezeTime:own(s,f,s.context.time.get(),"_freezeTime",1);active=true;break;
    case MTFeatureTimeSpeed:multiply(s,f,config,"hourDurationInSeconds",1/s.values[f]);active=true;break;
   }
   s.active[f]=active;s.notes[f]=active?@"Native Wirkung zurückgelesen.":f==MTFeatureResearch?@"Warte auf einen freien Lagerplatz für ein Forschungsteil.":@"Warte auf den passenden Spielzustand oder Gegenstand.";
  }catch(const std::exception& e){s.active[f]=false;s.notes[f]=@(e.what());}
 }
}
}
static __weak DredgeAdapter *observedAdapter;
@implementation DredgeAdapter { std::unique_ptr<State> _native;BOOL _registered; }
- (instancetype)init {if((self=[super init])){_native=std::make_unique<State>();for(int f=0;f<MTFeatureCount;f++)_native->values[f]=MTFeatureInfoAt((MTFeature)f)->initial;observedAdapter=self;}return self;}
- (void)onGameThread:(dispatch_block_t)work {
 __weak DredgeAdapter *weakSelf=self;
 BOOL queued=DREnqueueChecked(^{DredgeAdapter *owner=weakSelf;if(!owner)return;if(!owner->_registered){owner->_registered=YES;DRSetFrameHandler(^{DredgeAdapter *target=weakSelf;if(target)pulse(*target->_native);});}work();},^{dispatch_async(dispatch_get_main_queue(),work);});
 if(!queued)dispatch_async(dispatch_get_main_queue(),work);
}
- (MTGameContext *)captureContext {
 MTGameContext *context=[MTGameContext new];context.identity=@"dredge-unavailable";
 if(!DRSupportedImage()){context.kind=MTSessionUnsupported;context.note=@"Dieses Originalprogramm ist nicht für den DREDGE-Trainer freigegeben.";return context;}
 if(!DRInFrame()){context.kind=MTSessionLoading;context.note=DRNativeObservation()[@"nativeNote"] ?: @"Warte auf den originalen Unity-Rückruf.";return context;}
 try{bool ready=refresh(*_native);context.kind=ready?MTSessionSolo:MTSessionLoading;context.identity=@(_native->context.identity.c_str());context.note=_native->context.note;}
 catch(const std::exception& e){_native->context.ready=false;_native->active.fill(false);context.kind=MTSessionLoading;context.note=@(e.what());}return context;
}
- (void)releaseEffects {if(!DRInFrame())return;_native->wanted.fill(false);release(*_native);}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
 MTFeatureState *result=[MTFeatureState new];result.wanted=wanted;result.value=value;
 if(feature<0||feature>=MTFeatureCount||!DRInFrame()){result.note=@"Kein bestätigter ursprünglicher Spielthread.";return result;}
 const MTFeatureInfo *info=MTFeatureInfoAt(feature);if(!std::isfinite(value)||(info->numeric&&(value<info->minimum||value>info->maximum))){result.note=@"Der Wert liegt außerhalb des gültigen Bereichs.";return result;}
 auto &state=*_native;bool changed=state.wanted[feature]!=wanted||state.values[feature]!=value;
 state.wanted[feature]=wanted;state.values[feature]=value;result.available=state.context.ready;
 if(changed){if(!wanted)off(state,(int)feature);else{state.forceScan=true;pulse(state);}}
 result.active=wanted&&state.active[feature];result.note=state.notes[feature] ?: info->detail;return result;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {(void)feature;(void)value;return @"Dieser Trainer enthält ausschließlich Dauerschalter.";}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return DRMouse(wanted);}
- (NSDictionary *)nativeObservation {
 if(!DRInFrame())return DRNativeObservation();auto &s=*_native;NSMutableDictionary *result=[DRNativeObservation() mutableCopy];
 result[@"ready"]=@(s.context.ready);result[@"identity"]=@(s.context.identity.c_str());result[@"ownedFields"]=@(s.leases.size());result[@"effectFrames"]=@(s.frames);result[@"activeScans"]=@(s.scans);
 NSMutableArray *features=[NSMutableArray new];for(int f=0;f<MTFeatureCount;f++)[features addObject:@{@"id":@(f),@"wanted":@(s.wanted[f]),@"active":@(s.active[f]),@"note":s.notes[f] ?: @""}];result[@"features"]=features;
 return result;
}
- (NSDictionary *)observation {
 if(!DRInFrame())return @{@"ready":@NO,@"error":@"Beobachtung nur auf dem ursprünglichen Spielthread."};
 NSMutableDictionary *result=[[self nativeObservation] mutableCopy];auto &s=*_native;
 if(!s.context.ready)return result;
 try{
  Object player=s.context.player.get(),save=s.context.save.get(),config=s.context.config.get(),time=s.context.time.get(),controller=s.context.controller.get(),helper=s.context.research.get();
  result[@"godMode"]=@(n(player,"<IsGodModeEnabled>k__BackingField"));result[@"immuneMode"]=@(n(player,"<IsImmuneModeEnabled>k__BackingField"));result[@"funds"]=@(decimalValue(funds(save)));
  result[@"freezeTime"]=@(n(time,"_freezeTime"));result[@"hourDurationInSeconds"]=@(n(config,"hourDurationInSeconds"));result[@"movementModifier"]=@(n(controller,"_baseMovementModifier"));
  result[@"freshnessLossPerDay"]=@(n(config,"freshnessLossPerDay"));result[@"infectionChance"]=@(n(config,"itemInfectionSpreadChance"));result[@"darkSplashInfectionChance"]=@(n(config,"darkSplashInfectionChance"));
  result[@"dayTime"]=@(unboxNumber(getter(time,"get_Time","System.Single"),12));
  Klass unityTime=type("UnityEngine","Time","UnityEngine.CoreModule");result[@"gameSpeed"]=@(unboxNumber(call(typedMethod(unityTime,"get_timeScale","System.Single",{},true)),12));
  result[@"paused"]=@(n(s.context.manager.get(),"<IsPaused>k__BackingField"));
  if(helper)result[@"researchCount"]=@(unboxNumber(getter(helper,"get_TotalPartCount","System.Int32")));
  NSMutableArray *items=[NSMutableArray new];
  for(const char *name:{"get_Inventory","get_Storage","get_TrawlNet"}){Object grid=getter(save,name,"SerializableGrid");if(!grid)continue;
   for(auto &entry:list(r(grid,"spatialItems"),4096)){Object item=entry.get();NSMutableDictionary *record=[@{@"grid":@(name),@"id":@(text(r(item,"id")).c_str()),@"durability":@(n(item,"durability"))} mutableCopy];
    if(is(item,"FishItemInstance")){record[@"freshness"]=@(n(item,"freshness"));record[@"infected"]=@(n(item,"isInfected"));}[items addObject:record];}}
  result[@"items"]=items;
  Object ui=s.context.ui.get(),view=ui?r(ui,"harvestMinigameView"):nullptr,minigame=view?r(view,"activeMinigame"):nullptr;
  if(minigame){result[@"harvestRunning"]=@(n(minigame,"isGameRunning"));result[@"harvestProgress"]=@(n(minigame,"progress"));}
  if(view&&r(view,"itemDataToHarvest"))result[@"hasUndamagedEquipment"]=@(unboxNumber(call(typedMethod(cls(view),"HasUndamagedEquipment","System.Boolean",{},false),view),2));
  NSMutableArray *rods=[NSMutableArray new];for(auto &slot:s.rods){int32_t current=rodRead(slot);[rods addObject:@{@"id":@(text(r(slot.data.get(),"id")).c_str()),@"original":@(slot.first.original),@"last":@(slot.first.last),@"current":@(current),@"currentMatches":@(current==slot.first.last)}];}result[@"rodLeases"]=rods;
  NSMutableArray *fieldValues=[NSMutableArray new];for(auto &slot:s.leases){Object owner=slot.owner.get();if(!owner&&!slot.isStatic)continue;
   NSMutableDictionary *record=[@{@"feature":@(slot.feature),@"bytes":@(slot.last.size()),@"currentMatches":[NSNumber numberWithBool:read(owner,slot.klass,slot.field)==slot.last]} mutableCopy];
   if(scalarKind(slot.field)==12&&slot.original.size()==4){float original,last;memcpy(&original,slot.original.data(),4);memcpy(&last,slot.last.data(),4);record[@"original"]=@(original);record[@"last"]=@(last);}[fieldValues addObject:record];}
  result[@"leases"]=fieldValues;
  NSMutableArray *prices=[NSMutableArray new];
  Object grid=s.context.grid.get(),focused=grid?getter(grid,"GetCurrentlyFocusedObject","GridObject"):nullptr;
  Object focusedItem=focused?getter(focused,"get_SpatialItemInstance","SpatialItemInstance"):nullptr;
  for(auto &slot:s.leases)if(slot.feature==MTFeatureSellPrice&&!slot.saleCompensation&&slot.original.size()==4){
   Object handler=slot.owner.get();if(!handler)continue;float base;memcpy(&base,slot.original.data(),4);float current=(float)n(handler,"sellValueModifier");
   NSMutableDictionary *price=[@{@"baselineModifier":@(base),@"currentModifier":@(current),@"types":@(n(handler,"itemTypesBought")),@"subtypes":@(n(handler,"itemSubtypesBought"))} mutableCopy];
   if(focusedItem){Object data=itemData(s,focusedItem);uint8_t bulk=0;
    if(data&&unboxNumber(call(typedMethod(cls(handler),"DoesStoreAcceptThisItem","System.Boolean",{"SpatialItemData","System.Boolean"},false),handler,{data,&bulk}),2)){
     uint8_t selling=1;Method calculate=typedMethod(cls(s.context.items.get()),"GetItemValue","System.Decimal",{"SpatialItemInstance","System.Boolean","System.Single"},false);
     auto value=[&](float modifier){Object boxed=call(calculate,s.context.items.get(),{focusedItem,&selling,&modifier});if(!boxed||typeName(api.classType(cls(boxed)))!="System.Decimal")throw std::runtime_error("Ursprünglicher Verkaufspreis fehlt.");uint32_t alignment=0;if(api.valueSize(cls(boxed),&alignment)!=16)throw std::runtime_error("Ursprüngliche Dezimalgröße weicht ab.");Bytes bytes(16);memcpy(bytes.data(),api.unbox(boxed),16);return decimalValue(bytes);};
     price[@"baselinePrice"]=@(value(base));price[@"currentPrice"]=@(value(current));price[@"item"]=@(text(r(focusedItem,"id")).c_str());
    }
   }[prices addObject:price];
  }
  result[@"salePrices"]=prices;
  Object repaid=getter(save,"get_GreaterMarrowRepayments","System.Decimal");uint32_t repaidAlignment=0;
  if(repaid&&typeName(api.classType(cls(repaid)))=="System.Decimal"&&api.valueSize(cls(repaid),&repaidAlignment)==16){Bytes value(16);memcpy(value.data(),api.unbox(repaid),16);result[@"loanRepaid"]=@(decimalValue(value));}


 }catch(const std::exception& e){result[@"error"]=@(e.what());}
 return result;
}
@end
NSDictionary *DREffectObservation(void){DredgeAdapter *adapter=observedAdapter;return adapter?[adapter observation]:@{@"ready":@NO,@"error":@"Keine tatsächliche Trainerinstanz vorhanden."};}
