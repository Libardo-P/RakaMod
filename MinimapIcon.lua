RakaMod = RakaMod or {}

local MinimapIcon = {}
RakaMod.MinimapIcon = MinimapIcon

local BUTTON_SIZE = 32
local DEFAULT_ANGLE = 210
local btn
local currentAngle

local function Db()
  return RakaMod.db and RakaMod.db.general
end

local function GetAngle()
  if currentAngle then
    return currentAngle
  end
  local general = Db()
  currentAngle = (general and type(general.minimapIconAngle) == "number" and general.minimapIconAngle) or DEFAULT_ANGLE
  return currentAngle
end

local function SaveAngle()
  local general = Db()
  if not general then
    return
  end
  general.minimapIconAngle = currentAngle or DEFAULT_ANGLE
end

local function UpdatePosition()
  if not btn or not Minimap then
    return
  end
  local angle = math.rad(GetAngle())
  local mw, mh = Minimap:GetWidth(), Minimap:GetHeight()
  local radius = (math.max(mw or 140, mh or 140) / 2) + 5
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function DragOnUpdate()
  if not Minimap then
    return
  end
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale() or 1
  cx, cy = cx / scale, cy / scale
  currentAngle = math.deg(math.atan2(cy - my, cx - mx))
  UpdatePosition()
end

local function CreateButton()
  if btn or not Minimap then
    return btn
  end

  btn = CreateFrame("Button", "RakaModMinimapButton", Minimap)
  btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:SetClampedToScreen(true)
  btn:SetMovable(true)
  btn:RegisterForClicks("anyUp")
  btn:RegisterForDrag("LeftButton")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(25, 25)
  bg:SetPoint("CENTER", 0, 0)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetVertexColor(0, 0, 0, 1)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetPoint("CENTER", 0, 0)
  if RakaMod.Media and RakaMod.Media.StatusbarPath then
    icon:SetTexture(RakaMod.Media.StatusbarPath)
  else
    icon:SetTexture("Interface\\Buttons\\WHITE8x8")
  end
  icon:SetVertexColor(0.45, 0.70, 0.95, 1)

  local overlay = btn:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetPoint("TOPLEFT", 0, 0)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  btn:SetScript("OnClick", function(_, button)
    if InCombatLockdown and InCombatLockdown() then
      return
    end
    if button == "LeftButton" then
      RakaMod.OpenSettings()
    elseif button == "RightButton" or button == "MiddleButton" then
      local general = Db()
      if general then
        general.showMinimapIcon = false
      end
      btn:Hide()
      if RakaMod.Settings and RakaMod.Settings.SyncFromDB then
        RakaMod.Settings:SyncFromDB()
      end
    end
  end)

  btn:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then
      return
    end
    self:LockHighlight()
    self:SetScript("OnUpdate", DragOnUpdate)
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
    SaveAngle()
    UpdatePosition()
  end)

  btn:SetScript("OnEnter", function(self)
    if InCombatLockdown and InCombatLockdown() then
      return
    end
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("RakaMod")
    GameTooltip:AddLine("Left-click: Open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: Move", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: Hide icon", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  UpdatePosition()
  return btn
end

function MinimapIcon:Apply()
  local general = Db()
  local show = not general or general.showMinimapIcon ~= false
  if show then
    CreateButton()
    if btn then
      btn:Show()
      UpdatePosition()
    end
  elseif btn then
    btn:Hide()
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  MinimapIcon:Apply()
end)
