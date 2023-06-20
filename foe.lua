local foe = {
  _VERSION = 'Foe 1.0',
  _DESCRIPTION = 'Health bars for enemies.',
}

require('strings')
require('tables')

local texts = require('texts')
local images = require('images')
local res = require('resources')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

foe.list = {}

local chp = {r = 255, g = 155, b = 155}

function foe.onCommand(cmd)
  if cmd[1] == 'foe' then
    if cmd[2] == 'clear' then
      for i,f in ipairs(foe.list) do
        f.name:destroy()
        f.fill:destroy()
        f.edge:destroy()
        f.prog:destroy()
      end
      foe.list = {}
      return true
    end
    
    local tgt = windower.ffxi.get_mob_by_target('t')
    if not tgt then return true end
    
    for i,f in ipairs(foe.list) do
      if f.id == tgt.id then
        return true
      end
    end
    
    local f = {}
    f.id = tgt.id
    f.fade = 60
    f.name = foe.newTextName(tgt.name)
    f.fill = foe.newBoxFill()
    f.edge = foe.newBoxEdge()
    f.prog = foe.newBoxProg()
    
    foe.list[#foe.list+1] = f
    foe.draw()                   -- Being a little lazy here, most of these are intialized in the wrong place so I just call draw() to fix it after adding them
    return true
  end
  return false
end

local wsets = windower.get_windower_settings()
local win = vec2.create(wsets.x_res, wsets.y_res)
local base = vec2.create(16, 75)
local size = vec2.create(400, 24)
local margin = vec2.create(50, 2)
local font = 16
local padding = vec2.create(18, 1)
local progOff = 12
local numPad = 3

function foe.draw()
  -- Removal pass
  local player = windower.ffxi.get_mob_by_target("me")
  
  local rp = {}
  for i,f in ipairs(foe.list) do
    local target = windower.ffxi.get_mob_by_id(f.id)
    
    if not target or not player or target.hpp <= 0 or vec2.distance(vec2.create(player.x, player.y), vec2.create(target.x, target.y)) > 50 then
      if f.fade > 0 then
        f.fade = f.fade - 1
      end
    else
      f.fade = 60
    end
  
    if f.fade > 0 then
      rp[#rp+1] = f
    else
      f.name:destroy()
      f.fill:destroy()
      f.edge:destroy()
      f.prog:destroy()
    end
  end
  foe.list = rp

  -- Draw pass
  local v = 0
  for i,f in ipairs(foe.list) do
    if f then
      local tgt = windower.ffxi.get_mob_by_id(f.id)
      if not tgt then
        tgt = {}
        tgt.hpp = 0
      end
      
      local hps = (tgt.hpp / 100)
      local fds = (f.fade / 60)
      
      local off = vec2.add(base, vec2.create(size.x + margin.x, (size.y + margin.y) * v))
      f.name:pos(win.x - off.x + padding.x, off.y - padding.y)
      f.fill:pos(win.x - off.x, off.y)
      f.edge:pos(win.x - off.x, off.y)
      f.prog:pos(win.x - off.x + progOff, off.y)
      f.prog:size((size.x - (progOff * 2))*hps, size.y)
      
      f.name:alpha(255 * fds)
      f.name:stroke_alpha(175 * fds)
      f.fill:alpha(255 * fds)
      f.edge:alpha(255 * fds)
      f.prog:alpha(125 * fds)
      
      v = v + 1
    end
  end
end

function foe.newTextName(txt)
  local off = vec2.add(base, vec2.create(size.x + margin.x, margin.y))

  local t = texts.new({flags = {draggable = false}})
  t:text(txt)
  t:font('Consolas')
  t:color(255, 255, 255)
  t:alpha(255)
  
  t:pos(win.x - off.x + padding.x, off.y - padding.y)
  t:size(font)
  
  t:stroke_width(1)
  t:stroke_color(0, 0, 0)
  t:stroke_alpha(175)
  
  t:bg_color(0, 0, 0)
  t:bg_alpha(0, 0, 0)
  t:bg_visible(false)
  t:visible(true)
  
  return t
end

function foe.newBoxFill()
  local off = vec2.add(base, vec2.create(size.x + margin.x, margin.y))

  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\foe-fill-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  
  i:pos(win.x - off.x, off.y)
  i:size(size.x, size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function foe.newBoxEdge()
  local off = vec2.add(base, vec2.create(size.x + margin.x, margin.y))

  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\foe-edge-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  
  i:pos(win.x - off.x, off.y)
  i:size(size.x, size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function foe.newBoxProg()
  local off = vec2.add(base, vec2.create(size.x + margin.x + progOff, margin.y))

  local i = images.new()
  i:clear()
  i:color(chp.r, chp.g, chp.b)
  i:alpha(125)
  
  i:pos(win.x - off.x, off.y)
  i:size(size.x - (progOff * 2), size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

return foe