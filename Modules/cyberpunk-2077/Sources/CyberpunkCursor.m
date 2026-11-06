// SPDX-License-Identifier: GPL-3.0-only
#import "CyberpunkCursor.h"
#import "GameProfile.h"
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#include <stdatomic.h>
static _Atomic(BOOL) active;
static __weak NSView *owner;
static BOOL changedUnlock,changedVisibility;
static uintptr_t base;
static Ivar unlocked;
static IMP unlockIMP,showIMP,hideIMP,hiddenIMP;
static BOOL validate(NSView *view){
    if(!NSThread.isMainThread || !view || object_getClass(view)!=NSClassFromString(@"GameView"))return NO;
    if(!base){
        NSDictionary *identity=MTReadExecutableIdentity(NSBundle.mainBundle.executablePath);
        if(![identity[@"uuid"] isEqual:@"7D7382D0-EADD-36F0-BA1C-CEBEC1D5BEBC"])return NO;
        for(uint32_t i=0;i<_dyld_image_count();i++){
            const struct mach_header_64 *header=(const void *)_dyld_get_image_header(i);
            if(header->filetype==MH_EXECUTE){base=(uintptr_t)header;break;}
        }
    }
    Class cls=object_getClass(view);const char *names[]={"UnLockCursor:","ShowCursor","HideCursor","cursorIsHidden"};
    const char *types[]={"v20@0:8B16","v16@0:8","B16@0:8","B16@0:8"};
    uintptr_t offsets[]={0x1421bf4,0x1422260,0x142235c,0x1423ad4};IMP *methods[]={&unlockIMP,&showIMP,&hideIMP,&hiddenIMP};
    for(int i=0;i<4;i++){
        Method method=class_getInstanceMethod(cls,sel_registerName(names[i]));
        if(!method || strcmp(method_getTypeEncoding(method),types[i]) || (uintptr_t)method_getImplementation(method)!=base+offsets[i])return NO;
        *methods[i]=method_getImplementation(method);
    }
    unlocked=class_getInstanceVariable(cls,"bUnLockCursor");
    return unlocked && !strcmp(ivar_getTypeEncoding(unlocked),"B") && ivar_getOffset(unlocked)>=0 && (size_t)ivar_getOffset(unlocked)<class_getInstanceSize(cls);
}
static BOOL isUnlocked(NSView *view){uint8_t value=0;memcpy(&value,(const uint8_t *)(__bridge const void *)view+ivar_getOffset(unlocked),1);return value==1;}
static BOOL isHidden(NSView *view){return ((BOOL (*)(id,SEL))hiddenIMP)(view,sel_registerName("cursorIsHidden"));}
static void releaseCursor(void){
    NSView *view=owner;
    if(view && validate(view)){
        if(changedUnlock && isUnlocked(view))((void (*)(id,SEL,BOOL))unlockIMP)(view,sel_registerName("UnLockCursor:"),NO);
        // Let the game's original hide routine decide from its current window
        // and gameplay state. No global cursor hide counter is manipulated.
        if(changedVisibility && !isHidden(view) && NSApp.isActive && view.window.isKeyWindow)
            ((BOOL (*)(id,SEL))hideIMP)(view,sel_registerName("HideCursor"));
    }
    owner=nil;changedUnlock=NO;changedVisibility=NO;atomic_store(&active,NO);
}
BOOL CPUpdateOverlayCursor(NSView *view,BOOL wanted){
    if(!NSThread.isMainThread)return NO;
    if(!wanted || !NSApp.isActive || !view.window.isKeyWindow){releaseCursor();return NO;}
    if(owner && owner!=view)releaseCursor();
    if(!validate(view)){releaseCursor();return NO;}
    if(!owner)owner=view;
    if(!isUnlocked(view)){((void (*)(id,SEL,BOOL))unlockIMP)(view,sel_registerName("UnLockCursor:"),YES);changedUnlock=isUnlocked(view);}
    if(isHidden(view)){((void (*)(id,SEL))showIMP)(view,sel_registerName("ShowCursor"));changedVisibility=!isHidden(view);}
    BOOL confirmed=isUnlocked(view) && !isHidden(view);atomic_store(&active,confirmed);if(confirmed)[NSCursor.arrowCursor set];return confirmed;
}
BOOL CPOverlayCursorActive(void){return atomic_load(&active);}
