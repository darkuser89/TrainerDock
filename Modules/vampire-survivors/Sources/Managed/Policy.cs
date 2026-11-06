// SPDX-License-Identifier: GPL-3.0-only
using System;
namespace MHTVampireSurvivors {
 public static class Policy {
  public const int Count=19;
  public static bool Once(int f) { return f>=9 && f<Count; }
  public static bool Valid(int f,double v) {
   if(f<0||f>=Count||double.IsNaN(v)||double.IsInfinity(v))return false;
   if(f>=6&&f<=8)return v>=1&&v<=100;
   if(Once(f))return v>=0&&v<=(f==12||f==13?9999:1000000000)&&
    (!(f==12||f==13||f==16)||Math.Floor(v)==v);
   return true;
  }
  public static bool Near(double a,double b) { return !double.IsNaN(a)&&!double.IsInfinity(a)&&!double.IsNaN(b)&&!double.IsInfinity(b)&&Math.Abs(a-b)<=Math.Max(.00001,Math.Abs(b)*.00001); }
  public static float Contribution(float nativeBase,float nativeEgg,float factor) {
   double v=((double)nativeBase+nativeEgg)*factor-nativeBase;
   if(float.IsNaN(factor)||factor<0||double.IsNaN(v)||double.IsInfinity(v)||Math.Abs(v)>1e15)throw new ArgumentOutOfRangeException();
   return (float)v;
  }
 }
}
