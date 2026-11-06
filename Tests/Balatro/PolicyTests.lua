-- SPDX-License-Identifier: GPL-3.0-only
-- Synthetic fixtures only. No game source is copied into the product.
local function eq(a,b) assert(a==b,tostring(a)..' != '..tostring(b)) end
local t=trainer
eq(t.inspect().kind,2)
eq(G.GAME.dollars,4) -- no implicit actions or selection
assert(not t.effect(0,false,0).active)
assert(t.effect(0,true,0).active);eq(G.GAME.dollars,9999999)
G.GAME.dollars=G.GAME.dollars-7;love.update(0.1);eq(G.GAME.dollars,9999999)
t.effect(0,false,0);eq(G.GAME.dollars,0) -- original four minus spending, clamped
assert(t.once(5,123):find('bestätigt'));eq(G.GAME.dollars,123)
t.release();eq(G.GAME.dollars,123)
assert(t.effect(2,true,0).active);G.GAME.current_round.hands_left=3;love.update(0.1);eq(G.GAME.current_round.hands_left,4)
t.effect(2,false,0);eq(G.GAME.current_round.hands_left,3)
assert(t.effect(3,true,0).active);G.GAME.current_round.discards_left=2;love.update(0.1);eq(G.GAME.current_round.discards_left,3)
t.effect(3,false,0);eq(G.GAME.current_round.discards_left,2)
t.effect(4,true,2.5);love.update(0.02);eq(last_dt,0.05);assert(t.effect(4,true,2.5).active)
t.effect(4,false,2.5);love.update(0.02);eq(last_dt,0.02)
local b=G.GAME.selected_back
assert(not t.effect(1,true,0).active) -- wait for native scoring result
local c,m=b:trigger_effect{context='final_scoring_step',chips=5,mult=3};eq(c*m,1e12)
assert(t.effect(1,true,0).active)
t.effect(1,false,0);c,m=b:trigger_effect{context='final_scoring_step',chips=5,mult=3};eq(c*m,15)
t.once(7,4321);eq(t.inspect().pendingScore,4321)
c,m=b:trigger_effect{context='other',chips=4,mult=5};eq(c*m,20);eq(t.inspect().pendingScore,4321)
c,m=b:trigger_effect{context='final_scoring_step',chips=4,mult=5};eq(c*m,4321);eq(t.inspect().pendingScore,-1)
c,m=b:trigger_effect{context='final_scoring_step',chips=4,mult=5};eq(c*m,20) -- one shot
for _,p in ipairs({{5,'dollars',500},{6,'chips',10000},{8,'hands_left',10},{9,'discards_left',9}}) do
 assert(t.once(p[1],p[3]):find('bestätigt'));eq((p[1]<8 and G.GAME or G.GAME.current_round)[p[2]],p[3])
end
assert(not t.once(9,100):find('bestätigt'));eq(G.GAME.current_round.discards_left,9)
assert(not t.once(5,0/0):find('bestätigt'));assert(not t.effect(4,true,11).available)
t.once(7,999);t.effect(0,true,0);local previous=G.GAME
G.GAME={dollars=2,chips=0,round=1,round_resets={ante=1},current_round={hands_left=2,discards_left=1,current_hand={}}};G.GAME.selected_back=b
love.update(0.1);eq(G.GAME.dollars,2);eq(t.inspect().pendingScore,-1);eq(previous.dollars,9999999)
t.effect(0,true,0);G.SETTINGS.paused=true;love.update(0.1);eq(t.inspect().kind,1);eq(G.GAME.dollars,2)
G.SETTINGS.paused=false;love.update(0.1);eq(G.GAME.dollars,2)
t.once(7,999);t.effect(0,true,0);G.GAME.round=2;love.update(0.1);eq(t.inspect().pendingScore,-1)
t.effect(0,true,0);MP={};love.update(0.1);eq(t.inspect().kind,2);assert(t.effect(0,true,0).available)
assert(t.once(5,999):find('bestätigt'));MP=nil;love.update(0.1);eq(t.inspect().kind,2)
local after=G.GAME.dollars;love.update(0.1);assert(G.GAME.dollars>=after) -- network marker does not clear choices
t.mouse(0,true);eq(visible,true);t.mouse(0,false);eq(visible,false)
