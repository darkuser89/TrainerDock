// SPDX-License-Identifier: GPL-3.0-only
#import "FrostpunkEngine.h"
#import "FrostpunkResources.h"
#import "GameProfile.h"
#import "MemoryAccess.h"
#import "TrainerFeatures.h"
#import <AppKit/AppKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#include <math.h>
#include <string.h>

// Original SDL ABI. Interposition redirects only imported calls, never code bytes.
extern int SDL_PollEvent(void *event);
extern int SDL_ShowCursor(int toggle);
extern void *SDL_GetMouseFocus(void);
extern void *SDL_GetKeyboardFocus(void);
extern uint32_t SDL_GetWindowID(void *window);
extern void *SDL_GetWindowFromID(uint32_t identifier);
extern int SDL_GetWindowGrab(void *window);
extern void SDL_SetWindowGrab(void *window, int enabled);
extern void SDL_WarpMouseInWindow(void *window, int x, int y);

static const uint8_t originalUUID[16]={0x38,0x1a,0x9d,0xb7,0x58,0x49,0x39,0xb1,0x85,0xbc,0x20,0x88,0x61,0x54,0x4e,0x41};
static NSMutableArray<dispatch_block_t> *jobs;
static BOOL prepared, attempted, inFrame, maintaining;
static NSString *prepareFault;
static uint64_t frames, generation;
static uint64_t desiredGeneration;
static FPOwner previousOwner;
static void *gameObject, *economyConfig, *baseGame, *gameplayVtable;
static void **economySlot, **cheatSlot, **timeSlot, **sociotechSlot, **generatorSlot;
static void *(*currentState)(void *);
static BOOL (*loadingScreen)(void *);
static void (*enableCheats)(void *, uint32_t), (*disableCheats)(void *, uint32_t);
static void (*resetLawCooldown)(void *), (*setStress)(void *, float), (*setTimer)(void *, float);
static float (*getStress)(const void *);
static BOOL wanted[MTFeatureCount];
static double speedValue=1;
static BOOL mouseWanted, mouseLease;
static void *mouseWindow;
static uint32_t mouseWindowID;
static int originalVisible, originalGrab;

typedef struct {FPOwner owner; BOOL held; uint32_t added;} CheatLease;
static CheatLease buildLease, researchLease;
typedef struct {FPOwner owner; BOOL held; float original, written;} TimerLease;
static TimerLease timerLease;
typedef struct {FPOwner owner; BOOL held; int64_t original;} CooldownLease;
static CooldownLease cooldownLease;

BOOL FPReadAt(const void *object,size_t offset,void *result,size_t length){
    return object && offset<=UINTPTR_MAX-(uintptr_t)object && length &&
        length-1<=UINTPTR_MAX-((uintptr_t)object+offset) &&
        MTReadMemory((const uint8_t *)object+offset,result,length);
}
static const struct mach_header_64 *validateOriginalImage(void){
    const struct mach_header_64 *h=(const void *)_dyld_get_image_header(0);
    if(!h || h->magic!=MH_MAGIC_64 || h->filetype!=MH_EXECUTE || h->cputype!=CPU_TYPE_X86_64 || h->sizeofcmds>16*1024*1024)return NULL;
    const uint8_t *p=(const uint8_t *)(h+1),*end=p+h->sizeofcmds;
    for(uint32_t i=0;i<h->ncmds;i++){
        if((size_t)(end-p)<sizeof(struct load_command))return NULL;
        const struct load_command *c=(const void *)p;
        if(c->cmdsize<sizeof(*c) || c->cmdsize>(size_t)(end-p))return NULL;
        if(c->cmd==LC_UUID && c->cmdsize>=sizeof(struct uuid_command))return memcmp(((const struct uuid_command *)c)->uuid,originalUUID,16)==0?h:NULL;
        p+=c->cmdsize;
    }
    return NULL;
}
static const struct mach_header_64 *originalImage(void){
    static const struct mach_header_64 *image;static dispatch_once_t once;
    dispatch_once(&once,^{image=validateOriginalImage();});return image;
}
void *FPOriginalSymbol(const char *name){
    const struct mach_header_64 *h=originalImage();if(!h || !name)return NULL;
    void *symbol=dlsym(RTLD_MAIN_ONLY,name);Dl_info info={0};
    if(symbol && dladdr(symbol,&info) && info.dli_fbase==(const void *)h)return symbol;
    // This one original local symbol is not in the export trie. UUID and its
    // original prologue bind the offset; no generic guessed-address fallback.
    if(!strcmp(name,"_ZNK9EntryLinkI22FrostpunkResourceEntryE8GetEntryEv")){
        static const uint8_t prefix[]={0x55,0x48,0x89,0xe5,0x53,0x50,0x48,0x89,0xfb,0x48,0x8d,0x35};
        void *local=(uint8_t *)h+0x13bad0;uint8_t bytes[sizeof(prefix)];
        if(FPReadAt(local,0,bytes,sizeof(bytes)) && !memcmp(bytes,prefix,sizeof(bytes)))return local;
    }
    return NULL;
}
static void queueInit(void){static dispatch_once_t once;dispatch_once(&once,^{jobs=[NSMutableArray new];});}
static void *requiredSymbol(const char *name,NSString *failure){
    void *result=FPOriginalSymbol(name);if(!result && !prepareFault)prepareFault=failure;return result;
}
static BOOL prepare(void){
    if(prepared)return YES;if(attempted || !NSThread.isMainThread)return NO;attempted=YES;
    NSDictionary *environment=NSProcessInfo.processInfo.environment;
    NSDictionary *config=MTLoadConfiguration(environment[@"MHT_CONFIG"],NULL);
    if(!config){prepareFault=@"Trainerprofil konnte nicht gelesen werden.";return NO;}
    NSDictionary *profile=MTFindProfile(config,@"steam-x86_64-15262773");
    if(!profile || ![environment[@"MHT_PROFILE"] isEqual:@"steam-x86_64-15262773"]){prepareFault=@"Das geprüfte Steam-Profil wurde nicht ausgewählt.";return NO;}
    if(!MTCurrentProcessMatches(profile,environment[@"MHT_TARGET"]) || !originalImage()){prepareFault=@"Originalspiel und Trainerprofil stimmen nicht überein.";return NO;}
    gameObject=requiredSymbol("gFrostpunkGame",@"Spielkontext nicht gebunden.");economyConfig=requiredSymbol("gFrostpunkEconomyConfig",@"Ressourcenkonfiguration nicht gebunden.");baseGame=requiredSymbol("gGame",@"Spielzustellung nicht gebunden.");
    economySlot=requiredSymbol("gEconomy",@"Ressourcensystem nicht gebunden.");cheatSlot=requiredSymbol("gCheatSystem",@"Originale Schalterverwaltung nicht gebunden.");timeSlot=requiredSymbol("gTimeSystem",@"Zeitsystem nicht gebunden.");
    sociotechSlot=requiredSymbol("gSociotechSystem",@"Gesetzessystem nicht gebunden.");generatorSlot=requiredSymbol("gGeneratorSystem",@"Generatorsystem nicht gebunden.");
    gameplayVtable=requiredSymbol("_ZTV26FrostpunkGameStateGameplay",@"Stadtkontext nicht gebunden.");
    currentState=requiredSymbol("_ZN13FrostpunkGame19GetCurrentGameStateEv",@"Abfrage des Spielzustands nicht gebunden.");
    loadingScreen=requiredSymbol("_ZNK4Game21IsLoadingScreenActiveEv",@"Abfrage der Ladepause nicht gebunden.");
    enableCheats=requiredSymbol("_ZN20FrostpunkCheatSystem12EnableCheatsE9EnumFlagsI6eCheatE",@"Originale Schalteraktivierung nicht gebunden.");
    disableCheats=requiredSymbol("_ZN20FrostpunkCheatSystem13DisableCheatsE9EnumFlagsI6eCheatE",@"Originale Schaltrücknahme nicht gebunden.");
    resetLawCooldown=requiredSymbol("_ZN24FrostpunkSociotechSystem41ResetRemainingSociotechActivationCooldownEv",@"Gesetzeswartezeit nicht gebunden.");
    setStress=requiredSymbol("_ZN24FrostpunkGeneratorSystem9SetStressEf",@"Generatorsteuerung nicht gebunden.");getStress=requiredSymbol("_ZNK24FrostpunkGeneratorSystem9GetStressEv",@"Generatorrücklesung nicht gebunden.");
    setTimer=requiredSymbol("_ZN5Timer17SetTimeMultiplierEf",@"Spielgeschwindigkeit nicht gebunden.");
    prepared=gameObject && economyConfig && baseGame && economySlot && cheatSlot && timeSlot && sociotechSlot && generatorSlot &&
        gameplayVtable && currentState && loadingScreen && enableCheats && disableCheats && resetLawCooldown && setStress && getStress && setTimer;
    return prepared;
}
static void *slotValue(void **slot){void *value=NULL;(void)FPReadAt(slot,0,&value,sizeof(value));return value;}
BOOL FPSameOwner(FPOwner a,FPOwner b){return a.game==b.game && a.state==b.state && a.economy==b.economy && a.economyConfig==b.economyConfig &&
    a.cheats==b.cheats && a.time==b.time && a.timer==b.timer && a.sociotech==b.sociotech && a.generator==b.generator && a.gameplay==b.gameplay && a.generation==b.generation;}
FPOwner FPCaptureOwner(void){
    FPOwner o={0};if(!inFrame || !prepared)return o;
    o.game=gameObject;o.economyConfig=economyConfig;o.economy=slotValue(economySlot);o.cheats=slotValue(cheatSlot);o.time=slotValue(timeSlot);
    o.sociotech=slotValue(sociotechSlot);o.generator=slotValue(generatorSlot);
    int32_t state=-1;void *vtable=NULL;
    if(FPReadAt(o.game,0x438,&state,4) && state>=0 && state<=5){
        o.state=currentState(o.game);
        o.gameplay=state==1 && FPReadAt(o.state,0,&vtable,8) && vtable==(uint8_t *)gameplayVtable+16 && !loadingScreen(baseGame);
    }
    (void)FPReadAt(o.game,0x3e8,&o.timer,8);
    o.generation=previousOwner.generation;
    if(!FPSameOwner(o,previousOwner)){generation++;o.generation=generation;previousOwner=o;}
    return o;
}
static NSDictionary *stateResult(BOOL available,BOOL active,NSString *note){return @{@"available":@(available),@"active":@(active),@"note":note};}
static BOOL readFlags(FPOwner o,uint32_t *flags){return o.cheats && FPReadAt(o.cheats,0x68,flags,4);}
static BOOL sameCheatOwner(FPOwner a,FPOwner b){return a.game && a.game==b.game && a.cheats && a.cheats==b.cheats;}
static BOOL sameTimerOwner(FPOwner a,FPOwner b){return a.game && a.game==b.game && a.timer && a.timer==b.timer;}
static BOOL cheat(FPOwner o,BOOL on,uint32_t mask,CheatLease *lease){
    if(lease->held && !sameCheatOwner(lease->owner,o))*lease=(CheatLease){0};
    uint32_t flags=0;if(!readFlags(o,&flags))return NO;
    if(on){
        if(!(flags&mask)){enableCheats(o.cheats,mask);if(!readFlags(o,&flags) || !(flags&mask))return NO;
            lease->owner=o;lease->held=YES;lease->added|=mask;}
        return (flags&mask)!=0;
    }
    if(lease->held && (flags&lease->added))disableCheats(o.cheats,flags&lease->added);
    *lease=(CheatLease){0};return NO;
}
static BOOL timer(FPOwner o,BOOL on,double value){
    if(timerLease.held && !sameTimerOwner(timerLease.owner,o))timerLease=(TimerLease){0};
    float now=0;if(!FPReadAt(o.timer,0xd0,&now,4) || !isfinite(now) || now<0 || now>1000)return NO;
    if(!on){if(timerLease.held && now==timerLease.written)setTimer(o.timer,timerLease.original);timerLease=(TimerLease){0};return NO;}
    if(!isfinite(value) || value<0.1 || value>10)return NO;
    float goal=(float)value;
    if(!timerLease.held){timerLease=(TimerLease){.owner=o,.held=YES,.original=now,.written=now};}
    else if(now!=timerLease.written){timerLease.original=now;}
    if(now!=goal)setTimer(o.timer,goal);
    timerLease.written=goal;return FPReadAt(o.timer,0xd0,&now,4) && now==goal;
}
static BOOL lawCooldown(FPOwner o,BOOL on){
    if(cooldownLease.held && !FPSameOwner(cooldownLease.owner,o))cooldownLease=(CooldownLease){0};
    int64_t duration=0;if(!FPReadAt(o.sociotech,0xf8,&duration,8) || duration<0)return NO;
    if(!on){
        // The original reset is an expiration, not a reversible modifier. Stop
        // expiring future laws; do not resurrect a law cooldown already elapsed.
        cooldownLease=(CooldownLease){0};return NO;
    }
    if(duration){resetLawCooldown(o.sociotech);if(!FPReadAt(o.sociotech,0xf8,&duration,8))return NO;}
    cooldownLease=(CooldownLease){.owner=o,.held=YES};return duration==0;
}
static BOOL generatorExists(FPOwner o){void *list=NULL,*entity=NULL;return FPReadAt(o.generator,0x2208,&list,8) && FPReadAt(list,0,&entity,8) && entity;}
static BOOL stress(FPOwner o,BOOL on){
    if(!on)return NO;if(!generatorExists(o))return NO;
    float value=getStress(o.generator);if(!isfinite(value) || value<0 || value>1000000)return NO;
    if(value!=0)setStress(o.generator,0);return getStress(o.generator)==0;
}
NSDictionary *FPInspect(void){
    FPOwner o=FPCaptureOwner();NSString *identity=[NSString stringWithFormat:@"%p:%p:%p:%llu:%d",o.game,o.state,o.economy,(unsigned long long)o.generation,o.gameplay];
    NSString *note=!inFrame?@"Warte auf den originalen Spielrückruf.":!prepared?(prepareFault?:@"Native Anbindung nicht bestätigt."):
        o.gameplay?@"Stadt und originaler Spielrückruf bestätigt.":@"Menü oder Ladepause; wartet auf die Stadt.";
    NSMutableDictionary *result=[@{@"kind":@(!inFrame || !prepared?0:o.gameplay?2:1),@"identity":identity,@"frames":@(frames),@"mainThread":@(NSThread.isMainThread),@"note":note} mutableCopy];
    if(o.gameplay){uint32_t flags=0;float multiplier=0;int64_t duration=0;
        if(readFlags(o,&flags))result[@"cheatFlags"]=@(flags);
        if(FPReadAt(o.timer,0xd0,&multiplier,4) && isfinite(multiplier))result[@"timerMultiplier"]=@(multiplier);
        if(FPReadAt(o.sociotech,0xf8,&duration,8))result[@"lawCooldown"]=@(duration);
        if(generatorExists(o)){float value=getStress(o.generator);if(isfinite(value))result[@"generatorStress"]=@(value);}
    }
    return result;
}
NSDictionary *FPEffect(NSInteger feature,BOOL on,double value){
    if(!inFrame || feature<0 || feature>=MTFeatureCount)return stateResult(NO,NO,@"Kein originaler Spielrückruf.");
    FPOwner o=FPCaptureOwner();if(!o.gameplay)return stateResult(NO,NO,@"Warte auf eine geladene Stadt.");
    desiredGeneration=o.generation;
    if(feature<10){wanted[feature]=on;return FPResourceEffect(o,feature,on,value);}
    wanted[feature]=on;BOOL active=NO,available=YES;
    switch(feature){
        case MTFeatureInstantBuild:active=cheat(o,on,4,&buildLease);break;
        case MTFeatureInstantResearch:active=cheat(o,on,0x200,&researchLease);break;
        case MTFeatureLawCooldown:available=o.sociotech!=NULL;active=available && lawCooldown(o,on);break;
        case MTFeatureGeneratorStress:available=generatorExists(o);active=available && stress(o,on);break;
        case MTFeatureGameSpeed:available=o.timer!=NULL;if(on)speedValue=value;active=available && timer(o,on,value);break;
        default:available=NO;break;
    }
    return stateResult(available,active,!on?@"Eigene Dauerwirkung ausgeschaltet.":active?@"Originalwert gesetzt und zurückgelesen.":@"Warte auf bestätigte Wirkung im Spiel.");
}
NSString *FPOneShot(NSInteger feature,double value){
    if(!inFrame)return @"Kein originaler Spielrückruf.";FPOwner o=FPCaptureOwner();
    return o.gameplay?FPResourceAction(o,feature,value):@"Warte auf eine geladene Stadt.";
}
void FPReleaseEffects(void){
    if(!inFrame || !prepared)return;FPOwner o=FPCaptureOwner();
    memset(wanted,0,sizeof(wanted));
    (void)cheat(o,NO,4,&buildLease);(void)cheat(o,NO,0x200,&researchLease);(void)timer(o,NO,1);FPResourceRelease(o);
    buildLease=(CheatLease){0};researchLease=(CheatLease){0};timerLease=(TimerLease){0};cooldownLease=(CooldownLease){0};
}
static BOOL liveMouseWindow(void){return mouseLease && mouseWindowID && SDL_GetWindowFromID(mouseWindowID)==mouseWindow;}
static void releaseMouse(void){
    if(!mouseLease)return;
    // IDs are resolved in SDL's registry before using the saved window pointer.
    // An old window may have been destroyed during a load or game shutdown.
    if(liveMouseWindow())SDL_SetWindowGrab(mouseWindow,originalGrab);
    SDL_ShowCursor(originalVisible);mouseLease=NO;mouseWindow=NULL;mouseWindowID=0;
}
static BOOL validateMouseLease(void){
    if(mouseLease && !liveMouseWindow())releaseMouse();return mouseLease;
}
static void mouseState(void){
    BOOL on=mouseWanted && NSApp.isActive;
    (void)validateMouseLease();
    if(!on){releaseMouse();return;}
    // The non-focusing AppKit overlay can own the pointer without being an SDL
    // window. Keyboard focus still identifies the original game's SDL window.
    void *focused=SDL_GetMouseFocus();if(!focused)focused=SDL_GetKeyboardFocus();
    if(mouseLease && focused && focused!=mouseWindow)releaseMouse();
    if(!mouseLease && focused){
        uint32_t identifier=SDL_GetWindowID(focused);
        if(identifier && SDL_GetWindowFromID(identifier)==focused){
            mouseWindow=focused;mouseWindowID=identifier;originalVisible=SDL_ShowCursor(-1);
            originalGrab=SDL_GetWindowGrab(focused);mouseLease=YES;
        }
    }
    if(validateMouseLease()){SDL_ShowCursor(1);SDL_SetWindowGrab(mouseWindow,0);}
}
BOOL FPSetMouse(BOOL on){if(!inFrame || !prepared)return NO;mouseWanted=on;mouseState();return on && mouseLease && SDL_ShowCursor(-1)==1 && !SDL_GetWindowGrab(mouseWindow);}
void FPOnGameThread(dispatch_block_t work){if(!work)return;queueInit();@synchronized(jobs){if(jobs.count<64)[jobs addObject:[work copy]];}}
static void maintain(void){
    if(maintaining)return;BOOL any=buildLease.held || researchLease.held || timerLease.held || cooldownLease.held;
    // Storage capacity is persistent data. Its bounded record maintenance belongs
    // to the context poll, never to every SDL frame.
    for(NSInteger i=10;i<MTFeatureCount && !any;i++)any=wanted[i];if(!any)return;
    maintaining=YES;FPOwner o=FPCaptureOwner();
    if(o.gameplay && o.generation==desiredGeneration){
        if(wanted[MTFeatureInstantBuild])(void)cheat(o,YES,4,&buildLease);
        if(wanted[MTFeatureInstantResearch])(void)cheat(o,YES,0x200,&researchLease);
        if(wanted[MTFeatureLawCooldown])(void)lawCooldown(o,YES);
        if(wanted[MTFeatureGeneratorStress])(void)stress(o,YES);
        if(wanted[MTFeatureGameSpeed])(void)timer(o,YES,speedValue);}
    else{FPReleaseEffects();}
    maintaining=NO;
}
// Only hookedPoll's verified original boundary enters here. Separating queue
// completion from successful binding also lets failures return Unsupported,
// rather than retaining a bridge request forever with no response.
static void drainOriginalBoundary(void){
    queueInit();BOOL pending=NO;@synchronized(jobs){pending=jobs.count!=0;}
    if(!prepared && !pending)return;
    (void)prepare();
    @autoreleasepool{
        inFrame=YES;frames++;NSArray *batch=nil;@synchronized(jobs){if(jobs.count){batch=jobs.copy;[jobs removeAllObjects];}}
        @try{for(dispatch_block_t work in batch)work();if(prepared){maintain();if(mouseWanted || mouseLease)mouseState();}}
        @finally{inFrame=NO;}
    }
}
static int hookedPoll(void *event){
    void *caller=__builtin_return_address(0);int result=SDL_PollEvent(event);
    const struct mach_header_64 *image=originalImage();
    // Exactly the empty-event boundary in the original SDLApp::MainLoop, before
    // its Game::Tick call. Other SDL users, worker threads and nested events skip it.
    if(result==0 && !inFrame && image && caller==(uint8_t *)image+0xdb2ae8 && NSThread.isMainThread){
        drainOriginalBoundary();
    }
    return result;
}
static int hookedShow(int toggle){if(validateMouseLease() && toggle>=0){originalVisible=toggle;return SDL_ShowCursor(NSApp.isActive?1:toggle);}return SDL_ShowCursor(toggle);}
static void hookedGrab(void *window,int enabled){if(validateMouseLease() && mouseWindow==window){originalGrab=enabled;SDL_SetWindowGrab(window,NSApp.isActive?0:enabled);}else SDL_SetWindowGrab(window,enabled);}
static void hookedWarp(void *window,int x,int y){if(!validateMouseLease() || window!=mouseWindow || !NSApp.isActive)SDL_WarpMouseInWindow(window,x,y);}
__attribute__((used,section("__DATA,__interpose"))) static const struct {const void *replacement,*original;} interpositions[]={
    {(const void *)hookedPoll,(const void *)SDL_PollEvent},{(const void *)hookedShow,(const void *)SDL_ShowCursor},
    {(const void *)hookedGrab,(const void *)SDL_SetWindowGrab},{(const void *)hookedWarp,(const void *)SDL_WarpMouseInWindow}
};
