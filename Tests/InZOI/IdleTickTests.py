#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Execute the real trainer Lua with synthetic owners; never starts a game.

Pass a standalone Lua/LuaJIT library or an installed Lua runtime explicitly.
No game assemblies, original scripts or assets are copied into this fixture.
"""
import ctypes
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("Usage: IdleTickTests.py /absolute/path/to/Lua-library")
lua = ctypes.CDLL(str(Path(sys.argv[1]).resolve()))
state_type = ctypes.c_void_p
lua.luaL_newstate.restype = state_type
lua.luaL_openlibs.argtypes = [state_type]
lua.lua_close.argtypes = [state_type]
lua.lua_tolstring.argtypes = [state_type, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
load = getattr(lua, "luaL_loadbufferx", None)
if load:
    load.argtypes = [state_type, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_char_p]
else:
    load = lua.luaL_loadbuffer
    load.argtypes = [state_type, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
call = getattr(lua, "lua_pcallk", None)
if call:
    call.argtypes = [state_type, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
else:
    call = lua.lua_pcall
    call.argtypes = [state_type, ctypes.c_int, ctypes.c_int, ctypes.c_int]
modern_load = hasattr(lua, "luaL_loadbufferx")
modern_call = hasattr(lua, "lua_pcallk")
state = lua.luaL_newstate()
assert state
lua.luaL_openlibs(state)


def execute(text, name):
    data = text.encode()
    args = (state, data, len(data), name.encode())
    result = load(*args, None) if modern_load else load(*args)
    if not result:
        result = call(state, 0, 0, 0, 0, None) if modern_call else call(state, 0, 0, 0)
    if result:
        raise AssertionError(lua.lua_tolstring(state, -1, None).decode())


source = (Path(__file__).resolve().parents[2] / "Modules/inzoi/Sources/LuaProgram.hpp").read_text()
program = source.split('R"IZLUA(', 1)[1].split(')IZLUA"', 1)[0]
fixture = r"""
queries,writes,gets=0,0,0
owner='1';health=50;scale=1
local id=setmetatable({IsValid=function() return true end},{__tostring=function() return owner end})
local house=setmetatable({IsValid=function() return true end},{__tostring=function() return 'house' end})
local stats={GetOwnerEntityId=function() return id end,
 GetStat=function(_,key) gets=gets+1;return health end,
 SetStat=function(_,key,value) writes=writes+1;health=value end}
local ch={IsInvalid=function() return false end,IsRegistered=function() return true end,
 GetLocatedCityId=function() return 'city' end,GetEntityId=function() return id end,
 GetComponent=function(_,kind) assert(kind==1);return stats end}
local household={IsInvalid=function() return false end}
local controller={PossessEntityId=id,PossessHouseholdId=house,IsBuildMode=function() return false end}
local time={IsContainsPauseReason=function() return false end,IsPaused=function() return false end,
 GetTimeScaleRawValue=function() return scale end,
 SetTimeScale=function(_,value) writes=writes+1;scale=value end}
local entities={FindCharacter=function() return ch end,FindHousehold=function() return household end}
inzoi={getB2Subsystem=function(key) queries=queries+1;return controller end,
 getB2Manager=function(key) queries=queries+1;return key=='FB2TimeManager' and time or entities end}
INZOI={EB1PauseReason={Initialize=1,Loading=2}}
"""
try:
    execute(fixture, "synthetic-owners")
    execute("trainer=(function()\n" + program + "\nend)()", "real-trainer-program")
    execute(r"""
assert(trainer.context().ready)
local q=queries
for i=1,20000 do trainer.tick() end
assert(queries==q and writes==0 and gets==0,'idle ticks must perform no entity/component work')
assert(trainer.feature(0,true,0).active and health==100,'first enable applies and reads back')
local w=writes;local g=gets
for i=1,1000 do assert(trainer.feature(0,true,0).active) end
assert(writes==w and gets==g,'unchanged UI polls must not execute periodic effects again')
trainer.tick();assert(writes==w,'already satisfied stat needs no redundant setter')
health=90;trainer.tick();assert(health==100 and writes==w+1,'real simulation ticks still repair damage')
trainer.feature(0,false,0);q=queries;g=gets;w=writes
for i=1,20000 do trainer.tick() end
assert(queries==q and gets==g and writes==w,'last off returns to zero-work tick')
trainer.feature(19,true,2);assert(scale==2,'game speed applies')
w=writes;for i=1,100 do trainer.tick() end
assert(writes==w,'unchanged time scale causes no redundant setter')
trainer.feature(19,false,2);assert(scale==1,'off restores original speed')
trainer.feature(19,true,2);scale=3;trainer.feature(19,false,2)
assert(scale==3,'foreign time write preserved on off')
trainer.feature(0,true,0);owner='2';health=40;trainer.tick()
assert(health==40 and trainer.owner==nil and not trainer.tickWork,'changed owner releases rather than applying')
assert(trainer.context().ready,'new owner can be observed')
trainer.feature(16,true,0);q=queries;for i=1,20000 do trainer.tick() end
assert(queries==q,'skill-only hooks need no periodic entity discovery')
""", "idle-and-effect-contract")
    print("PASS: 60,000 idle ticks without native discovery, unchanged polling, real tick effects, owner changes and conditional time restoration. Synthetic only; no game started.")
finally:
    lua.lua_close(state)
