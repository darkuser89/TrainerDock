// SPDX-License-Identifier: GPL-3.0-only
// Synthetic owned-effect boundary checks only; never part of a product.
#import "PlayerEffects.hpp"
#include <map>
#include <cstring>
#include <cassert>
#include <cmath>
namespace {
unsigned char counter=0;bool damage=true;double health=75,maximum=100,timeScale=1;unsigned pushes=0,pops=0;double speed=2,cap=2,ratio=.05;float walk=180,run=500;unsigned lookups=0,speedReads=0,speedWrites=0;bool pawnAlive=true;
uintptr_t ptr(int i){return 0x10000ULL*(unsigned)i;}
void *worldSettings(void *,bool,bool){return (void *)ptr(6);}
float setTime(void *,float v){timeScale=v;return v;}
float walkingMaxSpeed(void *){speedReads++;return walk;}
float runningMaxSpeed(void *){speedReads++;return run;}
void check(bool ok,const char *text){if(!ok){fprintf(stderr,"FAIL: %s\n",text);exit(1);}}
}
namespace st {
bool isGameThread(){return true;}
Weak::Weak(Object o){index=(int32_t)(o.address/0x10000);serial=1;if(index==2&&!pawnAlive)throw std::runtime_error("Destroyed fixture pawn");}
Object Weak::get()const{return serial&&(index!=2||pawnAlive)?Object{ptr(index)}:Object{};}
Object object(int32_t i){if(i<1||i>7||(i==2&&!pawnAlive))throw std::runtime_error("Unknown fixture object");return {ptr(i)};}
Object world(){return object(1);}Object playerPawn(){return object(2);}Object playerController(){return object(3);}
NSString *className(Object o){switch(o.address/0x10000){case 1:return @"World";case 2:return @"BP_CatPawn_C";case 3:return @"HKPlayerController";case 4:return @"LifeComponent";case 5:return @"LocalPlayer";case 6:return @"WorldSettings";default:return @"Level";}}
bool read(uintptr_t at,void *out,size_t n){for(int i=1;i<=7;i++){if(at==ptr(i)+0x20&&n==8){uintptr_t level=ptr(7);memcpy(out,&level,8);return true;}if(at==ptr(i)+0xc&&n==4){memcpy(out,&i,4);return true;}}if(at==ptr(2)+0x1e30&&n==4&&pawnAlive){memcpy(out,&walk,4);return true;}if(at==ptr(2)+0x1e34&&n==4&&pawnAlive){memcpy(out,&run,4);return true;}if(at==ptr(2)+0x3790&&n==1){memcpy(out,&counter,1);return true;}return false;}
bool write(uintptr_t at,const void *bytes,size_t n){check(pawnAlive,"destroyed pawn is never written");if(n==4&&at==ptr(2)+0x1e30){memcpy(&walk,bytes,4);speedWrites++;return true;}if(n==4&&at==ptr(2)+0x1e34){memcpy(&run,bytes,4);speedWrites++;return true;}return false;}
uintptr_t binding(const char *name){if(!strcmp(name,"walkingMaxSpeed"))return (uintptr_t)&walkingMaxSpeed;if(!strcmp(name,"runningMaxSpeed"))return (uintptr_t)&runningMaxSpeed;if(!strcmp(name,"worldSettings"))return (uintptr_t)&worldSettings;if(!strcmp(name,"setTimeDilation"))return (uintptr_t)&setTime;throw std::runtime_error("Unknown fixture binding");}
Property property(Object owner,NSString *name){lookups++;Property p;p.name=name;p.ownerClass=owner;p.type=@"FloatProperty";p.count=1;p.size=4;if([name isEqual:@"m_maximumMovementInputSize"])p.offset=0x7c0;if([name isEqual:@"m_timeDilationLerpRatio"])p.offset=0x5d8;return p;}
id readValue(Object,const Property &p){int id=0;if([p.name isEqual:@"Pawn"])id=2;else if([p.name isEqual:@"Controller"])id=3;else if([p.name isEqual:@"Player"])id=5;else if([p.name isEqual:@"m_lifeComponent"])id=4;else if([p.name isEqual:@"OwningWorld"])id=1;else if([p.name isEqual:@"m_maximumMovementInputSize"])return @(cap);else if([p.name isEqual:@"m_timeDilationLerpRatio"])return @(ratio);else if([p.name isEqual:@"TimeDilation"])return @(timeScale);else throw std::runtime_error("Unknown fixture property");return @{@"object":@(id)};}
bool writeValue(Object,const Property &p,id value){if([p.name isEqual:@"m_maximumMovementInputSize"]){cap=[value doubleValue];return true;}if([p.name isEqual:@"m_timeDilationLerpRatio"]){ratio=[value doubleValue];return true;}throw std::runtime_error("Unknown fixture write");}
id invoke(Object owner,NSString *name,NSDictionary *args){
 if([name isEqual:@"CanTakeDamage"])return @(damage);
 if([name isEqual:@"SetTakeDamage"]){check(args.count==1&&args[@"_canTakeDamage"],"exact original damage argument");damage=[args[@"_canTakeDamage"] boolValue];return NSNull.null;}
 if([name isEqual:@"GetMaxLife"])return @(maximum);
 if([name isEqual:@"GetCurrentLife"])return @(health);
 if([name isEqual:@"Reset"]){check(args.count==1&&args[@"_life"],"exact original Reset argument");health=MIN(maximum,[args[@"_life"] doubleValue]);return NSNull.null;}
 if([name isEqual:@"IsDead"])return @(health<=0);
 if([name isEqual:@"GetOwner"]){check(owner.address==ptr(4),"life belongs to controlled pawn");return @{@"object":@2};}
 if([name isEqual:@"PushInvincibility"]){pushes++;if(counter++==0)damage=false;return NSNull.null;}
 if([name isEqual:@"PopInvincibility"]){pops++;check(counter>0,"native Pop must not underflow");if(--counter==0)damage=true;return NSNull.null;}
 if([name isEqual:@"GetFinalSpeedModifier"])return @(MIN(speed,cap));
 throw std::runtime_error("Unknown fixture native function");
}
}
int main(){@autoreleasepool{
 setenv("MHT_SESSION","fixture-owned-session",1);
 auto c=st::playerContext();check(c.ready,"world, local controller, pawn and component ownership agree");
 auto f=[&](NSInteger n,bool wanted,double v=1){return st::playerFeature(c,n,wanted,v);};
 check([f(0,true)[@"active"] boolValue]&&counter==1&&!damage,"God owns one native stack entry");
 f(0,true);check(pushes==1&&counter==1,"polling never duplicates the God stack");
 check([f(1,true)[@"active"] boolValue]&&health==maximum,"health invokes native maximum Reset and damage flag");
 f(0,false);check(counter==0&&!damage,"God release preserves active health protection");
 f(1,false);check(damage,"last health release restores captured original damage flag");
 damage=false;f(0,true);f(0,false);check(!damage,"last original Pop cannot override independently disabled damage");
 damage=false;counter=2;f(0,true);check(counter==3,"existing engine stack entries are preserved");f(0,false);check(counter==2&&!damage,"only trainer's own stack entry is removed");
 counter=254;unsigned before=pushes;check(![f(0,true)[@"active"] boolValue]&&pushes==before,"saturated native counter rejects activation");counter=0;damage=true;
 check([f(6,true,1)[@"active"] boolValue]&&walk==180&&run==500&&speedWrites==0,"factor one preserves both original native base speeds");
 check([f(6,true,2)[@"active"] boolValue]&&walk==360&&run==1000,"factor two doubles the actual walking and running base speeds");
 unsigned written=speedWrites;f(6,true,2);check(speedWrites==written&&walk==360&&run==1000,"polling does not compound or rewrite the speed factor");
 f(6,true,3);check(walk==540&&run==1500,"factor changes always derive from original base speeds");
 f(6,false,3);check(walk==180&&run==500,"off restores both original speed caches");
 check(speed==2&&cap==2,"native MIN modifiers and input cap remain untouched");
 f(6,true,2);walk=333;f(6,false,2);check(walk==333&&run==500,"off preserves foreign walking change and independently restores own running change");walk=180;
 f(6,true,2);walk=333;check(![f(6,true,3)[@"active"] boolValue]&&walk==333&&run==1000,"an intervening native change rejects further activation writes");f(6,false,2);check(walk==333&&run==500,"failed activation still returns the remaining owned speed cache");walk=180;
 check(![f(6,true,NAN)[@"active"] boolValue]&&! [f(6,true,11)[@"active"] boolValue]&&walk==180&&run==500,"invalid factors do not change native base speeds");
 check([f(7,true,2)[@"active"] boolValue]&&timeScale==2&&ratio==1,"native time setter and owned engine interpolation are read back");timeScale+=(1-std::pow(ratio,.5))*(1-timeScale);check(timeScale==2,"original inactive HK interpolation no longer undoes owned time");timeScale=3;f(7,false,2);check(timeScale==3&&ratio==.05,"off preserves intervening engine time changes and restores interpolation");f(7,true,2);f(7,false,2);check(timeScale==3,"later activation captures a fresh original time");
 f(6,true,2);unsigned writesBeforeDestroy=speedWrites;pawnAlive=false;st::releasePlayerEffects();check(speedWrites==writesBeforeDestroy,"destroyed owner is not accessed during release");pawnAlive=true;walk=180;run=500;
 check([f(6,true,2)[@"active"] boolValue]&&walk==360&&run==1000,"new owner captures fresh native base speeds");f(6,false,2);
 f(7,true,2);ratio=.2;f(7,false,2);check(ratio==.2,"time release preserves intervening native interpolation changes");
 unsigned idleBefore=lookups,idleSpeedReads=speedReads;for(int n=0;n<20000;n++)for(NSInteger feature: {0,1,6,7})f(feature,false);check(lookups==idleBefore&&speedReads==idleSpeedReads,"disabled unowned player features do not inspect metadata or native speeds");
 st::releasePlayerEffects();check(counter==0&&pops==3,"full release does not repeat native Pops");
 puts("PASS: original-stack ownership, God/health coordination, independent damage state, native walking/running scaling, conditional restoration, destroyed owners and time restoration. Synthetic boundary fixtures; no game started.");
}}
