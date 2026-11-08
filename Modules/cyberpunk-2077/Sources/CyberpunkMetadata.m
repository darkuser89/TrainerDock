// SPDX-License-Identifier: GPL-3.0-only
#import "CyberpunkMetadata.h"
#import <mach/mach_vm.h>

static BOOL readBytes(uintptr_t address,void *output,size_t length){
    if(!address || !output || !length || address>UINTPTR_MAX-length)return NO;
    mach_vm_size_t actual=0;
    return mach_vm_read_overwrite(mach_task_self(),address,length,(mach_vm_address_t)output,&actual)==KERN_SUCCESS && actual==length;
}
uint64_t CPNameHash(NSString *name){
    uint64_t result=UINT64_C(14695981039346656037);
    const unsigned char *bytes=(const void *)name.UTF8String;
    for(;*bytes;bytes++)result=(result^*bytes)*UINT64_C(1099511628211);
    return result;
}
typedef struct {uintptr_t buckets;uint32_t size,capacity;uintptr_t nodes;uint32_t nodeCapacity,stride,next,size2;uintptr_t allocator;} CPMap;
typedef struct {uint32_t next,hash;uint64_t key;uintptr_t value;} CPNode;
_Static_assert(sizeof(CPMap)==0x30,"map layout");
_Static_assert(sizeof(CPNode)==0x18,"node layout");
// Bounded, lock-free diagnostic snapshot only. No engine locks or functions are
// touched. A changing header is rejected; these snapshots must never own objects.
static uintptr_t lookup(uintptr_t address,uint64_t name){
    CPMap before={0},after={0};
    if(!readBytes(address,&before,sizeof(before)) || !before.capacity || before.capacity>262144
       || before.size>before.capacity || before.nodeCapacity!=before.capacity || before.stride!=sizeof(CPNode))return 0;
    uint32_t hash=(uint32_t)name^(uint32_t)(name>>32),index=UINT32_MAX;
    if(!readBytes(before.buckets+(hash%before.capacity)*sizeof(index),&index,sizeof(index)))return 0;
    uintptr_t result=0;
    for(uint32_t steps=0;index!=UINT32_MAX && steps<before.capacity && steps<4096;steps++){
        CPNode node={0};if(index>=before.nodeCapacity || !readBytes(before.nodes+index*sizeof(node),&node,sizeof(node)))return 0;
        if(node.key==name && node.hash==hash){result=node.value;break;}
        index=node.next;
    }
    return readBytes(address,&after,sizeof(after)) && !memcmp(&before,&after,sizeof(before)) ? result : 0;
}
static NSDictionary *reverseTypes(uintptr_t address){
    CPMap before={0},after={0};
    if(!readBytes(address,&before,sizeof(before)) || !before.capacity || before.capacity>262144
       || before.size>before.capacity || before.nodeCapacity!=before.capacity || before.stride!=sizeof(CPNode))return @{};
    NSMutableData *nodes=[NSMutableData dataWithLength:before.capacity*sizeof(CPNode)];
    NSMutableData *buckets=[NSMutableData dataWithLength:before.capacity*sizeof(uint32_t)];
    if(!readBytes(before.nodes,nodes.mutableBytes,nodes.length) || !readBytes(before.buckets,buckets.mutableBytes,buckets.length)
       || !readBytes(address,&after,sizeof(after)) || memcmp(&before,&after,sizeof(before)))return @{};
    const CPNode *entries=nodes.bytes;const uint32_t *indices=buckets.bytes;
    NSMutableDictionary *result=[NSMutableDictionary new];NSMutableIndexSet *seen=[NSMutableIndexSet new];
    for(uint32_t b=0;b<before.capacity;b++){
        uint32_t index=indices[b];
        while(index!=UINT32_MAX){
            if(index>=before.capacity || [seen containsIndex:index])return @{};
            [seen addIndex:index];const CPNode *node=&entries[index];
            result[@(node->value)]=@(node->key);index=node->next;
        }
    }
    return seen.count==before.size ? result : @{};
}
static NSString *typeName(uintptr_t pointer,NSDictionary *reverse){
    if(!pointer)return @"Void";
    NSNumber *hash=reverse[@(pointer)];if(!hash)return @"unresolved";
    NSArray *known=@[@"Bool",@"Float",@"Int32",@"Uint32",@"Int64",@"Uint64",@"CName",@"TweakDBID",@"entEntityID",@"gameStatsObjectID",@"gameGodModeType",@"gamedataStatPoolType",@"gamedataStatType",@"gameItemID",@"gameeventsHitEvent",@"gameDamageSystem",@"gameAttackComputed",@"gamedataDamageType",@"gameuiHackingMinigameGameController",@"handle:gameeventsHitEvent",@"handle:gameDamageSystem",@"handle:gameAttackComputed",@"handle:PlayerPuppet",@"handle:entEntity",@"handle:gameuiHackingMinigameGameController",@"gamestateMachineGameScriptInterface",@"gamestateMachineStateContextScript",@"gamestateMachineparameterTypeActionLocomotionParameters",@"handle:gamestateMachineGameScriptInterface",@"handle:gamestateMachineStateContextScript",@"handle:gamestateMachineparameterTypeActionLocomotionParameters",@"whandle:gameItemData",@"array:whandle:gameItemData",@"handle:gameIBlackboard",@"handle:gameItemObject",@"ScriptGameInstance",@"GameInstance",@"gameScriptGameInstance",@"handle:gameObject",@"whandle:gameObject",@"handle:gamePlayerSystem",@"whandle:gamePlayerSystem",@"gamePlayerSystem",@"handle:cpPlayerSystem",@"handle:gameGodModeSystem",@"handle:gameStatPoolsSystem",@"handle:gameStatsSystem",@"handle:gameTransactionSystem",
        @"GameTime",@"EngineTime",@"Vector4",@"EulerAngles",@"Quaternion",@"WorldPosition",@"array:CName",
        @"gamedataItemType",@"gamedataEquipmentArea",@"handle:EquipmentSystemPlayerData",
        @"gamecheatsystemFlag",@"handle:gameDebugCheatsSystem",@"handle:gameScriptableSystem",@"gameStatModifierType",@"gameStatPoolModificationTypes",@"gameStatPoolModifier",@"gamedataProficiencyType",@"gamedataDevelopmentPointType",@"telemetryLevelGainReason",
        @"handle:gameStatModifierData_Deprecated",@"handle:gameConstantStatModifierData_Deprecated",@"handle:gameTimeSystem",@"handle:tickScriptTimeDilationListener",@"handle:gameStatusEffectSystem",@"handle:gameTeleportationFacility",@"handle:gameScriptableSystemsContainer",@"handle:PlayerDevelopmentSystem",@"handle:PlayerDevelopmentData",@"handle:gameItemObject",@"handle:gameWeaponObject",@"handle:gameItemData",@"whandle:entEntity",@"whandle:IScriptable"];
    for(NSString *name in known)if(hash.unsignedLongLongValue==CPNameHash(name))return name;
    return [NSString stringWithFormat:@"fnv64:%016llx",hash.unsignedLongLongValue];
}
static NSDictionary *inspectClass(uintptr_t map,NSString *name,NSArray<NSString *> *methods,NSDictionary *reverse,uintptr_t image,BOOL binding){
    BOOL global=[name isEqual:@"$global"];
    uintptr_t cls=global ? 1 : lookup(map,CPNameHash(name));uint64_t actualName=0;uint32_t size=0;
    if(!global && (!cls || !readBytes(cls+0x18,&actualName,sizeof(actualName)) || actualName!=CPNameHash(name)
       || !readBytes(cls+0x68,&size,sizeof(size)) || size>16*1024*1024)
       )return @{@"class":name,@"metadataFound":@NO};
    NSMutableDictionary *found=[NSMutableDictionary new];
    for(NSString *method in methods){
        NSMutableSet *visited=[NSMutableSet new];uintptr_t current=cls;NSDictionary *entry=nil;
        for(unsigned depth=0;current && depth<24 && !entry;depth++){
            if([visited containsObject:@(current)])break;[visited addObject:@(current)];
            for(NSUInteger offset=0x48;offset<=(global ? 0x48 : 0x58) && !entry;offset+=0x10){
                uintptr_t functions=0;uint32_t count=0;
                uintptr_t globalFunction=global ? lookup(map+0x90,CPNameHash(method)) : 0;
                if(global)count=globalFunction ? 1 : 0;
                else if(!readBytes(current+offset,&functions,8) || !readBytes(current+offset+12,&count,4) || count>4096)continue;
                for(uint32_t i=0;i<count;i++){
                    uintptr_t fn=0;uint64_t shortName=0,fullName=0;uint32_t parameters=0;
                    if(global)fn=globalFunction;else if(!readBytes(functions+i*8,&fn,8))continue;
                    if(!fn || !readBytes(fn+0x10,&shortName,8) || !readBytes(fn+8,&fullName,8)
                       || (shortName!=CPNameHash(method) && fullName!=CPNameHash(method)))continue;
                    if(!readBytes(fn+0x34,&parameters,4) || parameters>64)continue;
                    uintptr_t paramArray=0,returnProperty=0,returnType=0;uint32_t flags=0;
                    readBytes(fn+0x28,&paramArray,8);readBytes(fn+0x18,&returnProperty,8);readBytes(fn+0xa8,&flags,4);
                    if(returnProperty)readBytes(returnProperty,&returnType,8);
                    NSMutableArray *types=[NSMutableArray new],*parameterFlags=[NSMutableArray new];
                    for(uint32_t p=0;p<parameters;p++){
                        uintptr_t prop=0,type=0;
                        if(readBytes(paramArray+p*8,&prop,8) && prop)readBytes(prop,&type,8);
                        [types addObject:type ? typeName(type,reverse) : @"unresolved"];
                        uint64_t propertyFlags=0;if(prop)readBytes(prop+0x28,&propertyFlags,8);
                        [parameterFlags addObject:@(propertyFlags)];
                    }
                    NSMutableDictionary *info=[@{@"found":@YES,@"parameterCount":@(parameters),@"staticArray":@(offset==0x58),
                        @"flags":@(flags),@"native":@((flags&1)!=0),@"parameterTypes":types,@"parameterFlags":parameterFlags,@"returnType":typeName(returnType,reverse)} mutableCopy];
                    if(binding){
                        info[@"function"]=@(fn);info[@"returnTypePointer"]=@(returnType);
                        NSMutableArray *properties=[NSMutableArray new];
                        for(uint32_t p=0;p<parameters;p++){uintptr_t prop=0;readBytes(paramArray+p*8,&prop,8);[properties addObject:@(prop)];}
                        info[@"properties"]=properties;
                    }
                    if(image && (flags&1)){
                        uintptr_t vt=0,getIndex=0;uint32_t code[2]={0};
                        if(readBytes(fn,&vt,8) && readBytes(vt+0x20,&getIndex,8) && readBytes(getIndex,code,sizeof(code)))
                            info[@"indexGetterCode"]=[NSString stringWithFormat:@"%08x %08x",code[0],code[1]];
                        if(readBytes(fn,&vt,8) && readBytes(vt+0x20,&getIndex,8) && readBytes(getIndex,code,sizeof(code))
                           && (code[0]&0xffc003ff)==0xb9400000 && code[1]==0xd65f03c0){
                            uint32_t index=UINT32_MAX;NSUInteger field=((code[0]>>10)&0xfff)*4;
                            if(field<0x100 && readBytes(fn+field,&index,4) && index<32768){
                                uintptr_t handler=0;int64_t adjustment=0;
                                uintptr_t slot=(flags&2) ? image+0x9a5c940+index*8 : image+0x99dc940+index*16;
                                readBytes(slot,&handler,8);if(!(flags&2))readBytes(slot+8,&adjustment,8);
                                info[@"registrationIndex"]=@(index);info[@"memberAdjustment"]=@(adjustment);
                                if(handler>image && handler<image+0x7758000)info[@"nativeHandlerOffset"]=[NSString stringWithFormat:@"0x%llx",(unsigned long long)(handler-image)];
                                if(binding){info[@"handler"]=@(handler);info[@"slot"]=@(slot);}
                            }
                        }
                    }
                    entry=info;break;
                }
            }
            if(global || !readBytes(current+0x10,&current,8))break;
        }
        found[method]=entry ?: @{@"found":@NO};
    }
    return @{@"class":name,@"metadataFound":@YES,@"instanceSize":@(size),@"methods":found,
             @"callSignaturesVerified":@NO,@"objectsValidated":@NO};
}
NSDictionary *CPReadClassMetadata(uintptr_t map,NSString *name,NSArray<NSString *> *methods){
    return inspectClass(map,name,methods,@{},0,NO);
}
NSDictionary *CPReadCyberpunkTargets(const struct mach_header_64 *image,NSDictionary<NSString *,NSArray<NSString *> *> *targets){
    if(![targets isKindOfClass:NSDictionary.class] || targets.count>16)return @{@"error":@"Ungültige Metadatenanfrage."};
    for(id key in targets){
        id value=targets[key];
        if(![key isKindOfClass:NSString.class] || ![key length] || [key length]>128 || ![value isKindOfClass:NSArray.class] || [value count]>32)return @{@"error":@"Ungültige Metadatenanfrage."};
        for(id method in value)if(![method isKindOfClass:NSString.class] || ![method length] || [method length]>128)return @{@"error":@"Ungültige Metadatenanfrage."};
    }
    // Exact 2.5.0 getter bytes independently checked against the local executable.
    // The accessor is NEVER called: decode its ADRP/ADD return address instead.
    static const uint32_t expected[]={0xa9bf7bfd,0x910003fd,0xd0037d08,0x913a0108,0x38bfc108,0x36000108,
        0xd0037d08,0x3979e108,0x36000128,0xd0037d00,0x913a6000,0xa8c17bfd,0xd65f03c0};
    uintptr_t getter=(uintptr_t)image+0x10b3cac;uint32_t actual[sizeof(expected)/4];
    if(!readBytes(getter,actual,sizeof(actual)) || memcmp(actual,expected,sizeof(actual)))return @{@"rttiFingerprintMatches":@NO};
    uint32_t adrp=actual[9],add=actual[10];
    int64_t immediate=(int64_t)((((adrp>>5)&0x7ffff)<<2)|((adrp>>29)&3));
    if(immediate&(1<<20))immediate-=(1<<21);
    uintptr_t registry=((getter+9*4)&~(uintptr_t)0xfff)+(immediate*4096)+((add>>10)&0xfff);
    uint8_t ready=0;uintptr_t vtable=0;
    if(!readBytes(registry-0x20,&ready,1) || !(ready&1) || !readBytes(registry,&vtable,8) || !vtable)
        return @{@"rttiFingerprintMatches":@YES,@"registryReady":@NO};
    NSDictionary *reverse=reverseTypes(registry+0x10);
    NSMutableArray *classes=[NSMutableArray new];
    for(NSString *name in [[targets allKeys] sortedArrayUsingSelector:@selector(compare:)])
        if([name isEqual:@"$opcodes"]){
            NSMutableDictionary *operators=[NSMutableDictionary new];
            for(NSString *code in targets[name]){
                unsigned value=0;NSScanner *scanner=[NSScanner scannerWithString:code];
                if(![scanner scanHexInt:&value] || !scanner.isAtEnd || value>255)continue;
                uintptr_t handler=0;
                if(readBytes((uintptr_t)image+0x9a5c940+value*8,&handler,8) && handler>(uintptr_t)image && handler<(uintptr_t)image+0x7758000)
                    operators[code]=[NSString stringWithFormat:@"0x%llx",(unsigned long long)(handler-(uintptr_t)image)];
            }
            [classes addObject:@{@"class":name,@"handlers":operators}];
        }else {
            NSMutableDictionary *record=[inspectClass(registry+0x10,name,targets[name],reverse,(uintptr_t)image,NO) mutableCopy];
            record[@"schema"]=CPReadTypeSchema(image,name);[classes addObject:record];
        }
    return @{@"rttiFingerprintMatches":@YES,@"registryReady":@YES,@"classes":classes,
             @"typeSnapshotStable":@(reverse.count>0),@"gameThreadVerified":@NO,@"cheatsApplied":@NO};
}
NSDictionary *CPResolveNativeBinding(const struct mach_header_64 *image,NSString *className,NSString *method){
    // Run the exact build/registry checks before exposing native pointers internally.
    NSDictionary *check=CPReadCyberpunkTargets(image,@{});
    if(![check[@"registryReady"] boolValue] || ![check[@"typeSnapshotStable"] boolValue])return nil;
    // Re-derived from the verified getter's ADRP/ADD sequence in this exact image.
    uintptr_t registry=(uintptr_t)image+0x8055e98;
    NSDictionary *record=inspectClass(registry+0x10,className,@[method],reverseTypes(registry+0x10),(uintptr_t)image,YES);
    NSDictionary *result=record[@"methods"][method];
    if(![result[@"native"] boolValue] || !result[@"nativeHandlerOffset"] || [result[@"memberAdjustment"] longLongValue]!=0)return nil;
    return result;
}
NSDictionary *CPResolveScriptBinding(const struct mach_header_64 *image,NSString *className,NSString *method){
    NSDictionary *check=CPReadCyberpunkTargets(image,@{});
    if(![check[@"registryReady"] boolValue] || ![check[@"typeSnapshotStable"] boolValue])return nil;
    uintptr_t map=(uintptr_t)image+0x8055ea8;
    NSDictionary *record=inspectClass(map,className,@[method],reverseTypes(map),(uintptr_t)image,YES);
    NSDictionary *binding=record[@"methods"][method];
    return [binding[@"found"] boolValue] && ![binding[@"native"] boolValue] ? binding : nil;
}
NSDictionary *CPReadTypeSchema(const struct mach_header_64 *image,NSString *name){
    uintptr_t type=CPFindNativeType(image,name);if(!type)return @{@"found":@NO};
    uint64_t at10=0,at18=0;readBytes(type+0x10,&at10,8);readBytes(type+0x18,&at18,8);
    if(at10==CPNameHash(name)){
        uint8_t size=0;uintptr_t names=0,values=0;uint32_t count=0,nvalues=0;
        if(!readBytes(type+0x20,&size,1) || (size!=1 && size!=2 && size!=4 && size!=8)
           || !readBytes(type+0x28,&names,8) || !readBytes(type+0x34,&count,4) || count>4096
           || !readBytes(type+0x38,&values,8) || !readBytes(type+0x44,&nvalues,4) || count!=nvalues)return @{@"found":@YES};
        NSMutableArray *members=[NSMutableArray new];
        for(uint32_t i=0;i<count;i++){
            uint64_t hash=0;int64_t value=0;if(!readBytes(names+i*8,&hash,8) || !readBytes(values+i*8,&value,8))return @{@"found":@NO};
            [members addObject:@{@"nameHash":[NSString stringWithFormat:@"%016llx",(unsigned long long)hash],@"value":@(value)}];
        }return @{@"found":@YES,@"kind":@"enum",@"size":@(size),@"members":members};
    }
    if(at18!=CPNameHash(name))return @{@"found":@YES};
    uint32_t size=0,flags=0;if(!readBytes(type+0x68,&size,4) || !readBytes(type+0x70,&flags,4) || size>16*1024*1024)return @{@"found":@NO};
    NSDictionary *reverse=reverseTypes((uintptr_t)image+0x8055ea8);NSMutableArray *fields=[NSMutableArray new];
    NSMutableSet *seen=[NSMutableSet new];uintptr_t cls=type;
    for(unsigned depth=0;cls && depth<24;depth++){
        if([seen containsObject:@(cls)])break;[seen addObject:@(cls)];
        for(NSUInteger fieldArray=0x28;fieldArray<=0x118;fieldArray+=0xf0){
            uintptr_t props=0;uint32_t count=0;
            if(!readBytes(cls+fieldArray,&props,8) || !readBytes(cls+fieldArray+12,&count,4) || count>1024)continue;
            for(uint32_t i=0;i<count && fields.count<512;i++){
                uintptr_t prop=0,fieldType=0;uint64_t hash=0,propertyFlags=0;uint32_t offset=0;
                if(!readBytes(props+i*8,&prop,8) || !readBytes(prop,&fieldType,8) || !readBytes(prop+8,&hash,8)
                   || !readBytes(prop+0x20,&offset,4) || !readBytes(prop+0x28,&propertyFlags,8))continue;
                [fields addObject:@{@"nameHash":[NSString stringWithFormat:@"%016llx",(unsigned long long)hash],@"type":typeName(fieldType,reverse),@"offset":@(offset),@"flags":@(propertyFlags)}];
            }
        }
        if(!readBytes(cls+0x10,&cls,8))break;
    }
    return @{@"found":@YES,@"kind":@"class",@"size":@(size),@"flags":@(flags),@"properties":fields};
}
uintptr_t CPFindNativeType(const struct mach_header_64 *image,NSString *typeName){
    // Getter identity and ready flag were validated at bridge installation.
    if(!image || !typeName.length)return 0;
    return lookup((uintptr_t)image+0x8055ea8,CPNameHash(typeName));
}
NSNumber *CPFindEnumValue(const struct mach_header_64 *image,NSString *typeName,NSString *member){
    uintptr_t type=CPFindNativeType(image,typeName),names=0,values=0;uint32_t count=0,valueCount=0;uint64_t name=0;
    if(!type || !readBytes(type+0x10,&name,8) || name!=CPNameHash(typeName)
       || !readBytes(type+0x28,&names,8) || !readBytes(type+0x34,&count,4) || count>4096
       || !readBytes(type+0x38,&values,8) || !readBytes(type+0x44,&valueCount,4) || count!=valueCount)return nil;
    for(uint32_t i=0;i<count;i++){
        uint64_t key=0;int64_t value=0;
        if(readBytes(names+i*8,&key,8) && key==CPNameHash(member) && readBytes(values+i*8,&value,8))return @(value);
    }
    return nil;
}
BOOL CPNativeClassIsA(const struct mach_header_64 *image,NSString *className,NSString *baseName){
    uintptr_t cls=CPFindNativeType(image,className),base=CPFindNativeType(image,baseName);
    if(!cls || !base)return NO;
    for(unsigned depth=0;cls && depth<32;depth++){
        if(cls==base)return YES;
        if(!readBytes(cls+0x10,&cls,8))return NO;
    }return NO;
}
NSDictionary *CPReadCyberpunkMetadata(const struct mach_header_64 *image){
    NSDictionary *targets=@{
        @"PlayerPuppet":@[@"GetGame",@"GetEntityID"],
        @"gameStatsSystem":@[@"GetStatValue",@"AddModifier",@"RemoveModifier"],
        @"gameStatPoolsSystem":@[@"GetStatPoolValue",@"RequestSettingStatPoolValue"],
        @"gameGodModeSystem":@[@"AddGodMode",@"RemoveGodMode",@"HasGodMode"],
        @"gameTransactionSystem":@[@"GetItemQuantity",@"GiveItem",@"RemoveItem"],
        @"cpPlayerSystem":@[@"GetLocalPlayerControlledGameObject",@"GetLocalPlayerMainGameObject"],
        @"ScriptGameInstance":@[@"GetPlayerSystem",@"GetGodModeSystem",@"GetStatPoolsSystem",@"GetStatsSystem",@"GetTransactionSystem"]};
    return CPReadCyberpunkTargets(image,targets);
}

uintptr_t CPFindProperty(const struct mach_header_64 *image,NSString *className,NSString *name,NSString *typeName){
    uintptr_t cls=CPFindNativeType(image,className),expected=CPFindNativeType(image,typeName);if(!cls || !expected)return 0;
    NSMutableSet *visited=[NSMutableSet new];
    for(unsigned depth=0;cls && depth<32;depth++){
        if([visited containsObject:@(cls)])return 0;[visited addObject:@(cls)];
        for(unsigned a=0;a<2;a++){
            uintptr_t array=0;uint32_t count=0;NSUInteger offset=a ? 0x118 : 0x28;
            if(!readBytes(cls+offset,&array,8) || !readBytes(cls+offset+12,&count,4) || count>4096)continue;
            for(uint32_t i=0;i<count;i++){
                uintptr_t property=0,type=0;uint64_t hash=0;
                if(readBytes(array+i*8,&property,8) && readBytes(property,&type,8) && type==expected && readBytes(property+8,&hash,8) && hash==CPNameHash(name))return property;
            }
        }
        if(!readBytes(cls+0x10,&cls,8))return 0;
    }return 0;
}
