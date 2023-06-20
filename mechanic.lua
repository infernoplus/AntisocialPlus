local mechanic = {
  _VERSION = 'Mechanic 1.0',
  _DESCRIPTION = 'Special orders for combat situations.',
}

require('strings')
require('tables')

local vec2 = require('vec2')
local util = require('util')

mechanic.type = nil
mechanic.stack = {timer = 0, target = nil}
mechanic.trick = {timer = 0, target = nil, use = false}
mechanic.sneak = {timer = 0, use = false}

function mechanic.onCommand(cmd)
  local player = windower.ffxi.get_mob_by_target('me')
  if not player then return false end

  if cmd[1] == 'mechanic' then
    if cmd[3] == 'cancel' then
      util.send(cmd[2], 'asp mechanicorder cancel')
      return true
    end
    
    local cmds = ''
    for i=3, #cmd do
      cmds = cmds .. cmd[i] .. ' '
    end
    
    util.send(cmd[2], 'asp mechanicorder ' .. player.name .. ' ' .. cmds)
    return true
    
  elseif cmd[1] == 'mechanicorder' then
    if cmd[2] == 'cancel' then
      mechanic.type = nil
      mechanic.stack = {timer = 0, target = nil}
      mechanic.trick = {timer = 0, targetA = nil, targetB = nil, use = false}
      windower.ffxi.run(false)
      return true
    end
  
    if string.lower(player.name) == string.lower(cmd[2]) then return true end
    
    if cmd[3] == 'stack' then
      mechanic.type = cmd[3]
      mechanic.stack.target = string.lower(cmd[2])
      mechanic.stack.timer = tonumber(cmd[4]) * 30
        
    elseif cmd[3] == 'trick' then
      local abl = res.job_abilities:with('en', 'Trick Attack')
      local ablrecasts = windower.ffxi.get_ability_recasts()
      local recast = ablrecasts[abl.recast_id]
      if not recast or recast > 1 then
        return true
      end
    
      mechanic.type = cmd[3]
      mechanic.trick.target = string.lower(cmd[4]) -- Player to trick attack behind
      mechanic.trick.timer = 300 -- Timeout incase something oofs, 10 seconds seems long enough
      mechanic.trick.use = false -- Flag that we have sent the order for Trick Attack to be used

    elseif cmd[3] == 'sneak' then
      local abl = res.job_abilities:with('en', 'Sneak Attack')
      local ablrecasts = windower.ffxi.get_ability_recasts()
      local recast = ablrecasts[abl.recast_id]
      if not recast or recast > 1 then
        return true
      end
    
      mechanic.type = cmd[3]
      mechanic.sneak.timer = 300 -- Timeout incase something oofs, 10 seconds seems long enough
      mechanic.sneak.use = false -- Flag that we have sent the order for Trick Attack to be used
    end
    
    return true
  end
  return false
end

function mechanic.onFrame()
  if mechanic.doStack() then return true
  elseif mechanic.doTrick() then return true
  elseif mechanic.doSneak() then return true
  end
  
  return false
end

function mechanic.doStack()
  if not (mechanic.type == 'stack') then
    return false
  elseif mechanic.stack.timer <= 0 then
    mechanic.type = nil
    mechanic.stack = {timer = 0, target = nil}
    windower.ffxi.run(false)
    return false
  end
  
  mechanic.stack.timer = mechanic.stack.timer - 1
  
  

  local player = windower.ffxi.get_mob_by_target('me')
  local target = util.getPlayerMob(mechanic.stack.target)
  
  if (not player) or (not target) then
    mechanic.type = nil
    mechanic.stack = {timer = 0, target = nil}
    windower.ffxi.run(false)
    return false
  end
  
  local ply = vec2.create(player.x, player.y)
  local tgt = vec2.create(target.x, target.y)
  
  if vec2.distance(ply, tgt) > 25 then
    mechanic.type = nil
    mechanic.stack = {timer = 0, target = nil}
    windower.ffxi.run(false)
    return true
  end
  
  local dist = vec2.distance(ply, tgt)
  local dir = vec2.normalize(vec2.subtract(tgt, ply))
  
  if dist > 0.75 then 
    util.move(dir)
  else
    windower.ffxi.run(false)
  end
  
  return true
end

function mechanic.doTrick()
  if not (mechanic.type == 'trick') then
    return false
  elseif mechanic.trick.timer <= 0 then
    mechanic.type = nil
    mechanic.trick = {timer = 0, target = nil, use = false}
    windower.ffxi.run(false)
    return false
  end
  
  mechanic.trick.timer = mechanic.trick.timer - 1

  local player = windower.ffxi.get_mob_by_target('me')
  local targetA = util.getPlayerMob(mechanic.trick.target) -- Player
  local targetB = windower.ffxi.get_mob_by_target('t') -- Enemy
  
  if (not player) or (not targetA) or (not targetB) then
    mechanic.type = nil
    mechanic.trick = {timer = 0, target = nil, use = false}
    windower.ffxi.run(false)
    return true
  end
  
  local ply = vec2.create(player.x, player.y)
  local tgta = vec2.create(targetA.x, targetA.y)
  local tgtb = vec2.create(targetB.x, targetB.y)
  
  if vec2.distance(ply, tgta) > 8 or vec2.distance(ply, tgtb) > 8 then
    mechanic.type = nil
    mechanic.trick = {timer = 0, target = nil, use = false}
    windower.ffxi.run(false)
    return true
  end
  
  local behind = vec2.add(tgta, vec2.scale(vec2.normalize(vec2.subtract(tgta, tgtb)), 1.25))
  local dist = vec2.distance(ply, behind)
  local dira = vec2.normalize(vec2.subtract(behind, ply))
  local dirb = vec2.normalize(vec2.subtract(tgtb, ply))
  
  local ang = vec2.angle(vec2.create(0,1), dirb)
  if dirb.x < 0 then
    ang = ang * -1
  end
  
  if dist > 0.35 then
    util.move(dira)
  else
    if not mechanic.trick.use then
      util.exec('ja \'Trick Attack\' <me>')
      util.exec('asp order ja <me> Trick Attack')
      mechanic.trick.timer = 250
      mechanic.trick.use = true
    end
    windower.ffxi.turn(ang - 1.5708)
    windower.ffxi.run(false)
  end
  
  return true
end

function mechanic.doSneak()
  if not (mechanic.type == 'sneak') then
    return false
  elseif mechanic.sneak.timer <= 0 then
    mechanic.type = nil
    mechanic.sneak = {timer = 0, use = false}
    windower.ffxi.run(false)
    return false
  end
  
  mechanic.sneak.timer = mechanic.sneak.timer - 1

  local player = windower.ffxi.get_mob_by_target('me')
  local target = windower.ffxi.get_mob_by_target('t')
  
  if (not player) or (not target) then
    mechanic.type = nil
    mechanic.sneak = {timer = 0, use = false}
    windower.ffxi.run(false)
    return true
  end
  
  local ply = vec2.create(player.x, player.y)
  local tgt = vec2.create(target.x, target.y)
  
  if vec2.distance(ply, tgt) > 8 then
    mechanic.type = nil
    mechanic.sneak = {timer = 0, use = false}
    windower.ffxi.run(false)
    return true
  end
  
  
  local dir = vec2.normalize(vec2.subtract(tgt, ply))
  local behindPos = vec2.add(tgt, vec2.rotate(vec2.create(-(target.model_size+0.25),0), target.facing))
  local behindDir = vec2.normalize(vec2.subtract(behindPos, ply))
  local dist = vec2.distance(ply, behindPos)
  
  local ang = vec2.angle(vec2.create(0,1), dir)
  if dir.x < 0 then
    ang = ang * -1
  end
  
  if dist > 0.35 then
    util.move(behindDir)
  else
    if not mechanic.sneak.use then
      util.exec('ja \'Sneak Attack\' <me>')
      util.exec('asp order ja <me> Sneak Attack')
      mechanic.sneak.timer = 250
      mechanic.sneak.use = true
    end
    windower.ffxi.turn(ang - 1.5708)
    windower.ffxi.run(false)
  end
  
  return true
end

return mechanic