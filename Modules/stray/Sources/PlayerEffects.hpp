// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "StrayEngine.hpp"
namespace st {
struct PlayerContext {Object world{},pawn{},controller{},life{};bool ready=false;NSString *identity=nil,*note=nil;};
PlayerContext playerContext();
NSDictionary *playerFeature(const PlayerContext &,NSInteger feature,bool wanted,double value);
void releasePlayerEffects();
NSDictionary *playerDiagnostics(const PlayerContext &);
}
