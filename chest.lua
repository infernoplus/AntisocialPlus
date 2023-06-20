local chest = {
  _VERSION = 'Chest Solver 1.0',
  _DESCRIPTION = 'Solves treasure chests',
}

require('strings')
require('tables')

local util = require('util')

chest.stage = nil
chest.combo = nil

-- Chest Solver
function chest.solve(msg)
  if string.find(msg, "The monster was concealing a treasure chest!") or string.find(msg, "failed to open the lock.") or string.find(msg, "succeeded in opening the lock!") then
    chest.stage = 5
    chest.combo = {}
    for i=1, 99 do
      chest.combo[i] = true
    end
    log('Treasure Chest Solver Active!')
    return true
  elseif string.find(msg, "You have a hunch that the second digit is even") then
    for i=1, 99 do
      if(i % 2 == 1) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  elseif string.find(msg, "You have a hunch that the first digit is even") then
    for i=1, 99 do
      if(math.floor(i/10) % 2 == 1) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  elseif string.find(msg, "You have a hunch that the second digit is odd") then
    for i=1, 99 do
      if(i % 2 == 0) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  elseif string.find(msg, "You have a hunch that the first digit is odd") then
    for i=1, 99 do
      if(math.floor(i/10) % 2 == 0) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  elseif string.find(msg, "You have a hunch that one of the two digits is ") then
    local spl = util.split(msg, " ")
    local digit = tonumber(string.sub(spl[12], 0, 1))
    for i=1, 99 do
      local a = math.floor(i/10)
      local b = i%10
      if not (a == digit or b == digit) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  elseif string.find(msg, "You have a hunch that the combination is greater than ") and string.find(msg, "less") then
    local spl = util.split(msg, " ")
    local digitA = tonumber(spl[11])
    local digitB = tonumber(string.sub(spl[15], 0, 2))
    for i=1, 99 do
      if not (i < digitB and i > digitA) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  elseif string.find(msg, "You have a hunch that the combination is greater than ") then
    local spl = util.split(msg, " ")
    local digitA = tonumber(string.sub(spl[11], 0, 2))
    for i=1, 99 do
      if not (i > digitA) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  elseif string.find(msg, "You have a hunch that the combination is less than ") then
    local spl = util.split(msg, " ")
    local digitA = tonumber(string.sub(spl[11], 0, 2))
    for i=1, 99 do
      if not (i < digitA) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  elseif string.find(msg, "You have a hunch that the second digit is ") then
    local digitA = tonumber(string.sub(msg, 42, 43))
    local digitB = tonumber(string.sub(msg, 45, 46))
    local digitC = tonumber(string.sub(msg, 51, 52))
    for i=1, 99 do
      local b = i%10
      if not (b == digitA or b == digitB or b == digitC) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  elseif string.find(msg, "You have a hunch that the first digit is ") then
    local digitA = tonumber(string.sub(msg, 41, 42))
    local digitB = tonumber(string.sub(msg, 44, 45))
    local digitC = tonumber(string.sub(msg, 50, 51))
    for i=1, 99 do
      local a = math.floor(i/10)
      if not (a == digitA or a == digitB or a == digitC) then
        chest.combo[i] = false
      end
    end
    chest.stage = chest.stage + 1
    chest.out()
    return true
  else
    return false
  end
end

function chest.out()
    local out = ""
    local j = 0
    for i=1, 99 do
      if chest.combo[i] then
        out = out .. i .. " "
        j = j + 1
      end
    end
    if j < 25 then
      log(out)
    else
      log("25+ solutions...")
    end
end

return chest