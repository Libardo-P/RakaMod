RakaMod = RakaMod or {}

local Gradient = {}
RakaMod.Gradient = Gradient

local UNIT_GLOBALS = {
  "EllesmereUIUnitFrames_Player",
  "EllesmereUIUnitFrames_Pet",
  "EllesmereUIUnitFrames_Target",
  "EllesmereUIUnitFrames_Focus",
  "EllesmereUIUnitFrames_TargetTarget",
  "EllesmereUIUnitFrames_Boss1",
  "EllesmereUIUnitFrames_Boss2",
  "EllesmereUIUnitFrames_Boss3",
  "EllesmereUIUnitFrames_Boss4",
  "EllesmereUIUnitFrames_Boss5",
  "EllesmereUIUnitFrames_Boss6",
  "EllesmereUIUnitFrames_Boss7",
  "EllesmereUIUnitFrames_Boss8",
}

local THROTTLE_SECONDS = 0.15

local hooked = {}
local barState = setmetatable({}, { __mode = "k" })
local active = false
local events
local pending = {}
local pendingAll = false
local pendingRescan = false
local flushScheduled = false

local function IsSecret(value)
  return issecretvalue ~= nil and issecretvalue(value) == true
end

local function StateOf(bar)
  local state = barState[bar]
  if not state then
    state = {}
    barState[bar] = state
  end
  return state
end

-- Reused across health paints (WoW is single-threaded; callers never store the table).
local unitInfoScratch = {
  dead = false,
  offline = false,
  tapped = false,
  isPlayer = false,
  classFile = nil,
  reactionKey = "neutral",
  threatKey = nil,
  classificationKey = nil,
}

local MAX_RESOURCE_PIPS = 12

local function IsStatusBar(value)
  return type(value) == "table" and value.GetObjectType ~= nil and value:GetObjectType() == "StatusBar"
end

-- Finds the health, power, castbar and class resource bars below an Ellesmere frame by field
-- name. inherited is the kind of the field the scan came through (a "castBar" frame holding its
-- bar under another name), hint the unit token to use when the bar's own frames do not say.
local function Scan(object, depth, found, opts, inherited)
  if not object or depth > 3 or found[object] then
    return
  end
  found[object] = true
  if type(object) ~= "table" or not object.GetObjectType then
    return
  end
  local logic = RakaMod.Logic
  for key, value in pairs(object) do
    if key ~= "parent" and key ~= "Parent" and type(value) == "table" then
      local kind = logic.BarKindFromKey(key)
      local effective = kind or inherited
      if IsStatusBar(value) then
        if effective then
          local index = type(key) == "number" and key or nil
          RakaMod.Gradient:Hook(value, opts and opts.unit, { kind = effective, index = index, nameplate = opts and opts.nameplate })
        end
      elseif kind == "resource" then
        for i = 1, MAX_RESOURCE_PIPS do
          local pip = value[i]
          if IsStatusBar(pip) then
            RakaMod.Gradient:Hook(pip, opts and opts.unit, { kind = "resource", index = i, nameplate = opts and opts.nameplate })
          end
        end
        if value.GetObjectType and depth < 3 then
          Scan(value, depth + 1, found, opts, kind)
        end
      elseif value.GetObjectType and depth < 3 then
        Scan(value, depth + 1, found, opts, effective)
      end
    end
  end
end

local function AddonOn(name)
  local core = RakaMod.Core
  return core and core.AddonLoaded and core:AddonLoaded(name) and true or false
end

local function ResolveUnit(bar)
  local hint = barState[bar] and barState[bar].unit
  if type(hint) == "string" and hint ~= "" then
    return hint
  end
  local frame = bar
  for _ = 1, 10 do
    if not frame then
      break
    end
    if type(frame.unit) == "string" and not IsSecret(frame.unit) and frame.unit ~= "" then
      return frame.unit
    end
    if frame.GetAttribute then
      local ok, unit = pcall(frame.GetAttribute, frame, "unit")
      if ok and type(unit) == "string" and not IsSecret(unit) and unit ~= "" then
        return unit
      end
    end
    frame = frame.GetParent and frame:GetParent() or nil
  end
  return nil
end

-- Returns a plain boolean, or false when the API errors or hands back a secret value.
local function SafeBool(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  local ok, result = pcall(fn, ...)
  if not ok or IsSecret(result) then
    return false
  end
  return result and true or false
end

local function UnitInfo(unit)
  local info = unitInfoScratch
  info.dead = false
  info.offline = false
  info.tapped = false
  info.isPlayer = false
  info.classFile = nil
  info.reactionKey = "neutral"
  info.threatKey = nil
  info.classificationKey = nil
  if type(unit) ~= "string" or unit == "" then
    return info
  end
  if not UnitExists or not SafeBool(UnitExists, unit) then
    return info
  end

  info.dead = SafeBool(UnitIsDeadOrGhost, unit)
  local isPlayer = SafeBool(UnitIsPlayer, unit)
  info.isPlayer = isPlayer

  local connected = true
  if UnitIsConnected then
    local ok, value = pcall(UnitIsConnected, unit)
    if ok and not IsSecret(value) then
      connected = value and true or false
    end
  end
  if isPlayer and not connected then
    info.offline = true
  end

  if UnitIsTapDenied then
    info.tapped = SafeBool(UnitIsTapDenied, unit)
  elseif UnitIsTapped and UnitIsTappedByPlayer then
    info.tapped = SafeBool(UnitIsTapped, unit) and not SafeBool(UnitIsTappedByPlayer, unit)
  end

  if isPlayer and UnitClass then
    local ok, _, classFile = pcall(UnitClass, unit)
    if ok and type(classFile) == "string" and not IsSecret(classFile) then
      info.classFile = classFile
    end
  end

  if UnitReaction then
    local ok, reaction = pcall(UnitReaction, unit, "player")
    if ok and type(reaction) == "number" and not IsSecret(reaction) then
      info.reactionKey = RakaMod.Logic.ReactionKey(reaction)
    end
  end

  return info
end

-- Reads one value from a unit API; nil when the API is missing, errors or answers a secret.
local function Safe(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c = pcall(fn, ...)
  if not ok then
    return nil
  end
  if IsSecret(a) then
    a = nil
  end
  if IsSecret(b) then
    b = nil
  end
  if IsSecret(c) then
    c = nil
  end
  return a, b, c
end

-- Threat and classification of a hostile non-player unit, for nameplate coloring.
local function AddNameplateInfo(info, unit)
  if info.isPlayer or type(unit) ~= "string" then
    return
  end
  local status = Safe(UnitThreatSituation, "player", unit)
  if status ~= nil then
    local tankRole = Safe(UnitGroupRolesAssigned, "player") == "TANK"
    local grouped = Safe(IsInGroup) == true
    local otherTank = false
    local targetUnit = unit .. "target"
    if Safe(UnitExists, targetUnit) == true and Safe(UnitIsUnit, targetUnit, "player") ~= true then
      otherTank = Safe(UnitGroupRolesAssigned, targetUnit) == "TANK"
    end
    info.threatKey = RakaMod.Logic.ThreatKey(status, tankRole, grouped, otherTank)
  end
  local classification = Safe(UnitClassification, unit)
  local level = Safe(UnitLevel, unit)
  local isBoss = false
  if type(unit) == "string" and string.find(unit, "^boss%d") then
    isBoss = true
  end
  local _, classFile = Safe(UnitClass, unit)
  info.classificationKey = RakaMod.Logic.ClassificationKey(classification, level, isBoss, classFile)
end

local function PlayerClassFile()
  local _, classFile = Safe(UnitClass, "player")
  if type(classFile) == "string" then
    return classFile
  end
  return nil
end

local function PlayerSpecIndex()
  local spec = Safe(GetSpecialization)
  if type(spec) == "number" then
    return spec
  end
  return nil
end

-- True while the unit's current cast or channel cannot be interrupted.
local function CastNonInterruptible(bar, unit)
  local own = bar.notInterruptible
  if type(own) == "boolean" and not IsSecret(own) then
    return own
  end
  if type(unit) ~= "string" then
    return false
  end
  local castFn = UnitCastingInfo
  if type(castFn) == "function" then
    local ok, name, _, _, _, _, _, _, notInterruptible = pcall(castFn, unit)
    if ok and name ~= nil then
      return type(notInterruptible) == "boolean" and not IsSecret(notInterruptible) and notInterruptible or false
    end
  end
  local channelFn = UnitChannelInfo
  if type(channelFn) == "function" then
    local ok, name, _, _, _, _, _, notInterruptible = pcall(channelFn, unit)
    if ok and name ~= nil then
      return type(notInterruptible) == "boolean" and not IsSecret(notInterruptible) and notInterruptible or false
    end
  end
  return false
end

-- Puts the bar back to the last flat colour Ellesmere gave it. SetStatusBarColor resets the
-- texture vertex colours; the explicit flat SetGradient is a belt-and-braces fallback for
-- clients where a previous gradient survives the vertex colour reset.
local function RestoreBar(bar)
  local state = barState[bar]
  local color = state and state.lastColor
  if state then
    state.painted = false
  end
  if type(color) ~= "table" then
    return
  end
  pcall(bar.SetStatusBarColor, bar, color[1], color[2], color[3], color[4])
  if type(color[1]) == "number" and not IsSecret(color[1]) and type(color[2]) == "number"
    and not IsSecret(color[2]) and type(color[3]) == "number" and not IsSecret(color[3]) then
    pcall(function()
      local flat = CreateColor(color[1], color[2], color[3], 1)
      bar:GetStatusBarTexture():SetGradient("HORIZONTAL", flat, flat)
    end)
  end
end

local KIND_SWITCH = { power = "powerEnabled", castbar = "castbarEnabled", resource = "resourcesEnabled" }

local function KindEnabled(gradient, kind)
  local key = KIND_SWITCH[kind]
  return key == nil or gradient[key] == true
end

-- Picks the gradient pair for one bar, or nil when this bar should keep Ellesmere's color.
local function ChoosePair(bar, state, gradient, unit)
  local logic = RakaMod.Logic
  local kind = state.kind or "health"
  if kind == "health" then
    local info = UnitInfo(unit)
    if state.nameplate and gradient.nameplatesEnabled == true then
      AddNameplateInfo(info, unit)
      return logic.PickNameplatePair(gradient, info), gradient.nameplateFadeDirection
    end
    return logic.PickGradientPair(gradient, info)
  end
  if kind == "power" then
    local id, token = Safe(UnitPowerType, unit or "player")
    return logic.PickBarPair(gradient, kind, { powerKey = logic.PowerKey(token, id) })
  end
  if kind == "castbar" then
    return logic.PickBarPair(gradient, kind, { nonInterruptible = CastNonInterruptible(bar, unit) })
  end
  local key = logic.ResourceKey(PlayerClassFile(), state.index, PlayerSpecIndex())
  return logic.PickBarPair(gradient, kind, { resourceKey = key })
end

function Gradient:Paint(bar)
  if not active then
    return
  end
  local gradient = RakaMod.db and RakaMod.db.gradient
  if type(gradient) ~= "table" or gradient.enabled ~= true then
    return
  end
  local state = StateOf(bar)
  if not KindEnabled(gradient, state.kind or "health") then
    if state.painted then
      RestoreBar(bar)
    end
    return
  end
  local unit = ResolveUnit(bar)
  local chosen, direction = ChoosePair(bar, state, gradient, unit)
  if type(chosen) ~= "table" then
    -- No pair for this bar (e.g. unconfigured power type): clear any prior gradient.
    if state.painted then
      RestoreBar(bar)
    end
    return
  end
  local left, right = RakaMod.Logic.OrientPair(chosen, direction)
  if type(left) ~= "table" or type(right) ~= "table" then
    if state.painted then
      RestoreBar(bar)
    end
    return
  end
  local ok = pcall(function()
    bar:GetStatusBarTexture():SetGradient(
      "HORIZONTAL",
      CreateColor(left.r, left.g, left.b, 1),
      CreateColor(right.r, right.g, right.b, 1)
    )
  end)
  if ok then
    state.painted = true
  elseif state.painted then
    RestoreBar(bar)
  end
end

-- Post-hook on the bar's own SetStatusBarColor (never replaces the method, so Ellesmere's
-- colouring and any other hooks keep working). hooksecurefunc cannot be undone, so the
-- module-level `active` flag decides whether the hook paints.
function Gradient:Hook(bar, unitHint, opts)
  if not bar or not bar.SetStatusBarColor then
    return
  end
  local state = StateOf(bar)
  if type(unitHint) == "string" and unitHint ~= "" then
    state.unit = unitHint
  end
  if type(opts) == "table" then
    state.kind = state.kind or opts.kind
    state.index = opts.index or state.index
    if opts.nameplate then
      state.nameplate = true
    end
  end
  if state.hooked then
    return
  end
  state.hooked = true
  if bar.GetStatusBarColor then
    local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
    if ok and type(r) == "number" then
      local color = state.lastColor
      if not color then
        color = { r, g, b, a }
        state.lastColor = color
      else
        color[1], color[2], color[3], color[4] = r, g, b, a
      end
    end
  end
  hooked[#hooked + 1] = bar
  hooksecurefunc(bar, "SetStatusBarColor", function(hookedBar, r, g, b, a)
    local st = barState[hookedBar]
    if not st then
      return
    end
    local color = st.lastColor
    if not color then
      color = { r, g, b, a }
      st.lastColor = color
    else
      color[1], color[2], color[3], color[4] = r, g, b, a
    end
    if active then
      RakaMod.Gradient:Paint(hookedBar)
    end
  end)
end

-- Events only some bar kinds need; registered while the matching switch is on. RegisterEvent
-- raises on event names a client does not know, so every call is protected.
local OPTIONAL_EVENTS = {
  power = { "UNIT_DISPLAYPOWER" },
  castbar = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
  },
  resource = { "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM" },
  nameplate = { "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE" },
}
local ALL_BARS_EVENTS = { PLAYER_SPECIALIZATION_CHANGED = true, UPDATE_SHAPESHIFT_FORM = true }
-- Threat payloads are often "player" (situation) or a mob token (list). Either way every
-- nameplate may need a new pair, so these force a full repaint rather than unit filtering.
local NAMEPLATE_THREAT_EVENTS = {
  UNIT_THREAT_SITUATION_UPDATE = true,
  UNIT_THREAT_LIST_UPDATE = true,
}
local optionalRegistered = {}

local function SyncEvents()
  local gradient = RakaMod.db and RakaMod.db.gradient
  local wanted = {}
  if active and type(gradient) == "table" and gradient.enabled == true then
    local switches = {
      power = gradient.powerEnabled,
      castbar = gradient.castbarEnabled,
      resource = gradient.resourcesEnabled,
      nameplate = gradient.nameplatesEnabled,
    }
    for group, on in pairs(switches) do
      if on == true then
        for _, event in ipairs(OPTIONAL_EVENTS[group]) do
          wanted[event] = true
        end
      end
    end
  end
  for event in pairs(wanted) do
    if not optionalRegistered[event] then
      optionalRegistered[event] = pcall(events.RegisterEvent, events, event) or nil
    end
  end
  for event in pairs(optionalRegistered) do
    if not wanted[event] then
      pcall(events.UnregisterEvent, events, event)
      optionalRegistered[event] = nil
    end
  end
end

function Gradient:Apply()
  if not active then
    return
  end
  SyncEvents()
  local gradient = RakaMod.db and RakaMod.db.gradient
  if type(gradient) ~= "table" or gradient.enabled ~= true then
    return
  end
  for i = 1, #hooked do
    self:Paint(hooked[i])
  end
end

local function HookRaidHealth(buttons, getFFD)
  if not buttons or not getFFD then
    return
  end
  for i = 1, #buttons do
    pcall(function()
      local button = buttons[i]
      local data = getFFD(button)
      local health = data and data.health
      if health and health.GetObjectType and health:GetObjectType() == "StatusBar" then
        local unit = button and button.unit
        RakaMod.Gradient:Hook(health, unit)
      end
      local power = data and data.power
      if power and power.GetObjectType and power:GetObjectType() == "StatusBar" then
        RakaMod.Gradient:Hook(power, button and button.unit, { kind = "power" })
      end
    end)
  end
end

local function Rescan()
  local found = {}
  if AddonOn("EllesmereUIUnitFrames") then
    for i = 1, #UNIT_GLOBALS do
      pcall(Scan, _G[UNIT_GLOBALS[i]], 1, found, nil, nil)
    end
  end
  if AddonOn("EllesmereUIRaidFrames") then
    local rf = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUIRaidFrames
    local getFFD = rf and (rf.GetFFD or (rf._internals and rf._internals.GetFFD))
    local internals = rf and rf._internals
    local raidButtons = rf and (rf._allButtons or (internals and internals.allButtons))
    local partyButtons = rf and (rf._partyAllButtons or (internals and internals.partyAllButtons))
    HookRaidHealth(raidButtons, getFFD)
    HookRaidHealth(partyButtons, getFFD)
  end
  if AddonOn("EllesmereUINameplates") then
    local np = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUINameplates
    local plates = np and np.plates
    if plates then
      for _, plate in pairs(plates) do
        pcall(function()
          local health = plate and plate.health
          if health and health.GetObjectType and health:GetObjectType() == "StatusBar" then
            RakaMod.Gradient:Hook(health, plate.unit, { kind = "health", nameplate = true })
          end
          Scan(plate, 2, found, { unit = plate.unit, nameplate = true }, nil)
        end)
      end
    end
  end
  Gradient:Apply()
end

-- Events only mark work as pending; one flush per throttle window does the repaint.
local function Flush()
  flushScheduled = false
  if not active then
    pending = {}
    pendingAll = false
    pendingRescan = false
    return
  end
  if pendingRescan then
    pendingRescan = false
    pendingAll = false
    pending = {}
    Rescan()
    return
  end
  local all = pendingAll
  local units = pending
  pendingAll = false
  pending = {}
  for i = 1, #hooked do
    local bar = hooked[i]
    if all or units[ResolveUnit(bar)] then
      Gradient:Paint(bar)
    end
  end
end

local function Schedule()
  if flushScheduled then
    return
  end
  flushScheduled = true
  if C_Timer and C_Timer.After then
    C_Timer.After(THROTTLE_SECONDS, Flush)
  else
    Flush()
  end
end

function Gradient:OnGameEvent(event, unit)
  if event == "GROUP_ROSTER_UPDATE" or event == "NAME_PLATE_UNIT_ADDED" then
    pendingRescan = true
  elseif event == "UNIT_FLAGS" or event == "UNIT_CONNECTION" then
    if type(unit) ~= "string" or IsSecret(unit) then
      return
    end
    pending[unit] = true
  elseif event == "PLAYER_TARGET_CHANGED" then
    pending.target = true
    pending.targettarget = true
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    pending.mouseover = true
  elseif ALL_BARS_EVENTS[event] then
    pendingAll = true
  elseif NAMEPLATE_THREAT_EVENTS[event] and optionalRegistered[event] then
    pendingAll = true
  elseif optionalRegistered[event] then
    if type(unit) ~= "string" or IsSecret(unit) then
      return
    end
    pending[unit] = true
  else
    return
  end
  Schedule()
end

function Gradient:Enable()
  if not AddonOn("EllesmereUIUnitFrames")
    and not AddonOn("EllesmereUIRaidFrames")
    and not AddonOn("EllesmereUINameplates") then
    return
  end
  active = true
  events:RegisterEvent("GROUP_ROSTER_UPDATE")
  events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  events:RegisterEvent("UNIT_FLAGS")
  events:RegisterEvent("UNIT_CONNECTION")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  SyncEvents()
  Rescan()
end

function Gradient:Disable()
  active = false
  events:UnregisterEvent("GROUP_ROSTER_UPDATE")
  events:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
  events:UnregisterEvent("UNIT_FLAGS")
  events:UnregisterEvent("UNIT_CONNECTION")
  events:UnregisterEvent("PLAYER_TARGET_CHANGED")
  events:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
  SyncEvents()
  pending = {}
  pendingAll = false
  pendingRescan = false
  flushScheduled = false
  for i = 1, #hooked do
    RestoreBar(hooked[i])
  end
end

events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
  Gradient:OnGameEvent(event, unit)
end)

RakaMod.Core:RegisterModule({
  name = "Gradient",
  dbKey = "gradient",
  requires = nil,
  OnLoad = function(self) end,
  OnEnable = function(self) RakaMod.Gradient:Enable() end,
  OnDisable = function(self) RakaMod.Gradient:Disable() end,
})
