local input = {
  _VERSION = 'AutoInput 1.0',
  _DESCRIPTION = 'Replicates inputs and allows triggering input impulses',
}

require('strings')
require('tables')
require('betterq')

local util = require('util')

input.key = false
input.talk = false
input.master = false

input.impulses = Q({})
input.last = nil
input.timer = 20

function input.command(cmd)
  local player = windower.ffxi.get_mob_by_target('me')
  if not player then return false end
  
  if cmd[1] == 'impulse' then
    local concat = ''
    for i=2, #cmd do
      concat = concat .. cmd[i] .. ' '
    end
    input.impulse(concat)
    return true
    
  elseif cmd[1] == 'autokey' then
    util.send('all', 'asp inprep reset')
    if cmd[2] == nil or cmd[2] == 'toggle' then
      input.key = not input.key
    elseif cmd[2] == 'on' then
      input.key = true
    else 
      input.key = false
    end
    if input.key then
      log('AutoKey Enabled')
    else
      log('AutoKey Disabled')
    end
    
  elseif cmd[1] == 'inprep' then
    if cmd[2] == 'reset' then
      input.reset()
      return true
    end
    
    if string.lower(player.name) == cmd[2] then
      return true
    end
    
    if cmd[3] == 'false' and not (input.talk or input.key) then
      return true
    end
    
    util.exec('setkey ' .. cmd[4] .. ' ' .. cmd[5])
    return true
  end
  
  return false
end

function input.frame()
  if input.timer > 0 then
    input.timer = input.timer - 1
    
    if input.timer < 4 and input.last then
      util.exec('setkey ' .. input.last .. ' up')
      input.last = nil
    end
    
    return
  elseif not input.impulses:empty() then
    input.timer = 10
    input.last = input.impulses:pop()
    util.exec('setkey ' .. input.last .. ' down')
  end
end

function input.onKey(id, down)
  local player = windower.ffxi.get_mob_by_target('me')
  if not player then return end

  if (input.key or input.talk) then
    local keyName
    if id == 28 then
      keyName = 'enter'
    elseif id == 200 then
      keyName = 'up'
    elseif id == 208 then
      keyName = 'down'
    elseif id == 203 then
      keyName = 'left'
    elseif id == 205 then
      keyName = 'right'
    elseif id == 59 then
      keyName = 'f1'
    elseif id == 60 then
      keyName = 'f2'
    elseif id == 61 then
      keyName = 'f3'
    elseif id == 62 then
      keyName = 'f4'
    elseif id == 63 then
      keyName = 'f5'
    elseif id == 64 then
      keyName = 'f6'
    elseif id == 65 then
      keyName = 'f7'
    elseif id == 66 then
      keyName = 'f8'
    elseif id == 67 then
      keyName = 'f9'
    elseif id == 68 then
      keyName = 'f10'
    elseif id == 87 then
      keyName = 'f11'
    elseif id == 88 then
      keyName = 'f12'
    elseif id == 12 then
      keyName = '-'
    elseif id == 1 then
      keyName = 'escape'
    else
      return
    end
  
    local boolString
    if down then
      boolString = 'down'
    else
      boolString = 'up'
    end
    
    if input.key then
      util.send('all', 'asp inprep ' .. string.lower(player.name) .. ' true ' .. keyName .. ' ' .. boolString)
    elseif input.talk and input.master then
      util.send('all', 'asp inprep ' .. string.lower(player.name) .. ' false ' .. keyName .. ' ' .. boolString)
    end
  end
end

function input.impulse(cmd)
  local spl = util.split(cmd)
  for i,mem in ipairs(spl) do
    input.impulses:push(mem)
  end
end

function input.reset()
  windower.send_command('wait 0.25; setkey enter up; setkey up up; setkey down up; setkey left up; setkey right up; setkey escape up; setkey - up;')
  input.impulses = Q({})
  input.last = nil
  input.timer = 20
end

return input