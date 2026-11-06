// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "TrainerFeatures.h"
typedef NS_ENUM(NSInteger, RE2SessionKind) { RE2SessionUnsupported, RE2SessionLoading, RE2SessionSolo, RE2SessionNetwork };
@interface RE2GameContext : NSObject
@property(nonatomic) RE2SessionKind kind;
@property(nonatomic,copy) NSString *identity, *note;
@end
@protocol RE2GameAdapter <NSObject>
// Schedule on the engine's actual gameplay thread. A random background queue is NOT sufficient.
- (void)onGameThread:(dispatch_block_t)work;
// identity must change when the world, player, inventory ownership or relevant session changes.
- (RE2GameContext *)captureContext;
// Release only this adapter's effects and baselines, preserving user choices in the bridge.
- (void)releaseEffects;
// Return active=YES only after successful readback; use engine weak handles for native owners.
- (RE2FeatureState *)applyFeature:(RE2Feature)feature wanted:(BOOL)wanted value:(double)value;
- (NSString *)performOneShot:(RE2Feature)feature value:(double)value;
// Cursor/UI ownership is independent of the solo gate. Restore before releasing ownership.
- (BOOL)setOverlayInteraction:(BOOL)wanted;
@optional
- (NSDictionary *)diagnostics;
@end
@interface RE2UnsupportedAdapter : NSObject <RE2GameAdapter>
@end
id<RE2GameAdapter> RE2CreateGameAdapter(void);
