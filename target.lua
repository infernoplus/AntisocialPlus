local target = {
  _VERSION = 'Target 1.0',
  _DESCRIPTION = 'Sends target by id to other clients',
}

require('strings')
require('tables')

local input = require('input')
local util = require('util')

function target.command(cmd)
  local player = windower.ffxi.get_player()
  if not player then return false end

-- Target
  if cmd[1] == 'target' then
    local target = windower.ffxi.get_mob_by_target('t')
	  if target then
      util.send(cmd[2], 'asp targetorder ' .. string.lower(player.name) .. ' ' .. (target.id))
    end
    return true
  
-- Target Order
  elseif cmd[1] == 'targetorder' then
    if cmd[2] == string.lower(player.name) then return true end
    
    target.target(cmd[3])
    
    return true
  end
    
  return false
end

function target.target(id)
  local tgt = windower.ffxi.get_mob_by_id(tonumber(id))
  local current = windower.ffxi.get_mob_by_target('t')
  local player = windower.ffxi.get_mob_by_target('me')
  
  -- Skip if target is already the target, if you inject this while the target is already the target then it locks on which is annoying as fuck
  if current and tgt and current.id == tgt.id then
    return
  end
  
  -- Cannot target self using packet injection so we do this instead if targetorder is to target self
  if player.id == tgt.id then
    input.impulse('f1')
    return true
  end
  
  if tgt then
    packets.inject(packets.new('incoming', 0x058, {
      ['Player'] = player.id,
      ['Target'] = tgt.id,
      ['Player Index'] = player.index,
    }))
  end
end
    
return target