// SPDX-License-Identifier: GPL-3.0-only
// Session-scoped instrumentation. Linked only into a private test candidate.
#import "DredgeNative.h"
#import "GameProfile.h"
#include "DredgeMono.hpp"
#import <AppKit/AppKit.h>
#import <unistd.h>
#include <array>
#include <cmath>
extern "C" NSDictionary *DREffectObservation(void);
namespace {
using namespace dr;
struct EquipmentFixture {
 void *ownerDomain=nullptr;int32_t domainId=0;Root manager,save,grid,items;
 std::array<Root,2> instance,data;std::array<std::vector<uint8_t>,2> baseline;
 std::array<float,2> maximum{};bool armed=false;
};
EquipmentFixture &fixture=*new EquipmentFixture; // Process lifetime; no Mono calls during static teardown.
Klass objectClass(Object object){if(!object)throw std::runtime_error("Der ursprüngliche Testbesitzer fehlt.");return api.objectClass(object);}
Object objectField(Object object,const char *name){return ref(object,objectClass(object),name);}
Object get(Object object,const char *name,const char *result){return call(typedMethod(objectClass(object),name,result,{},false),object);}
bool subtype(Object object,const char *name){if(!object)return false;Klass expected=type("",name);for(Klass k=objectClass(object);k;k=api.parent(k))if(k==expected)return true;return false;}
std::vector<Root> references(Object list,size_t limit){
 std::vector<Root> out;if(!list)return out;Klass k=objectClass(list);
 int count=(int)unboxNumber(get(list,"get_Count","System.Int32"));if(count<0||(size_t)count>limit)throw std::runtime_error("Die ursprüngliche Testliste überschreitet ihre Grenze.");
 Method item=method(k,"get_Item",1);void *signature=api.signature(item),*iterator=nullptr;
 int kind=api.kind(api.returnType(signature));if(api.paramCount(signature)!=1||typeName(api.params(signature,&iterator))!="System.Int32"||(kind!=18&&kind!=21&&kind!=28))throw std::runtime_error("Die ursprüngliche Testliste enthält keine geprüften Referenzen.");
 for(int i=0;i<count;i++)if(Object object=call(item,list,{&i}))out.emplace_back(object);return out;
}
bool contains(Object grid,Object instance){for(auto &item:references(objectField(grid,"spatialItems"),4096))if(item.get()==instance)return true;return false;}
bool stillOwn(size_t index){Object object=fixture.instance[index].get(),data=fixture.data[index].get();if(!object||!data||!contains(fixture.grid.get(),object))return false;
 Object cached=objectField(object,"_itemData");return (!cached||cached==data)&&text(objectField(object,"id"))==text(objectField(data,"id"));}
void forgetFixture(bool staleDomain){
 // A torn-down domain must never receive GC-handle calls, even during cleanup.
 if(staleDomain){fixture.manager.handle=fixture.save.handle=fixture.grid.handle=fixture.items.handle=0;for(auto &r:fixture.instance)r.handle=0;for(auto &r:fixture.data)r.handle=0;}
 fixture=EquipmentFixture{};
}
Object validateFixture(bool existing){
 if(!DRSupportedImage()||!DRInFrame())throw std::runtime_error("Der bestätigte Originalrückruf fehlt.");
 if(existing&&(domain()!=fixture.ownerDomain||api.domainByID(fixture.domainId)!=fixture.ownerDomain)){forgetFixture(true);throw std::runtime_error("Domain gewechselt; keine alten Testbesitzer berührt.");}
 Object manager=ref(nullptr,type("","GameManager"),"Instance");
 if(!manager||!number(manager,objectClass(manager),"<IsPlaying>k__BackingField"))throw std::runtime_error("Kein geladener lokaler Testkontext.");
 Object save=get(manager,"get_SaveData","SaveData"),player=objectField(manager,"<Player>k__BackingField");
 if(!save||!player||!number(player,objectClass(player),"<IsAlive>k__BackingField"))throw std::runtime_error("Kein lebender ursprünglicher Spieler.");
 if(existing&&(manager!=fixture.manager.get()||save!=fixture.save.get()||get(save,"get_Storage","SerializableGrid")!=fixture.grid.get()||objectField(manager,"_itemManager")!=fixture.items.get())){
  forgetFixture(false);throw std::runtime_error("Spielbesitzer gewechselt; alte Gegenstände wurden nicht angefasst.");
 }
 return manager;
}
bool productWanted(NSDictionary *effects,NSUInteger feature){NSArray *states=effects[@"features"];return states.count>feature&&[states[feature][@"wanted"] boolValue];}
void cleanupFixture(){
 validateFixture(true);Object grid=fixture.grid.get();
 for(size_t i=0;i<2;i++)if(Object object=fixture.instance[i].get()){
  if(!stillOwn(i))throw std::runtime_error("Eigener Gegenstand wurde verändert, verschoben oder verbraucht; keine fremde Position verändert.");
  uint8_t notify=1;call(typedMethod(objectClass(grid),"RemoveObjectFromGridData","System.Void",{"SpatialItemInstance","System.Boolean"},false),grid,{object,&notify});
  if(contains(grid,object))throw std::runtime_error("Ein eigener Testgegenstand konnte nicht entfernt werden.");
  fixture.instance[i].reset();fixture.data[i].reset();
 }
 forgetFixture(false);
}
NSDictionary *equipmentRequest(NSString *action){
 try{
  NSDictionary *effects=DREffectObservation();
  if(![effects[@"ready"] boolValue]||[effects[@"features"] count]!=15)throw std::runtime_error("Keine bestätigte tatsächliche Trainerinstanz für den Produktschaltertest.");
  if([action isEqual:@"equipment-setup"]){
   if(fixture.armed)throw std::runtime_error("Die eigene Ausrüstungsprüfung ist bereits vorbereitet.");
   if(productWanted(effects,7)||productWanted(effects,8))throw std::runtime_error("Netz- und Reusenschalter vor der Vorbereitung ausschalten.");
   Object manager=validateFixture(false),save=get(manager,"get_SaveData","SaveData"),items=objectField(manager,"_itemManager"),storage=get(save,"get_Storage","SerializableGrid");
   if(!items||!storage)throw std::runtime_error("Das ursprüngliche Lager fehlt.");
   auto definitions=references(objectField(items,"allItems"),4096);
   auto definition=[&](Object instance)->Object{Object cached=objectField(instance,"_itemData");if(cached)return cached;std::string id=text(objectField(instance,"id"));for(auto &entry:definitions)if(text(objectField(entry.get(),"id"))==id)return entry.get();return nullptr;};
   for(const char *name:{"get_Inventory","get_Storage","get_TrawlNet"})if(Object grid=get(save,name,"SerializableGrid"))for(const char *listName:{"spatialItems","spatialUnderlayItems"})for(auto &entry:references(objectField(grid,listName),4096)){
    Object data=definition(entry.get());if(data&&subtype(data,"DeployableItemData")){double kind=number(data,objectClass(data),"itemSubtype");if(kind==512||kind==256)throw std::runtime_error("Vorhandene Nutzer-Netze oder -Reusen: Produktschaltertest verweigert.");}
   }
   if(!references(objectField(save,"serializedCrabPotPOIs"),512).empty())throw std::runtime_error("Vorhandene ausgelegte Reusen: Produktschaltertest verweigert.");
   std::array<Object,2> chosen{};std::array<float,2> maxima{};
   for(auto &entry:definitions){Object data=entry.get();if(!subtype(data,"DeployableItemData"))continue;double kind=number(data,objectClass(data),"itemSubtype");int index=kind==512?0:kind==256?1:-1;if(index<0||chosen[index])continue;
    double maximum=unboxNumber(get(data,"get_MaxDurabilityDays","System.Single"),12);if(std::isfinite(maximum)&&maximum>0&&maximum<100000&&objectField(data,"id")){chosen[index]=data;maxima[index]=(float)maximum;}
   }
   if(!chosen[0]||!chosen[1])throw std::runtime_error("Originale Netz-/Reusendefinitionen fehlen.");
   fixture.ownerDomain=domain();fixture.domainId=api.domainID(domain());fixture.manager.reset(manager);fixture.save.reset(save);fixture.grid.reset(storage);fixture.items.reset(items);fixture.armed=true;
   try{for(size_t i=0;i<2;i++){
    validateFixture(true);uint8_t notify=1;Object id=objectField(chosen[i],"id");Object object=call(typedMethod(objectClass(items),"AddItemById","ItemInstance",{"System.String","SerializableGrid","System.Boolean"},false),items,{id,storage,&notify});
    if(!object)throw std::runtime_error("Kein freier Lagerplatz für beide echten Testgegenstände.");fixture.instance[i].reset(object);fixture.data[i].reset(chosen[i]);fixture.maximum[i]=maxima[i];
    if(!contains(storage,object)){fixture.instance[i].reset();fixture.data[i].reset();throw std::runtime_error("Kein freier Lagerplatz; Originalrückgabe wurde nicht als eingefügt gewertet.");}
    if(!subtype(object,"SpatialItemInstance")||text(objectField(object,"id"))!=text(id))throw std::runtime_error("Der Originalgegenstand wurde nicht eindeutig im Lager bestätigt.");
    Field durability=field(objectClass(object),"durability");fixture.baseline[i]=read(object,objectClass(object),durability);write(object,objectClass(object),durability,numeric(durability,maxima[i]*.25));
    if(std::abs(number(object,objectClass(object),"durability")-maxima[i]*.25)>.0001)throw std::runtime_error("Eigene reversible Haltbarkeitsabweichung nicht bestätigt.");
   }}catch(...){try{cleanupFixture();}catch(...){ }throw;}
   return @{@"prepared":@YES,@"note":@"Zwei eigene Originalgegenstände im Lager; Produktschalter 7 und 8 separat einschalten, danach equipment-check und ausgeschaltet equipment-reset."};
  }
  if(!fixture.armed)throw std::runtime_error("Keine eigene Ausrüstungsprüfung vorbereitet.");validateFixture(true);
  if([action isEqual:@"equipment-reset"]){if(productWanted(effects,7)||productWanted(effects,8))throw std::runtime_error("Produktschalter vor dem Entfernen ausschalten.");cleanupFixture();return @{@"removed":@YES,@"note":@"Eigene unbenutzte Lagergegenstände entfernt und Entfernung zurückgelesen."};}
  NSMutableArray *results=[NSMutableArray new];for(size_t i=0;i<2;i++){
   Object object=fixture.instance[i].get();bool present=stillOwn(i);double durability=present?number(object,objectClass(object),"durability"):-1;
   [results addObject:@{@"kind":i==0?@"net":@"pot",@"present":@(present),@"durability":@(durability),@"maximum":@(fixture.maximum[i]),@"repaired":@(present&&std::abs(durability-fixture.maximum[i])<.0001)}];
  }return @{@"items":results,@"effects":effects ?: @{}};
 }catch(const std::exception& e){return @{@"error":@(e.what()),@"prepared":@(fixture.armed)};}
}
}
static NSDictionary *readRequest(NSString *path){
 NSDictionary *a=[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL];
 if(![a[NSFileType] isEqual:NSFileTypeRegular] || [a[NSFileSize] unsignedLongLongValue]>4096)return nil;
 NSData *bytes=[NSData dataWithContentsOfFile:path];id object=bytes ? [NSJSONSerialization JSONObjectWithData:bytes options:0 error:NULL] : nil;
 return [object isKindOfClass:NSDictionary.class] ? object : nil;
}
__attribute__((constructor)) static void candidateChecks(void){@autoreleasepool{
 if(![NSProcessInfo.processInfo.environment[@"MHT_DREDGE_TEST"] isEqual:@"1"])return;
 NSDictionary *environment=NSProcessInfo.processInfo.environment;
 NSDictionary *configuration=MTLoadConfiguration(environment[@"MHT_CONFIG"],NULL);
 if(!MTCurrentProcessMatches(MTFindProfile(configuration,environment[@"MHT_PROFILE"]),environment[@"MHT_TARGET"]))return;
 NSString *token=NSProcessInfo.processInfo.environment[@"MHT_SESSION"];
 if(!token.length)return;
 dispatch_async(dispatch_get_main_queue(),^{
  NSString *root=@"/private/tmp/trainerdock-dredge";__block NSString *seen;
  NSTimer *timer=[NSTimer timerWithTimeInterval:.1 repeats:YES block:^(NSTimer *tick){
   (void)tick;NSDictionary *request=readRequest([root stringByAppendingPathComponent:@"Request.json"]);
   NSString *identifier=request[@"id"],*action=request[@"action"];
   BOOL equipment=[@[@"equipment-setup",@"equipment-check",@"equipment-reset"] containsObject:action];
   if(![identifier isKindOfClass:NSString.class] || ![[NSUUID alloc]initWithUUIDString:identifier] || [seen isEqual:identifier]
      || ![request[@"token"] isEqual:token] || [request[@"pid"] intValue]!=getpid() || (![action isEqual:@"observe"]&&!equipment))return;
   if([action isEqual:@"equipment-setup"]&&![request[@"ownEquipmentOnly"] isEqual:@YES])return;
   seen=identifier;
   void (^reply)(NSDictionary *)=^(NSDictionary *state){
    NSData *bytes=[NSJSONSerialization dataWithJSONObject:@{@"id":identifier,@"state":state} options:NSJSONWritingSortedKeys error:NULL];
    if(bytes)[bytes writeToFile:[root stringByAppendingPathComponent:@"CandidateReply.json"] options:NSDataWritingAtomic error:NULL];
   };
   if(!DREnqueueChecked(^{@autoreleasepool{
    if(equipment){reply(equipmentRequest(action));return;}
    NSDictionary *native=DRNativeObservation();NSDictionary *effects=DREffectObservation();
    reply(@{@"native":native ?: @{},@"effects":effects ?: @{}});
   }},^{reply(@{@"error":@"Originaldomain beendet; Testauftrag verworfen."});}))reply(@{@"error":@"Originalrückruf noch nicht bereit.",@"native":DRNativeObservation() ?: @{}});
  }];
  [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
 });
}}
#if defined(DREDGE_CANDIDATE_GUARD_TESTS)
int main(){@autoreleasepool{
 if(DRSupportedImage()||DRInFrame())return 1;
 for(NSString *action in @[@"equipment-setup",@"equipment-check",@"equipment-reset"]){NSDictionary *reply=equipmentRequest(action);if(!reply[@"error"]||fixture.armed)return 2;}
 puts("PASS: actual candidate equipment actions reject an unrelated process and missing real trainer before all Mono/item mutation. No game or original assembly loaded.");
}return 0;}
#endif
