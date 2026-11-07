// SPDX-License-Identifier: GPL-3.0-only
// Private implementation included inside CrimsonNative.mm's binding namespace.
struct StatOwnership {
    int64_t maximumDelta[3]{}, staticDelta[2]{};
    int64_t previousMinimum[3]{}, appliedMinimum[3]{};
    bool minimumOwned[3]{};
    uint32_t hpSerial=0;
    int64_t hpRate=1000000;
    bool hpOwned=false;

};
std::map<uint32_t,StatOwnership> serverEffects,clientEffects;
const uintptr_t statGetters[]={0x1ac8038,0x1ac8010,0x1ac8040,0x1ac8020,0x1ac8018};
uint16_t statIndex(unsigned kind) {
    void *infos=native<void *(*)(uint16_t)>(0x1b38c48)(2);
    return native<uint16_t(*)(void *)>(statGetters[kind])(infos);
}
template<typename T> bool writeField(void *owner,size_t offset,T value) {
    return MTWriteMemory(static_cast<uint8_t *>(owner)+offset,&value,sizeof(value));
}
bool infiniteStat(void *actor,unsigned kind,bool wanted,StatOwnership &own,double hpRate=1000000) {
    void *status=native<void *(*)(void *)>(0xf4a3a0)(actor);
    if(kind==0) {
        if(wanted==own.hpOwned)return true;
        if(wanted && !own.hpSerial) {
            void *component=read<void *>(read<void *>(actor,0x108),0xf0);
            if(!component)return false;
            own.hpSerial=native<uint32_t(*)(void *)>(0x1b29ad4)(component);
        }
        struct HpMinimumData {uint8_t unused[0x98]{};int64_t rate=1000000,serialOwned=1;} data;
        if(wanted)own.hpRate=llround(hpRate);
        data.rate=own.hpRate;
        uint64_t tick=native<uint64_t(*)()>(0xea8a64)();
        uint32_t error=native<uint32_t(*)(void *,uint32_t,const void *,bool,uint64_t)>(0x1f86384)(status,own.hpSerial,&data,wanted,tick);
        if(error)return false;
        own.hpOwned=wanted;return true;
    }
    uint16_t index=statIndex(kind);
    void *regen=native<void *(*)(void *,uint16_t)>(0x1f88460)(status,index);
    if(!regen)return false;
    int64_t currentMin=read<int64_t>(regen,0x28);
    if(wanted) {
        int64_t maximum=native<int64_t(*)(void *,uint16_t)>(0x1f88598)(status,index);
        if(maximum<=0 || maximum>1000000000000LL)return false;
        if(!own.minimumOwned[kind] || currentMin!=own.appliedMinimum[kind])own.previousMinimum[kind]=currentMin;
        if(!writeField(regen,0x28,maximum))return false;
        own.appliedMinimum[kind]=maximum;own.minimumOwned[kind]=true;
    } else if(own.minimumOwned[kind]) {
        if(currentMin==own.appliedMinimum[kind])writeField(regen,0x28,own.previousMinimum[kind]);
        own.minimumOwned[kind]=false;
    }

    return true;
}
bool applyServerEffect(uint32_t key,unsigned feature,bool wanted,double value) {
    if(!native<bool(*)()>(0xea5a44)())return false;
    void *ctx=native<void *(*)()>(0xc93470)();void *manager=ctx ? read<void *>(ctx) : nullptr;
    if(!manager)return false;
    ActorScope scope=native<ActorScope(*)(void *,uint32_t)>(0x825b2c)(manager,key);
    if(!scope.valid || !scope.actor || read<uint32_t>(scope.actor,0x100)!=key)return false;
    auto &own=serverEffects[key];
    if(feature==0 || feature==2 || feature==4)return infiniteStat(scope.actor,feature/2,wanted,own,1000000);
    void *status=native<void *(*)(void *)>(0xf4a3a0)(scope.actor);
    uint64_t tick=native<uint64_t(*)()>(0xea8a64)();
    if(feature==1 || feature==3 || feature==5) {
        unsigned kind=feature/2;uint16_t index=statIndex(kind);
        int64_t maximum=native<int64_t(*)(void *,uint16_t)>(0x1f88598)(status,index);
        int64_t next=wanted ? llround(value*1000)-(maximum-own.maximumDelta[kind]) : 0;
        int64_t difference=next-own.maximumDelta[kind];
        if(difference)native<void(*)(void *,uint16_t,uint64_t,const int64_t *,bool)>(0x1f8aa00)(status,index,tick,&difference,true);
        own.maximumDelta[kind]+=native<int64_t(*)(void *,uint16_t)>(0x1f88598)(status,index)-maximum;return true;
    }
    if(feature==6 || feature==9) {
        unsigned kind=feature==6 ? 0 : 1;uint16_t index=statIndex(kind+3);
        int64_t current=native<int64_t(*)(void *,uint16_t,uint64_t)>(0x1f85b44)(status,index,tick);
        int64_t next=wanted ? llround((feature==9 ? 10000 : value)*1000)-(current-own.staticDelta[kind]) : 0;
        int64_t difference=next-own.staticDelta[kind],changed=0;
        if(difference)native<void(*)(void *,uint16_t,uint64_t,int64_t,void *,bool,bool,uint8_t,uint16_t,int64_t *)>(0x1f86ff8)(status,index,tick,difference,scope.actor,false,false,19,10,&changed);
        own.staticDelta[kind]+=native<int64_t(*)(void *,uint16_t,uint64_t)>(0x1f85b44)(status,index,tick)-current;return true;
    }
    return false;
}
struct FieldTime {alignas(8) uint8_t bytes[32]{};};
static_assert(sizeof(FieldTime)==32,"Native FieldTime ABI");
bool actorTime(void *actor,FieldTime &time) {
    return native<bool(*)(void *,FieldTime *)>(0xf58ee4)(actor,&time);
}
struct SpeedOwnership {void *gameplay=nullptr;uint8_t before[2][20]{};float applied=1;bool owned=false;} speed;
bool setSpeed(void *gameplay,bool wanted,float value) {
    uint8_t type=5;
    void *tables[]={read<void *>(gameplay,0x1938),read<void *>(gameplay,0x1948)};
    if(!tables[0] || !tables[1])return false;
    if(wanted) {
        if(!speed.owned || speed.gameplay!=gameplay) {
            for(unsigned i=0;i<2;i++)MTReadMemory(static_cast<uint8_t *>(tables[i])+type*20,speed.before[i],20);
            speed.gameplay=gameplay;speed.owned=true;
        }
        native<void(*)(void *,const uint8_t *,float,float,float,float,float,float)>(0x3ffbed4)(gameplay,&type,-1,0,value,value,value,value);
        speed.applied=value;
    } else if(speed.owned && speed.gameplay==gameplay) {
        for(unsigned i=0;i<2;i++) {
            void *slot=static_cast<uint8_t *>(tables[i])+type*20;
            if(read<float>(slot)==speed.applied && read<float>(slot,4)==speed.applied)MTWriteMemory(slot,speed.before[i],20);
        }
        speed={};
    }
    return true;
}
struct DayOwnership {uint16_t field=UINT16_MAX,originalSpeed=0;uint64_t frozenSeconds=0;bool owned=false;} day;
bool setDay(void *actor,unsigned feature,bool wanted) {
    FieldTime time;if(!actorTime(actor,time))return false;
    uint16_t field=native<uint16_t(*)(void *)>(0xf3fa2c)(actor);
    if(day.owned && day.field!=field)day={};
    uint64_t seconds=native<uint64_t(*)(const FieldTime *)>(0xeef008)(&time);
    uint64_t tick=native<uint64_t(*)()>(0xea8a64)();
    tick=std::max(tick,read<uint64_t>(&time,0x18)+1);
    if(feature==10) {
        if(wanted) {
            if(!day.owned){day.field=field;day.originalSpeed=read<uint16_t>(&time,0x16);day.frozenSeconds=seconds;day.owned=true;}
            native<void(*)(FieldTime *,uint64_t)>(0xeeed48)(&time,day.frozenSeconds);
            native<void(*)(FieldTime *,uint64_t,uint16_t)>(0xeef19c)(&time,tick,0);
        } else {
            if(!day.owned)return true;
            if(read<uint16_t>(&time,0x16)!=0){day={};return true;}
            native<void(*)(FieldTime *,uint64_t,uint16_t)>(0xeef19c)(&time,tick,day.originalSpeed);day={};
        }
    } else {
        native<void(*)(FieldTime *,uint64_t)>(0xeeed48)(&time,seconds+3600);
        if(day.owned)day.frozenSeconds+=3600;
    }
    bool loadingScreen=false;uint32_t stage=UINT32_MAX;
    native<void(*)(void *,int,const FieldTime *,const bool *,const uint32_t *)>(0x4443518)(actor,4,&time,&loadingScreen,&stage);
    return true;
}
