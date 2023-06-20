local track = {
  _VERSION = 'Track 1.0',
  _DESCRIPTION = 'Track and display cooldowns of abilities for all party members',
}

-- Note: The ability name for your 2hour ability is always "SP Ability". This is because they all share a cooldown 
-- Note: For scholars just put "Stratagem" for all the stratagems

require('strings')
require('tables')

local inspect = require('inspect')
local texts = require('texts')
local images = require('images')
local res = require('resources')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

track.list = {}

track.last = nil
track.timer = 0

function track.onCommand(cmd)
  if cmd[1] == 'track' then
    if cmd[2] == 'clear' then
      for i,trk in ipairs(track.list) do
        trk.fill:destroy()
        trk.edge:destroy()
        trk.text:destroy()
        trk.prog:destroy()
        trk.timer:destroy()
      end
      track.list = {}
      return true
    end
    
    local cmds = ''
    for i=6, #cmd do
      cmds = cmds .. cmd[i] .. ' '
    end
    cmds = util.trim(cmds)
    
    local id = tonumber(cmd[3])
    local trk = {}
    trk.id = id
    trk.player = cmd[2]
    trk.color = util.color(cmd[4])
    trk.action = cmds
    trk.name = cmd[5]
    trk.time = 0
    trk.length = 1   -- Placeholder, set to actaul cooldown length when we recieve a trackdata
        
    trk.fill = track.newBoxFill()
    trk.edge = track.newBoxEdge()
    trk.text = track.newText(trk.name)
    trk.prog = track.newBoxProg()
    trk.timer = track.newTextTime()
    
    track.list[#track.list+1] = trk
    return true
  
  elseif cmd[1] == 'trackdata' then
    local cmds = ''
    for i=4, #cmd do
      cmds = cmds .. cmd[i] .. ' '
    end
    cmds = util.trim(cmds)
    
    for i,trk in pairs(track.list) do
      if(string.lower(trk.player) == string.lower(cmd[2]) and string.lower(trk.action) == string.lower(cmds)) then
        trk.start = os.clock()
        trk.time = tonumber(cmd[3])
        trk.length = trk.time
        return true
      end
    end
    
    return true
  end
  return false
end

-- Tracking cooldowns via events does not work for various stupid reasons so we do it this way instead
function track.onFrame()
  if track.timer > 0 then
    track.timer = track.timer - 1
    return
  end
  track.timer = 30
  
  for i,trk in ipairs(track.list) do
    if trk.time > 0 then
      trk.time = math.max(0, (trk.length + trk.start) -  os.clock())
    end
  end
  
  local player = windower.ffxi.get_player()
  if not player then return end
  
  local recasts = windower.ffxi.get_ability_recasts()
  
  if not track.last then
    track.last = recasts
    return
  end
  
  for i,re in pairs(track.last) do
    if recasts[i] == nil or re == nil then
    elseif recasts[i] > re then
      local abls = res.ability_recasts[i]
      util.send('all', 'asp trackdata ' .. player.name .. ' ' .. recasts[i] .. ' ' .. abls.en)
    end
  end
  
  track.last = recasts
end

-- @TODO: Could optimize the drawing a bit here. Lots of positionish stuff that could be set at init
function track.draw()
  if #track.list < 1 then return end
  
  local wsets = windower.get_windower_settings()
  local win = vec2.create(wsets.x_res, wsets.y_res)
  local offBase = vec2.create(16, 365)
  local size = vec2.create(182, 16)
  local margin = 2
  local font = 11
  local padding = vec2.create(10, 1)
  local progOff = 8
    
  for i,trk in ipairs(track.list) do
    local off = vec2.add(offBase, vec2.create(0, trk.id * (size.y + margin)))
    
    if trk.time > 0 then
      local sc = (trk.time / trk.length)
          
      trk.fill:color(155, 155, 155)
      trk.edge:path(windower.windower_path .. 'addons\\Antisocial\\img\\track-edge-2.png')
      trk.text:alpha(155)
      trk.text:stroke_alpha(75)
      trk.prog:pos(off.x + 8, win.y - off.y)
      trk.prog:size((size.x - (progOff * 2)) * sc, size.y)
      trk.prog:update()
      trk.prog:visible(true)
      trk.timer:text(math.floor(trk.time) .. '')
      trk.timer:pos(off.x + size.x + 3, (win.y - off.y) - padding.y)
      trk.timer:size(font)
      trk.timer:visible(true)
    else
      trk.fill:color(trk.color.r, trk.color.g, trk.color.b)
      trk.edge:path(windower.windower_path .. 'addons\\Antisocial\\img\\track-edge-1.png')
      trk.text:alpha(255)
      trk.text:stroke_alpha(150)
      trk.prog:visible(false)
      trk.timer:visible(false)
    end
    
    -- Stratagem Hack
    if trk.action == 'Stratagems' then
      local playerinfo = windower.ffxi.get_player()
      local schlvl
      local charges = 0
      local recharge = 0
      if playerinfo.main_job == "SCH" then
        schlvl = playerinfo.main_job_level
      else
        schlvl = playerinfo.sub_job_level
      end
      
      if schlvl >= 99 then
        charges = 5
        recharge = 48
      elseif schlvl >= 70 then
        charges = 4
        recharge = 60
      elseif schlvl >= 50 then
        charges = 3
        recharge = 80
      elseif schlvl >= 30 then
        charges = 2
        recharge = 120
      elseif schlvl >= 10 then
        charges = 1
        recharge = 240
      end

      local current = charges - math.ceil(trk.time/recharge) - 1
      local gna = trk.name .. ' '
      for i=0,current do
        gna = gna .. '+'
      end
      trk.text:text(gna)
    end
    
    trk.fill:pos(off.x, win.y - off.y)
    trk.fill:size(size.x, size.y)
    trk.fill:update()
    trk.fill:visible(true)
    
    trk.edge:pos(off.x, win.y - off.y)
    trk.edge:size(size.x, size.y)
    trk.edge:update()
    trk.edge:visible(true)
    
    trk.text:pos(off.x + padding.x, (win.y - off.y) - padding.y)
    trk.text:size(font)
    trk.text:visible(true)
  end
end

function track.newText(txt)
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

function track.newTextTime()
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

function track.newBoxEdge()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\track-edge-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  i:draggable(false)
  i:visible(false)

  return i
end

function track.newBoxFill()
  local i = images.new()
  i:clear()
  i:path(windower.windower_path .. 'addons\\Antisocial\\img\\track-fill-1.png')
  i:color(255, 255, 255)
  i:alpha(255)
  i:draggable(false)
  i:visible(false)

  return i
end

function track.newBoxProg()
  local i = images.new()
  i:clear()
  i:color(115, 115, 115)
  i:alpha(155)
  i:draggable(false)
  i:visible(false)

  return i
end

return track