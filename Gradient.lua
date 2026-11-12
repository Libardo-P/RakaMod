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

local RAID_PREFIX = "EllesmereUIRaidFrames"
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

function Gradient:Hook(bar)
  if not bar or bar.RakaModHooked then
    return
  end
  bar.RakaModHooked = true
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
    if RakaMod.db.gradient.enabled then
      RakaMod.Gradient:Paint(bar)
    end
  end
end

function Gradient:Paint(bar)
  local gradient = RakaMod.db and RakaMod.db.gradient
  local left = gradient and gradient.left
  local right = gradient and gradient.right
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

local function Rescan(unit)
  local found = {}
  if AddonOn("EllesmereUIUnitFrames") then
    for i = 1, #UNIT_GLOBALS do
      pcall(Scan, _G[UNIT_GLOBALS[i]], 1, found)
    end
  end
  if AddonOn("EllesmereUIRaidFrames") then
    for name, object in pairs(_G) do
      if type(name) == "string" and string.sub(name, 1, #RAID_PREFIX) == RAID_PREFIX then
        pcall(Scan, object, 1, found)
      end
    end
  end
  if AddonOn("EllesmereUINameplates") and C_NamePlate then
    if C_NamePlate.GetNamePlates then
      local ok, plates = pcall(C_NamePlate.GetNamePlates)
      if ok and type(plates) == "table" then
        for _, plate in ipairs(plates) do
          pcall(Scan, plate, 1, found)
        end
      end
    end
    if unit and C_NamePlate.GetNamePlateForUnit then
      local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
      if ok then
        pcall(Scan, plate, 1, found)
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
  Rescan()
end

function Gradient:Disable()
  events:UnregisterEvent("GROUP_ROSTER_UPDATE")
  events:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
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
    end
    hooked[i] = nil
  end
end

events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
  if event == "GROUP_ROSTER_UPDATE" then
    Rescan()
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    Rescan(unit)
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
