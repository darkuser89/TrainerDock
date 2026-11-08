// SPDX-License-Identifier: GPL-3.0-only
using System;
using MHTDuckov;
public static class CapacitySafetyTests {
 public static void Main() {
  OwnerChecks();
  SubscriptionChecks();
  ValueKeyChecks();
  if(CapacitySafety.Recover(10,0)!=10 || !CapacitySafety.CanFinish(10,0))throw new Exception("Empty inventory must recover baseline.");
  if(CapacitySafety.Recover(10,11)!=11 || CapacitySafety.CanFinish(10,11))throw new Exception("Occupied extra slot must survive all-off.");
  if(CapacitySafety.Recover(10,200)!=200 || CapacitySafety.CanFinish(10,200))throw new Exception("Highest occupied slot, including gaps, must survive.");
  if(CapacitySafety.Recover(10,10)!=10 || !CapacitySafety.CanFinish(10,10))throw new Exception("Finish only after extra slots become empty.");
  if(CapacitySafety.Recover(0,7)!=7 || CapacitySafety.CanFinish(0,7))throw new Exception("Invalid baseline must never discard occupied slots.");
  Console.WriteLine("PASS: inventory recovery preserves occupied extra slots and gaps, defers shrinking and completes after emptying.");
 }

 sealed class CollidingOwner {public override int GetHashCode(){return 1;}}
 static void OwnerChecks(){
  object a=new CollidingOwner(),b=new CollidingOwner(),c=new object(),d=new object(),e=new object(),f=new object(),g=new object();
  var baseline=new ContextOwner(a,b,c,d,e,f,g,7,true);
  if(!baseline.Same(new ContextOwner(a,b,c,d,e,f,g,7,true)))throw new Exception("Unchanged native owner must remain stable.");
  if(baseline.Same(new ContextOwner(new CollidingOwner(),b,c,d,e,f,g,7,true)))throw new Exception("A hash/instance collision must not preserve an old owner.");
  object[] refs={a,b,c,d,e,f,g};
  for(int i=0;i<refs.Length;i++){var changed=(object[])refs.Clone();changed[i]=new object();if(baseline.Same(new ContextOwner(changed[0],changed[1],changed[2],changed[3],changed[4],changed[5],changed[6],7,true)))throw new Exception("Every owner field participates in invalidation.");}
  if(baseline.Same(new ContextOwner(a,b,c,d,e,f,g,8,true))||baseline.Same(new ContextOwner(a,b,c,d,e,f,g,7,false)))throw new Exception("Scene/slot and valid/loading transitions invalidate the owner.");
  // Warm the generic/runtime paths before measuring the steady frame loop.
  for(int i=0;i<1000;i++)baseline.Same(new ContextOwner(a,b,c,d,e,f,g,7,true));
  long before=GC.GetAllocatedBytesForCurrentThread();
  bool same=true;for(int i=0;i<20000;i++)same &= baseline.Same(new ContextOwner(a,b,c,d,e,f,g,7,true));
  long allocated=GC.GetAllocatedBytesForCurrentThread()-before;
  if(!same||allocated!=0)throw new Exception("Steady owner snapshots must allocate zero managed bytes.");
  Console.WriteLine("PASS: 20,000 owner snapshots allocate zero bytes; every native owner, scene/slot, loading and recycled-ID boundary invalidates correctly.");
 }

 sealed class HandlerOwner {public void Handle(){}public void Other(){}}
 static void SubscriptionChecks(){
  var a=new HandlerOwner();var b=new HandlerOwner();Action ours=a.Handle,other=b.Handle;var cache=new EventSubscription();
  Action chain=other+ours;
  if(!cache.Contains(chain,a,"Handle"))throw new Exception("Own original handler must be observed.");
  if(cache.Contains(chain,a,"Other")||cache.Contains(chain,new HandlerOwner(),"Handle"))throw new Exception("Owner/method changes invalidate subscription readback.");
  if(!cache.Contains(chain,a,"Handle"))throw new Exception("Correct subscription remains available.");
  long before=GC.GetAllocatedBytesForCurrentThread();for(int i=0;i<20000;i++)if(!cache.Contains(chain,a,"Handle"))throw new Exception("Stable handler missing.");
  if(GC.GetAllocatedBytesForCurrentThread()!=before)throw new Exception("Stable subscription readback must not allocate invocation lists.");
  chain-=ours;if(cache.Contains(chain,a,"Handle")||cache.Contains(null,a,"Handle"))throw new Exception("External removal and a cleared event cannot claim an active subscription.");
  chain+=ours;if(!cache.Contains(chain,a,"Handle"))throw new Exception("An original re-subscription is revalidated.");
  Console.WriteLine("PASS: 20,000 subscription readbacks allocate zero bytes; external removal, re-subscription and owner/method changes are detected.");
 }

 static void ValueKeyChecks(){
  object first=new CollidingOwner(),second=new CollidingOwner();var entries=new System.Collections.Generic.Dictionary<OwnedValueKey,int>();
  entries[new OwnedValueKey(7,first,"weight")]=1;entries[new OwnedValueKey(15,first,"weight")]=2;entries[new OwnedValueKey(7,second,"weight")]=3;
  if(entries.Count!=3||entries[new OwnedValueKey(7,first,"weight")]!=1)throw new Exception("Lease index must distinguish owner reference and feature despite hash collisions.");
  long before=GC.GetAllocatedBytesForCurrentThread();for(int i=0;i<20000;i++)if(entries[new OwnedValueKey(7,first,"weight")]!=1)throw new Exception("Indexed lease missing.");
  if(GC.GetAllocatedBytesForCurrentThread()!=before)throw new Exception("Indexed lease lookup must allocate no per-frame key boxes.");
  entries.Remove(new OwnedValueKey(7,first,"weight"));if(entries.ContainsKey(new OwnedValueKey(7,first,"weight"))||entries.Count!=2)throw new Exception("Lease release must remove only its exact owner/feature/property.");
  Console.WriteLine("PASS: exact-reference lease keys, collision/feature isolation and 20,000 zero-allocation indexed lookups.");
 }
}
