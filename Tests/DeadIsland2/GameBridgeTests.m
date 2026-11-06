// SPDX-License-Identifier: GPL-3.0-only
#import "GameBridge.h"
#import "GameAccess.h"
#import "SelectionSettings.h"
#include <limits.h>
#include <math.h>
@interface DI2GameBridge (Testing)
- (instancetype)initWithTestAPI:(DI2GameAPI)api;
- (DI2TrainerState *)update:(NSInteger)command value:(NSNumber *)parameter context:(uint64_t)context;
- (DI2TrainerState *)testUpdate:(DI2TrainerAction)action;
- (DI2TrainerState *)testFeature:(DI2Feature)feature;
- (DI2TrainerState *)testValue:(double)value feature:(DI2Feature)feature;
@end
void DI2TestSelectionSettings(void);
void DI2TestExtraFeatures(void);
void DI2TestOverlayInput(void);
#define COUNT 31
static uint8_t *objects[COUNT]; static BOOL live[COUNT],solo=YES;
static void *currentPlayer,*currentAmmo,*currentSpread,*currentRecoil,*world;
static int classes[COUNT],gods,removes,durabilityAdds,durabilityRemoves,repairs,heals,resets;
static BOOL simulateUnprotectedHit, rejectAmmoSet, rejectAttributeSet;
static int ammoReads, attributeLookups;
static int32_t cash,clip,xp; static float endurance,fury=20,speed=1;
static NSMutableArray *jobs;
static void storePointer(void *owner,size_t offset,void *value) { memcpy((char *)owner+offset,&value,8); }
static void storeFloat(void *owner,size_t offset,float value) { memcpy((char *)owner+offset,&value,4); }
static float readFloat(const void *owner,size_t offset) { float value; memcpy(&value,(const char *)owner+offset,4); return value; }
#define CLASS_FN(name,index) static void *name(void) { return &classes[index]; }
CLASS_FN(playerClass,0) CLASS_FN(inventoryClass,1) CLASS_FN(healthClass,2) CLASS_FN(staminaClass,3)
CLASS_FN(physicalSlotClass,4) CLASS_FN(equippableClass,5) CLASS_FN(rangedClass,6) CLASS_FN(modulesClass,7)
CLASS_FN(clipClass,8) CLASS_FN(meleeClass,10) CLASS_FN(meleeAttributesClass,11) CLASS_FN(attributeClass,12)
CLASS_FN(damageableClass,14) CLASS_FN(furyClass,15) CLASS_FN(throwClass,16) CLASS_FN(progressionClass,17)
CLASS_FN(levelsClass,18) CLASS_FN(spreadClass,19) CLASS_FN(recoilClass,20)
CLASS_FN(controllerType,21) CLASS_FN(localPlayerType,22) CLASS_FN(viewportType,23)
static void *worldViewport(const void *context) { (void)context;return world; }
static void inputUI(void *object,void *widget,uint8_t lock) {
    NSCAssert(object==objects[21] && !widget && lock==0,@"local overlay UI mode");
    ((uint8_t *)world)[0x329]=1;((uint8_t *)world)[0x32a]=0;((uint8_t *)world)[0x32c]=0;
}
static void inputGame(void *object) {
    NSCAssert(object==objects[21],@"restore local input");
    ((uint8_t *)world)[0x329]=0;((uint8_t *)world)[0x32a]=2;((uint8_t *)world)[0x32c]=1;
}
static bool valid(const void *object,bool recursive) { (void)recursive; for(int i=0;i<COUNT;i++) if(objects[i]==object) return live[i]; return false; }
static bool child(void *a,void *b) { return a==b; }
static void *player(const void *context,int index) { (void)context;(void)index; return currentPlayer; }
static void *controller(const void *context,int index) { (void)context;(void)index; return objects[21]; }
static bool standalone(void *context) { (void)context;return solo; }
static void *inventory(const void *context) { (void)context;return objects[1]; }
static void *component(const void *owner,void *class) {
    if(owner==currentPlayer) { if(class==healthClass())return objects[2]; if(class==staminaClass())return objects[3]; if(class==damageableClass())return objects[14]; if(class==throwClass())return objects[16]; }
    if(owner==objects[21]) { if(class==furyClass())return objects[15]; if(class==progressionClass())return objects[17]; }
    if(owner==objects[6] && class==modulesClass())return objects[7];
    if(owner==objects[10] && class==meleeAttributesClass())return objects[11];
    return NULL;
}
static int32_t count(const void *owner,const void *archetype) { (void)owner;(void)archetype;return cash; }
static int32_t addCash(void *owner,int32_t amount) { (void)owner;int32_t added=(int32_t)MIN((int64_t)amount,(int64_t)INT_MAX-cash);cash+=added;return added; }
static int32_t removeCash(void *owner,int32_t amount) { (void)owner;int32_t removed=MIN(cash,amount);cash-=removed;return removed; }
static void name(void *target,const uint16_t *value,int mode) { (void)value;(void)mode;*(uint64_t *)target=123; }
static void addGod(void *owner,uint64_t reason) { (void)owner;NSCAssert(reason==123,@"own reason");gods++; }
static void removeGod(void *owner,uint64_t reason) { (void)owner;(void)reason;removes++; }
static void health(void *owner,float value) { (void)owner;NSCAssert(value==1,@"health fraction");heals++; }
static float stamina(const void *owner) { (void)owner;return endurance; }
static float maximum(const void *owner) { (void)owner;return 100; }
static void setStamina(void *owner,float value) { (void)owner;endurance=value; }
static void weakAssign(DI2WeakObject *weak,const void *object) { *weak=(DI2WeakObject){0,0};for(int i=0;i<COUNT;i++)if(objects[i]==object && live[i])*weak=(DI2WeakObject){i+1,1}; }
static void *weakGet(const DI2WeakObject *weak) { return weak->serial==1 && weak->index>0 && weak->index<=COUNT && live[weak->index-1] ? objects[weak->index-1] : NULL; }
static void heldItem(void *item) { storePointer(objects[5],0xd0,item); }
static void *ammoHandler(const void *owner) { (void)owner;return currentAmmo; }
static int32_t ammo(const void *owner) { (void)owner;ammoReads++;return clip; }
static int32_t capacity(const void *owner) { (void)owner;return 12; }
static void setAmmo(void *owner,int32_t value) { (void)owner;if(!rejectAmmoSet)clip=value; }
static void addDurability(void *owner,uint64_t reason) { (void)owner;(void)reason;durabilityAdds++; uint32_t count=0; memcpy(&count,(char *)owner+0xca8,4);count++;memcpy((char *)owner+0xca8,&count,4); }
static void removeDurability(void *owner,uint64_t reason) { (void)owner;(void)reason;durabilityRemoves++; uint32_t count=0;memcpy(&count,(char *)owner+0xca8,4);NSCAssert(count>0,@"own durability reason exists");count--;memcpy((char *)owner+0xca8,&count,4); }
static void repair(void *owner) { repairs++; storeFloat(owner,0xc20,readFloat(owner,0x1320)); }
static float durabilityLoss(const void *owner) { uint32_t count=0;memcpy(&count,(const char *)owner+0xca8,4);return count && !simulateUnprotectedHit ? 0 : 2.5f; }
static void incoming(void *owner,float value) { storeFloat(owner,0xf0,value); }
static float getSpeed(const void *owner) { (void)owner;return speed; }
static void setSpeed(const void *owner,float value) { (void)owner;speed=value; }
static void *damageAttribute(void *owner) { (void)owner;attributeLookups++;return objects[12]; }
static void *forceAttribute(void *owner) { (void)owner;attributeLookups++;return objects[13]; }
static float getAttribute(const void *owner) { return readFloat(owner,0x50); }
static void setAttribute(void *owner,float value) { if(!rejectAttributeSet)storeFloat(owner,0x50,value); }
static void *spreadHandler(const void *owner) { (void)owner;return currentSpread; }
static void *recoilHandler(const void *owner) { (void)owner;return currentRecoil; }
static void resetCurveballs(void *owner) { (void)owner;resets++; }
static void setInfiniteFury(void *owner,bool value) { ((uint8_t *)owner)[0x214]=value; }
static float getFury(void *owner) { (void)owner;return fury; }
static void addFury(void *owner,float value,void *source) { (void)owner;(void)source;fury=MIN(100,fury+value); }
static int32_t getXP(const void *owner) { (void)owner;return xp; }
static int32_t getLevel(const void *owner) { (void)owner;return MIN(30,xp/1000+1); }
static int32_t maxLevel(const void *owner) { (void)owner;return 30; }
static int32_t xpForLevel(const void *owner,int32_t level) { (void)owner;return (level-1)*1000; }
static void addXP(void *owner,int32_t amount,uint64_t reason) { (void)owner;(void)reason;NSCAssert(amount<=INT_MAX-xp,@"XP does not overflow");xp+=amount; }
static void gameThreadCall(void (^block)(void),NSArray *modes,bool wait) { (void)modes;NSCAssert(!wait,@"async only");[jobs addObject:[block copy]]; }
static void runJob(void) { NSCAssert(jobs.count==1,@"one job in flight");void (^block)(void)=jobs.firstObject;[jobs removeObjectAtIndex:0];block();[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.03]]; }
int main(void) {
 @autoreleasepool {
    DI2TestSelectionSettings();
    DI2GameAPI unsupported;NSCAssert(!DI2LoadGameAPI(&unsupported),@"synthetic host rejects production ABI");
    for(int i=0;i<COUNT;i++) { objects[i]=calloc(1,0x1600);live[i]=YES;storePointer(objects[i],0x10,&classes[i==9 || i==26 ? 8 : i==13 ? 12 : i==24 ? 0 : i==27 ? 19 : i==28 ? 20 : i==29 ? 7 : i==30 ? 23 : i]); }
    world=objects[23];currentPlayer=objects[0];heldItem(objects[6]);currentAmmo=objects[8];currentSpread=objects[19];currentRecoil=objects[20];
    storePointer(objects[1],0x318,objects[6]);storePointer(objects[0],0x15a8,objects[4]);storePointer(objects[24],0x15a8,objects[4]);storePointer(objects[4],0x70,objects[5]);
    storePointer(objects[4],0x20,currentPlayer);storePointer(objects[7],0xd0,objects[6]);storePointer(objects[11],0xd0,objects[10]);
    storePointer(objects[16],0xd0,currentPlayer);
    storePointer(objects[5],0x20,objects[10]); // Deliberately different UObject Outer; Owner remains authoritative.
    for(int i=0;i<COUNT;i++)if(i==8 || i==9 || i==19 || i==20 || i==26 || i==27 || i==28)weakAssign((DI2WeakObject *)(objects[i]+0x98),objects[7]);
    storeFloat(objects[0],0xc8,1.25);storeFloat(objects[14],0xf0,0.8);storeFloat(objects[15],0x158,100);objects[15][0x1e8]=1;
    weakAssign((DI2WeakObject *)(objects[15]+0x15c),objects[22]);weakAssign((DI2WeakObject *)(objects[17]+0x158),objects[22]);storePointer(objects[17],0x120,objects[18]);
    storeFloat(objects[10],0x1320,60);storeFloat(objects[10],0xc20,15);storeFloat(objects[12],0x50,20);storeFloat(objects[13],0x50,15);
    const size_t spread[]={0xc0,0xd8},recoil[]={0xc8,0xe0,0xf8,0x110};
    for(int i=0;i<2;i++){objects[19][spread[i]]=1;storeFloat(objects[19],spread[i]+4,i+1);}
    for(int i=0;i<4;i++){objects[20][recoil[i]]=1;storeFloat(objects[20],recoil[i]+4,i+2);}
    objects[8][0xe0]=1;cash=125;clip=3;endurance=40;xp=125;jobs=[NSMutableArray new];
    DI2GameAPI api={.world=&world,.gameThreadCall=gameThreadCall,.playerCharacter=player,.playerController=controller,.standalone=standalone,.valid=valid,.classIsChildOf=child,
    .playerClass=playerClass,.inventoryClass=inventoryClass,.healthClass=healthClass,.staminaClass=staminaClass,.physicalSlotClass=physicalSlotClass,.equippableClass=equippableClass,.rangedClass=rangedClass,.modulesClass=modulesClass,.clipClass=clipClass,.meleeClass=meleeClass,.meleeAttributesClass=meleeAttributesClass,.attributeClass=attributeClass,.damageableClass=damageableClass,.furyClass=furyClass,.throwClass=throwClass,.progressionClass=progressionClass,.levelsClass=levelsClass,.spreadClass=spreadClass,.recoilClass=recoilClass,
    .component=component,.inventory=inventory,.count=count,.addCash=addCash,.removeCash=removeCash,.name=name,.addGod=addGod,.removeGod=removeGod,.fillHealth=health,.stamina=stamina,.maxStamina=maximum,.setStamina=setStamina,.weakAssign=weakAssign,.weakGet=weakGet,.ammoHandler=ammoHandler,.ammo=ammo,.capacity=capacity,.setAmmo=setAmmo,.addDurability=addDurability,.removeDurability=removeDurability,.repair=repair,.durabilityLoss=durabilityLoss,.setIncomingDamage=incoming,.getGameSpeed=getSpeed,.setGameSpeed=setSpeed,.damageAttribute=damageAttribute,.forceAttribute=forceAttribute,.getAttribute=getAttribute,.setAttribute=setAttribute,.spreadHandler=spreadHandler,.recoilHandler=recoilHandler,.resetCurveballs=resetCurveballs,.setInfiniteFury=setInfiniteFury,.getFury=getFury,.addFury=addFury,.getXP=getXP,.getLevel=getLevel,.maxLevel=maxLevel,.xpForLevel=xpForLevel,.addXP=addXP};
    DI2GameAPI mouseAPI=api;mouseAPI.controllerClass=controllerType;mouseAPI.localPlayerClass=localPlayerType;
    mouseAPI.viewportClass=viewportType;mouseAPI.worldViewport=worldViewport;mouseAPI.inputUIOnly=inputUI;mouseAPI.inputGameOnly=inputGame;
    storePointer(objects[21],0x2d0,objects[22]);objects[21][0x489]=1;
    DI2GameBridge *mouseBridge=[[DI2GameBridge alloc]initWithTestAPI:mouseAPI];
    solo=NO;[mouseBridge poll];[mouseBridge setOverlayInteraction:YES];[mouseBridge setOverlayInteraction:NO];[mouseBridge setOverlayInteraction:YES];
    runJob();runJob();
    NSCAssert(mouseBridge.state.ready && mouseBridge.state.overlayMouseActive && objects[23][0x329]==1,@"mouse UI and trainer remain usable in a network-labelled context; last request wins");
    [mouseBridge setOverlayInteraction:NO];runJob();NSCAssert(!objects[23][0x329] && !mouseBridge.state.overlayMouseActive,@"network status cannot discard mouse release");
    solo=YES;[mouseBridge poll];for(int i=0;i<20;i++)[mouseBridge performAction:DI2TrainerCash1000];
    [mouseBridge setOverlayInteraction:YES];runJob();runJob();NSCAssert(mouseBridge.state.overlayMouseActive,@"UI command takes priority over full cheat queue");
    [mouseBridge setOverlayInteraction:NO];runJob();runJob();NSCAssert(!mouseBridge.state.overlayMouseActive && !objects[23][0x329],@"mouse release survives queue saturation");
    while(jobs.count)runJob();
    DI2GameBridge *bridge=[[DI2GameBridge alloc]initWithTestAPI:api];
    DI2TrainerState *state=[bridge testUpdate:DI2TrainerPoll];NSCAssert(state.ready && state.cash.intValue==125,@"local player inventory");
    [bridge poll];[bridge performAction:DI2TrainerCash1000];[bridge performAction:DI2TrainerCash10000];runJob();runJob();runJob();NSCAssert(cash==11125 && jobs.count==0,@"queued commands exactly once");
    cash=INT_MAX-5;[bridge testUpdate:DI2TrainerCash1000];NSCAssert(cash==INT_MAX,@"cash overflow");
    [bridge testValue:500 feature:DI2FeatureMoney];[bridge testFeature:DI2FeatureMoney];NSCAssert(cash==500,@"target money can decrease");
    [bridge testValue:1200 feature:DI2FeatureMoney];[bridge testFeature:DI2FeatureMoney];NSCAssert(cash==1200,@"target money can increase");
    [bridge testUpdate:DI2TrainerHealth];for(int i=0;i<20;i++)[bridge testUpdate:DI2TrainerPoll];NSCAssert(gods==1 && removes==0,@"one god reason");
    [bridge testUpdate:DI2TrainerHealth];NSCAssert(removes==1,@"own reason removed");
    int beforeHeals=heals;[bridge testFeature:DI2FeatureHealth];[bridge testUpdate:DI2TrainerPoll];NSCAssert(heals==beforeHeals+2 && gods==1,@"health refill independent of god");[bridge testFeature:DI2FeatureHealth];
    [bridge testUpdate:DI2TrainerStamina];NSCAssert(endurance==100 && objects[3][0x19c]==1,@"stamina");[bridge testUpdate:DI2TrainerStamina];NSCAssert(objects[3][0x19c]==0,@"restore stamina");
    [bridge update:300+DI2FeatureStamina value:@YES context:0];
    state=[bridge update:300+DI2FeatureStamina value:@YES context:0];
    NSCAssert(state.features[DI2FeatureStamina].wanted,@"Repeated launcher set-on must not toggle off");
    [bridge update:300+DI2FeatureStamina value:@NO context:0];
    state=[bridge update:300+DI2FeatureStamina value:@NO context:0];
    NSCAssert(!state.features[DI2FeatureStamina].wanted,@"Repeated launcher set-off stays off");
    [bridge testUpdate:DI2TrainerAmmo];NSCAssert(clip==3 && objects[8][0xe1]==0,@"reserve does not alter magazine");
    [bridge testFeature:DI2FeatureNoReload];NSCAssert(clip==12 && objects[8][0xe1]==1,@"separate no-reload");
    currentAmmo=objects[9];[bridge testUpdate:DI2TrainerPoll];NSCAssert(objects[8][0xe0]==1 && objects[8][0xe1]==0 && objects[9][0xe1]==1,@"weapon switch restores each original flag");
    [bridge testFeature:DI2FeatureAccuracy];[bridge testFeature:DI2FeatureNoRecoil];
    for(int i=0;i<2;i++)NSCAssert(!objects[19][spread[i]] && readFloat(objects[19],spread[i]+4)==0,@"zero spread proxy");
    for(int i=0;i<4;i++)NSCAssert(!objects[20][recoil[i]] && readFloat(objects[20],recoil[i]+4)==0,@"zero recoil proxy");
    // Every ranged feature must follow the same physical slot and ownership chain.
    const DI2Feature rangedFeatures[]={DI2FeatureAmmo,DI2FeatureNoReload,DI2FeatureAccuracy,DI2FeatureNoRecoil};
    storePointer(objects[25],0x70,objects[5]);storePointer(objects[0],0x15a8,objects[25]);
    state=[bridge testUpdate:DI2TrainerPoll];
    for(int i=0;i<4;i++)NSCAssert(state.features[rangedFeatures[i]].wanted && !state.features[rangedFeatures[i]].available && !state.features[rangedFeatures[i]].active,@"ranged features reject PaperDoll slot");
    storePointer(objects[0],0x15a8,objects[4]);state=[bridge testUpdate:DI2TrainerPoll];
    for(int i=0;i<4;i++)NSCAssert(state.features[rangedFeatures[i]].active,@"ranged features recover with physical slot");
    storePointer(objects[4],0x20,objects[24]);state=[bridge testUpdate:DI2TrainerPoll];
    for(int i=0;i<4;i++)NSCAssert(!state.features[rangedFeatures[i]].active,@"foreign player's physical slot rejected");
    storePointer(objects[4],0x20,objects[0]);
    storePointer(objects[5],0xd0,NULL); // Its Outer still points at a valid weapon.
    state=[bridge testUpdate:DI2TrainerPoll];
    for(int i=0;i<4;i++)NSCAssert(!state.features[rangedFeatures[i]].available,@"missing Owner never falls back to unrelated UObject Outer");
    heldItem(objects[6]);[bridge testUpdate:DI2TrainerPoll];
    int readsBefore=ammoReads;
    storePointer(objects[7],0xd0,objects[10]);state=[bridge testUpdate:DI2TrainerPoll];
    for(int i=0;i<4;i++)NSCAssert(!state.features[rangedFeatures[i]].active,@"weapon modules owned by another actor rejected");
    NSCAssert(ammoReads==readsBefore,@"native ammo getter not called through a foreign owner");
    storePointer(objects[7],0xd0,objects[6]);[bridge testUpdate:DI2TrainerPoll];
    weakAssign((DI2WeakObject *)(objects[9]+0x98),objects[29]);readsBefore=ammoReads;
    state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(!state.ammoAvailable && !state.features[DI2FeatureNoReload].active && ammoReads==readsBefore,@"stale selected ammo handler must not be dereferenced");
    weakAssign((DI2WeakObject *)(objects[9]+0x98),objects[7]);
    weakAssign((DI2WeakObject *)(objects[19]+0x98),NULL);weakAssign((DI2WeakObject *)(objects[20]+0x98),objects[29]);
    state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(!state.features[DI2FeatureAccuracy].active && !state.features[DI2FeatureNoRecoil].active && state.ammoAvailable,@"spread/recoil weak owners validated independently");
    weakAssign((DI2WeakObject *)(objects[19]+0x98),objects[7]);weakAssign((DI2WeakObject *)(objects[20]+0x98),objects[7]);
    [bridge testUpdate:DI2TrainerPoll];
    // A fire-mode change can switch handlers without switching the weapon actor.
    for(int i=0;i<2;i++){objects[27][spread[i]]=i%2;storeFloat(objects[27],spread[i]+4,i+7);}
    for(int i=0;i<4;i++){objects[28][recoil[i]]=(i+1)%2;storeFloat(objects[28],recoil[i]+4,i+10);}
    currentAmmo=objects[26];currentSpread=objects[27];currentRecoil=objects[28];
    state=[bridge testUpdate:DI2TrainerPoll];
    for(int i=0;i<4;i++)NSCAssert(state.features[rangedFeatures[i]].active,@"new fire-mode handlers applied");
    NSCAssert(!objects[9][0xe0] && !objects[9][0xe1] && objects[26][0xe0] && objects[26][0xe1],@"ammo switch restores old handler before touching new");
    for(int i=0;i<2;i++)NSCAssert(objects[19][spread[i]]==1 && readFloat(objects[19],spread[i]+4)==i+1 && !objects[27][spread[i]],@"old spread configuration preserved");
    for(int i=0;i<4;i++)NSCAssert(objects[20][recoil[i]]==1 && readFloat(objects[20],recoil[i]+4)==i+2 && !objects[28][recoil[i]],@"old recoil configuration preserved");
    clip=2;rejectAmmoSet=YES;state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(!state.features[DI2FeatureNoReload].active && state.features[DI2FeatureNoReload].wanted,@"failed magazine refill cannot pretend active");
    rejectAmmoSet=NO;state=[bridge testUpdate:DI2TrainerPoll];NSCAssert(state.features[DI2FeatureNoReload].active && clip==12,@"refill recovers when handler accepts it");
    live[7]=NO;readsBefore=ammoReads;state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(!state.ammoAvailable && ammoReads==readsBefore,@"destroyed owning modules never dereferenced by native getters");
    live[7]=YES;[bridge testUpdate:DI2TrainerPoll];
    [bridge testUpdate:DI2TrainerDisableAll];
    NSCAssert(!objects[26][0xe0] && !objects[26][0xe1],@"last ammo handler restored");
    for(int i=0;i<2;i++)NSCAssert(objects[27][spread[i]]==i%2 && readFloat(objects[27],spread[i]+4)==i+7,@"restore mixed constant/attribute spread proxies");
    for(int i=0;i<4;i++)NSCAssert(objects[28][recoil[i]]==(i+1)%2 && readFloat(objects[28],recoil[i]+4)==i+10,@"restore mixed recoil proxies");
    currentAmmo=objects[9];currentSpread=objects[19];currentRecoil=objects[20];
    for(int i=0;i<2;i++)NSCAssert(objects[19][spread[i]] && readFloat(objects[19],spread[i]+4)==i+1,@"restore spread proxy");
    for(int i=0;i<4;i++)NSCAssert(objects[20][recoil[i]] && readFloat(objects[20],recoil[i]+4)==i+2,@"restore recoil proxy");
    NSCAssert(!objects[9][0xe0] && !objects[9][0xe1],@"restore current ammo");
    [bridge testFeature:DI2FeatureDurability];state=[bridge testUpdate:DI2TrainerPoll];NSCAssert(state.features[DI2FeatureDurability].wanted && !state.features[DI2FeatureDurability].active,@"wait for melee");
    heldItem(objects[10]);[bridge testUpdate:DI2TrainerPoll];[bridge testUpdate:DI2TrainerPoll];NSCAssert(durabilityAdds==1 && repairs==1 && durabilityLoss(objects[10])==0 && readFloat(objects[10],0xc20)==60,@"physical slot + component owner detects melee despite unrelated Outer, repairs once and blocks native per-hit loss");
    NSCAssert(state.features.count==26,@"all feature states retained");
    storePointer(objects[25],0x70,objects[5]);storePointer(objects[0],0x15a8,objects[25]);
    state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(!state.features[DI2FeatureDurability].available && !state.features[DI2FeatureDurability].active && durabilityLoss(objects[10])>0,@"inventory PaperDoll slot must not impersonate UPhysicalSlot and previous weapon is restored");
    storePointer(objects[0],0x15a8,objects[4]);state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(state.features[DI2FeatureDurability].active && durabilityAdds==2 && repairs==2,@"physical slot recognition resumes after a slot transition");
    simulateUnprotectedHit=YES;state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(state.features[DI2FeatureDurability].wanted && !state.features[DI2FeatureDurability].active,@"a native positive loss must never be reported as protected");
    simulateUnprotectedHit=NO;state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(state.features[DI2FeatureDurability].active && durabilityAdds==2,@"readback does not repeatedly register reasons");
    [bridge testFeature:DI2FeatureDamageMultiplier];NSCAssert(getAttribute(objects[12])==40,@"damage factor");
    [bridge testFeature:DI2FeatureOneHit];NSCAssert(getAttribute(objects[12])==2000000,@"one-hit priority");
    [bridge testFeature:DI2FeatureOneHit];NSCAssert(getAttribute(objects[12])==40,@"one-hit off preserves factor");
    [bridge testFeature:DI2FeatureForceMultiplier];[bridge testFeature:DI2FeatureSuperForce];NSCAssert(getAttribute(objects[13])==1500000,@"force priority");
    // The same slot regression must cover every melee-dependent feature.
    [bridge testFeature:DI2FeatureOneHit];
    const DI2Feature meleeFeatures[]={DI2FeatureDurability,DI2FeatureDamageMultiplier,DI2FeatureOneHit,DI2FeatureForceMultiplier,DI2FeatureSuperForce};
    int lookupsBefore=attributeLookups;
    storePointer(objects[0],0x15a8,objects[25]);state=[bridge testUpdate:DI2TrainerPoll];
    for(int i=0;i<5;i++)NSCAssert(state.features[meleeFeatures[i]].wanted && !state.features[meleeFeatures[i]].available && !state.features[meleeFeatures[i]].active,@"all melee features reject inventory slot");
    NSCAssert(attributeLookups==lookupsBefore && getAttribute(objects[12])==20 && getAttribute(objects[13])==15,@"wrong slot restores attributes without querying foreign weapon");
    storePointer(objects[0],0x15a8,objects[4]);state=[bridge testUpdate:DI2TrainerPoll];
    for(int i=0;i<5;i++)NSCAssert(state.features[meleeFeatures[i]].active,@"all melee features recover on held weapon");
    lookupsBefore=attributeLookups;storePointer(objects[11],0xd0,objects[6]);state=[bridge testUpdate:DI2TrainerPoll];
    for(int i=1;i<5;i++)NSCAssert(!state.features[meleeFeatures[i]].active,@"foreign attribute component rejected");
    NSCAssert(attributeLookups==lookupsBefore && state.features[DI2FeatureDurability].active,@"durability independent of mismatched attributes");
    storePointer(objects[11],0xd0,objects[10]);rejectAttributeSet=YES;state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(!state.features[DI2FeatureOneHit].active && !state.features[DI2FeatureSuperForce].active,@"rejected attribute writes never pretend effective");
    rejectAttributeSet=NO;state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(state.features[DI2FeatureOneHit].active && state.features[DI2FeatureSuperForce].active,@"attribute readback recovers");
    [bridge testFeature:DI2FeatureOneHit];
    heldItem(objects[6]);[bridge testUpdate:DI2TrainerPoll];NSCAssert(getAttribute(objects[12])==20 && getAttribute(objects[13])==15 && durabilityRemoves==3,@"weapon switch restores attributes and durability");
    [bridge testFeature:DI2FeaturePlayerSpeed];[bridge testFeature:DI2FeatureGameSpeed];[bridge testFeature:DI2FeatureDefenseMultiplier];
    NSCAssert(readFloat(objects[0],0xc8)==2.5 && speed==1.5 && fabs(readFloat(objects[14],0xf0)-0.4)<0.0001,@"speed + defense");
    state=[bridge testValue:NAN feature:DI2FeaturePlayerSpeed];NSCAssert(state.features[DI2FeaturePlayerSpeed].value==2,@"reject NaN");
    [bridge testFeature:DI2FeatureCurveball];NSCAssert(resets==1,@"curveball cooldown");
    int resetsBefore=resets;storePointer(objects[16],0xd0,objects[24]);state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(resets==resetsBefore && !state.features[DI2FeatureCurveball].active,@"foreign Curveball component is never reset");
    storePointer(objects[16],0xd0,currentPlayer);state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(resets==resetsBefore+1 && state.features[DI2FeatureCurveball].active,@"local Curveball owner recovers independently of main-hand weapon");
    [bridge testFeature:DI2FeatureFullFury];NSCAssert(fury==100,@"max fury");
    [bridge testFeature:DI2FeatureInfiniteFury];NSCAssert(objects[15][0x214]==1,@"native infinite fury");
    [bridge testFeature:DI2FeatureXPMultiplier];xp+=100;[bridge testUpdate:DI2TrainerPoll];NSCAssert(xp==325,@"XP bonus");[bridge testUpdate:DI2TrainerPoll];NSCAssert(xp==325,@"own XP never multiplied again");
    [bridge testFeature:DI2FeatureMaxXP];NSCAssert(xp==29000 && getLevel(NULL)==30,@"max XP uses regular threshold");[bridge testUpdate:DI2TrainerPoll];NSCAssert(xp==29000,@"max-XP not multiplied");
    const DI2Feature extraKinds[]={DI2FeatureStealth,DI2FeatureMovementSpeed,DI2FeatureConsumables,DI2FeatureItems,DI2FeatureCrafting};
    for(int i=0;i<5;i++){state=[bridge testFeature:extraKinds[i]];NSCAssert(state.features[extraKinds[i]].wanted && !state.features[extraKinds[i]].active,@"missing native context remains waiting");}
    [bridge testFeature:DI2FeatureGod];[bridge testFeature:DI2FeatureStamina];
    [bridge testFeature:DI2FeatureAmmo];state=[bridge testValue:3 feature:DI2FeaturePlayerSpeed];
    BOOL selected[DI2FeatureCount];
    for(NSInteger i=0;i<DI2FeatureCount;i++)selected[i]=state.features[i].wanted;
    uint64_t beforeTravel=state.context;
    currentPlayer=NULL;state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(!state.ready && state.context!=beforeTravel && speed==1 && readFloat(objects[0],0xc8)==1.25
        && objects[3][0x19c]==0 && !objects[15][0x214],@"loading releases effects without a local pawn");
    uint64_t loadingContext=state.context;int travelRemoves=removes;
    for(NSInteger i=0;i<DI2FeatureCount;i++)NSCAssert(state.features[i].wanted==selected[i] && !state.features[i].active,@"all selected cheats wait during travel");
    state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(state.context==loadingContext && removes==travelRemoves,@"repeated loading polls do not reset context or restore twice");
    world=NULL;state=[bridge testUpdate:DI2TrainerPoll];loadingContext=state.context;
    state=[bridge testUpdate:DI2TrainerPoll];NSCAssert(state.context==loadingContext && !state.ready,@"missing world is a stable loading pause");
    world=objects[30];currentPlayer=objects[24];storeFloat(currentPlayer,0xc8,1.75);
    storePointer(objects[4],0x20,currentPlayer);storePointer(objects[16],0xd0,currentPlayer);
    xp=5000;state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(state.ready && state.features[DI2FeatureGod].active && state.features[DI2FeatureAmmo].active
        && state.features[DI2FeatureStamina].active && speed==1.5 && readFloat(currentPlayer,0xc8)==5.25
        && state.features[DI2FeaturePlayerSpeed].value==3
        && objects[15][0x214] && xp==5000,@"new solo world and pawn reapply choices with fresh originals and XP baseline");
    for(NSInteger i=0;i<DI2FeatureCount;i++)NSCAssert(state.features[i].wanted==selected[i],@"travel preserves every toggle selection");
    xp+=10;[bridge testUpdate:DI2TrainerPoll];NSCAssert(xp==5020,@"XP multiplier resumes for new gains only");
    [bridge testUpdate:DI2TrainerPoll];NSCAssert(xp==5020 && readFloat(currentPlayer,0xc8)==5.25,@"reapplied factors and XP do not compound");
    // A direct replacement can happen between polls without an observable gap.
    currentPlayer=objects[0];storePointer(objects[4],0x20,currentPlayer);storePointer(objects[16],0xd0,currentPlayer);
    state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(state.features[DI2FeatureGod].active && readFloat(objects[24],0xc8)==1.75
        && readFloat(currentPlayer,0xc8)==3.75,@"direct pawn replacement preserves choices and restores outgoing pawn");
    [bridge poll];runJob();[bridge poll];
    [bridge performAction:DI2TrainerCash1000];[bridge performFeature:DI2FeatureMaxXP];[bridge performFeature:DI2FeatureFullFury];
    world=objects[23];int32_t travelCash=cash;xp=6000;fury=20;
    while(jobs.count)runJob();
    NSCAssert(bridge.state.ready && bridge.state.features[DI2FeatureGod].active && cash==travelCash && xp==6000 && fury==20,
        @"world-only travel resumes toggles but discards stale queued money, XP and fury actions");
    solo=NO;int32_t moneyBefore=cash;state=[bridge testUpdate:DI2TrainerCash1000];
    NSCAssert(state.ready && cash==moneyBefore && state.features[DI2FeatureGod].active,@"mode change preserves effects but rejects the stale one-shot");
    for(NSInteger i=0;i<DI2FeatureCount;i++)NSCAssert(state.features[i].wanted==selected[i],@"network status preserves every feature request");
    solo=YES;state=[bridge testUpdate:DI2TrainerPoll];NSCAssert(state.ready && state.features[DI2FeatureGod].wanted,@"mode changes preserve choices");
    [bridge testUpdate:DI2TrainerHealth];[bridge poll];runJob();[bridge poll];
    for(int i=0;i<20;i++)[bridge performAction:DI2TrainerCash1000];
    [bridge performAction:DI2TrainerDisableAll];currentPlayer=NULL;while(jobs.count)runJob();
    NSCAssert(!bridge.state.ready && !bridge.state.features[DI2FeatureGod].wanted && cash==moneyBefore,@"F12 survives full queue and loading; queued one-shots are dropped");
    currentPlayer=objects[0];state=[bridge testUpdate:DI2TrainerPoll];NSCAssert(!state.features[DI2FeatureGod].active,@"F12 during travel prevents automatic reactivation");
    [bridge poll];runJob();[bridge poll];[bridge performFeature:DI2FeatureGod];[bridge performAction:DI2TrainerCash1000];
    [bridge performAction:DI2TrainerDisableAll];while(jobs.count)runJob();
    NSCAssert(!bridge.state.features[DI2FeatureGod].wanted && cash==moneyBefore,@"F12 also cancels older queued toggles and one-shots in solo");
    [bridge testFeature:DI2FeatureStamina];currentPlayer=NULL;[bridge testUpdate:DI2TrainerPoll];
    solo=NO;currentPlayer=objects[0];state=[bridge testUpdate:DI2TrainerPoll];
    NSCAssert(state.ready && state.features[DI2FeatureStamina].wanted && objects[3][0x19c]==1,@"loading into a network-labelled context reapplies the local selection");
    solo=YES;[bridge testUpdate:DI2TrainerPoll];
    [bridge testUpdate:DI2TrainerHealth];currentPlayer=NULL;state=[bridge testUpdate:DI2TrainerDisableAll];
    NSCAssert(!state.features[DI2FeatureGod].wanted,@"F12 works on the same update that detects a loading transition");
    currentPlayer=objects[0];[bridge testUpdate:DI2TrainerPoll];[bridge testUpdate:DI2TrainerHealth];live[2]=NO;int removedBefore=removes;[bridge testUpdate:DI2TrainerDisableAll];NSCAssert(removes==removedBefore,@"dead weak owner never dereferenced");
    // Simulate a fresh launch: restore intent, never a queued native action.
    live[2]=YES;solo=YES;world=objects[23];currentPlayer=NULL;
    DI2GameBridge *restored=[[DI2GameBridge alloc]initWithTestAPI:api];
    NSDictionary *saved=@{@"features":@{@"0":@{@"wanted":@YES},@"5":@{@"wanted":@YES,@"value":@3},
        @"13":@{@"wanted":@YES,@"value":@42},@"22":@{@"wanted":@YES},@"24":@{@"wanted":@YES}}};
    int oldGods=gods;int32_t oldCash=cash,oldXP=xp;float oldFury=fury;
    [restored restoreSelection:saved];
    NSCAssert(gods==oldGods && !restored.state.features[0].active && restored.state.features[0].wanted,@"restore intent performs no native call");
    state=[restored testUpdate:DI2TrainerPoll];
    NSCAssert(!state.ready && !state.selectionCanBeSaved && state.features[0].wanted,@"initial loading retains saved intent without overwriting preferences");
    currentPlayer=objects[0];state=[restored testUpdate:DI2TrainerPoll];
    NSCAssert(state.ready && state.selectionCanBeSaved && state.features[0].active && state.features[5].active
        && state.features[5].value==3 && gods==oldGods+1,@"selection applies only after validated solo context");
    NSCAssert(cash==oldCash && xp==oldXP && fury==oldFury,@"restored money/XP/fury actions never execute");
    solo=NO;state=[restored testUpdate:DI2TrainerPoll];
    NSCAssert(state.selectionCanBeSaved && state.features[0].wanted && state.features[0].active,@"network status retains the saved selection");
    solo=YES;state=[restored testUpdate:DI2TrainerPoll];
    NSCAssert(state.features[0].active && state.features[5].wanted,@"selection remains active across mode changes");
    currentPlayer=NULL;
    DI2GameBridge *stopped=[[DI2GameBridge alloc]initWithTestAPI:api];[stopped restoreSelection:saved];
    state=[stopped testUpdate:DI2TrainerDisableAll];
    NSCAssert(!state.features[0].wanted && state.selectionCanBeSaved,@"explicit all-off while loading persists immediately");
    DI2GameBridge *next=[[DI2GameBridge alloc]initWithTestAPI:api];[next restoreSelection:DI2SelectionFromState(state)];
    currentPlayer=objects[0];state=[next testUpdate:DI2TrainerPoll];
    NSCAssert(!state.features[0].wanted && !state.features[0].active,@"next launch respects saved all-off");
    DI2GameBridge *disabled=[[DI2GameBridge alloc]initWithTestAPI:api];[disabled restoreSelection:nil];
    state=[disabled testUpdate:DI2TrainerPoll];
    for(DI2FeatureState *feature in state.features) NSCAssert(!feature.wanted,@"restore option off starts with no cheat requests");
    puts("Selection startup checks passed: loading/solo restore, no one-shots, network continuity, all-off during loading and disabled restore.");
    uint8_t byte;NSCAssert(!DI2ReadMemory((void *)1,&byte,1) && !DI2WriteByte((void *)1,0,1) && !DI2WriteFloat((void *)1,0,1),@"unmapped pages rejected");
    for(int i=0;i<COUNT;i++)free(objects[i]);
    DI2TestExtraFeatures();
    DI2TestOverlayInput();
    puts("Synthetic bridge checks passed: 26 feature bindings, travel persistence, fresh owners/XP baselines, stale action rejection, F12 during loading, restoration, independent controls, numeric limits, queue and local owner gates.");
 }return 0;
}
