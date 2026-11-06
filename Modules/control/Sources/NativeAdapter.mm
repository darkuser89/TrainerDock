// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "ControlEngine.h"
#import "ControlInput.h"
#import "ControlInventory.h"
#import "ControlShield.h"
#import "ControlCombat.h"
#import "ControlMovement.h"
#include <dlfcn.h>
#include <map>
#include <string>
#include <vector>
#include <cmath>
template<class T>static T read(uintptr_t p){T value{};MHTControlRead(p,&value,sizeof(value));return value;}
static void notifyPin(uintptr_t address,BOOL boolean){uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r21FlowConnectionManager12sm_pInstanceE"),flow=read<uintptr_t>(global);if(flow)((void(*)(void*,void*))(MHTControlAddress(boolean?MHTControlNotifyBool:MHTControlNotifyFloat)))((void*)flow,(void*)address);}
struct OwnedValue {uintptr_t address;std::vector<uint8_t> baseline,last;};
@interface MHTNativeAdapter () {
 uintptr_t _session,_avatar,_health,_resource,_inventory,_player,_assist,_movement;
 uint64_t _ownerID,_lastMoney;
 BOOL _hadMoney,_healthOwned,_multiplierConfirmed;
 double _moneyFraction;
 BOOL _wanted[MTFeatureCount],_active[MTFeatureCount];
 double _values[MTFeatureCount];
 std::map<std::string,OwnedValue> _owned;
 std::unique_ptr<MHTControlInventory> _items;
 std::unique_ptr<MHTControlShield> _shields;
 std::unique_ptr<MHTControlCombat> _combat;
 std::unique_ptr<MHTControlMovement> _speed;
 MHTControlInventoryResult _itemState;
 MHTControlShieldResult _shieldState;
 MHTControlCombatResult _combatState;
}
@end
@implementation MHTNativeAdapter
- (instancetype)init{if((self=[super init])){_items=std::make_unique<MHTControlInventory>();_shields=std::make_unique<MHTControlShield>();_combat=std::make_unique<MHTControlCombat>();_speed=std::make_unique<MHTControlMovement>();for(NSInteger i=0;i<MTFeatureCount;i++)_values[i]=MTFeatureInfoAt((MTFeature)i)->initial;__weak MHTNativeAdapter *weak=self;MHTControlSetMaintenance(^{MHTNativeAdapter *adapter=weak;if(adapter)[adapter maintain];});}return self;}
- (void)onGameThread:(dispatch_block_t)work{MHTControlSchedule(work);}
- (void)restore:(const std::string&)key {
 auto it=_owned.find(key);if(it==_owned.end())return;auto &p=it->second;
 std::vector<uint8_t> current(p.last.size());
 if(MHTControlRead(p.address,current.data(),current.size())&&current==p.last){MHTControlWrite(p.address,p.baseline.data(),p.baseline.size());if(key!="energy-flag")notifyPin(p.address,key=="ammo");}_owned.erase(it);
}
- (BOOL)patch:(const std::string&)key address:(uintptr_t)p bytes:(const void*)value size:(size_t)n {
 if(!p||!n||n>16)return NO;auto it=_owned.find(key);
 if(it==_owned.end()){OwnedValue initial{p,std::vector<uint8_t>(n),std::vector<uint8_t>(n)};if(!MHTControlRead(p,initial.baseline.data(),n))return NO;_owned.emplace(key,std::move(initial));it=_owned.find(key);}
 auto &owned=it->second;if(owned.address!=p||owned.last.size()!=n||!MHTControlWrite(p,value,n))return NO;memcpy(owned.last.data(),value,n);std::vector<uint8_t> actual(n);return MHTControlRead(p,actual.data(),n)&&memcmp(actual.data(),value,n)==0;
}
- (BOOL)patchPin:(const std::string&)key address:(uintptr_t)p bytes:(const void*)value size:(size_t)n {
 std::vector<uint8_t> before(n);if(!MHTControlRead(p,before.data(),n))return NO;BOOL ok=[self patch:key address:p bytes:value size:n];if(ok&&memcmp(before.data(),value,n)!=0)notifyPin(p,key=="ammo");return ok;
}
- (void)discardOwner {
 // Resolve the old GlobalID before touching its components. An old address may
 // already belong to a new entity after loading.
 uintptr_t global=(uintptr_t)dlsym(RTLD_DEFAULT,"_ZN1r11GlobalIDMap12sm_pInstanceE"),map=read<uintptr_t>(global);
 auto resolve=(void*(*)(void*,const uint64_t*))dlsym(RTLD_DEFAULT,"_ZNK1r11GlobalIDMap10getPointerERKNS_8GlobalIDE");
 BOOL live=_ownerID&&map&&resolve&&(uintptr_t)resolve((void*)map,&_ownerID)==_avatar;
 if(live){
  uintptr_t list=read<uintptr_t>(_avatar+0x60);uint32_t count=read<uint32_t>(_avatar+0x68);std::map<uintptr_t,uintptr_t> components;
  if(count<=128)for(uint32_t i=0;i<count;i++){uintptr_t c=read<uintptr_t>(list+8*i);if(read<uintptr_t>(c+0x20)==_avatar)components[c]=read<uintptr_t>(c);}
  
  if(_healthOwned&&components[_health]==MHTControlAddress(MHTControlHealthVT)){((void(*)(void*,bool,uint32_t))(MHTControlAddress(MHTControlHealthInvulnerable)))((void*)_health,false,0x40000000);}
  for(auto it=_owned.begin();it!=_owned.end();){std::string key=it->first;++it;uintptr_t c=key=="ammo"?_inventory:_resource,vt=key=="ammo"?MHTControlAddress(MHTControlInventoryVT):MHTControlAddress(MHTControlResourceVT);if(components[c]==vt)[self restore:key];}
  _items->release();
 }else _items->discardOwner();
 _shields->reset();_combat->reset();_speed->release();_itemState={};_shieldState={};_combatState={};
 MHTControlSetSimulationRate(1);_owned.clear();_healthOwned=NO;_hadMoney=NO;_multiplierConfirmed=NO;_moneyFraction=0;memset(_active,0,sizeof(_active));memset(_wanted,0,sizeof(_wanted));
}
- (BOOL)refresh {
 if(!MHTControlOnEngineFrame()||!MHTControlEngineIdentity())return NO;
 void *server=MHTControlServer();if(!server)return NO;
 uintptr_t session=((uintptr_t(*)(void*))(MHTControlAddress(MHTControlSession)))(server);
 uintptr_t avatar=session?((uintptr_t(*)(void*))(MHTControlAddress(MHTControlAvatar)))((void*)session):0;
 uint64_t owner=read<uint64_t>(avatar+0x10);
 uintptr_t health=0,resource=0,inventory=0,player=0,assist=0,movement=0;
 uintptr_t list=read<uintptr_t>(avatar+0x60);uint32_t count=read<uint32_t>(avatar+0x68);
 if(avatar&&count<=128)for(uint32_t i=0;i<count;i++){
  uintptr_t c=read<uintptr_t>(list+8*i);if(read<uintptr_t>(c+0x20)!=avatar)continue;uintptr_t vt=read<uintptr_t>(c);
  if(vt==MHTControlAddress(MHTControlHealthVT))health=c;else if(vt==MHTControlAddress(MHTControlResourceVT))resource=c;else if(vt==MHTControlAddress(MHTControlInventoryVT))inventory=c;else if(vt==MHTControlAddress(MHTControlPlayerVT))player=c;else if(vt==MHTControlAddress(MHTControlAssistVT))assist=c;else if(vt==MHTControlAddress(MHTControlMovementVT))movement=c;
 }
 if(session!=_session||avatar!=_avatar||owner!=_ownerID||health!=_health||resource!=_resource||inventory!=_inventory||player!=_player||assist!=_assist||movement!=_movement)[self discardOwner];
 _session=session;_avatar=avatar;_ownerID=owner;_health=health;_resource=resource;_inventory=inventory;_player=player;_assist=assist;_movement=movement;
 uintptr_t nativeHealth=read<uintptr_t>(health+0x50);float normalized=read<float>(nativeHealth+0x94),energy=read<float>(resource+0x38),ammo=read<float>(inventory+0x2b8);int maxHealth=read<int>(nativeHealth+0xb8);
 return avatar&&health&&inventory&&player&&resource&&assist&&movement&&nativeHealth>0x10000
  &&std::isfinite(normalized)&&normalized>=0&&normalized<=1&&maxHealth>0&&maxHealth<=100000000
  &&read<uint8_t>(nativeHealth+0xbc)<=1&&std::isfinite(energy)&&energy>=0&&energy<=1&&std::isfinite(ammo)&&ammo>=0&&ammo<=10000000;
}
- (MTGameContext *)captureContext {
 MTGameContext *context=[MTGameContext new];BOOL ready=[self refresh];
 context.kind=!MHTControlEngineIdentity()?MTSessionUnsupported:ready?MTSessionSolo:MTSessionLoading;
 context.identity=[NSString stringWithFormat:@"%llx:%llx:%llx:%llx:%llx",(unsigned long long)_session,(unsigned long long)_avatar,(unsigned long long)_ownerID,(unsigned long long)_inventory,(unsigned long long)_player];
 context.note=ready?[MHTControlBuildLabel() stringByAppendingString:@" · lokale native Anbindung"]:context.kind==MTSessionUnsupported?@"Dieser Control-/Engine-Build ist nicht unterstützt.":@"Warte auf einen geladenen lokalen Spieler.";return context;
}
- (void)releaseEffects {
 if(!MHTControlOnEngineFrame())return;
 _items->release();_shields->reset();_combat->reset();_speed->release();_itemState={};_shieldState={};_combatState={};
 MHTControlSetSimulationRate(1);
 if(_healthOwned&&_health&&read<uintptr_t>(_health+0x50)>0x10000){((void(*)(void*,bool,uint32_t))(MHTControlAddress(MHTControlHealthInvulnerable)))((void*)_health,false,0x40000000);_healthOwned=NO;}
 while(!_owned.empty())[self restore:_owned.begin()->first];memset(_active,0,sizeof(_active));memset(_wanted,0,sizeof(_wanted));_hadMoney=NO;_multiplierConfirmed=NO;_moneyFraction=0;
}
- (void)maintain {
 if(![self refresh]){MHTControlSetSimulationRate(1);return;}
 _itemState=_items->update(_avatar,_inventory,_wanted[MTFeatureMaterials],_wanted[MTFeatureCrafting]);
 _active[MTFeatureMaterials]=_itemState.materialsActive;_active[MTFeatureCrafting]=_itemState.craftActive;
 _shieldState=_shields->update(_avatar,_wanted[MTFeatureShield]);_active[MTFeatureShield]=_shieldState.confirmed;
 // This reason bit is added only if it was absent, and removed only when owned.
 if(_wanted[MTFeatureHealth]){BOOL ownedBit=(read<uint32_t>(_health+0x5c)&0x40000000)!=0;if(!ownedBit||!read<uint8_t>(read<uintptr_t>(_health+0x50)+0xbc)){((void(*)(void*,bool,uint32_t))(MHTControlAddress(MHTControlHealthInvulnerable)))((void*)_health,true,0x40000000);if(!ownedBit)_healthOwned=YES;}_active[MTFeatureHealth]=read<uint8_t>(read<uintptr_t>(_health+0x50)+0xbc)==1;}
 else {if(_healthOwned){((void(*)(void*,bool,uint32_t))(MHTControlAddress(MHTControlHealthInvulnerable)))((void*)_health,false,0x40000000);_healthOwned=NO;}_active[MTFeatureHealth]=NO;}
 float energy=1;uint8_t enabled=1;
 if(_wanted[MTFeatureEnergy]){BOOL flag=[self patch:"energy-flag" address:_resource+0x139 bytes:&enabled size:1];_active[MTFeatureEnergy]=flag&&[self patchPin:"energy" address:_resource+0x38 bytes:&energy size:4];}else{[self restore:"energy-flag"];[self restore:"energy"];_active[MTFeatureEnergy]=NO;}
 if(_wanted[MTFeatureAmmo])_active[MTFeatureAmmo]=[self patchPin:"ammo" address:_inventory+0x2ac bytes:&enabled size:1];else{[self restore:"ammo"];_active[MTFeatureAmmo]=NO;}
 _combatState=_combat->update(_avatar,_wanted[MTFeatureOneHit]);_active[MTFeatureOneHit]=_combatState.confirmed;
 _active[MTFeatureSpeed]=_speed->update(_avatar,_movement,_wanted[MTFeatureSpeed],_values[MTFeatureSpeed]);
 float rate=_wanted[MTFeatureSlow]?(float)_values[MTFeatureSlow]:1.f;MHTControlSetSimulationRate(rate);_active[MTFeatureSlow]=_wanted[MTFeatureSlow]&&MHTControlSimulationRate()==rate;
 uint64_t money=read<uint64_t>(_player+0x38);_active[MTFeatureMoneyMultiplier]=NO;
 if(_wanted[MTFeatureMoneyMultiplier]&&_hadMoney&&money>_lastMoney&&money<999999999){uint64_t gain=money-_lastMoney;double bonus=(double)gain*(_values[MTFeatureMoneyMultiplier]-1)+_moneyFraction;uint64_t extra=(uint64_t)floor(bonus);_moneyFraction=bonus-(double)extra;if(extra>999999999-money)extra=999999999-money;uint64_t target=money+extra;if(MHTControlWrite(_player+0x38,&target,8)&&read<uint64_t>(_player+0x38)==target){money=target;if(extra)_multiplierConfirmed=YES;}}
 _lastMoney=money;_hadMoney=YES;
 if(_wanted[MTFeatureMoneyMultiplier])_active[MTFeatureMoneyMultiplier]=_multiplierConfirmed&&read<uint64_t>(_player+0x38)==money;
 else {_multiplierConfirmed=NO;_moneyFraction=0;}
}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
 MTFeatureState *state=[MTFeatureState new];const MTFeatureInfo *info=MTFeatureInfoAt(feature);if(!info)return state;
 state.value=value;state.wanted=wanted;
 if(!MHTControlOnEngineFrame()||!_avatar||!info->implemented){state.note=info->detail;return state;}
 if(info->numeric&&(!std::isfinite(value)||value<info->minimum||value>info->maximum))return state;
 state.available=YES;
 if(feature==MTFeatureMaterials)state.available=_itemState.materialCount>0;
 if(!info->oneShot){if(feature==MTFeatureMoneyMultiplier&&(_values[feature]!=value||!wanted)){_multiplierConfirmed=NO;_moneyFraction=0;}_wanted[feature]=wanted&&state.available;_values[feature]=value;[self maintain];state.active=_wanted[feature]&&_active[feature];}
 state.note=state.active?@"Native Wirkung zurückgelesen.":feature==MTFeatureMoneyMultiplier&&wanted?@"Wartet auf neue Quellenenergie.":feature==MTFeatureMaterials&&!state.available?@"Noch kein eigenes Herstellungsmaterial im Inventar.":feature==MTFeatureShield&&wanted?@"Wartet auf einen Treffer gegen einen feindlichen Schild.":feature==MTFeatureOneHit&&wanted?@"Wartet auf bestätigten Gesundheitsschaden an einem feindlichen Gegner.":info->detail;return state;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {
 if(!MHTControlOnEngineFrame()||![self refresh]||!std::isfinite(value)||floor(value)!=value)return @"Kein gültiger lokaler Spieler.";
 if(feature==MTFeatureMoney&&value>=0&&value<=999999999){uint64_t amount=(uint64_t)value;if(MHTControlWrite(_player+0x38,&amount,8)&&read<uint64_t>(_player+0x38)==amount){_lastMoney=amount;_hadMoney=YES;return @"Quellenenergie gesetzt und zurückgelesen.";}}
 if(feature==MTFeatureSkillPoints&&value>=0&&value<=9999){int amount=(int)value;if(MHTControlWrite(_player+0x40,&amount,4)&&read<int>(_player+0x40)==amount)return @"Fähigkeitspunkte gesetzt und zurückgelesen.";}
 return @"Die Aktion wurde nicht bestätigt.";
}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return MHTControlOverlayInteraction(wanted);}
@end
