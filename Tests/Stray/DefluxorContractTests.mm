// SPDX-License-Identifier: GPL-3.0-only
// Isolated original-API contract fixture; never linked into product/game code.
#import <Foundation/Foundation.h>
#import "Defluxor.hpp"
#import "PlayerEffects.hpp"
#include <cstring>
#include <cmath>
namespace {
constexpr uintptr_t pc=0x10000,cat=0x20000,map=0x30000,device=0x40000;
bool ready=true,bound=true,thread=true,hasDrone=true,unlocked=true,rightWorld=true,rightSchema=true;
int serial=1;NSUInteger writes=0,failWrite=0,nativeQueries=0,contextQueries=0,equipmentQueries=0;
NSMutableDictionary *values;
void *actorWorldFixture(void *actor){NSCAssert((uintptr_t)actor==device,@"Only the identified local equipment may use the actor API");return (void *)(rightWorld?map:cat);}
void check(bool value,const char *why){if(!value){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
void reset(){
 bound=true;thread=true;ready=true;STDefluxorRelease();serial++;hasDrone=true;unlocked=true;rightWorld=true;rightSchema=true;
 values=[@{@"HeatIncreaseSpeed":@0.4,@"Battery":@0.8,@"DroneIsOverHeating":@YES} mutableCopy];writes=0;failWrite=0;nativeQueries=0;contextQueries=0;equipmentQueries=0;
}
}
namespace st {
bool isBound(){return bound;}bool isGameThread(){return thread;}
PlayerContext playerContext(){nativeQueries++;contextQueries++;PlayerContext c;c.ready=ready;c.controller={pc};c.pawn={cat};c.world={map};c.identity=@"local-cat:world";return c;}
Weak::Weak(Object o){nativeQueries++;index=(int32_t)(o.address>>16);this->serial=::serial;}
Object Weak::get()const{nativeQueries++;return this->serial==::serial?Object{((uintptr_t)index)<<16}:Object{};}
Object object(int32_t index){nativeQueries++;NSCAssert(index==4,@"Only the original GetDrone result may resolve to equipment");return {device};}
NSString *className(Object o){nativeQueries++;NSCAssert(o.address==device,@"Only local equipment is inspected");return @"BP_Drone_C";}
uintptr_t binding(const char *name){nativeQueries++;return !strcmp(name,"actorWorld")?(uintptr_t)actorWorldFixture:0;}
bool read(uintptr_t address,void *out,size_t n){nativeQueries++;if(address!=device+0xc||n!=4)return false;int32_t index=4;memcpy(out,&index,n);return true;}
id invoke(Object o,NSString *function,NSDictionary *args){
 nativeQueries++;equipmentQueries++;
 NSCAssert(args.count==0,@"Only the observed argument-free native getters may be used");
 if(o.address==pc&&[function isEqual:@"GetDrone"])return hasDrone?@{@"object":@4}:NSNull.null;
 if(o.address==device&&[function isEqual:@"IsStrongLightUnlocked"])return @(unlocked);
 NSCAssert(NO,@"No native equipment unlock/setter or unrelated API may be called");return nil;
}
Property property(Object o,NSString *name){
 nativeQueries++;
 NSCAssert(o.address==device&&values[name],@"Only identified local original fields may be inspected");Property p;p.name=name;p.count=1;
 p.type=[name isEqual:@"DroneIsOverHeating"]?@"BoolProperty":@"FloatProperty";p.size=[p.type isEqual:@"BoolProperty"]?1:4;
 p.offset=[name isEqual:@"HeatIncreaseSpeed"]?0x638:[name isEqual:@"Battery"]?0x528:0x63c;p.boolMask=255;if(!rightSchema)p.offset++;return p;
}
id readValue(Object o,const Property &p){nativeQueries++;NSCAssert(o.address==device&&values[p.name],@"Read only the identified equipment");return values[p.name];}
bool writeValue(Object o,const Property &p,id value){
 NSCAssert(o.address==device&&values[p.name],@"No unrelated original object may be changed");writes++;if(writes==failWrite)return false;values[p.name]=value;return true;
}
}
int main(){@autoreleasepool{
 reset();for(int i=0;i<10000;i++)check(![STDefluxorApply(false)[@"active"] boolValue],"Off stays inactive");
 check(nativeQueries==0&&writes==0,"10,000 inactive polls perform zero context, metadata, weak, memory or equipment queries");
 reset();bound=false;check(![STDefluxorApply(true)[@"active"] boolValue]&&writes==0,"Unbound engine never mutates equipment");
 reset();thread=false;check(![STDefluxorApply(true)[@"active"] boolValue]&&writes==0,"No background-thread writes");
 reset();ready=false;check(![STDefluxorApply(true)[@"available"] boolValue]&&writes==0,"No effect outside a valid local run");
 reset();hasDrone=false;check(![STDefluxorApply(true)[@"available"] boolValue]&&writes==0,"Missing equipment is never supplied by the trainer");
 reset();unlocked=false;check(![STDefluxorApply(true)[@"available"] boolValue]&&writes==0&&!unlocked,"A locked Defluxor stays locked");
 reset();rightWorld=false;check(![STDefluxorApply(true)[@"active"] boolValue]&&writes==0,"Another world's equipment cannot be changed");
 reset();rightSchema=false;check(![STDefluxorApply(true)[@"active"] boolValue]&&writes==0,"Changed native metadata rejects before mutation");
 reset();check([STDefluxorApply(true)[@"active"] boolValue],"Active requires native writes and actual readback");
 check([values[@"Battery"] doubleValue]==0&&[values[@"HeatIncreaseSpeed"] doubleValue]==0&&![values[@"DroneIsOverHeating"] boolValue],"Heat is reset to zero, never to the overheat threshold one");
 check([STDefluxorApply(true)[@"active"] boolValue],"Repeated on does not replace the original baseline");
 STDefluxorRelease();check(std::abs([values[@"Battery"] doubleValue]-.8)<1e-6&&std::abs([values[@"HeatIncreaseSpeed"] doubleValue]-.4)<1e-6&&[values[@"DroneIsOverHeating"] boolValue],"Off restores only the captured original heat configuration");
 nativeQueries=0;writes=0;for(int i=0;i<10000;i++)STDefluxorApply(false);
 check(nativeQueries==0&&writes==0,"After real off restoration, subsequent inactive polls have zero native work");
 reset();STDefluxorApply(true);NSUInteger contextsBefore=contextQueries,equipmentBefore=equipmentQueries;ready=false;STDefluxorApply(false);
 check(contextQueries==contextsBefore&&equipmentQueries==equipmentBefore&&[values[@"HeatIncreaseSpeed"] doubleValue]==.4,"The off transition restores its lease without resolving a new player or querying equipment");
 reset();STDefluxorApply(true);values[@"Battery"]=@0.25;STDefluxorRelease();check([values[@"Battery"] doubleValue]==.25,"An intervening game change survives off");
 reset();STDefluxorApply(true);values[@"HeatIncreaseSpeed"]=@0.6;STDefluxorApply(true);STDefluxorRelease();check([values[@"HeatIncreaseSpeed"] doubleValue]==.6,"A later original configuration becomes the new restore baseline");
 reset();STDefluxorApply(true);serial++;NSUInteger before=writes;STDefluxorRelease();check(writes==before,"Expired serials never receive restore writes");
 reset();failWrite=2;check(![STDefluxorApply(true)[@"active"] boolValue]&&[values[@"Battery"] doubleValue]==.8&&[values[@"HeatIncreaseSpeed"] doubleValue]==.4,"A partial rejected change rolls back prior owned writes");
 puts("PASS: Defluxor ownership/readback/restoration and 20,000 off polls with zero native queries/writes; off transition makes no new player/equipment queries. Fixture API only; no game started.");
}}
