local melee = {
  _VERSION = 'Melee 1.0',
  _DESCRIPTION = 'Order a client to fight a target with melee or range using specific spacing parameters',
}

require('strings')
require('tables')

local use = require('use')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

melee.target = nil
melee.leader = nil
melee.range = {}
melee.range.min = 0
melee.range.max = 0
melee.orientation = nil
melee.state = false          -- If true then we have our weapon out
melee.switch = nil           -- If we are engaged and recieve a new target, we will switch to this new target as soon as we can
melee.timer = {}
melee.timer.attack = 0
melee.timer.stuck = 0
melee.timer.stop = 0
melee.timer.switch = 0
melee.timer.reswitch = false
melee.timer.range = 0        -- Time between range attack queues, this timer is kinda goofy due to the nature of use HALT actions.
melee.autorange = false      -- If this is true we queue up ranged attacks automatically
melee.precision = 0.25       -- Not a user setting
melee.stuck = false
melee.stop = false           -- Set when we get a disengage order, this makes sure that we put our weapons away if the order came in before the state change (laggy game is laggy)

function melee.command(cmd)
  local player = windower.ffxi.get_mob_by_target('me')
  if not player then return false end

  if cmd[1] == 'melee' or cmd[1] == 'range' then  
    local target = windower.ffxi.get_mob_by_target('t')
    if target and target.is_npc and target.valid_target then
      if cmd[5] == nil then
        cmd[5] = "none"
      end
      util.send(cmd[2], 'asp ' .. cmd[1] .. 'order ' .. (target.id) .. ' ' .. (player.id).. ' ' .. cmd[3] .. ' ' .. cmd[4] .. ' ' .. cmd[5])
      return true
    end
		
  elseif cmd[1] == 'meleeorder' or cmd[1] == 'rangeorder' then
    local target = windower.ffxi.get_mob_by_id(tonumber(cmd[2]))
    local leader = windower.ffxi.get_mob_by_id(tonumber(cmd[3]))
    
    if not (target.is_npc and target.valid_target) then return true end
    	
    if target and leader then
      if melee.target and target.id ~= melee.target and melee.state then
        melee.switch = target.id
        melee.leader = leader.id
        melee.range.min = tonumber(cmd[4])
        melee.range.max = tonumber(cmd[5])
        melee.orientation = cmd[6]
        melee.precision = 0.25
        melee.timer.attack = 0
        melee.timer.stuck = 0
        melee.stuck = false
        melee.stop = false
        melee.timer.stop = 0
        melee.timer.switch = 0
        melee.reswitch = false
        return true
      end
      
      if cmd[1] == 'rangeorder' then
        melee.autorange = true
      end

      local player = windower.ffxi.get_player()
      packets.inject(packets.new('incoming', 0x058, {
        ['Player'] = player.id,
        ['Target'] = target.id,
        ['Player Index'] = player.index,
      }))
		
      melee.target = target.id
      melee.leader = leader.id
      melee.range.min = tonumber(cmd[4])
      melee.range.max = tonumber(cmd[5])
      melee.orientation = cmd[6]
      melee.precision = 0.25
      melee.timer.attack = 0
      melee.timer.stuck = 0
      melee.stuck = false
      melee.stop = false
      melee.timer.stop = 0
      melee.timer.switch = 0
      melee.reswitch = false
    end
    return true
  end
  
  return false
end

function melee.frame()
  -- Some stuff to make sure weapons get put away when recieving a disengage order
  if melee.stop and melee.state then
    melee.stop = false
    util.exec('input /attackoff')
  elseif melee.stop and melee.timer.stop > 90 then
    melee.stop = false
  elseif melee.stop then
    melee.timer.stop = melee.timer.stop + 1
  end
  
  if (not melee.target) then return false end
  local player = windower.ffxi.get_mob_by_target('me')
  local target = windower.ffxi.get_mob_by_id(melee.target)
  if (not target) or (not player) then return false end
  
  local target = windower.ffxi.get_mob_by_id(melee.target)
  local leader = windower.ffxi.get_mob_by_id(melee.leader)
  local player = windower.ffxi.get_mob_by_target('me')
  local select =  windower.ffxi.get_mob_by_target('t')
  
  local tgt = vec2.create(target.x, target.y)
  local ply = vec2.create(player.x, player.y)
  local led = vec2.create(leader.x, leader.y)
  
  local dist = vec2.distance(tgt, ply)
  local dir = vec2.normalize(vec2.subtract(tgt, ply))
    
  local switch
  if melee.switch then
    switch = windower.ffxi.get_mob_by_id(melee.switch)
  end
  
  if switch and melee.state then
    if melee.timer.switch > 0 then
      melee.timer.switch = melee.timer.switch - 1
      return true
    end
    
    local player = windower.ffxi.get_player()
    packets.inject(packets.new('incoming', 0x058, {
      ['Player'] = player.id,
      ['Target'] = switch.id,
      ['Player Index'] = player.index,
    }))
    if select.id == switch.id then
      
      packets.inject(packets.new('outgoing', 0x01A, {
        ['Category'] = 15,
        ['Param'] = 0,
        ['Target'] = switch.id,
        ["Target Index"] = switch.index,
        ["X Offset"] = 0,
        ["Y Offset"] = 0,
        ["Z Offset"] = 0
      }))
      
      if not melee.reswitch then
        melee.reswitch = true
      else
        melee.target = switch.id
        melee.switch = nil
      end
      melee.timer.switch = 22
    end
    
    melee.timer.switch = melee.timer.switch + 10
    windower.ffxi.run(false)
    return true
  end
    
  -- If target is dead then disengage
  if target.hpp < 1 then
    melee.disengage()
    return true
  end
  
  -- Out of range to engage, move closer
  if dist > 25 and not melee.state then
    util.move(dir)
    return true
  end
  
  -- If in range to engage attack, and we are correctly targeting our target, attempt to do so at regular intervals
  if (not melee.state) and select and select.id == target.id then
    windower.ffxi.run(false)
    if melee.timer.attack > 0 then
      melee.timer.attack = melee.timer.attack - 1
    else
      windower.send_command('input /attack on')
      melee.timer.attack = 20
    end
    return true
  end
  
  -- Orientation stuff
  local min = math.max(0.1, target.model_size + melee.range.min)
  local max = target.model_size + melee.range.max
  local med = (min + max) * 0.5
  
  local formOrn = vec2.normalize(vec2.subtract(tgt, led))
  local formAng = vec2.angle(vec2.create(0,1), formOrn)
  if formOrn.x < 0 then
    formAng = formAng * -1
  end
  
  local tgtOrn = vec2.create(0, med)
  if melee.orientation == 'west' then
    tgtOrn = vec2.create(-med, 0)
  elseif melee.orientation == 'east' then
    tgtOrn = vec2.create(med, 0)
  elseif melee.orientation == 'south' then
    tgtOrn = vec2.create(0, -med)
	end
  
  local tgtOrn = vec2.rotate(tgtOrn, formAng)
  local tgtPos = vec2.add(tgt, tgtOrn)
  local tgtDist = vec2.distance(ply, tgtPos)
  local tgtDir = vec2.normalize(vec2.subtract(tgtPos, ply))
  local ang = vec2.angle(vec2.create(0,1), dir)
  if dir.x < 0 then
    ang = ang * -1
  end
  
  -- If we get stuck on something near the mob (EX: up against a wall) then just turn towards the mob and attack
  if (dist < max+3) then
    melee.timer.stuck = melee.timer.stuck + 1
    if melee.timer.stuck > 150 then
      melee.orientation = 'none'
      melee.range.min = -5
      melee.range.max = 1.5
      melee.report()
    end
  end

  -- Do movement based on above data
  if dist > max then
    melee.precision = 0.25
    util.move(dir)
  elseif dist < min then
    melee.precision = 0.25
    util.move(tgtDir)
  elseif melee.orientation ~= 'none' and tgtDist > melee.precision then
    melee.precision = 0.25
    util.move(tgtDir)
  else
    if melee.autorange then
      if melee.timer.range > 5 then
        melee.timer.range = 0
        if (not use.next) then
          util.exec('asp order ra <t> Ranged Attack')
        end
      else
        melee.timer.range = melee.timer.range + 1
      end
    end
    melee.timer.stuck = 0
    melee.precision = 0.45
    windower.ffxi.turn(ang - 1.5708)
    windower.ffxi.run(false)
  end
  return true
end

function melee.status(id)
  melee.state = id == 1
end

function melee.onAction(act)
  local player = windower.ffxi.get_mob_by_target('me')
  if (not player) or (act.actor_id ~= player.id) then return false end
  
  if act.category == 01 then
    melee.timer.stuck = 0
  end
end

function melee.disengage()
  if melee.state then
    util.exec('input /attackoff')
  end
  if use.next and use.next.type == 'ra' then
    use.pop()
  end
  melee.target = nil
  melee.leader = nil
  melee.range.min = 0
  melee.range.max = 0
  melee.orientation = nil
  melee.switch = nil
  melee.timer.attack = 0
  melee.precision = 0.25
  melee.timer.stuck = 0
  melee.stuck = false
  melee.stop = true
  melee.timer.stop = 0
  melee.timer.switch = 0
  melee.reswitch = false
  windower.ffxi.run(false)
end

function melee.dead()
  if melee.target then
    melee.disengage()
  end
end

function melee.report()
  if melee.stuck then return end
  
  melee.stuck = true
  --util.exec('input /p Can\'t reach my position! Just gonna bonk em from here instead.')
  log('Melee plugin failed to reach position!')
end

return melee