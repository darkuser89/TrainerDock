// SPDX-License-Identifier: GPL-3.0-only
using System;
namespace MHTVampireSurvivors {
 public static class Policy {
  public const int Count=19;
  // Exact observed build tuples. Do not accept independently mixed assemblies.
  static readonly Guid SteamRuntime=new Guid("a0f710ef-5749-41d3-acf9-dffec2421678");
  static readonly Guid SteamPhaser=new Guid("93b42865-e14c-4ce5-8022-591e2f7dff4d");
  static readonly Guid SteamUniTask=new Guid("6b0d9df4-3659-4035-852e-1d51528841f6");
  static readonly Guid EpicRuntime=new Guid("7b778702-8647-455b-bbcc-f38442e8cf59");
  static readonly Guid EpicPhaser=new Guid("e01b784b-6119-42cb-be5d-8b4533ff7fa3");
  static readonly Guid EpicUniTask=new Guid("795da216-3443-4ac3-89f6-28c5377f97de");
  static readonly Guid UnityCore=new Guid("1b3ea231-962b-4662-b0df-c5487b245a2e");
  public static bool SupportedBuild(Guid runtime,Guid phaser,Guid uniTask,Guid unityCore) {
   if(unityCore!=UnityCore)return false;
   return (runtime==SteamRuntime&&phaser==SteamPhaser&&uniTask==SteamUniTask)||
          (runtime==EpicRuntime&&phaser==EpicPhaser&&uniTask==EpicUniTask);
  }
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

 // Reference identity prevents a recycled instance ID or hash collision from
 // retaining effects. This value snapshot allocates no per-frame owner string.
 public readonly struct ContextOwner {
  readonly object a,b,c,d,e,f,g;readonly int number;readonly bool valid;
  public ContextOwner(object a,object b,object c,object d,object e,object f,object g,int number,bool valid){this.a=a;this.b=b;this.c=c;this.d=d;this.e=e;this.f=f;this.g=g;this.number=number;this.valid=valid;}
  public bool Same(ContextOwner o){return valid==o.valid&&number==o.number&&object.ReferenceEquals(a,o.a)&&object.ReferenceEquals(b,o.b)&&object.ReferenceEquals(c,o.c)&&object.ReferenceEquals(d,o.d)&&object.ReferenceEquals(e,o.e)&&object.ReferenceEquals(f,o.f)&&object.ReferenceEquals(g,o.g);}
 }
}
