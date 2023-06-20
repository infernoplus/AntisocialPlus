local party = {
  _VERSION = 'AutoParty 1.0',
  _DESCRIPTION = 'Automatically adds all local running clients to your party',
}

require('strings')
require('tables')

local util = require('util')

party.join = false
party.list = {}
party.timer = 0

function party.command(cmd)
  local player = windower.ffxi.get_player()
  if not player then return false end
  
  -- Autoparty
  if cmd[1] == 'autoparty' then
    party.list = {}
    party.timer = 0
    util.send('all', 'asp autopartyreq ' .. string.lower(player.name))
    return true
	
  -- Autoparty Request
  elseif cmd[1] == 'autopartyreq' then
    if string.lower(cmd[2]) == string.lower(player.name) then
      return true
    end
    util.send(cmd[2], 'asp autopartyres ' .. string.lower(player.name))
    party.join = true
    return true
	
  -- Autoparty Response
  elseif cmd[1] == 'autopartyres' then
    party.list[#party.list + 1] = cmd[2]
    return true
  end

  return false
end

function party.frame()
  if party.timer > 0 then
    party.timer = party.timer - 1
    return
  else
    party.timer = 90
  end

  for i,mem in ipairs(party.list) do
    if mem and mem ~= 'null' then
      util.exec('pcmd add ' ..mem)
      log('Inviting ' ..mem.. '...')
      party.list[i] = 'null'
      return
    end
  end
end

function party.invite()
  if party.join then
    util.exec('input /join')
    party.join = false
  --else
  --  util.exec('input /decline')   -- not good because it literally locks out out of invites from non-ipc clients
  end
end

return party