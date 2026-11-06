// SPDX-License-Identifier: GPL-3.0-only
namespace MHTDuckov {
 // Occupied means highest occupied index + 1, including gaps. Do not compact,
 // detach, delete or drop items to fit a requested/recovered inventory size.
 public static class CapacitySafety {
  public static int Recover(int baseline,int occupied) {
   return System.Math.Max(System.Math.Max(1,baseline),occupied);
  }
  public static bool CanFinish(int baseline,int occupied) {
   return occupied<=System.Math.Max(1,baseline);
  }
 }
}
