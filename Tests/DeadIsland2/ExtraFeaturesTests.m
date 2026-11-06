// SPDX-License-Identifier: GPL-3.0-only
#import "ExtraFeatures.h"
#include <math.h>

enum { Player, Controller, Inventory, AI, PlayerState, Movement, Definition,
    MaterialCategory, AmmoCategory, QuestCategory, UnknownCategory,
    MaterialContainer, AmmoContainer, QuestContainer, UnknownContainer,
    Material, Ammo, Quest, Unknown, Medkit, Weapon,
    MaterialActor, AmmoActor, QuestActor, UnknownActor, MedkitActor, WeaponActor,
    Ingredients0, Ingredients1, Ingredients2, Recipe0, Recipe1, Recipe2, ExtraCount };
enum { TypeAI, TypeState, TypeMovement, TypeDefinition, TypeCategory, TypeContainer,
    TypeArchetype, TypeActor, TypeIngredients, TypeRecipe, TypeCount };
static uint8_t *obj[ExtraCount]; static BOOL live[ExtraCount]; static int serial[ExtraCount],types[TypeCount];
static NSString *names[ExtraCount]; static int32_t counts[ExtraCount];
static uint8_t ignoreMap[0x50],mapEntry[16],table[3][0x258];
static void *containers[4],*assets[3]; static uint8_t slots[4][120],ingredientEntries[3][32];
static float movementBase,modifierValue; static BOOL modifierPresent,rejectMovement,rejectRefill;
static int guidCounter,additions,freedArrays,aiCalls,removeModifiers;
static void put(void *p,size_t o,const void *v,size_t n) { memcpy((char *)p+o,v,n); }
static void ptr(void *p,size_t o,void *v) { put(p,o,&v,8); }
static void integer(void *p,size_t o,int32_t v) { put(p,o,&v,4); }
static int32_t integerAt(void *p,size_t o) { int32_t v=0;memcpy(&v,(char *)p+o,4);return v; }
static void arr(void *p,size_t o,void *data,int32_t n) { DI2Array a={data,n,n};put(p,o,&a,sizeof(a)); }
static int indexOf(const void *p) { for(int i=0;i<ExtraCount;i++)if(obj[i]==p)return i;return -1; }
#define TYPE_FN(fn,t) static void *fn(void) { return &types[t]; }
TYPE_FN(aiClass,TypeAI) TYPE_FN(stateClass,TypeState) TYPE_FN(movementClass,TypeMovement)
TYPE_FN(definitionClass,TypeDefinition) TYPE_FN(categoryClass,TypeCategory) TYPE_FN(containerClass,TypeContainer)
TYPE_FN(archetypeClass,TypeArchetype) TYPE_FN(actorClass,TypeActor)
TYPE_FN(ingredientsClass,TypeIngredients) TYPE_FN(recipeClass,TypeRecipe)
static bool valid(const void *p,bool recurse) { (void)recurse;int i=indexOf(p);return i>=0 && live[i]; }
static bool child(void *a,void *b) { return a==b; }
static void assign(DI2WeakObject *weak,const void *p) { int i=indexOf(p);*weak=(DI2WeakObject){i+1,i>=0 ? serial[i] : 0}; }
static void *resolve(const DI2WeakObject *weak) { int i=weak->index-1;return i>=0 && i<ExtraCount && live[i] && weak->serial==serial[i] ? obj[i] : NULL; }
static void *manager(void *p) { NSCAssert(p==obj[Player],@"local player");return obj[AI]; }
static void updateAI(void *p) { NSCAssert(p==obj[AI],@"manager"); }
static void ignorePlayer(void *p,const DI2Array *arguments) {
    NSCAssert(p==obj[AI] && arguments->num==2,@"native command shape");
    const DI2Array *strings=arguments->data;
    NSString *identifier=[[NSString alloc]initWithCharacters:strings[0].data length:strings[0].num-1];
    NSCAssert(identifier.intValue==42,@"only local player ID");
    uint16_t *flag=strings[1].data;mapEntry[4]=flag[0]=='1';aiCalls++;
}
static void name(void *out,const uint16_t *text,int mode) { (void)text;(void)mode;*(uint64_t *)out=123; }
static bool current(const void *c,const void *d,float *out) {
    NSCAssert(c==obj[Movement] && d==obj[Definition],@"local movement definition");
    uint8_t op=obj[Definition][0x40];
    *out=modifierPresent ? (op==0 ? movementBase+modifierValue : movementBase*modifierValue) : movementBase;
    return true;
}
static DI2Guid addModifier(void *c,const void *d,uint64_t reason,float value,int32_t policy,float duration,bool recalc) {
    (void)c;(void)d;NSCAssert(reason==123 && policy==1 && duration==0 && recalc,@"own permanent modifier");
    if(rejectMovement)return (DI2Guid){0,0};
    NSCAssert(!modifierPresent,@"no duplicate modifiers");modifierPresent=YES;modifierValue=value;
    return (DI2Guid){(uint64_t)++guidCounter,1};
}
static void removeModifier(void *c,DI2Guid guid,float delay) {
    NSCAssert(c==obj[Movement] && guid.low>0 && delay==0,@"remove own GUID");
    modifierPresent=NO;removeModifiers++;
}
static void updateModifier(void *c,const void *d,DI2Guid guid,float value) {
    (void)c;(void)d;NSCAssert(modifierPresent && guid.low>0,@"update existing GUID");modifierValue=value;
}
static int32_t nameString(const void *name,uint16_t *out,uint32_t capacity) {
    uint64_t key=*(const uint64_t *)name;NSString *value=key>0 && key<=ExtraCount ? names[key-1] : @"";
    NSCAssert(value.length+1<capacity,@"bounded name");[value getCharacters:out range:NSMakeRange(0,value.length)];out[value.length]=0;
    return (int32_t)value.length;
}
static int32_t count(const void *owner,const void *archetype) { NSCAssert(owner==obj[Inventory],@"local inventory");int i=indexOf(archetype);return i>=0 ? counts[i] : 0; }
static bool addItem(void *owner,const void *archetype,int32_t amount,bool notify) {
    int i=indexOf(archetype);BOOL fuse=i==Unknown && [names[Unknown] isEqualToString:@"DA_InventoryTypes_KeyItems_Fuse"];
    NSCAssert(owner==obj[Inventory] && (i==Material || i==Ammo || i==Medkit || fuse) && amount>0 && !notify,@"ordinary stacks only");
    if(rejectRefill)return false;counts[i]+=amount;additions++;return true;
}
static int32_t zeroCost(const void *self,const void *context) { (void)self;(void)context;return 0; }
static int32_t originalCost(const void *self,const void *context) { (void)self;(void)context;return 125; }
static int32_t cashCost(int which) {
    void *vtable=NULL;memcpy(&vtable,obj[Ingredients0+which],8);
    int32_t (*fn)(const void *,const void *)=NULL;memcpy(&fn,(char *)vtable+0x240,8);
    return fn(obj[Ingredients0+which],NULL);
}
static void objectsOfClass(const void *class,DI2Array *array,bool derived,uint32_t excluded,uint32_t internal) {
    NSCAssert(class==recipeClass() && derived && excluded==0x30 && internal==0,@"loaded recipe enumeration excludes CDO/archetypes");
    array->data=malloc(sizeof(assets));memcpy(array->data,assets,sizeof(assets));array->num=3;array->capacity=3;
}
static void freeMemory(void *p) { free(p);freedArrays++; }
static void setType(int index,int type) { ptr(obj[index],0x10,&types[type]); }

void DI2TestExtraFeatures(void) {
    for(int i=0;i<ExtraCount;i++) {
        obj[i]=calloc(1,0x1600);live[i]=YES;serial[i]=1;names[i]=@"";
        uint64_t key=(uint64_t)i+1;put(obj[i],0x18,&key,8);
    }
    setType(AI,TypeAI);setType(PlayerState,TypeState);setType(Movement,TypeMovement);setType(Definition,TypeDefinition);
    ptr(obj[Controller],0x260,obj[PlayerState]);integer(obj[PlayerState],0x25c,42);
    ptr(ignoreMap,0,mapEntry);integer(ignoreMap,8,1);integer(ignoreMap,0x38,0);integer(ignoreMap,0x48,1);
    integer(mapEntry,0,42);integer(mapEntry,8,-1);
    ptr(obj[Player],0x780,obj[Movement]);ptr(obj[Player],0xd68,obj[Definition]);ptr(obj[Movement],0xd0,obj[Player]);
    movementBase=1.25;obj[Definition][0x40]=3;
    NSString *groupNames[]={@"Inventory_Ingredients",@"Inventory_Ammo",@"Inventory_Quest",@"Unknown"};
    for(int i=0;i<4;i++) {
        int group=MaterialCategory+i,container=MaterialContainer+i;
        setType(group,TypeCategory);names[group]=groupNames[i];setType(container,TypeContainer);
        containers[i]=obj[container];ptr(obj[container],0x28,obj[group]);ptr(obj[container],0x38,obj[Inventory]);
        arr(obj[container],0x1a0,slots[i],i==0 ? 3 : 1);
    }
    arr(obj[Inventory],0x120,containers,4);
    NSString *itemNames[]={@"DA_Resource_Scrap",@"DA_Ammo_Pistol",@"DA_Quest_Medicine",@"DA_Unknown",@"DA_Medkit",@"DA_MeleeWeapon"};
    for(int i=0;i<6;i++) {
        int archetype=Material+i,actor=MaterialActor+i,group=i<4 ? i : 0;
        setType(archetype,TypeArchetype);setType(actor,TypeActor);names[archetype]=itemNames[i];counts[archetype]=10;
        ptr(obj[archetype],0x78,obj[MaterialCategory+group]);integer(obj[archetype],0x80,i==5 ? 1 : 99);
        ptr(obj[actor],0x370,obj[archetype]);
        if(i<4)ptr(slots[group],0x10,obj[actor]);else ptr(slots[0],(size_t)(i-3)*40+0x10,obj[actor]);
    }
    names[MaterialCategory]=@"DA_GenericCategory";names[Player]=@"Ingredients";
    uint64_t categoryName=Player+1;put(obj[MaterialCategory],0x30,&categoryName,8);
    for(int i=0;i<3;i++) {
        setType(Ingredients0+i,TypeIngredients);setType(Recipe0+i,TypeRecipe);
        assets[i]=obj[Recipe0+i];ptr(obj[Recipe0+i],0x38,obj[Ingredients0+i]);
        void *fn=(void *)originalCost;ptr(table[i],16+0x240,fn);ptr(obj[Ingredients0+i],0,table[i]+16);
        ptr(ingredientEntries[i],0,obj[Material]);integer(ingredientEntries[i],8,5+i);
        ptr(ingredientEntries[i],16,obj[Medkit]);integer(ingredientEntries[i],24,2);
        arr(obj[Ingredients0+i],0x28,ingredientEntries[i],2);
    }
    DI2GameAPI api={.valid=valid,.classIsChildOf=child,.weakAssign=assign,.weakGet=resolve,.name=name,
        .ignorePlayers=ignoreMap,.aiManager=manager,.aiManagerClass=aiClass,.playerStateClass=stateClass,
        .updateIgnorePlayers=updateAI,.setIgnorePlayer=ignorePlayer,.modifiableClass=movementClass,.movementDefinitionClass=definitionClass,
        .currentMovementValue=current,.addMovementModifier=addModifier,.removeMovementModifier=removeModifier,.updateMovementModifier=updateModifier,
        .containerClass=containerClass,.categoryClass=categoryClass,.itemActorClass=actorClass,.archetypeClass=archetypeClass,
        .nameString=nameString,.addItem=addItem,.count=count,.recipeClass=recipeClass,.ingredientsClass=ingredientsClass,
        .objectsOfClass=objectsOfClass,.freeMemory=freeMemory,.zeroCraftingCost=zeroCost,
        .ingredientVTables={table[0]+16,table[1]+16,table[2]+16}};
    DI2ExtraFeatures *service=[[DI2ExtraFeatures alloc]initWithAPI:api];
    BOOL wanted[DI2FeatureCount]={0},available[DI2FeatureCount]={0},active[DI2FeatureCount]={0};double values[DI2FeatureCount]={0};
    NSMutableArray *states=[NSMutableArray new];for(int i=0;i<DI2FeatureCount;i++)[states addObject:[DI2FeatureState new]];
#define UPDATE() [service updatePlayer:obj[Player] controller:obj[Controller] inventory:obj[Inventory] wanted:wanted values:values available:available active:active states:states]
    wanted[DI2FeatureStealth]=YES;UPDATE();NSCAssert(active[DI2FeatureStealth] && mapEntry[4] && aiCalls==1,@"local AI ignore readback");
    UPDATE();NSCAssert(aiCalls==1,@"no duplicate AI command");
    wanted[DI2FeatureStealth]=NO;UPDATE();NSCAssert(!mapEntry[4],@"restore AI flag");
    mapEntry[4]=1;wanted[DI2FeatureStealth]=YES;UPDATE();[service reset];NSCAssert(mapEntry[4],@"preserve pre-existing AI ignore");
    mapEntry[4]=0;integer(mapEntry,0,7);integer(mapEntry,8,0);UPDATE();NSCAssert(!active[DI2FeatureStealth],@"cyclic malformed hash chain bounded");
    integer(mapEntry,0,42);integer(mapEntry,8,-1);wanted[DI2FeatureStealth]=NO;
    wanted[DI2FeatureMovementSpeed]=YES;values[DI2FeatureMovementSpeed]=2;UPDATE();
    float movement=0;current(obj[Movement],obj[Definition],&movement);NSCAssert(active[DI2FeatureMovementSpeed] && movement==2.5,@"separate movement factor");
    values[DI2FeatureMovementSpeed]=0.5;UPDATE();current(obj[Movement],obj[Definition],&movement);NSCAssert(movement==0.625 && guidCounter==1,@"edit existing GUID");
    movementBase=2;UPDATE();current(obj[Movement],obj[Definition],&movement);NSCAssert(movement==1,@"native external movement modifier retained");
    wanted[DI2FeatureMovementSpeed]=NO;UPDATE();NSCAssert(!modifierPresent && movementBase==2,@"remove own modifier only");
    obj[Definition][0x40]=0;wanted[DI2FeatureMovementSpeed]=YES;values[DI2FeatureMovementSpeed]=2;UPDATE();
    current(obj[Movement],obj[Definition],&movement);NSCAssert(movement==4,@"additive definition adapts");
    movementBase=3;UPDATE();current(obj[Movement],obj[Definition],&movement);NSCAssert(movement==6,@"no multiplier feedback in additive mode");
    ptr(obj[Movement],0xd0,obj[Controller]);UPDATE();NSCAssert(!active[DI2FeatureMovementSpeed] && !modifierPresent,@"foreign component restores movement");
    ptr(obj[Movement],0xd0,obj[Player]);rejectMovement=YES;UPDATE();NSCAssert(!active[DI2FeatureMovementSpeed],@"native rejection never green");rejectMovement=NO;
    wanted[DI2FeatureMovementSpeed]=NO;UPDATE();
    wanted[DI2FeatureConsumables]=YES;UPDATE();NSCAssert(active[DI2FeatureConsumables],@"ordinary material stacks captured");
    counts[Material]=0;counts[Medkit]=4;counts[Ammo]=2;counts[Quest]=0;counts[Unknown]=0;counts[Weapon]=0;UPDATE();
    NSCAssert(counts[Material]==10 && counts[Medkit]==10 && counts[Ammo]==2 && counts[Quest]==0 && counts[Unknown]==0 && counts[Weapon]==0,@"category FName resolves ingredients; ammo, weapons and quest/unknown categories excluded");
    wanted[DI2FeatureItems]=YES;UPDATE();counts[Material]=3;counts[Ammo]=0;int before=additions;UPDATE();
    NSCAssert(active[DI2FeatureItems] && counts[Material]==10 && counts[Ammo]==2 && additions==before+2,@"overlapping controls refill once per archetype");
    counts[Material]=25;UPDATE();counts[Material]=1;UPDATE();NSCAssert(counts[Material]==25,@"pickups raise floor");
    wanted[DI2FeatureItems]=NO;UPDATE();counts[Ammo]=0;UPDATE();NSCAssert(counts[Ammo]==0,@"disabling items drops ammo floor");
    rejectRefill=YES;counts[Medkit]=0;UPDATE();NSCAssert(!active[DI2FeatureConsumables],@"failed readback stays orange");rejectRefill=NO;
    ptr(obj[MaterialContainer],0x38,obj[Controller]);UPDATE();NSCAssert(!active[DI2FeatureConsumables] && counts[Medkit]==0,@"foreign container never refilled");
    ptr(obj[MaterialContainer],0x38,obj[Inventory]);wanted[DI2FeatureConsumables]=NO;UPDATE();
    names[Unknown]=@"DA_InventoryTypes_KeyItems_Fuse";counts[Unknown]=3;wanted[DI2FeatureConsumables]=YES;UPDATE();
    counts[Unknown]=0;UPDATE();NSCAssert(counts[Unknown]==3 && counts[Quest]==0,@"normal consumable fuse distinguished from quest keys");
    wanted[DI2FeatureConsumables]=NO;UPDATE();
    wanted[DI2FeatureCrafting]=YES;UPDATE();NSCAssert(active[DI2FeatureCrafting] && freedArrays==1,@"three native ingredient types supported and UE array freed");
    for(int i=0;i<3;i++)NSCAssert(cashCost(i)==0 && integerAt(ingredientEntries[i],8)==0 && integerAt(ingredientEntries[i],24)==0,@"zero native cash dispatch and material costs");
    NSCAssert(integerAt(table[1],16+0x240)!=0,@"original vtable stays intact");
    UPDATE();NSCAssert(freedArrays==2,@"repeat enumeration freed");
    wanted[DI2FeatureCrafting]=NO;UPDATE();
    for(int i=0;i<3;i++)NSCAssert(cashCost(i)==125 && integerAt(ingredientEntries[i],8)==5+i,@"restore original vptr and ingredient count");
    wanted[DI2FeatureCrafting]=YES;UPDATE();
    integer(ingredientEntries[0],8,37); // An external live edit must not be overwritten during rollback.
    live[Ingredients2]=NO;[service reset];
    NSCAssert(integerAt(ingredientEntries[0],8)==37 && cashCost(1)==125,@"restore preserves later changes and skips dead objects");
    NSCAssert(cashCost(2)==0,@"pending native destruction retains a valid shared dispatch table");
    ptr(obj[Ingredients2],0,table[2]+16);live[Ingredients2]=YES;serial[Ingredients2]++;
    // Unsupported vtables and malformed arrays cannot be treated as success.
    uint8_t unknownTable[0x258]={0};ptr(obj[Ingredients1],0,unknownTable+16);UPDATE();NSCAssert(!active[DI2FeatureCrafting],@"unknown virtual ABI stays orange");[service reset];
    ptr(obj[Ingredients1],0,table[1]+16);integer(obj[Ingredients0],0x30,2000);UPDATE();NSCAssert(!active[DI2FeatureCrafting],@"ingredient bounds checked");[service reset];
    for(int i=0;i<ExtraCount;i++){free(obj[i]);obj[i]=NULL;names[i]=nil;}
    NSCAssert(removeModifiers>=2,@"movement rollback exercised");
    puts("Extra feature checks passed: AI state, movement GUIDs, overlapping stack retention, exclusions, readback failures, recipe costs/vtables, bounds and dead objects.");
#undef UPDATE
}
