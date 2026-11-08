// SPDX-License-Identifier: GPL-3.0-only
// Original-call seams for VMDispatchTests only. Never linked into a product.
#include <stdint.h>
#include <atomic>
struct lua_State;
using Continuation=int(*)(lua_State *,int,intptr_t);
std::atomic<unsigned> IZFixtureOriginalCalls{0},IZFixtureCloses{0};
int IZFixtureResult=0;
extern "C" int IZFixturePCall(lua_State *,int,int,int,intptr_t,Continuation){IZFixtureOriginalCalls++;return IZFixtureResult;}
extern "C" void IZFixtureClose(lua_State *){IZFixtureCloses++;}
