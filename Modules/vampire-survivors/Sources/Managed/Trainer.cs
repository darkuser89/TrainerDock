// SPDX-License-Identifier: GPL-3.0-only
// Own Unity/Mono trainer. Original assemblies and save files are never rewritten.
using System;
using System.Collections.Generic;
using System.Reflection;
using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.SceneManagement;
using Cysharp.Threading.Tasks;
using Newtonsoft.Json;
using VampireSurvivors.Framework;
using VampireSurvivors.Framework.NumberTypes;
using VampireSurvivors.Objects;
using VampireSurvivors.Data;
using CC=VampireSurvivors.Objects.Characters.CharacterController;
using UObj=UnityEngine.Object;
namespace MHTVampireSurvivors {
 public static class Native { [MethodImpl(MethodImplOptions.InternalCall)] public static extern void Tick(); }
 public sealed class Trainer:MonoBehaviour {
  static Trainer instance;static bool scheduled;static readonly object gate=new object();
  readonly bool[] wanted=new bool[Policy.Count];readonly double[] values=new double[Policy.Count];
  readonly Dictionary<string,EggOwner> eggs=new Dictionary<string,EggOwner>();
  CC player;GameManager core;PlayerModifierStats stats;PlayerOptionsData config;string owner="loading",note="Warte auf einen geladenen Spieler.";
  bool ready,godOwned,cursorOwned,cursorVisible;CursorLockMode cursorLock;
  sealed class EggOwner { public EggFloat target;public float original,last; }
  static string Json(object v){return JsonConvert.SerializeObject(v);}
  static bool MainThread {get{return PlayerLoopHelper.IsMainThread;}}
  public static bool Bootstrap(){lock(gate){
   if(instance||scheduled)return true;
   if(!Policy.SupportedBuild(typeof(CC).Module.ModuleVersionId,
      typeof(CC).BaseType.Module.ModuleVersionId,
      typeof(PlayerLoopHelper).Module.ModuleVersionId,
      typeof(MonoBehaviour).Module.ModuleVersionId))return false;
   if(PlayerLoopHelper.MainThreadId==0||PlayerLoopHelper.UnitySynchronizationContext==null)return false;
   scheduled=true;try{PlayerLoopHelper.AddContinuation(PlayerLoopTiming.Update,()=>{try{
    if(!MainThread)throw new InvalidOperationException("Kein Unity-GameThread.");
    var go=new GameObject("MHT Vampire Survivors Trainer");UObj.DontDestroyOnLoad(go);instance=go.AddComponent<Trainer>();
   }finally{scheduled=false;}});return true;}catch{scheduled=false;return false;}
  }}
  bool Refresh(){
   if(!MainThread)return false;
   var c=GM.Core;CC p=null;PlayerModifierStats s=null;PlayerOptionsData data=null;
   if(c){p=c.IsOnlineMultiplayer?c.MyOnlinePlayer:c.Player;if(p){s=p.PlayerStats;data=c.PlayerOptions!=null?c.PlayerOptions.MainGameConfig:null;}}
   bool valid=c&&(c.IsGameRunning||c.IsPaused)&&p&&!p.IsDead&&s!=null&&data!=null;
   string next=valid?c.GetInstanceID()+":"+p.GetInstanceID()+":"+s.GetHashCode()+":"+data.GetHashCode()+":"+SceneManager.GetActiveScene().handle:"loading";
   if(owner!=next){ReleaseOwned();Array.Clear(wanted,0,wanted.Length);owner=next;}
   core=c;player=p;stats=s;config=data;ready=valid;note=valid?"Vampire Survivors 1.16.111 · native lokale Anbindung.":"Warte auf einen geladenen lebenden Spieler.";return valid;
  }
  void Update(){if(!MainThread)return;try{Refresh();Native.Tick();if(ready)Maintain();}catch(Exception ex){ReleaseOwned();Array.Clear(wanted,0,wanted.Length);note="Native Prüfung: "+ex.GetType().Name;}}
  void LateUpdate(){if(cursorOwned){Cursor.lockState=CursorLockMode.None;Cursor.visible=true;}}
  void OnDestroy(){ReleaseOwned();ReleaseMouse();}
  void ReleaseEgg(string key){EggOwner v;if(!eggs.TryGetValue(key,out v))return;
   if(Policy.Near(v.target.GetEggValue(),v.last))v.target.SetEggValue(v.original);eggs.Remove(key);
  }
  void Scale(string key,EggFloat target,float factor){
   if(target==null||Policy.Near(factor,1)){ReleaseEgg(key);return;}
   EggOwner v;float current=target.GetEggValue();
   if(!eggs.TryGetValue(key,out v)){v=new EggOwner{target=target,original=current,last=current};eggs.Add(key,v);}
   // Native level-ups update Val, leaving the independently owned EggVal intact.
   // Operators may replace the wrapper while preserving its values.
   if(v.target!=target){if(Policy.Near(current,v.last))v.target=target;else{ReleaseEgg(key);Scale(key,target,factor);return;}}
   if(!Policy.Near(current,v.last))v.original+=current-v.last;
   float value=Policy.Contribution(target.GetValue(),v.original,factor);target.SetEggValue(value);v.last=target.GetEggValue();
  }
  void Maintain(){
   if(wanted[0]){if(!player.PermanentInvulnerability){godOwned=true;player.SetPermanentInvulnerability(true);}if(!player.IsInvul)player.IsInvul=true;}
   else if(godOwned){player.SetPermanentInvulnerability(false);godOwned=false;}
   Scale("move",stats.MoveSpeed,(wanted[1]?3f:1f)*(wanted[7]?(float)values[7]:1f));
   Scale("power",stats.Power,(wanted[2]?10f:1f)*(wanted[8]?(float)values[8]:1f));
   Scale("area",stats.Area,wanted[3]?4f:1f);
   Scale("cooldown",stats.Cooldown,wanted[4]?.1f:1f);
   Scale("growth",stats.Growth,(wanted[5]?100f:1f)*(wanted[6]?(float)values[6]:1f));
  }
  void ReleaseOwned(){foreach(var k in new List<string>(eggs.Keys))ReleaseEgg(k);
   if(godOwned&&player&&player.PermanentInvulnerability)player.SetPermanentInvulnerability(false);godOwned=false;
  }
  float Natural(string key,EggFloat target){EggOwner e;return target.GetValue()+(eggs.TryGetValue(key,out e)?e.original:target.GetEggValue());}
  double Read(int f){switch(f){
   case 0:return player.PermanentInvulnerability&&player.IsInvul?1:0;
   case 1:case 7:return player.PMoveSpeed();case 2:case 8:return player.PPower();case 3:return player.PArea();case 4:return player.PCooldown();case 5:case 6:return player.PGrowth();
   case 9:return player.Xp;case 10:return Natural("growth",stats.Growth);case 11:return (float)stats.Luck;
   case 12:return (double)stats.Revivals-stats.UsedRevivals;case 13:return (float)stats.ReRolls;
   case 14:return config.Coins;case 15:return config.RunCoins;case 16:return config.RunEnemies;case 17:return config.LifetimeCoins;case 18:return config.TotalCoins;
   default:return 0;
  }}
  bool Confirmed(int f){if(!wanted[f])return false;if(f==0)return Read(0)==1;
   string k=f==1||f==7?"move":f==2||f==8?"power":f==3?"area":f==4?"cooldown":"growth";
   EggOwner e;return eggs.TryGetValue(k,out e)&&Policy.Near(e.target.GetEggValue(),e.last);
  }
  public static string Inspect(){if(!MainThread||!instance)return Json(new{kind=0,identity="unavailable",note="Unity-GameThread noch nicht bestätigt."});var t=instance;t.Refresh();return Json(new{kind=t.ready?2:1,identity=t.owner,note=t.note});}
  public static string Effect(int f,bool on,double value){
   if(!MainThread||!instance||!Policy.Valid(f,value))return Json(new{available=false,active=false,note="Keine gültige native Anbindung oder ungültiger Wert."});
   var t=instance;if(!t.Refresh())return Json(new{available=false,active=false,note=t.note});
   if(Policy.Once(f))return Json(new{available=true,active=false,note="Einmalaktion · Aktuell "+t.Read(f)+". Kann vom Spiel gespeichert werden."});
   t.wanted[f]=on;t.values[f]=value;t.Maintain();bool active=t.Confirmed(f);
   return Json(new{available=true,active=active,note="Nativer Wert: "+t.Read(f)});
  }
  public static string OneShot(int f,double value){
   if(!MainThread||!instance||!Policy.Once(f)||!Policy.Valid(f,value))return "Ungültige Einmalaktion.";
   var t=instance;if(!t.Refresh())return t.note;
   switch(f){
    case 9:t.player.Xp=(float)value;break;
    case 10:t.ReleaseEgg("growth");t.stats.Growth.SetValue((float)value-t.stats.Growth.GetEggValue());break;
    case 11:t.stats.Luck.SetValue((float)value-t.stats.Luck.GetEggValue());break;
    case 12:t.stats.Revivals.SetValue(value+t.stats.UsedRevivals-t.stats.Revivals.GetEggValue());break;
    case 13:t.stats.ReRolls.SetValue((float)value-t.stats.ReRolls.GetEggValue());break;
    case 14:t.config.Coins=(float)value;break;case 15:t.config.RunCoins=(float)value;break;case 16:t.config.RunEnemies=(int)value;break;case 17:t.config.LifetimeCoins=(float)value;break;case 18:t.config.TotalCoins=(float)value;break;
   }
   bool ok=Policy.Near(t.Read(f),value);t.Maintain();return ok?"Nativer Wert gesetzt und zurückgelesen.":"Die native Rücklesung stimmt nicht mit dem Auftrag überein.";
  }
  public static void Release(){if(MainThread&&instance){instance.ReleaseOwned();Array.Clear(instance.wanted,0,Policy.Count);}}
  static void ReleaseMouse(){if(instance&&instance.cursorOwned){Cursor.lockState=instance.cursorLock;Cursor.visible=instance.cursorVisible;instance.cursorOwned=false;}}
  public static bool Mouse(bool on){if(!MainThread||!instance)return false;var t=instance;
   if(!on){ReleaseMouse();return false;}if(!t.cursorOwned){t.cursorVisible=Cursor.visible;t.cursorLock=Cursor.lockState;t.cursorOwned=true;}
   Cursor.lockState=CursorLockMode.None;Cursor.visible=true;return Cursor.visible&&Cursor.lockState==CursorLockMode.None;
  }
  // Real readbacks also used by the native contract; no synthetic game objects.
  public static string Observation(){if(!MainThread||!instance||!instance.Refresh())return "{}";var t=instance;var v=new Dictionary<string,object>();
   v["owner"]=t.owner;v["frame"]=Time.frameCount;v["paused"]=t.core.IsPaused;v["position"]=new[]{t.player.transform.position.x,t.player.transform.position.y,t.player.transform.position.z};
   var native=new double[Policy.Count];for(int i=0;i<native.Length;i++)native[i]=t.Read(i);v["values"]=native;v["wanted"]=(bool[])t.wanted.Clone();v["level"]=t.player.Level;v["hp"]=t.player.CurrentHp;
   return Json(v);
  }
 }
}
