local ammo = {
  _VERSION = 'Ammo 1.0',
  _DESCRIPTION = 'Automatically uses ammo pouches and equips ammo when you run out.',
}

require('strings')
require('tables')

local use = require('use')
local input = require('input')
local util = require('util')

ammo.item = undefined
ammo.equip = undefined

ammo.timer = {}
ammo.timer.equip = 0 -- Wait a few seconds between reload attempts
ammo.timer.item = 0

function ammo.command(cmd)
  local player = windower.ffxi.get_player()
  if not player then return false end

-- ammo
  if cmd[1] == 'ammo' then
    ammo.equip = undefined
    ammo.item = undefined
  
    -- Sending names with spaces over ipc is a mess so we convert all underscores to spaces for sanity
    if cmd[2] then ammo.equip = string.gsub(cmd[2], '_', ' ') end
    if cmd[3] then ammo.item = string.gsub(cmd[3], '_', ' ') end
    if ammo.item then
      log('Auto-reload: ' .. ammo.equip .. ' + ' .. ammo.item)
    else
      log('Auto-reload: ' .. ammo.equip)
    end
    return true
  end
    
  return false
end

function ammo.frame()
  local player = windower.ffxi.get_mob_by_target('me')
  if not player then return false end
  
  if ammo.equip then
    if ammo.timer.equip > 0 then
      ammo.timer.equip = ammo.timer.equip -1
    else
      local inv = windower.ffxi.get_items()
      if inv.equipment.ammo == 0 then
        util.exec("equip 'ammo' '".. ammo.equip .. "'")
      end
      ammo.timer.equip = 30
    end
  end

  if ammo.item then
    if ammo.timer.item > 0 then
      ammo.timer.item = ammo.timer.item -1
    else
      local inv = windower.ffxi.get_items()
      if inv.equipment.ammo == 0 then
        util.exec('asp order item <me> ' .. ammo.item)
        ammo.timer.item = 300
      else
        ammo.timer.item = 30
      end
    end
  end
end

return ammo