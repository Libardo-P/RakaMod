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

local function Scan(object, depth, found)
  if not object or depth > 3 or found[object] then
    return
  end
  found[object] = true
  if type(object) ~= "table" or not object.GetObjectType then
    return
  end
  for key, value in pairs(object) do
    if RakaMod.Logic.IsHealthBarKey(key) and type(value) == "table" and value.GetObjectType and value:GetObjectType() == "StatusBar" then
      RakaMod.Gradient:Hook(value)
    elseif type(value) == "table" and value.GetObjectType and depth < 3 then
      Scan(value, depth + 1, found)
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
  local info = {
    dead = false,
    offline = false,
    tapped = false,
    isPlayer = false,
    classFile = nil,
    reactionKey = "neutral",
  }
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

function Gradient:Paint(bar)
  if not active then
    return
  end
  local gradient = RakaMod.db and RakaMod.db.gradient
  if type(gradient) ~= "table" or gradient.enabled ~= true then
    return
  end
  local unit = ResolveUnit(bar)
  local info = UnitInfo(unit)
  local chosen = RakaMod.Logic.PickGradientPair(gradient, info)
  local left = chosen and chosen.left
  local right = chosen and chosen.right
  if type(left) ~= "table" or type(right) ~= "table" then
    return
  end
  pcall(function()
    bar:GetStatusBarTexture():SetGradient(
      "HORIZONTAL",
      CreateColor(left.r, left.g, left.b, 1),
      CreateColor(right.r, right.g, right.b, 1)
    )
  end)
end

-- Post-hook on the bar's own SetStatusBarColor (never replaces the method, so Ellesmere's
-- colouring and any other hooks keep working). hooksecurefunc cannot be undone, so the
-- module-level `active` flag decides whether the hook paints.
function Gradient:Hook(bar, unitHint)
  if not bar or not bar.SetStatusBarColor then
    return
  end
  local state = StateOf(bar)
  if type(unitHint) == "string" and unitHint ~= "" then
    state.unit = unitHint
  end
  if state.hooked then
    return
  end
  state.hooked = true
  if bar.GetStatusBarColor then
    local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
    if ok and type(r) == "number" then
      state.lastColor = { r, g, b, a }
    end
  end
  hooked[#hooked + 1] = bar
  hooksecurefunc(bar, "SetStatusBarColor", function(self, r, g, b, a)
    local st = barState[self]
    if not st then
      return
    end
    st.lastColor = { r, g, b, a }
    if active then
      RakaMod.Gradient:Paint(self)
    end
  end)
end

function Gradient:Apply()
  if not active then
    return
  end
  for i = 1, #hooked do
    self:Paint(hooked[i])
  end
end

-- Puts the bar back to the last flat colour Ellesmere gave it. SetStatusBarColor resets the
-- texture vertex colours; the explicit flat SetGradient is a belt-and-braces fallback for
-- clients where a previous gradient survives the vertex colour reset.
local function RestoreBar(bar)
  local state = barState[bar]
  local color = state and state.lastColor
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
    end)
  end
end

local function Rescan()
  local found = {}
  if AddonOn("EllesmereUIUnitFrames") then
    for i = 1, #UNIT_GLOBALS do
      pcall(Scan, _G[UNIT_GLOBALS[i]], 1, found)
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
            RakaMod.Gradient:Hook(health, plate.unit)
          end
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
  pending = {}
  pendingAll = false
  pendingRescan = false
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
