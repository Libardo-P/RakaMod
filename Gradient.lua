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

local hooked = {}
local events

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
  if bar and type(bar.RakaModUnit) == "string" and bar.RakaModUnit ~= "" then
    return bar.RakaModUnit
  end
  local frame = bar
  for _ = 1, 10 do
    if not frame then
      break
    end
    if type(frame.unit) == "string" and frame.unit ~= "" then
      return frame.unit
    end
    if frame.GetAttribute then
      local ok, unit = pcall(frame.GetAttribute, frame, "unit")
      if ok and type(unit) == "string" and unit ~= "" then
        return unit
      end
    end
    frame = frame.GetParent and frame:GetParent() or nil
  end
  return nil
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  local ok, result = pcall(fn, ...)
  if ok then
    return result and true or false, result
  end
  return false
end

local function UnitInfo(unit)
  local info = {
    dead = false,
    offline = false,
    disconnected = false,
    tapped = false,
    isPlayer = false,
    classFile = nil,
    reactionKey = "neutral",
  }
  if type(unit) ~= "string" or unit == "" then
    return info
  end
  if not UnitExists or not UnitExists(unit) then
    return info
  end

  info.dead = SafeCall(UnitIsDeadOrGhost, unit) and true or false

  local isPlayer = SafeCall(UnitIsPlayer, unit) and true or false
  info.isPlayer = isPlayer

  local connected = true
  if UnitIsConnected then
    local ok, value = pcall(UnitIsConnected, unit)
    if ok then
      connected = value and true or false
    end
  end
  if isPlayer and not connected then
    info.offline = true
  end

  if UnitIsTapDenied then
    info.tapped = SafeCall(UnitIsTapDenied, unit) and true or false
  elseif UnitIsTapped and UnitIsTappedByPlayer then
    local tapped = SafeCall(UnitIsTapped, unit)
    local byPlayer = SafeCall(UnitIsTappedByPlayer, unit)
    info.tapped = tapped and not byPlayer
  end

  if isPlayer and UnitClass then
    local ok, _, classFile = pcall(UnitClass, unit)
    if ok and type(classFile) == "string" then
      info.classFile = classFile
    end
  end

  if UnitReaction then
    local ok, reaction = pcall(UnitReaction, unit, "player")
    if ok then
      info.reactionKey = RakaMod.Logic.ReactionKey(reaction)
    end
  end

  return info
end

function Gradient:Hook(bar, unitHint)
  if not bar or bar.RakaModHooked then
    if bar and type(unitHint) == "string" and unitHint ~= "" then
      bar.RakaModUnit = unitHint
    end
    return
  end
  bar.RakaModHooked = true
  if type(unitHint) == "string" and unitHint ~= "" then
    bar.RakaModUnit = unitHint
  end
  bar.RakaModOriginalColor = bar.SetStatusBarColor
  if not bar.RakaModLastColor and bar.GetStatusBarColor then
    local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
    if ok and type(r) == "number" then
      bar.RakaModLastColor = { r, g, b, a }
    end
  end
  hooked[#hooked + 1] = bar
  function bar:SetStatusBarColor(r, g, b, a)
    bar.RakaModLastColor = { r, g, b, a }
    bar.RakaModOriginalColor(bar, r, g, b, a)
    if RakaMod.db and RakaMod.db.gradient and RakaMod.db.gradient.enabled then
      RakaMod.Gradient:Paint(bar)
    end
  end
end

function Gradient:Paint(bar)
  local gradient = RakaMod.db and RakaMod.db.gradient
  if type(gradient) ~= "table" then
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

function Gradient:Apply()
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

function Gradient:Enable()
  if not AddonOn("EllesmereUIUnitFrames")
    and not AddonOn("EllesmereUIRaidFrames")
    and not AddonOn("EllesmereUINameplates") then
    return
  end
  events:RegisterEvent("GROUP_ROSTER_UPDATE")
  events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  events:RegisterEvent("UNIT_FLAGS")
  events:RegisterEvent("UNIT_CONNECTION")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  Rescan()
end

function Gradient:Disable()
  events:UnregisterEvent("GROUP_ROSTER_UPDATE")
  events:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
  events:UnregisterEvent("UNIT_FLAGS")
  events:UnregisterEvent("UNIT_CONNECTION")
  events:UnregisterEvent("PLAYER_TARGET_CHANGED")
  events:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
  for i = 1, #hooked do
    local bar = hooked[i]
    local original = bar and bar.RakaModOriginalColor
    if type(original) == "function" then
      bar.SetStatusBarColor = original
      local color = bar.RakaModLastColor
      if type(color) == "table" then
        pcall(original, bar, color[1], color[2], color[3], color[4])
      end
    end
    if bar then
      bar.RakaModHooked = nil
      bar.RakaModUnit = nil
    end
    hooked[i] = nil
  end
end

events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
  if event == "GROUP_ROSTER_UPDATE" or event == "NAME_PLATE_UNIT_ADDED" then
    Rescan()
  else
    Gradient:Apply()
  end
end)

RakaMod.Core:RegisterModule({
  name = "Gradient",
  dbKey = "gradient",
  requires = nil,
  OnLoad = function(self) end,
  OnEnable = function(self) RakaMod.Gradient:Enable() end,
  OnDisable = function(self) RakaMod.Gradient:Disable() end,
})
