local vec2 = {
  _VERSION = 'Vec2 1.0',
  _DESCRIPTION = 'Jank vec2 math lib for Antisocial',
}

require('tables')

function vec2.create(x, y)
  local v = {}
  v.x = x
  v.y = y
  return v
end

function vec2.scale(v, s)
  local vr = {}
  vr.x = v.x * s
  vr.y = v.y * s
  return vr
end

function vec2.inverse(v)
  local vr = {}
  vr.x = -v.x
  vr.y = -v.y
  return vr
end

function vec2.distance(v1, v2)
  return math.sqrt(((v2.x-v1.x)^2) + ((v2.y-v1.y)^2))
end

function vec2.magnitude(v)
  return math.sqrt((v.x^2) + (v.y^2))
end

function vec2.add(v1, v2)
  local vr = {}
  vr.x = v1.x + v2.x
  vr.y = v1.y + v2.y
  return vr
end

function vec2.subtract(v1, v2)
  local vr = {}
  vr.x = v1.x - v2.x
  vr.y = v1.y - v2.y
  return vr
end

function vec2.normalize(v)
  local vr = {}
  local vm = vec2.magnitude(v)

  if vm == 0 then
    vr.x = 0
    vr.y = 1
    return vr
  end

  vr.x = v.x / vm
  vr.y = v.y / vm

  return vr
end

function vec2.rotate(v, a)
  local cos = math.cos(a)
  local sin = math.sin(a)

  local vr = {}
  vr.x = (v.x * cos) + (v.y * sin)
  vr.y = (v.x * -sin) + (v.y * cos)
  return vr
end

function vec2.angle(v1, v2)
  local dot = vec2.dot(v1, v2)
  local a = math.sqrt((v1.x^2) + (v1.y^2))
  local b = math.sqrt((v2.x^2) + (v2.y^2))
  return math.acos(dot/(a*b))
end

function vec2.dot(v1, v2)
  return (v1.x * v2.x) + (v1.y * v2.y)
end

return vec2
