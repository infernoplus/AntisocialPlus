local talk = {
  _VERSION = 'AutoTalk 1.0',
  _DESCRIPTION = 'Attempts to replicate dialouge to all clients',
}

require('strings')
require('tables')

local texts = require('texts')
local images = require('images')
local input = require('input')
local vec2 = require('vec2')
local util = require('util')

talk.enabled = false
talk.inDialouge = false
talk.lastPacket = nil

talk.target = nil
talk.targetIndex = nil
talk.off = {}
talk.enterTimer = 10
talk.targetTimer = 0
talk.escTimer = 35

talk.box = nil
talk.text = nil

talk.border = {}

function talk.command(cmd)
  if cmd[1] == 'autotalk' then
    util.send('all', 'asp inprep reset')
    if cmd[2] == nil or cmd[2] == 'toggle' then
      talk.enabled = not talk.enabled
    elseif cmd[2] == 'on' then
      talk.enabled = true
    else 
      talk.enabled = false
    end
    
    if talk.enabled then
      log('AutoTalk Enabled')
    else
      log('AutoTalk Disabled')
    end
    return true
    
  elseif cmd[1] == 'talkorder' then
    local player = windower.ffxi.get_mob_by_target('me')
    local info = windower.ffxi.get_info()
    if string.lower(player.name) == cmd[2] or not (info.zone == tonumber(cmd[3])) then return end
    
    local tid = tonumber(cmd[4])
    local tindex = tonumber(cmd[5])
    local x = tonumber(cmd[6])
    local y = tonumber(cmd[7])
    local z = tonumber(cmd[8])
    
    local target = windower.ffxi.get_mob_by_id(tid)
    if not target then return end
        
    local tgt = vec2.create(target.x, target.y)
    local ply = vec2.create(player.x, player.y)
    local dist = vec2.distance(tgt, ply)
    
    if dist > 15 then return end
    
    talk.target = tid
    talk.targetIndex = tindex
    talk.off.x = x
    talk.off.y = y
    talk.off.z = z
    talk.enterTimer = math.floor(math.random()*10)
    talk.targetTimer = 0
    talk.escTimer = 35
    
    return true
  end
  return false
end

function talk.frame()
    input.talk = talk.inDialouge
    input.master = talk.enabled

    if talk.inDialouge then return true
    elseif not talk.target then return false end
    
    local player = windower.ffxi.get_mob_by_target('me')
    local target = windower.ffxi.get_mob_by_id(talk.target)
    
    if not target then
      talk.target = nil
      return false
    end
    
    local tgt = vec2.create(target.x, target.y)
    local ply = vec2.create(player.x, player.y)
    local dist = vec2.distance(tgt, ply)
    local dir = vec2.normalize(vec2.subtract(tgt, ply))
        
    if dist > 3.5 then 
      util.move(dir)
    elseif talk.target then
      windower.ffxi.run(false)
      
      local ang = vec2.angle(vec2.create(0,1), dir)
      if dir.x < 0 then
        ang = ang * -1
      end
      windower.ffxi.turn(ang - 1.5708)
      
      if not (talk.escTimer > 0) then
        if talk.enterTimer > 0 then
          talk.enterTimer = talk.enterTimer - 1
        else
          local nupak = packets.new('outgoing', 0x01A, {
            ['Category'] = 0,
            ['Param'] = 0,
            ['Target'] = talk.target,
            ['Target Index'] = talk.targetIndex,
            ['X Offset'] = talk.off.x,
            ['Y Offset'] = talk.off.y,
            ['Z Offset'] = talk.off.z
          })
          packets.inject(nupak)
          talk.enterTimer = 70
          log('Attempting to talk to ' .. target.name)
        end
      end
    end
    
    if talk.escTimer > 0 then
      if talk.escTimer == 30 then
        input.impulse('escape escape escape')
      end
      talk.escTimer = talk.escTimer - 1
    end
    
    return true
end

function talk.draw()
  for i,b in ipairs(talk.border) do
    b:visible(talk.enabled or input.key)
  end

  if talk.target then
    talk.box:visible(true)
    talk.text:visible(true)
  else
    talk.box:visible(false)
    talk.text:visible(false)
  end
end

function talk.outPacket(id, data)
  local player = windower.ffxi.get_mob_by_target('me')
  if not player or not talk.enabled then return nil end
  
  local pak = packets.parse('outgoing', data)

  if id == 26 then
    if pak.Category == 0 and pak.Param == 0 then  -- Only talk packets, the rest are actaul things
      talk.lastPacket = pak
    end
  end
end

function talk.status(id)
  if id == 4 then
    talk.inDialouge = true
    talk.replicate()
    talk.target = nil
  else
    talk.inDialouge = false
    talk.lastPacket = nil
    input.reset()
  end
end

function talk.replicate()
  if not talk.enabled then return end
  
  local player = windower.ffxi.get_mob_by_target('me')
  local info = windower.ffxi.get_info()
  if not player or not (talk.inDialouge and talk.lastPacket) then return end
  
  util.send('all', 'asp talkorder ' .. string.lower(player.name) .. ' ' .. info.zone .. ' ' .. talk.lastPacket.Target .. ' ' .. talk.lastPacket["Target Index"] .. ' ' .. talk.lastPacket["X Offset"] .. ' ' .. talk.lastPacket["Y Offset"] .. ' ' .. talk.lastPacket["Z Offset"])
end

function talk.dead()
  if talk.target then
    talk.enabled = false
    talk.inDialouge = false
    talk.lastPacket = nil

    talk.target = nil
    talk.escTimer = 35
  end
end

  local wsets = windower.get_windower_settings()
  local size = vec2.create(255, 32)
  local pos = vec2.create((wsets.x_res-size.x)*0.5, (wsets.y_res-size.y)*0.5)

  local t = texts.new({flags = {draggable = false}})
  t:text("Please wait...")
  t:font('Consolas')
  t:color(255, 255, 255)
  t:alpha(255)
  t:pos(pos.x,pos.y-2)
  t:size(24)
  t:visible(false)
  
  t:stroke_width(1)
  t:stroke_color(0, 0, 0)
  t:stroke_alpha(175)
  
  t:bg_color(0, 0, 0)
  t:bg_alpha(0, 0, 0)
  t:bg_visible(false)
  
  talk.text = t
  
  local i = images.new()
  i:clear()
  i:color(44, 66, 180)
  i:alpha(160)
  i:pos(pos.x,pos.y)
  i:size(size.x,size.y)
  i:draggable(false)
  i:visible(false)
  
  talk.box = i
  
  -- Generate stuff for red border that shows when autotalk/autokey is enabled, this is so you don't forget that it's on since it can be oof if your forget
  local left = images.new()
  left:clear()
  left:color(255, 0, 0)
  left:alpha(144)
  left:pos(0,0)
  left:size(5, wsets.y_res)
  left:draggable(false)
  left:visible(false)
  
  local right = images.new()
  right:clear()
  right:color(255, 0, 0)
  right:alpha(144)
  right:pos(wsets.x_res - 5,0)
  right:size(5, wsets.y_res)
  right:draggable(false)
  right:visible(false)
  
  local top = images.new()
  top:clear()
  top:color(255, 0, 0)
  top:alpha(144)
  top:pos(0,0)
  top:size(wsets.x_res, 5)
  top:draggable(false)
  top:visible(false)
  
  local bottom = images.new()
  bottom:clear()
  bottom:color(255, 0, 0)
  bottom:alpha(144)
  bottom:pos(0,wsets.y_res - 5)
  bottom:size(wsets.x_res, 5)
  bottom:draggable(false)
  bottom:visible(false)
  
  talk.border[1] = left
  talk.border[2] = right
  talk.border[3] = top
  talk.border[4] = bottom

return talk