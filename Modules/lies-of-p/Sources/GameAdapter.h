// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "TrainerFeatures.h"
typedef NS_ENUM(NSInteger, MTSessionKind) { MTSessionUnsupported, MTSessionLoading, MTSessionSolo, MTSessionNetwork };
@interface MTGameContext : NSObject
@property(nonatomic) MTSessionKind kind;
@property(nonatomic,copy) NSString *identity, *note;
@end
@protocol MTGameAdapter <NSObject>
// Schedule on the engine's actual gameplay thread. A random background queue is NOT sufficient.
- (void)onGameThread:(dispatch_block_t)work;
// identity must change when the world, player, inventory ownership or relevant session changes.
- (MTGameContext *)captureContext;
// Release only this adapter's effects and baselines, preserving user choices in the bridge.
- (void)releaseEffects;
// Return active=YES only after successful readback; use engine weak handles for native owners.
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value;
- (NSString *)performOneShot:(MTFeature)feature value:(double)value;
// Cursor/UI ownership is independent of the solo gate. Restore before releasing ownership.
- (BOOL)setOverlayInteraction:(BOOL)wanted;
@end
@interface MTUnsupportedAdapter : NSObject <MTGameAdapter>
@end
FOUNDATION_EXPORT id<MTGameAdapter> MTCreateGameAdapter(void);
