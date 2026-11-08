// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "Unreal.hpp"

namespace fp::effects {
// All operations run on the original GameThread. The caller supplies the current
// context and selected city; these are checked for a common live World.
struct ScalarResult {
    bool available=false;
    bool invoked=false;
    bool writeReadbackConfirmed=false;
    double value=0;
    NSString *reason=nil;
};
ScalarResult getStockpile(Object worldContext,Object city,Object resource);
ScalarResult setStockpileAbsolute(Object worldContext,Object city,Object resource,int32_t value);
ScalarResult getStatistic(Object worldContext,Object city,Object statistic);
// PXStatisticUtils has no static setter in this build. A real native
// PXCheatManager instance in the same World is required; its CDO is rejected.
ScalarResult setStatisticAbsolute(Object worldContext,Object city,Object statistic,
                                 int32_t value,Object nativeCheatManager={});
}
