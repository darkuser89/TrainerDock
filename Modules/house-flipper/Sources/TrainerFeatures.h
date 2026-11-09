// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
// Replace this disabled development entry with genuinely implemented native features.
typedef NS_ENUM(NSInteger,MTFeature){MTFeatureMoney,MTFeaturePerkPoints,MTFeatureCount};
typedef struct {
    __unsafe_unretained NSString *title,*shortcut,*detail;
    BOOL implemented,numeric,oneShot,integer;
    double initial,minimum,maximum,step;
    unsigned short key;
    NSUInteger modifiers;
} MTFeatureInfo;
const MTFeatureInfo *MTFeatureInfoAt(MTFeature feature);
@interface MTFeatureState : NSObject
@property(nonatomic) BOOL available,wanted,active;
@property(nonatomic) double value;
@property(nonatomic,copy) NSString *note;
@end
