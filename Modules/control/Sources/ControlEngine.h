// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#include <stdint.h>
// Every store build must match all five pinned images before native access.
FOUNDATION_EXPORT BOOL MHTControlEngineIdentity(void);
FOUNDATION_EXPORT uintptr_t MHTControlMainImage(void);
FOUNDATION_EXPORT uintptr_t MHTControlCoreImage(void);
FOUNDATION_EXPORT BOOL MHTControlOnEngineFrame(void);
FOUNDATION_EXPORT void *MHTControlServer(void);
FOUNDATION_EXPORT BOOL MHTControlRead(uintptr_t address,void *result,size_t size);
FOUNDATION_EXPORT BOOL MHTControlWrite(uintptr_t address,const void *value,size_t size);
FOUNDATION_EXPORT NSString *MHTControlType(uintptr_t object);
FOUNDATION_EXPORT void MHTControlSchedule(dispatch_block_t work);
FOUNDATION_EXPORT void MHTControlSetMaintenance(dispatch_block_t work);
FOUNDATION_EXPORT BOOL MHTControlSetSimulationRate(float rate);
FOUNDATION_EXPORT float MHTControlSimulationRate(void);
#if defined(MHT_CONTROL_TESTING)
FOUNDATION_EXPORT void MHTControlExternalFrame(uintptr_t mainImage,uintptr_t coreImage,void *server);
FOUNDATION_EXPORT void MHTControlSetTestObserver(dispatch_block_t work);
#endif

// Addresses are selected from the complete, matching store build, never mixed.
typedef NS_ENUM(NSUInteger,MHTControlSymbol) {
 MHTControlNotifyFloat, MHTControlNotifyBool, MHTControlHealthVT,
 MHTControlResourceVT, MHTControlInventoryVT, MHTControlPlayerVT,
 MHTControlAssistVT, MHTControlMovementVT, MHTControlArmorVT,
 MHTControlStackVT, MHTControlLootVT, MHTControlServerVT,
 MHTControlServerUpdate, MHTControlHealthInvulnerable,
 MHTControlHealthNormalized, MHTControlDatabase,
 MHTControlRunner, MHTControlSession, MHTControlAvatar,
 MHTControlWindow, MHTControlMouse, MHTControlSymbolCount
};
FOUNDATION_EXPORT uintptr_t MHTControlAddress(MHTControlSymbol symbol);
FOUNDATION_EXPORT NSString *MHTControlBuildLabel(void);
