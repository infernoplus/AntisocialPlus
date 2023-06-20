local uptime = {
  _VERSION = 'Uptime 1.0',
  _DESCRIPTION = 'Configure certain job abilities to always be recast when their buff is missing',
}

require('strings')
require('tables')

local res = require('resources')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

uptime.actions = {}
uptime.timer = 0
uptime.state = 0 -- Player state, so we don't try to do stuff during cutscenes or while healing, etc
uptime.mounted = false

function uptime.onCommand(cmd)
  if cmd[1] == 'uptime' then
    if cmd[2] == 'clear' then
      uptime.actions = {}
      return true
    end
    
    local cond = ''
    for i=5, #cmd do
      cond = cond .. cmd[i] .. ' '
    end
    local act = {}
    act.type = cmd[2]      -- ja / ma / ws / exec ...
    act.action = string.gsub(string.gsub(cmd[3], '_', ' '), '&', '\'')    -- "Divine Seal" / "Hasso" ...            -- NOTE: replacing all _ wiht spaces so we can send this over exec easier
    act.target = cmd[4]    -- <t> / <me> / nil / ...
    act.condition = string.gsub(cond, '&', '\'')   -- Condition to eval
    act.func = loadstring('return function(buff, hp, mp, tp, combat, tgt, range) return ' .. cond .. ' end') -- Compiled condition so we dont recomp it every time
    uptime.actions[#uptime.actions+1] = act
    return true
  end
  
  return false
end

function uptime.status(id)
  uptime.state = id
end

function uptime.onFrame()
  local player = windower.ffxi.get_mob_by_target('me')
  local target = windower.ffxi.get_mob_by_target('t')
  local info = windower.ffxi.get_player()
  if not player then return end
  if uptime.timer > 0 then
    uptime.timer = uptime.timer - 1
    return
  end
  
  -- If the player is not neutral or in combat skip uptime checks
  if not (uptime.state == 0 or uptime.state == 1) then
    uptime.timer = 30
    return
  end
  
  -- Check if player is mounted because that is a buff for some dumb reason. skip if uptime check if they are
  local buffs = windower.ffxi.get_player().buffs
  for i,b in ipairs(buffs) do
    if b == 252 then
      uptime.timer = 30
      return
    end
  end
  
  uptime.timer = 90

  local buff = function(name)
    local buffs = info.buffs
    for i,id in ipairs(buffs) do
      if string.lower(res.buffs[id].en) == string.lower(name) then
        return true
      end
    end
    return false
  end
  
  local hp = info.vitals.hpp
  local mp = info.vitals.mp
  local tp = info.vitals.tp
  local combat = info.in_combat
  local tgt = (target and target.is_npc and target.valid_target and target.hpp > 0)
  local range = 0
  if tgt then
    range = vec2.distance(vec2.create(player.x, player.y), vec2.create(target.x, target.y))
  end
  
  for i,act in ipairs(uptime.actions) do
    if act.func()(buff, hp, mp, tp, combat, tgt, range) then
      if act.type == 'ja' then
        local abl = res.job_abilities:with('name', act.action)
        local ablrecasts = windower.ffxi.get_ability_recasts()
        local recast = ablrecasts[abl.recast_id]
        if recast ~= nil and recast < 1 then
          util.exec(act.type .. ' ' .. act.action .. ' ' .. act.target)
        end
      elseif act.type == 'ws' or act.type == 'ma' then
        util.exec(act.type .. ' ' .. act.action .. ' ' .. act.target)
      elseif act.type == 'exec' then
        util.exec(act.action)
      end
      return
    end
  end
end

return uptime