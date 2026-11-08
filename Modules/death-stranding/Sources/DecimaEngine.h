// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef struct {
    // entity+0x55a8 is DSPlayerParamComponent (verified native vtable),
    // not the separate DSPlayerController or DSPlayerMover.
    uintptr_t system,pool,actor,entity,component,vitals,parameters;
} MHTDSOwner;
BOOL MHTDSBuildMatches(void);
BOOL MHTDSAttachEngine(void);
void MHTDSSchedule(dispatch_block_t work);
BOOL MHTDSCaptureOwner(MHTDSOwner *owner);
BOOL MHTDSIsEngineThread(void);
uintptr_t MHTDSAddress(uintptr_t original);
void MHTDSSetMaintenance(dispatch_block_t work);
typedef struct {
    float blood,maximumBlood,consciousness,maximumConsciousness,stamina,maximumStamina,fatigue;
    float battery,maximumBattery,shoes,maximumShoes,bbStress;
    float standReserve,maximumStandReserve;
    float maximumBBStress,displayBBStress;
    int32_t crystals,maximumCrystals;
} MHTDSVitals;
BOOL MHTDSReadVitals(MHTDSOwner owner,MHTDSVitals *vitals);
BOOL MHTDSSetBlood(MHTDSOwner owner,float amount);
BOOL MHTDSFillConsciousness(MHTDSOwner owner);
BOOL MHTDSAddStamina(MHTDSOwner owner,float amount);
BOOL MHTDSSetFatigue(MHTDSOwner owner,float amount);
BOOL MHTDSRecoverBattery(MHTDSOwner owner);
BOOL MHTDSRecoverShoes(MHTDSOwner owner);
BOOL MHTDSSetCrystals(MHTDSOwner owner,int32_t amount);
BOOL MHTDSResourceFull(float current,float maximum);
BOOL MHTDSAddStandReserve(MHTDSOwner owner,float amount);
BOOL MHTDSSetBBStressRate(MHTDSOwner owner,float rate);
void MHTDSClearBBRequest(uintptr_t system);
typedef struct {uintptr_t system;int32_t identifier;float value;BOOL owned;} MHTDSTimeControl;
typedef struct {
    float scales[3],duration,transition,endingScales[3],endingDuration,reserved,removeTransition;
    uint8_t retained,padding[3];
    uintptr_t curves[3],sound;
    int32_t name,identifier;
    uint32_t priority,paddingEnd;
} MHTDSTimeRequest;
BOOL MHTDSPrepareTimeRequest(float value,MHTDSTimeRequest *request);
BOOL MHTDSReadTime(MHTDSOwner owner,float scales[3]);
BOOL MHTDSSetTime(MHTDSOwner owner,float value,MHTDSTimeControl *control);
void MHTDSClearTime(MHTDSTimeControl *control);
typedef struct {MHTDSOwner owner;float previous[2],written[2];BOOL owned;} MHTDSCapacityControl;
BOOL MHTDSReadCapacity(MHTDSOwner owner,float bases[2],float effective[2]);
BOOL MHTDSSetCapacity(MHTDSOwner owner,float value,MHTDSCapacityControl *control);
void MHTDSClearCapacity(MHTDSCapacityControl *control);
void MHTDSSetApplicationActive(BOOL active);
BOOL MHTDSOverlayInteraction(BOOL wanted);
