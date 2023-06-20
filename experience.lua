local experience = {
  _VERSION = 'Experience 1.0',
  _DESCRIPTION = 'Shows your current EXP',
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

local packets = require('packets')

experience.bar = nil
experience.timer = 0
experience.update = false

function experience.onCommand(cmd)
  if cmd[1] == 'exp' then
    if cmd[2] == 'clear' and not (experience.bar == nil) then
      experience.bar.fill:destroy()
      experience.bar.edge:destroy()
      experience.bar.text:destroy()
      experience.bar.prog:destroy()
      experience.bar = {}
      return true
    end
    
    local cmds = ''
    for i=2, #cmd do
      cmds = cmds .. cmd[i] .. ' '
    end
    cmds = util.trim(cmds)
    
    local id = tonumber(cmd[2])
    local bar = {}
    bar.id = id
        
    bar.fill = experience.newBoxFill()
    bar.edge = experience.newBoxEdge()
    bar.text = experience.newText('...')
    bar.prog = experience.newBoxProg()
    bar.timer = experience.newTextTime()
    bar.xp = 0
    bar.xpt = 0
    bar.xpp = 0
    
    experience.bar = bar
    return true
  end
  return false
end

-- Get xp. borrowed some from barfiller on github. https://github.com/Windower/Lua/blob/live/addons/barfiller/barfiller.lua 
windower.register_event('incoming chunk',function(id,org,modi,is_injected,is_blocked)
    if is_injected then return end
    if experience.bar == nil then return end
    
    local packet_table = packets.parse('incoming', org)
    --if id == 0x2D then
      --log(packet_table['Param 1'] .. packet_table['Message'])
    if id == 0x61 then
        experience.bar.xp = packet_table['Current EXP']
        experience.bar.xpt = packet_table['Required EXP']
        experience.bar.xpp = experience.bar.xp / experience.bar.xpt
        experience.update = true
    end
end)

-- Guh
function experience.onFrame()
  if not experience.update then return end
  
  
end

-- @TODO: Could optimize the drawing a bit here. Lots of positionish stuff that could be set at init
function experience.draw()
  if experience.bar == nil then return end
  
  local wsets = windower.get_windower_settings()
  local win = vec2.create(wsets.x_res, wsets.y_res)
  local offBase = vec2.create(16, 365)
  local size = vec2.create(182, 16)
  local margin = 2
  local font = 11
  local padding = vec2.create(10, 1)
  local progOff = 8
    
  local off = vec2.add(offBase, vec2.create(0, experience.bar.id * (size.y + margin)))
          
  experience.bar.fill:color(155, 155, 155)
  experience.bar.edge:path(windower.windower_path .. 'addons\\Antisocial\\img\\track-edge-2.png')
  experience.bar.text:alpha(200)
  experience.bar.text:stroke_alpha(120)
  experience.bar.prog:pos(off.x + 8, win.y - off.y)
  experience.bar.prog:size((size.x - (progOff * 2)) * experience.bar.xpp, size.y)
  experience.bar.prog:color(255, 166, 50)
  experience.bar.prog:update()
  experience.bar.prog:visible(true)
 
  
  experience.bar.fill:pos(off.x, win.y - off.y)
  experience.bar.fill:size(size.x, size.y)
  experience.bar.fill:update()
  experience.bar.fill:visible(true)
  
  experience.bar.edge:pos(off.x, win.y - off.y)
  experience.bar.edge:size(size.x, size.y)
  experience.bar.edge:update()
  experience.bar.edge:visible(true)
  
  experience.bar.text:text(experience.bar.xp .. ' / ' .. experience.bar.xpt)
  experience.bar.text:pos(off.x + padding.x, (win.y - off.y) - padding.y)
  experience.bar.text:size(font)
  experience.bar.text:visible(true)
end

function experience.newText(txt)
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

function experience.newTextTime()
  local t = texts.new({flags = {draggable = false}})
  t:text('0')
  t:font('Consolas')
  t:color(200, 200, 200)
  t:alpha(150)
  t:visible(false)
  
  t:stroke_width(1)
  t:stroke_color(0, 0, 0)
  t:stroke_alpha(75)
  
  t:bg_color(0, 0, 0)
  t:bg_alpha(0, 0, 0)
  t:bg_visible(false)
  
  return t
end

function experience.newBoxEdge()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\track-edge-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  i:draggable(false)
  i:visible(false)

  return i
end

function experience.newBoxFill()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\track-fill-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  i:draggable(false)
  i:visible(false)

  return i
end

function experience.newBoxProg()
  local i = images.new()
  i:clear()
  i:color(115, 115, 115)
  i:alpha(155)
  i:draggable(false)
  i:visible(false)

  return i
end

return experience