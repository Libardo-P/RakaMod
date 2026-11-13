RakaMod = RakaMod or {}

local Reveal = {}
RakaMod.Reveal = Reveal

local EVENTS = {
  "UNIT_HEALTH",
  "UNIT_MAXHEALTH",
  "UNIT_ABSORB_AMOUNT_CHANGED",
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_FAILED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
}

local UNIT_EVENT = {
  UNIT_HEALTH = true,
  UNIT_MAXHEALTH = true,
  UNIT_ABSORB_AMOUNT_CHANGED = true,
  UNIT_SPELLCAST_START = true,
  UNIT_SPELLCAST_STOP = true,
  UNIT_SPELLCAST_CHANNEL_START = true,
  UNIT_SPELLCAST_CHANNEL_STOP = true,
  UNIT_SPELLCAST_INTERRUPTED = true,
  UNIT_SPELLCAST_FAILED = true,
}

local hovering = false
local enabled = false
local hookedFrame
local enterHooked = false
local leaveHooked = false
local cycles = {}
local drivers = {}
local visibilityHooked = false
local alphaPinned = {}
local pinning = false

local events

local function IsSecret(value)
  if issecretvalue and issecretvalue(value) then
    return true
  end
  if canaccessvalue and not canaccessvalue(value) then
    return true
  end
  return false
end

local function Config()
  local reveal = RakaMod.db and RakaMod.db.reveal
  if type(reveal) ~= "table" then
    return nil
  end
  return reveal
end

local function Locked()
  return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function Protected(frame)
  if frame == nil then
    return false
  end
  local ok, value = pcall(function()
    return frame:IsProtected()
  end)
  return ok and value and true or false
end

local function HealthAboveFull()
  if type(UnitHealth) ~= "function" or type(UnitHealthMax) ~= "function" then
    return false
  end
  if not RakaMod.Logic or type(RakaMod.Logic.HealthAboveFull) ~= "function" then
    return false
  end
  local okCurrent, current = pcall(UnitHealth, "player")
  local okMax, maxHealth = pcall(UnitHealthMax, "player")
  if not okCurrent or not okMax then
    return false
  end
  local absorbs = 0
  if type(UnitGetTotalAbsorbs) == "function" then
    local okAbsorb, value = pcall(UnitGetTotalAbsorbs, "player")
    if okAbsorb and type(value) == "number" then
      absorbs = value
    elseif okAbsorb and IsSecret(value) then
      return false
    end
  end
  local secret = IsSecret(current) or IsSecret(maxHealth)
  local okAbove, above = pcall(RakaMod.Logic.HealthAboveFull, current, maxHealth, absorbs, secret)
  return okAbove and above or false
end

local function InfoActive(fn)
  if type(fn) ~= "function" then
    return false
  end
  local ok, value = pcall(fn, "player")
  if not ok then
    return false
  end
  if IsSecret(value) then
    return true
  end
  return value and true or false
end

local function CastingNow()
  return InfoActive(UnitCastingInfo) or InfoActive(UnitChannelInfo)
end

local function CombatNow()
  if type(UnitAffectingCombat) == "function" then
    local ok, value = pcall(UnitAffectingCombat, "player")
    if ok and not IsSecret(value) and value then
      return true
    end
  end
  if type(InCombatLockdown) == "function" then
    local ok, value = pcall(InCombatLockdown)
    if ok and value then
      return true
    end
  end
  return false
end

local function Triggers(cfg)
  local casting = cfg.casting == true and CastingNow()
  local health = cfg.health == true and HealthAboveFull()
  local mouseover = cfg.mouseover == true and hovering
  local combat = cfg.combat == true and CombatNow()
  return {
    casting = casting and true or false,
    health = health and true or false,
    mouseover = mouseover and true or false,
    combat = combat and true or false,
    any = (casting or health or mouseover or combat) and true or false,
  }
end

local function BlankCycle()
  return { active = false, shown = nil, alpha = nil }
end

local function AlphaTarget(frame)
  if frame and frame._visWrap then
    return frame._visWrap
  end
  return frame
end

local function Remember(frame, cycle)
  if cycle.active then
    return
  end
  local target = AlphaTarget(frame)
  local okShown, shown = pcall(target.IsShown, target)
  if okShown then
    cycle.shown = shown and true or false
  end
  local okAlpha, alpha = pcall(target.GetAlpha, target)
  if okAlpha then
    cycle.alpha = alpha
  end
  cycle.active = true
end

local function PinAlpha(frame)
  local target = AlphaTarget(frame)
  if not target or alphaPinned[target] or type(hooksecurefunc) ~= "function" then
    return
  end
  local ok = pcall(hooksecurefunc, target, "SetAlpha", function(_, alpha)
    if pinning then
      return
    end
    local cycle = cycles[frame]
    if not cycle or not cycle.active or (not IsSecret(alpha) and alpha == 1) then
      return
    end
    pinning = true
    pcall(target.SetAlpha, target, 1)
    pinning = false
  end)
  if ok then
    alphaPinned[target] = true
  end
end

local function ForceAlpha(frame)
  local target = AlphaTarget(frame)
  PinAlpha(frame)
  pcall(target.SetAlpha, target, 1)
end

local function InstallDriver(frame, cycle)
  if drivers[frame] then
    return
  end
  Remember(frame, cycle)
  if type(RegisterStateDriver) ~= "function" then
    return
  end
  local ok = pcall(RegisterStateDriver, frame, "visibility", "[combat] show")
  if ok then
    drivers[frame] = true
  end
end

local function RemoveDriver(frame)
  if not drivers[frame] then
    return true
  end
  if Locked() and Protected(frame) then
    return false
  end
  if type(UnregisterStateDriver) ~= "function" then
    drivers[frame] = nil
    return true
  end
  local ok = pcall(UnregisterStateDriver, frame, "visibility")
  if not ok then
    return false
  end
  drivers[frame] = nil
  pcall(function()
    frame._euiVisDriver = nil
  end)
  return true
end

local function ReapplyActiveAlpha()
  local any = false
  for _, cycle in pairs(cycles) do
    if cycle.active then
      any = true
      break
    end
  end
  if not any then
    return
  end
  for frame, cycle in pairs(cycles) do
    if cycle.active then
      ForceAlpha(frame)
    end
  end
end

local function HookVisibility()
  if visibilityHooked or type(hooksecurefunc) ~= "function" then
    return
  end
  local root = EllesmereUI
  if type(root) ~= "table" or type(root._ModuleNS) ~= "table" then
    return
  end
  local frames = root._ModuleNS.EllesmereUIUnitFrames
  if type(frames) ~= "table" or type(frames.UpdateFrameVisibility) ~= "function" then
    return
  end
  local ok = pcall(hooksecurefunc, frames, "UpdateFrameVisibility", ReapplyActiveAlpha)
  if ok then
    visibilityHooked = true
  end
end

local function VisibilityUpdate()
  local root = EllesmereUI
  if type(root) ~= "table" then
    return nil
  end
  local registry = root._ModuleNS
  if type(registry) ~= "table" then
    return nil
  end
  local frames = registry.EllesmereUIUnitFrames
  if type(frames) ~= "table" then
    return nil
  end
  local update = frames.UpdateFrameVisibility
  if type(update) ~= "function" then
    return nil
  end
  return update
end

local function Restore(frame, cycle)
  if cycle.shown == true then
    pcall(frame.Show, frame)
  elseif cycle.shown == false then
    pcall(frame.Hide, frame)
  end
  if cycle.alpha ~= nil then
    local target = AlphaTarget(frame)
    pcall(target.SetAlpha, target, cycle.alpha)
  end
end

local function ClearCycle(frame)
  cycles[frame] = nil
  drivers[frame] = nil
end

local function Release(frame)
  local cycle = cycles[frame]
  if not cycle or not cycle.active then
    ClearCycle(frame)
    return true
  end
  if not RemoveDriver(frame) then
    return false
  end
  HookVisibility()
  local update = VisibilityUpdate()
  if update then
    cycle.active = false
    pcall(update)
    ClearCycle(frame)
    return true
  end
  if Locked() then
    return false
  end
  cycle.active = false
  Restore(frame, cycle)
  ClearCycle(frame)
  return true
end

local function Activate(frame, armCombat)
  local cycle = cycles[frame] or BlankCycle()
  cycles[frame] = cycle
  if armCombat then
    InstallDriver(frame, cycle)
  elseif not Locked() and not RemoveDriver(frame) then
    return
  end
  if Locked() then
    Remember(frame, cycle)
    ForceAlpha(frame)
    return
  end
  Remember(frame, cycle)
  pcall(frame.Show, frame)
  ForceAlpha(frame)
end

local function Apply(frame, triggers, armCombat)
  if triggers.any then
    Activate(frame, armCombat)
  else
    Release(frame)
  end
end

local function ReleaseStale(keep)
  local stale = {}
  for frame in pairs(cycles) do
    if not keep[frame] then
      stale[#stale + 1] = frame
    end
  end
  for i = 1, #stale do
    Release(stale[i])
  end
end

local function ReleaseKnown()
  local frames = {}
  for frame in pairs(cycles) do
    frames[#frames + 1] = frame
  end
  local pending = false
  for i = 1, #frames do
    if not Release(frames[i]) then
      pending = true
    end
  end
  return pending
end

local function Hook(frame, script, handler)
  if type(frame.HookScript) == "function" then
    return pcall(frame.HookScript, frame, script, handler)
  end
  if type(frame.GetScript) ~= "function" or type(frame.SetScript) ~= "function" then
    return false
  end
  local okOriginal, original = pcall(frame.GetScript, frame, script)
  if not okOriginal then
    return false
  end
  return pcall(frame.SetScript, frame, script, function(...)
    if type(original) == "function" then
      original(...)
    end
    handler(...)
  end)
end

local function OnHover(entered)
  hovering = entered and true or false
  if enabled then
    Reveal:Update()
  end
end

local function TryHookPlayer()
  local frame = EllesmereUIUnitFrames_Player
  if not frame then
    return
  end
  if hookedFrame ~= frame then
    hookedFrame = frame
    enterHooked = false
    leaveHooked = false
  end
  if not enterHooked then
    enterHooked = Hook(frame, "OnEnter", function()
      OnHover(true)
    end)
    if enterHooked then
      local ok, over = pcall(frame.IsMouseOver, frame)
      if ok and over then
        hovering = true
      end
    end
  end
  if not leaveHooked then
    leaveHooked = Hook(frame, "OnLeave", function()
      OnHover(false)
    end)
  end
end

function Reveal:Update()
  if not enabled then
    return
  end
  TryHookPlayer()
  HookVisibility()
  local cfg = Config()
  if not cfg then
    ReleaseKnown()
    return
  end
  local triggers = Triggers(cfg)
  local keep = {}
  local player = EllesmereUIUnitFrames_Player
  if player then
    keep[player] = true
    Apply(player, triggers, cfg.combat == true)
  end
  if cfg.pet == true then
    local pet = EllesmereUIUnitFrames_Pet
    if pet then
      keep[pet] = true
      Apply(pet, triggers, cfg.combat == true)
    end
  end
  ReleaseStale(keep)
end

local function UnregisterAll()
  if not events then
    return
  end
  for i = 1, #EVENTS do
    pcall(events.UnregisterEvent, events, EVENTS[i])
  end
end

local function FinishPending()
  if not ReleaseKnown() then
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
end

function Reveal:Enable()
  enabled = true
  for i = 1, #EVENTS do
    pcall(events.RegisterEvent, events, EVENTS[i])
  end
  TryHookPlayer()
  Reveal:Update()
end

function Reveal:Disable()
  enabled = false
  local pending = ReleaseKnown()
  UnregisterAll()
  if pending then
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
  end
end

events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
  if not enabled then
    if event == "PLAYER_REGEN_ENABLED" then
      FinishPending()
    end
    return
  end
  if UNIT_EVENT[event] and unit ~= "player" then
    return
  end
  Reveal:Update()
end)

RakaMod.Core:RegisterModule({
  name = "Reveal",
  dbKey = "reveal",
  requires = "EllesmereUIUnitFrames",
  OnLoad = function(self) end,
  OnEnable = function(self) RakaMod.Reveal:Enable() end,
  OnDisable = function(self) RakaMod.Reveal:Disable() end,
})
