// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "Backend.hpp"
static void deliver(dispatch_block_t work){
 if(!fp::isBound())fp::bind();
 if(fp::onGameThread(work))return;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/10),dispatch_get_main_queue(),^{deliver(work);});
}
@implementation MHTNativeAdapter
- (void)onGameThread:(dispatch_block_t)work {if(work)deliver([work copy]);}
- (MTGameContext *)captureContext{return fp::backend::capture();}
- (void)releaseEffects{fp::backend::release();}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value{return fp::backend::apply(feature,wanted,value);}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value{return fp::backend::perform(feature,value);}
- (BOOL)setOverlayInteraction:(BOOL)wanted{return fp::backend::mouse(wanted);}
@end
