// SPDX-License-Identifier: GPL-3.0-only
using System;using MHTVampireSurvivors;
class PolicyTests {
 static void Check(bool b,string why){if(!b)throw new Exception(why);}
 static void Main(){
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
  Console.WriteLine("Vampire Survivors numeric/one-shot/owned-stat checks passed");
 }
}
