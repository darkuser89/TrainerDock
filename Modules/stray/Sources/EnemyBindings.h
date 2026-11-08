// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <cstdint>
#include <cstddef>
// Read-only original facts for Stray Steam12863654, UUID
// C72D3F73-25F4-333B-9108-83432E09E687. Not a cross-build layout.
// Native setters must only be called after the main identity and these bytes
// match; the supplied address is unslid. These facts alone are not effect proof.
namespace st::enemy {
struct Function {uintptr_t address;const uint8_t *bytes;size_t size;};
inline constexpr uint8_t CanSwarmSeeBytes[]={0x0,0x80,0x51,0x39,0xc0,0x3,0x5f,0xd6};
inline constexpr Function CanSwarmSee={0x10100469cULL,CanSwarmSeeBytes,sizeof(CanSwarmSeeBytes)};
inline constexpr uint8_t SetSwarmCanSeeBytes[]={0x1,0x80,0x11,0x39,0xc0,0x3,0x5f,0xd6};
inline constexpr Function SetSwarmCanSee={0x1010065fcULL,SetSwarmCanSeeBytes,sizeof(SetSwarmCanSeeBytes)};
inline constexpr uint8_t CanSwarmHearSoundBytes[]={0x8,0x88,0x41,0xf9,0x0,0x1,0x52,0x39,0xc0,0x3,0x5f,0xd6};
inline constexpr Function CanSwarmHearSound={0x101004678ULL,CanSwarmHearSoundBytes,sizeof(CanSwarmHearSoundBytes)};
inline constexpr uint8_t SetSwarmCanHearSoundBytes[]={0x8,0x88,0x41,0xf9,0x1,0x1,0x12,0x39,0xc0,0x3,0x5f,0xd6};
inline constexpr Function SetSwarmCanHearSound={0x1010064bcULL,SetSwarmCanHearSoundBytes,sizeof(SetSwarmCanHearSoundBytes)};
inline constexpr uint8_t SetAggressiveBytes[]={0xff,0x83,0x0,0xd1,0xfd,0x7b,0x1,0xa9,0xfd,0x43,0x0,0x91,0x8,0xa0,0x56,0x39};
inline constexpr Function SetAggressive={0x100f8f7a0ULL,SetAggressiveBytes,sizeof(SetAggressiveBytes)};
inline constexpr uint8_t SetVisonLightEnabledBytes[]={0x8,0xa4,0x56,0x39,0x1f,0x1,0x1,0x6b,0x41,0x0,0x0,0x54,0xc0,0x3,0x5f,0xd6};
inline constexpr Function SetVisonLightEnabled={0x100f8e890ULL,SetVisonLightEnabledBytes,sizeof(SetVisonLightEnabledBytes)};
inline constexpr uint8_t GetTazerModeBytes[]={0x0,0x0,0x58,0x39,0xc0,0x3,0x5f,0xd6};
inline constexpr Function GetTazerMode={0x100f8f4d4ULL,GetTazerModeBytes,sizeof(GetTazerModeBytes)};
// m_cachedPlayerCatPawn is an original ObjectProperty (descriptor0x1049e8ff8).
// Only leaders bound to the current local cat should receive sense changes.
inline constexpr size_t LeaderCachedCat=0x338,LeaderNoisableComponent=0x310;
inline constexpr size_t LeaderCanSee=0x460,NoisableCanHear=0x480;
// Native aggressive setter broadcasts OnSentinelAggressivityChanged.
inline constexpr size_t SentinelSettings=0x550,SentinelAggressive=0x5a8;
inline constexpr size_t SentinelVisionLight=0x5a9,SentinelTazerMode=0x600;
inline constexpr size_t SentinelLockedTarget=0x660;
// The original Blueprint BTS_Sentinel_Vision gates its ReceiveTickAI at
// graph0x1463 on this flag; false graph0x14a0 clears target and visibility.
// IsActorInVision itself does not check the flag; the original caller does.
}
