// SPDX-License-Identifier: GPL-3.0-only
#import "ExtraFeatures.h"
#include <math.h>

static BOOL readAt(const void *object, size_t offset, void *out, size_t size) {
    return object && offset<=UINTPTR_MAX-(uintptr_t)object
        && DI2ReadMemory((const char *)object+offset,out,size);
}
static void *pointerAt(const void *object, size_t offset) {
    void *value=NULL; readAt(object,offset,&value,sizeof(value)); return value;
}
static BOOL arrayAt(const void *object, size_t offset, DI2Array *array, int32_t limit) {
    return readAt(object,offset,array,sizeof(*array)) && array->num>=0
        && array->num<=limit && array->capacity>=array->num && array->capacity<=65536
        && (!array->num || (array->data && !((uintptr_t)array->data&7)));
}
static BOOL writeIntChecked(void *object, size_t offset, int32_t value) {
    int32_t actual=-1;
    return DI2WriteInt(object,offset,value) && readAt(object,offset,&actual,4) && actual==value;
}
static BOOL guidValid(DI2Guid guid) { return (guid.low|guid.high)!=0; }
static void *sharedIngredientTable(const DI2GameAPI *api, void *original) {
    // WeakGet(NULL) can mean pending destruction, not a completed destructor.
    // Keep at most three small immutable tables alive for the process lifetime,
    // so a late native destructor can never dispatch into freed table memory.
    static struct { void *original, *copy; } tables[3];
    for (NSUInteger i=0;i<3;i++) if (tables[i].original==original) return tables[i].copy;
    for (NSUInteger i=0;i<3;i++) if (!tables[i].original) {
        void *copy=malloc(0x258);
        if (!copy || !DI2ReadMemory((char *)original-16,copy,0x258)) { free(copy); return NULL; }
        memcpy((char *)copy+16+0x240,&api->zeroCraftingCost,8);
        tables[i].original=original; tables[i].copy=copy; return copy;
    }
    return NULL;
}

@interface DI2RetainedStack : NSObject {
@public DI2WeakObject archetype, category; int32_t count; BOOL consumable;
}
@end
@implementation DI2RetainedStack
@end

@interface DI2FreeRecipe : NSObject {
@public DI2WeakObject weak; void *originalVTable, *shadow;
    DI2Array ingredients; NSData *originalEntries;
}
@end
@implementation DI2FreeRecipe
@end

@interface DI2ExtraFeatures () {
    DI2GameAPI _api;
    DI2WeakObject _ai, _playerState, _movement, _definition, _inventory;
    int32_t _playerId;
    uint8_t _originalIgnored;
    BOOL _stealthApplied;
    DI2Guid _movementGuid;
    float _contribution;
    uint8_t _movementOperation;
    NSMutableArray<DI2RetainedStack *> *_stacks;
    NSMutableArray<DI2FreeRecipe *> *_recipes;
}
@end

@implementation DI2ExtraFeatures
- (instancetype)initWithAPI:(DI2GameAPI)api {
    if ((self=[super init])) { _api=api; _stacks=[NSMutableArray new]; _recipes=[NSMutableArray new]; }
    return self;
}
- (BOOL)object:(void *)object class:(void *(*)(void))type {
    void *actual=pointerAt(object,0x10);
    return object && !((uintptr_t)object&7) && actual && type && _api.valid(object,false)
        && _api.classIsChildOf(actual,type());
}
- (BOOL)weak:(DI2WeakObject *)weak assign:(void *)object {
    _api.weakAssign(weak,object); return object && _api.weakGet(weak)==object;
}
// The map uses native hash chains, not a linear scan over freed sparse entries.
- (BOOL)ignored:(int32_t)playerId value:(uint8_t *)value {
    int32_t count=0,buckets=0,index=-1;
    void *map=_api.ignorePlayers,*data=pointerAt(map,0),*hash=pointerAt(map,0x40);
    if (!hash && map) hash=(char *)map+0x38;
    if (!data || !hash || !readAt(map,8,&count,4) || count<=0 || count>4096
        || !readAt(map,0x48,&buckets,4) || buckets<=0 || buckets>8192 || (buckets&(buckets-1))) return NO;
    if (!readAt(hash,((uint32_t)playerId&(buckets-1))*4,&index,4)) return NO;
    for (int32_t visited=0;index>=0 && index<count && visited<count;visited++) {
        int32_t key=0,next=-1; uint8_t result=0;
        if (!readAt(data,(size_t)index*16,&key,4) || !readAt(data,(size_t)index*16+8,&next,4)) return NO;
        if (key==playerId) {
            if (!readAt(data,(size_t)index*16+4,&result,1) || result>1) return NO;
            *value=result; return YES;
        }
        index=next;
    }
    return NO;
}
- (void)setIgnored:(BOOL)enabled manager:(void *)manager playerId:(int32_t)playerId {
    NSString *identifier=[NSString stringWithFormat:@"%d",playerId];
    uint16_t idString[16]={0},flag[2]={enabled ? '1' : '0',0};
    [identifier getCharacters:idString range:NSMakeRange(0,identifier.length)];
    DI2Array strings[2]={{idString,(int32_t)identifier.length+1,(int32_t)identifier.length+1},{flag,2,2}};
    DI2Array arguments={strings,2,2};
    _api.setIgnorePlayer(manager,&arguments);
}
- (void)restoreStealth {
    if (_stealthApplied) {
        void *manager=_api.weakGet(&_ai),*state=_api.weakGet(&_playerState);
        int32_t identifier=0; uint8_t value=0;
        if (manager && state && readAt(state,0x25c,&identifier,4) && identifier==_playerId
            && [self ignored:_playerId value:&value] && value==1)
            [self setIgnored:_originalIgnored!=0 manager:manager playerId:_playerId];
    }
    _stealthApplied=NO; memset(&_ai,0,sizeof(_ai)); memset(&_playerState,0,sizeof(_playerState));
}
- (BOOL)stealthPlayer:(void *)player controller:(void *)controller wanted:(BOOL)wanted available:(BOOL *)available {
    BOOL bound=_api.aiManager && _api.setIgnorePlayer && _api.updateIgnorePlayers && _api.ignorePlayers;
    void *manager=bound ? _api.aiManager(player) : NULL,*state=pointerAt(controller,0x260);
    if (![self object:manager class:_api.aiManagerClass] || ![self object:state class:_api.playerStateClass]) manager=NULL;
    int32_t identifier=0; uint8_t ignored=0;
    if (manager) _api.updateIgnorePlayers(manager);
    *available=manager && readAt(state,0x25c,&identifier,4) && [self ignored:identifier value:&ignored];
    if (_stealthApplied && (!wanted || !*available || _api.weakGet(&_ai)!=manager
        || _api.weakGet(&_playerState)!=state || identifier!=_playerId)) [self restoreStealth];
    if (!wanted || !*available) return NO;
    if (!_stealthApplied) {
        if (![self weak:&_ai assign:manager] || ![self weak:&_playerState assign:state]) return NO;
        _playerId=identifier; _originalIgnored=ignored; _stealthApplied=YES;
    }
    if (!ignored) [self setIgnored:YES manager:manager playerId:identifier];
    return [self ignored:identifier value:&ignored] && ignored==1;
}
- (void)restoreMovement {
    void *component=_api.weakGet(&_movement);
    if (component && guidValid(_movementGuid)) _api.removeMovementModifier(component,_movementGuid,0);
    _movementGuid=(DI2Guid){0,0}; _contribution=0;
    memset(&_movement,0,sizeof(_movement)); memset(&_definition,0,sizeof(_definition));
}
- (BOOL)movementPlayer:(void *)player wanted:(BOOL)wanted factor:(float)factor available:(BOOL *)available {
    // CalcMaxMoveSpeedForMovementParams multiplies every walking/sprinting mode
    // by d68. d70/d78 additionally govern sprint blending; scaling all three is wrong.
    void *component=pointerAt(player,0x780),*definition=pointerAt(player,0xd68);
    uint8_t operation=255;
    BOOL bound=_api.currentMovementValue && _api.addMovementModifier
        && _api.removeMovementModifier && _api.updateMovementModifier;
    *available=bound && [self object:component class:_api.modifiableClass]
        && pointerAt(component,0xd0)==player && [self object:definition class:_api.movementDefinitionClass]
        && readAt(definition,0x40,&operation,1) && (operation==0 || operation==3);
    if (guidValid(_movementGuid) && (!wanted || !*available || _api.weakGet(&_movement)!=component
        || _api.weakGet(&_definition)!=definition || operation!=_movementOperation)) [self restoreMovement];
    if (!wanted || !*available) return NO;
    float current=0;
    if (!_api.currentMovementValue(component,definition,&current) || !isfinite(current) || current<=0) return NO;
    float baseline=current;
    if (guidValid(_movementGuid)) baseline=operation==0 ? current-_contribution : current/_contribution;
    if (!isfinite(baseline) || baseline<=0 || baseline>1000) { [self restoreMovement]; return NO; }
    float contribution=operation==0 ? baseline*(factor-1) : factor;
    if (!guidValid(_movementGuid)) {
        if (![self weak:&_movement assign:component] || ![self weak:&_definition assign:definition]) return NO;
        uint64_t reason=0;
        static const uint16_t label[]={'D','I','2','T','r','a','i','n','e','r','.','M','o','v','e',0};
        _api.name(&reason,label,1);
        _movementGuid=_api.addMovementModifier(component,definition,reason,contribution,1,0,true);
        _movementOperation=operation;
    } else if (fabsf(contribution-_contribution)>0.00001f)
        _api.updateMovementModifier(component,definition,_movementGuid,contribution);
    _contribution=contribution;
    float after=0,target=baseline*factor;
    BOOL confirmed=guidValid(_movementGuid) && _api.currentMovementValue(component,definition,&after)
        && isfinite(after) && fabsf(after-target)<=MAX(0.001f,fabsf(target)*0.001f);
    if (!confirmed) [self restoreMovement];
    return confirmed;
}
- (NSString *)nameAt:(void *)object offset:(size_t)offset {
    // UE FNames are at most NAME_SIZE (1024) UTF-16 units plus numeric suffix.
    // This native overload does not enforce its capacity argument in this build.
    uint16_t text[2048]={0}; uint64_t name=0;
    if (!_api.nameString || !readAt(object,offset,&name,8)) return @"";
    int32_t length=_api.nameString(&name,text,2048);
    return length>0 && length<2048 ? [[NSString alloc]initWithCharacters:text length:(NSUInteger)length].lowercaseString : @"";
}
- (NSInteger)stackKind:(void *)archetype category:(void *)category cash:(void *)cash {
    if (archetype==cash || ![self object:archetype class:_api.archetypeClass]
        || ![self object:category class:_api.categoryClass] || pointerAt(archetype,0x78)!=category) return 0;
    int32_t maximum=0;
    if (!readAt(archetype,0x80,&maximum,4) || maximum<=1 || maximum>1000000) return 0;
    NSString *name=[self nameAt:archetype offset:0x18];
    // GetCategory(FName) compares the category's own name at +0x30, which
    // need not match its UObject asset name (+0x18).
    NSString *group=[NSString stringWithFormat:@"%@ %@",[self nameAt:category offset:0x18],[self nameAt:category offset:0x30]];
    if (!name.length || !group.length) return 0;
    BOOL ordinaryFuse=[name isEqualToString:@"da_inventorytypes_keyitems_fuse"];
    for (NSString *excluded in @[@"quest",@"key",@"journal",@"collect",@"blueprint",@"recipe",@"cash",@"currency",@"unlock",@"mission",@"weapon"])
        if (!(ordinaryFuse && [excluded isEqualToString:@"key"]) && ([name containsString:excluded] || [group containsString:excluded])) return 0;
    BOOL knownMaterial=[name hasPrefix:@"da_itemarchetype_ingredients_"] || [name hasPrefix:@"da_itemarchetype_exoticmaterials_"];
    if (knownMaterial || ordinaryFuse || [name isEqualToString:@"da_inventorytypes_consumable_healthpack"]) return 1;
    // Positive category evidence is required: unknown and progression categories
    // are never retained merely because they happen to be stackable.
    for (NSString *ordinary in @[@"material",@"ingredient",@"crafting",@"resource",@"consum",@"medkit",@"healthkit",@"parts"])
        if ([group containsString:ordinary]) return 1;
    if ([group containsString:@"ammo"] || [name hasPrefix:@"da_ammoarchetype_"]) return 2;
    return 0;
}
- (BOOL)inventory:(void *)inventory consumables:(BOOL)consumables items:(BOOL)items
           activeConsumables:(BOOL *)activeConsumables activeItems:(BOOL *)activeItems {
    if (_api.weakGet(&_inventory)!=inventory) { [_stacks removeAllObjects]; [self weak:&_inventory assign:inventory]; }
    if (!consumables && !items) { [_stacks removeAllObjects]; return inventory!=NULL; }
    if (!inventory || !_api.containerClass || !_api.addItem || !_api.count || !_api.nameString) return NO;
    DI2Array categories={0};
    if (!arrayAt(inventory,0x120,&categories,128)) return NO;
    NSMutableDictionary<NSValue *,NSNumber *> *observed=[NSMutableDictionary new];
    NSMutableDictionary<NSValue *,NSValue *> *groups=[NSMutableDictionary new];
    void *cash=pointerAt(inventory,0x318);
    for (int32_t i=0;i<categories.num;i++) {
        void *container=pointerAt(categories.data,(size_t)i*8);
        if (![self object:container class:_api.containerClass] || pointerAt(container,0x38)!=inventory) continue;
        void *category=pointerAt(container,0x28); DI2Array slots={0};
        if (!arrayAt(container,0x1a0,&slots,1024)) return NO;
        for (int32_t j=0;j<slots.num;j++) {
            void *actor=pointerAt(slots.data,(size_t)j*40+0x10);
            if (![self object:actor class:_api.itemActorClass]) continue;
            void *archetype=pointerAt(actor,0x370);
            NSInteger kind=[self stackKind:archetype category:category cash:cash];
            if (!kind || (kind==2 && !items)) continue;
            int32_t count=_api.count(inventory,archetype);
            if (count<=0 || count>1000000) continue;
            NSValue *key=[NSValue valueWithPointer:archetype];
            observed[key]=@(kind); groups[key]=[NSValue valueWithPointer:category];
        }
    }
    for (NSValue *key in observed) {
        void *archetype=key.pointerValue; BOOL found=NO;
        for (DI2RetainedStack *stack in _stacks) if (_api.weakGet(&stack->archetype)==archetype) { found=YES; break; }
        if (!found && _stacks.count<1024) {
            DI2RetainedStack *stack=[DI2RetainedStack new];
            if ([self weak:&stack->archetype assign:archetype] && [self weak:&stack->category assign:groups[key].pointerValue]) {
                stack->count=_api.count(inventory,archetype); stack->consumable=observed[key].integerValue==1;
                [_stacks addObject:stack];
            }
        }
    }
    BOOL goodConsumables=YES,goodItems=YES; NSUInteger numConsumables=0,numItems=0;
    for (NSInteger i=(NSInteger)_stacks.count-1;i>=0;i--) {
        DI2RetainedStack *stack=_stacks[(NSUInteger)i];
        void *archetype=_api.weakGet(&stack->archetype),*category=_api.weakGet(&stack->category);
        NSInteger kind=[self stackKind:archetype category:category cash:cash];
        if (!kind || (kind==2 && !items)) { [_stacks removeObjectAtIndex:(NSUInteger)i]; continue; }
        // Refuse refill after a category has left this player's inventory.
        BOOL local=NO;
        for (int32_t j=0;j<categories.num;j++) {
            void *container=pointerAt(categories.data,(size_t)j*8);
            if ([self object:container class:_api.containerClass] && pointerAt(container,0x38)==inventory
                && pointerAt(container,0x28)==category) { local=YES; break; }
        }
        if (!local) { [_stacks removeObjectAtIndex:(NSUInteger)i]; continue; }
        int32_t before=_api.count(inventory,archetype);
        BOOL valid=before>=0 && before<=1000000;
        if (valid && before<stack->count) _api.addItem(inventory,archetype,stack->count-before,false);
        int32_t after=_api.count(inventory,archetype);
        BOOL verified=valid && after>=stack->count && after<=1000000;
        if (verified) stack->count=after; // New ordinary pickups establish the new floor.
        numItems++; goodItems=goodItems && verified;
        if (stack->consumable) { numConsumables++; goodConsumables=goodConsumables && verified; }
    }
    *activeConsumables=consumables && numConsumables>0 && goodConsumables;
    *activeItems=items && numItems>0 && goodItems;
    return YES;
}
- (void)restoreIngredients:(DI2FreeRecipe *)recipe object:(void *)object {
    DI2Array array={0};
    if (!object || !arrayAt(object,0x28,&array,1024) || array.data!=recipe->ingredients.data
        || array.num!=recipe->ingredients.num) return;
    const uint8_t *original=recipe->originalEntries.bytes;
    for (int32_t i=0;i<array.num;i++) {
        void *archetype=NULL; int32_t count=0,now=-1;
        memcpy(&archetype,original+(size_t)i*16,8); memcpy(&count,original+(size_t)i*16+8,4);
        if (pointerAt(array.data,(size_t)i*16)==archetype && readAt(array.data,(size_t)i*16+8,&now,4) && now==0)
            DI2WriteInt(array.data,(size_t)i*16+8,count);
    }
}
- (void)restoreRecipe:(DI2FreeRecipe *)recipe {
    void *object=_api.weakGet(&recipe->weak);
    if (object) {
        [self restoreIngredients:recipe object:object];
        if (pointerAt(object,0)==(char *)recipe->shadow+16)
            DI2WritePointer(object,0,recipe->originalVTable);
        // Do not free a table while a still-live object can dispatch through it.
        if (pointerAt(object,0)==(char *)recipe->shadow+16) return;
    }
    recipe->shadow=NULL; // Shared immutable storage remains valid through native GC.
}
- (void)restoreCrafting {
    for (DI2FreeRecipe *recipe in _recipes.copy) { [self restoreRecipe:recipe]; if (!recipe->shadow) [_recipes removeObject:recipe]; }
}
- (BOOL)freeRecipe:(DI2FreeRecipe *)recipe object:(void *)object {
    DI2Array array={0};
    if (!arrayAt(object,0x28,&array,1024)) return NO;
    if (array.data!=recipe->ingredients.data || array.num!=recipe->ingredients.num) {
        [self restoreIngredients:recipe object:object];
        NSMutableData *entries=[NSMutableData dataWithLength:(NSUInteger)array.num*16];
        if (array.num && !DI2ReadMemory(array.data,entries.mutableBytes,entries.length)) return NO;
        // Validate the entire list before any count is changed.
        for (int32_t i=0;i<array.num;i++) {
            void *archetype=NULL; int32_t count=0;
            memcpy(&archetype,(char *)entries.bytes+(size_t)i*16,8); memcpy(&count,(char *)entries.bytes+(size_t)i*16+8,4);
            if (![self object:archetype class:_api.archetypeClass] || count<0 || count>1000000) return NO;
        }
        recipe->ingredients=array; recipe->originalEntries=entries;
    }
    BOOL verified=pointerAt(object,0)==(char *)recipe->shadow+16;
    for (int32_t i=0;i<array.num;i++) verified=writeIntChecked(array.data,(size_t)i*16+8,0) && verified;
    return verified;
}
- (BOOL)craftingWanted:(BOOL)wanted available:(BOOL *)available count:(NSUInteger *)count {
    *available=_api.objectsOfClass && _api.freeMemory && _api.recipeClass && _api.ingredientsClass && _api.zeroCraftingCost;
    if (!wanted) { [self restoreCrafting]; return NO; }
    if (!*available) return NO;
    // Discover only loaded recipe assets; no package loading, entitlement bypass,
    // UObject construction, global vtable writes or executable memory changes.
    DI2Array recipes={0};
    _api.objectsOfClass(_api.recipeClass(),&recipes,true,0x30,0);
    BOOL valid=recipes.num>=0 && recipes.num<=8192 && recipes.capacity>=recipes.num
        && recipes.capacity<=65536 && (!recipes.num || recipes.data);
    BOOL success=valid;
    NSMutableSet<NSValue *> *seen=[NSMutableSet new];
    for (int32_t i=0;valid && i<recipes.num;i++) {
        void *asset=pointerAt(recipes.data,(size_t)i*8);
        if (![self object:asset class:_api.recipeClass]) continue;
        void *object=pointerAt(asset,0x38);
        if (![self object:object class:_api.ingredientsClass]) continue;
        NSValue *identity=[NSValue valueWithPointer:object]; if ([seen containsObject:identity]) continue;
        [seen addObject:identity];
        DI2FreeRecipe *entry=nil;
        for (DI2FreeRecipe *candidate in _recipes) if (_api.weakGet(&candidate->weak)==object) { entry=candidate; break; }
        if (!entry && _recipes.count<8192) {
            void *vtable=pointerAt(object,0); BOOL known=NO;
            for (int j=0;j<3;j++) if (_api.ingredientVTables[j] && vtable==_api.ingredientVTables[j]) known=YES;
            if (!known) { success=NO; continue; }
            entry=[DI2FreeRecipe new]; entry->originalVTable=vtable; entry->shadow=sharedIngredientTable(&_api,vtable);
            if (!entry->shadow || ![self weak:&entry->weak assign:object]) { success=NO; continue; }
            // Preserve RTTI and every virtual slot except GetCashCost. Its target
            // is the game's own zero-cost implementation, not generated code.
            if (!DI2WritePointer(object,0,(char *)entry->shadow+16)) { success=NO; continue; }
            [_recipes addObject:entry];
        }
        if (!entry || ![self freeRecipe:entry object:object]) {
            success=NO;
            if (entry) { [self restoreRecipe:entry]; if (!entry->shadow) [_recipes removeObject:entry]; }
        } else (*count)++;
    }
    if (recipes.data) _api.freeMemory(recipes.data);
    for (DI2FreeRecipe *entry in _recipes.copy) {
        void *object=_api.weakGet(&entry->weak);
        if (!object || ![seen containsObject:[NSValue valueWithPointer:object]]) {
            [self restoreRecipe:entry]; if (!entry->shadow) [_recipes removeObject:entry];
        }
    }
    return success && *count>0;
}
- (void)reset {
    [self restoreStealth]; [self restoreMovement]; [self restoreCrafting];
    [_stacks removeAllObjects]; memset(&_inventory,0,sizeof(_inventory));
}
- (void)updatePlayer:(void *)player controller:(void *)controller inventory:(void *)inventory
             wanted:(const BOOL *)wanted values:(const double *)values
          available:(BOOL *)available active:(BOOL *)active states:(NSArray<DI2FeatureState *> *)states {
    active[DI2FeatureStealth]=[self stealthPlayer:player controller:controller wanted:wanted[DI2FeatureStealth] available:&available[DI2FeatureStealth]];
    active[DI2FeatureMovementSpeed]=[self movementPlayer:player wanted:wanted[DI2FeatureMovementSpeed]
        factor:(float)values[DI2FeatureMovementSpeed] available:&available[DI2FeatureMovementSpeed]];
    BOOL inventoryOK=[self inventory:inventory consumables:wanted[DI2FeatureConsumables] items:wanted[DI2FeatureItems]
        activeConsumables:&active[DI2FeatureConsumables] activeItems:&active[DI2FeatureItems]];
    available[DI2FeatureConsumables]=available[DI2FeatureItems]=inventoryOK && _api.addItem && _api.nameString;
    NSUInteger recipes=0;
    active[DI2FeatureCrafting]=[self craftingWanted:wanted[DI2FeatureCrafting] available:&available[DI2FeatureCrafting] count:&recipes];
    if (wanted[DI2FeatureCrafting]) states[DI2FeatureCrafting].note=[NSString stringWithFormat:@"%lu geladene Zutatenlisten kostenfrei · Rezepte/Freischaltungen unverändert%@",
        (unsigned long)recipes,active[DI2FeatureCrafting] ? @"" : @" · wartet auf vollständig unterstützte Rezepte"];
    const DI2Feature extra[]={DI2FeatureStealth,DI2FeatureMovementSpeed,DI2FeatureConsumables,DI2FeatureItems};
    for (NSUInteger i=0;i<sizeof(extra)/sizeof(extra[0]);i++) {
        DI2Feature kind=extra[i];
        if (wanted[kind] && !active[kind]) states[kind].note=kind==DI2FeatureConsumables || kind==DI2FeatureItems
            ? @"Wartet auf sicher erkannte normale Stapel oder bestätigtes Auffüllen. Questobjekte und Waffen bleiben ausgenommen."
            : @"Wartet auf gültige lokale Spielobjekte und bestätigten Laufzeitzustand.";
    }
}
@end
