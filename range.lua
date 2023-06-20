local range = {
  _VERSION = 'Range 1.0',
  _DESCRIPTION = 'Order a client to fight a target with ranged attacks using specific spacing parameters',
}

require('strings')
require('tables')

local use = require('use')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

range.target = nil
range.leader = nil
range.range = {}
range.range.min = 0
range.range.max = 0
range.orientation = nil
range.state = false          -- If true then we have our weapon out
range.switch = nil           -- If we are engaged and recieve a new target, we will switch to this new target as soon as we can
range.timer = {}
range.timer.attack = 0
range.timer.stuck = 0
range.timer.stop = 0
range.timer.switch = 0
range.timer.reswitch = false
range.timer.queue = 0        -- Time between range attack queues, this timer is kinda goofy due to the nature of use HALT actions.
range.precision = 0.25       -- Not a user setting
range.stuck = false
range.stop = false           -- Set when we get a disengage order, this makes sure that we put our weapons away if the order came in before the state change (laggy game is laggy)

function range.command(cmd)
  local player = windower.ffxi.get_mob_by_target('me')
  if not player then return false end

  if cmd[1] == 'range' then  
    local target = windower.ffxi.get_mob_by_target('t')
    if target and target.is_npc and target.valid_target then
      if cmd[5] == nil then
        cmd[5] = "none"
      end
      util.send(cmd[2], 'asp rangeorder ' .. (target.id) .. ' ' .. (player.id).. ' ' .. cmd[3] .. ' ' .. cmd[4] .. ' ' .. cmd[5])
      return true
    end
		
  elseif cmd[1] == 'rangeorder' then
    local target = windower.ffxi.get_mob_by_id(tonumber(cmd[2]))
    local leader = windower.ffxi.get_mob_by_id(tonumber(cmd[3]))
    
    if not (target.is_npc and target.valid_target) then return true end
    	
    if target and leader then
      if range.target and target.id ~= range.target and range.state then
        range.switch = target.id
        range.leader = leader.id
        range.range.min = tonumber(cmd[4])
        range.range.max = tonumber(cmd[5])
        range.orientation = cmd[6]
        range.precision = 0.25
        range.timer.attack = 0
        range.timer.stuck = 0
        range.stuck = false
        range.stop = false
        range.timer.stop = 0
        range.timer.switch = 0
        range.reswitch = false
        return true
      end

      local player = windower.ffxi.get_player()
      packets.inject(packets.new('incoming', 0x058, {
        ['Player'] = player.id,
        ['Target'] = target.id,
        ['Player Index'] = player.index,
      }))
		
      range.target = target.id
      range.leader = leader.id
      range.range.min = tonumber(cmd[4])
      range.range.max = tonumber(cmd[5])
      range.orientation = cmd[6]
      range.precision = 0.25
      range.timer.attack = 0
      range.timer.stuck = 0
      range.stuck = false
      range.stop = false
      range.timer.stop = 0
      range.timer.switch = 0
      range.reswitch = false
    end
    return true
  end
  
  return false
end

function range.frame()
  -- Some stuff to make sure weapons get put away when recieving a disengage order
  if range.stop and range.state then
    range.stop = false
    util.exec('input /attackoff')
  elseif range.stop and range.timer.stop > 90 then
    range.stop = false
  elseif range.stop then
    range.timer.stop = range.timer.stop + 1
  end
  
  if (not range.target) then return false end
  local player = windower.ffxi.get_mob_by_target('me')
  local target = windower.ffxi.get_mob_by_id(range.target)
  if (not target) or (not player) then return false end
  
  local target = windower.ffxi.get_mob_by_id(range.target)
  local leader = windower.ffxi.get_mob_by_id(range.leader)
  local player = windower.ffxi.get_mob_by_target('me')
  local select =  windower.ffxi.get_mob_by_target('t')
  
  local tgt = vec2.create(target.x, target.y)
  local ply = vec2.create(player.x, player.y)
  local led = vec2.create(leader.x, leader.y)
  
  local dist = vec2.distance(tgt, ply)
  local dir = vec2.normalize(vec2.subtract(tgt, ply))
    
  local switch
  if range.switch then
    switch = windower.ffxi.get_mob_by_id(range.switch)
  end
  
  if switch and range.state then
    if range.timer.switch > 0 then
      range.timer.switch = range.timer.switch - 1
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
      
      if not range.reswitch then
        range.reswitch = true
      else
        range.target = switch.id
        range.switch = nil
      end
      range.timer.switch = 22
    end
    
    range.timer.switch = range.timer.switch + 10
    windower.ffxi.run(false)
    return true
  end
    
  -- If target is dead then disengage
  if target.hpp < 1 then
    range.disengage()
    return true
  end
  
  -- Out of range to engage, move closer
  if dist > 25 and not range.state then
    util.move(dir)
    return true
  end
  
  -- If in range to engage attack, and we are correctly targeting our target, attempt to do so at regular intervals
  if (not range.state) and select and select.id == target.id then
    windower.ffxi.run(false)
    if range.timer.attack > 0 then
      range.timer.attack = range.timer.attack - 1
    else
      windower.send_command('input /attack on')
      range.timer.attack = 20
    end
    return true
  end
  
  -- Orientation stuff
  local min = math.max(0.1, target.model_size + range.range.min)
  local max = target.model_size + range.range.max
  local med = (min + max) * 0.5
  
  local formOrn = vec2.normalize(vec2.subtract(tgt, led))
  local formAng = vec2.angle(vec2.create(0,1), formOrn)
  if formOrn.x < 0 then
    formAng = formAng * -1
  end
  
  local tgtOrn = vec2.create(0, med)
  if range.orientation == 'west' then
    tgtOrn = vec2.create(-med, 0)
  elseif range.orientation == 'east' then
    tgtOrn = vec2.create(med, 0)
  elseif range.orientation == 'south' then
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
    range.timer.stuck = range.timer.stuck + 1
    if range.timer.stuck > 150 then
      range.orientation = 'none'
      range.range.min = -5
      range.range.max = 1.5
      range.report()
    end
  end

  -- Do movement based on above data
  if dist > max then
    range.precision = 0.25
    util.move(dir)
  elseif dist < min then
    range.precision = 0.25
    util.move(tgtDir)
  elseif range.orientation ~= 'none' and tgtDist > range.precision then
    range.precision = 0.25
    util.move(tgtDir)
  else
    range.timer.stuck = 0
    range.precision = 0.45
    windower.ffxi.turn(ang - 1.5708)
    windower.ffxi.run(false)
  end
  return true
end

function range.status(id)
  range.state = id == 1
end

function range.onAction(act)
  local player = windower.ffxi.get_mob_by_target('me')
  if (not player) or (act.actor_id ~= player.id) then return false end
  
  if act.category == 01 then
    range.timer.stuck = 0
  end
end

-- Queue up an RA in the use plugin
function range.queue()
  if (not use.next) then
    util.exec('asp order ra <t> Ranged Attack')
  end
end

function range.disengage()
  if range.state then
    util.exec('input /attackoff')
  end
  if use.next and use.next.type == 'ra' then
    use.pop()
  end
  range.target = nil
  range.leader = nil
  range.range.min = 0
  range.range.max = 0
  range.orientation = nil
  range.switch = nil
  range.timer.attack = 0
  range.precision = 0.25
  range.timer.stuck = 0
  range.stuck = false
  range.stop = true
  range.timer.stop = 0
  range.timer.switch = 0
  range.reswitch = false
  windower.ffxi.run(false)
end

function range.dead()
  if range.target then
    range.disengage()
  end
end

function range.report()
  if range.stuck then return end
  
  range.stuck = true
  util.exec('input /p Can\'t reach my position! Just gonna bonk em from here instead.')
end

return range