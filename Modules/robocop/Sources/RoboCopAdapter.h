// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
#include <stdint.h>
typedef struct { int32_t index,serial; } RCWeak;
typedef struct { void **data; int32_t count,capacity; } RCActorArray;
// Narrow ABI for the inspected arm64 build. No Unreal SDK headers or code hooks.
typedef struct {
    BOOL valid;
    void **worldSlot, **macApplicationSlot, **slateSlot;
    int32_t **oneHitSlot;
    BOOL (*isGameThread)(void);
    void (*gameThreadCall)(dispatch_block_t,NSArray *,bool);
    void (*weakAssign)(RCWeak *,const void *);
    void *(*weakGet)(const RCWeak *);
    bool (*isA)(void *const *,void *);
    void *(*getPlayer)(void *);
    void *(*getController)(void *,int);
    void *(*getComponent)(void *,void *);
    void *(*healthClass)(void), *(*weaponComponentClass)(void), *(*rifleClass)(void);
    void *(*getMovement)(void *), *(*getWeapon)(void *,bool), *(*getProgression)(void *);
    void (*setCanBeDamaged)(void *,bool), (*heal)(void *,float);
    int (*getClipCapacity)(void *);
    void *(*fppRifleClass)(void), *(*aiControllerClass)(void), *(*attributeClass)(void);
    void *(*actorWorld)(void *), *(*getAttributes)(void *), *(*getWorldSettings)(void *,bool,bool);
    void (*getActors)(void *,void *,RCActorArray *), (*freeMemory)(void *);
    bool (*oneHitEnabled)(void *), (*infiniteAmmoEnabled)(void *,bool);
    void (*fillClip)(void *);
    float (*getFireRate)(void *), (*getHitDamage)(void *,bool), (*getTime)(void *);
    void (*setTime)(void *,float);
    int (*getXPRequired)(void *);
    bool (*atMaxLevel)(void *);
    void (*setSkillPoints)(void *,int), (*addXP)(void *,int,uint8_t,bool);
    void *(*getViewport)(void), *(*getGameInstance)(void *);
    bool (*worldIsGame)(void *);
    int (*getNetMode)(void *);
    void (*setCapture)(void *,uint8_t), (*setLock)(void *,uint8_t), (*setHide)(void *,bool);
    void (*setPrecision)(void *,bool,const void *);
    void (*cursorLock)(void *,const int32_t *), (*cursorShow)(void *,bool), (*cursorType)(void *,int);
    void (*ignoreMove)(void *,bool), (*ignoreLook)(void *,bool);
    void (*releaseCapture)(void *,int), (*focusViewport)(void *,int);
} RCNativeAPI;
@interface RCRoboCopAdapter : NSObject <MTGameAdapter>
- (instancetype)initWithAPI:(RCNativeAPI)api; // Synthetic regression tests only.
@end
RCNativeAPI RCResolveNativeAPI(void);
