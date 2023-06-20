local util = {
  _VERSION = 'Util 1.0',
  _DESCRIPTION = 'Jank utils for Antisocial',
}

local vec2 = require('vec2')

-- String Splitter
function util.split (inputstr, sep)
  -- I stole this code from stack overflow lol
  if sep == nil then
    sep = "%s"
  end
  local t={}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

-- String trim whitespace
function util.trim(s)
  -- Also grabbed from stack overflow
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Take string name of color and return {rgb 255}
function util.color(name)
  if string.lower(name) == 'white' then
    return {r = 255, g = 255, b = 255}
  elseif string.lower(name) == 'red' then
    return {r = 242, g = 16, b = 0}
  elseif string.lower(name) == 'green' then
    return {r = 31, g = 242, b = 60}
  elseif string.lower(name) == 'blue' then
    return {r = 31, g = 67, b = 242}
  elseif string.lower(name) == 'purple' then
    return {r = 186, g = 31, b = 242}
  elseif string.lower(name) == 'orange' then
    return {r = 252, g = 190, b = 3}
  elseif string.lower(name) == 'yellow' then
    return {r = 245, g = 245, b = 59}
  else
    return {r = 33, g = 33, b = 33}
  end
end

function util.send(to, cmd)
  if to == 'all' then
    windower.send_command('send @all ' ..cmd)
  else
    windower.send_command('send ' ..to.. ' ' ..cmd)
  end
end

function util.exec(cmd)
  windower.send_command(cmd)
end

-- Converts normalized vector movement into angle movement
function util.move(v)
  local ang = vec2.angle(vec2.create(0,1), v)
  if v.x < 0 then
    ang = ang * -1
  end
  windower.ffxi.run(ang - 1.5708)
end

-- Gets the party as an array
function util.getParty()
  local party = windower.ffxi.get_party()
  local pt = {}
  for i,p in ipairs({'p0','p1','p2','p3','p4','p5'}) do
    if party[p] then
      pt[#pt+1] = party[p]
    end
  end
  return pt
end

-- get the party info of you
function util.getMe()
  local me = windower.ffxi.get_player()
  local party = windower.ffxi.get_party()
  for i,p in ipairs({'p0','p1','p2','p3','p4','p5'}) do
    if party[p] and string.lower(party[p].name) == string.lower(me.name) then
      return party[p]
    end
  end
  return nil
end

-- Gets the party info of a player by thier name
function util.getPlayer(name)
  local party = windower.ffxi.get_party()
  for i,p in ipairs({'p0','p1','p2','p3','p4','p5'}) do
    if party[p] and string.lower(party[p].name) == string.lower(name) then
      return party[p]
    end
  end
  return nil
end

-- Gets the mob of a player in your party by their name
function util.getPlayerMob(name)
  local party = windower.ffxi.get_party()
  for i,p in ipairs({'p0','p1','p2','p3','p4','p5'}) do
    if party[p] and string.lower(party[p].name) == string.lower(name) then
      return windower.ffxi.get_mob_by_target(p)
    end
  end
  return nil
end

return util