// SPDX-License-Identifier: GPL-3.0-only
#import "Backend.hpp"
#import "GameEffects.hpp"
#import "GameBindings.h"
#import "Cursor.hpp"
#import "Speed.hpp"
#import "Manager.hpp"
#import "ContinuousFlags.hpp"
#import "CommunitySelection.hpp"
#import "Population.hpp"
#import "Operations.hpp"
#import "Trust.hpp"
#include <array>
#include <map>
#include <cmath>
#include <chrono>
namespace fp::backend {
namespace {
Context current;
std::map<std::string,Weak> assets;
double assetScan=-100;
bool pendingFlagRestore=false,pendingTrustRestore=false,pendingOperationRestore=false;
void retryPendingRestore(){
 // Failed restoration keeps its original lease; loading polls only retry that
 // restoration, never acquire or reapply an effect.
 if(pendingFlagRestore)pendingFlagRestore=!continuous::releaseOwnEffects();
 if(pendingTrustRestore)pendingTrustRestore=!trust::releaseOwnEffects();
 if(pendingOperationRestore)pendingOperationRestore=!operations::release();
}
Object asset(int i){
 if(i<0 || i>=15)throw std::runtime_error("Unbekannte Ressource für diesen Spielbuild.");
 std::string key=FPGameAssets[i].objectPath;auto cached=assets.find(key);if(cached!=assets.end()){Object o=cached->second.get();if(o)return o;assets.erase(cached);}
 double now=std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
 if(now-assetScan>2){assetScan=now;for(NSString *type in @[@"PXResource",@"PXStatistic"]){for(Object o:find(type,@"DA_",1024)){if(![className(o) isEqual:type])continue;NSString *n=name(o);uintptr_t outer=read<uintptr_t>(o.address+0x20);if(!outer)continue;NSString *package=name(Object{outer});for(const auto &spec:FPGameAssets){NSString *path=@(spec.objectPath);if([n isEqual:path.pathExtension] && [package isEqual:path.stringByDeletingPathExtension] && [type isEqual:@(spec.nativeClass)])assets[spec.objectPath]=Weak(o);}}}}
 auto found=assets.find(key);if(found==assets.end() || !found->second.get())throw std::runtime_error("Die ursprünglichen Ressourcen- oder Statistikdaten sind noch nicht geladen.");return found->second.get();
}
int assetIndex(MTFeature f){if(f<=MTFeatureScraps)return (int)f;if(f>=MTFeatureTension && f<=MTFeatureCrime)return 9+(int)f-(int)MTFeatureTension;return -1;}
effects::ScalarResult readFeature(MTFeature f){int i=assetIndex(f);Object a=asset(i);return i<9?effects::getStockpile(current.controller,current.city,a):effects::getStatistic(current.controller,current.city,a);}
}
Context context(){return current;}
void release(){if(!isGameThread())return;FPSetOverlayMouse(false,{});FPReleaseSpeed();pendingFlagRestore=!continuous::releaseOwnEffects();pendingOperationRestore=!operations::release();pendingTrustRestore=!trust::releaseOwnEffects();}
MTGameContext *capture(){MTGameContext *c=[MTGameContext new];if(!isGameThread()){c.note=@"Originaler GameThread nicht bestätigt.";return c;}Context next=captureContext();if(!next.ready || ![current.identity isEqual:next.identity]){release();assetScan=-100;}else retryPendingRestore();current=next;c.kind=next.ready?MTSessionSolo:MTSessionLoading;c.identity=next.ready?next.identity:@"loading";c.note=next.note;if(!next.ready && (pendingFlagRestore || pendingTrustRestore || pendingOperationRestore))c.note=[c.note stringByAppendingString:@" Eigene Wirkungsrücknahme wird erneut versucht."];return c;}
MTFeatureState *apply(MTFeature f,bool wanted,double value){MTFeatureState *s=[MTFeatureState new];s.wanted=wanted;s.value=value;const auto *info=MTFeatureInfoAt(f);s.note=info?info->detail:@"Unbekannte Funktion.";if(!info || !info->implemented || !isGameThread() || !current.ready)return s;
 try{if(f==MTFeatureRelations){auto v=trust::apply(current,wanted);s.available=v.available;s.active=v.active;s.note=v.note ?: info->detail;return s;}if(f==MTFeatureGeneratorWear || f==MTFeatureDemolish){auto v=f==MTFeatureGeneratorWear?operations::generatorWear(current,wanted):operations::demolish(current,wanted);s.available=v.available;s.active=wanted&&v.confirmed;s.note=v.note ?: info->detail;return s;}if(f==MTFeatureConstruction || f==MTFeatureExpansion || f==MTFeatureResearch || f==MTFeatureExpedition || f==MTFeatureLaws){auto v=continuous::apply(current,f,wanted);s.available=v.available;s.active=v.active;s.note=v.note ?: info->detail;return s;}if(f==MTFeaturePopulation || f==MTFeaturePopulationAll){s.available=f==MTFeaturePopulation?!!selectedCommunity(current):!listLocalCommunities(current).empty();s.note=s.available?info->detail:@"Keine aktive Gemeinschaft in der aktuellen Stadt.";return s;}if(f==MTFeatureCouncil){s.available=true;return s;}if(f==MTFeatureSpeed){auto v=FPApplySpeed(current,wanted,value);s.available=v.available;s.active=v.active;s.value=value;s.note=v.note ?: info->detail;return s;}if(assetIndex(f)>=0){
 // Edit actions display the requested value, not a live stockpile/statistic.
 // Resolve their exact bound asset for availability; invoking 15 native getters
 // here discarded every value. perform() retains fresh ownership/type checks,
 // the original setter and its authoritative readback on explicit application.
 s.available=!!asset(assetIndex(f));s.active=NO;return s;}}
 catch(const std::exception &e){s.note=@(e.what());return s;}
 s.note=@"Native Funktion noch nicht freigegeben.";return s;
}
NSString *perform(MTFeature f,double value){if(!isGameThread() || !current.ready || !std::isfinite(value))return @"Gültige lokale Stadt erforderlich.";const auto *info=MTFeatureInfoAt(f);if(!info || !info->implemented || !info->oneShot)return @"Aktion nicht freigegeben.";if(info->numeric && (value<info->minimum || value>info->maximum || (info->integer && std::floor(value)!=value)))return @"Ungültiger Wert.";try{
 if(f==MTFeatureCouncil){auto r=operations::council(current);return r.note ?: (r.confirmed?@"Ratspause nativ beendet.":@"Ratspause nicht bestätigt.");}
 if(f==MTFeaturePopulation || f==MTFeaturePopulationAll){std::vector<Object> chosen;if(f==MTFeaturePopulationAll)chosen=listLocalCommunities(current);else{Object selected=selectedCommunity(current);if(selected)chosen.push_back(selected);}if(chosen.empty())return @"Bitte zuerst im Spiel eine Gemeinschaft/Fraktion auswählen.";int changed=0;for(Object community:chosen){Object type=communityType(community);int before=[invoke(community,@"GetCommunitySize",@{}) intValue];int64_t delta=(int64_t)value-before;if(delta==0)continue;if(delta>100000 || delta< -100000)return [NSString stringWithFormat:@"%d Gemeinschaften geändert; nächster Unterschied überschreitet ±100.000.",changed];int32_t actual=0;if(!FPChangeCommunityPopulation(current.controller,current.city,type,(int32_t)delta,&actual))return [NSString stringWithFormat:@"%d Gemeinschaften geändert; letzte Änderung nur teilweise bestätigt (Delta %d). Kein automatischer Wiederholungsversuch.",changed,actual];changed++;}return [NSString stringWithFormat:@"%d von %lu Gemeinschaften nativ geändert; Ziel %.0f zurückgelesen.",changed,(unsigned long)chosen.size(),value];}
if(f>=MTFeatureTension && f<=MTFeatureCrime){auto manager=ensureCheatManager(current.controller);if(!manager.ready)return manager.reason ?: @"Native Managerinitialisierung nicht bestätigt.";auto r=effects::setStatisticAbsolute(current.controller,current.city,asset(assetIndex(f)),(int32_t)value,manager.manager);return r.writeReadbackConfirmed?[NSString stringWithFormat:@"Nativ gesetzt und zurückgelesen: %.0f",r.value]:r.reason ?: @"Änderung nicht bestätigt.";}if(f>=MTFeatureHeatstamps && f<=MTFeatureScraps){auto r=effects::setStockpileAbsolute(current.controller,current.city,asset((int)f),(int32_t)value);return r.writeReadbackConfirmed?[NSString stringWithFormat:@"Nativ gesetzt und zurückgelesen: %.0f",r.value]:r.reason ?: @"Änderung nicht bestätigt.";}}
 catch(const std::exception &e){return @(e.what());}return @"Native Aktion noch nicht freigegeben.";
}
bool mouse(bool wanted){if(!isGameThread())return false;return FPSetOverlayMouse(wanted&&current.ready,current.controller);}
NSDictionary *diagnostics(){if(!isGameThread())return @{};NSMutableDictionary *d=[@{@"ready":@(current.ready),@"note":current.note ?: @"",@"identity":current.identity ?: @""} mutableCopy];if(current.ready){for(auto pair:{std::pair{"controller",current.controller},std::pair{"world",current.world},std::pair{"city",current.city},std::pair{"nation",current.nation}})d[@(pair.first)]=@(read<int32_t>(pair.second.address+0xc));
 NSMutableArray *values=[NSMutableArray new];for(int i=0;i<15;i++){@try{try{auto r=readFeature((MTFeature)(i<9?i:MTFeatureTension+i-9));[values addObject:@{@"feature":@(i<9?i:MTFeatureTension+i-9),@"available":@(r.available),@"value":@(r.value),@"reason":r.reason ?: @""}];}catch(const std::exception &e){[values addObject:@{@"feature":@(i<9?i:MTFeatureTension+i-9),@"error":@(e.what())}];}}@catch(NSException *e){d[@"assetError"]=e.reason;}}d[@"values"]=values;
 try{NSMutableArray *communities=[NSMutableArray new];for(auto o:listLocalCommunities(current)){auto type=communityType(o);[communities addObject:@{@"index":@(read<int32_t>(o.address+0xc)),@"type":@(read<int32_t>(type.address+0xc)),@"name":name(o),@"size":invoke(o,@"GetCommunitySize",@{})}];}d[@"communities"]=communities;auto selected=selectedCommunity(current);d[@"selectedCommunity"]=selected?@(read<int32_t>(selected.address+0xc)):@(-1);}catch(const std::exception &e){d[@"communityError"]=@(e.what());}
 }return d;}
}
