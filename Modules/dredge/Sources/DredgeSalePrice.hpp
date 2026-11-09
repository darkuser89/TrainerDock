// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <stdexcept>
namespace dredge {
inline double saleModifier(double original,double factor){
 if(!std::isfinite(original)||original<=0||!std::isfinite(factor)||factor<1||factor>100)
  throw std::runtime_error("Ungültiger ursprünglicher Verkaufsfaktor.");
 return std::max(1.0,original)*factor;
}
// Fish clamps the handler modifier to one. Non-fish uses its separate sell
// override: compensate that sell-only base while keeping purchase value intact.
inline double resaleCorrection(double original){
 if(!std::isfinite(original)||original<=0)throw std::runtime_error("Ungültige ursprüngliche Wiederverkaufsbasis.");
 return original/std::max(1.0,original);
}
}
