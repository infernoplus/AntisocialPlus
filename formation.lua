local formation = {
  _VERSION = 'Formation 1.0',
  _DESCRIPTION = 'Move groups of characters in tight formation',
}

require('strings')
require('tables')

local input = require('input')
local vec2 = require('vec2')
local util = require('util')

formation.type = nil
formation.members = {}
formation.scale = nil
formation.precision = 0.2
formation.zone = nil        -- Checked against each update for zone change
formation.timer = 0         -- Delay between updates so we don't do it every frame
formation.last = nil

formation.move = {}
formation.move.position = nil
formation.move.precision = nil
formation.move.zone = nil
formation.move.timer = 90
formation.move.last = nil
formation.move.stuck = 0

function formation.command(cmd)
  if cmd[1] == 'formation' then
    if cmd[2] == 'stop' or cmd[2] == 'end' or cmd[2] == 'cancel' then
      if formation.type then
        util.send('all', 'asp formation stop')
      end
      formation.type = nil
      formation.members = {}
      formation.scale = nil
      formation.precision = nil
      formation.zone = nil
      formation.timer = 0
      formation.move.position = nil
      formation.move.zone = nil
      formation.move.precision = nil
      formation.move.timer = 90
      formation.move.last = nil
      windower.ffxi.run(false)
    else    
      if cmd[2] == 'point' then
        formation.type = 'point'
      elseif cmd[2] == 'line' then
        formation.type = 'line'
      elseif cmd[2] == 'follow' then
        formation.type = 'follow'
      end
      local info = windower.ffxi.get_info()
      formation.zone = info.zone
      formation.scale = tonumber(cmd[3])
      formation.members = {}
      for i,mem in ipairs(cmd) do
        if i > 3 then
          formation.members[i-3] = mem
        end
      end
    end
    return true
    
  elseif cmd[1] == 'moveorder' then
    local player = windower.ffxi.get_mob_by_target('me')
    local info = windower.ffxi.get_info()
    if (not player) or (not player.x) then return true end
    
    local prec = tonumber(cmd[2])
    local zone = tonumber(cmd[3])
    local pos = vec2.create(tonumber(cmd[4]), tonumber(cmd[5]))
    
    local ply = vec2.create(player.x, player.y)
    local dist = vec2.distance(ply, pos)
               
    if (zone ~= info.zone) or (dist > 30) or (dist < prec) then
      return true
    end
    
    formation.move.precision = prec
    formation.move.zone = zone
    formation.move.position = pos
    return true
  end
  return false
end

function formation.frame()
  return formation.update() or formation.move.update()
end

function formation.update()
  local player = windower.ffxi.get_mob_by_target('me')
  local info = windower.ffxi.get_info()
  if not formation.type then return false end
  if (not player) or (not player.x) then return true end

  formation.timer = formation.timer + 1
  if formation.timer < 2 then
    return true
  end

  formation.timer = 0

  if formation.zone and formation.zone ~= info.zone then
    util.send('all', 'asp moveorder 0.01 ' .. formation.zone ..  ' ' .. formation.last.x .. ' ' .. formation.last.y)
    formation.zone = info.zone
  end
  
  local ply = vec2.create(player.x, player.y)
  local fpoints = formation.calculate(ply, player.facing, formation.type, formation.scale, #formation.members)
  local fprec = 0
  for i,mem in ipairs(formation.members) do
    if formation.type == 'follow' then
      fprec = fprec + formation.scale
    elseif formation.type == 'point' then
      fprec = formation.scale
    else
      fprec = 0.2
    end
    util.send(mem, 'asp moveorder ' .. fprec .. ' ' .. info.zone .. ' ' .. fpoints[i].x .. ' ' .. fpoints[i].y)
  end
  formation.last = ply
  formation.zone = info.zone
  return true
end

function formation.move.update()
  local player = windower.ffxi.get_mob_by_target('me')
  local info = windower.ffxi.get_info()
  if not formation.move.position then return false end
  if (not player) or (not player.x) then return true end
  if formation.move.stuck > 0 then
    formation.move.stuck = formation.move.stuck - 1
    windower.ffxi.run(false)
    return true
  end
    
  local ply = vec2.create(player.x, player.y)
  local dist = vec2.distance(ply, formation.move.position)
  
  if (formation.move.zone ~= info.zone) or (dist > 30) or (dist < formation.move.precision) then
    formation.move.position = nil
    formation.move.zone = nil
    formation.move.precision = nil
    formation.move.timer = 90
    formation.move.last = nil
    windower.ffxi.run(false)
  else
    local dir = vec2.normalize(vec2.subtract(formation.move.position, ply))
    util.move(dir)
    
    if not formation.move.last then
      formation.move.last = ply
    end
    
    if formation.move.timer > 0 then
      formation.move.timer = formation.move.timer - 1
    else
      formation.move.timer = 90
      local prog = vec2.distance(ply, formation.move.last)
      if prog < 0.75 and dist > (formation.move.precision + 2) then
        formation.move.stuck = 150
        formation.report()
      end
      formation.move.last = ply
    end
  end
  
  return true
end

-- Creates an array of vec2s based on formation type
function formation.calculate(pos, orn, type, scale, size)
  local positions = {}

  if type == 'point' or type == 'follow' then
    for i=0, size do
      positions[i+1] = pos
    end
  elseif type == 'line' then
    local flipc = 1
    for i=0, size do
      local offset = vec2.create(0, flipc * scale)
      local center = pos
      local offang = vec2.rotate(offset, orn)
      positions[i+1] = vec2.add(center, offang)
      if flipc > 0 then
        flipc = flipc * -1
      else
        flipc = (flipc * -1) + 1
      end
    end
  end

  return positions
end

function formation.report()
  local messages = {
    'I\'m stucky-wucky~',
    'My movementaru is obstructaru\'d',
    'Waitaru for meeeeeee~',
    'Don\'t leave withoutaru me!',
    'I need some helpy-welpy back here~',
    'What are you doing step-taru?~~',
    'Door stuck! Door stuck!',
    'Oh no! My one weakness! A wall!'
  }  
  local selecto = math.floor(math.random()*#messages)
  util.exec('input /p ' .. messages[selecto+1])
end

function formation.dead()
  if formation.type or formation.move.position then
    formation.type = nil
    formation.members = {}
    formation.scale = nil
    formation.precision = nil
    formation.zone = nil
    formation.timer = 0
    formation.move.position = nil
    formation.move.zone = nil
    formation.move.precision = nil
    formation.move.timer = 90
    formation.move.last = nil
    windower.ffxi.run(false)
  end
end

return formation