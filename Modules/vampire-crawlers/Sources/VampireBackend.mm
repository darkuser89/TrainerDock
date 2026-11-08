// SPDX-License-Identifier: GPL-3.0-only
#import "VampireBackend.h"
#import "UnityLoop.h"
#import "TrainerFeatures.h"
#include "IL2CPP.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <limits>
#include <sstream>
#include <iomanip>
namespace {
using vc::Object;using vc::Root;
struct BooleanLease {Root object;std::string stamp;bool baseline=false;};
struct EnemyLease {Root object;std::string stamp;double health=0,armor=0;bool guardian=false;};
struct Context {Object player=nullptr,stats=nullptr,progression=nullptr;std::string profile,scene,identity;int kind=1;};
struct MouseLease {Root manager,eventSystem;std::vector<std::pair<Root,bool>> maps;bool held=false,visible=false,eventEnabled=false;int lock=0;};
struct Backend {
    Context context;Root cachedPlayer,cachedProgression;std::string previousIdentity;
    std::array<bool,4> wanted{},active{};std::array<double,4> values{0,0,0,2};
    BooleanLease god;std::vector<BooleanLease> cards;std::vector<EnemyLease> enemies;
    MouseLease mouse;double xpBaseline=0;bool xpKnown=false;unsigned frames=0;
    std::string encounterIdentity;
    NSString *failure=nil;NSTimer *retry;
};
// Engine-owned references are released in frame callbacks, never from a static
// destructor after Unity has shut down.
Backend& backend(){static Backend *instance=new Backend;return *instance;}
const char *statNames[]={"Health","Armor","Might","Amount","Area","Growth","Greed","Luck","Recovery","Mana","DealCount","Magnet","Duration","RevivalCharge","RevivalStacks","CardSkips","Rerolls","Banishes","Curse","Charm"};
vc::Class gameClass(const char *space,const char *name){return vc::klass("Pancake.dll",space,name);}
bool sameType(Object object,vc::Class wanted){
    for(vc::Class type=object ? vc::api.objectClass(object) : nullptr;type;type=vc::api.parent(type))if(type==wanted)return true;
    return false;
}
Object singleton(const char *space,const char *name,bool asset=false){
    vc::Class type=gameClass(space,name);if(!type)return nullptr;
    for(vc::Class base=type;base;base=vc::api.parent(base)){
        vc::Field f=vc::api.findField(base,"_instance");
        if(f && (vc::api.fieldFlags(f)&0x10)){
            Object object=nullptr;vc::api.staticRead(f,&object);
            if(object && sameType(object,type) && vc::alive(object))return object;
        }
    }
    auto objects=vc::findObjects(type,asset);
    return objects.size()==1 ? objects.front() : nullptr;
}
std::string stamp(Object object){
    if(!object)return "";
    vc::Method getter=vc::method(vc::api.objectClass(object),"get_Guid",0);
    if(!getter){std::ostringstream s;s<<object;return s.str();}
    Root boxed(vc::call(getter,object));if(!boxed.get())return "";
    std::string string=vc::text(boxed.get());if(!string.empty())return string;
    vc::Class type=vc::api.objectClass(boxed.get());uint32_t align=0;
    if(!vc::api.valueType(type))return "";
    int size=vc::api.valueSize(type,&align);if(size<1 || size>64)return "";
    const uint8_t *bytes=(const uint8_t *)vc::api.unbox(boxed.get());static const char hex[]="0123456789abcdef";
    std::string result;for(int i=0;i<size;i++){result+=hex[bytes[i]>>4];result+=hex[bytes[i]&15];}return result;
}
std::string sceneName(Object manager){
    vc::Method getter=manager ? vc::method(vc::api.objectClass(manager),"get_CurrentState",0) : nullptr;
    if(!getter)return "";Root state(vc::call(getter,manager));double current=vc::number(state.get());
    vc::Class type=vc::api.typeClass(vc::api.returnType(getter));void *iterator=nullptr;
    while(vc::Field f=vc::api.fields(type,&iterator))if(vc::api.fieldFlags(f)&0x40){
        uint64_t number=0;vc::api.staticRead(f,&number);if((double)number==current)return vc::api.fieldName(f);
    }
    return "";
}
bool enabled(Object object){
    if(!vc::alive(object))return false;vc::Method getter=vc::method(vc::api.objectClass(object),"get_isActiveAndEnabled",0);
    return !getter || vc::number(vc::call(getter,object))!=0;
}
Context capture(){
    Backend& b=backend();Context result;
    if(!VCInFrame())return result;
    Object save=singleton("Nosebleed.SaveLoadSystem.Pancake","SaveLoadManager");
    if(save)result.profile=vc::text(vc::call(vc::method(vc::api.objectClass(save),"get_CurrentProfileId",0),save));
    result.scene=sceneName(singleton("Nosebleed.Pancake","GameStateManager"));
    bool inRun=result.scene=="Game" || result.scene=="Tutorial";
    bool town=result.scene=="MainMenu" || result.scene=="CharacterSelect";
    Object progression=b.cachedProgression.get();
    if(!progression || !vc::alive(progression)){progression=singleton("Nosebleed.Pancake.MetaProgression","ProgressionData",true);b.cachedProgression.reset(progression,true);}
    result.progression=progression;
    if(inRun){
        Object player=b.cachedPlayer.get();
        if(!enabled(player) || b.frames%15==0){
            auto players=vc::findObjects(gameClass("Nosebleed.Pancake.Models","PlayerModel"));
            players.erase(std::remove_if(players.begin(),players.end(),[](Object p){return !enabled(p);}),players.end());
            if(players.size()>1){result.kind=0;result.identity="multiple-player-models";return result;}
            player=players.size()==1 ? players.front() : nullptr;b.cachedPlayer.reset(player,true);
        }
        if(enabled(player)){
            result.player=player;
            vc::Method getter=vc::method(vc::api.objectClass(player),"get_PlayerStats",0);
            if(getter)result.stats=vc::call(getter,player);
            if(result.stats && !sameType(result.stats,gameClass("Nosebleed.Pancake.GameLogic","PlayerStats")))result.stats=nullptr;
        }
    }
    std::ostringstream identity;identity<<std::setprecision(17)<<result.profile<<'/'<<result.scene<<'/'<<progression<<'/'<<result.player<<'/'<<result.stats<<'/'<<stamp(result.player);
    if(result.player){
        Object seed=vc::reference(result.player,"_runSeed");if(seed)identity<<'/'<<vc::getNumber(seed,"get_Seed");
    }
    result.identity=identity.str();
    if(!result.profile.empty() && progression && ((inRun && result.player && result.stats) || town))result.kind=2;
    return result;
}
Object stat(NSInteger feature){
    if(feature<MTFeatureHealth || feature>=MTFeatureCount)return nullptr;
    Object owner=backend().context.stats;return owner ? vc::reference(owner,statNames[feature-MTFeatureHealth]) : nullptr;
}
double statValue(Object object){return vc::getNumber(object,"get_Value");}
void setStat(Object object,double value){
    bool original=vc::boolean(object,"_uncapped");vc::boolean(object,"_uncapped",true);
    try{vc::invokeNumber(object,"SetValue",value,true);}catch(...){vc::boolean(object,"_uncapped",original);throw;}
    vc::boolean(object,"_uncapped",original);
}
void setHand(Object object,double value){
    // DealCount has a real minimum and maximum that can both equal four.
    // Edit the native stat's bounds once; never freeze or replay this command.
    Object minimum=vc::call(vc::method(vc::api.objectClass(object),"get_Min",0),object);
    Object maximum=vc::call(vc::method(vc::api.objectClass(object),"get_Max",0),object);
    double low=statValue(minimum),high=statValue(maximum),before=statValue(object);
    bool uncapped=vc::boolean(object,"_uncapped");
    try{
        if(value<low)vc::invokeNumber(object,"SetMin",value);
        if(value>high)vc::invokeNumber(object,"SetMax",value);
        vc::invokeNumber(object,"SetValue",value);
        if(statValue(object)!=value){
            vc::call(vc::method(vc::api.objectClass(object),"Uncap",0),object);
            vc::invokeNumber(object,"SetValue",value);
        }
        if(statValue(object)==value)return;
    }catch(...){
        vc::invokeNumber(object,"SetMin",low);vc::invokeNumber(object,"SetMax",high);
        vc::boolean(object,"_uncapped",uncapped);vc::invokeNumber(object,"SetValue",before);throw;
    }
    vc::invokeNumber(object,"SetMin",low);vc::invokeNumber(object,"SetMax",high);
    vc::boolean(object,"_uncapped",uncapped);vc::invokeNumber(object,"SetValue",before);
    throw std::runtime_error("Der ursprüngliche Handgrößenwert hat die gewünschte Änderung abgelehnt.");
}
bool leaseValid(const BooleanLease& lease){Object object=lease.object.get();return vc::alive(object) && stamp(object)==lease.stamp;}
void releaseGod(){
    Backend& b=backend();Object player=b.god.object.get();
    if(leaseValid(b.god) && vc::boolean(player,"_isInvulnerable"))vc::numericCall(vc::method(vc::api.objectClass(player),"SetInvulnerable",1),player,{b.god.baseline ? 1.0 : 0.0});
    b.god={};b.active[0]=false;
}
void restoreCard(BooleanLease& lease){
    if(leaseValid(lease)){
        Object card=lease.object.get();if(vc::boolean(card,"_isTemporaryFree")){
            vc::boolean(card,"_isTemporaryFree",lease.baseline);
            vc::numericCall(vc::method(vc::api.objectClass(card),"RefreshFreeToPlayState",1),card,{1});
        }
    }
}
void releaseCards(){
    Backend& b=backend();for(BooleanLease& lease:b.cards)restoreCard(lease);
    b.cards.clear();b.active[1]=false;
}
double health(const EnemyLease& lease){Object enemy=lease.object.get();return lease.guardian ? vc::getNumber(enemy,"get_CurrentHealth") : vc::getNumber(enemy,"get_Health");}
double armor(const EnemyLease& lease){Object enemy=lease.object.get();return lease.guardian ? vc::getNumber(enemy,"get_CurrentArmor") : vc::getNumber(enemy,"get_Armor");}
void setEnemy(EnemyLease& lease,bool hitpoints,double value){
    Object enemy=lease.object.get();
    if(lease.guardian){Object variable=vc::reference(enemy,hitpoints ? "_currentHealth" : "_currentArmor");if(!variable)throw std::runtime_error("Die Schutzvariable fehlt.");vc::invokeNumber(variable,"SetValue",value);}
    else vc::numericCall(vc::method(vc::api.objectClass(enemy),hitpoints ? "SetHealth" : "SetArmor",1),enemy,{value});
}
void releaseEnemies(){
    Backend& b=backend();for(EnemyLease& lease:b.enemies){
        Object object=lease.object.get();if(!vc::alive(object) || stamp(object)!=lease.stamp)continue;
        // A defeated enemy is never revived by disabling the trainer.
        if(health(lease)<=0)continue;
        if(health(lease)==1)setEnemy(lease,true,lease.health);
        if(armor(lease)==0)setEnemy(lease,false,lease.armor);
    }
    b.enemies.clear();b.encounterIdentity.clear();b.active[2]=false;
}
struct Targets {std::vector<Object> enemies,guardians;std::string identity;};
Targets targets(){
    Targets result;if(!backend().context.player || !vc::getNumber(backend().context.player,"get_IsInEncounter"))return result;
    // Resolve ownership through the active encounter, not every live EnemyModel
    // in a scene (which can contain previews, pools or the next encounter).
    std::vector<Object> owners;
    for(Object encounter:vc::findObjects(gameClass("Nosebleed.Pancake.Models","EnemyEncounterModel")))
        if(enabled(encounter) && vc::boolean(encounter,"_isActiveEncounter"))owners.push_back(encounter);
    for(Object guardian:vc::findObjects(gameClass("Nosebleed.Pancake.Models","GuardianEncounterModel")))
        if(enabled(guardian) && vc::boolean(guardian,"_isActiveEncounter"))result.guardians.push_back(guardian);
    if(owners.size()+result.guardians.size()>1)throw std::runtime_error("Der aktive Kampf ist nicht eindeutig; keine Gegneränderungen ausgeführt.");
    if(!owners.empty()){
        Object owner=owners.front();result.identity=stamp(owner);
        result.enemies=vc::list(vc::reference(owner,"_aliveEnemies"));
        vc::Class enemy=gameClass("Nosebleed.Pancake.Models","EnemyModel");
        result.enemies.erase(std::remove_if(result.enemies.begin(),result.enemies.end(),[&](Object o){return !enabled(o) || !sameType(o,enemy);}),result.enemies.end());
    }else if(!result.guardians.empty())result.identity=stamp(result.guardians.front());
    return result;
}
void release(){releaseGod();releaseCards();releaseEnemies();backend().xpKnown=false;backend().active[3]=false;}
void god(){
    Backend& b=backend();Object player=b.context.player;
    if(!b.wanted[0] || !player){releaseGod();return;}
    if(!leaseValid(b.god) || b.god.object.get()!=player){releaseGod();b.god.object.reset(player,true);b.god.stamp=stamp(player);b.god.baseline=vc::boolean(player,"_isInvulnerable");}
    if(!vc::boolean(player,"_isInvulnerable"))vc::numericCall(vc::method(vc::api.objectClass(player),"SetInvulnerable",1),player,{1});
    b.active[0]=vc::boolean(player,"_isInvulnerable");
}
void mana(){
    Backend& b=backend();Object player=b.context.player;
    if(!b.wanted[1] || !player){releaseCards();return;}
    auto current=vc::list(vc::reference(player,"_allCards"));bool readback=!current.empty();
    for(auto lease=b.cards.begin();lease!=b.cards.end();){
        Object card=lease->object.get();
        if(!leaseValid(*lease) || std::find(current.begin(),current.end(),card)==current.end()){
            restoreCard(*lease);lease=b.cards.erase(lease);
        }else ++lease;
    }
    for(Object card:current){
        if(!vc::alive(card) || !sameType(card,gameClass("Nosebleed.Pancake.Models","CardModel")))continue;
        std::string id=stamp(card);
        auto found=std::find_if(b.cards.begin(),b.cards.end(),[&](const BooleanLease& l){return l.object.get()==card && l.stamp==id;});
        if(found==b.cards.end()){
            if(b.cards.size()>=4096){readback=false;break;}
            BooleanLease lease;lease.object.reset(card,true);lease.stamp=id;lease.baseline=vc::boolean(card,"_isTemporaryFree");b.cards.push_back(std::move(lease));
        }
        if(!vc::boolean(card,"_isTemporaryFree")){
            vc::boolean(card,"_isTemporaryFree",true);
            vc::numericCall(vc::method(vc::api.objectClass(card),"RefreshFreeToPlayState",1),card,{1});
        }
        readback=readback && vc::number(vc::numericCall(vc::method(vc::api.objectClass(card),"GetCardCostTypeManaCost",2),card,{0,0}))==0;
    }
    b.active[1]=readback;
}
void oneHit(){
    Backend& b=backend();Object player=b.context.player;
    if(!b.wanted[2] || !player){releaseEnemies();return;}
    bool inEncounter=vc::getNumber(player,"get_IsInEncounter")!=0;
    if(!inEncounter){releaseEnemies();return;}
    Targets current=targets();
    if(current.identity!=b.encounterIdentity){releaseEnemies();b.encounterIdentity=current.identity;}
    for(auto entry=b.enemies.begin();entry!=b.enemies.end();){
        auto &owned=entry->guardian ? current.guardians : current.enemies;
        if(!enabled(entry->object.get()) || stamp(entry->object.get())!=entry->stamp || health(*entry)<=0
            || std::find(owned.begin(),owned.end(),entry->object.get())==owned.end())entry=b.enemies.erase(entry);
        else ++entry;
    }
    bool confirmed=false;
    for(bool guardian:{false,true}){
        auto &objects=guardian ? current.guardians : current.enemies;
        for(Object object:objects){
            if(!enabled(object) || (guardian && !vc::boolean(object,"_isActiveEncounter")))continue;
            std::string id=stamp(object);
            auto found=std::find_if(b.enemies.begin(),b.enemies.end(),[&](const EnemyLease& lease){return lease.object.get()==object && lease.stamp==id;});
            if(found==b.enemies.end()){
                if(b.enemies.size()>=1024)throw std::runtime_error("Die Grenze für eigene Gegneränderungen ist erreicht.");
                EnemyLease lease;lease.object.reset(object,true);lease.stamp=id;lease.guardian=guardian;
                lease.health=health(lease);lease.armor=armor(lease);if(lease.health<=0)continue;
                b.enemies.push_back(std::move(lease));found=std::prev(b.enemies.end());
            }
            if(health(*found)<=0)continue;
            if(armor(*found)!=0)setEnemy(*found,false,0);
            if(health(*found)>1)setEnemy(*found,true,1);
            confirmed=confirmed || (health(*found)>0 && health(*found)<=1 && armor(*found)==0);
        }
    }
    b.active[2]=confirmed;
}
void experience(){
    Backend& b=backend();Object player=b.context.player;
    if(!b.wanted[3] || !player){b.xpKnown=false;b.active[3]=false;return;}
    double current=vc::getNumber(player,"get_TotalXp");
    if(!std::isfinite(current) || current<0)throw std::runtime_error("Ungültiger nativer Erfahrungszähler.");
    if(!b.xpKnown || current<b.xpBaseline){b.xpBaseline=current;b.xpKnown=true;return;}
    double gained=current-b.xpBaseline;b.xpBaseline=current;
    if(!gained || b.values[3]==1)return;
    double extra=std::floor(gained*(b.values[3]-1));
    if(extra<0 || current+extra>std::numeric_limits<int32_t>::max())throw std::runtime_error("Der Erfahrungsfaktor würde den nativen Wertebereich überschreiten.");
    vc::numericCall(vc::method(vc::api.objectClass(player),"AddXp",2),player,{extra,0});
    double actual=vc::getNumber(player,"get_TotalXp");b.active[3]=actual==current+extra;b.xpBaseline=actual;
}
void toggle(NSInteger feature){switch(feature){case 0:god();break;case 1:mana();break;case 2:oneHit();break;case 3:experience();break;default:break;}}
void refresh(){
    Backend& b=backend();Context next=capture();
    if(next.identity!=b.previousIdentity || next.kind!=b.context.kind){release();b.previousIdentity=next.identity;}
    b.context=std::move(next);
    if(b.context.kind==0)b.wanted.fill(false);
    if(b.context.kind!=2){release();return;}
}
void tick(){
    if(!VCInFrame())return;Backend& b=backend();b.frames++;
    // With no requested or owned effect, UI polls still validate context, but
    // the per-frame hook must not scan the scene or construct boxed identities.
    if(std::none_of(b.wanted.begin(),b.wanted.end(),[](bool on){return on;}) && !b.god.object.handle && b.cards.empty() && b.enemies.empty() && !b.xpKnown)return;
    try{refresh();if(b.context.kind==2)for(NSInteger i=0;i<4;i++)toggle(i);b.failure=nil;}
    catch(const std::exception& e){b.failure=@(e.what());b.wanted.fill(false);try{release();}catch(...){}b.active.fill(false);}
}
bool available(NSInteger feature){
    Context& c=backend().context;if(c.kind!=2)return false;
    if(feature==MTFeatureTownCoins)return c.progression && vc::method(vc::api.objectClass(c.progression),"AddCoins",1);
    if(!c.player || !c.stats)return false;
    if(feature<4)return true;
    if(feature==MTFeatureDungeonCoins)return vc::method(vc::api.objectClass(c.player),"AddCoins",2) && vc::method(vc::api.objectClass(c.player),"SubtractCoins",1);
    if(feature==MTFeatureExperience)return vc::method(vc::api.objectClass(c.player),"AddXp",2)!=nullptr;
    Object s=stat(feature);return s && vc::method(vc::api.objectClass(s),"SetValue",2) && vc::method(vc::api.objectClass(s),"get_Value",0);
}
NSDictionary *failure(const char *message){return @{@"available":@NO,@"active":@NO,@"note":@(message)};}
}
void VCStartBackend(){
    Backend& b=backend();VCSetFrameHandler(^{tick();});
    if(!b.retry){b.retry=[NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t){(void)t;VCEnsureLoop();}];[NSRunLoop.mainRunLoop addTimer:b.retry forMode:NSRunLoopCommonModes];}
    VCEnsureLoop();
}
NSDictionary *VCInspect(){
    if(!VCInFrame())return @{@"kind":@0,@"identity":@"off-thread",@"note":@"Kein nativer Unity-Rückruf."};
    try{refresh();Backend& b=backend();return @{@"kind":@(b.context.kind),@"identity":@(b.context.identity.c_str()),@"note":b.failure ?: (b.context.kind==2 ? (b.context.player ? @"Lokaler Dungeon-Spieler bestätigt." : @"Lokales Stadtprofil bestätigt.") : @"Warte auf ein gültiges lokales Profil und einen Spielzustand.")};}
    catch(const std::exception& e){return @{@"kind":@0,@"identity":@"binding-error",@"note":@(e.what())};}
}
NSDictionary *VCEffect(NSInteger feature,BOOL wanted,double value){
    if(!VCInFrame() || feature<0 || feature>=MTFeatureCount)return failure("Keine gültige native Zustellung.");
    try{
        const MTFeatureInfo *info=MTFeatureInfoAt((MTFeature)feature);
        if(!std::isfinite(value) || (info->numeric && (value<info->minimum || value>info->maximum || (info->integer && std::floor(value)!=value))))return failure("Ungültiger nativer Wert.");
        bool can=available(feature);Backend& b=backend();
        if(feature<4){if(feature==3 && b.values[feature]!=value){b.active[feature]=false;b.xpKnown=false;}b.wanted[feature]=wanted;b.values[feature]=value;if(can || !wanted)toggle(feature);else b.active[feature]=false;}
        NSString *note=can ? @"Bereit für die einmalige Änderung." : @"Im aktuellen Spielzustand nicht verfügbar.";
        if(feature<4)note=b.active[feature] ? @"Native Wirkung zurückgelesen." : wanted ? (feature==3 ? @"Warte auf den nächsten EXP-Gewinn." : @"Warte auf einen gültigen Besitzer bzw. ein Ziel.") : @"Aus.";
        return @{@"available":@(can),@"active":@(feature<4 && b.active[feature]),@"note":note};
    }catch(const std::exception& e){return failure(e.what());}
}
NSString *VCOneShot(NSInteger feature,double value){
    if(!VCInFrame())return @"Kein nativer Unity-Rückruf; keine Änderung.";
    const MTFeatureInfo *info=MTFeatureInfoAt((MTFeature)feature);
    if(!info || !info->oneShot || !std::isfinite(value) || value<info->minimum || value>info->maximum || (info->integer && std::floor(value)!=value))return @"Ungültiger Wert; keine Änderung.";
    try{
        refresh();if(!available(feature))return @"Spielzustand hat gewechselt; Aktion verworfen.";
        Context& c=backend().context;double actual=0;
        if(feature==MTFeatureTownCoins){
            Object coins=vc::call(vc::method(vc::api.objectClass(c.progression),"get_TotalCoins",0),c.progression);
            double before=statValue(coins);vc::numericCall(vc::method(vc::api.objectClass(c.progression),"AddCoins",1),c.progression,{value-before});actual=statValue(coins);
        }else if(feature==MTFeatureDungeonCoins){
            double before=vc::getNumber(c.player,"get_CurrentCoinCount");
            if(value>=before)vc::numericCall(vc::method(vc::api.objectClass(c.player),"AddCoins",2),c.player,{value-before,0});
            else vc::numericCall(vc::method(vc::api.objectClass(c.player),"SubtractCoins",1),c.player,{before-value});
            actual=vc::getNumber(c.player,"get_CurrentCoinCount");
        }else if(feature==MTFeatureExperience){
            double before=vc::getNumber(c.player,"get_TotalXp");vc::numericCall(vc::method(vc::api.objectClass(c.player),"AddXp",2),c.player,{value-before,1});
            actual=vc::getNumber(c.player,"get_TotalXp");backend().xpBaseline=actual;backend().xpKnown=true;
        }else{
            Object object=stat(feature);
            if(feature==MTFeatureHand)setHand(object,value);
            else if(feature==MTFeatureHealth)vc::invokeNumber(object,"SetValue",std::min(value,vc::getNumber(object,"GetMaxValue")));
            else setStat(object,value);
            actual=statValue(object);
        }
        if(!std::isfinite(actual) || std::fabs(actual-value)>std::max(0.0001,std::fabs(value)*0.000001))return [NSString stringWithFormat:@"Spielregel begrenzt den Wert: zurückgelesen %.8g.",actual];
        return [NSString stringWithFormat:@"%@: %.8g gesetzt und zurückgelesen.",info->title,actual];
    }catch(const std::exception& e){return [NSString stringWithFormat:@"Änderung nicht bestätigt: %s",e.what()];}
}
void VCRelease(){if(!VCInFrame())return;try{backend().wanted.fill(false);release();}catch(const std::exception& e){backend().failure=@(e.what());backend().active.fill(false);}}
BOOL VCMouse(BOOL wanted){
    if(!VCInFrame())return NO;
    try{
        Backend& b=backend();MouseLease& lease=b.mouse;
        if(!wanted && !lease.held)return NO;
        vc::Class cursor=vc::klass("UnityEngine.CoreModule.dll","UnityEngine","Cursor");
        auto current=[&](const char *name){return vc::number(vc::call(vc::method(cursor,name,0),nullptr));};
        auto set=[&](const char *name,double v){vc::numericCall(vc::method(cursor,name,1),nullptr,{v});};
        if(!wanted){
            if(lease.held){
                for(auto &map:lease.maps)if(vc::alive(map.first.get()) && map.second && !vc::getNumber(map.first.get(),"get_enabled"))vc::call(vc::method(vc::api.objectClass(map.first.get()),"Enable",0),map.first.get());
                Object event=lease.eventSystem.get();if(vc::alive(event) && lease.eventEnabled && !vc::getNumber(event,"get_enabled"))vc::numericCall(vc::method(vc::api.objectClass(event),"set_enabled",1),event,{1});
                if(current("get_visible")==1)set("set_visible",lease.visible ? 1 : 0);
                if(current("get_lockState")==0)set("set_lockState",lease.lock);
            }
            lease={};return NO;
        }
        if(!lease.held){
            Object manager=singleton("Nosebleed.Pancake.InputSystem","InputManager");if(!manager)return NO;
            Object input=vc::reference(manager,"_input"),event=vc::reference(manager,"_eventSystem");if(!input || !event)return NO;
            lease.manager.reset(manager,true);lease.eventSystem.reset(event,true);
            lease.visible=current("get_visible")!=0;lease.lock=(int)current("get_lockState");lease.eventEnabled=vc::getNumber(event,"get_enabled")!=0;
            void *iterator=nullptr;
            while(vc::Field f=vc::api.fields(vc::api.objectClass(input),&iterator))if(vc::typeName(vc::api.fieldType(f))=="UnityEngine.InputSystem.InputActionMap"){
                Object map=nullptr;vc::api.fieldRead(input,f,&map);if(map)lease.maps.emplace_back(Root(map,true),vc::getNumber(map,"get_enabled")!=0);
            }
            if(lease.maps.empty())return NO;lease.held=true;
        }
        bool blocked=true;
        for(auto &entry:lease.maps){Object map=entry.first.get();if(!map)continue;if(vc::getNumber(map,"get_enabled"))vc::call(vc::method(vc::api.objectClass(map),"Disable",0),map);blocked=blocked && vc::getNumber(map,"get_enabled")==0;}
        Object event=lease.eventSystem.get();if(!vc::alive(event))return NO;
        if(vc::getNumber(event,"get_enabled"))vc::numericCall(vc::method(vc::api.objectClass(event),"set_enabled",1),event,{0});
        set("set_lockState",0);set("set_visible",1);
        return blocked && current("get_visible")==1 && current("get_lockState")==0 && vc::getNumber(event,"get_enabled")==0;
    }catch(const std::exception& e){backend().failure=@(e.what());return NO;}
}
NSDictionary *VCValues(){
    if(!VCInFrame())return @{};
    try{
        refresh();Context& c=backend().context;NSMutableDictionary *values=[NSMutableDictionary new];
        if(c.progression){Object coins=vc::call(vc::method(vc::api.objectClass(c.progression),"get_TotalCoins",0),c.progression);if(coins)values[@"TownCoins"]=@(statValue(coins));}
        if(c.player){values[@"DungeonCoins"]=@(vc::getNumber(c.player,"get_CurrentCoinCount"));values[@"EXP"]=@(vc::getNumber(c.player,"get_TotalXp"));values[@"Invulnerable"]=@(vc::boolean(c.player,"_isInvulnerable"));values[@"CurrentXP"]=@(vc::getNumber(c.player,"get_PlayerXp"));values[@"MaxXP"]=@(vc::getNumber(c.player,"get_MaxXp"));values[@"Level"]=@(vc::getNumber(c.player,"get_PlayerLevel"));values[@"InEncounter"]=@(vc::getNumber(c.player,"get_IsInEncounter"));values[@"Cards"]=@(vc::list(vc::reference(c.player,"_allCards")).size());}
        for(NSInteger i=MTFeatureHealth;i<MTFeatureCount;i++)if(Object object=stat(i))values[@(statNames[i-MTFeatureHealth])]=@(statValue(object));
        NSMutableArray *cards=[NSMutableArray new],*enemies=[NSMutableArray new];
        if(c.player)for(Object card:vc::list(vc::reference(c.player,"_allCards")))if(vc::alive(card)){
            [cards addObject:@{@"identity":@(stamp(card).c_str()),@"free":@(vc::boolean(card,"_isTemporaryFree")),
                @"cost":@(vc::number(vc::numericCall(vc::method(vc::api.objectClass(card),"GetCardCostTypeManaCost",2),card,{0,0})))}];
        }
        Targets owned=targets();values[@"encounterIdentity"]=@(owned.identity.c_str());
        if(c.player && vc::getNumber(c.player,"get_IsInEncounter"))for(bool guardian:{false,true}){
            for(Object object:guardian ? owned.guardians : owned.enemies){
                if(!enabled(object) || (guardian && !vc::boolean(object,"_isActiveEncounter")))continue;
                EnemyLease entry;entry.object.reset(object,true);entry.guardian=guardian;
                [enemies addObject:@{@"identity":@(stamp(object).c_str()),@"health":@(health(entry)),@"armor":@(armor(entry)),@"guardian":@(guardian)}];
            }
        }
        values[@"cardReadback"]=cards;values[@"enemyReadback"]=enemies;
        if(Object hand=stat(MTFeatureHand))values[@"handLimits"]=@{
            @"min":@(statValue(vc::call(vc::method(vc::api.objectClass(hand),"get_Min",0),hand))),
            @"max":@(statValue(vc::call(vc::method(vc::api.objectClass(hand),"get_Max",0),hand))),
            @"uncapped":@(vc::boolean(hand,"_uncapped"))};
        NSMutableArray *effects=[NSMutableArray new];for(bool active:backend().active)[effects addObject:@(active)];values[@"effects"]=effects;
        return values;
    }catch(const std::exception& e){return @{@"error":@(e.what())};}
}
