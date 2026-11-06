// SPDX-License-Identifier: GPL-3.0-only
// Own trainer; compiled against, never shipped with or written into, original assemblies.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.SceneManagement;
using ItemStatsSystem;
using ItemStatsSystem.Stats;
using Duckov;
using Duckov.Economy;
using Duckov.PerkTrees;
using Cysharp.Threading.Tasks;
using Newtonsoft.Json;
using UObj = UnityEngine.Object;
namespace MHTDuckov {
 public static class Native {
  [MethodImpl(MethodImplOptions.InternalCall)] public static extern void Tick();
 }
 public sealed class Trainer : MonoBehaviour {
  static Trainer instance;
  static bool scheduled;
  static readonly object gate = new object();
  const BindingFlags Fields = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
  readonly bool[] enabledFeatures = new bool[35];
  readonly double[] values = new double[35];
  readonly bool[] confirmed = new bool[35];
  readonly string[] notes = new string[35];
  readonly List<OwnStat> modifiers = new List<OwnStat>();
  readonly List<OwnValue> changes = new List<OwnValue>();
  readonly List<OwnStat> capacityPending = new List<OwnStat>();
  readonly List<OwnValue> capacityValuesPending = new List<OwnValue>();
  CharacterMainControl player;
  Item root;
  string owner = "";
  int mode = 1;
  string contextNote = "Warte auf lokalen Spielstand.";
  bool creditGuard, expGuard;
  long lastExp;
  bool moneyBound, expBound;
  InteractableLootbox loot;
  float scanAt;
  Perk[] perks = new Perk[0];
  bool cursorOwned;
  bool cursorBaseVisible;
  CursorLockMode cursorBaseLock;
  int saveFrame = -1;
  sealed class OwnStat {
   public int feature; public Item item; public Stat stat; public Modifier modifier;
   public Inventory inventory; public int order;
  }
  sealed class OwnValue {
   public int feature; public UObj target; public string key; public object before, last;
   public Func<object> read; public Action<object> write; public bool touched;
  }
  static string Json(object value) { return JsonConvert.SerializeObject(value); }
  static int Id(UObj obj) { return obj ? obj.GetInstanceID() : 0; }
  static FieldInfo Field(Type type, string key) {
   for (; type != null; type = type.BaseType) { var f=type.GetField(key,Fields); if(f!=null)return f; }
   throw new MissingFieldException(key);
  }
  static bool Near(float a,float b) { return !float.IsNaN(a) && !float.IsInfinity(a) && Mathf.Abs(a-b)<=Mathf.Max(0.0001f,Mathf.Abs(b)*0.0001f); }
  static bool Same(object a,object b) { return a is float && b is float ? Near((float)a,(float)b) : Equals(a,b); }
  public static bool Bootstrap() {
   lock(gate) {
    if(instance || scheduled)return true;
    if(typeof(CharacterMainControl).Module.ModuleVersionId.ToString()!="56e93b81-6333-4c06-97b3-f12b74bd5347" ||
       typeof(Item).Module.ModuleVersionId.ToString()!="5ddfaeb4-bb26-458f-86b9-b83fc91d09e2" ||
       typeof(PlayerLoopHelper).Module.ModuleVersionId.ToString()!="49ee66b7-796c-41e4-9343-f4e0bdfbbce3")return false;
    if(PlayerLoopHelper.MainThreadId==0 || PlayerLoopHelper.UnitySynchronizationContext==null)return false;
    scheduled=true;
    try { PlayerLoopHelper.AddContinuation(PlayerLoopTiming.Update,()=> {
     try {
      if(!PlayerLoopHelper.IsMainThread)throw new InvalidOperationException("Kein Unity-GameThread.");
      var go=new GameObject("MHT Duckov Trainer");UObj.DontDestroyOnLoad(go);instance=go.AddComponent<Trainer>();
      Debug.Log("MHT Duckov: native Unity PlayerLoop reached, thread "+System.Threading.Thread.CurrentThread.ManagedThreadId);
     } finally { scheduled=false; }
    }); return true; } catch { scheduled=false; return false; }
   }
  }
  void Awake() {
   InteractableLootbox.OnStartLoot+=StartLoot;
   InteractableLootbox.OnStopLoot+=StopLoot;
   SceneLoader.onStartedLoadingScene+=Loading;
   PauseMenu.onPauseMenuOn+=ReleaseAll;
   Saves.SavesSystem.OnCollectSaveData+=BeforeSave;
   Saves.SavesSystem.OnSetFile+=ReleaseAll;
  }
  void OnDestroy() {
   ReleaseAll();
   InteractableLootbox.OnStartLoot-=StartLoot;InteractableLootbox.OnStopLoot-=StopLoot;
   SceneLoader.onStartedLoadingScene-=Loading;PauseMenu.onPauseMenuOn-=ReleaseAll;
   Saves.SavesSystem.OnCollectSaveData-=BeforeSave;Saves.SavesSystem.OnSetFile-=ReleaseAll;
  }
  void Loading(SceneLoadingContext unused) { ReleaseAll();owner=""; }
  void BeforeSave() { saveFrame=Time.frameCount;ReleaseAll(); }
  void StartLoot(InteractableLootbox box) { loot=box; }
  void StopLoot(InteractableLootbox box) { if(loot==box)loot=null; }
  static bool MainThread { get { return PlayerLoopHelper.IsMainThread; } }
  bool Refresh() {
   if(!MainThread)return false;
   int next=1;string key="loading";string note="Warte auf lokalen Einzelspieler.";
   var level=LevelManager.Instance;var main=CharacterMainControl.Main;
   if(level && main && main==level.MainCharacter && main.IsMainCharacter && main.CharacterItem && main.Health && !main.Health.IsDead && LevelManager.LevelInited && LevelManager.AfterInit && !LevelManager.LevelInitializing && !SceneLoader.IsSceneLoading) {
    var item=main.CharacterItem;
    if(item.Inventory && !item.Inventory.Loading) {
     key=Id(level)+":"+Id(main)+":"+Id(item)+":"+Id(item.Inventory)+":"+Id(level.PetCharacter)+":"+Id(main.agentHolder ? main.agentHolder.CurrentHoldGun : null)+":"+Id(Duckov.UI.ItemUIUtilities.SelectedItem)+":"+Saves.SavesSystem.CurrentSlot;
     next=GameManager.Paused || Saves.SavesSystem.IsSaving || saveFrame==Time.frameCount ? 1 : 2;
     note=next==2 ? "Duckov 2.3.30 · lokaler Einzelspieler." : "Pause/Speichern: eigene Dauereffekte gelöst.";
     player=main;root=item;
    }
   }
   if(next!=2 || key!=owner) { ReleaseAll();owner=key; }
   mode=next;contextNote=note;
   return next==2;
  }
  void Update() {
   if(!MainThread)return;
   try {
    bool ready=Refresh();
    DrainCapacity();
    Native.Tick(); // Native gameplay blocks run exclusively in this Unity Update.
    if(ready)for(int f=0;f<35;f++)if(enabledFeatures[f])ApplyChecked(f);
   } catch(Exception ex) { ReleaseAll();contextNote="Native Prüfung: "+ex.GetType().Name; }
  }
  void LateUpdate() {
   // Native TimeScaleManager writes each Update; respect pauses and bullet time.
   if(MainThread && enabledFeatures[23] && mode==2 && !GameManager.Paused && !SceneLoader.IsSceneLoading) {
    float factor=(float)values[23];
    float native=Time.timeScale;
    Own(23,this,"timeScale",()=>Time.timeScale,v=>Time.timeScale=(float)v,native*factor);
    Own(23,this,"fixedDelta",()=>Time.fixedDeltaTime,v=>Time.fixedDeltaTime=(float)v,Mathf.Max(.0005f,.02f*Time.timeScale));
    confirmed[23]=Near(Time.timeScale,native*factor);
   }
  }
  public static string Inspect() {
   if(!MainThread || !instance)return Json(new {kind=0,identity="unavailable",note="Unity-GameThread noch nicht bestätigt."});
   instance.Refresh();return Json(new {kind=instance.mode,identity=instance.owner,note=instance.contextNote});
  }
  static bool Once(int feature) { return feature==12 || feature==14 || feature==20; }
  public static string Effect(int feature,bool wanted,double value) {
   if(!MainThread || !instance || feature<0 || feature>=35)return Json(new {available=false,active=false,note="Keine native Anbindung."});
   var t=instance;
   if(!t.Refresh())return Json(new {available=false,active=false,note=t.contextNote});
   if(Once(feature)) {
    string current=feature==12 ? EconomyManager.Money.ToString()+" Geld" : feature==20 ? EXPManager.EXP.ToString()+" EP" : t.Available(14) ? Duckov.UI.ItemUIUtilities.SelectedItem.StackCount+" / "+Duckov.UI.ItemUIUtilities.SelectedItem.MaxStackCount+" im Stapel" : "kein eigener Stapel ausgewählt";
    return Json(new {available=t.Available(feature),active=false,note="Einmalaktion · Aktuell "+current+". Kann vom Spiel gespeichert werden."});
   }
   if(!wanted) { t.enabledFeatures[feature]=false;bool released=t.ReleaseFeature(feature);return Json(new {available=t.Available(feature),active=false,note=released ? "Aus · eigene Effekte gelöst." : "Aus · belegte Zusatzplätze bleiben bis zum Leeren erhalten."}); }
   if(double.IsNaN(value)||double.IsInfinity(value))return Json(new {available=false,active=false,note="Ungültiger Wert."});
   t.values[feature]=value;t.enabledFeatures[feature]=true;t.ApplyChecked(feature);
   return Json(new {available=t.Available(feature),active=t.confirmed[feature],note=t.notes[feature] ?? "Keine native Rücklesebestätigung."});
  }
  bool Available(int f) {
   if(!player || !root)return false;
   if(f==5 || f==6)return player.agentHolder && player.agentHolder.CurrentHoldGun && player.agentHolder.CurrentHoldGun.Holder==player;
   if(f==14) { var selected=Duckov.UI.ItemUIUtilities.SelectedItem;return selected && selected.GetCharacterItem()==root && selected.Stackable; }
   if(f==29)return LevelManager.Instance && LevelManager.Instance.PetCharacter && LevelManager.Instance.PetCharacter.CharacterItem && LevelManager.Instance.PetCharacter.CharacterItem.Inventory;
   if(f==24)return GameCamera.Instance;
   if(f==25 || f==26)return GameClock.Instance;
   if(f==19)return LevelManager.Instance && LevelManager.Instance.FogOfWarManager;
   return true;
  }
  void ApplyChecked(int f) {
   try {
    if(!Available(f)) { confirmed[f]=false;notes[f]="Passende Ausrüstung oder lokaler Besitzer fehlt.";ReleaseFeature(f);return; }
    foreach(var c in changes)if(c.feature==f && f!=23)c.touched=false;
    bool result=Apply(f,(float)values[f]);
    for(int i=changes.Count-1;i>=0;i--)if(changes[i].feature==f && f!=23 && !changes[i].touched)Restore(i);
    confirmed[f]=result;
    if(notes[f]==null || !result)notes[f]=result ? "Nativ rückgelesen." : "Warte auf die passende native Aktion.";
   } catch(Exception ex) { confirmed[f]=false;notes[f]="Native Prüfung: "+ex.GetType().Name; }
  }
  bool Stat(int f,Item item,string key,float amount,bool multiply=false,bool target=false) {
   if(!item)return false;var stat=item.GetStat(key);if(stat==null)return false;
   var own=modifiers.Find(x=>x.feature==f && x.item==item && x.stat==stat);
   if(own==null) { own=new OwnStat {feature=f,item=item,stat=stat,order=1000000000+f};modifiers.Add(own); }
   if(own.modifier!=null)stat.RemoveModifier(own.modifier);
   float before=stat.Value;
   float modifier=target ? amount-before : multiply ? amount-1 : amount;
   own.modifier=new Modifier(multiply ? ModifierType.PercentageMultiply : ModifierType.Add,modifier,true,own.order,own);
   stat.AddModifier(own.modifier);
   float expected=target ? amount : multiply ? before*amount : before+amount;
   return stat.Modifiers.Contains(own.modifier) && Near(stat.Value,expected);
  }
  bool Own(int f,UObj target,string key,Func<object> read,Action<object> write,object value) {
   if(!target)return false;
   var entry=changes.Find(c=>c.feature==f && c.target==target && c.key==key);
   if(entry==null) { entry=new OwnValue {feature=f,target=target,key=key,before=read(),read=read,write=write};changes.Add(entry); }
   entry.touched=true;if(!Same(read(),value))write(value);entry.last=value;return Same(read(),value);
  }
  bool SetField(int f,UObj target,string key,object value) {
   if(!target)return false;var field=Field(target.GetType(),key);
   return Own(f,target,key,()=>field.GetValue(target),v=>field.SetValue(target,v),value);
  }
  bool Restore(int index) {
   var c=changes[index];changes.RemoveAt(index);
   if(c.target && Same(c.read(),c.last)) {
    if(c.feature==29 && c.target is Inventory && !CapacitySafety.CanFinish((int)c.before,Occupied((Inventory)c.target))) {
     capacityValuesPending.Add(c);return false;
    }
    c.write(c.before);return Same(c.read(),c.before);
   }
   return true;
  }
  static int Occupied(Inventory inventory) {
   if(!inventory)return 0;var list=inventory.Content;
   for(int i=list.Count-1;i>=0;i--)if(list[i])return i+1;
   return 0;
  }
  bool ReleaseFeature(int f) {
   confirmed[f]=false;notes[f]=null;
   if(f==26) { if(!enabledFeatures[25] && !enabledFeatures[26])return ReleaseFeature(25);return true; }
   if(f==25 && enabledFeatures[26])return true;
   bool complete=!capacityPending.Any(x=>x.feature==f) && !capacityValuesPending.Any(x=>x.feature==f);
   var weightRoots=new HashSet<Item>();
   if(f==7)foreach(var c in changes)if(c.feature==7 && c.target is Item && c.target)weightRoots.Add(((Item)c.target).GetRoot());
   for(int i=modifiers.Count-1;i>=0;i--)if(modifiers[i].feature==f) {
    var m=modifiers[i];modifiers.RemoveAt(i);
    if(m.item && m.modifier!=null) {
     m.stat.RemoveModifier(m.modifier);
     if(m.inventory && Occupied(m.inventory)>Mathf.RoundToInt(m.stat.Value)) {
      int occupied=Occupied(m.inventory);
      m.modifier=new Modifier(ModifierType.Add,occupied-m.stat.Value,true,m.order,m);m.stat.AddModifier(m.modifier);
      capacityPending.Add(m);complete=false;
     }
    }
   }
   for(int i=changes.Count-1;i>=0;i--)if(changes[i].feature==f)complete=Restore(i) && complete;
   foreach(var item in weightRoots)if(item)item.RecalculateTotalWeight();
   if(f==13 && moneyBound) { EconomyManager.OnMoneyChanged-=MoneyChanged;moneyBound=false; }
   if(f==21 && expBound) { EXPManager.onExpChanged-=ExpChanged;expBound=false; }
   confirmed[f]=false;notes[f]=null;return complete;
  }
  void DrainCapacity() {
   for(int i=capacityValuesPending.Count-1;i>=0;i--) {
    var c=capacityValuesPending[i];var inventory=c.target as Inventory;
    if(!inventory || !Same(c.read(),c.last)) { capacityValuesPending.RemoveAt(i);continue; }
    int occupied=Occupied(inventory), baseline=(int)c.before;
    int next=CapacitySafety.Recover(baseline,occupied);
    c.write(next);c.last=next;
    if(CapacitySafety.CanFinish(baseline,occupied) && Same(c.read(),baseline))capacityValuesPending.RemoveAt(i);
   }
   for(int i=capacityPending.Count-1;i>=0;i--) {
    var m=capacityPending[i];
    if(!m.item || !m.inventory) { capacityPending.RemoveAt(i);continue; }
    m.stat.RemoveModifier(m.modifier);
    int occupied=Occupied(m.inventory);
    if(occupied<=Mathf.RoundToInt(m.stat.Value)) { capacityPending.RemoveAt(i);continue; }
    m.modifier=new Modifier(ModifierType.Add,occupied-m.stat.Value,true,m.order,m);m.stat.AddModifier(m.modifier);
   }
  }
  void ReleaseAll() {
   Array.Clear(enabledFeatures,0,enabledFeatures.Length);
   for(int f=0;f<35;f++)ReleaseFeature(f);
   ReleaseMouse();
  }
  public static void Release() { if(MainThread && instance)instance.ReleaseAll(); }
  bool Apply(int f,float value) {
   notes[f]=null;
   var health=player.Health;var gun=player.agentHolder ? player.agentHolder.CurrentHoldGun : null;
   switch(f) {
    case 0:return Own(f,health,"Invincible",()=>health.Invincible,v=>health.SetInvincible((bool)v),true);
    case 1:health.SetHealth(health.MaxHealth);return Near(health.CurrentHealth,health.MaxHealth);
    case 2: {
     bool zero=Stat(f,root,"StaminaDrainRate",0,true);
     bool filled=SetField(f,player,"currentStamina",player.MaxStamina);
     return zero && filled && Near(player.CurrentStamina,player.MaxStamina);
    }
    case 3: {
     bool zero=Stat(f,root,"EnergyCost",0,true);player.CurrentEnergy=player.MaxEnergy;return zero && Near(player.CurrentEnergy,player.MaxEnergy);
    }
    case 4: {
     bool zero=Stat(f,root,"WaterCost",0,true);player.CurrentWater=player.MaxWater;return zero && Near(player.CurrentWater,player.MaxWater);
    }
    case 5: {
     var setting=gun.GunItemSetting;if(!setting || setting.TargetBulletID<=0 || setting.Capacity<1)return false;
     var setter=typeof(ItemSetting_Gun).GetProperty("bulletCount",Fields).GetSetMethod(true);
     return Own(f,setting,"bulletCount",()=>setting.BulletCount,v=>setter.Invoke(setting,new object[]{v}),setting.Capacity);
    }
    case 6:return Stat(f,gun.Item,"ReloadTime",.01f,false,true);
    case 7: {
     bool ok=true;foreach(var item in root.GetAllChildren(true,true))if(item && item.GetCharacterItem()==root)ok=SetField(f,item,"weight",0f) && ok;
     ok=SetField(f,root,"weight",0f) && ok;root.RecalculateTotalWeight();return ok && Near(root.TotalWeight,0);
    }
    case 8:return Stat(f,root,"GunCritRateGain",1) & Stat(f,root,"MeleeCritRateGain",1);
    case 9:return Stat(f,root,"GunDamageMultiplier",1000,true) & Stat(f,root,"MeleeDamageMultiplier",1000,true);
    case 10:return Stat(f,root,"GunDamageMultiplier",value,true) & Stat(f,root,"MeleeDamageMultiplier",value,true);
    case 11:return Stat(f,root,"BodyArmor",value,true) & Stat(f,root,"HeadArmor",value,true);
    case 13: {
     if(!moneyBound) { EconomyManager.OnMoneyChanged+=MoneyChanged;moneyBound=true; }
     var ev=typeof(EconomyManager).GetField("OnMoneyChanged",BindingFlags.Static|BindingFlags.NonPublic).GetValue(null) as Delegate;
     notes[f]="Nativer Geldgewinn-Handler gebunden; nur positive Einnahmen.";return ev!=null && ev.GetInvocationList().Any(d=>ReferenceEquals(d.Target,this) && d.Method.Name=="MoneyChanged");
    }
    case 15: {
     int count=0;bool ok=true;foreach(var item in root.GetAllChildren(true,true))if(item && item.GetCharacterItem()==root && item.UseDurability) { count++;ok=Own(f,item,"Durability",()=>item.Durability,v=>item.Durability=(float)v,item.MaxDurabilityWithLoss) && ok; }
     return count>0 && ok;
    }
    case 16: {
     if(!loot)return false;var target=(Item)Field(typeof(InteractableLootbox),"inspectingItem").GetValue(loot);
     if(!target || !target.Inspecting)return false;
     float duration=(float)Field(typeof(InteractableLootbox),"inspectTime").GetValue(loot);
     return SetField(f,loot,"inspectTimer",duration);
    }
    case 17:return FreeRequirements();
    case 18:return ResearchTime();
    case 19: {
     var fog=LevelManager.Instance.FogOfWarManager;
     if(!fog || !fog.fogOfWar)return false;
     var world=fog.fogOfWar;var appearance=world.GetFowAppearance();
     object none=Enum.Parse(appearance.GetType(),"None");
     var setter=world.GetType().GetMethod("SetFowAppearance");
     return Own(f,world,"fogAppearance",()=>world.GetFowAppearance(),v=>setter.Invoke(world,new object[]{v}),none) & SetField(f,fog,"allVision",true);
    }
    case 21: {
     if(!expBound) { lastExp=EXPManager.EXP;EXPManager.onExpChanged+=ExpChanged;expBound=true; }
     notes[f]="Nativer EP-Gewinn-Handler gebunden; nur neue positive EP.";
     return EXPManager.onExpChanged!=null && EXPManager.onExpChanged.GetInvocationList().Any(d=>ReferenceEquals(d.Target,this) && d.Method.Name=="ExpChanged");
    }
    case 22:return Stat(f,root,"WalkSpeed",value,true) & Stat(f,root,"RunSpeed",value,true);
    case 23:notes[f]="Zeitfaktor wird nach dem nativen Update rückgelesen.";return confirmed[f];
    case 24: {
     var cam=GameCamera.Instance;
     bool ok=Own(f,cam,"defaultFOV",()=>cam.defaultFOV,v=>cam.defaultFOV=(float)v,value) & Own(f,cam,"adsFOV",()=>cam.adsFOV,v=>cam.adsFOV=(float)v,value);
     cam.UpdateFov(0);return ok && cam.mainVCam && Near(cam.mainVCam.m_Lens.FieldOfView,value);
    }
    case 25:case 26: {
     var clock=GameClock.Instance;
     // Shared clock owner keeps freeze and rate independent.
     float rate=enabledFeatures[25] ? 0 : enabledFeatures[26] ? (float)values[26] : 1;
     return Own(25,clock,"clockTimeScale",()=>clock.clockTimeScale,v=>clock.clockTimeScale=(float)v,rate);
    }
    case 27:return Stat(f,root,"MaxHealth",value,false,true);
    case 28:return Stat(f,root,"Stamina",value,false,true);
    case 29: { // Pet inventory belongs to the actual local pet, never an arbitrary NPC.
     var pet=LevelManager.Instance.PetCharacter;var item=pet.CharacterItem;
     var inv=item.Inventory;return Own(f,inv,"capacity",()=>inv.Capacity,v=>inv.SetCapacity(Mathf.Max((int)v,Occupied(inv))),Mathf.Max(Mathf.RoundToInt(value),Occupied(inv)));
    }
    case 30:return Stat(f,root,"MaxWeight",value,false,true);
    case 31: {
     var inv=root.Inventory;float wanted=Mathf.Max(value,Occupied(inv));
     bool ok=Stat(f,root,"InventoryCapacity",wanted,false,true);
     var entry=modifiers.Find(x=>x.feature==f && x.item==root);if(entry!=null)entry.inventory=inv;
     // The game reconciles this stat in its native update; no detaching/dropping.
     inv.SetCapacity(Mathf.RoundToInt(wanted));return ok && inv.Capacity==Mathf.RoundToInt(wanted);
    }
    case 32:return Stat(f,root,"StaminaDrainRate",value,true);
    case 33:return Stat(f,root,"EnergyCost",value,true);
    case 34:return Stat(f,root,"WaterCost",value,true);
   }
   return false;
  }
  void MoneyChanged(long before,long after) {
   if(creditGuard || !enabledFeatures[13] || !Refresh() || after<=before)return;
   long extra=(long)Math.Min(1000000000,Math.Max(0,(after-before)*(values[13]-1)));
   if(extra==0)return;
   creditGuard=true;try { long old=EconomyManager.Money;bool ok=EconomyManager.Add(extra);confirmed[13]=ok && EconomyManager.Money==old+extra;notes[13]=confirmed[13] ? "Geldgewinn nativ multipliziert und rückgelesen." : "Geldgewinn nicht bestätigt."; } finally { creditGuard=false; }
  }
  void ExpChanged(long after) {
   long delta=after-lastExp;lastExp=after;
   if(expGuard || !enabledFeatures[21] || !Refresh() || delta<=0)return;
   int extra=(int)Math.Min(1000000000,Math.Max(0,delta*(values[21]-1)));
   if(extra==0)return;
   expGuard=true;try { long old=EXPManager.EXP;bool ok=EXPManager.AddExp(extra);confirmed[21]=ok && EXPManager.EXP==old+extra;lastExp=EXPManager.EXP;notes[21]=confirmed[21] ? "EP-Gewinn nativ multipliziert und rückgelesen." : "EP-Gewinn nicht bestätigt."; } finally { expGuard=false; }
  }
  void ScanPerks() { if(Time.unscaledTime>=scanAt) { scanAt=Time.unscaledTime+1;perks=UObj.FindObjectsByType<Perk>(FindObjectsInactive.Include,FindObjectsSortMode.None); } }
  bool FreeRequirements() {
   ScanPerks();bool ok=true;int count=0;
   foreach(var perk in perks)if(perk && perk.Requirement!=null) {
    var req=perk.Requirement;count++;
    ok=Own(17,perk,"requirement.cost",()=>req.cost,v=>req.cost=(Cost)v,new Cost(0L)) && ok;
    ok=Own(17,perk,"requirement.level",()=>req.level,v=>req.level=(int)v,0) && ok;
   }
   var collection=CraftingFormulaCollection.Instance;
   if(collection) {
    var field=Field(typeof(CraftingFormulaCollection),"list");
    var original=(List<CraftingFormula>)field.GetValue(collection);
    // Replace only our own shallow list; preserve formula identity and unlocks.
    var existing=changes.Find(x=>x.feature==17 && x.target==collection && x.key=="formulas");
    var source=existing!=null ? (List<CraftingFormula>)existing.before : original;
    var free=source.Select(x=> { x.cost=new Cost(0L);return x; }).ToList();
    ok=Own(17,collection,"formulas",()=>field.GetValue(collection),v=> { field.SetValue(collection,v);Field(typeof(CraftingFormulaCollection),"_entries_ReadOnly").SetValue(collection,null); },free) && ok;
    count+=free.Count;
   }
   notes[17]="Native Kosten/Levelbedingungen entfernt; vorhandene Freischaltungen bleiben maßgeblich.";
   return count>0 && ok;
  }
  bool ResearchTime() {
   ScanPerks();int count=0;bool ok=true;
   foreach(var perk in perks)if(perk && perk.Requirement!=null) { var req=perk.Requirement;count++;ok=Own(18,perk,"requirement.time",()=>req.requireTime,v=>req.requireTime=(long)v,0L) && ok; }
   notes[18]="Native Forschungsdauer 0; Forschung weiterhin selbst starten und bestätigen.";
   return count>0 && ok;
  }
  public static string OneShot(int feature,double value) {
   if(!MainThread || !instance || !instance.Refresh() || !Once(feature) || double.IsNaN(value) || double.IsInfinity(value) || value<0 || value!=Math.Floor(value))return "Aktion wegen ungültigem Kontext/Wert verworfen.";
   var t=instance;
   if(feature==12 && value<=1000000000000) {
    t.creditGuard=true;try { long target=(long)value;bool ok=EconomyManager.Add(target-EconomyManager.Money);return ok && EconomyManager.Money==target ? "Geldbetrag nativ bestätigt." : "Keine Geldbestätigung."; } finally { t.creditGuard=false; }
   }
   if(feature==20 && value<=1000000000) {
    t.expGuard=true;try { long target=(long)value;long delta=target-EXPManager.EXP;if(delta<int.MinValue || delta>int.MaxValue)return "EP-Differenz zu groß.";bool ok=EXPManager.AddExp((int)delta);t.lastExp=EXPManager.EXP;return ok && EXPManager.EXP==target ? "EP-Betrag nativ bestätigt." : "Keine EP-Bestätigung."; } finally { t.expGuard=false; }
   }
   if(feature==14 && t.Available(feature)) {
    var item=Duckov.UI.ItemUIUtilities.SelectedItem;
    if(value<1 || value>item.MaxStackCount)return "Wert überschreitet die native Stapelgrenze ("+item.MaxStackCount+").";
    item.StackCount=(int)value;return item.StackCount==(int)value ? "Ausgewählter eigener Stapel nativ bestätigt." : "Keine Stapelbestätigung.";
   }
   return "Aktion nicht verfügbar.";
  }
  void ReleaseMouse() {
   if(cursorOwned) { if(Cursor.visible && Cursor.lockState==CursorLockMode.None) { Cursor.visible=cursorBaseVisible;Cursor.lockState=cursorBaseLock; }cursorOwned=false; }
  }
  public static bool Mouse(bool wanted) {
   if(!MainThread || !instance)return false;var t=instance;
   if(!wanted || !t.Refresh()) { t.ReleaseMouse();return false; }
   if(!t.cursorOwned) { t.cursorBaseVisible=Cursor.visible;t.cursorBaseLock=Cursor.lockState;t.cursorOwned=true; }
   Cursor.visible=true;Cursor.lockState=CursorLockMode.None;return Cursor.visible && Cursor.lockState==CursorLockMode.None;
  }
 }
}
