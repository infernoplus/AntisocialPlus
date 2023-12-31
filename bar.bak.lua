local bar = {
  _VERSION = 'Bar 1.0',
  _DESCRIPTION = 'Health/Mana/TP bars for you and *optionlly* for other players in your party.',
}

require('strings')
require('tables')

local texts = require('texts')
local images = require('images')
local res = require('resources')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

bar.list = {}

bar.bupdate = false
bar.lbids = {}  -- Local buff ids
bar.timer = 0

local chp = {r = 255, g = 155, b = 155}
local cmp = {r = 206, g = 234, b = 151}
local ctp = {r = 255, g = 191, b = 152}
local ctpnum = {r = 91, g = 135, b = 252}

local chp75 = {r = 238, g = 239, b = 119}
local chp50 = {r = 247, g = 186, b = 116}
local chp25 = {r = 233, g = 119, b = 119}

function bar.onCommand(cmd)
  if cmd[1] == 'bar' then
    if cmd[2] == 'clear' then
      for i,b in ipairs(bar.list) do
        b.name:destroy()
        b.tp.fill:destroy()
        b.tp.edge:destroy()
        b.tp.num:destroy()
        b.tp.prog:destroy()
        b.mp.fill:destroy()
        b.mp.edge:destroy()
        b.mp.num:destroy()
        b.mp.prog:destroy()
        b.hp.fill:destroy()
        b.hp.edge:destroy()
        b.hp.num:destroy()
        b.hp.prog:destroy()
      end
      bar.list = {}
      return true
    end
    
    local b = {}
    b.id = tonumber(cmd[3]) - 1
    b.player = cmd[2]
    b.name = bar.newTextName(b.player, b.id, 2)
    
    local i = 2
    local j = 4
    local nxt = cmd[j]
    while nxt and i >= 0 do
      if nxt == 'tp' then
        b.tp = {}
        b.tp.fill = bar.newBoxFill(b.id, i)
        b.tp.edge = bar.newBoxEdge(b.id, i)
        b.tp.num = bar.newTextNum(b.id, i)
        b.tp.prog = bar.newBoxProg(b.id, i, ctp)
      elseif nxt == 'mp' then
        b.mp = {}
        b.mp.fill = bar.newBoxFill(b.id, i)
        b.mp.edge = bar.newBoxEdge(b.id, i)
        b.mp.num = bar.newTextNum(b.id, i)
        b.mp.prog = bar.newBoxProg(b.id, i, cmp)
      else
        b.hp = {}
        b.hp.fill = bar.newBoxFill(b.id, i)
        b.hp.edge = bar.newBoxEdge(b.id, i)
        b.hp.num = bar.newTextNum(b.id, i)
        b.hp.prog = bar.newBoxProg(b.id, i, chp)
      end
      j = j + 1
      i = i - 1
      nxt = cmd[j]
    end
    
    b.buff = {}
    b.buff.ids = {}
    b.buff.list = {}
    
    bar.list[#bar.list+1] = b
    return true
  elseif cmd[1] == 'bupdate' then
    local bfs = {}
    for i=3, #cmd do
      bfs[i-2] = tonumber(cmd[i])
    end
    
    for i,b in ipairs(bar.list) do
      if string.lower(b.player) == string.lower(cmd[2]) then
        b.buff.ids = bfs
        bar.bupdate = true
      end
    end
    return true
  end
  return false
end

function bar.onFrame()
  local player = windower.ffxi.get_mob_by_target('me')
  
  if not player then return end
  
  if bar.timer > 0 then
    bar.timer = bar.timer - 1
    return
  else
    bar.timer = 30
  end
  
  local bfs = windower.ffxi.get_player().buffs
  if #bfs == #bar.lbids then
    return
  end
  
  local bufcat = ''
  for i,b in ipairs(bfs) do
    bufcat = bufcat .. b .. ' '
  end
  util.send('all', 'asp bupdate ' .. player.name .. ' ' .. util.trim(bufcat))
  
  bar.lbids = bfs
end

local wsets = windower.get_windower_settings()
local win = vec2.create(wsets.x_res, wsets.y_res)
local base = vec2.create(215, 190)
local size = vec2.create(208, 16)
local margin = vec2.create(50, 2)
local font = 11
local padding = vec2.create(10, 1)
local progOff = 8
local numPad = 3
local bsize = vec2.create(18,18)

function bar.draw()
  local party = windower.ffxi.get_party()
  local tgt = windower.ffxi.get_mob_by_target('t')
  local stgt = windower.ffxi.get_mob_by_target('st')
    
  local visibleBar = function(bp, bool)
    if bp then
      bp.fill:visible(bool)
      bp.edge:visible(bool)
      bp.prog:visible(bool)
      bp.num:visible(bool)
    end
  end
  
  bar.target:visible(false)
  bar.subtarget:visible(false)
    
  for i,b in ipairs(bar.list) do
    local player = util.getPlayer(b.player)
    if not player then
      visibleBar(b.hp, false)
      visibleBar(b.mp, false)
      visibleBar(b.tp, false)
      b.name:visible(false)
    else
      visibleBar(b.hp, true)
      visibleBar(b.mp, true)
      visibleBar(b.tp, true)
      b.name:visible(true)
    
      local hps = (player.hpp / 100)
      local mps = (player.mpp / 100)
      local tps = (player.tp / 3000)
      
      local hp = player.hp
      local mp = player.mp
      local tp = player.tp
           
      if b.hp then
        b.hp.prog:size((size.x - (progOff * 2))*hps, size.y)
        b.hp.num:text(hp .. '')
        
        if hps < 0.25 then
          b.hp.num:color(chp25.r, chp25.g, chp25.b)
          b.hp.num:alpha(255)
          b.hp.num:stroke_alpha(155)
        elseif hps < 0.5 then
          b.hp.num:color(chp50.r, chp50.g, chp50.b)
          b.hp.num:alpha(255)
          b.hp.num:stroke_alpha(155)
        elseif hps < 0.75 then
          b.hp.num:color(chp75.r, chp75.g, chp75.b)
          b.hp.num:alpha(255)
          b.hp.num:stroke_alpha(155)
        else
          b.hp.num:color(255, 255, 255)
          b.hp.num:alpha(175)
          b.hp.num:stroke_alpha(100)
        end
        
        if tgt and string.lower(tgt.name) == string.lower(b.player) then
          local off = vec2.add(base, vec2.create(((size.x + margin.x) * b.id) + progOff, (size.y + margin.y) * 2))
          bar.target:pos(off.x + (size.x * 0.5) - 11, (win.y - off.y) - 40 - bsize.y)
          bar.target:visible(true)
        end
        
        if stgt and string.lower(stgt.name) == string.lower(b.player) then
          local off = vec2.add(base, vec2.create(((size.x + margin.x) * b.id) + progOff, (size.y + margin.y) * 2))
          bar.subtarget:pos(off.x + (size.x * 0.5) - 11, (win.y - off.y) - 40 - bsize.y)
          bar.subtarget:visible(true)
        end
      end
      
      if b.mp then 
        b.mp.prog:size((size.x - (progOff * 2))*mps, size.y)
        b.mp.num:text(mp .. '')
      end
      
      if b.tp then 
        b.tp.prog:size((size.x - (progOff * 2))*tps, size.y)
        b.tp.num:text(tp .. '')
        if tp >= 1000 then
          b.tp.num:color(ctpnum.r, ctpnum.g, ctpnum.b)
          b.tp.num:alpha(255)
          b.tp.num:stroke_alpha(155)
        else
          b.tp.num:color(255, 255, 255)
          b.tp.num:alpha(175)
          b.tp.num:stroke_alpha(100)
        end
      end
      
      if bar.bupdate then
        for j,bu in ipairs(b.buff.list) do
          bu.icon:destroy()
        end
        b.buff.list = {}
        
        for j,bid in ipairs(b.buff.ids) do
          local bo = {}
          bo.id = bid
          bo.icon = bar.newBoxBuff(bid, b.id)
          
          local off = vec2.add(base, vec2.create(((size.x + margin.x) * b.id) + (bsize.x * (j-1)), ((size.y + margin.y) * 2) + bsize.y))
          bo.icon:pos(off.x, win.y - off.y)
          b.buff.list[#b.buff.list+1] = bo
        end
      end
    end
  end
  bar.bupdate = false
end

function bar.newTextName(txt, id, num)
  local off = vec2.add(base, vec2.create((size.x + margin.x) * id, (size.y + margin.y) * num))

  local t = texts.new({flags = {draggable = false}})
  t:text(txt)
  t:font('Consolas')
  t:color(255, 255, 255)
  t:alpha(255)
  
  t:pos(off.x + padding.x, (win.y - off.y) - padding.y)
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

function bar.newTextNum(id, num)
  local off = vec2.add(base, vec2.create((size.x + margin.x) * id, (size.y + margin.y) * num))

  local t = texts.new({flags = {draggable = false}})
  t:text('0')
  t:font('Consolas')
  t:color(255, 255, 255)
  t:alpha(175)
  
  t:pos(off.x + size.x + numPad, (win.y - off.y) - padding.y)
  t:size(font)
  
  t:stroke_width(1)
  t:stroke_color(0, 0, 0)
  t:stroke_alpha(100)
  
  t:bg_color(0, 0, 0)
  t:bg_alpha(0, 0, 0)
  t:bg_visible(false)
  t:visible(true)
  
  return t
end

function bar.newBoxFill(id, num)
  local off = vec2.add(base, vec2.create((size.x + margin.x) * id, (size.y + margin.y) * num))

  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\bar-fill-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  
  i:pos(off.x, win.y - off.y)
  i:size(size.x, size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function bar.newBoxEdge(id, num)
  local off = vec2.add(base, vec2.create((size.x + margin.x) * id, (size.y + margin.y) * num))

  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\bar-edge-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  
  i:pos(off.x, win.y - off.y)
  i:size(size.x, size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function bar.newBoxProg(id, num, color)
  local off = vec2.add(base, vec2.create(((size.x + margin.x) * id) + progOff, (size.y + margin.y) * num))

  local i = images.new()
  i:clear()
  i:color(color.r, color.g, color.b)
  i:alpha(125)
  
  i:pos(off.x, win.y - off.y)
  i:size(size.x - (progOff * 2), size.y)
  
  i:draggable(false)
  i:visible(true)

  return i
end

function bar.newBoxT()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\arrow-1.png')
  i:color(255, 255, 255)
  i:alpha(185)
  
  i:pos(0, 0)
  i:size(22, 34)
  
  i:draggable(false)
  i:visible(false)

  return i
end

function bar.newBoxST()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\arrow-2.png')
  i:color(255, 255, 255)
  i:alpha(210)
  
  i:pos(0, 0)
  i:size(20, 32)
  
  i:draggable(false)
  i:visible(false)

  return i
end

function bar.newBoxBuff(bid, id)
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\buff\\' .. bid .. '.png')
  i:color(255, 255, 255)
  i:alpha(255)
  
  i:pos(255, 255 + (id * 16))
  i:size(18, 18) -- Literally does nothing lol
  i:fit(false)
  
  i:draggable(false)
  i:visible(true)
  return i
end

bar.target = bar.newBoxT()
bar.subtarget = bar.newBoxST()

return bar