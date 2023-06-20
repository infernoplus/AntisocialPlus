local examine = {
  _VERSION = 'examine 1.0',
  _DESCRIPTION = 'Prints out information on mobs.',
}

require('strings')
require('tables')

local util = require('util')

function examine.command(cmd)
  local player = windower.ffxi.get_player()
  if not player then return false end

-- examine
  if cmd[1] == 'examine' then
    examine.examine()
    return true
  end
    
  return false
end

function examine.examine()
  local target = windower.ffxi.get_mob_by_target('t')
  if not target then return end
  
  log('ID:' .. target.id .. '  INDEX:' .. target.index .. '  TYPE:' .. target.spawn_type)
end
    
return examine