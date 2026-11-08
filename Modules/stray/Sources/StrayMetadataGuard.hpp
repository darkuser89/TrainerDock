// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <array>
#include <cstdint>
#include <cstring>
namespace st::detail {
// Immutable original metadata only. The owner weak serial is checked separately;
// a cache hit still compares its native header/descriptor before any access.
template<size_t N> struct MetadataGuard {
 uintptr_t address=0;std::array<uint8_t,N> expected{};
 template<class Reader> bool capture(uintptr_t at,Reader read){address=at;return read(at,expected.data(),N);}
 template<class Reader> bool matches(Reader read)const{std::array<uint8_t,N> now{};return address&&read(address,now.data(),N)&&!memcmp(now.data(),expected.data(),N);}
};
}
