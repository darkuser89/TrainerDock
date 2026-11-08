// SPDX-License-Identifier: GPL-3.0-only
#import "Unreal.hpp"
#include <cassert>
#include <cmath>
#include <cstring>
#include <limits>
using namespace fp;
static Property scalar(NSString *type,int size,int at=0){Property p;p.type=type;p.count=1;p.size=size;p.offset=at;return p;}
template<class F>static void rejected(F call){bool threw=false;try{call();}catch(const std::runtime_error &){threw=true;}assert(threw);}
int main(){@autoreleasepool{
    uint8_t b[32];memset(b,0xa5,sizeof(b));Property p=scalar(@"IntProperty",4,8);
    assert(detail::packScalar(p,@(INT32_MIN),b,sizeof(b)));assert([detail::unpackScalar(p,b,sizeof(b)) longLongValue]==INT32_MIN);
    assert(b[7]==0xa5&&b[12]==0xa5);assert(!detail::packScalar(p,@(INT64_MAX),b,sizeof(b)));assert(!detail::packScalar(p,@1.5,b,sizeof(b)));assert(!detail::packScalar(p,@"100",b,sizeof(b)));
    p.offset=30;assert(!detail::packScalar(p,@1,b,sizeof(b)));p.offset=-1;assert(!detail::packScalar(p,@1,b,sizeof(b)));p.offset=0;p.count=2;assert(!detail::packScalar(p,@1,b,sizeof(b)));
    p=scalar(@"UInt64Property",8);assert(detail::packScalar(p,@(UINT64_MAX),b,sizeof(b)));assert([detail::unpackScalar(p,b,sizeof(b)) unsignedLongLongValue]==UINT64_MAX);assert(!detail::packScalar(p,@(-1),b,sizeof(b)));
    p=scalar(@"ByteProperty",1);assert(detail::packScalar(p,@255,b,sizeof(b)));assert(!detail::packScalar(p,@256,b,sizeof(b)));
    p=scalar(@"FloatProperty",4);assert(!detail::packScalar(p,@(INFINITY),b,sizeof(b)));assert(!detail::packScalar(p,@(NAN),b,sizeof(b)));assert(!detail::packScalar(p,@(std::numeric_limits<double>::max()),b,sizeof(b)));assert(detail::packScalar(p,@1.25,b,sizeof(b)));assert([detail::unpackScalar(p,b,sizeof(b)) doubleValue]==1.25);
    p=scalar(@"BoolProperty",1);p.boolMask=4;b[0]=0xa1;assert(detail::packScalar(p,@YES,b,sizeof(b)));assert(b[0]==0xa5);assert(detail::packScalar(p,@NO,b,sizeof(b)));assert(b[0]==0xa1);assert(!detail::packScalar(p,@2,b,sizeof(b)));p.boolMask=255;assert(detail::packScalar(p,@YES,b,sizeof(b)));assert(b[0]==1);p.boolByteOffset=1;assert(!detail::packScalar(p,@YES,b,sizeof(b)));
    p=scalar(@"StructProperty",8);assert(!detail::packScalar(p,@0,b,sizeof(b)));rejected([&]{detail::unpackScalar(p,b,sizeof(b));});
    assert(!isBound()&&!bind()&&!isGameThread());assert(binding("weakAssign")==0);__block bool ran=false;assert(!onGameThread(^{ran=true;}));assert(!ran);
    rejected([&]{object(0);});rejected([&]{Weak w(Object{4096});(void)w;});rejected([&]{Weak{}.get();});rejected([&]{find();});rejected([&]{invoke(Object{4096},@"NeverCall",@{});});
    uint32_t copied=0;assert(!read(0,&copied,sizeof(copied)));assert(!read(UINTPTR_MAX-1,&copied,sizeof(copied)));
    NSLog(@"Unreal contracts passed: bounded scalar packing, bool preservation, object/weak/invoke GameThread rejection.");
}}
