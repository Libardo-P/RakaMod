RakaMod = RakaMod or {}

local Settings = {}
RakaMod.Settings = Settings

local OUTLINES = { "NONE", "OUTLINE", "THICKOUTLINE" }
local ROW = 28
local VIEW_TOP = -36

local checks = {}
local sliders = {}
local swatches = {}
local applying = false
local skinned = false

local template = BackdropTemplateMixin and "BackdropTemplate" or nil
local frame = CreateFrame("Frame", "RakaModSettingsFrame", UIParent, template)
frame:SetSize(480, 560)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

if frame.SetBackdrop then
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
end

if UISpecialFrames then
  UISpecialFrames[#UISpecialFrames + 1] = "RakaModSettingsFrame"
end

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -12)
title:SetText("RakaMod")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)
close:SetScript("OnClick", function()
  frame:Hide()
end)
frame.Close = close

local scroll = CreateFrame("ScrollFrame", "RakaModSettingsScroll", frame, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 16, VIEW_TOP)
scroll:SetPoint("BOTTOMRIGHT", -32, 16)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(420, 680)
scroll:SetScrollChild(content)

local y = VIEW_TOP

local function LocalY()
  return y - VIEW_TOP
end

local function Advance()
  y = y - ROW
end

local function OnMouseWheel(_, delta)
  local step = delta > 0 and -ROW or ROW
  local nextScroll = (scroll:GetVerticalScroll() or 0) + step
  if nextScroll < 0 then
    nextScroll = 0
  end
  local maxScroll = scroll:GetVerticalScrollRange() or 0
  if nextScroll > maxScroll then
    nextScroll = maxScroll
  end
  scroll:SetVerticalScroll(nextScroll)
  local bar = scroll.ScrollBar or (scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"])
  if bar and bar.SetValue and bar:GetValue() ~= nextScroll then
    bar:SetValue(nextScroll)
  end
end

scroll:SetScript("OnMouseWheel", OnMouseWheel)

local function PassWheel(widget)
  widget:EnableMouseWheel(true)
  widget:SetScript("OnMouseWheel", OnMouseWheel)
end

local function PickColor(target, onChange)
  local previous = { r = target.r, g = target.g, b = target.b }
  local function write(r, g, b)
    target.r, target.g, target.b = r, g, b
    onChange()
  end
  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = target.r, g = target.g, b = target.b, opacity = 1, hasOpacity = false,
      swatchFunc = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        write(r, g, b)
      end,
      cancelFunc = function()
        write(previous.r, previous.g, previous.b)
      end,
    })
  else
    ColorPickerFrame.func = function()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      write(r, g, b)
    end
    ColorPickerFrame.cancelFunc = function()
      write(previous.r, previous.g, previous.b)
    end
    ColorPickerFrame:SetColorRGB(target.r, target.g, target.b)
    ColorPickerFrame:Show()
  end
end

local function NextOutline(current)
  local index = 0
  for i = 1, #OUTLINES do
    if OUTLINES[i] == current then
      index = i
      break
    end
  end
  return OUTLINES[(index % #OUTLINES) + 1]
end

local checkSerial = 0

local function AddCheck(text, section, key)
  checkSerial = checkSerial + 1
  local check = CreateFrame("CheckButton", "RakaModSettingsCheck" .. checkSerial, content, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  check:SetPoint("TOPLEFT", content, "TOPLEFT", 4, LocalY() - 2)
  local label = check.Text
  if not label then
    label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
  end
  label:SetText(text)
  check:SetScript("OnClick", function(self)
    local saved = RakaMod.db and RakaMod.db[section]
    if not saved then
      return
    end
    saved[key] = self:GetChecked() and true or false
    RakaMod.Core:RefreshModules()
  end)
  PassWheel(check)
  checks[#checks + 1] = { widget = check, section = section, key = key }
  Advance()
  return check
end

local function AddSlider(text, section, key, minValue, maxValue)
  local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", content, "TOPLEFT", 32, LocalY() - 6)
  label:SetText(text)

  local slider = CreateFrame("Slider", nil, content)
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("TOPLEFT", content, "TOPLEFT", 188, LocalY() - 6)
  slider:SetSize(150, 16)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then
    slider:SetObeyStepOnDrag(true)
  end
  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.2, 0.2, 0.2, 1)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local thumb = slider:GetThumbTexture()
  if thumb then
    thumb:SetSize(16, 16)
  end

  local valueText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  valueText:SetPoint("LEFT", slider, "RIGHT", 8, 0)

  slider:SetScript("OnValueChanged", function(self, value)
    local intValue = math.floor((value or 0) + 0.5)
    if intValue < minValue then
      intValue = minValue
    elseif intValue > maxValue then
      intValue = maxValue
    end
    valueText:SetText(tostring(intValue))
    if applying then
      return
    end
    if value ~= intValue then
      applying = true
      self:SetValue(intValue)
      applying = false
    end
    local saved = RakaMod.db and RakaMod.db[section]
    if not saved then
      return
    end
    saved[key] = intValue
    RakaMod.Core:RefreshModules()
    if section == "zoneText" and RakaMod.ZoneText and RakaMod.ZoneText.Apply then
      RakaMod.ZoneText:Apply()
    end
  end)
  PassWheel(slider)

  sliders[#sliders + 1] = {
    widget = slider,
    valueText = valueText,
    section = section,
    key = key,
    minValue = minValue,
  }
  Advance()
  return slider
end

local function AddColorButton(text, getTarget, onChange)
  local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", content, "TOPLEFT", 32, LocalY() - 6)
  label:SetText(text)

  local swatch = CreateFrame("Button", nil, content)
  swatch:SetSize(20, 20)
  swatch:SetPoint("TOPLEFT", content, "TOPLEFT", 188, LocalY() - 4)
  local edge = swatch:CreateTexture(nil, "BACKGROUND")
  edge:SetColorTexture(0, 0, 0, 1)
  edge:SetPoint("TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", 1, -1)
  local color = swatch:CreateTexture(nil, "ARTWORK")
  color:SetPoint("TOPLEFT", 1, -1)
  color:SetPoint("BOTTOMRIGHT", -1, 1)
  swatch.color = color

  local function paint()
    local target = getTarget()
    local r = target and target.r or 1
    local g = target and target.g or 1
    local b = target and target.b or 1
    color:SetColorTexture(r, g, b, 1)
  end

  swatch:SetScript("OnClick", function()
    local target = getTarget()
    if not target then
      return
    end
    PickColor(target, function()
      paint()
      onChange()
    end)
  end)
  PassWheel(swatch)
  swatches[#swatches + 1] = { paint = paint }
  Advance()
  return swatch
end

local function AddSwatch(text, which)
  return AddColorButton(text, function()
    local gradient = RakaMod.db and RakaMod.db.gradient
    return gradient and gradient[which]
  end, function()
    if RakaMod.Gradient and RakaMod.Gradient.Apply then
      RakaMod.Gradient:Apply()
    end
  end)
end

local function AddZoneSwatch(text)
  return AddColorButton(text, function()
    return RakaMod.db and RakaMod.db.zoneText
  end, function()
    RakaMod.Core:RefreshModules()
    if RakaMod.ZoneText and RakaMod.ZoneText.Apply then
      RakaMod.ZoneText:Apply()
    end
  end)
end

local function AddNote(text)
  local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", content, "TOPLEFT", 8, LocalY() - 8)
  note:SetWidth(400)
  note:SetJustifyH("LEFT")
  note:SetWordWrap(false)
  note:SetText(text)
  note:SetTextColor(1, 0.82, 0.2)
  Advance()
  return note
end

local overlayNote = AddNote("")
overlayNote:Hide()

AddCheck("Overlay enabled", "overlay", "enabled")
AddCheck("Collections", "overlay", "collections")
AddCheck("Played", "overlay", "played")
AddCheck("Professions", "overlay", "professions")

local revealNote = AddNote("EllesmereUI Unit Frames is not installed.")

AddCheck("Reveal enabled", "reveal", "enabled")
AddCheck("Casting", "reveal", "casting")
AddCheck("Health", "reveal", "health")
AddSlider("Health percent", "reveal", "healthPercent", 1, 100)
AddCheck("Mouseover", "reveal", "mouseover")
AddCheck("Combat", "reveal", "combat")
AddCheck("Pet", "reveal", "pet")

AddCheck("Zone text enabled", "zoneText", "enabled")
AddSlider("Size", "zoneText", "size", 8, 64)

local outlineLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
outlineLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 32, LocalY() - 6)
outlineLabel:SetText("Outline")

local outlineButton = CreateFrame("Button", nil, content)
outlineButton:SetSize(156, 22)
outlineButton:SetPoint("TOPLEFT", content, "TOPLEFT", 188, LocalY() - 3)
local outlineBg = outlineButton:CreateTexture(nil, "BACKGROUND")
outlineBg:SetAllPoints()
outlineBg:SetColorTexture(0.15, 0.15, 0.15, 1)
local outlineText = outlineButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
outlineText:SetPoint("CENTER")
outlineButton:SetFontString(outlineText)
outlineButton:SetText("OUTLINE")
outlineButton:SetScript("OnClick", function(self)
  local zoneText = RakaMod.db and RakaMod.db.zoneText
  if not zoneText then
    return
  end
  local nextValue = NextOutline(zoneText.outline)
  zoneText.outline = nextValue
  self:SetText(nextValue)
  RakaMod.Core:RefreshModules()
  if RakaMod.ZoneText and RakaMod.ZoneText.Apply then
    RakaMod.ZoneText:Apply()
  end
end)
PassWheel(outlineButton)
Advance()

AddZoneSwatch("Color")

AddCheck("AFK enabled", "afk", "enabled")
AddCheck("Camera pan", "afk", "cameraPan")

local gradientNote = AddNote("No Ellesmere health-bar module is installed.")

AddCheck("Gradient enabled", "gradient", "enabled")
AddSwatch("Left", "left")
AddSwatch("Right", "right")

content:SetHeight((VIEW_TOP - y) + 16)

local function SyncFromDB()
  local db = RakaMod.db
  if type(db) ~= "table" then
    return
  end
  applying = true
  for i = 1, #checks do
    local entry = checks[i]
    local section = db[entry.section]
    local value = section and section[entry.key]
    entry.widget:SetChecked(value and true or false)
  end
  for i = 1, #sliders do
    local entry = sliders[i]
    local section = db[entry.section]
    local value = section and section[entry.key]
    if type(value) ~= "number" then
      value = entry.minValue
    end
    entry.widget:SetValue(value)
    entry.valueText:SetText(tostring(math.floor(value + 0.5)))
  end
  if db.zoneText then
    outlineButton:SetText(db.zoneText.outline or "NONE")
  end
  for i = 1, #swatches do
    swatches[i].paint()
  end
  applying = false
end

function Settings:RefreshNotes()
  overlayNote:Hide()
  if RakaMod.Core:AddonLoaded("EllesmereUIUnitFrames") then
    revealNote:Hide()
  else
    revealNote:Show()
  end
  local healthBars = RakaMod.Core:AddonLoaded("EllesmereUIUnitFrames")
    or RakaMod.Core:AddonLoaded("EllesmereUIRaidFrames")
    or RakaMod.Core:AddonLoaded("EllesmereUINameplates")
  if healthBars then
    gradientNote:Hide()
  else
    gradientNote:Show()
  end
end

function Settings:Show()
  if not skinned and EllesmereUI and EllesmereUI.RegisterSkin then
    skinned = true
    EllesmereUI.RegisterSkin("RakaMod", function(S)
      if S.Shell then S.Shell(frame) end
      if S.CloseButton and frame.Close then S.CloseButton(frame.Close) end
    end)
  end
  local width = scroll:GetWidth()
  if width and width > 1 then
    content:SetWidth(width)
  end
  if scroll.UpdateScrollChildRect then
    scroll:UpdateScrollChildRect()
  end
  SyncFromDB()
  frame:Show()
  self:RefreshNotes()
end
