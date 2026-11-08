#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Exercise exact own C# hot-path methods with isolated typed fixtures.

Bodies are extracted from product sources at test time, so tests cannot silently
exercise a stale copy. The fixtures never load game assemblies or enter products.
"""
from pathlib import Path
import json
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'script'))
from managed import managed_compiler

def method(source,signature):
    start=source.index(signature)
    at=source.index('{',start);depth=1;end=at+1
    while depth:
        if source[end]=='{':depth+=1
        elif source[end]=='}':depth-=1
        end+=1
    return source[start:end]

DU=r'''
using System;using System.Collections.Generic;using MHTDuckov;
#pragma warning disable 0649
static class Mathf {public static int RoundToInt(float v){return (int)Math.Round(v);}public static float Abs(float v){return Math.Abs(v);}public static float Max(float a,float b){return Math.Max(a,b);}}
enum ModifierType {Add,PercentageMultiply}
class Inventory{public readonly List<Item> Content=new List<Item>();public int Capacity;public static bool operator !(Inventory v){return object.ReferenceEquals(v,null);}}
class Modifier {
 public static int Created;public ModifierType Type;public float Value;public int Order;public object Source;
 public Modifier(ModifierType t,float v,bool order,int n,object source){Created++;Type=t;Value=v;Order=n;Source=source;}
}
class Stat {
 public float Base=2;public int Adds,Removes;public readonly List<Modifier> Modifiers=new List<Modifier>();
 public float Value {get{float v=Base;foreach(var m in Modifiers)v=m.Type==ModifierType.Add?v+m.Value:v*(1+m.Value);return v;}}
 public void AddModifier(Modifier m){Adds++;Modifiers.Add(m);}public void RemoveModifier(Modifier m){Removes++;Modifiers.Remove(m);}
}
class Item {public Stat value=new Stat();public Stat GetStat(string unused){return value;}public static bool operator !(Item item){return object.ReferenceEquals(item,null);}public static implicit operator bool(Item item){return !object.ReferenceEquals(item,null);}}
class Fixture {
 readonly List<OwnStat> modifiers=new List<OwnStat>(),capacityPending=new List<OwnStat>();
 readonly List<OwnValue> capacityValuesPending=new List<OwnValue>();
 class OwnValue {public object target,before,last;public Func<object> read;public Action<object> write;}
 __OWNSTAT__
 __NEAR__
 __STAT__
 __SAME__
 __OCCUPIED__
 __DRAIN__
 static void Check(bool ok,string why){if(!ok)throw new Exception(why);}
 static void Main(){
  var t=new Fixture();var item=new Item();var s=item.value;
  Check(t.Stat(1,item,"power",2,true)&&s.Value==4,"first multiplier applies");
  int adds=s.Adds,removes=s.Removes,created=Modifier.Created;
  long before=GC.GetAllocatedBytesForCurrentThread();
  for(int i=0;i<20000;i++)Check(t.Stat(1,item,"power",2,true),"stable multiplier readback");
  Check(GC.GetAllocatedBytesForCurrentThread()==before,"steady modifier checks allocate no managed objects");
  Check(s.Adds==adds&&s.Removes==removes&&Modifier.Created==created,"steady requests never remove/recreate modifiers or dirty their stat");
  s.Base=3;Check(t.Stat(1,item,"power",2,true)&&s.Value==6&&s.Adds==adds,"natural base changes still flow through original persistent modifier");
  Check(t.Stat(1,item,"power",3,true)&&s.Value==9&&s.Adds==adds+1,"changed factor rebuilds its own contribution");
  s.Modifiers[0].Value=5;Check(t.Stat(1,item,"power",3,true)&&s.Value==9,"externally changed own modifier is not falsely confirmed");
  var foreign=new Modifier(ModifierType.Add,1,true,1,new object());s.AddModifier(foreign);
  Check(t.Stat(1,item,"power",3,true)&&s.Modifiers.Contains(foreign),"foreign modifier is preserved");
  var target=new Item();Check(t.Stat(2,target,"health",10,false,true)&&target.value.Value==10,"target modifier reaches requested value");
  int previous=target.value.Adds;Check(t.Stat(2,target,"health",10,false,true)&&target.value.Adds==previous,"unchanged target reuses original modifier");
  target.value.Base=5;Check(t.Stat(2,target,"health",10,false,true)&&target.value.Value==10&&target.value.Adds==previous+1,"changed native base recalculates target contribution");
  target.value.Modifiers.Clear();Check(t.Stat(2,target,"health",10,false,true)&&target.value.Value==10,"externally removed modifier is rebound");
  var inv=new Inventory {Capacity=11};for(int i=0;i<11;i++)inv.Content.Add(new Item());
  var capped=new Item();capped.value.Base=10;var cap=new OwnStat{feature=31,item=capped,stat=capped.value,inventory=inv,order=1000000031,contribution=1,pendingOccupied=11,pendingReadback=11};
  cap.modifier=new Modifier(ModifierType.Add,1,true,cap.order,cap);cap.stat.AddModifier(cap.modifier);t.capacityPending.Add(cap);
  adds=cap.stat.Adds;removes=cap.stat.Removes;created=Modifier.Created;
  for(int i=0;i<20000;i++)t.DrainCapacity();
  Check(cap.stat.Adds==adds&&cap.stat.Removes==removes&&Modifier.Created==created&&cap.stat.Value==11,"unchanged occupied extra slots do not recreate their holding modifier");
  inv.Content[10]=null;t.DrainCapacity();Check(t.capacityPending.Count==0&&cap.stat.Modifiers.Count==0&&cap.stat.Value==10,"after emptying, stat capacity restores baseline without dropping items");
  inv.Content[10]=new Item();int capacityWrites=0;var pending=new OwnValue{target=inv,before=10,last=11,read=()=>inv.Capacity,write=v=>{capacityWrites++;inv.Capacity=(int)v;}};t.capacityValuesPending.Add(pending);
  for(int i=0;i<20000;i++)t.DrainCapacity();Check(capacityWrites==0&&inv.Capacity==11,"unchanged capacity values do not repeatedly invoke native setter");
  inv.Content[10]=null;t.DrainCapacity();Check(capacityWrites==1&&inv.Capacity==10&&t.capacityValuesPending.Count==0,"value capacity shrinks only after the extra slot is empty");
  Console.WriteLine("PASS: exact Duckov Stat hot path: 20,000 zero-allocation/no-rebuild polls, natural growth, target/factor edits, external changes, foreign modifiers and deferred occupied-slot restoration.");
 }
}
'''
VS=r'''
using System;using System.Collections.Generic;using MHTVampireSurvivors;
class EggFloat {public float Base=1,Egg;public int Writes;public float GetValue(){return Base;}public float GetEggValue(){return Egg;}public void SetEggValue(float v){Egg=v;Writes++;}}
class Player {public bool PermanentInvulnerability,IsInvul;public int Writes;public void SetPermanentInvulnerability(bool on){PermanentInvulnerability=on;Writes++;}}
class Stats {
 public int Reads;public readonly EggFloat move=new EggFloat(),power=new EggFloat(),area=new EggFloat(),cooldown=new EggFloat(),growth=new EggFloat();
 public EggFloat MoveSpeed {get{Reads++;return move;}}public EggFloat Power {get{Reads++;return power;}}public EggFloat Area {get{Reads++;return area;}}public EggFloat Cooldown {get{Reads++;return cooldown;}}public EggFloat Growth {get{Reads++;return growth;}}
}
class Fixture {
 readonly bool[] wanted=new bool[19];readonly double[] values=new double[19];readonly Dictionary<string,EggOwner> eggs=new Dictionary<string,EggOwner>();
 readonly Player player=new Player();readonly Stats stats=new Stats();bool godOwned;
 __EGGOWNER__
 __RELEASE__
 __SCALE__
 __MAINTAIN__
 static void Check(bool ok,string why){if(!ok)throw new Exception(why);}
 static void Main(){
  var t=new Fixture();for(int i=0;i<20000;i++)t.Maintain();Check(t.stats.Reads==0,"all-off maintenance does not query stats");
  t.wanted[1]=true;t.Maintain();Check(t.stats.move.GetEggValue()==2&&t.stats.move.Writes==1,"native movement contribution applied once");
  long before=GC.GetAllocatedBytesForCurrentThread();for(int i=0;i<20000;i++)t.Maintain();
  Check(GC.GetAllocatedBytesForCurrentThread()==before&&t.stats.move.Writes==1,"stable active multiplier allocates no objects and performs no redundant setters");
  t.stats.move.Base=2;t.Maintain();Check(t.stats.move.GetEggValue()==4,"natural base growth updates removable contribution");
  t.stats.move.Egg=5;t.Maintain();Check(t.stats.move.GetEggValue()==7,"external egg growth becomes part of original baseline");
  t.wanted[1]=false;t.Maintain();Check(t.stats.move.GetEggValue()==1,"off restores original plus external growth");
  t.wanted[0]=true;t.Maintain();Check(t.player.PermanentInvulnerability&&t.player.IsInvul,"god ownership applies");
  int writes=t.player.Writes;t.Maintain();Check(t.player.Writes==writes,"unchanged god state is not re-applied");
  t.wanted[0]=false;t.Maintain();Check(!t.player.PermanentInvulnerability,"god ownership returns on off");
  Console.WriteLine("PASS: exact Vampire Survivors Scale/Maintain hot paths: 20,000 all-off/no-query and active zero-allocation/no-setter polls, natural/external growth and owned restoration.");
 }
}
'''

DUAUX=r'''
using System;using System.Collections.Generic;using System.Reflection;using MHTDuckov;
#pragma warning disable 0649
class UObj {public static implicit operator bool(UObj v){return !object.ReferenceEquals(v,null);}public static bool operator !(UObj v){return object.ReferenceEquals(v,null);}}
class Inventory:UObj{}
class Item:UObj {public float Durability=10,MaxDurabilityWithLoss=100,weight=4;}
struct Entry {public int id,amount;}
struct Cost {public long money;public Entry[] items;public Cost(long n){money=n;items=null;}}
struct CraftingFormula {public string id;public Entry result;public string[] tags;public Cost cost;public bool unlockByDefault,lockInDemo,hideInIndex;public string requirePerk;}
class CraftingFormulaCollection:UObj {List<CraftingFormula> list;object _entries_ReadOnly;public CraftingFormulaCollection(List<CraftingFormula> source){list=source;}public List<CraftingFormula> Current {get{return list;}set{list=value;}}public object ReadOnly {get{return _entries_ReadOnly;}set{_entries_ReadOnly=value;}}}
class PerkRequirement {public Cost cost;public int level;public long requireTime;}
class Perk:UObj {public PerkRequirement Requirement;}
static class Mathf {public static float Abs(float v){return Math.Abs(v);}public static float Max(float a,float b){return Math.Max(a,b);}}
class Fixture {
 const BindingFlags Fields=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
 readonly List<OwnValue> changes=new List<OwnValue>(),capacityValuesPending=new List<OwnValue>();
 readonly Dictionary<OwnedValueKey,OwnValue> valueIndex=new Dictionary<OwnedValueKey,OwnValue>();
 static readonly Dictionary<Type,Dictionary<string,FieldInfo>> fieldCache=new Dictionary<Type,Dictionary<string,FieldInfo>>();
 __METHODS__
 static int Occupied(Inventory unused){return 0;}
 static void Check(bool ok,string why){if(!ok)throw new Exception(why);}
 static CraftingFormula Formula(string id,long cost){return new CraftingFormula{id=id,result=new Entry{id=17,amount=2},cost=new Cost(cost),tags=new[]{"native"},requirePerk="original",unlockByDefault=true};}
 void Off(CraftingFormulaCollection c){var entry=FindValue(17,c,"formulas");if(entry!=null)Restore(changes.IndexOf(entry));}
 static void Main(){
  var t=new Fixture();int count;var source=new List<CraftingFormula>{Formula("one",10),Formula("two",20)};var collection=new CraftingFormulaCollection(source);
  Check(t.FreeFormulas(collection,out count)&&count==2,"free list installed");var first=collection.Current;
  Check(!ReferenceEquals(first,source)&&source[0].cost.money==10&&first[0].cost.money==0,"only own value-type formula copies change, original costs remain untouched");
  object marker=new object();collection.ReadOnly=marker;
  for(int i=0;i<1000;i++)Check(t.FreeFormulas(collection,out count),"warm source check");
  long before=GC.GetAllocatedBytesForCurrentThread();for(int i=0;i<20000;i++)Check(t.FreeFormulas(collection,out count),"stable source check");
  Check(GC.GetAllocatedBytesForCurrentThread()==before&&ReferenceEquals(collection.Current,first)&&ReferenceEquals(collection.ReadOnly,marker),"20,000 unchanged formula checks allocate no lists/objects and never rebuild native read-only view");
  var edit=source[0];edit.result.amount=5;source[0]=edit;Check(t.FreeFormulas(collection,out count)&&collection.Current[0].result.amount==5&&!ReferenceEquals(first,collection.Current),"in-place original source content change creates exactly a fresh correct projection");
  source.Add(Formula("three",30));Check(t.FreeFormulas(collection,out count)&&count==3&&collection.Current.Count==3,"source count growth is included");
  var owned=collection.Current;edit=source[0];edit.cost.money=44;source[0]=edit;Check(t.FreeFormulas(collection,out count)&&ReferenceEquals(owned,collection.Current),"source cost changes do not rebuild the identical free projection");
  t.Off(collection);Check(ReferenceEquals(collection.Current,source)&&source[0].cost.money==44&&source[0].result.amount==5,"off restores actual original source with its own newer content/costs");
  t.FreeFormulas(collection,out count);var foreign=new List<CraftingFormula>{Formula("foreign",99)};collection.Current=foreign;
  Check(t.FreeFormulas(collection,out count)&&collection.Current[0].id=="foreign","a replaced original list becomes the new source owner");
  t.Off(collection);Check(ReferenceEquals(collection.Current,foreign)&&foreign[0].cost.money==99,"off returns external replacement, never stale original list");
  t.FreeFormulas(collection,out count);var externallyEdited=collection.Current;edit=externallyEdited[0];edit.id="edited while owned";externallyEdited[0]=edit;
  t.Off(collection);Check(ReferenceEquals(collection.Current,externallyEdited)&&collection.Current[0].id==edit.id,"off does not overwrite an externally edited owned list");
  edit=externallyEdited[0];edit.cost.money=77;externallyEdited[0]=edit;t.FreeFormulas(collection,out count);
  Check(collection.Current[0].cost.money==0,"foreign cost becomes a new baseline before a new free projection");t.Off(collection);Check(ReferenceEquals(collection.Current,externallyEdited)&&collection.Current[0].cost.money==77,"external cost survives later off");
  var second=new CraftingFormulaCollection(new List<CraftingFormula>{Formula("second",3)});t.FreeFormulas(collection,out count);t.FreeFormulas(second,out count);t.Off(collection);Check(second.Current[0].cost.money==0,"one collection's off never releases another owner");t.Off(second);Check(second.Current[0].cost.money==3,"second collection independently restores");
  var item=new Item();Check(t.Durability(15,item)&&item.Durability==100,"durability lease");var lease=t.FindValue(15,item,"Durability");var read=lease.read;var write=lease.write;
  for(int i=0;i<20000;i++)Check(t.Durability(15,item),"durability readback");Check(ReferenceEquals(read,lease.read)&&ReferenceEquals(write,lease.write),"per-item delegates are created once instead of per frame");
  t.Restore(t.changes.IndexOf(lease));Check(item.Durability==10,"cached durability delegates restore exact original owner");
  t.SetField(7,item,"weight",0f);lease=t.FindValue(7,item,"weight");read=lease.read;write=lease.write;for(int i=0;i<20000;i++)t.SetField(7,item,"weight",0f);
  Check(ReferenceEquals(read,lease.read)&&ReferenceEquals(write,lease.write)&&item.weight==0,"reflection field delegates remain stable");t.Restore(t.changes.IndexOf(lease));Check(item.weight==4,"field baseline restored");
  var req=new PerkRequirement{cost=new Cost(5),level=6,requireTime=7};var perk=new Perk{Requirement=req};t.Requirement(17,perk,"requirement.level",0);var replacement=new PerkRequirement{level=8};perk.Requirement=replacement;
  Check(t.Requirement(17,perk,"requirement.level",0)&&req.level==6&&replacement.level==0,"requirement-object replacement returns old owner and captures new baseline");t.Restore(t.changes.IndexOf(t.FindValue(17,perk,"requirement.level")));Check(replacement.level==8,"new requirement owner restores independently");
  Console.WriteLine("PASS: exact Duckov formulas/delegates: 20,000 no-allocation/no-rebuild source checks, source/content/owner/foreign changes, independent off restoration and cached per-item/per-perk accessors.");
 }
}
'''

compiler=managed_compiler()
refs=compiler.parents[4]/'packs/Microsoft.NETCore.App.Ref'
reference=sorted(refs.iterdir(),key=lambda p:tuple(map(int,p.name.split('.'))))[-1]
framework='net'+'.'.join(reference.name.split('.')[:2])
with tempfile.TemporaryDirectory(prefix='trainerdock-managed-hotpaths-',dir='/private/tmp') as raw:
    stage=Path(raw)
    for module,label,fixture in [('escape-from-duckov','stats',DU),('escape-from-duckov','formulas',DUAUX),('vampire-survivors','stats',VS)]:
        path=ROOT/'Modules'/module/'Sources/Managed';source=(path/'Trainer.cs').read_text()
        if label=='formulas':
            signatures=['sealed class OwnValue','static FieldInfo Field(','static bool Near(','static bool Same(',
                        'OwnValue FindValue(','void AddValue(','void ForgetValue(','bool ApplyValue(','static OwnValue FieldValue(',
                        'bool SetField(','static OwnValue DurabilityValue(','bool Durability(','static OwnValue RequirementValue(',
                        'bool Requirement(','sealed class FormulaOwner','static bool SameFormula(','static bool SameFormulas(',
                        'static OwnValue FormulaValue(','bool FreeFormulas(','bool Restore(']
            fixture=fixture.replace('__METHODS__','\n'.join(method(source,name) for name in signatures));extra=[path/'Safety.cs']
        elif module=='escape-from-duckov':
            fixture=fixture.replace('__OWNSTAT__',method(source,'sealed class OwnStat'))
            fixture=fixture.replace('__NEAR__',method(source,'static bool Near('))
            fixture=fixture.replace('__STAT__',method(source,'bool Stat('))
            for marker,signature in [('SAME','static bool Same('),('OCCUPIED','static int Occupied('),('DRAIN','void DrainCapacity(')]:
                fixture=fixture.replace('__'+marker+'__',method(source,signature))
            extra=[path/'Safety.cs']
        else:
            for marker,signature in [('EGGOWNER','sealed class EggOwner'),('RELEASE','void ReleaseEgg('),('SCALE','void Scale('),('MAINTAIN','void Maintain(')]:
                fixture=fixture.replace('__'+marker+'__',method(source,signature))
            extra=[path/'Policy.cs']
        test=stage/(module+'-'+label+'.cs');test.write_text(fixture)
        output=stage/(module+'-'+label+'.dll')
        subprocess.run(['dotnet',str(compiler),'-noconfig','-nostdlib+','-target:exe','-optimize+','-warnaserror+', '-out:'+str(output),
                        *['-r:'+str(p) for p in sorted((reference/'ref'/framework).glob('*.dll'))],str(test),*[str(p) for p in extra]],check=True)
        output.with_suffix('.runtimeconfig.json').write_text(json.dumps({'runtimeOptions':{'tfm':framework,'framework':{'name':'Microsoft.NETCore.App','version':reference.name}}}))
        subprocess.run(['dotnet',str(output)],check=True)
