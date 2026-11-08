// SPDX-License-Identifier: GPL-3.0-only
// Explicit test-only native diagnostics. Never included in a released module.
#import "LongDarkBackend.h"
#import "UnityLoop.h"
#include "IL2CPP.hpp"
#include "SaveGuard.hpp"
#include <dlfcn.h>
#include <cstring>
namespace {
NSTimer *timer;NSString *lastRequest;bool backgroundHeld=false,oldBackground=false;
tld::Class type(const char *name,const char *space=""){auto k=tld::klass("Assembly-CSharp.dll",space,name);if(!k)throw std::runtime_error("Test class missing");return k;}
tld::Object component(const char *name){return tld::call(tld::method(type("GameManager"),name,0),nullptr);}
NSDictionary *describe(tld::Class k){using namespace tld;
 NSMutableArray *fields=[NSMutableArray new],*methods=[NSMutableArray new];void *it=nullptr;
 while(Field f=api.fields(k,&it)){
  NSMutableDictionary *d=[@{@"name":@(api.fieldName(f)),@"type":@(typeName(api.fieldType(f)).c_str()),@"flags":@(api.fieldFlags(f)),@"offset":@(api.fieldOffset(f))} mutableCopy];
  if(api.fieldFlags(f)&0x10){auto c=api.typeClass(api.fieldType(f));if(!api.valueType(c)){Object o=nullptr;api.staticRead(f,&o);if(typeName(api.fieldType(f))=="System.String")d[@"string"]=@(text(o).c_str());}}
  [fields addObject:d];
 }
 it=nullptr;while(Method m=api.methods(k,&it)){
  NSMutableArray *args=[NSMutableArray new];for(uint32_t i=0;i<api.parameterCount(m);i++)[args addObject:@(typeName(api.parameterType(m,i)).c_str())];
  uintptr_t fn=0;memcpy(&fn,m,8);Dl_info info={};if(fn)dladdr((void *)fn,&info);uint32_t f=0;
  [methods addObject:@{@"name":@(api.methodName(m)),@"args":args,@"return":@(typeName(api.returnType(m)).c_str()),@"flags":@(api.methodFlags(m,&f)),@"rva":@(fn-(uintptr_t)info.dli_fbase)}];
 }
 return @{@"fields":fields,@"methods":methods};
}
NSDictionary *snapshot(NSDictionary *request){using namespace tld;
 if(!TLDInFrame())throw std::runtime_error("Not in original frame");
 NSString *action=request[@"op"] ?: @"values";
 if([action isEqual:@"describe"])return describe(type([request[@"class"] UTF8String],[request[@"namespace"] UTF8String] ?: ""));
 if([action isEqual:@"finish"] && backgroundHeld){auto app=klass("UnityEngine.CoreModule.dll","UnityEngine","Application");numericCall(method(app,"set_runInBackground",1),nullptr,{oldBackground?1.0:0.0});backgroundHeld=false;}
 if([action isEqual:@"deleteFixture"]){
  NSString *label=[@"trainerdock-fixture-" stringByAppendingString:NSUUID.UUID.UUIDString];Root name(api.stringNew(label.UTF8String));
  std::string path=text(call(method(type("SaveGameDataPC"),"GetFullPath",1),nullptr,{name.get()}));
  NSString *file=@(path.c_str());if([NSFileManager.defaultManager fileExistsAtPath:file])throw std::runtime_error("Fixture already exists");
  if(![[NSData dataWithBytes:"fixture" length:7] writeToFile:file atomically:NO])throw std::runtime_error("Cannot create disposable test fixture");
  float hp=100;int mode=1;uint64_t before=TLDBlockedSaveDeletes();bool retained=false,removed=false;
  @try {try{
   TLDProtectSaves({path},(uintptr_t)&hp,(uintptr_t)&mode);
   call(method(type("SaveGameDataPC"),"DeleteData",1),nullptr,{name.get()});
   retained=[NSFileManager.defaultManager fileExistsAtPath:file] && TLDBlockedSaveDeletes()>before;
   TLDClearSaveGuard();call(method(type("SaveGameDataPC"),"DeleteData",1),nullptr,{name.get()});
   removed=![NSFileManager.defaultManager fileExistsAtPath:file];
  }catch(...){TLDClearSaveGuard();[NSFileManager.defaultManager removeItemAtPath:file error:nil];throw;}}
  @finally{TLDClearSaveGuard();[NSFileManager.defaultManager removeItemAtPath:file error:nil];}
  return @{@"retainedThroughOriginalDelete":@(retained),@"deletedWhenOff":@(removed)};
 }
 if([action isEqual:@"food"]){
  Object hunger=component("GetHungerComponent");double cap=getNumber(hunger,"GetAdjustedMaxReserveCalories");float reserve=(float)(cap-200);api.fieldWrite(hunger,field(api.objectClass(hunger),"m_CurrentReserveCalories"),&reserve);
  for(Object o:findObjects(type("GearItem"),true)){if(!boolean(o,"m_InPlayerInventory") || !reference(o,"m_FoodItem"))continue;
   Object p=component("GetPlayerManagerComponent");call(method(api.objectClass(p),"UseFoodInventoryItem",1),p,{o});return @{@"started":@YES};
  }
  throw std::runtime_error("No original owned food");
 }
 if([action isEqual:@"weaponHit"]){
  Object gun=nullptr;for(Object o:findObjects(type("GearItem"),true))if(boolean(o,"m_InPlayerInventory") && reference(o,"m_GunItem")){gun=reference(o,"m_GunItem");break;}
  if(!gun)throw std::runtime_error("No owned firearm");float damage=0;api.fieldRead(gun,field(api.objectClass(gun),"m_DamageHP"),&damage);
  if(damage<100000)throw std::runtime_error("One-hit effect must be natively active first");
  for(Object ai:findObjects(type("BaseAi"))){float hp=0;api.fieldRead(ai,field(api.objectClass(ai),"m_CurrentHP"),&hp);if(hp<=100)continue;
   Method m=method(api.objectClass(ai),"ApplyDamage",3);Root amount(boxNumber(api.parameterType(m,0),damage)),source(boxNumber(api.parameterType(m,1),1)),collider(api.stringNew("body"));
   call(m,ai,{amount.get(),source.get(),collider.get()});float after=0;api.fieldRead(ai,field(api.objectClass(ai),"m_CurrentHP"),&after);
   return @{@"name":@(text(call(method(api.objectClass(ai),"get_name",0),ai)).c_str()),@"before":@(hp),@"weaponDamage":@(damage),@"after":@(after)};
  }throw std::runtime_error("No original living animal above normal weapon damage");
 }
 if([action isEqual:@"animals"]){NSMutableArray *animals=[NSMutableArray new];
  for(Object ai:findObjects(type("BaseAi"))){float hp=0;api.fieldRead(ai,field(api.objectClass(ai),"m_CurrentHP"),&hp);
   Root transform(call(method(api.objectClass(ai),"get_transform",0),ai)),position(call(method(api.objectClass(transform.get()),"get_position",0),transform.get()));
   float xyz[3]={};uint32_t alignment=0;if(api.valueSize(api.objectClass(position.get()),&alignment)!=12)throw std::runtime_error("Original position layout differs");memcpy(xyz,api.unbox(position.get()),12);
   [animals addObject:@{@"name":@(text(call(method(api.objectClass(ai),"get_name",0),ai)).c_str()),@"hp":@(hp),@"position":@[@(xyz[0]),@(xyz[1]),@(xyz[2])]}];
  }return @{@"animals":animals};
 }
 if([action isEqual:@"craftMenu"]){call(method(type("InputManager"),"ExecuteCraftingAction",0),nullptr);return @{@"requested":@YES};}
 if([action isEqual:@"craft"]){auto panels=findObjects(type("Panel_Crafting"));for(Object p:panels)if(getNumber(p,"CanCraftSelectedBlueprint")){call(method(api.objectClass(p),"OnBeginCrafting",0),p);return @{@"started":@YES};}throw std::runtime_error("No craftable selection");}
 if([action isEqual:@"damage"]){double amount=[request[@"amount"] doubleValue];if(amount<0 || amount>20)throw std::runtime_error("Bounded reversible HP test only");Object c=component("GetConditionComponent");double before=getNumber(c,"GetNormalizedCondition");numericCall(method(api.objectClass(c),"AddHealth",3),c,{-amount,0,0});return @{@"before":@(before),@"after":@(getNumber(c,"GetNormalizedCondition"))};}
 if([action isEqual:@"heal"]){auto c=component("GetConditionComponent");numericCall(method(api.objectClass(c),"AddHealth",3),c,{20,0,0});}
 if([action isEqual:@"consume"]){auto inv=component("GetInventoryComponent");auto gear=findObjects(type("GearItem"),true);for(Object o:gear){if(!boolean(o,"m_InPlayerInventory") || !reference(o,"m_StackableItem") || reference(o,"m_AmmoItem"))continue;
  auto stack=reference(o,"m_StackableItem");if(getNumber(stack,"get_IsAStackOfItems")==0)continue;
  auto gameObject=call(method(api.objectClass(o),"get_gameObject",0),o);
  call(method(api.objectClass(component("GetPlayerManagerComponent")),"ConsumeUnitFromInventory",1),component("GetPlayerManagerComponent"),{gameObject});(void)inv;return @{@"consumed":@YES};}
  throw std::runtime_error("No disposable stack");}
 NSMutableDictionary *d=[TLDValues() mutableCopy];
 NSMutableArray *gear=[NSMutableArray new];for(Object o:findObjects(type("GearItem"),true)){if(!boolean(o,"m_InPlayerInventory"))continue;
  NSMutableDictionary *g=[@{@"name":@(text(call(method(api.objectClass(o),"get_name",0),o)).c_str())} mutableCopy];
  if(Object gun=reference(o,"m_GunItem")){g[@"rounds"]=@(getNumber(gun,"NumRoundsInClip"));g[@"timeSinceFire"]=@(getNumber(gun,"get_TimeSinceLastFire"));Field f=field(api.objectClass(gun),"m_DamageHP");float hp=0;api.fieldRead(gun,f,&hp);g[@"damage"]=@(hp);}
  if(Object stack=reference(o,"m_StackableItem")){int n=0;api.fieldRead(stack,field(api.objectClass(stack),"m_Units"),&n);g[@"units"]=@(n);}
  [gear addObject:g];
 }
 d[@"gear"]=gear;
 auto panels=findObjects(type("Panel_Crafting"));NSMutableArray *craft=[NSMutableArray new];
 for(Object p:panels){Object operation=reference(p,"m_CraftingOperation");if(operation)[craft addObject:@{@"inProgress":@(getNumber(operation,"get_InProgress")),@"lastCrafted":@(reference(operation,"m_LastCraftedItem")!=nullptr),@"canCraft":@(getNumber(p,"CanCraftSelectedBlueprint"))}];}d[@"crafting"]=craft;
 auto save=type("SaveGameSystem");d[@"saveName"]=@(text(call(method(save,"GetCurrentSaveName",0),nullptr)).c_str());
 NSMutableArray *slots=[NSMutableArray new];Object listObject=nullptr;api.staticRead(field(type("SaveGameSlots"),"m_SaveSlots"),&listObject);
 for(Object slot:list(listObject,64)){
  Object name=reference(slot,"m_InternalName");std::string n=text(name);if(n!=[d[@"saveName"] UTF8String])continue;
  std::string full=text(call(method(type("SaveGameDataPC"),"GetFullPath",1),nullptr,{name}));
  NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:@(full.c_str()) error:nil];
  [slots addObject:@{@"name":@(n.c_str()),@"path":@(full.c_str()),@"modified":@([attributes[NSFileModificationDate] timeIntervalSince1970]),@"size":attributes[NSFileSize] ?: @0}];
 }d[@"saveFiles"]=slots;
 d[@"saveRunning"]= @(number(call(method(save,"IsAsyncSaveRunning",0),nullptr)));
 d[@"saveBusy"]=@(number(call(method(type("SaveGameData"),"IsSaving",0),nullptr)));
 return d;
}
void perform(NSDictionary *request){
 id a=request[@"action"];NSDictionary *action=[a isKindOfClass:NSString.class]?@{@"op":a}:a;
 NSMutableDictionary *response=[@{@"id":request[@"id"] ?: @""} mutableCopy];
 @try{try{response[@"result"]=snapshot(action);}catch(const std::exception& e){response[@"error"]=@(e.what());}}
 @catch(NSException *e){response[@"error"]=e.reason ?: @"Objective-C test error";}
 NSError *error=nil;NSData *data=[NSJSONSerialization dataWithJSONObject:response options:NSJSONWritingPrettyPrinted error:&error];
 if(!data)data=[NSJSONSerialization dataWithJSONObject:@{@"id":request[@"id"],@"error":error.localizedDescription ?: @"Invalid JSON result"} options:0 error:nil];
 [data writeToFile:@"/private/tmp/trainerdock-the-long-dark/CandidateReply.json" atomically:YES];
}
}
__attribute__((constructor)) static void beginCandidateChecks(){dispatch_async(dispatch_get_main_queue(),^{
 if(strcmp(getenv("MHT_TLD_DEVELOPMENT") ?: "","1"))return;
 NSString *token=getenv("MHT_SESSION") ? @(getenv("MHT_SESSION")):nil;if(!token.length)return;
 timer=[NSTimer scheduledTimerWithTimeInterval:.25 repeats:YES block:^(NSTimer *t){(void)t;
  NSDictionary *r=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@"/private/tmp/trainerdock-the-long-dark/Request.json"] ?: [NSData data] options:0 error:nil];
  if(![r isKindOfClass:NSDictionary.class] || ![r[@"token"] isEqual:token] || ![r[@"id"] isKindOfClass:NSString.class] || [r[@"id"] isEqual:lastRequest])return;
  lastRequest=r[@"id"];TLDEnqueue(^{perform(r);});
 }];
 TLDEnqueue(^{using namespace tld;auto app=klass("UnityEngine.CoreModule.dll","UnityEngine","Application");oldBackground=number(call(method(app,"get_runInBackground",0),nullptr))!=0;numericCall(method(app,"set_runInBackground",1),nullptr,{1});backgroundHeld=true;});
});}
