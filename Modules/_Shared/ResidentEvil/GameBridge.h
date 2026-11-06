// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
typedef NS_ENUM(NSInteger, RE2TrainerAction) { RE2TrainerPoll, RE2TrainerDisableAll };
@interface RE2TrainerState : NSObject
@property(nonatomic) BOOL ready, overlayMouseActive, selectionPending, commandAccepted;
@property(nonatomic) double updatedAt;
@property(nonatomic,copy) NSDictionary *diagnostics;
@property(nonatomic,copy) NSString *status, *message;
@property(nonatomic,copy) NSArray<RE2FeatureState *> *features;
@property(nonatomic) uint64_t context;
@end
@interface RE2GameBridge : NSObject
@property(nonatomic,readonly) RE2TrainerState *state;
@property(nonatomic,copy) void (^stateChanged)(RE2TrainerState *);
- (instancetype)initWithAdapter:(id<RE2GameAdapter>)adapter;
- (instancetype)initWithAdapter:(id<RE2GameAdapter>)adapter readOnly:(BOOL)readOnly;
- (instancetype)initWithAdapter:(id<RE2GameAdapter>)adapter readOnly:(BOOL)readOnly restoreSelection:(NSDictionary *)selection;
- (void)controlCommand:(NSDictionary *)request completion:(void (^)(RE2TrainerState *state, NSString *error))completion;
- (void)poll;
- (void)performAction:(RE2TrainerAction)action;
- (void)performFeature:(RE2Feature)feature;
- (void)setValue:(double)value forFeature:(RE2Feature)feature;
- (void)setOverlayInteraction:(BOOL)enabled;
@end
