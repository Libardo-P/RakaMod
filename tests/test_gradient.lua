-- Gradient module behaviour against a minimal fake WoW API.
local unpack = table.unpack or unpack
local failures = 0
local function eq(actual, expected, name)
  if actual ~= expected then
    failures = failures + 1
    io.stderr:write(string.format("FAIL %s: got %s expected %s\n", name, tostring(actual), tostring(expected)))
  end
end

local savedGlobals = {}
local function setGlobal(name, value)
  if savedGlobals[name] == nil then
    savedGlobals[name] = { value = _G[name] }
  end
  _G[name] = value
end

local timers = {}
local registered = {}
local frameScripts = {}
setGlobal("CreateFrame", function()
  local f = {}
  function f:RegisterEvent(e)
    registered[e] = true
  end
  function f:UnregisterEvent(e)
    registered[e] = nil
  end
  function f:SetScript(name, fn)
    frameScripts[name] = fn
  end
  return f
end)
setGlobal("C_Timer", { After = function(_, fn) timers[#timers + 1] = fn end })
setGlobal("CreateColor", function(r, g, b)
  return { r = r, g = g, b = b }
end)
setGlobal("issecretvalue", function(v)
  return type(v) == "table" and v.secret == true
end)
setGlobal("UnitExists", function() return true end)
setGlobal("UnitIsDeadOrGhost", function() return false end)
setGlobal("UnitIsPlayer", function() return true end)
setGlobal("UnitIsConnected", function() return true end)
setGlobal("UnitIsTapDenied", function() return false end)
setGlobal("UnitClass", function(unit)
  if unit == "target" then
    return "Mage", "MAGE"
  end
  return "Warrior", "WARRIOR"
end)
setGlobal("UnitReaction", function() return 5 end)
setGlobal("EllesmereUIUnitFrames_Player", nil)

local hooks = {}
setGlobal("hooksecurefunc", function(obj, name, fn)
  local original = obj[name]
  hooks[#hooks + 1] = { obj = obj, name = name }
  obj[name] = function(...)
    local results = { original(...) }
    fn(...)
    return unpack(results)
  end
end)

RakaMod = { Logic = dofile("Logic.lua") }
local loaded = {}
RakaMod.Core = {
  AddonLoaded = function(_, name) return name == "EllesmereUIUnitFrames" end,
  RegisterModule = function(_, def) loaded[#loaded + 1] = def end,
}
RakaMod.db = { gradient = RakaMod.Logic.BuildGradientDefaults() }
RakaMod.db.gradient.enabled = true
dofile("Gradient.lua")
local Gradient = RakaMod.Gradient

local function newBar(unit)
  local bar = { gradients = 0, flat = 0, unit = unit, color = { 0.1, 0.2, 0.3, 1 } }
  local tex = {}
  function tex:SetGradient(_, a, b)
    if a == b or (a.r == b.r and a.g == b.g and a.b == b.b) then
      bar.flat = bar.flat + 1
    else
      bar.gradients = bar.gradients + 1
    end
    bar.lastLeft = a
  end
  function bar:GetObjectType() return "StatusBar" end
  function bar:GetStatusBarTexture() return tex end
  function bar:GetStatusBarColor() return unpack(self.color) end
  function bar:SetStatusBarColor(r, g, b, a)
    self.color = { r, g, b, a }
    self.originalCalls = (self.originalCalls or 0) + 1
  end
  return bar
end

local playerBar, targetBar = newBar("player"), newBar("target")
local originalSet = playerBar.SetStatusBarColor
Gradient:Hook(playerBar)
Gradient:Hook(targetBar)
Gradient:Hook(playerBar)
eq(#hooks, 2, "each bar hooked once")
eq(rawequal(playerBar.SetStatusBarColor, originalSet), false, "hooksecurefunc wraps via the API, not by hand")

-- Module not enabled yet: color changes must not paint.
playerBar:SetStatusBarColor(0.5, 0.5, 0.5, 1)
eq(playerBar.gradients, 0, "inactive hook does not paint")

Gradient:Enable()
eq(registered.UNIT_FLAGS, true, "enable registers UNIT_FLAGS")
playerBar:SetStatusBarColor(0.6, 0.6, 0.6, 1)
eq(playerBar.gradients >= 1, true, "active hook paints on SetStatusBarColor")
eq(playerBar.originalCalls >= 1, true, "original SetStatusBarColor still runs")

-- Unit-filtered, throttled events.
local base = { player = playerBar.gradients, target = targetBar.gradients }
local before = #timers
Gradient:OnGameEvent("UNIT_FLAGS", "player")
Gradient:OnGameEvent("UNIT_FLAGS", "player")
Gradient:OnGameEvent("UNIT_CONNECTION", "raid7")
eq(#timers - before, 1, "burst of events schedules one flush")
timers[#timers]()
eq(playerBar.gradients - base.player, 1, "matching unit repainted once")
eq(targetBar.gradients - base.target, 0, "other units untouched")

Gradient:OnGameEvent("UNIT_FLAGS", { secret = true })
eq(#timers - before, 1, "secret unit token ignored")

-- Disable restores the last colour Ellesmere set and stops painting.
playerBar:SetStatusBarColor(0.7, 0.8, 0.9, 1)
local flatBefore = playerBar.flat
Gradient:Disable()
eq(playerBar.color[1], 0.7, "disable re-applies Ellesmere colour")
eq(playerBar.flat > flatBefore, true, "disable flattens the gradient")
local gradientsAfterDisable = playerBar.gradients
playerBar:SetStatusBarColor(0.2, 0.2, 0.2, 1)
eq(playerBar.gradients, gradientsAfterDisable, "no painting after disable")
eq(registered.UNIT_FLAGS, nil, "disable unregisters events")

-- Secret colour values pass straight through to the original without arithmetic.
Gradient:Enable()
local secretColor = { secret = true }
playerBar:SetStatusBarColor(secretColor, secretColor, secretColor, 1)
eq(playerBar.color[1], secretColor, "secret colour forwarded untouched")

for name, saved in pairs(savedGlobals) do
  _G[name] = saved.value
end
RakaMod = nil

if failures > 0 then
  os.exit(1)
end
print("gradient ok")
