#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Check both original TLD store contracts offline; never load/start either app.

The consumed fields/methods are resolved from each original metadata and ARM64
Il2CppType table. Numeric metadata indices, field offsets and function addresses
are not transferred between versions. This is not an in-game effect test.
"""
import importlib.util,struct
from pathlib import Path
sp=importlib.util.spec_from_file_location('tld_original',Path(__file__).with_name('OriginalMethods.py'));MOD=importlib.util.module_from_spec(sp);sp.loader.exec_module(MOD)
class Contract(MOD.Original):
 def __init__(self,app):
  super().__init__(app);M=self.metadata
  self.typedefs=[M.type(i) for i in range(M.types[1])];self.typenames={t['index']:t['namespace']+'.'+t['name'] for t in self.typedefs};self.classes={}
  for i in range(M.images[1]):
   image,first,count=M.image(i)
   for t in self.typedefs[first:first+count]:self.classes[image,t['namespace']+'.'+t['name']]=t
  samples=[t for t in self.typedefs if (t['namespace'],t['name']) in [('System','Boolean'),('System','Single'),('','GameManager'),('UnityEngine.LowLevel','PlayerLoopSystemInternal')]]
  maximum=max(t['byval'] for t in self.typedefs);candidates=[]
  for at in range(0,len(self.data)-16,8):
   n,p=struct.unpack_from('<QQ',self.data,at)
   if not maximum<n<300000:continue
   try:
    loc=self.file(p)
    if all(struct.unpack_from('<Q',self.data,self.file(struct.unpack_from('<Q',self.data,loc+t['byval']*8)[0]))[0]==t['index'] for t in samples):candidates.append(loc)
   except (ValueError,struct.error):pass
  if len(candidates)!=1:raise ValueError(candidates)
  self.table=candidates[0];self.descriptions={}
 def pointertype(self,p,depth=0):
  if depth>8:raise ValueError('recursion')
  data,bits=struct.unpack_from('<QI',self.data,self.file(p));kind=(bits>>16)&255
  if kind in list(range(1,15))+[17,18,24,25,28]:name=self.typenames.get(data,'?'+str(data))
  elif kind in [15,16,29]:name=self.pointertype(data,depth+1)+{15:'*',16:'&',29:'[]'}[kind]
  elif kind==21:
   base,context=struct.unpack_from('<QQ',self.data,self.file(data));argc,argp=struct.unpack_from('<Q Q',self.data,self.file(context));args=[self.pointertype(struct.unpack_from('<Q',self.data,self.file(argp)+8*i)[0],depth+1) for i in range(argc)]
   name=self.pointertype(base,depth+1)+'<'+','.join(args)+'>'
  else:name='kind#'+str(kind)
  return name+('&' if bits&(1<<30) else '')
 def type(self,index):return self.pointertype(struct.unpack_from('<Q',self.data,self.table+8*index)[0])
 def describe(self,full,image='Assembly-CSharp.dll'):
  if (image,full) in self.descriptions:return self.descriptions[image,full]
  M=self.metadata;t=self.classes[image,full];lines=[]
  for i in range(t['field'],t['field']+t['field_count']):
   name,typ,_=struct.unpack_from('<IiI',M.data,M.fields[0]+12*i);pointer=struct.unpack_from('<Q',self.data,self.table+8*typ)[0];bits=struct.unpack_from('<QI',self.data,self.file(pointer))[1];lines.append(('field',M.string(name),self.type(typ),bool(bits&0x10)))
  for i in range(t['method'],t['method']+t['method_count']):
   row=struct.unpack_from('<7i4H',M.data,M.methods[0]+36*i);args=[self.type(struct.unpack_from('<IIi',M.data,M.parameters[0]+12*p)[2]) for p in range(row[4],row[4]+row[-1])];lines.append(('method',M.string(row[0])+':'+str(row[-1]),self.type(row[2]),args,bool(row[7]&0x10)))
  self.descriptions[image,full]=lines;return lines

# All 44 feature paths, owner/context/save checks and cursor/PlayerLoop bindings.
# Field/method types and staticness must match the existing original Steam ABI.
CONTRACTS={
 '.GameManager':('m_ActiveScene m_vpFPSPlayer','AllowedToSave:1 SaveGameAndDisplayHUDMessage:0'),
 '.PlayerManager':('m_StartHasBeenCalled m_SceneTransitionStarted m_ControlMode m_Ghost','PlayerIsDead:0 PlayerIsInvisibleToAi:0 AddItemCONSOLE:3'),
 '.Condition':('m_Invulnerable m_CurrentHP','GetAdjustedMaxHP:0 HasAffliction:0'),
 '.Freezing':('m_CurrentFreezing',''), '.Fatigue':('m_CurrentFatigue',''), '.Thirst':('m_CurrentThirst',''),
 '.Hunger':('m_CurrentReserveCalories','GetAdjustedMaxReserveCalories:0'),
 '.Infection':('','HasInfection:0 Cure:0'), '.InfectionRisk':('','HasInfectionRisk:0 Cure:0'),
 '.ExperienceModeManager':('','GetCurrentExperienceMode:0'),
 'TLD.Gameplay.ExperienceMode':('m_CalorieBurnScale m_ThirstRateScale m_FreezingRateScale m_FatigueRateScale',''),
 '.PlayerMovement':('m_UnlimitedSprint m_SprintStamina m_SprintStaminaUsagePerSecond m_ForceNoRandomSprain m_IsCrouching','get_CurrentMaxStamina:0'),
 '.SprainedWrist':('m_IsNoSprainWristForced','HasSprainedWrist:0 Cure:0 SprainedWristStart:2'),
 '.SprainedAnkle':('m_ChanceSprainAfterFall','HasSprainedAnkle:0 Cure:0 SprainedAnkleStart:2'),
 '.SprainPain':('','HasSprainPain:0 Cure:0'), '.Headache':('','HasHeadache:0 Cure:0'),
 '.BrokenBody':('m_DamageMultiplier <HasAffliction>k__BackingField',''),
 '.Inventory':('m_Items m_ForceOverrideWeight m_OverridedWeight',''),
 'TLD.Gear.GearItemObject':('m_GearItem',''),
 '.Encumber':('m_MaxCarryCapacity m_MaxCarryCapacityWhenExhausted m_NoSprintCarryCapacity m_NoWalkCarryCapacity',''),
 '.GearItem':('m_InPlayerInventory m_StackableItem m_DegradeOnUse m_FoodItem m_WaterSupply m_LiquidItem m_GunItem m_HaltDecay m_CurrentHP m_DecayScalar',''),
 '.StackableItem':('m_Units',''), '.DegradeOnUse':('m_DegradeHP',''),
 '.FoodItem':('m_MustConsumeAll m_CaloriesRemaining m_CaloriesTotal',''),
 '.WaterSupply':('m_VolumeInLiters',''), '.LiquidItem':('m_Liquid',''),
 'TLD.IntBackedUnit.ItemWeight':('m_Units','FromKilograms:1'),
 'TLD.IntBackedUnit.ItemLiquidVolume':('m_Units','FromLiters:1 Max:2'),
 'TLD.Gear.BlueprintManager':('','get_Instance:0 GetAllBlueprints:0 UnlockSilent:1'),
 'TLD.Gear.BlueprintData':('m_RequiredGear m_RequiredPowder m_RequiredLiquid m_RequiredTool m_RequiresLight m_RequiresLitFire m_RequiredCraftingLocation','get_Locked:0'),
 '.CraftingLocation':('Anywhere',''), '.Panel_Crafting':('m_CraftingDisplayTimeSeconds m_CraftingOperation',''),
 'TLD.Gear.CraftingOperation':('m_RealTimeDuration','get_InProgress:0'),
 '.SkillsManager':('','GetNumSkills:0 GetSkillFromIndex:1'), '.Skill':('','GetMaxPoints:0 SetPoints:2 GetPoints:0'),
 '.TimeOfDay':('m_LockedTOD m_WeatherSystem','SetNormalizedTime:1 GetNormalizedTime:0'),
 '.WeatherTransition':('m_SuppressBlizzards',''), '.Weather':('m_LockedAirTemperature','IsBlizzard:0 LockAirTemperature:1'),
 '.WeatherStage':('LightSnow HeavySnow Blizzard Clear Cloudy LightFog DenseFog',''),
 '.UniStormWeatherSystem':('','SetWeatherStage:3 GetWeatherStage:0'),
 '.SpawnRegion':(' '.join('m_MaxSimultaneousSpawns'+period+difficulty for period in ['Day','Night'] for difficulty in ['Pilgrim','Voyageur','Stalker','Interloper'])+' '+' '.join('m_MaxRespawnsPerDay'+difficulty for difficulty in ['Pilgrim','Voyageur','Stalker','Interloper']),'IsPredator:0'),
 '.AuroraManager':('m_ForceAuroraNextOpportunity','ForceAuroraNextOpportunity:3 AuroraIsActive:0'),
 '.CameraDebugMode':('','get_IsLock:0 get_IsFly:0'), '.ConsoleManager':('','CONSOLE_fly:0'), '.FlyMode':('m_Camera','Exit:0'),
 '.GunItem':('m_ClipSize m_DamageHP m_ForceNoJam','NumRoundsInClip:0 AddRoundsToClip:2'),
 '.vp_FPSPlayer':('Controller',''), '.vp_FPSController':('MotorAcceleration MotorVelocityMax',''),
 '.SaveGameSystem':('m_CurrentGameId','GetCurrentSaveName:0'), '.SaveGameSlots':('m_SaveSlots',''),
 '.SlotData':('m_GameId m_InternalName',''), '.SaveGameDataPC':('','GetFullPath:1'), '.PlayerControlMode':('Dead',''),
 '.InputManager':('s_IgnoreInput m_CursorState','ShowCursor:1'),
 'UnityEngine.Time':('','get_timeScale:0 set_timeScale:1'),
 'UnityEngine.Cursor':('','get_visible:0 get_lockState:0 set_visible:1 set_lockState:1'),
 'UnityEngine.LowLevel.PlayerLoop':('','GetCurrentPlayerLoopInternal:0 SetPlayerLoopInternal:1'),
 'UnityEngine.LowLevel.PlayerLoopSystemInternal':('type updateDelegate updateFunction loopConditionFunction numSubSystems',''),
}
GETTERS='GetPlayerManagerComponent GetInventoryComponent GetConditionComponent GetFreezingComponent GetFatigueComponent GetThirstComponent GetHungerComponent GetInfectionComponent GetInfectionRiskComponent GetExperienceModeManagerComponent GetPlayerMovementComponent GetSprainedWristComponent GetSprainedAnkleComponent GetSprainPainComponent GetHeadacheComponent GetBrokenBody GetEncumberComponent GetTimeOfDayComponent GetWeatherComponent GetSkillsManager GetAuroraManager'
CONTRACTS['.GameManager']=(CONTRACTS['.GameManager'][0],CONTRACTS['.GameManager'][1]+' '+' '.join(n+':0' for n in GETTERS.split()))

def lookup(original,full,kind,name):
 image='UnityEngine.CoreModule.dll' if full.startswith('UnityEngine.') else 'Assembly-CSharp.dll'
 if (image,full) not in original.classes:
  possibilities=[key for key in original.classes if key[1]==full]
  if len(possibilities)!=1:raise ValueError(f'Ursprünglicher Typ fehlt oder ist mehrdeutig: {full}')
  image=possibilities[0][0]
 for _ in range(32):
  matches=[row for row in original.describe(full,image) if row[0]==kind and row[1]==name]
  if matches:
   if len(matches)!=1:raise ValueError(f'{image}:{full}::{name} ist nicht eindeutig')
   return matches[0][2:]
  t=original.classes[image,full]
  parent=struct.unpack_from('<i',original.metadata.data,original.metadata.types[0]+88*t['index']+16)[0]
  if parent<0:break
  full=original.type(parent)
  possibilities=[key for key in original.classes if key[1]==full]
  if len(possibilities)!=1:break
  image=possibilities[0][0]
 raise ValueError(f'Ursprüngliche {kind}-Anbindung fehlt: {full}::{name}')

def main():
 import argparse,hashlib,re,subprocess
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--steam',required=True,type=Path);parser.add_argument('--epic',required=True,type=Path)
 args=parser.parse_args();apps=[args.steam,args.epic]
 metadata='Contents/Resources/Data/il2cpp_data/Metadata/global-metadata.dat'
 hashes=['fa5e43f8f4e4ee31cb696e5f01ddd3983aff46a59ae5652db3643cd3b9175d8b','2452161252ccb39634938495612c1cee70f28d7cda517444183588c8007c9636']
 for app,expected in zip(apps,hashes):
  path=app/metadata
  if not path.is_file():raise ValueError(f'Original fehlt; Prüfung nicht ausgeführt: {path}')
  if hashlib.sha256(path.read_bytes()).hexdigest()!=expected:raise ValueError(f'Unbekannter Original-Metadatenbuild: {app}')
 originals=[Contract(app) for app in apps];count=0
 for owner,(fields,methods) in CONTRACTS.items():
  for kind,entries in [('field',fields),('method',methods)]:
   for member in entries.split():
    a,b=[lookup(o,owner,kind,member) for o in originals]
    if a!=b:raise ValueError(f'Abweichender Storevertrag {owner}::{member}: Steam={a}, Epic={b}')
    count+=1
 source=Path(__file__).parents[2]/'Modules/the-long-dark/Sources/IL2CPP.mm'
 exports=set(re.findall(r'LOAD\(\w+,"([^"]+)"\)',source.read_text()))
 for app in apps:
  data=subprocess.check_output(['nm','-gjU','-arch','arm64',str(app/'Contents/Frameworks/GameAssembly.dylib')],text=True)
  available={line.removeprefix('_') for line in data.splitlines()}
  if missing:=exports-available:raise ValueError(f'Ursprüngliche IL2CPP-Exports fehlen: {sorted(missing)}')
 # The original PlayerLoop/native-main-thread provider is exactly shared.
 unity=[hashlib.sha256((app/'Contents/Frameworks/UnityPlayer.dylib').read_bytes()).hexdigest() for app in apps]
 if unity!=['aabaa19667e49d42f740044212bd30fed4e73dde9c359ae9d2ad07d725160359']*2:raise ValueError('Unbekannter ursprünglicher UnityPlayer')
 print(f'BESTANDEN: {count} normalisierte Feld-/Methodenverträge für alle 44 Funktionspfade, {len(exports)} IL2CPP-Exports je Original und byteidentischer UnityPlayer. Nur statisch; keine Ingame-Wirkungen geprüft, kein Spiel gestartet.')

if __name__=='__main__':
 try:main()
 except (ValueError,KeyError,OSError,struct.error) as error:
  import sys
  print(f'FEHLER: {error}',file=sys.stderr);sys.exit(1)
