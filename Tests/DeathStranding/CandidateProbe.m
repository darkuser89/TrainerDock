// SPDX-License-Identifier: GPL-3.0-only
// Native diagnostics compiled ONLY into the temporary explicit test candidate.
#import "DecimaEngine.h"
#import "MemoryAccess.h"
#import "MHTProtocol.h"
#import <AppKit/AppKit.h>
static NSString *token;
static NSDictionary *last;
static BOOL inFlight;
static void snapshot(void){@autoreleasepool{
    MHTDSOwner owner={0};MHTDSVitals v={0};NSMutableDictionary *state=[NSMutableDictionary new];
    if(MHTDSCaptureOwner(&owner) && MHTDSReadVitals(owner,&v)){
        [state addEntriesFromDictionary:@{@"owner":@(owner.actor),@"actor":@(owner.actor),@"entity":@(owner.entity),@"vitals":@(owner.vitals),
            @"blood":@(v.blood),@"maximumBlood":@(v.maximumBlood),@"consciousness":@(v.consciousness),@"maximumConsciousness":@(v.maximumConsciousness),
            @"stamina":@(v.stamina),@"maximumStamina":@(v.maximumStamina),@"fatigue":@(v.fatigue),@"battery":@(v.battery),@"maximumBattery":@(v.maximumBattery),
            @"shoes":@(v.shoes),@"maximumShoes":@(v.maximumShoes),@"crystals":@(v.crystals),@"bbStress":@(v.bbStress),
            @"standReserve":@(v.standReserve),@"maximumStandReserve":@(v.maximumStandReserve)}];
        state[@"maximumBBStress"]=@(v.maximumBBStress);state[@"displayBBStress"]=@(v.displayBBStress);
        float scales[3];if(MHTDSReadTime(owner,scales))state[@"timeScales"]=@[@(scales[0]),@(scales[1]),@(scales[2])];
        float bases[2],capacity[2];if(MHTDSReadCapacity(owner,bases,capacity)){
            state[@"capacityBases"]=@[@(bases[0]),@(bases[1])];state[@"capacityLimits"]=@[@(capacity[0]),@(capacity[1])];
        }
    }
    state[@"lastAction"]=last ?: @{};state[@"engineThread"]=@(MHTDSIsEngineThread());
    uintptr_t debug=0,mouse=0;int32_t mode=-1;uint8_t visible=0,clamped=0;
    MTReadMemory((void *)MHTDSAddress(0x1060aac90),&debug,8);
    MTReadMemory((void *)MHTDSAddress(0x10638fc40),&mouse,8);
    if(debug && MTReadMemory((void *)(debug+0x24),&mode,4))state[@"godMode"]=@(mode);
    if(mouse && MTReadMemory((void *)(mouse+0x151),&visible,1) && MTReadMemory((void *)(mouse+0x1c4),&clamped,1)){
        state[@"mouseVisible"]=@(visible);state[@"mouseClamped"]=@(clamped);
    }
    MHTPost(@"local.mht.ds.native.state.v1",@{@"version":@1,@"module":@"death-stranding",@"session":token,@"pid":@(getpid()),@"state":state});
}}
static void action(NSDictionary *q){
    MHTDSOwner owner={0};MHTDSVitals v={0};if(!MHTDSCaptureOwner(&owner) || !MHTDSReadVitals(owner,&v) || owner.actor!=[q[@"owner"] unsignedLongLongValue])return;
    NSString *kind=q[@"action"];BOOL accepted=NO;float amount=[q[@"value"] floatValue];
    if([kind isEqual:@"blood"] && amount>=1 && amount<=v.maximumBlood)accepted=MHTDSSetBlood(owner,amount);
    else if([kind isEqual:@"stamina"] && amount>=-v.maximumStamina && amount<=v.maximumStamina)accepted=MHTDSAddStamina(owner,amount);
    else if([kind isEqual:@"fatigue"] && amount>=0 && amount<=10000)accepted=MHTDSSetFatigue(owner,amount);
    else if([kind isEqual:@"standReserve"])accepted=MHTDSAddStandReserve(owner,amount);
    else if([kind isEqual:@"bbStress"] && amount>=0 && amount<=0.75f)accepted=MHTDSSetBBStressRate(owner,amount);
    else if([kind isEqual:@"consciousness"] && amount>=1 && amount<=v.maximumConsciousness){
        ((void(*)(void *,float))MHTDSAddress(0x102dde340))((void *)owner.vitals,amount);accepted=YES;
    }else if([kind isEqual:@"battery"] && amount>=1 && amount<=v.maximumBattery)accepted=MTWriteFloat((void *)owner.component,0x4810,amount);
    else if([kind isEqual:@"shoes"] && amount>=1 && amount<=v.maximumShoes){((void(*)(float))MHTDSAddress(0x102ef9758))(amount);accepted=YES;}
    else if([kind isEqual:@"read"]){
        // Bounded, read-only diagnostics of this exact local owner's structures.
        NSDictionary *areas=@{@"vitals":@[@(owner.vitals),@0x1000],@"component":@[@(owner.component),@0x6000],
            @"parameters":@[@(owner.parameters),@0x8000],@"locomotion":@[@(owner.parameters),@0x8000],
            @"system":@[@(owner.system),@0x24000],@"entity":@[@(owner.entity),@0x6000]};
        NSArray *area=areas[q[@"area"]];NSUInteger offset=[q[@"offset"] unsignedIntegerValue],size=[q[@"size"] unsignedIntegerValue];
        if(area && size>0 && size<=8192 && offset<=[area[1] unsignedIntegerValue] && size<=[area[1] unsignedIntegerValue]-offset){
            NSMutableData *bytes=[NSMutableData dataWithLength:size];
            if(MTReadMemory((void *)([area[0] unsignedLongLongValue]+offset),bytes.mutableBytes,size)){
                last=@{@"serial":q[@"serial"] ?: @0,@"action":kind,@"accepted":@YES,@"bytes":[bytes base64EncodedStringWithOptions:0]};snapshot();return;
            }
        }
    }
    last=@{@"serial":q[@"serial"] ?: @0,@"action":kind ?: @"",@"accepted":@(accepted)};snapshot();
}
__attribute__((constructor))static void begin(void){dispatch_async(dispatch_get_main_queue(),^{
    token=NSProcessInfo.processInfo.environment[@"MHT_SESSION"];if(!token.length || !MHTDSAttachEngine())return;NSMutableOrderedSet *seen=[NSMutableOrderedSet new];
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"local.mht.ds.native.command.v1" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
        NSDictionary *q=MHTDecodeMessage(event.object);if(!MHTAcceptCommand(q,@"death-stranding",token,getpid(),seen,NSDate.date.timeIntervalSince1970))return;MHTDSSchedule(^{action(q);});
    }];
    [NSTimer scheduledTimerWithTimeInterval:.5 repeats:YES block:^(NSTimer *timer){(void)timer;if(inFlight)return;inFlight=YES;MHTDSSchedule(^{snapshot();dispatch_async(dispatch_get_main_queue(),^{inFlight=NO;});});}];
});}
