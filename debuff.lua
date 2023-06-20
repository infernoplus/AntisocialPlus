local debuff = {
  _VERSION = 'Debuff 1.0',
  _DESCRIPTION = 'Health bar and buff tracking for enemies.',
}

require('strings')
require('tables')

debuff.target = nil

function debuff.onCommand(cmd)
  if cmd[1] == 'debuff' then
    if cmd[2] == 'clear' then
      debuff.clear()
    end
  
    local target = windower.ffxi.get_mob_by_target('t')
    if not target then return true end
    
    debuff.clear()
    
    debuff.target = {}
    debuff.target.id = target.id
    return true
  end
  return false
end

function debuff.onGainBuff(id)
  if debuff.target and debuff
  end
end

function debuff.onLosebuff(id)

end

function debuff.clear()
  if debuff.target then
    -- @TODO: Clear stuff from current target
  end
end

return debuff