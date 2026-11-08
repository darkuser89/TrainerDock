// SPDX-License-Identifier: GPL-3.0-only
#import "PlayerEffects.hpp"
#include <cmath>
#include <array>
#include <exception>
namespace st {
namespace {
struct Lease {Weak pawn{},life{},world{},controller{},settings{};bool god=false,health=false,baseline=false,damageOriginal=false,damageWritten=false,speed=false,time=false,timeRatio=false;std::array<double,2> speedOriginal{},speedWritten{};std::array<bool,2> speedOwned{};double timeOriginal=1,timeWritten=1,ratioOriginal=1;};
Lease lease;
[[noreturn]]void fail(const char *text){throw std::runtime_error(text);}
bool near(double a,double b){return std::isfinite(a)&&std::isfinite(b)&&std::abs(a-b)<.002;}
Object valueObject(id value){if(value==NSNull.null)return {};if(![value isKindOfClass:NSDictionary.class]||![value[@"object"] isKindOfClass:NSNumber.class])fail("Das Spiel hat keinen Objektbesitzer zurückgegeben.");return object([value[@"object"] intValue]);}
Object member(Object o,NSString *field){return valueObject(readValue(o,property(o,field)));}
bool inWorld(Object actor,Object expected){try{Object level{read<uintptr_t>(actor.address+0x20)};return [className(level) isEqual:@"Level"]&&member(level,@"OwningWorld")==expected;}catch(const std::exception &){return false;}}
bool canDamage(Object life){return [invoke(life,@"CanTakeDamage",@{}) boolValue];}
void setDamage(Object life,bool wanted){invoke(life,@"SetTakeDamage",@{@"_canTakeDamage":@(wanted)});if(canDamage(life)!=wanted)fail("Der Schadenszustand wurde nicht bestätigt.");}
uint8_t invincibility(Object pawn){return read<uint8_t>(pawn.address+0x3790);}
void captureDamage(Object life){if(!lease.baseline){lease.damageOriginal=canDamage(life);lease.baseline=true;}}
void repairDamage(){Object pawn=lease.pawn.get(),life=lease.life.get();if(!pawn||!life)return;
 if(lease.health||lease.god){if(canDamage(life))setDamage(life,false);lease.damageWritten=true;}
 else if(invincibility(pawn)==0&&lease.baseline&&lease.damageWritten&&!canDamage(life)){setDamage(life,lease.damageOriginal);lease.damageWritten=false;}
 if(!lease.god&&!lease.health){lease.baseline=false;lease.damageWritten=false;}
}
void releaseGod(){Object pawn=lease.pawn.get(),life=lease.life.get();bool last=false;
 if(lease.god&&pawn){uint8_t before=invincibility(pawn);if(before>0){invoke(pawn,@"PopInvincibility",@{});last=before==1;}}
 lease.god=false;
 // The original last Pop explicitly writes true; restore the captured flag when
 // it was independently false before this trainer acquired its own stack entry.
 if(last&&!lease.health&&life&&lease.baseline&&canDamage(life)!=lease.damageOriginal)setDamage(life,lease.damageOriginal);
 repairDamage();
}
void releaseHealth(){lease.health=false;repairDamage();}
Property originalFloat(Object owner,NSString *field,int32_t offset){Property p=property(owner,field);if(![p.type isEqual:@"FloatProperty"]||p.offset!=offset||p.size!=4||p.count!=1)fail("Die ursprüngliche Geschwindigkeitszuordnung stimmt nicht überein.");return p;}
constexpr uintptr_t speedOffsets[2]={0x1e30,0x1e34};
constexpr const char *speedGetters[2]={"walkingMaxSpeed","runningMaxSpeed"};
double speedValue(Object pawn,size_t which){
 Weak keep(pawn);uintptr_t getter=binding(speedGetters[which]);if(!getter||keep.get()!=pawn)fail("Der native Bewegungsbesitzer ist abgelaufen.");
 float direct=read<float>(pawn.address+speedOffsets[which]);float native=((float(*)(void *))getter)((void *)pawn.address);
 if(keep.get()!=pawn||!std::isfinite(native)||native<=0||native>100000||!near(direct,native))fail("Die ursprüngliche Bewegungsgeschwindigkeit stimmt nicht überein.");return native;
}
bool speedOwner(Object pawn){Object w=lease.world.get(),pc=lease.controller.get();return pawn&&lease.pawn.get()==pawn&&w&&pc&&world()==w&&playerPawn()==pawn&&playerController()==pc&&member(pc,@"Pawn")==pawn&&member(pawn,@"Controller")==pc&&inWorld(pawn,w)&&inWorld(pc,w);}
void writeSpeed(Object pawn,size_t which,double wanted){
 if(!std::isfinite(wanted)||wanted<=0||wanted>100000||!speedOwner(pawn))fail("Der lokale Bewegungsbesitzer ist nicht bestätigt.");
 // Original BeginPlay caches TROT/RUN reference speeds in these local floats.
 // The two bound native getters prove both offsets; animation assets and the
 // original MIN-based slowdowns/Rail modifiers remain untouched.
 (void)speedValue(pawn,which);float value=(float)wanted;
 if(lease.pawn.get()!=pawn||!write(pawn.address+speedOffsets[which],&value,sizeof(value))||!near(speedValue(pawn,which),wanted))fail("Die Bewegungsgeschwindigkeit wurde nicht bestätigt.");
}
bool applySpeed(Object pawn,double factor){
 std::array<double,2> current{speedValue(pawn,0),speedValue(pawn,1)};
 if(!lease.speed){lease.speedOriginal=current;lease.speedWritten=current;lease.speedOwned={};lease.speed=true;}
 for(size_t i=0;i<2;i++){
  if(!near(current[i],lease.speedWritten[i]))fail("Die Bewegungsgeschwindigkeit wurde inzwischen vom Spiel verändert.");
  double desired=lease.speedOriginal[i]*factor;if(!std::isfinite(desired)||desired<=0||desired>100000)fail("Die gewünschte Bewegungsgeschwindigkeit liegt außerhalb der Grenzen.");
  if(!near(current[i],desired)){lease.speedOwned[i]=true;lease.speedWritten[i]=(float)desired;writeSpeed(pawn,i,desired);lease.speedWritten[i]=speedValue(pawn,i);}
 }
 return near(speedValue(pawn,0),lease.speedOriginal[0]*factor)&&near(speedValue(pawn,1),lease.speedOriginal[1]*factor);
}
void releaseSpeed(){Object pawn=lease.pawn.get();if(lease.speed&&pawn&&speedOwner(pawn))for(size_t i=0;i<2;i++)if(lease.speedOwned[i]&&near(speedValue(pawn,i),lease.speedWritten[i]))writeSpeed(pawn,i,lease.speedOriginal[i]);lease.speed=false;lease.speedOwned={};}
Object settings(Object world){Object s{(uintptr_t)((void *(*)(void *,bool,bool))binding("worldSettings"))((void *)world.address,false,true)};if(!s||!inWorld(s,world)||[className(s) rangeOfString:@"WorldSettings"].location==NSNotFound)fail("Die Einstellungen der aktiven Spielwelt fehlen.");return s;}
double timeValue(Object settings){return [readValue(settings,property(settings,@"TimeDilation")) doubleValue];}
void setTime(Object settings,double value){((float(*)(void *,float))binding("setTimeDilation"))((void *)settings.address,(float)value);}
void holdTimeRatio(Object controller){Property p=originalFloat(controller,@"m_timeDilationLerpRatio",0x5d8);double current=[readValue(controller,p) doubleValue];if(!std::isfinite(current)||current<0||current>1)fail("Der native Zeitübergang ist ungültig.");if(!lease.timeRatio){lease.ratioOriginal=current;lease.timeRatio=true;}else if(!near(current,1))fail("Der Zeitübergang wurde inzwischen vom Spiel verändert.");if(!near(current,1)&&!writeValue(controller,p,@1))fail("Der native Zeitübergang wurde nicht übernommen.");if(!near([readValue(controller,p) doubleValue],1))fail("Der native Zeitübergang wurde nicht bestätigt.");}
void releaseTime(){Object s=lease.settings.get(),controller=lease.controller.get();if(lease.time&&s&&near(timeValue(s),lease.timeWritten))setTime(s,lease.timeOriginal);lease.time=false;lease.settings={};if(lease.timeRatio&&controller){Property p=originalFloat(controller,@"m_timeDilationLerpRatio",0x5d8);if(near([readValue(controller,p) doubleValue],1)&&!writeValue(controller,p,@(lease.ratioOriginal)))fail("Der native Zeitübergang konnte nicht zurückgegeben werden.");}lease.timeRatio=false;}
void establish(const PlayerContext &c){if(lease.pawn.get()!=c.pawn||lease.life.get()!=c.life||lease.world.get()!=c.world||lease.controller.get()!=c.controller){releasePlayerEffects();lease.pawn=Weak(c.pawn);lease.life=Weak(c.life);lease.world=Weak(c.world);lease.controller=Weak(c.controller);}}

}
PlayerContext playerContext(){
 PlayerContext c;c.note=@"Auf die steuerbare Katze warten.";
 try{
  if(!isGameThread())return c;c.world=world();c.pawn=playerPawn();c.controller=playerController();
  if([className(c.pawn) rangeOfString:@"CatPawn"].location==NSNotFound||!inWorld(c.pawn,c.world)||!inWorld(c.controller,c.world))return c;
  if(member(c.controller,@"Pawn")!=c.pawn||member(c.pawn,@"Controller")!=c.controller)return c;
  Object local=member(c.controller,@"Player");if(!local||[className(local) rangeOfString:@"LocalPlayer"].location==NSNotFound)return c;
  c.life=member(c.pawn,@"m_lifeComponent");if(!c.life||![className(c.life) isEqual:@"LifeComponent"]||valueObject(invoke(c.life,@"GetOwner",@{}))!=c.pawn)return c;
  if([invoke(c.pawn,@"IsDead",@{}) boolValue]){c.note=@"Die Katze ist derzeit nicht steuerbar.";return c;}
  Weak w(c.world),p(c.pawn),l(c.life),pc(c.controller);c.identity=[NSString stringWithFormat:@"%d:%d/%d:%d/%d:%d/%d:%d",w.index,w.serial,p.index,p.serial,l.index,l.serial,pc.index,pc.serial];c.ready=true;c.note=@"Lokale Katze verbunden.";
 }catch(const std::exception &e){c.ready=false;c.note=[NSString stringWithUTF8String:e.what()] ?: @"Der lokale Spielkontext ist noch nicht bereit.";}
 return c;
}
void releasePlayerEffects(){if(!isGameThread())return;for(int n=0;n<4;n++)try{if(n==0)releaseSpeed();if(n==1)releaseTime();if(n==2)releaseHealth();if(n==3)releaseGod();}catch(const std::exception &){}lease={};}
NSDictionary *playerFeature(const PlayerContext &c,NSInteger f,bool wanted,double value){
 if(!isGameThread()||!c.ready)return @{@"available":@NO,@"active":@NO,@"note":@"Auf einen gültigen lokalen Spielstand warten."};
 // Disabled features without an owned change do not traverse metadata, capture
 // owners, resolve effects or call into the engine on every bridge poll.
 if(!wanted&&((f==0&&!lease.god)||(f==1&&!lease.health)||(f==6&&!lease.speed)||(f==7&&!lease.time&&!lease.timeRatio)))return @{@"available":@YES,@"active":@NO,@"note":@"Aus."};
 try{
  establish(c);bool active=false;
  if(f==0){
   if(wanted&&!lease.god){uint8_t before=invincibility(c.pawn);if(before>=254)fail("Die Unverwundbarkeit ist bereits zu oft gestapelt.");captureDamage(c.life);invoke(c.pawn,@"PushInvincibility",@{});lease.god=true;lease.damageWritten=true;if(invincibility(c.pawn)!=(uint8_t)(before+1))fail("Der native Schutz wurde nicht bestätigt.");}
   if(!wanted&&lease.god)releaseGod();active=wanted&&lease.god&&invincibility(c.pawn)>0&&!canDamage(c.life);
  }else if(f==1){
   if(wanted){captureDamage(c.life);lease.health=true;setDamage(c.life,false);lease.damageWritten=true;double maximum=[invoke(c.life,@"GetMaxLife",@{}) doubleValue];if(!std::isfinite(maximum)||maximum<=0||maximum>1000000)fail("Ungültiges ursprüngliches Gesundheitsmaximum.");invoke(c.life,@"Reset",@{@"_life":@(maximum)});active=near([invoke(c.life,@"GetCurrentLife",@{}) doubleValue],maximum)&&!canDamage(c.life);}
   else if(lease.health)releaseHealth();
  }else if(f==6){
   if(!std::isfinite(value)||value<.25||value>10)fail("Ungültiger Geschwindigkeitsfaktor.");
   if(wanted)active=applySpeed(c.pawn,value);
   else if(lease.speed)releaseSpeed();
  }else if(f==7){
   if(!std::isfinite(value)||value<.1||value>10)fail("Ungültige Spielgeschwindigkeit.");
   if(wanted){Object s=settings(c.world);double before=timeValue(s);if(!lease.time){lease.timeOriginal=before;lease.settings=Weak(s);}else if(lease.settings.get()!=s)fail("Die aktive Spielwelt hat gewechselt.");holdTimeRatio(c.controller);setTime(s,value);lease.timeWritten=timeValue(s);lease.time=true;active=near(lease.timeWritten,value);}
   else if(lease.time||lease.timeRatio)releaseTime();
  }else return @{@"available":@NO,@"active":@NO,@"note":@"Keine passende Spielerfunktion."};
  return @{@"available":@YES,@"active":@(wanted&&active),@"note":!wanted?@"Aus.":active?@"Native Wirkung bestätigt.":@"Auf native Rückmeldung warten."};
 }catch(const std::exception &e){if(!lease.god&&!lease.health){lease.baseline=false;lease.damageWritten=false;}return @{@"available":@NO,@"active":@NO,@"note":[NSString stringWithUTF8String:e.what()] ?: @"Die native Spielerfunktion wurde nicht bestätigt."};}
}
NSDictionary *playerDiagnostics(const PlayerContext &c){if(!isGameThread()||!c.ready)return @{@"ready":@NO};NSMutableDictionary *d=[@{@"ready":@YES,@"identity":c.identity?:@"",@"pawn":@(read<int32_t>(c.pawn.address+0xc)),@"life":@(read<int32_t>(c.life.address+0xc)),@"invincibility":@(invincibility(c.pawn))} mutableCopy];for(NSString *method in @[@"GetCurrentLife",@"GetMaxLife",@"CanTakeDamage"])try{d[method]=invoke(c.life,method,@{});}catch(const std::exception &){}try{d[@"speed"]=invoke(c.pawn,@"GetFinalSpeedModifier",@{});d[@"walkingMaxSpeed"]=@(speedValue(c.pawn,0));d[@"runningMaxSpeed"]=@(speedValue(c.pawn,1));}catch(const std::exception &){}try{d[@"time"]=@(timeValue(settings(c.world)));}catch(const std::exception &){}return d;}
}
