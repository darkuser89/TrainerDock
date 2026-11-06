// SPDX-License-Identifier: GPL-3.0-only
using System;
using MHTDuckov;
public static class CapacitySafetyTests {
 public static void Main() {
  if(CapacitySafety.Recover(10,0)!=10 || !CapacitySafety.CanFinish(10,0))throw new Exception("Empty inventory must recover baseline.");
  if(CapacitySafety.Recover(10,11)!=11 || CapacitySafety.CanFinish(10,11))throw new Exception("Occupied extra slot must survive all-off.");
  if(CapacitySafety.Recover(10,200)!=200 || CapacitySafety.CanFinish(10,200))throw new Exception("Highest occupied slot, including gaps, must survive.");
  if(CapacitySafety.Recover(10,10)!=10 || !CapacitySafety.CanFinish(10,10))throw new Exception("Finish only after extra slots become empty.");
  if(CapacitySafety.Recover(0,7)!=7 || CapacitySafety.CanFinish(0,7))throw new Exception("Invalid baseline must never discard occupied slots.");
  Console.WriteLine("PASS: inventory recovery preserves occupied extra slots and gaps, defers shrinking and completes after emptying.");
 }
}
