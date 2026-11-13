RakaMod = RakaMod or {}

local MinimapIcon = {}
RakaMod.MinimapIcon = MinimapIcon

local ICON_NAME = "RakaMod"
local dataObject
local lastShow = nil

local function Db()
  return RakaMod.db and RakaMod.db.general
end

local function IconLib()
  return LibStub and LibStub("LibDBIcon-1.0", true)
end

local function EnsureDataObject()
  if dataObject then
    return dataObject
  end
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  if not ldb then
    return nil
  end
  local iconPath = (RakaMod.Media and RakaMod.Media.IconPath) or "Interface\\AddOns\\RakaMod\\Media\\icon"
  dataObject = ldb:NewDataObject(ICON_NAME, {
    type = "launcher",
    text = "RakaMod",
    icon = iconPath,
    OnClick = function(_, button)
      if InCombatLockdown and InCombatLockdown() then
        return
      end
      if button == "LeftButton" then
        RakaMod.OpenSettings()
      elseif button == "RightButton" or button == "MiddleButton" then
        local general = Db()
        if general then
          general.showMinimapIcon = false
          general.hide = true
        end
        lastShow = false
        local icon = IconLib()
        if icon and icon:IsRegistered(ICON_NAME) then
          -- Hide() (not LibDBIcon:Show/Refresh): Ellesmere tracks this as unwanted
          -- and removes the button from the group/ungroup bar.
          icon:Hide(ICON_NAME)
        end
        if RakaMod.Settings and RakaMod.Settings.SyncFromDB then
          RakaMod.Settings:SyncFromDB()
        end
      end
    end,
    OnTooltipShow = function(tooltip)
      if not tooltip or not tooltip.AddLine then
        return
      end
      tooltip:AddLine("RakaMod")
      tooltip:AddLine("Left-click: Open settings", 0.8, 0.8, 0.8)
      tooltip:AddLine("Right-click: Hide icon", 0.8, 0.8, 0.8)
    end,
  })
  return dataObject
end

-- Prefer frame Show/Hide over LibDBIcon:Show/Refresh. Refresh/Show call
-- updatePosition, which fights Ellesmere's minimap button bar layout.
local function SetShown(show)
  local icon = IconLib()
  if not icon or not icon:IsRegistered(ICON_NAME) then
    return
  end
  local button = icon:GetMinimapButton(ICON_NAME)
  if not button then
    return
  end
  if show then
    button:Show()
  else
    button:Hide()
  end
end

function MinimapIcon:Apply()
  local general = Db()
  if type(general) ~= "table" then
    return
  end
  local show = general.showMinimapIcon ~= false
  general.hide = not show

  local icon = IconLib()
  local obj = EnsureDataObject()
  if not icon or not obj then
    return
  end

  if not icon:IsRegistered(ICON_NAME) then
    if show then
      icon:Register(ICON_NAME, obj, general)
      lastShow = true
    else
      lastShow = false
    end
    return
  end

  if lastShow == show then
    return
  end
  lastShow = show
  SetShown(show)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  lastShow = nil
  MinimapIcon:Apply()
end)
