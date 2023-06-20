local macro = {
  _VERSION = 'Macro 1.0',
  _DESCRIPTION = 'Allows you to add clickable buttons for macros to the interface. Use aliases!',
}

require('strings')
require('tables')

local texts = require('texts')
local images = require('images')
local res = require('resources')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

macro.list = {}

local blue = {r = 52, g = 50, b = 122}
local orange = {r = 237, g = 179, b = 6}
local white = {r = 255, g = 255, b = 255}

function macro.onCommand(cmd)
  if cmd[1] == 'macro' then
    if cmd[2] == 'clear' then
      for i,b in ipairs(macro.list) do
        b.fill:destroy()
        b.edge:destroy()
        b.text:destroy()
      end
      macro.list = {}
      return true
    end
    
    local btn = {}
    btn.id = tonumber(cmd[2]) - 1
    btn.fill = macro.newBoxFill(btn.id)
    btn.edge = macro.newBoxEdge(btn.id)
    btn.text = macro.newText(cmd[3], btn.id)
    btn.alias = cmd[4]
    
    macro.list[#macro.list+1] = btn
    
    return true
  end
  return false
end

windower.register_event('mouse', function(type, x, y, delta, blocked)
  for i,btn in ipairs(macro.list) do
    if btn.fill:hover(x, y) then
      if type == 1 then
        btn.fill:color(white.r, white.g, white.b)
        return true
      elseif type == 2 then
        btn.fill:color(orange.r, orange.g, orange.b)
        util.exec(btn.alias)
        return true
      else
        btn.fill:color(orange.r, orange.g, orange.b)
      end
    else
      btn.fill:color(blue.r, blue.g, blue.b)
    end
  end
end)

function macro.draw()

end

local wsets = windower.get_windower_settings()
local win = vec2.create(wsets.x_res, wsets.y_res)
local base = vec2.create(16, 175)
local size = vec2.create(120, 16)
local margin = 2
local font = 11
local padding = vec2.create(10, 1)

function macro.newText(txt, id)
  local off = vec2.add(base, vec2.create(((id%2)+1)*(size.x+margin), math.floor((id/2))*(size.y+margin)))

  local t = texts.new({flags = {draggable = false}})
  t:text(txt)
  t:font('Consolas')
  t:color(255, 255, 255)
  t:alpha(255)
  
  t:pos((win.x - off.x) + padding.x, (win.y - off.y) - padding.y)
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

function macro.newBoxEdge(id)
  local off = vec2.add(base, vec2.create(((id%2)+1)*(size.x+margin), math.floor((id/2))*(size.y+margin)))

  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\btn-edge-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  
  i:pos(win.x - off.x, win.y - off.y)
  i:size(size.x, size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function macro.newBoxFill(id)
  local off = vec2.add(base, vec2.create(((id%2)+1)*(size.x+margin), math.floor((id/2))*(size.y+margin)))

  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\btn-fill-1.png')
  i:color(blue.r, blue.g, blue.b)
  i:alpha(255)
  
  i:pos(win.x - off.x, win.y - off.y)
  i:size(size.x, size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

return macro