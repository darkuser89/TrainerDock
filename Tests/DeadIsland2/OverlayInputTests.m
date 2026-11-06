// SPDX-License-Identifier: GPL-3.0-only
#import "OverlayInput.h"

static uint8_t *inputObjects[6];
static BOOL inputLive[6],rejectMode;
static int inputTypes[3],uiCalls,gameCalls;
static void *activeController;
static void store(void *object,size_t offset,void *value) { memcpy((char *)object+offset,&value,8); }
static void *controllerClass(void) { return &inputTypes[0]; }
static void *localClass(void) { return &inputTypes[1]; }
static void *viewportClass(void) { return &inputTypes[2]; }
static bool valid(const void *object,bool recurse) { (void)recurse;for(int i=0;i<6;i++)if(object==inputObjects[i])return inputLive[i];return false; }
static bool child(void *a,void *b) { return a==b; }
static void assign(DI2WeakObject *weak,const void *object) { *weak=(DI2WeakObject){0,0};for(int i=0;i<6;i++)if(object==inputObjects[i])*weak=(DI2WeakObject){i+1,1}; }
static void *resolve(const DI2WeakObject *weak) { int i=weak->index-1;return i>=0 && i<6 && weak->serial==1 && inputLive[i] ? inputObjects[i] : NULL; }
static void *controller(const void *world,int player) { (void)world;NSCAssert(player==0,@"local controller only");return activeController; }
static void *viewport(const void *world) { (void)world;return inputObjects[3]; }
static void ui(void *object,void *widget,uint8_t lock) {
    NSCAssert(object==activeController && !widget && lock==0,@"native UIOnly, no capture/lock or game widget");uiCalls++;
    if(rejectMode)return;
    inputObjects[3][0x329]=1;inputObjects[3][0x32a]=0;inputObjects[3][0x32c]=0;
}
static void game(void *object) {
    NSCAssert(object==activeController,@"never refocus a stale controller");gameCalls++;
    inputObjects[3][0x329]=0;inputObjects[3][0x32a]=2;inputObjects[3][0x32c]=1;
}
void DI2TestOverlayInput(void) {
    for(int i=0;i<6;i++){inputObjects[i]=calloc(1,0x600);inputLive[i]=YES;}
    store(inputObjects[1],0x10,controllerClass());store(inputObjects[4],0x10,controllerClass());
    store(inputObjects[2],0x10,localClass());store(inputObjects[5],0x10,localClass());
    store(inputObjects[3],0x10,viewportClass());
    store(inputObjects[1],0x2d0,inputObjects[2]);store(inputObjects[4],0x2d0,inputObjects[5]);
    activeController=inputObjects[1];
    const uint8_t original[]={0,3,1,2};memcpy(inputObjects[3]+0x329,original,4);
    inputObjects[1][0x470]=0xa4; // Adjacent controller bits must survive.
    DI2GameAPI api={.valid=valid,.classIsChildOf=child,.weakAssign=assign,.weakGet=resolve,
        .controllerClass=controllerClass,.localPlayerClass=localClass,.viewportClass=viewportClass,
        .playerController=controller,.worldViewport=viewport,.inputUIOnly=ui,.inputGameOnly=game};
    DI2OverlayInput *input=[[DI2OverlayInput alloc]initWithAPI:api];
    NSCAssert([input updateWorld:inputObjects[0] wanted:YES] && uiCalls==1
        && inputObjects[1][0x470]==0xa5 && inputObjects[1][0x489]==1,@"hidden cursor released with visible arrow");
    for(int i=0;i<10;i++)NSCAssert([input updateWorld:inputObjects[0] wanted:YES],@"keep confirmed UI ownership");
    NSCAssert(uiCalls==1,@"no repeated input mode installation each poll");
    inputObjects[1][0x470]|=0x10;
    [input updateWorld:inputObjects[0] wanted:NO];
    NSCAssert(gameCalls==1 && inputObjects[1][0x470]==0xb4 && inputObjects[1][0x489]==0
        && !memcmp(inputObjects[3]+0x329,original,4),@"restore exact capture/lock/hide values while preserving unrelated bits");
    inputObjects[1][0x470]=1;inputObjects[1][0x489]=1;inputObjects[3][0x329]=1;
    int beforeUI=uiCalls,beforeGame=gameCalls;
    NSCAssert([input updateWorld:inputObjects[0] wanted:YES],@"existing menu cursor usable");
    [input updateWorld:inputObjects[0] wanted:NO];
    NSCAssert(beforeUI==uiCalls && beforeGame==gameCalls && inputObjects[1][0x470]==1,@"do not replace existing menu focus or hide menu cursor");
    inputObjects[1][0x470]=0;inputObjects[1][0x489]=0;memcpy(inputObjects[3]+0x329,original,4);
    rejectMode=YES;NSCAssert(![input updateWorld:inputObjects[0] wanted:YES],@"rejected native mode not reported active");rejectMode=NO;
    NSCAssert(inputObjects[1][0x470]==0 && inputObjects[1][0x489]==0
        && !memcmp(inputObjects[3]+0x329,original,4),@"partial cursor change rolled back after failed mode setup");
    [input updateWorld:inputObjects[0] wanted:YES];
    // A game menu subsequently replaces UIOnly with its own mode.
    inputObjects[3][0x32c]=2;beforeGame=gameCalls;
    [input updateWorld:inputObjects[0] wanted:NO];
    NSCAssert(beforeGame==gameCalls && inputObjects[1][0x470]==1 && inputObjects[3][0x32c]==2,@"later game menu owns its cursor and input mode");
    inputObjects[1][0x470]=0;memcpy(inputObjects[3]+0x329,original,4);
    [input updateWorld:inputObjects[0] wanted:YES];activeController=inputObjects[4];beforeGame=gameCalls;
    NSCAssert([input updateWorld:inputObjects[0] wanted:YES] && beforeGame==gameCalls,@"controller replacement does not refocus stale owner");
    [input updateWorld:inputObjects[0] wanted:NO];
    NSCAssert(!memcmp(inputObjects[3]+0x329,original,4),@"new controller receives clean capture baseline");
    [input updateWorld:inputObjects[0] wanted:YES];inputLive[4]=NO;[input updateWorld:NULL wanted:NO];
    NSCAssert(!memcmp(inputObjects[3]+0x329,original,4),@"destroyed controller never dereferenced; surviving viewport restored");
    inputLive[4]=YES;store(inputObjects[4],0x2d0,NULL);
    NSCAssert(![input updateWorld:inputObjects[0] wanted:YES],@"remote/nonlocal controller rejected");
    for(int i=0;i<6;i++)free(inputObjects[i]);
    puts("Overlay input checks passed: native mouse release, exact restoration, existing menus, partial failures, controller changes and dead owners.");
}
