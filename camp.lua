local camp = {
  _VERSION = 'Camp 1.0',
  _DESCRIPTION = 'Automatically camps a specified target. Kind of a bot lol sorry',
}

require('strings')
require('tables')

local util = require('util')

camp.interval = 180   -- # of frames between scans
camp.delay = 300 -- # of frames to wait after we attempt engage a target
camp.range = 25

camp.targetName = nil -- scan by name (stub)
camp.targetIndex = nil -- scan by index

camp.timer = 0

camp.last = nil         -- measures time between target spawns and warns you if it takes longer than normal
camp.measure = nil

function camp.command(cmd)
  local player = windower.ffxi.get_player()
  if not player then return false end

    if cmd[2] == 'off' then
      camp.targetName = nil
      camp.targetIndex = nil
      camp.last = nil
      camp.measure = nil
      return true
    end
    
    local cmds = ''
    for i=3, #cmd do
      cmds = cmds .. cmd[i] .. ' '
    end
    cmds = util.trim(cmds)
    
    if cmd[2] == 'index' then
      camp.targetIndex = tonumber(cmd[3])
    elseif cmd[2] == 'name' then
      camp.targetName = cmd[3]
    end
    
  return false
end

function camp.onFrame()
  local player = windower.ffxi.get_mob_by_target('me')
  if not player then return end
  
  if camp.timer > 0 then
    camp.timer = camp.timer - 1
    return
  end
  camp.timer = camp.interval
  
  if camp.measure and (os.clock() - camp.last > camp.measure + 30) then
    log("CAMP target is over 30 seconds late on spawn...") -- change this to an onscreen text later
  end
  
  local target = nil
  if camp.targetIndex then
    target = windower.ffxi.get_mob_by_index(camp.targetIndex)
  end
  
  local info = windower.ffxi.get_player()
  if target and target.hpp > 0 and target.distance < camp.range and not info.in_combat then  
    util.exec("asp meleeorder " .. target.id .. " " .. player.id .. " -0.1 1.25 none") -- calling the melee plugin to actually handle combat
    log("Engaging CAMP target...")
    
    if camp.last and not camp.measure then
      camp.measure = os.clock() - camp.last
      log("CAMP target estimated spawn time is " .. camp.measure .. " seconds")
    end
    
    camp.last = os.clock()
    
    camp.timer = camp.delay
  end
end
    
return camp