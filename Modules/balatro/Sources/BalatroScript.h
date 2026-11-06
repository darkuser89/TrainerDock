// SPDX-License-Identifier: GPL-3.0-only
// Own runtime code. No game sources or assets are copied into the module.
static const char BAScript[]=R"MHTLUA(
local native_tick, native_input = ...
if type(G)~='table' or G.VERSION~='1.0.1o-FULL' or type(love.update)~='function'
   or type(Back)~='table' or type(Back.trigger_effect)~='function' then return nil end
local root, original_update, original_back = G, love.update, Back.trigger_effect
local wanted, leases, owner, generation, pending = {}, {}, nil, 0, nil
local mouse, mouse_base, last_score, last_dt, scaled_dt = false, nil, nil, 0, 0
local api = {}
local function finite(v) return type(v)=='number' and v==v and v~=math.huge and v~=-math.huge end
local function kind()
  if G~=root or G.VERSION~='1.0.1o-FULL' or love.update~=api.update or Back.trigger_effect~=api.back then return 0 end
  if G.STAGE~=G.STAGES.RUN or type(G.GAME)~='table' or type(G.GAME.current_round)~='table'
    or not G.HUD or not G.hand or not G.deck or G.screenwipe or G.SETTINGS.paused
    or G.STATE==G.STATES.GAME_OVER then return 1 end
  local g,r=G.GAME,G.GAME.current_round
  if not finite(g.dollars) or not finite(g.chips) or not finite(r.hands_left) or not finite(r.discards_left)
    or type(g.round_resets)~='table' or type(r.current_hand)~='table' then return 0 end
  return 2
end
local function same_owner()
  return owner and G==root and G.GAME==owner.game and G.GAME.current_round==owner.round
    and G.GAME.round==owner.number and G.GAME.blind==owner.blind and G.GAME.selected_back==owner.back
    and G.GAME.round_resets==owner.resets and G.GAME.round_resets.ante==owner.ante
end
local function refresh(id)
  if G~=root or not G.HUD then return end
  local ok = pcall(function()
    local e=G.HUD:get_UIE_by_ID(id)
    if e and e.config and e.config.object and e.config.object.update then e.config.object:update(0) end
    G.HUD:recalculate()
  end)
  return ok
end
local function release_lease(id)
  local l=leases[id]
  if l and same_owner() and finite(l.tab[l.key]) and l.tab[l.key]==l.last then
    l.tab[l.key]=l.base
    if l.ui then refresh(l.ui) end
  end
  leases[id]=nil
end
function api.release()
  for id=0,3 do release_lease(id) end
  wanted={}; pending=nil; last_score=nil
end
local function synchronize()
  if not same_owner() then
    -- Never write to a former run/round. References protect against pointer reuse.
    leases={}; wanted={}; pending=nil; last_score=nil;last_dt=0;scaled_dt=0;generation=generation+1
    if G==root and type(G.GAME)=='table' and type(G.GAME.current_round)=='table' and type(G.GAME.round_resets)=='table' then
      owner={game=G.GAME,round=G.GAME.current_round,number=G.GAME.round,blind=G.GAME.blind,back=G.GAME.selected_back,
             resets=G.GAME.round_resets,ante=G.GAME.round_resets.ante}
    else owner=nil end
  end
  local k=kind()
  if k~=2 then api.release() end
  return k
end
local function lease(id,tab,key,floor,ui)
  local n=tab[key]
  if not finite(n) then return false end
  local l=leases[id]
  if not l then l={tab=tab,key=key,base=n,last=n,floor=floor,ui=ui};leases[id]=l end
  if l.tab~=tab then return false end
  if n~=l.last then l.base=math.max(0,l.base+(n-l.last)) end
  local target=math.max(n,l.floor)
  tab[key]=target;l.last=target
  if target~=n and ui then refresh(ui) end
  return tab[key]==target
end
local function maintain()
  if synchronize()~=2 then return end
  local g,r=G.GAME,G.GAME.current_round
  if wanted[0] then lease(0,g,'dollars',9999999,'dollar_text_UI') end
  if wanted[2] then lease(2,r,'hands_left',math.max(1,r.hands_left),'hand_UI_count') end
  if wanted[3] then lease(3,r,'discards_left',math.max(1,r.discards_left),'discard_UI_count') end
end
function api.inspect()
  local k=synchronize()
  local result={kind=k,identity=tostring(generation)..':'..tostring(k),
    note=k==2 and (last_score and ('Handergebnis bestätigt: '..string.format('%.0f',last_score)) or 'LÖVE-Update: lokaler Lauf bestätigt.') or 'Warte auf einen gültigen lokalen Lauf.',
    lastScore=last_score or -1,pendingScore=pending or -1,inputDt=last_dt,outputDt=scaled_dt}
  if same_owner() then
    result.money=owner.game.dollars;result.chips=owner.game.chips
    result.hands=owner.round.hands_left;result.discards=owner.round.discards_left
  end
  return result
end
function api.effect(id,on,value)
  local k=synchronize()
  if k~=2 or id<0 or id>9 or id~=math.floor(id) then return {available=false,active=false,note='Kein gültiger lokaler Besitzer.'} end
  if id>=5 then return {available=true,active=false,note=id==7 and (pending and 'Für nächste Hand vorgemerkt.' or 'Einmalaktion: nächste Hand.') or 'Einmalaktion bereit.'} end
  if id==4 and (not finite(value) or value<0.1 or value>10) then return {available=false,active=false,note='Ungültiger Zeitfaktor.'} end
  wanted[id]=on and (id==4 and value or true) or nil
  if not on then release_lease(id) end
  maintain()
  local active=on and ((id==0 or id==2 or id==3) and leases[id] and leases[id].tab[leases[id].key]==leases[id].last
    or id==1 and Back.trigger_effect==api.back and last_score and last_score>=1e12
    or id==4 and love.update==api.update and last_dt>0 and math.abs(scaled_dt-last_dt*value)<1e-9) or false
  return {available=true,active=not not active,note=active and (id==1 and 'Schlusswertung angebunden; wartet auf Hand.' or id==4 and 'Update-Zeitfaktor angebunden.' or 'Spielwert zurückgelesen.') or (on and 'Wartet auf bestätigte Handwertung / Update.' or 'Aus.')}
end
function api.once(id,value)
  if synchronize()~=2 or not finite(value) or value<0 or value~=math.floor(value) then return 'Aktion verworfen: Kontext oder Wert ungültig.' end
  if id==7 then
    if value>1e15 then return 'Wert außerhalb des Bereichs.' end
    pending=value;return 'Für nächste ausgewertete Hand vorgemerkt; noch keine Punkte vergeben.'
  end
  local tab,key,ui,max
  if id==5 then tab,key,ui,max=G.GAME,'dollars','dollar_text_UI',1e9
  elseif id==6 then tab,key,ui,max=G.GAME,'chips','chip_UI_count',1e15
  elseif id==8 then tab,key,ui,max=G.GAME.current_round,'hands_left','hand_UI_count',99
  elseif id==9 then tab,key,ui,max=G.GAME.current_round,'discards_left','discard_UI_count',99
  else return 'Keine zulässige Einmalaktion.' end
  if value>max or not finite(tab[key]) then return 'Wert außerhalb des Bereichs.' end
  -- Explicit edits become the new baseline; all-off must not undo user edits.
  local lease_id=id==5 and 0 or id==8 and 2 or id==9 and 3 or -1
  leases[lease_id]=nil
  tab[key]=value;refresh(ui)
  return tab[key]==value and ('Spielwert bestätigt: '..string.format('%.0f',value)) or 'Keine Rücklesebestätigung.'
end
function api.back(self,args,...)
  local chips,mult=original_back(self,args,...)
  if type(args)=='table' and args.context=='final_scoring_step' and synchronize()==2
    and self==G.GAME.selected_back then
    local target=pending
    if target~=nil then pending=nil
    elseif wanted[1] then target=math.max(1e12,(finite(chips) and chips or args.chips or 0)*(finite(mult) and mult or args.mult or 1)) end
    if finite(target) and target>=0 then last_score=target;return target,1 end
  end
  return chips,mult
end
function api.mouse(_,on)
  if love.mouse and love.mouse.isVisible and love.mouse.setVisible then
    if on and not mouse then mouse_base=love.mouse.isVisible();love.mouse.setVisible(true)
    elseif not on and mouse and love.mouse.isVisible() then love.mouse.setVisible(mouse_base or false);mouse_base=nil end
    mouse=not not on
    return {active=mouse and love.mouse.isVisible()}
  end
  return {active=false}
end
function api.update(dt)
  maintain()
  native_tick()
  maintain()
  local speed=kind()==2 and wanted[4] or 1
  last_dt=dt;scaled_dt=dt*speed
  original_update(scaled_dt)
  maintain()
end
-- Route input before the original game callback. Coordinates stay normalized
-- until AppKit maps them into its own point-based overlay tree.
local held={}
local function modifiers()
  if not love.keyboard then return 0 end
  return ((held.lgui or held.rgui or love.keyboard.isDown('lgui','rgui')) and 1 or 0)+((held.lshift or held.rshift or love.keyboard.isDown('lshift','rshift')) and 2 or 0)
    +((held.lctrl or held.rctrl or love.keyboard.isDown('lctrl','rctrl')) and 4 or 0)+((held.lalt or held.ralt or love.keyboard.isDown('lalt','ralt')) and 8 or 0)
end
local function mouse_input(kind,x,y)
  local w,h=love.graphics.getDimensions()
  return native_input(kind,x/w,y/h,'',modifiers())
end
local released=love.keyreleased
local down,up,move,key,text=love.mousepressed,love.mousereleased,love.mousemoved,love.keypressed,love.textinput
love.mousepressed=function(x,y,b,...) if b==1 and mouse_input(1,x,y) then return end;if down then return down(x,y,b,...) end end
love.mousereleased=function(x,y,b,...) if b==1 and mouse_input(2,x,y) then return end;if up then return up(x,y,b,...) end end
love.mousemoved=function(x,y,...) if mouse_input(3,x,y) then return end;if move then return move(x,y,...) end end
love.keypressed=function(k,scan,repeated,...)
  held[k]=true
  if not repeated and native_input(4,0,0,scan or k,modifiers()) then return end
  if key then return key(k,scan,repeated,...) end
end
love.keyreleased=function(k,...) held[k]=nil;if released then return released(k,...) end end
love.textinput=function(t,...) if native_input(5,0,0,t,0) then return end;if text then return text(t,...) end end
Back.trigger_effect=api.back
love.update=api.update
return api
)MHTLUA";
