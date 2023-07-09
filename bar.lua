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
      bar.clear()
      return true
    end
    
    bar.clear()
    bar.setup()
    
    return true
  end
  return false
end

-- nuke it
function bar.clear()
  for i,b in ipairs(bar.list) do
    b.name:destroy()
    b.tp.fill:destroy()
    b.tp.edge:destroy()
    b.tp.num:destroy()
    b.tp.prog:destroy()
    if b.mp then
      b.mp.fill:destroy()
      b.mp.edge:destroy()
      b.mp.num:destroy()
      b.mp.prog:destroy()
    end
    b.hp.fill:destroy()
    b.hp.edge:destroy()
    b.hp.num:destroy()
    b.hp.prog:destroy()
    for j,buf in ipairs(b.buffs) do
      buf.icon:destroy()
    end
  end
  bar.list = {}
  return true
end

-- creates health bars based on current party info
function bar.setup()
  -- check if the current bar.list matches the party -- add some code to chaeck for mana and regen
  local party = util.getParty()
  local regen = false
  for i,p in ipairs(party) do
    if not bar.list[i] or not (string.lower(bar.list[i].player) == string.lower(p.name)) then
      regen = true
    end
  end
  
  -- if regen is marked true we rebuild the whole bar list based on party info
  if not regen then return end
  bar.clear()
  
  for i,p in ipairs(party) do
    local h = 2
    local b = {}
    b.id = i
    b.player = p.name
    b.name = bar.newTextName(p.name, i, 2)
    
    b.hp = {}
    b.hp.fill = bar.newBoxFill(b.id, h)
    b.hp.edge = bar.newBoxEdge(b.id, h)
    b.hp.num = bar.newTextNum(b.id, h)
    b.hp.prog = bar.newBoxProg(b.id, h, chp)
    
    if p.mp > 1 then
      h = h - 1
      b.mp = {}
      b.mp.fill = bar.newBoxFill(b.id, h)
      b.mp.edge = bar.newBoxEdge(b.id, h)
      b.mp.num = bar.newTextNum(b.id, h)
      b.mp.prog = bar.newBoxProg(b.id, h, cmp)
    end
    
    h = h - 1
    b.tp = {}
    b.tp.fill = bar.newBoxFill(b.id, h)
    b.tp.edge = bar.newBoxEdge(b.id, h)
    b.tp.num = bar.newTextNum(b.id, h)
    b.tp.prog = bar.newBoxProg(b.id, h, ctp)
    
    b.buffs = {}
    
    bar.list[#bar.list+1] = b
  end
end

function bar.onFrame()
  local player = windower.ffxi.get_mob_by_target('me')
  
  if not player then return end
  if #bar.list < 1 then return end
  
  if bar.timer > 0 then
    bar.timer = bar.timer - 1
    return
  else
    bar.timer = 30
  end
  
  bar.setup() -- if we need to regen the party list this will do it
  
  -- Update local players buffs
  bar.bupdate(1, windower.ffxi.get_player().buffs)

end

local wsets = windower.get_windower_settings()
local win = vec2.create(wsets.x_res, wsets.y_res)
local base = vec2.create(-25, 190)        -- so it turns out that we start at id 1 so we have 1 full bar of padding on the left
local size = vec2.create(208, 16)
local margin = vec2.create(50, 2)
local font = 11
local padding = vec2.create(10, 1)
local progOff = 8
local numPad = 3
local bsize = vec2.create(18,18)

function bar.bupdate(index, data)
  if not bar.list[index] or #data == #bar.list[index].buffs then
    return   -- temp hacky, need to actually sort ids low to high then compare
  end
  
  for i,bu in ipairs(bar.list[index].buffs) do
    bu.icon:destroy()
  end
  bar.list[index].buffs = {}
  
  for j,bid in ipairs(data) do
    local bo = {}
    bo.id = bid
    bo.icon = bar.newBoxBuff(bid, bar.list[index].id)
    
    local off = vec2.add(base, vec2.create(((size.x + margin.x) * bar.list[index].id) + (bsize.x * (j-1)), ((size.y + margin.y) * 2) + bsize.y))
    bo.icon:pos(off.x, win.y - off.y)
    bar.list[index].buffs[#bar.list[index].buffs+1] = bo
  end
end

function bar.inPacket(id, original)
  -- Party buff lists
  if id == 118 then
    local pak = packets.parse('incoming', original)    
    local pt = {}
    
    -- collect buff data
    for  k = 0, 4 do
      local b = {}
      b.id = pak['ID ' .. (k+1)]
      b.index = pak['Index ' .. (k+1)]
      b.buffs = {}
      
      if not (b.id == 0 and b.index == 0) then
        for i = 1, 32 do
          local buff = original:byte(k*48+5+16+i-1) + 256*( math.floor( original:byte(k*48+5+8+ math.floor((i-1)/4)) / 4^((i-1)%4) )%4) -- Credit: Byrth, GearSwap
          if buff == 255 then break end -- not exactly correct but ehhhh fuck it why not
          
          b.buffs[i] = buff
        end
      end
      
      pt[k+1] = b
    end

    for i,pb in ipairs(pt) do
      local party = util.getParty()
      
      for j,ply in ipairs(party) do
      -- fix this for the love of god. we are just assuming they are in the same order  
        --if ply.mob then print(ply.mob.id .. ' and ' .. pb.id) end
        --if ply.mob and pb.id == ply.mob.id then
          --print('calling bupdate')
          


        --end
        
        if ply.mob and ply.mob.id == pb.id then  -- probably correct??
          bar.bupdate(i+1, pb.buffs)
        end
      end
      --bar.bupdate(i+1, pb.buffs)
    end
   
  end
  
  -- Party member update
  if id == 228 then
    local pak = packets.parse('incoming', original)
    print( pak.ID .. ' is a ' .. pak['Main Job'] .. '/' .. pak['Sub Job'])
  end
end

function bar.draw()
  local party = windower.ffxi.get_party()
  local tgt = windower.ffxi.get_mob_by_target('t')
  local stgt = windower.ffxi.get_mob_by_target('st')
  local me = util.getMe()
    
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
    if not (player and player.zone == me.zone) then
      visibleBar(b.hp, false)
      visibleBar(b.mp, false)
      visibleBar(b.tp, false)
      b.name:visible(false)
      for j,buf in ipairs(b.buffs) do
        buf.icon:visible(false)
      end
    else
      visibleBar(b.hp, true)
      visibleBar(b.mp, true)
      visibleBar(b.tp, true)
      b.name:visible(true)
      for j,buf in ipairs(b.buffs) do
        buf.icon:visible(true)
      end
    
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
    end
  end
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