// SPDX-License-Identifier: GPL-3.0-only
#import "Movement.h"
#import "LuaEngine.hpp"
#include <mutex>
#include <cmath>
#include <stdexcept>
namespace {
std::mutex mutex;
NSString *currentOwner;
uint64_t generation=0;
bool wants=false,busy=false,captured=false,confirmed=false;
double multiplier=1,original=0,written=0;
NSString *entity(NSString *owner){
 NSString *value=[owner componentsSeparatedByString:@":"].firstObject;
 if(!value.length||value.length>20||[value rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location!=NSNotFound)return nil;
 return value;
}
double readSpeed(NSString *id){
 NSDictionary *response=IZPresentationCommand([@"movement.set_speed action=get entity_id=" stringByAppendingString:id]);
 NSString *text=response[@"data"];
 if(![response[@"ok"] boolValue]||![text isKindOfClass:NSString.class]||text.length>4096)throw std::runtime_error("Original movement query rejected");
 NSDictionary *data=[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
 if(![data isKindOfClass:NSDictionary.class]||![data[@"max_walk_speed"] isKindOfClass:NSNumber.class])throw std::runtime_error("Original movement schema differs");
 double value=[data[@"max_walk_speed"] doubleValue];
 if(!std::isfinite(value)||value<1||value>2000)throw std::runtime_error("Original movement value outside bounds");
 return value;
}
void setSpeed(NSString *id,double value){
 NSDictionary *r=IZPresentationCommand([NSString stringWithFormat:@"movement.set_speed action=set speed=%.6f entity_id=%@",value,id]);
 if(![r[@"ok"] boolValue])throw std::runtime_error("Original movement setter rejected");
}
void restore(NSString *owner,double value,double last){
 NSString *id=entity(owner);if(!id)return;
 IZOnPresentationThread(^{@try{try{if(std::abs(readSpeed(id)-last)<.05)setSpeed(id,value);}catch(const std::exception &){}}@catch(NSException *){}});
}
}
void IZMovementSetOwner(NSString *owner){
 NSString *old=nil;double value=0,last=0;
 {std::lock_guard<std::mutex> lock(mutex);if((!currentOwner&&!owner)||[currentOwner isEqual:owner])return;
  if(captured){old=currentOwner;value=original;last=written;}
  generation++;currentOwner=[owner copy];wants=false;busy=false;captured=false;confirmed=false;original=0;written=0;
 }
 if(old)restore(old,value,last);
}
NSDictionary *IZMovementApply(NSString *owner,BOOL wanted,double factor){
 IZMovementSetOwner(owner);NSString *id=entity(owner);
 if(!id||!std::isfinite(factor)||factor<.25||factor>10)return @{@"available":@NO,@"active":@NO,@"note":@"Kein gültiger lokaler Zoi verfügbar."};
 NSString *restoreOwner=nil;double restoreValue=0,restoreLast=0;uint64_t epoch=0;bool schedule=false;
 NSDictionary *result=nil;
 {std::lock_guard<std::mutex> lock(mutex);
  if(wants!=(bool)wanted||multiplier!=factor){generation++;busy=false;confirmed=false;}
  if(!wanted&&captured){restoreOwner=currentOwner;restoreValue=original;restoreLast=written;captured=false;}
  wants=wanted;multiplier=factor;
  if(wanted&&!busy){busy=true;schedule=true;epoch=generation;}
  result=@{@"available":@YES,@"active":@(wanted&&confirmed),@"note":!wanted?@"Aus.":confirmed?@"Native Bewegungsgeschwindigkeit bestätigt.":@"Auf native Rückmeldung warten."};
 }
 if(restoreOwner)restore(restoreOwner,restoreValue,restoreLast);
 if(schedule)IZOnPresentationThread(^{
  @try{try{
   {std::lock_guard<std::mutex> lock(mutex);if(generation!=epoch||!wants)return;}
   double actual=readSpeed(id),baseline=actual;
   {std::lock_guard<std::mutex> lock(mutex);if(generation!=epoch||!wants)return;if(captured&&std::abs(actual-written)<.05)baseline=original;}
   double target=std::min(2000.,std::max(1.,baseline*factor));
   if(std::abs(actual-target)>=.05)setSpeed(id,target);
   double observed=readSpeed(id);
   std::lock_guard<std::mutex> lock(mutex);
   if(generation==epoch&&wants){original=baseline;written=target;captured=true;confirmed=std::abs(observed-target)<.05;busy=false;}
  }catch(const std::exception &){std::lock_guard<std::mutex> lock(mutex);if(generation==epoch){busy=false;confirmed=false;}}}
  @catch(NSException *){std::lock_guard<std::mutex> lock(mutex);if(generation==epoch){busy=false;confirmed=false;}}
 });
 return result;
}
