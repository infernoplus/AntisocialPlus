local foe = {
  _VERSION = 'Foe 1.0',
  _DESCRIPTION = 'Health bars for enemies.',
}

require('strings')
require('tables')

local inspect = require('inspect')
local texts = require('texts')
local images = require('images')
local res = require('resources')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

foe.enabled = false
foe.list = {}

foe.target = nil        -- arrow icon things
foe.subtarget = nil

-- Borrowed tables from https://github.com/mverteuil/windower4-addons/blob/master/Debuffed/Debuffed.lua
local debuffs = {
    [2] = S{253,259,678}, --Sleep
    [3] = S{220,221,225,350,351,716}, --Poison
    [4] = S{58,80,341,644,704}, --Paralyze
    [5] = S{254,276,347,348}, --Blind
    [6] = S{59,687,727}, --Silence
    [7] = S{255,365,722}, --Break
    [11] = S{258,531}, --Bind
    [12] = S{216,217,708}, --Gravity
    [13] = S{56,79,344,345,703}, --Slow
    [21] = S{286,472,884}, --addle/nocturne
    [28] = S{575,720,738,746}, --terror
    [31] = S{682}, --plague
    [136] = S{240,705}, --str down
    [137] = S{238}, --dex down
    [138] = S{237}, --VIT down
    [139] = S{236,535}, --AGI down
    [140] = S{235,572,719}, --int down
    [141] = S{239}, --mnd down
    [146] = S{524,699}, --accuracy down
    [147] = S{319,651,659,726}, --attack down
    [148] = S{610,841,842,882}, --Evasion Down
    [149] = S{717,728,651}, -- defense down
    [156] = S{707,725}, --Flash
    [167] = S{656}, --Magic Def. Down
    [168] = S{508}, --inhibit TP
    [192] = S{368,369,370,371,372,373,374,375}, --requiem
    [193] = S{463,471,376,377}, --lullabies
    [194] = S{421,422,423}, --elegy
    [217] = S{454,455,456,457,458,459,460,461,871,872,873,874,875,876,877,878}, --threnodies
    [404] = S{843,844,883}, --Magic Evasion Down
    [597] = S{879}, --inundation
}

local hierarchy = {
    [23] = 1, --Dia
    [33] = 1, --Diaga
    [24] = 3, --Dia II
    [34] = 3, --Diaga II
    [25] = 5, --Dia III
    [35] = 5, --Diaga III
    [230] = 2, --Bio
    [231] = 4, --Bio II
    [232] = 6, --Bio III
}

local chp = {r = 255, g = 155, b = 155}

function foe.onCommand(cmd)
  if cmd[1] == 'foe' then 
    if cmd[2] == 'clear' then
      for i,f in ipairs(foe.list) do
        f.name:destroy()
        f.fill:destroy()
        f.edge:destroy()
        f.prog:destroy()
        f.chunk:destroy()
      end
      foe.target:destroy()
      foe.subtarget:destroy()
      foe.list = {}
      foe.enabled = false
      return true
    end
    
    if cmd[2] == 'target' and foe.enabled then
      foe.select()
      return true
    end
    
    if foe.enabled then
      for i,f in ipairs(foe.list) do
        f.name:destroy()
        f.fill:destroy()
        f.edge:destroy()
        f.prog:destroy()
        f.chunk:destroy()
      end
      foe.target:destroy()
      foe.subtarget:destroy()
      foe.list = {}
    end
    
    foe.target = foe.newBoxT()
    foe.subtarget = foe.newBoxST()
    foe.enabled = true
    return true
  end
  return false
end

function foe.select()
      local seltgt = windower.ffxi.get_mob_by_target("t")
      local player = windower.ffxi.get_player()
      if #foe.list < 1 then return end
      
      local next = false
      for i,f in ipairs(foe.list) do
        local tgt = windower.ffxi.get_mob_by_id(f.id)
        if next then
          packets.inject(packets.new('incoming', 0x058, {
            ['Player'] = player.id,
            ['Target'] = tgt.id,
            ['Player Index'] = player.index,
          }))
          return
        end
        if tgt and seltgt and tgt.id == seltgt.id then
          next = true
        end
      end
      
      local tgt = windower.ffxi.get_mob_by_id(foe.list[1].id)
      packets.inject(packets.new('incoming', 0x058, {
        ['Player'] = player.id,
        ['Target'] = tgt.id,
        ['Player Index'] = player.index,
      }))
end

function foe.add(id)
    local tgt = windower.ffxi.get_mob_by_id(id)
    if not tgt then return end
    
    for i,f in ipairs(foe.list) do
      if f.id == tgt.id then
        return
      end
    end
    
    local f = {}
    f.id = tgt.id
    f.fade = 60
    f.debuffs = {}
    f.name = foe.newTextName(tgt.name)
    f.fill = foe.newBoxFill()
    f.edge = foe.newBoxEdge()
    f.prog = foe.newBoxProg()
    f.chunk = foe.newBoxChunk()
    f.cpp = tgt.hpp
    
    foe.list[#foe.list+1] = f
    foe.draw()                   -- Being a little lazy here, most of these are intialized in the wrong place so I just call draw() to fix it after adding them
end

function foe.get(id)
  for i, f in ipairs(foe.list) do
    if f.id == id then return f end
  end
  return nil
end

-- add debuff to foe
function foe.debuff(ft, spell)
  -- find which debuff icon id we need
  local debuff = -1
  for i,d in pairs(debuffs) do
    if d:contains(spell) then
      debuff = i
      break
    end
  end
  
  -- Bio or Dia moment~
  local hier = -1
  if T{23,24,25, 33,34,35, 230,231,232}:contains(spell) then
    hier = hierarchy[spell]
    for i,d in ipairs(ft.debuffs) do
      if d.hier == hier then d.time = 0 return         -- same tier we refresh time
      elseif d.hier > hier then return end  -- if there is a higher tier spell we just dont even
    end
    
    if T{230,231,232}:contains(spell) then
      debuff = 135
    else
      debuff = 134
    end
  end
  
  if debuff == -1 then return end -- nothing burger
  
  -- see if foe already has this debuff
  for i,d in ipairs(ft.debuffs) do
    if d.id == debuff then
      d.time = 0
      return
    end
  end
  
  -- addy
  local nd  = {}
  nd.id = debuff
  nd.time = 0
  nd.icon = foe.newBoxBuff(debuff)
  nd.hier = hier
  ft.debuffs[#ft.debuffs+1] = nd
  --print('added debuff->' .. debuff)
end

-- debuff wears off, remove icon
function foe.wear(ft, debuff)
  local rp = {} -- replace
  for i, d in pairs(ft.debuffs) do
    if d.id == debuff then
      d.icon:destroy()
    else
      rp[#rp+1] = d
    end
  end
  ft.debuffs = rp
end


function foe.status(id)
  if not foe.enabled then return end
  
  if id == 1 then
    local target = windower.ffxi.get_mob_by_target('t')
    if target then foe.add(target.id) end
  end
end

function foe.onAction(act)
  if not foe.enabled then return end
  
  -- add foe if you or a party member start a JA RA or MA on a mob
  if act.category == 06 or act.category == 02 or act.category == 08 or act.category == 01 then
    -- check if it's a party member
    local isParty = false
    local party = util.getParty()
    for i,ply in ipairs(party) do
      if ply.mob and ply.mob.id == act.actor_id then
        isParty = true
      end
    end
    
    if not isParty then return end
  
    -- add foe
    local tgt = windower.ffxi.get_mob_by_id(act.targets[1].id)
    if tgt and tgt.is_npc then foe.add(tgt.id) end
  end
end

function foe.onActionMessage(actor_id, target_id, actor_index, target_index, message_id, param_1, param_2, param_3)
  if not foe.enabled then return end
  
  local fa = foe.get(actor_id)
  if fa then
    foe.wear(fa, param_1)
    --print('foeT->' .. ft.id .. ' mesage->' .. message_id .. ' params->' .. param_1 .. '/' .. param_2)
  end
end

function foe.inPacket(id, original)
  if not foe.enabled then return end
  if not (id == 0x028) then return end
  
  local pak = packets.parse('incoming', original)
  
  --local fa = foe.get(pak.Actor)
  local ft = foe.get(pak["Target 1 ID"])
  
  -- Spell
  -- Message 236 is a hit, 85 is a resist (there are others but that is default)
  if ft and pak.Category == 4 then
    if S{2,252,236,237,268,271}:contains(pak["Target 1 Action 1 Message"]) then
      foe.debuff(ft, pak.Param)
    end
    
    --print('foe->' .. ft.id .. ' had spell cast on it->' .. pak.Param .. ' with results MSG/PARAM->' .. pak["Target 1 Action 1 Message"] .. '/' .. pak["Target 1 Action 1 Param
  end
  
  -- fa then
  --print('foe -> ' .. fa.id .. ' had mesage -> ' .. pak['Added Effect Message'] .. ' done to it!')
  --seif ft and pak['Added Effect Message'] then
  --print('foe -> ' .. ft.id .. ' had mesage -> ' .. pak['Added Effect Message'] .. ' done to it!')
 --nd

end

local wsets = windower.get_windower_settings()
local win = vec2.create(wsets.x_res, wsets.y_res)
local base = vec2.create(16, 75)
local size = vec2.create(300, 18)
local margin = vec2.create(50, 2)
local font = 14
local padding = vec2.create(18, 2)
local progOff = 9
local numPad = 3

function foe.draw()
  -- Removal pass
  if not foe.enabled then return end

  local player = windower.ffxi.get_mob_by_target("me")
  
  local rp = {}
  for i,f in ipairs(foe.list) do
    local target = windower.ffxi.get_mob_by_id(f.id)
    
    if not target or not player or target.hpp <= 0 or vec2.distance(vec2.create(player.x, player.y), vec2.create(target.x, target.y)) > 50 then
      if f.fade > 0 then
        f.fade = f.fade - 1
      end
    else
      f.fade = 60
    end
  
    if f.fade > 0 then
      rp[#rp+1] = f
    else
      f.name:destroy()
      f.fill:destroy()
      f.edge:destroy()
      f.prog:destroy()
      f.chunk:destroy()
      for i,b in pairs(f.debuffs) do
        b.icon:destroy()
      end
    end
  end
  foe.list = rp
  
  foe.target:visible(false)
  foe.subtarget:visible(false)

  -- Draw pass
  local v = 0
  for i,f in ipairs(foe.list) do
    if f then
      local tgt = windower.ffxi.get_mob_by_id(f.id)
      if not tgt then
        tgt = {}
        tgt.hpp = 0
      end
      
      -- bar rendering
      if tgt.hpp < f.cpp then f.cpp = f.cpp - 0.25 end
      local cps = (f.cpp / 100)
      local hps = (tgt.hpp / 100)
      local fds = (f.fade / 60)
      
      local off = vec2.add(base, vec2.create(size.x + margin.x, (size.y + margin.y) * v))
      f.name:pos(win.x - off.x + padding.x, off.y - padding.y)
      f.fill:pos(win.x - off.x, off.y)
      f.edge:pos(win.x - off.x, off.y)
      f.prog:pos(win.x - off.x + progOff, off.y)
      f.prog:size((size.x - (progOff * 2))*hps, size.y)
      f.chunk:pos((win.x - off.x + progOff) + ((size.x - (progOff * 2))*hps), off.y)
      f.chunk:size((size.x - (progOff * 2))*(cps-hps), size.y)
      
      f.name:alpha(255 * fds)
      f.name:stroke_alpha(175 * fds)
      f.fill:alpha(255 * fds)
      f.edge:alpha(255 * fds)
      f.prog:alpha(125 * fds)
      f.chunk:alpha(125 * fds)
      
      -- target arrow rendering
      local seltgt = windower.ffxi.get_mob_by_target("t")
      local subtgt = windower.ffxi.get_mob_by_target("st")
      
      if subtgt and subtgt.id == tgt.id then
        foe.subtarget:pos(win.x - off.x - 40, off.y-2)
        foe.subtarget:visible(true)
      elseif seltgt and seltgt.id == tgt.id then
        foe.target:pos(win.x - off.x - 40, off.y-2)
        foe.target:visible(true)
      end
      
      -- buff rendering
      for i,b in pairs(f.debuffs) do
        b.icon:pos((win.x - off.x) + ((i-1) * 17), off.y + size.y + 3)
        b.icon:alpha(255 * fds)
      end
      
      v = v + 1
      if #f.debuffs > 0 then v = v + 1 end
    end
  end
end

function foe.newTextName(txt)
  local off = vec2.add(base, vec2.create(size.x + margin.x, margin.y))

  local t = texts.new({flags = {draggable = false}})
  t:text(txt)
  t:font('Consolas')
  t:color(255, 255, 255)
  t:alpha(255)
  
  t:pos(win.x - off.x + padding.x, off.y - padding.y)
  t:size(font)
  
  t:stroke_width(1)
  t:stroke_color(0, 0, 0)
  t:stroke_alpha(175)
  
  t:bg_color(0, 0, 0)
  t:bg_alpha(0, 0, 0)
  t:bg_visible(false)
  t:visible(true)
  
  return t
end

function foe.newBoxFill()
  local off = vec2.add(base, vec2.create(size.x + margin.x, margin.y))

  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\foe-fill-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  
  i:pos(win.x - off.x, off.y)
  i:size(size.x, size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function foe.newBoxEdge()
  local off = vec2.add(base, vec2.create(size.x + margin.x, margin.y))

  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\foe-edge-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  
  i:pos(win.x - off.x, off.y)
  i:size(size.x, size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function foe.newBoxProg()
  local off = vec2.add(base, vec2.create(size.x + margin.x + progOff, margin.y))

  local i = images.new()
  i:clear()
  i:color(chp.r, chp.g, chp.b)
  i:alpha(125)
  
  i:pos(win.x - off.x, off.y)
  i:size(size.x - (progOff * 2), size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function foe.newBoxChunk()
  local off = vec2.add(base, vec2.create(size.x + margin.x + progOff, margin.y))

  local i = images.new()
  i:clear()
  i:color(255, 255, 255)
  i:alpha(125)
  
  i:pos((win.x - off.x) + (size.x - (progOff * 2)), off.y)
  i:size(0, size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function foe.newBoxBuff(bid)
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\buff\\' .. bid .. '.png')
  i:color(255, 255, 255)
  i:alpha(255)
  i:size(18, 18) -- Literally does nothing lol
  i:fit(false)
  
  i:draggable(false)
  i:visible(true)
  return i
end

function foe.newBoxT()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\arrow-3.png')
  i:color(255, 255, 255)
  i:alpha(185)
  
  i:pos(0, 0)
  i:size(22, 34)
  
  i:draggable(false)
  i:visible(false)

  return i
end

function foe.newBoxST()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\arrow-4.png')
  i:color(255, 255, 255)
  i:alpha(210)
  
  i:pos(0, 0)
  i:size(22, 34)
  
  i:draggable(false)
  i:visible(false)

  return i
end

return foe