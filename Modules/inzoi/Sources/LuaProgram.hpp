// SPDX-License-Identifier: GPL-3.0-only
#pragma once
// Runs only in the exact original B2 VM, on its owning simulation thread.
static constexpr const char *IZTrainerProgram=R"IZLUA(
local M={flags={},values={},confirmed={},samples={},tickWork=false}
local names={'Hunger','Cleanliness','Sleep','Toilet','Fun','Society','Admit','Energy'}
local tickIds={0,1,2,3,4,5,6,7,8,9,10,13,15,19}
local function near(a,b) return type(a)=='number' and math.abs(a-b)<0.01 end
local function localObjects()
 local c=inzoi.getB2Subsystem('FB2ControllerSystem')
 local e=inzoi.getB2Manager('FB2EntityManager')
 if not c or not e then return end
 local t=inzoi.getB2Manager('FB2TimeManager')
 if not t or t:IsContainsPauseReason(INZOI.EB1PauseReason.Initialize) or t:IsContainsPauseReason(INZOI.EB1PauseReason.Loading) or c:IsBuildMode() then return end
 local id,house=c.PossessEntityId,c.PossessHouseholdId
 if not id or not id:IsValid() or not house or not house:IsValid() then return end
 local ch=e:FindCharacter(id)
 local h=e:FindHousehold(house)
 if not ch or ch:IsInvalid() or not ch:IsRegistered() or not h or h:IsInvalid() then return end
 return {id=id,house=house,ch=ch,h=h,key=tostring(id)..':'..tostring(house)..':'..tostring(ch:GetLocatedCityId())}
end
local function component(o,n)
 local x=o and o:GetComponent(n)
 if x and tostring(x:GetOwnerEntityId())==tostring(o:GetEntityId()) then return x end
end
local function stat(o) return component(o.ch,1) end
local function wallet(o) return component(o.h,17) end
local function time() return inzoi.getB2Manager('FB2TimeManager') end
function M.release()
 if M.timeOriginal and M.timeWritten then
  local t=time()
  if t and near(t:GetTimeScaleRawValue(),M.timeWritten) then t:SetTimeScale(M.timeOriginal) end
 end
 M.timeOriginal=nil;M.timeWritten=nil
 M.flags={};M.values={};M.confirmed={};M.samples={};M.owner=nil;M.tickWork=false
end
function M.context()
 local o=localObjects()
 if not o then M.release();return {ready=false,identity='',note='Auf den lokalen Spielstand warten.'} end
 if M.owner and M.owner~=o.key then M.release() end
 M.owner=o.key
 return {ready=true,identity=o.key,note='Lokaler Zoi verbunden.'}
end
local function scaledStat(s,name,scale,key)
 local value=s:GetStat(name)
 local previous=M.samples[key]
 if previous and ((scale.kind=='loss' and value<previous) or (scale.kind=='gain' and value>previous)) then
  local target=math.max(-100,math.min(100,previous+(value-previous)*scale.factor))
  s:SetStat(name,target,0)
  value=s:GetStat(name)
  M.confirmed[scale.id]=near(value,target)
 end
 M.samples[key]=value
end
local function scaledCurrency(o,key,feature)
 local w=wallet(o);if not w then return end
 local value=w:GetCurrencyAmount(key,o.id)
 local previous=M.samples[key]
 if previous and value>previous then
  local target=math.min(999999999,math.floor(previous+(value-previous)*M.values[feature]+0.5))
  w:SetCurrency(key,target,1,o.id,false,o.id)
  value=w:GetCurrencyAmount(key,o.id)
  M.confirmed[feature]=(value==target)
 end
 M.samples[key]=value
end
function M.tick()
 -- The original TimeManager already calls this once per simulation step.
 -- No active periodic effect means no entity/component discovery or writes.
 if not M.tickWork then return end
 local o=localObjects()
 if not o or M.owner~=o.key then if M.owner then M.release() end;return end
 local s=stat(o)
 if s then
  if M.flags[8] then
   for _,n in ipairs(names) do scaledStat(s,n,{kind='loss',factor=M.values[8],id=8},'needs:'..n) end
  end
  if M.flags[10] then scaledStat(s,'Karma',{kind='gain',factor=M.values[10],id=10},'karma') end
  for i,n in ipairs(names) do
   if M.flags[i-1] then
    local v=s:GetStat(n)
    if v~=100 then s:SetStat(n,100,0);v=s:GetStat(n) end
    M.confirmed[i-1]=near(v,100);M.samples['needs:'..n]=v
   end
  end
  if M.flags[9] then
   local v=s:GetStat('Karma')
   if v~=100 then s:SetStat('Karma',100,0);v=s:GetStat('Karma') end
   M.confirmed[9]=near(v,100);M.samples.karma=v
  end
 end
 if M.flags[13] then scaledCurrency(o,'Mew',13) end
 if M.flags[15] then scaledCurrency(o,'Nyang',15) end
 if M.flags[19] then
  local t=time()
  if t and not t:IsPaused() then
   local current=t:GetTimeScaleRawValue()
   if not M.timeOriginal then M.timeOriginal=current end
   if current~=M.values[19] then t:SetTimeScale(M.values[19]);current=t:GetTimeScaleRawValue() end
   M.timeWritten=current
   M.confirmed[19]=near(M.timeWritten,M.values[19])
  end
 end
end
function M.feature(id,wanted,value)
 local c=M.context()
 if not c.ready then return {available=false,active=false,note=c.note} end
 if id==18 then return {available=false,active=false,note='Diese native Funktion wird noch geprüft.'} end
 if id==11 or id==12 or id==14 then return {available=true,active=false,note='Einmalig anwenden.'} end
 local changed=(M.flags[id]~=wanted or M.values[id]~=value)
 if changed then
  M.confirmed[id]=false
  if id==8 then for _,n in ipairs(names) do M.samples['needs:'..n]=nil end end
  if id==10 then M.samples.karma=nil end
  if id==13 then M.samples.Mew=nil end
  if id==15 then M.samples.Nyang=nil end
 end
 if not wanted and id==19 and M.timeOriginal then
  local t=time();if t and near(t:GetTimeScaleRawValue(),M.timeWritten) then t:SetTimeScale(M.timeOriginal) end
  M.timeOriginal=nil;M.timeWritten=nil
 end
 M.flags[id]=wanted;M.values[id]=value
 if changed then
  M.tickWork=false
  for _,i in ipairs(tickIds) do if M.flags[i] then M.tickWork=true;break end end
  M.tick()
 end
 return {available=true,active=wanted and M.confirmed[id] or false,note=(not wanted and 'Aus.' or (M.confirmed[id] and 'Native Wirkung bestätigt.' or 'Bereit; auf passende Spieländerung warten.'))}
end
function M.perform(id,value)
 local c=M.context();if not c.ready then return c.note end
 local o=localObjects();local w=wallet(o)
 local key=(id==12 and 'Mew' or id==14 and 'Nyang' or nil)
 if not key or not w then return 'Keine passende native Aktion verfügbar.' end
 value=math.floor(math.max(0,math.min(999999999,value)))
 w:SetCurrency(key,value,1,o.id,false,o.id)
 local read=w:GetCurrencyAmount(key,o.id);M.samples[key]=read
 return read==value and 'Wert im Spiel bestätigt.' or 'Das Spiel hat den Wert nicht bestätigt.'
end
function M.ambitionPlan()
 local ctx=M.context();if not ctx.ready then return {ready=false,note=ctx.note} end
 local o=localObjects();local a=component(o.ch,43);local mc=component(o.ch,45)
 if not a or not mc then return {ready=false,note='Keine aktive Ambition verfügbar.'} end
 local id=a:GetPlayingAmbitionItemId();local state=a:FindAmbitionState(id)
 if not state then return {ready=false,note='Keine aktive Ambition verfügbar.'} end
 local ids=state.StepMissionIds;assert(ids:Length()<=32,'Zu viele Ambitionsmissionen.')
 local missions={}
 for i=1,ids:Length() do
  local mid=ids:Get(i);local ms=mc:FindMissionState(mid)
  if ms and ms.bIsActive and not ms.bIsFinished then
   local conditions={};assert(ms.ConditionStates:Length()<=32,'Zu viele Missionsbedingungen.')
   for j=1,ms.ConditionStates:Length() do local cs=ms.ConditionStates:Get(j);conditions[j]={kind=cs.ConditionType,goal=cs.GoalCount,compare=cs.CompareType} end
   missions[#missions+1]={id=mid.Value,row=tostring(ms.MissionDtId),conditions=conditions}
  end
 end
 return {ready=true,owner=o.key,item=tostring(id),step=state.CurrentStep,missions=missions,completed=a:IsCompleteAmbitionItem(id)}
end
function M.advanceAmbition(plan,definitions)
 local current=M.ambitionPlan()
 assert(current.ready and current.owner==plan.owner and current.item==plan.item and current.step==plan.step,'Der lokale Ambitionskontext hat gewechselt.')
 local o=localObjects();local mc=component(o.ch,45);local pending={}
 for _,mission in ipairs(current.missions) do
  local def=definitions[mission.row]
  assert(type(def)=='table' and def._row_name==mission.row and type(def.conditions)=='table' and #def.conditions==#mission.conditions,'Die Missionsdefinition stimmt nicht überein.')
  local mid=INZOI.FB1MissionId();mid.Value=mission.id
  for index,condition in ipairs(def.conditions) do
   local expected=mission.conditions[index]
   local kind=INZOI.EB1MissionCondition[condition.conditionType]
   assert(kind==expected.kind and condition.goalCount==expected.goal,'Die native Missionsbedingung stimmt nicht überein.')
   local trigger=INZOI.FB1MissionConditionTrigger();trigger.MissionId=mid;trigger.bIsAdd=false;trigger.Count=expected.goal
   local data=INZOI.FB1MissionConditionData();data.ConditionType=kind;data.GoalCount=expected.goal
   data.ConditionId1=condition.conditionId1;data.ConditionId2=condition.conditionId2;data.ConditionInt=condition.conditionInt;trigger.CondData=data
   pending[#pending+1]=trigger
  end
 end
 assert(mc.TriggersIndex>=0 and mc.TriggersIndex<2,'Ungültiger nativer Triggerpuffer.')
 local queue=mc.TriggersList:GetRef(mc.TriggersIndex+1).ConditionTriggers
 assert(queue:Length()+#pending<=256,'Der native Triggerpuffer ist voll.')
 for _,trigger in ipairs(pending) do queue:Add(trigger) end
 mc:ApplyTrigger()
 local a=component(o.ch,43);local state=a:FindAmbitionState(plan.item)
 return {owner=o.key,item=plan.item,completed=a:IsCompleteAmbitionItem(plan.item),step=state and state.CurrentStep or -1,triggers=#pending}
end
function M.skillGain(comp,id,exp)
 local o=localObjects()
 if not o or M.owner~=o.key or tostring(comp:GetOwnerEntityId())~=tostring(o.id) or exp<=0 then return comp:AddSkillExp(id,exp) end
 local before=comp:FindSkill(id);local oldLevel=before and before.Level or 0;local oldExp=before and before.Experience or 0
 local amount=exp
 if M.flags[16] then amount=1000000 elseif M.flags[17] then amount=exp*M.values[17] end
 comp:AddSkillExp(id,amount)
 local after=comp:FindSkill(id)
 if after then
  if M.flags[16] then M.confirmed[16]=comp:IsMaxLevel(id) end
  if M.flags[17] then M.confirmed[17]=(after.Level>oldLevel or after.Experience>oldExp) end
 end
end
return M
)IZLUA";
