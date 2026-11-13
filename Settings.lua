RakaMod = RakaMod or {}

local Settings = {}
RakaMod.Settings = Settings

local ACCENT = { r = 0.45, g = 0.70, b = 0.95 }
local SIDEBAR_WIDTH = 140
local NAV_HEIGHT = 28
local NAV_GAP = 4
local NAV_PAD = 6
local OUTLINES = { "NONE", "OUTLINE", "THICKOUTLINE" }
local ROW = 28

local checks = {}
local sliders = {}
local swatches = {}
local outlineButton
local applying = false
local skinned = false
local pages = {}
local selectedKey = "overlay"
local revealNote
local gradientNote

local NAV = {
  { key = "overlay", label = "Overlay" },
  { key = "reveal", label = "Player Frame" },
  { key = "zoneText", label = "Zone Text" },
  { key = "afk", label = "AFK" },
  { key = "gradient", label = "Gradient" },
}

local template = BackdropTemplateMixin and "BackdropTemplate" or nil
local frame = CreateFrame("Frame", "RakaModSettingsFrame", UIParent, template)
frame:SetSize(640, 520)
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
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
  frame:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.85)
else
  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(0.08, 0.08, 0.10, 0.95)
end

if UISpecialFrames then
  UISpecialFrames[#UISpecialFrames + 1] = "RakaModSettingsFrame"
end

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -12)
title:SetText("RakaMod")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -4, -4)
close:SetScript("OnClick", function()
  frame:Hide()
end)
frame.Close = close

local function ApplyDarkPanel(target, r, g, b, a)
  if not target.SetBackdrop then
    local fill = target:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(r, g, b, a)
    return
  end
  target:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  target:SetBackdropColor(r, g, b, a)
  target:SetBackdropBorderColor(0.20, 0.22, 0.26, 0.90)
end

local sidebar = CreateFrame("Frame", nil, frame, template)
sidebar:SetPoint("TOPLEFT", 12, -40)
sidebar:SetPoint("BOTTOMLEFT", 12, 12)
sidebar:SetWidth(SIDEBAR_WIDTH)
ApplyDarkPanel(sidebar, 0.11, 0.11, 0.13, 0.95)

local contentHost = CreateFrame("Frame", nil, frame, template)
contentHost:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
contentHost:SetPoint("BOTTOMRIGHT", -12, 12)
ApplyDarkPanel(contentHost, 0.07, 0.07, 0.09, 0.95)

local function PaintNav(button, selected)
  button.selected = selected and true or false
  if button.SetBackdropColor then
    if button.selected then
      button:SetBackdropColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
      button:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.90)
    else
      button:SetBackdropColor(0.12, 0.12, 0.14, 0.95)
      button:SetBackdropBorderColor(0.18, 0.18, 0.22, 0.80)
    end
  end
  if button.highlight then
    if button.selected then
      button.highlight:Show()
    else
      button.highlight:Hide()
    end
  end
  if button.selected then
    button.label:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
  else
    button.label:SetTextColor(0.82, 0.82, 0.84)
  end
end

function Settings:SelectPage(key)
  if not pages[key] then
    return
  end
  selectedKey = key
  for pageKey, entry in pairs(pages) do
    local selected = pageKey == key
    if entry.page then
      if selected then
        entry.page:Show()
      else
        entry.page:Hide()
      end
    end
    if entry.button then
      PaintNav(entry.button, selected)
    end
  end
end

for i = 1, #NAV do
  local nav = NAV[i]
  local button = CreateFrame("Button", nil, sidebar, template)
  local yOff = -NAV_PAD - (i - 1) * (NAV_HEIGHT + NAV_GAP)
  button:SetHeight(NAV_HEIGHT)
  button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", NAV_PAD, yOff)
  button:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -NAV_PAD, yOff)

  if button.SetBackdrop then
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
  else
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.12, 0.12, 0.14, 0.95)
    local highlight = button:CreateTexture(nil, "BORDER")
    highlight:SetAllPoints()
    highlight:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
    highlight:Hide()
    button.highlight = highlight
  end

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", 10, 0)
  label:SetJustifyH("LEFT")
  label:SetText(nav.label)
  button.label = label

  button:SetScript("OnClick", function()
    Settings:SelectPage(nav.key)
  end)
  button:SetScript("OnEnter", function(self)
    if self.selected or not self.SetBackdropColor then
      return
    end
    self:SetBackdropColor(0.18, 0.20, 0.24, 0.95)
  end)
  button:SetScript("OnLeave", function(self)
    PaintNav(self, self.selected)
  end)

  pages[nav.key] = { button = button }
end

local function OnMouseWheel(scroll, delta)
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

local function PassWheel(scroll, widget)
  widget:EnableMouseWheel(true)
  widget:SetScript("OnMouseWheel", function(_, delta)
    OnMouseWheel(scroll, delta)
  end)
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

local function CreatePage(key)
  local page = CreateFrame("Frame", nil, contentHost)
  page:SetAllPoints()
  page:Hide()

  local scroll = CreateFrame("ScrollFrame", "RakaModSettingsScroll_" .. key, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  scroll:SetScript("OnMouseWheel", function(_, delta)
    OnMouseWheel(scroll, delta)
  end)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(400, 400)
  scroll:SetScrollChild(content)

  local y = 0
  local ctx = {
    key = key,
    page = page,
    scroll = scroll,
    content = content,
    LocalY = function() return y end,
    Advance = function() y = y - ROW end,
    Finish = function()
      content:SetHeight((-y) + 16)
    end,
  }
  pages[key].page = page
  pages[key].ctx = ctx
  return ctx
end

local checkSerial = 0

local function AddCheck(ctx, text, section, key)
  checkSerial = checkSerial + 1
  local check = CreateFrame("CheckButton", "RakaModSettingsCheck" .. checkSerial, ctx.content, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  check:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 4, ctx.LocalY() - 2)
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
  PassWheel(ctx.scroll, check)
  checks[#checks + 1] = { widget = check, section = section, key = key }
  ctx.Advance()
  return check
end

local function AddSlider(ctx, text, section, key, minValue, maxValue)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 32, ctx.LocalY() - 6)
  label:SetText(text)

  local slider = CreateFrame("Slider", nil, ctx.content)
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 188, ctx.LocalY() - 6)
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

  local valueText = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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
  PassWheel(ctx.scroll, slider)

  sliders[#sliders + 1] = {
    widget = slider,
    valueText = valueText,
    section = section,
    key = key,
    minValue = minValue,
  }
  ctx.Advance()
  return slider
end

local function AddColorButton(ctx, text, getTarget, onChange)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 32, ctx.LocalY() - 6)
  label:SetText(text)

  local swatch = CreateFrame("Button", nil, ctx.content)
  swatch:SetSize(20, 20)
  swatch:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 188, ctx.LocalY() - 4)
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
    local r, g, b = 1, 1, 1
    if target then
      if type(target.r) == "number" then r = target.r end
      if type(target.g) == "number" then g = target.g end
      if type(target.b) == "number" then b = target.b end
    end
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
  PassWheel(ctx.scroll, swatch)
  swatches[#swatches + 1] = { paint = paint }
  ctx.Advance()
  return swatch
end

local function AddSwatch(ctx, text, which)
  return AddColorButton(ctx, text, function()
    local gradient = RakaMod.db and RakaMod.db.gradient
    return gradient and gradient[which]
  end, function()
    if RakaMod.Gradient and RakaMod.Gradient.Apply then
      RakaMod.Gradient:Apply()
    end
  end)
end

local function AddZoneSwatch(ctx, text)
  return AddColorButton(ctx, text, function()
    return RakaMod.db and RakaMod.db.zoneText
  end, function()
    RakaMod.Core:RefreshModules()
    if RakaMod.ZoneText and RakaMod.ZoneText.Apply then
      RakaMod.ZoneText:Apply()
    end
  end)
end

local function AddNote(ctx, text)
  local note = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 8, ctx.LocalY() - 8)
  note:SetWidth(400)
  note:SetJustifyH("LEFT")
  note:SetWordWrap(false)
  note:SetText(text)
  note:SetTextColor(1, 0.82, 0.2)
  ctx.Advance()
  return note
end

local function AddDescription(ctx, text)
  local header = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 8, ctx.LocalY() - 4)
  header:SetText("Description")
  header:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
  ctx.Advance()

  local body = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  body:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 8, ctx.LocalY() - 4)
  body:SetWidth(380)
  body:SetJustifyH("LEFT")
  body:SetWordWrap(true)
  body:SetText(text)
  body:SetTextColor(1, 1, 1)
  ctx.Advance()
  ctx.Advance() -- second row so wrapped descriptions do not overlap controls
  return body
end

local function AddOutlineButton(ctx)
  local outlineLabel = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  outlineLabel:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 32, ctx.LocalY() - 6)
  outlineLabel:SetText("Outline")

  outlineButton = CreateFrame("Button", nil, ctx.content)
  outlineButton:SetSize(156, 22)
  outlineButton:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 188, ctx.LocalY() - 3)
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
  PassWheel(ctx.scroll, outlineButton)
  ctx.Advance()
  return outlineButton
end

local overlay = CreatePage("overlay")
AddDescription(overlay, "Escape overlay buttons (collections / played / professions).")
AddCheck(overlay, "Enabled", "overlay", "enabled")
AddCheck(overlay, "Collections", "overlay", "collections")
AddCheck(overlay, "Played", "overlay", "played")
AddCheck(overlay, "Professions", "overlay", "professions")
overlay.Finish()

local reveal = CreatePage("reveal")
AddDescription(reveal, "Show the player frame when casting, low health, mouseover, or combat.")
AddCheck(reveal, "Enabled", "reveal", "enabled")
AddCheck(reveal, "Casting", "reveal", "casting")
AddCheck(reveal, "Health", "reveal", "health")
AddSlider(reveal, "Health percent", "reveal", "healthPercent", 1, 100)
AddCheck(reveal, "Mouseover", "reveal", "mouseover")
AddCheck(reveal, "Combat", "reveal", "combat")
AddCheck(reveal, "Pet", "reveal", "pet")
revealNote = AddNote(reveal, "EllesmereUI Unit Frames is not installed.")
reveal.Finish()

local zoneText = CreatePage("zoneText")
AddDescription(zoneText, "Custom zone change text appearance.")
AddCheck(zoneText, "Enabled", "zoneText", "enabled")
AddSlider(zoneText, "Size", "zoneText", "size", 8, 64)
AddOutlineButton(zoneText)
AddZoneSwatch(zoneText, "Color")
zoneText.Finish()

local afk = CreatePage("afk")
AddDescription(afk, "Full AFK screen behavior.")
AddCheck(afk, "Enabled", "afk", "enabled")
AddCheck(afk, "Camera pan", "afk", "cameraPan")
afk.Finish()

local gradient = CreatePage("gradient")
AddDescription(gradient, "Two-color health bar gradient via Ellesmere modules.")
AddCheck(gradient, "Enabled", "gradient", "enabled")
AddSwatch(gradient, "Left", "left")
AddSwatch(gradient, "Right", "right")
gradientNote = AddNote(gradient, "No Ellesmere health-bar module is installed.")
gradient.Finish()

Settings:SelectPage("overlay")

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
  if outlineButton and db.zoneText then
    outlineButton:SetText(db.zoneText.outline or "NONE")
  end
  for i = 1, #swatches do
    swatches[i].paint()
  end
  applying = false
end

function Settings:RefreshNotes()
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

local function UpdateScrollChildWidth(key)
  local entry = pages[key]
  local ctx = entry and entry.ctx
  if not ctx or not ctx.scroll or not ctx.content then
    return
  end
  local width = ctx.scroll:GetWidth()
  if not width or width <= 1 then
    local hostWidth = contentHost:GetWidth()
    if hostWidth and hostWidth > 36 then
      width = hostWidth - 36
    end
  end
  if width and width > 1 then
    ctx.content:SetWidth(width)
  end
  if ctx.scroll.UpdateScrollChildRect then
    ctx.scroll:UpdateScrollChildRect()
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
  SyncFromDB()
  self:SelectPage(selectedKey or "overlay")
  frame:Show()
  self:RefreshNotes()
  for i = 1, #NAV do
    UpdateScrollChildWidth(NAV[i].key)
  end
end
