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

 // Reference identity prevents a recycled instance ID or hash collision from
 // retaining effects. This value snapshot allocates no per-frame owner string.
 public readonly struct ContextOwner {
  readonly object a,b,c,d,e,f,g;readonly int number;readonly bool valid;
  public ContextOwner(object a,object b,object c,object d,object e,object f,object g,int number,bool valid){this.a=a;this.b=b;this.c=c;this.d=d;this.e=e;this.f=f;this.g=g;this.number=number;this.valid=valid;}
  public bool Same(ContextOwner o){return valid==o.valid&&number==o.number&&object.ReferenceEquals(a,o.a)&&object.ReferenceEquals(b,o.b)&&object.ReferenceEquals(c,o.c)&&object.ReferenceEquals(d,o.d)&&object.ReferenceEquals(e,o.e)&&object.ReferenceEquals(f,o.f)&&object.ReferenceEquals(g,o.g);}
 }

 // Multicast delegates are immutable. Revalidate when the actual subscription
 // chain changes; do not allocate its invocation list on every native frame.
 public sealed class EventSubscription {
  System.Delegate observed;object target;string name;bool confirmed;
  public bool Contains(System.Delegate current,object owner,string method){
   if(object.ReferenceEquals(current,observed)&&object.ReferenceEquals(target,owner)&&name==method)return current!=null&&confirmed;
   observed=current;target=owner;name=method;confirmed=false;
   if(current!=null)foreach(var handler in current.GetInvocationList())if(object.ReferenceEquals(handler.Target,owner)&&handler.Method.Name==method){confirmed=true;break;}
   return confirmed;
  }
 }

 // Exact managed owner references, feature and property form the lookup key.
 // Indexing avoids quadratic per-item/per-perk searches through all leases.
 public readonly struct OwnedValueKey:System.IEquatable<OwnedValueKey> {
  readonly int feature;readonly object owner;readonly string key;
  public OwnedValueKey(int feature,object owner,string key){this.feature=feature;this.owner=owner;this.key=key;}
  public bool Equals(OwnedValueKey value){return feature==value.feature&&object.ReferenceEquals(owner,value.owner)&&string.Equals(key,value.key,System.StringComparison.Ordinal);}
  public override bool Equals(object value){return value is OwnedValueKey&&Equals((OwnedValueKey)value);}
  public override int GetHashCode(){unchecked{return ((feature*397)^System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(owner))*397^(key==null?0:System.StringComparer.Ordinal.GetHashCode(key));}}
 }
}
