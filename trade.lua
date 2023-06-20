local trade = {
  _VERSION = 'Trade 1.0',
  _DESCRIPTION = 'Accept trade offers automatically.',
}

require('strings')
require('tables')

--local inspect = require('inspect')
local util = require('util')

trade.enabled = false

function trade.onCommand(cmd)
  if cmd[1] == 'trade' then
    if cmd[2] == nil or cmd[2] == 'toggle' then
      trade.enabled = not trade.enabled
    elseif cmd[2] == 'on' then
      trade.enabled = true
    else 
      trade.enabled = false
    end
    
    if trade.enabled then
      log('AutoTrade Enabled')
    else
      log('AutoTrade Disabled')
    end
    return true
  end
  
  return false
end

function trade.inPacket(id, original)
  if id == 33 and trade.enabled then
    log('Auto accepting trade...')
    local nupak = packets.new('outgoing', 0x033, {
      ['Trade Count'] = 0,
    })
    packets.inject(nupak)
  end
end

return trade