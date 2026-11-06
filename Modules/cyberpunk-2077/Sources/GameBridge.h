// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
typedef NS_ENUM(NSInteger, MTTrainerAction) { MTTrainerPoll, MTTrainerDisableAll };
@interface MTTrainerState : NSObject
@property(nonatomic) BOOL ready, overlayMouseActive;
@property(nonatomic,copy) NSString *status, *message;
@property(nonatomic,copy) NSArray<MTFeatureState *> *features;
@property(nonatomic) uint64_t context;
@property(nonatomic) MTSessionKind sessionKind;
@end
@interface MTGameBridge : NSObject
@property(nonatomic,readonly) MTTrainerState *state;
@property(nonatomic,copy) void (^stateChanged)(MTTrainerState *);
- (instancetype)initWithAdapter:(id<MTGameAdapter>)adapter;
- (void)restoreSelection:(NSDictionary *)selection;
- (void)poll;
- (void)performAction:(MTTrainerAction)action;
- (void)setWanted:(BOOL)wanted forFeature:(MTFeature)feature;
- (void)performFeature:(MTFeature)feature;
- (void)setValue:(double)value forFeature:(MTFeature)feature;
- (void)setOverlayInteraction:(BOOL)enabled;
- (void)setMovementInput:(uint32_t)input;
@end
