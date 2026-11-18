// SPDX-License-Identifier: GPL-3.0-only
// Synthetic fixtures exercise the real resource backend, never shipped in a module.
#import <Foundation/Foundation.h>
#define FPReadAt FPResourceFixtureReadAt
#define FPOriginalSymbol FPResourceFixtureOriginalSymbol
#define FPCaptureOwner FPResourceFixtureCaptureOwner
#define FPSameOwner FPResourceFixtureSameOwner
#define FPResourceEffect FPResourceFixtureEffect
#define FPResourceAction FPResourceFixtureAction
#define FPResourceRelease FPResourceFixtureRelease
#import "../../Modules/frostpunk/Sources/FrostpunkResources.m"
#import "TrainerFeatures.h"
#import <mach/mach_vm.h>
#include <assert.h>
#include <limits.h>
#include <math.h>
#include <string.h>

enum { FixtureRecordCount = 9 };
static unsigned char economy[0x2250], config[0x180], records[FixtureRecordCount][0x70];
static void *entries[FixtureRecordCount];
static const char *names[FixtureRecordCount] = {"Coal", "Wood", "Augmentation parts", "Steel", "Bodies",
    "Wooden Materials", "Steel Plates", "Steam Tools", "Food Rations"};
static FPOwner current;
static unsigned setterCalls, capacityCalls, resolveCalls, recordReads;
static int maximumNativeAddition;
static BOOL wrongSetterOwner, nativeHonorsCapacity;

BOOL FPReadAt(const void *object, size_t offset, void *result, size_t length) {
    if (!object || !result || !length || (uintptr_t)object > UINTPTR_MAX-offset) return NO;
    uintptr_t address = (uintptr_t)object + offset;
    if (address >= (uintptr_t)records && address < (uintptr_t)records+sizeof(records)) recordReads++;
    mach_vm_size_t actual = 0;
    return mach_vm_read_overwrite(mach_task_self(),address,length,(mach_vm_address_t)result,&actual)==KERN_SUCCESS && actual==length;
}
FPOwner FPCaptureOwner(void) {return current;}
BOOL FPSameOwner(FPOwner left, FPOwner right) {
    return left.game==right.game && left.state==right.state && left.economy==right.economy &&
        left.economyConfig==right.economyConfig && left.generation==right.generation && left.gameplay==right.gameplay;
}
static int field(int index, size_t offset) {int value=0;memcpy(&value,records[index]+offset,sizeof(value));return value;}
static void setInt(int index, size_t offset, int value) {memcpy(records[index]+offset,&value,sizeof(value));}
static int indexOf(const void *entry) {for(int i=0;i<FixtureRecordCount;i++)if(entry==entries[i])return i;return -1;}
static void changeResource(void *owner,const void *entry,int delta,int kind) {
    setterCalls++;
    wrongSetterOwner |= owner!=current.economy;
    assert(kind==0);
    int i=indexOf(entry);assert(i>=0);
    int added=MIN(delta,maximumNativeAddition);
    if(nativeHonorsCapacity) added=MIN(added,MAX(0,field(i,12)-field(i,8)));
    setInt(i,8,field(i,8)+added);
}
static void changeCapacity(void *owner,const void *entry,int delta) {
    capacityCalls++;
    wrongSetterOwner |= owner!=current.economy;
    int i=indexOf(entry);assert(i>=0);
    setInt(i,12,field(i,12)+delta);
}
static void *getEntry(const void *link) {resolveCalls++;void *entry=NULL;memcpy(&entry,link,sizeof(entry));return entry;}
void *FPOriginalSymbol(const char *name) {
    if(!strcmp(name,"_ZN16FrostpunkEconomy14ChangeResourceEPK22FrostpunkResourceEntryi19eResourceChangeType")) return (void *)changeResource;
    if(!strcmp(name,"_ZN16FrostpunkEconomy22ChangeResourceCapacityEPK22FrostpunkResourceEntryi")) return (void *)changeCapacity;
    if(!strcmp(name,"_ZNK9EntryLinkI22FrostpunkResourceEntryE8GetEntryEv")) return (void *)getEntry;
    return NULL;
}
static void reset(void) {
    FPResourceRelease(current);
    uint64_t generation=current.generation+1;
    memset(economy,0,sizeof(economy));memset(config,0,sizeof(config));memset(records,0,sizeof(records));
    for(int i=0;i<FixtureRecordCount;i++) {
        entries[i]=(void *)&names[i];
        memcpy(records[i],&entries[i],sizeof(void *));setInt(i,8,10+i);setInt(i,12,500+i);records[i][16]=1;
    }
    void *table=records;int count=4;
    memcpy(economy+0x2240,&table,sizeof(table));memcpy(economy+0x2248,&count,sizeof(count));
    memcpy(config+0xe8,&entries[0],sizeof(void *));memcpy(config+0x128,&entries[1],sizeof(void *));
    memcpy(config+0x118,&entries[3],sizeof(void *));
    current=(FPOwner){.game=economy,.state=config,.economy=economy,.economyConfig=config,.gameplay=YES,.generation=generation};
    setterCalls=capacityCalls=resolveCalls=recordReads=0;wrongSetterOwner=NO;maximumNativeAddition=INT_MAX;nativeHonorsCapacity=NO;
}
void MHTFrostpunkResourceContractTests(void) {@autoreleasepool {
    reset();
    NSDictionary *state=FPResourceEffect(current,MTFeatureCoal,YES,1000);
    assert([state[@"available"] boolValue] && ![state[@"active"] boolValue]);
    assert(!setterCalls && !capacityCalls); // A query can never repeat an action.
    unsigned resolves=resolveCalls;
    for(int i=0;i<20;i++) FPResourceEffect(current,MTFeatureCoal,YES,1000);
    assert(resolveCalls==resolves && !setterCalls && !capacityCalls);
    NSString *note=FPResourceAction(current,MTFeatureCoal,1000);
    assert([note containsString:@"bestätigt"] && setterCalls==1 && field(0,8)==1010);
    for(int i=0;i<20;i++) FPResourceEffect(current,MTFeatureCoal,YES,1000);
    assert(setterCalls==1);

    reset();
    for(NSNumber *number in @[@(-1),@(0),@(0.5),@(1000001),@(NAN),@(INFINITY)])
        FPResourceAction(current,MTFeatureCoal,number.doubleValue);
    assert(!setterCalls);
    FPResourceAction(current,MTFeatureSteamCores,10001);assert(!setterCalls);
    setInt(0,8,INT_MAX-1);FPResourceAction(current,MTFeatureCoal,2);assert(!setterCalls);
    setInt(0,8,10);records[0][16]=0;state=FPResourceEffect(current,MTFeatureCoal,NO,0);
    assert([state[@"available"] boolValue] && [state[@"note"] containsString:@"ausgeblendet"]);
    note=FPResourceAction(current,MTFeatureCoal,1);
    assert(setterCalls==1 && field(0,8)==11 && [note containsString:@"bestätigt"] && [note containsString:@"ausgeblendet"]);
    state=FPResourceEffect(current,MTFeatureStructuralProfiles,NO,0);assert(![state[@"available"] boolValue]);
    FPResourceAction(current,MTFeatureStructuralProfiles,1);assert(setterCalls==1);
    records[2][16]=0;state=FPResourceEffect(current,MTFeatureProstheses,NO,0);
    assert([state[@"available"] boolValue] && [state[@"note"] containsString:@"ausgeblendet"]);
    FPResourceAction(current,MTFeatureProstheses,1);assert(setterCalls==2 && field(2,8)==13);

    reset();
    maximumNativeAddition=5;
    note=FPResourceAction(current,MTFeatureCoal,10);
    assert(setterCalls==1 && field(0,8)==15 && [note containsString:@"Nur 5 von 10"] && ![note containsString:@"bestätigt"]);
    FPResourceEffect(current,MTFeatureCoal,YES,10);assert(setterCalls==1);

    reset();
    FPResourceEffect(current,MTFeatureCoal,NO,0);
    void *replacement=entries[3];memcpy(records[0],&replacement,sizeof(replacement));
    FPResourceAction(current,MTFeatureCoal,1);assert(!setterCalls);

    reset();
    state=FPResourceEffect(current,MTFeatureStorage,NO,0);assert(!capacityCalls && ![state[@"active"] boolValue]);
    state=FPResourceEffect(current,MTFeatureStorage,YES,0);assert([state[@"active"] boolValue] && capacityCalls==4);
    for(int i=0;i<4;i++) assert(field(i,12)==1000000);
    for(int i=0;i<20;i++) FPResourceEffect(current,MTFeatureStorage,YES,0);
    assert(capacityCalls==4); // Equal confirmed values must not trigger setters.
    FPResourceEffect(current,MTFeatureStorage,NO,0);assert(capacityCalls==8);
    for(int i=0;i<4;i++) assert(field(i,12)==500+i && field(i,8)==10+i);
    FPResourceEffect(current,MTFeatureStorage,YES,0);assert(capacityCalls==12);
    FPResourceRelease(current);assert(capacityCalls==16);

    reset();
    int expandedCount=FixtureRecordCount;memcpy(economy+0x2248,&expandedCount,sizeof(expandedCount));
    memcpy(config+0x148,&entries[5],sizeof(void *));memcpy(config+0x168,&entries[6],sizeof(void *));
    memcpy(config+0x158,&entries[7],sizeof(void *));memcpy(config+0xf8,&entries[8],sizeof(void *));
    records[2][16]=records[5][16]=records[6][16]=records[7][16]=0;
    nativeHonorsCapacity=YES;
    state=FPResourceEffect(current,MTFeatureStorage,YES,0);
    assert([state[@"active"] boolValue] && capacityCalls==8 && !setterCalls);
    for(int i=0;i<FixtureRecordCount;i++)
        assert(field(i,12)==(i==4 ? 504 : 1000000) && field(i,8)==10+i);
    unsigned initialResolutions=resolveCalls;
    FPResourceEffect(current,MTFeatureStorage,YES,0);
    assert(capacityCalls==8 && resolveCalls==initialResolutions);
    for(NSNumber *feature in @[@(MTFeatureProstheses),@(MTFeatureStructuralProfiles),@(MTFeatureSteelComposites),@(MTFeatureSteamExchangers)]) {
        note=FPResourceAction(current,feature.integerValue,1000);
        assert([note containsString:@"bestätigt"] && [note containsString:@"ausgeblendet"]);
    }
    assert(setterCalls==4 && field(4,8)==14 && field(4,12)==504);
    FPResourceEffect(current,MTFeatureStorage,NO,0);
    assert(capacityCalls==16);
    for(int i=0;i<FixtureRecordCount;i++) assert(field(i,12)==500+i);
    assert(field(2,8)==1012 && field(5,8)==1015 && field(6,8)==1016 && field(7,8)==1017 && field(4,8)==14);

    reset();
    FPResourceEffect(current,MTFeatureStorage,YES,0);
    setInt(0,12,1000010); // A different owner of the value changed this resource.
    FPResourceEffect(current,MTFeatureStorage,NO,0);
    assert(field(0,12)==1000010 && capacityCalls==7);
    for(int i=1;i<4;i++) assert(field(i,12)==500+i);

    reset();
    FPResourceEffect(current,MTFeatureStorage,YES,0);
    FPOwner stale=current;current.generation++;
    FPResourceRelease(stale);assert(capacityCalls==4);
    FPResourceAction(stale,MTFeatureCoal,100);assert(!setterCalls && !wrongSetterOwner);

    reset();
    int badCount=65;memcpy(economy+0x2248,&badCount,sizeof(badCount));
    recordReads=0;state=FPResourceEffect(current,MTFeatureCoal,YES,1000);
    assert(![state[@"available"] boolValue] && !setterCalls && !capacityCalls && !recordReads);
    badCount=0;memcpy(economy+0x2248,&badCount,sizeof(badCount));FPResourceAction(current,MTFeatureCoal,1);assert(!setterCalls);
    badCount=4;memcpy(economy+0x2248,&badCount,sizeof(badCount));
    void *invalid=(void *)(UINTPTR_MAX-8);memcpy(economy+0x2240,&invalid,sizeof(invalid));
    state=FPResourceEffect(current,MTFeatureStorage,YES,0);assert(![state[@"available"] boolValue] && !capacityCalls);
    FPResourceRelease(current);
    puts("Frostpunk resource contracts: action isolation, native readback, ranges, bounded cache, lease rollback, foreign values and stale owners passed (synthetic only).");
}}
