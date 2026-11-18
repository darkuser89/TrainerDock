// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach_vm.h>
#import "../../Modules/frostpunk/Sources/FrostpunkEngine.h"
#import "../../Modules/frostpunk/Sources/FrostpunkResources.h"
#import "../../Modules/frostpunk/Sources/GameProfile.h"
#import "../../Modules/frostpunk/Sources/MemoryAccess.h"
#import "../../Modules/frostpunk/Sources/TrainerFeatures.h"
#include <assert.h>
#include <math.h>
#include <string.h>

// Compile the actual engine path in the test TU with private names. Synthetic
// owners and injected original setters exist only here, never in the product.
static NSUInteger reads, enableCalls, disableCalls, timerCalls, resourceCalls;
static BOOL FPTestReadMemory(const void *p,void *out,size_t n){
    reads++;if(!p || !out || !n)return NO;mach_vm_size_t actual=0;
    return mach_vm_read_overwrite(mach_task_self(),(mach_vm_address_t)p,n,(mach_vm_address_t)out,&actual)==KERN_SUCCESS && actual==n;
}
// Contract fixtures never authorize a real process or profile. Keeping these
// dependencies private also lets generic bridge tests link this fixture TU.
static NSDictionary *FPTestLoadConfiguration(NSString *path,NSError **error){(void)path;(void)error;return nil;}
static NSDictionary *FPTestFindProfile(NSDictionary *config,NSString *identifier){(void)config;(void)identifier;return nil;}
static BOOL FPTestCurrentProcessMatches(NSDictionary *profile,NSString *target){(void)profile;(void)target;return NO;}
static NSDictionary *FPTestResourceEffect(FPOwner owner,NSInteger feature,BOOL on,double value){
    (void)owner;(void)feature;(void)on;(void)value;resourceCalls++;return @{};
}
static NSString *FPTestResourceAction(FPOwner owner,NSInteger feature,double value){(void)owner;(void)feature;(void)value;return @"Test";}
static void FPTestResourceRelease(FPOwner owner){(void)owner;}
@interface FPEngineFixtureApplication : NSObject
@property(nonatomic,getter=isActive) BOOL active;
@end
@implementation FPEngineFixtureApplication @end
static FPEngineFixtureApplication *fixtureApplication;
#define NSApp fixtureApplication
#define MTReadMemory FPTestReadMemory
#define MTLoadConfiguration FPTestLoadConfiguration
#define MTFindProfile FPTestFindProfile
#define MTCurrentProcessMatches FPTestCurrentProcessMatches
#define FPReadAt FPTestReadAt
#define FPOriginalSymbol FPTestOriginalSymbol
#define FPCaptureOwner FPTestCaptureOwner
#define FPSameOwner FPTestSameOwner
#define FPOnGameThread FPTestOnGameThread
#define FPInspect FPTestInspect
#define FPEffect FPTestEffect
#define FPOneShot FPTestOneShot
#define FPReleaseEffects FPTestReleaseEffects
#define FPSetMouse FPTestSetMouse
#define FPResourceEffect FPTestResourceEffect
#define FPResourceAction FPTestResourceAction
#define FPResourceRelease FPTestResourceRelease
#import "../../Modules/frostpunk/Sources/FrostpunkEngine.m"
#undef MTReadMemory

static void testEnable(void *p,uint32_t bits){uint32_t value=0;memcpy(&value,(uint8_t *)p+0x68,4);value|=bits;memcpy((uint8_t *)p+0x68,&value,4);enableCalls++;}
static void testDisable(void *p,uint32_t bits){uint32_t value=0;memcpy(&value,(uint8_t *)p+0x68,4);value&=~bits;memcpy((uint8_t *)p+0x68,&value,4);disableCalls++;}
static void testTimer(void *p,float value){memcpy((uint8_t *)p+0xd0,&value,4);timerCalls++;}
static uint32_t testFlags(void *p){uint32_t value=0;memcpy(&value,(uint8_t *)p+0x68,4);return value;}
extern NSUInteger MHTFrostpunkSDLFixtureCallCount(void);
extern NSUInteger MHTFrostpunkSDLFixtureInvalidWindowCalls(void);
extern void MHTFrostpunkSDLFixtureReset(void *,void *,int,int,int);
extern void MHTFrostpunkSDLFixtureSetFocus(void *,void *);
extern void MHTFrostpunkSDLFixtureDestroyWindow(uint32_t);
extern int MHTFrostpunkSDLFixtureVisible(void);
extern int MHTFrostpunkSDLFixtureGrab(uint32_t);
static BOOL requestMouse(BOOL on){
    __block BOOL result=NO;FPTestOnGameThread(^{result=FPTestSetMouse(on);});drainOriginalBoundary();return result;
}
void MHTFrostpunkEngineContractTests(void){
    uint8_t cheatObject[0x100]={0},timerObject[0x100]={0},secondCheat[0x100]={0};
    FPOwner first={.game=(void *)1,.state=(void *)2,.economy=(void *)3,.cheats=cheatObject,.timer=timerObject,.gameplay=YES,.generation=1};
    FPOwner next=first;next.cheats=secondCheat;next.generation=2;
    enableCheats=testEnable;disableCheats=testDisable;setTimer=testTimer;
    reads=enableCalls=disableCalls=timerCalls=resourceCalls=0;
    buildLease=(CheatLease){0};researchLease=(CheatLease){0};timerLease=(TimerLease){0};cooldownLease=(CooldownLease){0};
    memset(wanted,0,sizeof(wanted));
    // Idle maintenance must not even read a synthetic game owner or scan storage.
    maintain();assert(reads==0 && resourceCalls==0);
    uint32_t foreign=0x8000;memcpy(cheatObject+0x68,&foreign,4);
    assert(cheat(first,YES,4,&buildLease));assert(testFlags(cheatObject)==0x8004 && enableCalls==1);
    assert(cheat(first,YES,4,&buildLease));assert(enableCalls==1);
    (void)cheat(first,NO,4,&buildLease);assert(testFlags(cheatObject)==foreign && disableCalls==1);
    // A pre-existing native cheat belongs to the game, not to this trainer.
    foreign|=4;memcpy(cheatObject+0x68,&foreign,4);
    assert(cheat(first,YES,4,&buildLease));(void)cheat(first,NO,4,&buildLease);
    assert(testFlags(cheatObject)==foreign && disableCalls==1);
    foreign=0;memcpy(cheatObject+0x68,&foreign,4);
    assert(cheat(first,YES,0x200,&researchLease));
    assert(cheat(next,YES,0x200,&researchLease));(void)cheat(next,NO,0x200,&researchLease);
    assert(testFlags(cheatObject)==0x200 && testFlags(secondCheat)==0);
    assert(enableCalls==3 && disableCalls==2);
    float original=1;memcpy(timerObject+0xd0,&original,4);
    assert(timer(first,YES,2));assert(timerCalls==1);
    assert(timer(first,YES,2));assert(timerCalls==1);
    (void)timer(first,NO,1);float readback=0;memcpy(&readback,timerObject+0xd0,4);assert(readback==1 && timerCalls==2);
    assert(timer(first,YES,2));float foreignSpeed=0.75f;memcpy(timerObject+0xd0,&foreignSpeed,4);
    (void)timer(first,NO,1);memcpy(&readback,timerObject+0xd0,4);assert(readback==foreignSpeed);
    assert(!timer(first,YES,NAN) && !timer(first,YES,100));
    assert(!FPTestReadAt((void *)UINTPTR_MAX,1,&readback,4));
    assert(!FPTestReadAt(NULL,0,&readback,4));
    memset(wanted,0,sizeof(wanted));buildLease=(CheatLease){0};researchLease=(CheatLease){0};timerLease=(TimerLease){0};
    wanted[MTFeatureStorage]=YES;reads=resourceCalls=0;maintain();assert(reads==0 && resourceCalls==0);wanted[MTFeatureStorage]=NO;
    // A failed real preparation must still complete work on the already verified
    // native boundary. It must not touch a game owner, effect, or SDL capture.
    prepared=NO;attempted=NO;inFrame=NO;prepareFault=nil;mouseWanted=NO;
    NSUInteger sdlBefore=MHTFrostpunkSDLFixtureCallCount(),enableBefore=enableCalls,disableBefore=disableCalls,timerBefore=timerCalls;
    __block NSUInteger completed=0;
    FPTestOnGameThread(^{
        assert(inFrame && !prepared);
        NSDictionary *snapshot=FPTestInspect();
        assert([snapshot[@"kind"] integerValue]==0 && [snapshot[@"note"] isEqual:@"Trainerprofil konnte nicht gelesen werden."]);
        assert(!FPTestSetMouse(YES));FPTestReleaseEffects();completed++;
    });
    drainOriginalBoundary();assert(completed==1 && jobs.count==0 && !inFrame && attempted && !prepared && !mouseWanted);
    FPTestOnGameThread(^{assert([FPTestInspect()[@"kind"] integerValue]==0);completed++;});
    drainOriginalBoundary();assert(completed==2 && jobs.count==0 && !inFrame);
    assert(reads==0 && resourceCalls==0 && enableCalls==enableBefore && disableCalls==disableBefore && timerCalls==timerBefore);
    assert(MHTFrostpunkSDLFixtureCallCount()==sdlBefore);
    // Exercise the actual queued frame path with a keyboard-focused original SDL
    // window while the pointer is over the non-SDL overlay panel.
    fixtureApplication=[FPEngineFixtureApplication new];fixtureApplication.active=YES;
    prepared=YES;attempted=YES;mouseLease=NO;mouseWanted=NO;mouseWindow=NULL;mouseWindowID=0;
    MHTFrostpunkSDLFixtureReset(NULL,(void *)1,0,1,1);
    assert(requestMouse(YES) && mouseWindow==(void *)1 && mouseWindowID==1);
    assert(MHTFrostpunkSDLFixtureVisible()==1 && MHTFrostpunkSDLFixtureGrab(1)==0);
    assert(requestMouse(YES) && originalVisible==0 && originalGrab==1);
    // Fresh requests made by the game while the overlay is open are restored,
    // rather than replacing them with the trainer's temporary unlocked values.
    assert(hookedShow(0)==1);hookedGrab((void *)1,1);
    fixtureApplication.active=NO;assert(!requestMouse(YES));
    assert(!mouseLease && MHTFrostpunkSDLFixtureVisible()==0 && MHTFrostpunkSDLFixtureGrab(1)==1);
    fixtureApplication.active=YES;assert(requestMouse(YES));
    assert(!requestMouse(NO) && !mouseLease);
    assert(MHTFrostpunkSDLFixtureVisible()==0 && MHTFrostpunkSDLFixtureGrab(1)==1);
    assert(requestMouse(YES));fixtureApplication.active=NO;
    assert(hookedShow(1)==1);hookedGrab((void *)1,0);
    assert(!requestMouse(YES) && !mouseLease);
    assert(MHTFrostpunkSDLFixtureVisible()==1 && MHTFrostpunkSDLFixtureGrab(1)==0);
    fixtureApplication.active=YES;MHTFrostpunkSDLFixtureReset(NULL,(void *)1,0,1,1);
    // Pointer focus has priority, and switching ownership releases the previous
    // live window before acquiring the new one.
    MHTFrostpunkSDLFixtureSetFocus((void *)1,(void *)2);assert(requestMouse(YES) && mouseWindow==(void *)1);
    MHTFrostpunkSDLFixtureSetFocus(NULL,(void *)2);assert(requestMouse(YES) && mouseWindow==(void *)2);
    assert(MHTFrostpunkSDLFixtureGrab(1)==1 && MHTFrostpunkSDLFixtureGrab(2)==0);
    MHTFrostpunkSDLFixtureDestroyWindow(2);
    MHTFrostpunkSDLFixtureSetFocus(NULL,(void *)1);assert(requestMouse(YES) && mouseWindow==(void *)1);
    assert(MHTFrostpunkSDLFixtureInvalidWindowCalls()==0);
    assert(!requestMouse(NO));
    MHTFrostpunkSDLFixtureSetFocus(NULL,NULL);assert(!requestMouse(YES) && !mouseLease);
    assert(!requestMouse(NO));prepared=NO;mouseWanted=NO;fixtureApplication=nil;
    NSLog(@"Frostpunk engine contracts: idle, native setters, restoration, unsupported completion and SDL keyboard-focus/window-lifetime contracts passed.");
}
