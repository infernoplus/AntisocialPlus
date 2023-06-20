_addon.name = 'Antisocial+'
_addon.author = 'InfernoPlus'
_addon.version = '2.0'
_addon.commands = {'antisocial', 'asp'}

require('strings')
require('tables')
require('sets')
require('coroutine')
packets = require('packets')
res = require('resources')
items = res.items
config = require('config')
texts = require('texts')
require('logger')

local mechanic = require('mechanic')
local melee = require('melee')
local ammo = require('ammo')
local formation = require('formation')
local use = require('use')
local battlemage = require('battlemage')
local track = require('track')
local macro = require('macro')
local input = require('input')
local talk = require('talk')
local trade = require('trade')
local target = require('target')
local examine = require('examine')
local misc = require('misc')
local uptime = require('uptime')
local bar = require('bar')
local gather = require('gather')
local experience = require('experience')
local foe = require('foe')
local party = require('party')
local chest = require('chest')

local inspect = require('inspect')
local vec2 = require('vec2')
local util = require('util')

-- Addon commands
windower.register_event('addon command', function(...)
  local arg = {...}
  local cmd = {}

  for i,a in ipairs(arg) do
    if a then
      cmd[i] = a
    end
  end

  -- Help // Null
  if not cmd[1] or cmd[1] == 'help' then
    log('Antisocial+ - asp')
    log('--------------------------------------------------------')
    log('  input <character name> <...commands>')
    log('  input all <...commands>')
    log('  exec <character name> <...commands>')
    log('  exec all <...commands>')
    log('  target <character name>')
    log('  target all')
    log('  formation <type> <scale> <...list of character names>')
    log('  formation stop')
    log('  melee <character name> <min range> <max range> <orientation>')
    log('  range <character name> <min range> <max range> <orientation>')
    log('  disengage <character name>')
    log('  disengage all')
    log('  do <character name> <action type> <action name> <target type>')
    log('  battlecast <character name> <action type> <action name> <target type>')
    log('  ammo')
    log('  trade ')
    log('  gather <on/off> ')
    log('  foe ')
    log('  bar ')
    log('  exp <line>')
    log('  track ')
    log('  macro ')
    log('  examine ')
    log('  impulse <...list of keys to push>')
    log('  autotalk <on \ off \ toggle>')
    log('  autokey <on \ off \ toggle>')
    log('  autoparty')
    return
    
  -- Chat Log Command
  elseif cmd[1] == 'input' then
    local concat = ''
    for i=3, #cmd do
      concat = concat .. cmd[i] .. ' '
    end
    util.send(cmd[2], 'input /' .. concat)
    
  -- Windower Console Command
  elseif cmd[1] == 'exec' then
    local concat = ''
    for i=3, #cmd do
      concat = concat .. cmd[i] .. ' '
    end
    util.send(cmd[2], concat)
   
  -- Disengage Command
  elseif cmd[1] == 'disengage' then
    if cmd[2] == 'all' or not cmd[2] then
      util.send('all', 'asp disengageorder')
    else
      util.send(cmd[2], 'asp disengageorder')
    end
  
  -- Disengage Order
  elseif cmd[1] == 'disengageorder' then
    melee.disengage()
 
  -- Addon Classes
  elseif mechanic.onCommand(cmd) then return
  elseif melee.command(cmd) then return
  elseif ammo.command(cmd) then return
  elseif formation.command(cmd) then return
  elseif bar.onCommand(cmd) then return
  elseif experience.onCommand(cmd) then return
  elseif gather.onCommand(cmd) then return
  elseif foe.onCommand(cmd) then return
  elseif party.command(cmd) then return
  elseif target.command(cmd) then return
  elseif examine.command(cmd) then return
  elseif misc.command(cmd) then return
  elseif uptime.onCommand(cmd) then return
  elseif use.onCommand(cmd) then return
  elseif battlemage.onCommand(cmd) then return
  elseif track.onCommand(cmd) then return
  elseif macro.onCommand(cmd) then return
  elseif talk.command(cmd) then return
  elseif input.command(cmd) then return
  elseif trade.onCommand(cmd) then return
  end
end)

-- Functions to run every frame
windower.register_event('prerender', function()
  if dead() then return end

  party.frame()
  input.frame()
  battlemage.onFrame()
  ammo.frame()
  use.onFrame()
  track.onFrame()
  uptime.onFrame()
  gather.onFrame()
  bar.onFrame()
  experience.onFrame()
  
  if not use.isHalt() then
    if mechanic.onFrame() then return
    elseif melee.frame() then return
    elseif talk.frame() then return
    elseif formation.frame() then return
    end
  else
    windower.ffxi.run(false)
  end
end)

-- Functions to run after every frame
windower.register_event('postrender', function()
  bar.draw()
  foe.draw()
  track.draw()
  macro.draw()
  gather.draw()
  experience.draw()
  
  if dead() then return end

  use.draw()
  talk.draw()
end)

-- Incoming packet event
windower.register_event('incoming chunk', function(id, original, modified, injected, blocked)
  if injected or blocked then return end
  
  trade.inPacket(id, original)
  
  --local pak = packets.parse('incoming', original)
  -- if id == 202 then
  --  print('pkt ' .. id)
  --  print('    ' .. inspect(pak))
  -- end
 
  if pkt then return end
end)

-- Outgoing packet event
windower.register_event('outgoing chunk', function(id, original, modified, injected, blocked)
  if injected or blocked then return end
  
  talk.outPacket(id, original)
  
  --local pak = packets.parse('outgoing', original)
  --if id ~= 21 then
  --  print('pkt ' .. id)
  --  print('    ' .. inspect(pak))
  --end
 
  if pkt then return end
end)

-- Keyboard input events
windower.register_event('keyboard', function(id, down, flag, blocked)
  input.onKey(id, down)
end)

-- Hard player status changes
windower.register_event('status change', function(id)
  use.onStatus(id)
  melee.status(id)
  talk.status(id)
  uptime.status(id)
end)

-- Player action events
windower.register_event('action', function(act)
  use.onAction(act)
  melee.onAction(act)
  battlemage.onAction(act)
end)

windower.register_event('action message',function (actor_id, target_id, actor_index, target_index, message_id, param_1, param_2, param_3)
  --log(message_id)
  use.onActionMessage(message_id)
end)

windower.register_event('party invite', function()
  party.invite()
end)

-- Chat log message event
windower.register_event('incoming text', function(original, modified, omode, mmode)
  if chest.solve(original) then return end
end)

windower.register_event('unload', function()
  windower.ffxi.run(false)
  coroutine.sleep(0.25)
end)

function dead()
  local player = windower.ffxi.get_mob_by_target('me')
  if player and player.hpp < 1 then
    use.dead()
    melee.dead()
    formation.dead()
    talk.dead()
    battlemage.dead()
    return true
  end
  return false
end