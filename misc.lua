local misc = {
  _VERSION = 'Misc 1.0',
  _DESCRIPTION = 'Little hacks and things',
}

require('strings')
require('tables')

local inspect = require('inspect')
local util = require('util')

function misc.command(cmd)
  local player = windower.ffxi.get_player()
  if not player then return false end

-- trade cabbage x5
  if cmd[1] == 'misc' and cmd[2] == 'cabbagex5' then
       -- cabbage item id    4366
       local bag = windower.ffxi.get_items().inventory
       local cabbage = nil
       for i,itm in ipairs(bag) do
        if itm.id == 4366 and itm.count >= 5 then
          cabbage = i
        end
       end
  
      local target = windower.ffxi.get_mob_by_target('t')
  
      if cabbage and target then
        log('Found cabbage at inv index: ' .. cabbage)
        local nupak = packets.new('outgoing', 0x036, {
          ["Item Count 1"] = 5,
          ["Item Count 2"] = 0,
          ["Item Count 3"] = 0,
          ["Item Count 4"] = 0,
          ["Item Count 5"] = 0,
          ["Item Count 6"] = 0,
          ["Item Count 7"] = 0,
          ["Item Count 8"] = 0,
          ["Item Count 9"] = 0,
          ["Item Index 1"] = cabbage,
          ["Item Index 2"] = 0,
          ["Item Index 3"] = 0,
          ["Item Index 4"] = 0,
          ["Item Index 5"] = 0,
          ["Item Index 6"] = 0,
          ["Item Index 7"] = 0,
          ["Item Index 8"] = 0,
          ["Item Index 9"] = 0,
          ["Number of Items"] = 1,
          ["Target Index"] = target.index,
          ["Target"] = target.id,
        })
        packets.inject(nupak)
      end
    return true
  end
    
  return false
end
    
return misc