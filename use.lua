local use = {
  _VERSION = 'Use 1.0',
  _DESCRIPTION = 'Queue an action to be used. Will make sure the action is done so long as its not on cooldown.',
}

require('strings')
require('tables')
require('betterq')

local targetaddon = require('target') -- Name already used locally in many places so yeah...

local inspect = require('inspect')
local texts = require('texts')
local images = require('images')
local res = require('resources')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

use.actions = Q({})
use.timer = 0
use.combat = false
use.next = nil
use.state = 0

use.haltTimer = 0
use.lastPos = vec2.create(0, 0)
use.lastRot = 0

use.lastAct = 0

function use.onCommand(cmd)
  if cmd[1] == 'do' then
    if cmd[2] == 'cancel' then
      util.send('all', 'asp order cancel')
      return true
    end
    
    if cmd[3] == 'cancel' then
      util.send(cmd[2], 'asp order cancel')
      return true
    end
    
    if cmd[5] == '<x>' or cmd[5] == 'x' then
      local target = windower.ffxi.get_mob_by_target('t')
      if not target then
        cmd[5] = '<t>'
      else
        cmd[5] = target.id
      end
    end
    
    if cmd[5] == '<xt>' or cmd[5] == 'xt' then
      local subtarget = windower.ffxi.get_mob_by_target('st')
      local target = windower.ffxi.get_mob_by_target('t')
      if subtarget then
        cmd[5] = subtarget.id
      elseif target then
        cmd[5] = target.id
      else
        cmd[5] = '<t>'
      end
    end
    
    util.send(cmd[2], 'asp order ' .. cmd[3] .. ' ' .. cmd[5] .. ' ' .. cmd[4])
    return true

  elseif cmd[1] == 'order' then
    if cmd[2] == 'cancel' then
      use.clear()
      return true
    end
    
    local cmds = ''
    for i=4, #cmd do
      cmds = cmds .. cmd[i] .. ' '
    end
    cmds = util.trim(cmds)
        
    local act = {}
    act.type = util.trim(cmd[2])
    act.action = cmds
    act.target = util.trim(cmd[3])
    
    -- Check to see if we already have an order for this same action. No dupes.
    local copy = Q({})
    if use.next then
      copy:push(use.next)
    end
    for i = 1, use.actions:length() do
      copy:push(use.actions:at(i))
    end
    
    while not copy:empty() do
      local c = copy:pop()
      if string.lower(c.type) == string.lower(act.type) and string.lower(c.action) == string.lower(act.action) then
        return true
      end
    end
    
    act.box = use.newBox()
    act.text = use.newText(act.action)    
    use.actions:push(act)
    use.timer = 1                          -- Since we got a new order, skip timer to next frame
    
    return true
  end
  
  return false
end

function use.onFrame()
  local player = windower.ffxi.get_mob_by_target('me')
  local target = windower.ffxi.get_mob_by_target('t')
  local info = windower.ffxi.get_player()
  
  -- Clear use queue if null player (loading or whatever)
  if not player then use.clear() return end
  
  -- If we are not in neutral or combat state we should clear use queue as we are probably resting or dead or something
  if not (use.state == 0 or use.state == 1) then use.clear() return end
  
  -- Update last position/halt timer
  local ply = vec2.create(player.x, player.y)
  if vec2.distance(ply, use.lastPos) < 0.05 and math.abs(player.facing - use.lastRot) < 0.1 then
    use.haltTimer = use.haltTimer + 1
  else
    use.haltTimer = 0
  end
  use.lastPos = ply
  use.lastRot = player.facing
  
  -- Turn to target if we are ranging - DEPRECATED, TURN NOW HANDLED BY RANGE ADDON
--  if use.isRanging() and target then
--      -- Note: due to the way we are doing this, RA won't support any kind of targeting except <t>
--      local tgt = vec2.create(target.x, target.y)
--      local dir = vec2.normalize(vec2.subtract(tgt, ply))
--     
--      local ang = vec2.angle(vec2.create(0,1), dir)
--      if dir.x < 0 then
--        ang = ang * -1
--      end
--      windower.ffxi.turn(ang - 1.5708)
--  end
  
  -- Delay timer reduction at end of cast/range
  if use.timer > 0 then
    if (not use.isCasting() and not use.isRanging()) and use.timer > 20 then
      use.timer = 20
    end
    use.timer = use.timer - 1
    return
  end
  
  -- Delay timer set based on current action/state
  if use.isCasting() or use.isRanging() then
    use.timer = 90
  elseif use.lastAct == 08 and use.next and use.next.type == 'ma' then -- @TODO: these could be improved i imagine
    use.timer = 5
  elseif use.lastAct == 02 and use.next and use.next.type == 'ra' then
    use.timer = 5
  else
    use.timer = 20
  end
    
  if (not use.next) and (not use.actions:empty()) then
    use.next = use.actions:pop()
    use.next.box:path(windower.windower_path .. 'addons\\Antisocial\\img\\bar-2.png')
    use.next.box:update()
  end
  
  if not use.next then return end

  local tp = info.vitals.tp
  local tgt
  if not target then
    tgt = false
  elseif target.is_npc and target.valid_target and target.hpp > 0 then
    tgt = true
  else
    tgt = false
  end

  if use.next.target == '<t>' and (not tgt) then
    use.pop()
    return
  end
      
  if use.next.type == 'ja' then
    local abl = res.job_abilities:with('en', use.next.action)
    local ablrecasts = windower.ffxi.get_ability_recasts()
    local recast = ablrecasts[abl.recast_id]
    
    -- Dancer Check
    -- Dancer has TP costs on job abilities, so we test for that specifically as it's kinda unique to that job
    if abl.tp_cost > tp then
      log('Not enough TP')
      use.pop()
      return
    end
    
    -- Stratagem Hack
    -- Stratagems show as *on cooldown* after 1 charge has been used. Have to calculate charges based on the timer and player level
    if abl.recast_id == 231 then
      local playerinfo = windower.ffxi.get_player()
      local schlvl
      local charges = 0
      local recharge = 0
      if playerinfo.main_job == "SCH" then
        schlvl = playerinfo.main_job_level
      else
        schlvl = playerinfo.sub_job_level
      end
      
      if schlvl >= 99 then
        charges = 5
        recharge = 48
      elseif schlvl >= 70 then
        charges = 4
        recharge = 60
      elseif schlvl >= 50 then
        charges = 3
        recharge = 80
      elseif schlvl >= 30 then
        charges = 2
        recharge = 120
      elseif schlvl >= 10 then
        charges = 1
        recharge = 240
      end

      --print(charges)
      --print(recharge)
      --print('lvl ' .. schlvl)
      --print(math.floor(recast/recharge))
      if recast > 0 and charges - 1 > math.floor(recast/recharge)then
        recast = 0 -- Ignore recast if we calcualte that we have a stratagem charge
      end
    end
    
    if not recast or recast > 1 then
      use.pop()
      return
    end
    use.execute(use.next)
  elseif use.next.type == 'ws' then
    if tp < 1000 or (not use.combat) then
      log('Not enough TP')
      use.pop()
      return
    end
    use.execute(use.next)
  elseif use.next.type == 'ma' then
    local ma = res.spells:with('en', use.next.action)
    local marecast = windower.ffxi.get_spell_recasts()
    local recast = marecast[ma.recast_id]
    
    -- Calculate actual mana cost
    -- [ I got wiped on a boss because my character refused to cast flare during manafont because his mana was below 300. ]
    local mp_actual = ma.mp_cost
    local buffs = windower.ffxi.get_player().buffs
    for i,b in ipairs(buffs) do
      if b == 47 then mp_actual = 0 --manafont
      elseif b == 361 or b == 360 then mp_actual = mp_actual * 0.5 --parsimony, penury
      elseif b == 358 or b == 359 then mp_actual = mp_actual * 0.9 end --light arts, dark arts
    end
    
    if not recast or recast > 1 then
      use.pop()
      return
    end
    
    if mp_actual > info.vitals.mp then
      log('Not enough MP')
      use.pop()
      return
    end
    
    -- Wait till we have stopped moving for at least 10 frames before we attempt to cast a spell (lag)
    if use.haltTimer < 10 then
      use.timer = 3
      return
    end
    
    use.execute(use.next)
  elseif use.next.type == 'item' then
    -- Wait till we have stopped moving for at least 10 frames before we attempt to use an item (lag)
    if use.haltTimer < 10 then
      use.timer = 3
      return
    end
    -- TODO: item recast not supported
    use.execute(use.next)
  elseif use.next.type == 'ra' then
    -- Wait till we have stopped moving for at least 10 frames before we attempt to range attack (lag)
    if use.haltTimer < 10 then
      use.timer = 3
      return
    end
  
    use.execute(use.next)
  elseif use.next.type == 'exec' then
    util.exec(use.next.action) -- Special case, no way to track so we just pop and move on
    use.pop()
  end
end

function use.draw()  
  if (not use.next) and use.actions:empty() then return end

  local wsets = windower.get_windower_settings()
  local win = vec2.create(wsets.x_res, wsets.y_res)
  local off = vec2.create(16, 55)
  local size = vec2.create(208, 16)
  local margin = 2
  local font = 11
  local padding = vec2.create(9, 1)

  -- Deprecate this copy Q
  local copy = Q({})
  if use.next then
    copy:push(use.next)
  end
  
  for i = 1, use.actions:length() do
    copy:push(use.actions:at(i))
  end

  local i = 0
  while not copy:empty() do
    act = copy:pop()
    
    act.box:pos((win.x - off.x) - size.x, off.y)
    act.box:size(size.x, size.y)
    act.box:update()
    act.box:visible(true)
    
    act.text:pos(((win.x - off.x) - size.x) + padding.x, off.y - padding.y)
    act.text:size(font)
    act.text:visible(true)
    
    off.y = off.y + size.y + margin
    
    i = i + 1
  end
end

function use.onAction(act)
  local player = windower.ffxi.get_mob_by_target('me')
  if (not player) or (act.actor_id ~= player.id) then return false end
  
  use.lastAct = act.category
  
  if act.category == 03 or act.category == 04 or act.category == 06 or act.category == 07 or act.category == 02 or act.category == 05 then
    -- @TODO: Should probably verify that the action is actaully the 'use.next' skill but ehhhhh we can just assume and it's 99% accurate
    -- @TODO: Should probably fix the paralyze bug related to this though
    use.timer = 5
    use.pop()
  end
end

function use.onStatus(id)
  use.state = id
  use.combat = id == 1
end

function use.onActionMessage(id)
  if use.next and use.next.type == 'ra' and (id == 217 or id == 78) then  -- Cancel RA if 'cannot see' or 'too far away'
    use.pop()
  end
end

function use.dead()
  use.clear()
end

-- This function determines if the do command is a generic target like <t> or <me> or if it is using a mod id target #. Then it either sends a normal command or packet injects one
function use.execute(act)
    local id = tonumber(act.target)
    local target
    if id then
      local t1 = windower.ffxi.get_mob_by_id(id)
      local t2 = windower.ffxi.get_mob_by_target('t')
      local t3 = windower.ffxi.get_mob_by_target('me')
      if t1 and t2 and t1.id == t2.id then
        act.target = '<t>'
      elseif t1 and t3 and t1.id == t3.id then
        act.target = '<me>'
      else
        target = t1
        targetaddon.target(t1.id) -- If we are injecting a packet for an <x> copy target then we also tell the target addon to target that mob so on repeat casts we can just use <t>
      end
    end
    
    -- This is a check to see if the target is a players name. Used for things like casting cure on a party member by name.
    local tgtByName = windower.ffxi.get_mob_by_name(act.target)
    if tgtByName and tgtByName.name and tgtByName.name:lower() == act.target:lower() then
      target = tgtByName
    end
    
    -- Pop command if no target at all  (Somewhat redundant as we have old 'valid target check' code in the method that calls this, but whatever ech refactor)
    if not target and not windower.ffxi.get_mob_by_target(act.target) then
      use.pop()
      return
    end
    
    -- Pop command if injection target is dead or invalid
    if target and not(target.valid_target and target.hpp > 0) then
      use.pop()
      return
    end
    
    local category
    local param
    
    local action_fixed = use.next.action

    if act.type == 'ja' then
      category = 9
      param = res.job_abilities:with('en', use.next.action).id
    elseif act.type == 'ws' then
      category = 7
      param = res.weapon_skills:with('en', use.next.action).id
    elseif act.type == 'ma' then
      category = 3
      param = res.spells:with('en', use.next.action).id
      -- Hacky fix for stupid ninjutsu shit
      if use.next.action:lower():match(": ichi") or use.next.action:lower():match(": ni") or use.next.action:lower():match(": san") then
        action_fixed = use.next.action:gsub(" ", "")
      end
    elseif act.type == 'ra' then
      -- todo: <x> on ra unsupported, need to parse packets and get all the values for it
    elseif act.type == 'item' then
      -- todo: <x> on item unsupported, need to parse packets and get all the values for it
    end
    
    if target and category and param and target.id and target.index then -- Safety
      -- Inject magic cast packet with target id
      local nupak = packets.new('outgoing', 0x01A, {
        ['Category'] = category,
        ['Param'] = param,
        ['Target'] = target.id,
        ['Target Index'] = target.index,
        ['X Offset'] = 0,
        ['Y Offset'] = 0,
        ['Z Offset'] = 0
      })
      packets.inject(nupak)
    else
      if act.type == 'ra' then
        -- RA
        util.exec(act.type .. ' ' .. act.target)
      elseif act.type == 'item' then
        -- Item
        util.exec('input /' .. act.type .. ' "' .. action_fixed .. '" ' .. act.target)
      else
        -- Normal command execution
        util.exec(act.type .. ' ' .. action_fixed .. ' ' .. act.target)
      end
    end
end

function use.pop()
  if use.next then
    use.next.text:destroy()
    use.next.box:destroy()
    use.next = nil
  end
end

function use.clear()
  while not use.actions:empty() do
    local pop = use.actions:pop()
    pop.text:destroy()
    pop.box:destroy()
  end
  use.pop()
  use.timer = 0
  use.actions:clear()
  
  if use.next then
    use.next.text:destroy()
    use.next.box:destroy()
    use.next = nil
  end
end

-- Returns true if we are casting a spell (ma).
function use.isCasting()
  return (use.next and use.next.type == 'ma' and use.lastAct == 08)
end

-- Returns true if we are doing a ranged attack
function use.isRanging()
  return (use.next and use.next.type == 'ra' and use.lastAct == 12)
end

-- Called by main class, returns true if the player needs to stop moving in order to cast a spell
function use.isHalt()
  return (use.next and (use.next.type == 'ma' or use.next.type == 'ra' or use.next.type == 'item'))
end

function use.newText(txt)
  local t = texts.new({flags = {draggable = false}})
  t:text(txt)
  t:font('Consolas')
  t:color(255, 255, 255)
  t:alpha(255)
  t:visible(false)
  
  t:stroke_width(1)
  t:stroke_color(0, 0, 0)
  t:stroke_alpha(175)
  
  t:bg_color(0, 0, 0)
  t:bg_alpha(0, 0, 0)
  t:bg_visible(false)
  
  return t
end

function use.newBox()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\bar-3.png')
  i:color(255, 255, 255)
  i:alpha(255)
  i:draggable(false)
  i:visible(false)
  
  return i
end

return use