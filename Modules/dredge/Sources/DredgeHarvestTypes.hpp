// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <cstdint>
#include <stdexcept>
namespace dredge {
// Ownership of one element in an existing, runtime-validated HarvestableType[].
// A changed original value becomes the new baseline; unchanged owned values
// are only read back. The managed array/field/GC owner is checked by the caller.
struct HarvestTypeLease {
    bool held=false;
    int32_t original=0,last=0;
    template<class Read,class Write>
    bool apply(int32_t requested,Read read,Write write) {
        if(requested<1||requested>10)throw std::runtime_error("Unbekannter ursprünglicher Fangtyp.");
        int32_t current=read();
        int32_t baseline=!held||current!=last ? current : original;
        if(current!=requested)write(requested);
        if(read()!=requested)throw std::runtime_error("Der ursprüngliche Rutenfangtyp konnte nicht zurückgelesen werden.");
        original=baseline;last=requested;held=true;return true;
    }
    template<class Read,class Write>
    void release(Read read,Write write) {
        if(!held)return;
        if(read()==last)write(original);
        held=false;
    }
};
}
