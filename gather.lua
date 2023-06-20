local gather = {
  _VERSION = 'Gather 1.0',
  _DESCRIPTION = 'Notifies you when gather points are nearby',
}

require('strings')
require('tables')

local inspect = require('inspect')
local texts = require('texts')
local images = require('images')
local res = require('resources')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

gather.list = {}
gather.enabled = false
gather.low = 0
gather.high = 0
gather.timer = 0
gather.text = nil

function gather.onCommand(cmd)
  if cmd[1] == 'gather' then
    if cmd[2] == 'off' then
      for i,gth in ipairs(gather.list) do
        gth.text:destroy()
      end
      gather.list = {}
      gather.enabled = false
      return true
    end
   
    --local mobs = windower.ffxi.get_mob_array()
    --for i,mob in ipairs(mobs) do
    --  log(mob.name)
    --end
    --log(inspect(windower.ffxi.get_mob_by_index(118)))
    --log(inspect(windower.ffxi.get_mob_by_target('<t>')))
    
    local cmds = ''
    for i=3, #cmd do
      cmds = cmds .. cmd[i] .. ' '
    end
    cmds = util.trim(cmds)
    
    gather.low = tonumber(cmd[2])
    gather.high = tonumber(cmd[3])
    
    gather.text = gather.newText('...')
      
    gather.enabled = true
    
    return true
  end
  return false
end

-- Guh
function gather.onFrame()
  if not gather.enabled then return end
  
  if gather.timer > 0 then
    gather.timer = gather.timer - 1
    return
  end
  gather.timer = 30
  
  gather.list = {}
  
  local player = windower.ffxi.get_mob_by_target('me')
  if not player then return end
  
  local ply = vec2.create(player.x, player.y)
  
  for i=gather.low,gather.high do
    local mob = windower.ffxi.get_mob_by_index(i)
    if not(mob == nil) and mob.name == 'Mining Point' and mob.valid_target then
      local pnt = {}
      pnt.index = mob.index
      pnt.position = vec2.create(mob.x, mob.y)
      pnt.distance = vec2.distance(ply, pnt.position)
      
      local u = pnt.position.x - ply.x
      local v = pnt.position.y - ply.y
      local a = '...'
      local b = '...'
      if u > 0 then a = 'east' else a = 'west' end
      if v > 0 then b = 'north' else b = 'south' end
      local combo = '...'
      
      if math.abs(u) < 10 then
        combo = b
      elseif math.abs(v) < 10 then
        combo = a
      else
        combo = b .. a
      end
      
      if pnt.distance < 10 then combo = 'here' end
      
      pnt.cardinal = combo
      
      if pnt.distance < 300 then
        gather.list[#gather.list+1] = pnt
      end
    end
  end
end

-- @TODO: Could optimize the drawing a bit here. Lots of positionish stuff that could be set at init
function gather.draw()
  if not gather.enabled then return end
  
  local wsets = windower.get_windower_settings()
  local wsets = windower.get_windower_settings()
  local win = vec2.create(wsets.x_res, wsets.y_res)
  
  local txt = ''
  for i,pnt in ipairs(gather.list) do
    txt = string.format("%.3f", pnt.distance) .. ' ' .. pnt.cardinal .. '\n' .. txt
  end
  
  gather.text:text(txt)
  gather.text:alpha(255)
  gather.text:stroke_alpha(150)
  gather.text:pos(win.x - 300, 125)
  gather.text:size(24)
  gather.text:visible(true)
end

function gather.newText(txt)
  local t = texts.new({flags = {draggable = false}})
  t:text(txt)
  t:font('Consolas')
  t:color(255, 255, 255)
  t:alpha(255)
  t:visible(false)
  
  t:stroke_width(1)
  t:stroke_color(0, 0, 0)
  t:stroke_alpha(175)
  
  t:bg_color(0, 0, 0)
  t:bg_alpha(0, 0, 0)
  t:bg_visible(false)
  
  return t
end

return gather