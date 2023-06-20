local battlemage = {
  _VERSION = 'Battlemage 1.0',
  _DESCRIPTION = 'Queue a spell to be cast AFTER the next melee attack hits me. Primarily for Paladins to self heal while tanking.',
}

require('strings')
require('tables')
require('betterq')

local inspect = require('inspect')
local texts = require('texts')
local images = require('images')
local res = require('resources')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

battlemage.action = nil

function battlemage.onCommand(cmd)
  if cmd[1] == 'battlecast' then
    if cmd[2] == 'cancel' then
      util.send('all', 'asp battlecastorder cancel')
      return true
    end
    
    util.send(cmd[2], 'asp battlecastorder ' .. cmd[3] .. ' ' .. cmd[5] .. ' ' .. cmd[4])

  elseif cmd[1] == 'battlecastorder' then
    if cmd[2] == 'cancel' and battlemage.action then
        battlemage.action.text:destroy()
        battlemage.action.box:destroy()
        battlemage.action = nil
      return true
    end
    
    local cmds = ''
    for i=4, #cmd do
      cmds = cmds .. cmd[i] .. ' '
    end
    cmds = util.trim(cmds)
    
    local act = {}
    act.type = util.trim(cmd[2])
    act.action = cmds
    act.target = util.trim(cmd[3])
        
    act.box = battlemage.newBox()
    act.text = battlemage.newText(act.action)
    
    if battlemage.action then
      battlemage.action.text:destroy()
      battlemage.action.box:destroy()
    end
    
    battlemage.action = act
    
    return true
  end
  
  return false
end

function battlemage.dead()
  if battlemage.action then
    battlemage.action.text:destroy()
    battlemage.action.box:destroy()
    battlemage.action = nil
  end
end

function battlemage.onFrame()
  local player = windower.ffxi.get_mob_by_target('me')
  local info = windower.ffxi.get_player()
  if not player then return end
  
  local info = windower.ffxi.get_player()
  local combat = info.in_combat
  
  if battlemage.action and (not combat) then
    battlemage.act()
  end
end

function battlemage.onAction(act)
  if not battlemage.action then return false end
  
  local player = windower.ffxi.get_mob_by_target('me')
  local target = windower.ffxi.get_mob_by_target('t')
  if (not player) then return false end
  
  -- After a melee attack, range attack, tp move, or weaponskill we start casting
  -- Only if the actor that made that action is the one we are currently targeting (in melee combat this should almost always be the case)
  if act.actor_id  == target.id and (act.category == 01 or act.category == 02 or act.category == 03 or act.category == 11) then
    battlemage.act()
  end
  return false
end

function battlemage.act()
  util.exec(battlemage.action.type .. ' ' .. battlemage.action.action .. ' ' .. battlemage.action.target)
  battlemage.action.text:destroy()
  battlemage.action.box:destroy()
  battlemage.action = nil
end


local wsets = windower.get_windower_settings()
local win = vec2.create(wsets.x_res, wsets.y_res)
local off = vec2.create(208 + 16 + 16, 55)
local size = vec2.create(208, 16)
local padding = vec2.create(9, 1)

function battlemage.newText(txt)
  local t = texts.new({flags = {draggable = false}})
  t:text(txt)
  t:font('Consolas')
  t:color(255, 255, 255)
  t:alpha(255)
    
  t:pos(((win.x - off.x) - size.x) + padding.x, off.y - padding.y)
  t:visible(true)
  
  t:stroke_width(1)
  t:stroke_color(0, 0, 0)
  t:stroke_alpha(175)
  
  t:bg_color(0, 0, 0)
  t:bg_alpha(0, 0, 0)
  t:bg_visible(false)
  
  return t
end

function battlemage.newBox()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\bar-3.png')
  i:color(255, 255, 255)
  i:alpha(255)
  i:pos((win.x - off.x) - size.x, off.y)
  i:size(size.x, size.y)
  i:draggable(false)
  i:visible(true)
  
  return i
end

return battlemage