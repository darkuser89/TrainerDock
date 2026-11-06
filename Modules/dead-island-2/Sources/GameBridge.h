// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "TrainerFeatures.h"

typedef NS_ENUM(NSInteger, DI2TrainerAction) {
    DI2TrainerPoll, DI2TrainerHealth, DI2TrainerStamina, DI2TrainerAmmo,
    DI2TrainerCash1000, DI2TrainerCash10000, DI2TrainerDisableAll
};
@interface DI2TrainerState : NSObject
@property(nonatomic) BOOL ready, healthAvailable, staminaAvailable, ammoAvailable;
@property(nonatomic) BOOL healthEnabled, staminaEnabled, ammoEnabled;
@property(nonatomic) BOOL overlayMouseActive;
@property(nonatomic, copy) NSString *status, *message;
@property(nonatomic, strong) NSNumber *cash, *staminaValue, *staminaMaximum, *ammoValue;
@property(nonatomic, copy) NSArray<DI2FeatureState *> *features;
// Initial loading polls must not erase a saved selection; explicit all-off may.
@property(nonatomic) BOOL selectionCanBeSaved;
@property(nonatomic) uint64_t context;
@end

@interface DI2GameBridge : NSObject
@property(nonatomic, readonly) DI2TrainerState *state;
@property(nonatomic, copy) void (^stateChanged)(DI2TrainerState *);
- (void)restoreSelection:(NSDictionary *)selection;
- (void)poll;
- (void)performAction:(DI2TrainerAction)action;
- (void)setWanted:(BOOL)wanted forFeature:(DI2Feature)feature;
- (void)performFeature:(DI2Feature)feature;
- (void)setValue:(double)value forFeature:(DI2Feature)feature;
- (void)setOverlayInteraction:(BOOL)enabled;
@end
