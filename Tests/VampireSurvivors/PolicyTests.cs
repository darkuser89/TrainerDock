// SPDX-License-Identifier: GPL-3.0-only
using System;using MHTVampireSurvivors;
class PolicyTests {
 static void Check(bool b,string why){if(!b)throw new Exception(why);}
 static void Main(){
  var builds=new[]{
   new[]{new Guid("a0f710ef-5749-41d3-acf9-dffec2421678"),new Guid("93b42865-e14c-4ce5-8022-591e2f7dff4d"),new Guid("6b0d9df4-3659-4035-852e-1d51528841f6"),new Guid("1b3ea231-962b-4662-b0df-c5487b245a2e")},
   new[]{new Guid("7b778702-8647-455b-bbcc-f38442e8cf59"),new Guid("e01b784b-6119-42cb-be5d-8b4533ff7fa3"),new Guid("795da216-3443-4ac3-89f6-28c5377f97de"),new Guid("1b3ea231-962b-4662-b0df-c5487b245a2e")}
  };
  foreach(var b in builds){
   Check(Policy.SupportedBuild(b[0],b[1],b[2],b[3]),"Exact original store build accepted");
   for(int missing=0;missing<4;missing++){
    var changed=(Guid[])b.Clone();changed[missing]=Guid.Empty;
    Check(!Policy.SupportedBuild(changed[0],changed[1],changed[2],changed[3]),"Unknown/empty assembly identity rejected");
   }
  }
  for(int mix=0;mix<8;mix++)Check(Policy.SupportedBuild(builds[mix&1][0],builds[(mix>>1)&1][1],builds[(mix>>2)&1][2],builds[0][3])==(mix==0||mix==7),"Mixed store assemblies rejected");
  foreach(double v in new[]{double.NaN,double.PositiveInfinity,double.NegativeInfinity})for(int f=0;f<Policy.Count;f++)Check(!Policy.Valid(f,v),"Nonfinite command rejected");
  Check(!Policy.Valid(-1,1)&&!Policy.Valid(19,1),"Feature bounds");
  Check(!Policy.Valid(6,.5)&&!Policy.Valid(8,101),"Multiplier bounds");
  Check(!Policy.Valid(12,1.5)&&!Policy.Valid(13,10000)&&!Policy.Valid(16,-1),"Counts must be bounded integers");
  for(int f=0;f<19;f++)Check(Policy.Once(f)==(f>=9),"No implicit one-shot replay");
  float native=1.2f,egg=.3f;float contribution=Policy.Contribution(native,egg,2);
  Check(Policy.Near(native+contribution,3),"Multiplier includes original egg contribution");
  // A native level-up changes only Val; the trainer must not overwrite it.
  native+=.1f;contribution=Policy.Contribution(native,egg,2);
  Check(Policy.Near(native+contribution,3.2)&&Policy.Near(native+egg,1.6),"Native progress survives the removable contribution");
  Check(Policy.Contribution(.8f,0,.1f)<0,"Native cooldown supports a negative removable contribution");
  bool threw=false;try{Policy.Contribution(float.MaxValue,0,100);}catch(ArgumentOutOfRangeException){threw=true;}Check(threw,"Overflowing native stats rejected");
  Console.WriteLine("Vampire Survivors exact store-build tuples, mixed/unknown identity rejection, numeric/one-shot/owned-stat checks passed");
 }
}
