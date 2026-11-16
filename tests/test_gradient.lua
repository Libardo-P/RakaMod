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

-- Power, castbar, class resource and nameplate bars ------------------------------------------
do
  local Logic = RakaMod.Logic
  local g = RakaMod.db.gradient
  Gradient:Disable()
  g.enabled = true

  local function frameWith(fields)
    local f = { GetObjectType = function() return "Frame" end }
    for k, v in pairs(fields) do f[k] = v end
    return f
  end
  local function sameLeft(bar, pairColors)
    return bar.lastLeft ~= nil and bar.lastLeft.r == pairColors.left.r and bar.lastLeft.g == pairColors.left.g
  end

  local power, cast, pip1, pip2 = newBar("player"), newBar("player"), newBar("player"), newBar("player")
  local plateHealth = newBar("nameplate1")
  setGlobal("UnitPowerType", function() return 0, "MANA" end)
  setGlobal("UnitClass", function() return "Rogue", "ROGUE" end)
  setGlobal("GetSpecialization", function() return 1 end)
  setGlobal("EllesmereUIUnitFrames_Player", frameWith({
    unit = "player",
    powerBar = power,
    castBar = cast,
    classPower = { pip1, pip2 },
    absorbBar = newBar("player"),
  }))
  Gradient:Enable()
  eq(#hooks >= 6, true, "power, cast and resource bars are found and hooked")

  eq(power.gradients, 0, "power bars stay untouched while their switch is off")
  eq(cast.gradients, 0, "cast bars stay untouched while their switch is off")
  eq(pip1.gradients, 0, "resource bars stay untouched while their switch is off")

  g.powerEnabled = true
  Gradient:Apply()
  eq(sameLeft(power, g.power.mana), true, "power bar paints the mana gradient")
  setGlobal("UnitPowerType", function() return 1, "RAGE" end)
  Gradient:Apply()
  eq(sameLeft(power, g.power.rage), true, "power gradient follows the power type")
  setGlobal("UnitPowerType", function() return 99, "FURY" end)
  local before = power.gradients
  local flatBeforeUnknown = power.flat
  Gradient:Apply()
  eq(power.gradients, before, "power types without a gradient do not paint a new gradient")
  eq(power.flat > flatBeforeUnknown, true, "leaving a painted power type restores the flat colour")

  g.castbarEnabled = true
  setGlobal("UnitCastingInfo", function() return "Fireball", "", "", 0, 1, false, "id", false, 1 end)
  Gradient:Apply()
  eq(sameLeft(cast, g.castbar.regular), true, "interruptible cast paints the regular gradient")
  setGlobal("UnitCastingInfo", function() return "Fireball", "", "", 0, 1, false, "id", true, 1 end)
  Gradient:Apply()
  eq(sameLeft(cast, g.castbar.nonInterruptible), true, "uninterruptible cast paints the non-interruptible gradient")
  setGlobal("UnitCastingInfo", function() return nil end)
  setGlobal("UnitChannelInfo", function() return "Drain", "", "", 0, 1, false, true, 1 end)
  Gradient:Apply()
  eq(sameLeft(cast, g.castbar.nonInterruptible), true, "uninterruptible channel paints the non-interruptible gradient")

  g.resourcesEnabled = true
  Gradient:Apply()
  eq(sameLeft(pip1, g.classResources.comboPoint1), true, "first combo point pip paints comboPoint1")
  eq(sameLeft(pip2, g.classResources.comboPoint2), true, "second combo point pip paints comboPoint2")

  setGlobal("UnitPowerType", function() return 0, "MANA" end)
  g.powerEnabled = true
  Gradient:Apply()
  eq(sameLeft(power, g.power.mana), true, "power paints again after an unknown type")
  g.powerEnabled = false
  local flatBefore = power.flat
  Gradient:Apply()
  eq(power.flat > flatBefore, true, "turning a switch off flattens the bars it painted")
  local gradientsAfterOff = power.gradients
  power:SetStatusBarColor(0.3, 0.3, 0.3, 1)
  eq(power.gradients, gradientsAfterOff, "a switched-off kind no longer paints")

  eq(registered.UNIT_SPELLCAST_START, true, "cast events are registered while cast bars are on")
  eq(registered.UNIT_DISPLAYPOWER, nil, "power events are dropped once power painting is off")
  eq(registered.UNIT_THREAT_SITUATION_UPDATE, nil, "threat events stay off without nameplate colors")
  local queued = #timers
  Gradient:OnGameEvent("UNIT_SPELLCAST_START", "player")
  eq(#timers - queued, 1, "cast events schedule a repaint")
  Gradient:OnGameEvent("UNIT_DISPLAYPOWER", "player")
  eq(#timers - queued, 1, "events nobody asked for are ignored")

  -- Nameplates: threat and classification colors need their own switch.
  local plate = frameWith({ unit = "nameplate1", health = plateHealth })
  RakaMod.Core.AddonLoaded = function(_, name) return name == "EllesmereUINameplates" end
  EllesmereUI = { _ModuleNS = { EllesmereUINameplates = { plates = { plate } } } }
  setGlobal("UnitIsPlayer", function() return false end)
  setGlobal("UnitReaction", function() return 2 end)
  setGlobal("UnitThreatSituation", function() return 3 end)
  setGlobal("UnitGroupRolesAssigned", function() return "TANK" end)
  setGlobal("IsInGroup", function() return true end)
  setGlobal("UnitClassification", function() return "elite" end)
  setGlobal("UnitLevel", function() return 80 end)
  Gradient:Disable()
  Gradient:Enable()
  eq(sameLeft(plateHealth, g.npc.enemy), true, "nameplates use the Health tab colors while the switch is off")
  g.nameplatesEnabled = true
  Gradient:Apply()
  eq(sameLeft(plateHealth, g.nameplateThreat.good), true, "tank holding aggro paints the good threat gradient")
  setGlobal("UnitThreatSituation", function() return nil end)
  Gradient:Apply()
  eq(sameLeft(plateHealth, g.nameplateClassification.eliteMini), true, "no threat falls back to the classification gradient")
  setGlobal("UnitClassification", function() return "normal" end)
  Gradient:Apply()
  eq(sameLeft(plateHealth, g.npc.enemy), true, "ordinary mobs fall back to the NPC gradient")
  eq(registered.UNIT_THREAT_SITUATION_UPDATE, true, "threat events are registered with nameplate colors on")

  -- UNIT_THREAT_SITUATION_UPDATE often reports "player"; must still repaint nameplates.
  setGlobal("UnitThreatSituation", function() return 3 end)
  setGlobal("UnitClassification", function() return "elite" end)
  -- Drain any coalesced flush so Schedule can arm again (mirrors Disable clearing the flag).
  while #timers > 0 do
    table.remove(timers, 1)()
  end
  local threatTimers = #timers
  Gradient:OnGameEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
  eq(#timers, threatTimers + 1, "threat situation schedules a flush")
  timers[#timers]()
  eq(sameLeft(plateHealth, g.nameplateThreat.good), true, "threat event with unit player still repaints nameplates")

  setGlobal("UnitThreatSituation", function() return nil end)
  setGlobal("UnitClassification", function() return "normal" end)
  Gradient:Apply()
  eq(sameLeft(plateHealth, g.npc.enemy), true, "nameplates return to NPC colours after threat clears")

  g.nameplateFadeDirection = "LEFT"
  Gradient:Apply()
  eq(plateHealth.lastLeft.r, g.npc.enemy.right.r, "LEFT fade direction swaps the gradient colors")

  setGlobal("UnitIsDeadOrGhost", function() return true end)
  Gradient:Apply()
  eq(sameLeft(plateHealth, g.states.dead) or plateHealth.lastLeft.r == g.states.dead.right.r, true, "dead nameplates keep the state gradient")

  -- Toolbar master Enabled gates every kind; per-kind switches alone are not enough.
  setGlobal("UnitIsDeadOrGhost", function() return false end)
  g.powerEnabled = true
  g.castbarEnabled = true
  g.resourcesEnabled = true
  g.nameplatesEnabled = true
  g.enabled = false
  local powerBefore = power.gradients
  local plateBefore = plateHealth.gradients
  Gradient:Apply()
  eq(power.gradients, powerBefore, "master off stops power painting even when powerEnabled")
  eq(plateHealth.gradients, plateBefore, "master off stops nameplate painting even when nameplatesEnabled")
  g.enabled = true
  Gradient:Apply()
  eq(power.gradients > powerBefore, true, "master on resumes power painting with powerEnabled")
  eq(plateHealth.gradients > plateBefore, true, "master on resumes nameplate painting with nameplatesEnabled")

  Gradient:Disable()
  EllesmereUI = nil
end

for name, saved in pairs(savedGlobals) do
  _G[name] = saved.value
end
RakaMod = nil

if failures > 0 then
  os.exit(1)
end
print("gradient ok")
