RakaMod = RakaMod or {}

local Settings = {}
RakaMod.Settings = Settings

-- Ellesmere-inspired shell palette (not a clone of EUI chrome).
local ACCENT = { r = 0.20, g = 0.55, b = 1.00 }
local SHELL = { r = 0.04, g = 0.05, b = 0.08 }
local SIDEBAR_BG = { r = 0.035, g = 0.045, b = 0.07 }
local CONTENT_BG = { r = 0.05, g = 0.06, b = 0.09 }
local MUTED = { r = 0.55, g = 0.58, b = 0.64 }
local SIDEBAR_WIDTH = 200
local NAV_HEIGHT = 26
local NAV_GAP = 2
local NAV_PAD = 12
local NAV_ITEM_INDENT = 6
local HEADER_HEIGHT = 18
local HEADER_GAP = 12
local BRAND_HEIGHT = 52
local OUTLINES = { "NONE", "OUTLINE", "THICKOUTLINE" }
local ROW = 30
local CONTROL_X = 220
local PILL_W, PILL_H = 40, 20

local checks = {}
local sliders = {}
local swatches = {}
local outlineButton
local applying = false
local skinned = false
local pages = {}
local selectedKey = "general"
local revealNote
local gradientNote
local navPageKeys = {}
local pageTitle
local pageDesc
local pageBody

local PAGE_META = {
  general = { title = "General", description = "Addon-wide options." },
  overlay = { title = "Game Menu", description = "Escape menu overlay buttons (collections / played / professions)." },
  afk = {
    title = "AFK Mode",
    description = "Full-screen AFK overlay with RakaMod branding, timer, character model, and Ellesmere patch notes. Dismiss with any key or click.",
  },
  reveal = {
    title = "Player Frame",
    description = "Force-show the Ellesmere player frame while casting, while effective health is above 100% (absorbs / overshield), on mouseover, or in combat. It never hides the frame itself.",
  },
  zoneText = { title = "Zone Text", description = "Custom zone change text appearance." },
  gradient = { title = "Gradient", description = "Health bar gradients shift by class, NPC reaction, and unit state." },
}

-- Category headers are non-clickable labels; items open existing pages.
local NAV = {
  { header = "CORE" },
  { key = "general", label = "General" },
  { header = "FEATURES" },
  { key = "overlay", label = "Game Menu" },
  { key = "afk", label = "AFK" },
  { header = "APPEARANCE" },
  { key = "reveal", label = "Player Frame" },
  { key = "zoneText", label = "Zone Text" },
  { key = "gradient", label = "Gradient" },
}

local template = BackdropTemplateMixin and "BackdropTemplate" or nil
local frame = CreateFrame("Frame", "RakaModSettingsFrame", UIParent, template)
frame:SetSize(920, 600)
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
  frame:SetBackdropColor(SHELL.r, SHELL.g, SHELL.b, 0.98)
  frame:SetBackdropBorderColor(0.12, 0.18, 0.28, 1)
else
  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(SHELL.r, SHELL.g, SHELL.b, 0.98)
end

if UISpecialFrames then
  UISpecialFrames[#UISpecialFrames + 1] = "RakaModSettingsFrame"
end

local function ApplyDarkPanel(target, r, g, b, a, borderA)
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
  target:SetBackdropBorderColor(0.10, 0.14, 0.22, borderA or 0.95)
end

local sidebar = CreateFrame("Frame", nil, frame, template)
sidebar:SetPoint("TOPLEFT", 0, 0)
sidebar:SetPoint("BOTTOMLEFT", 0, 0)
sidebar:SetWidth(SIDEBAR_WIDTH)
ApplyDarkPanel(sidebar, SIDEBAR_BG.r, SIDEBAR_BG.g, SIDEBAR_BG.b, 1, 0)

local brand = CreateFrame("Frame", nil, sidebar)
brand:SetPoint("TOPLEFT", 0, 0)
brand:SetPoint("TOPRIGHT", 0, 0)
brand:SetHeight(BRAND_HEIGHT)

local titleIconPath = (RakaMod.Media and RakaMod.Media.IconPath) or "Interface\\AddOns\\RakaMod\\Media\\icon"
local titleIcon = brand:CreateTexture(nil, "ARTWORK")
titleIcon:SetSize(28, 28)
titleIcon:SetPoint("LEFT", 14, 0)
titleIcon:SetTexture(titleIconPath)

local brandTitle = brand:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
brandTitle:SetPoint("LEFT", titleIcon, "RIGHT", 10, 0)
brandTitle:SetText("RakaMod")
brandTitle:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)

local brandRule = brand:CreateTexture(nil, "ARTWORK")
brandRule:SetColorTexture(0.12, 0.18, 0.28, 1)
brandRule:SetPoint("BOTTOMLEFT", 12, 0)
brandRule:SetPoint("BOTTOMRIGHT", -12, 0)
brandRule:SetHeight(1)

local contentHost = CreateFrame("Frame", nil, frame, template)
contentHost:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
contentHost:SetPoint("BOTTOMRIGHT", 0, 0)
ApplyDarkPanel(contentHost, CONTENT_BG.r, CONTENT_BG.g, CONTENT_BG.b, 1, 0)

local close = CreateFrame("Button", nil, contentHost, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
close:SetScript("OnClick", function()
  frame:Hide()
end)
frame.Close = close

local pageHeader = CreateFrame("Frame", nil, contentHost)
pageHeader:SetPoint("TOPLEFT", 20, -14)
pageHeader:SetPoint("TOPRIGHT", -40, -14)
pageHeader:SetHeight(52)

pageTitle = pageHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
pageTitle:SetPoint("TOPLEFT", 0, 0)
pageTitle:SetJustifyH("LEFT")
pageTitle:SetTextColor(1, 1, 1)

pageDesc = pageHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pageDesc:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)
pageDesc:SetPoint("TOPRIGHT", pageHeader, "TOPRIGHT", 0, -22)
pageDesc:SetJustifyH("LEFT")
pageDesc:SetWordWrap(true)
pageDesc:SetTextColor(MUTED.r, MUTED.g, MUTED.b)

local headerRule = pageHeader:CreateTexture(nil, "ARTWORK")
headerRule:SetColorTexture(0.12, 0.18, 0.28, 1)
headerRule:SetPoint("BOTTOMLEFT", 0, 0)
headerRule:SetPoint("BOTTOMRIGHT", 0, 0)
headerRule:SetHeight(1)

pageBody = CreateFrame("Frame", nil, contentHost)
pageBody:SetPoint("TOPLEFT", pageHeader, "BOTTOMLEFT", 0, -8)
pageBody:SetPoint("BOTTOMRIGHT", contentHost, "BOTTOMRIGHT", -8, 8)

local function AddonVersion()
  local ver
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    ver = C_AddOns.GetAddOnMetadata("RakaMod", "Version")
  elseif GetAddOnMetadata then
    ver = GetAddOnMetadata("RakaMod", "Version")
  end
  if type(ver) == "string" and ver ~= "" then
    return "v" .. ver
  end
  return "v0.2.0"
end

local versionText = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
versionText:SetPoint("BOTTOMLEFT", 14, 12)
versionText:SetText(AddonVersion())
versionText:SetTextColor(MUTED.r, MUTED.g, MUTED.b)

local function PaintNav(button, selected)
  button.selected = selected and true or false
  if button.SetBackdropColor then
    if button.selected then
      button:SetBackdropColor(ACCENT.r * 0.22, ACCENT.g * 0.22, ACCENT.b * 0.35, 0.95)
      button:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
    else
      button:SetBackdropColor(0, 0, 0, 0)
      button:SetBackdropBorderColor(0, 0, 0, 0)
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
    button.label:SetTextColor(1, 1, 1)
  else
    button.label:SetTextColor(0.70, 0.74, 0.80)
  end
end

local function UpdatePageHeader(key)
  local meta = PAGE_META[key]
  if pageTitle then
    pageTitle:SetText((meta and meta.title) or key or "")
  end
  if pageDesc then
    pageDesc:SetText((meta and meta.description) or "")
  end
end

function Settings:SelectPage(key)
  if not pages[key] then
    return
  end
  selectedKey = key
  UpdatePageHeader(key)
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

do
  local yOff = -(BRAND_HEIGHT + NAV_PAD)
  for i = 1, #NAV do
    local nav = NAV[i]
    if nav.header then
      if i > 1 then
        yOff = yOff - HEADER_GAP
      end
      local header = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      header:SetPoint("TOPLEFT", sidebar, "TOPLEFT", NAV_PAD, yOff)
      header:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -NAV_PAD, yOff)
      header:SetJustifyH("LEFT")
      header:SetText(nav.header)
      header:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
      yOff = yOff - HEADER_HEIGHT
    elseif nav.key then
      local button = CreateFrame("Button", nil, sidebar, template)
      button:SetHeight(NAV_HEIGHT)
      button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", NAV_PAD + NAV_ITEM_INDENT, yOff)
      button:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -NAV_PAD, yOff)

      if button.SetBackdrop then
        button:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8x8",
          edgeFile = "Interface\\Buttons\\WHITE8x8",
          edgeSize = 1,
          insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        button:SetBackdropColor(0, 0, 0, 0)
        button:SetBackdropBorderColor(0, 0, 0, 0)
      else
        local fill = button:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(0, 0, 0, 0)
        local highlight = button:CreateTexture(nil, "BORDER")
        highlight:SetAllPoints()
        highlight:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.18)
        highlight:Hide()
        button.highlight = highlight
      end

      local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      label:SetPoint("LEFT", 10, 0)
      label:SetJustifyH("LEFT")
      label:SetText(nav.label)
      label:SetTextColor(0.70, 0.74, 0.80)
      button.label = label

      button:SetScript("OnClick", function()
        Settings:SelectPage(nav.key)
      end)
      button:SetScript("OnEnter", function(self)
        if self.selected then
          return
        end
        if self.SetBackdropColor then
          self:SetBackdropColor(0.08, 0.12, 0.20, 0.55)
          self:SetBackdropBorderColor(0.16, 0.22, 0.32, 0.40)
        elseif self.highlight then
          self.highlight:Show()
        end
        self.label:SetTextColor(0.92, 0.94, 0.98)
      end)
      button:SetScript("OnLeave", function(self)
        PaintNav(self, self.selected)
      end)

      pages[nav.key] = { button = button }
      navPageKeys[#navPageKeys + 1] = nav.key
      yOff = yOff - (NAV_HEIGHT + NAV_GAP)
    end
  end
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

local colorClipboard = nil
local pickerSession = nil
local rakaPicker
local pickerButtons = {}
local pickerFields = {}
local editingRgb = false
local ORANGE = { r = 1, g = 0.82, b = 0.2 }

local function PlayerClassColor()
  local classFile
  if UnitClass then
    local ok, _, file = pcall(UnitClass, "player")
    if ok and type(file) == "string" then
      classFile = file
    end
  end
  if not classFile then
    return { r = 1, g = 1, b = 1 }
  end
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if type(c) == "table" and type(c.r) == "number" then
    return { r = c.r, g = c.g, b = c.b }
  end
  local fallback = RakaMod.Logic and RakaMod.Logic.CLASS_FALLBACK_COLORS and RakaMod.Logic.CLASS_FALLBACK_COLORS[classFile]
  if type(fallback) == "table" then
    return { r = fallback.r, g = fallback.g, b = fallback.b }
  end
  return { r = 1, g = 1, b = 1 }
end

local function ClampByte(value)
  value = tonumber(value) or 0
  if value < 0 then
    return 0
  end
  if value > 255 then
    return 255
  end
  return math.floor(value + 0.5)
end

local function Clamp01(value)
  if type(value) ~= "number" then
    return 0
  end
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

local function MakePickerButton(parent, text, width, height)
  local button = CreateFrame("Button", nil, parent, template)
  button:SetSize(width, height or 24)
  if button.SetBackdrop then
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(0.10, 0.10, 0.12, 1)
    button:SetBackdropBorderColor(0, 0, 0, 1)
  end
  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("CENTER")
  label:SetText(text)
  label:SetTextColor(ORANGE.r, ORANGE.g, ORANGE.b)
  button.label = label
  button:SetScript("OnEnter", function(self)
    if self:IsEnabled() and self.SetBackdropColor then
      self:SetBackdropColor(0.16, 0.16, 0.18, 1)
    end
  end)
  button:SetScript("OnLeave", function(self)
    if self.SetBackdropColor then
      self:SetBackdropColor(0.10, 0.10, 0.12, 1)
    end
  end)
  return button
end

local function MakeRgbBox(parent, width, maxLetters, numeric)
  local box = CreateFrame("EditBox", nil, parent, template)
  box:SetSize(width, 22)
  box:SetAutoFocus(false)
  box:SetMaxLetters(maxLetters)
  box:SetNumeric(numeric and true or false)
  box:SetJustifyH("CENTER")
  box:SetTextInsets(4, 4, 0, 0)
  box:SetFontObject(GameFontHighlight)
  box:SetTextColor(1, 1, 1)
  if box.SetBackdrop then
    box:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    box:SetBackdropColor(0.08, 0.08, 0.10, 1)
    box:SetBackdropBorderColor(0, 0, 0, 1)
  end
  return box
end

local function UpdatePasteButton()
  local paste = pickerButtons.paste
  if not paste then
    return
  end
  local has = type(colorClipboard) == "table"
  paste:SetEnabled(has)
  if has then
    paste:SetAlpha(1)
    paste.label:SetTextColor(ORANGE.r, ORANGE.g, ORANGE.b)
  else
    paste:SetAlpha(0.55)
    paste.label:SetTextColor(0.55, 0.55, 0.55)
  end
end

local function UpdateRgbFields(r, g, b)
  if editingRgb or not pickerFields.hex then
    return
  end
  if type(r) ~= "number" then
    if rakaPicker and rakaPicker.GetColorRGB then
      r, g, b = rakaPicker:GetColorRGB()
    else
      return
    end
  end
  local rb = ClampByte((r or 0) * 255)
  local gb = ClampByte((g or 0) * 255)
  local bb = ClampByte((b or 0) * 255)
  editingRgb = true
  pickerFields.hex:SetText(string.format("%02x%02x%02x", rb, gb, bb))
  pickerFields.r:SetText(tostring(rb))
  pickerFields.g:SetText(tostring(gb))
  pickerFields.b:SetText(tostring(bb))
  if pickerFields.newSwatch then
    pickerFields.newSwatch:SetColorTexture(r or 0, g or 0, b or 0, 1)
  end
  editingRgb = false
end

local function SetPickerRGB(r, g, b)
  r, g, b = Clamp01(r), Clamp01(g), Clamp01(b)
  if rakaPicker and rakaPicker.SetColorRGB then
    rakaPicker:SetColorRGB(r, g, b)
  end
  if pickerSession and pickerSession.write then
    pickerSession.write(r, g, b)
  end
  UpdateRgbFields(r, g, b)
end

local function ApplyFromRgbFields()
  if editingRgb then
    return
  end
  SetPickerRGB(
    ClampByte(pickerFields.r:GetText()) / 255,
    ClampByte(pickerFields.g:GetText()) / 255,
    ClampByte(pickerFields.b:GetText()) / 255
  )
end

local function ApplyFromHexField()
  if editingRgb then
    return
  end
  local text = string.lower(pickerFields.hex:GetText() or ""):gsub("[^0-9a-f]", "")
  if #text ~= 6 then
    return
  end
  local r = tonumber(text:sub(1, 2), 16)
  local g = tonumber(text:sub(3, 4), 16)
  local b = tonumber(text:sub(5, 6), 16)
  if not r or not g or not b then
    return
  end
  SetPickerRGB(r / 255, g / 255, b / 255)
end

-- ColorSelect setters take Texture widgets (or a texture's global name), not file paths.
-- Wheel/value canvases must stay blank: the engine paints HSV onto them. Setting a
-- file (or SetColorTexture) on those canvases clears/blocks the engine wheel.
-- Thumbs use shared Blizzard button art; underlay uses shipped Media colorwheel.
local THUMB_PATH = "Interface\\Buttons\\UI-ColorPicker-Buttons"
local THUMB_FALLBACK = "Interface\\Buttons\\WHITE8x8"

local function WheelArtPath()
  if RakaMod.Media and type(RakaMod.Media.ColorWheelPath) == "string" then
    return RakaMod.Media.ColorWheelPath
  end
  return "Interface\\AddOns\\RakaMod\\Media\\colorwheel"
end

local function TextureResolved(tex)
  if not tex or not tex.GetTexture then
    return false
  end
  local got = tex:GetTexture()
  return got ~= nil and got ~= "" and got ~= 0 and got ~= false
end

local function TrySetTexture(tex, path)
  if not tex or not tex.SetTexture or type(path) ~= "string" then
    return false
  end
  local ok = pcall(tex.SetTexture, tex, path)
  return ok and TextureResolved(tex)
end

local function ApplyThumb(tex, withCoords)
  if TrySetTexture(tex, THUMB_PATH) then
    if withCoords and tex.SetTexCoord then
      withCoords(tex)
    end
    return
  end
  TrySetTexture(tex, THUMB_FALLBACK)
end

local function SetupColorSelectWheel(dest)
  -- Visible underlay when engine paint is missing (Forever); Retail engine art covers it.
  -- BORDER sits above the solid backdrop fill so the circle is not covered.
  -- Always use shipped Media art here: GetTexture() can still report a missing
  -- UI-ColorPicker-Wheel path as "set", so Blizzard-first fallback is unreliable.
  local underlay = dest:CreateTexture(nil, "BORDER")
  underlay:SetSize(128, 128)
  underlay:SetPoint("TOPLEFT", 24, -42)
  TrySetTexture(underlay, WheelArtPath())
  underlay:Show()

  local wheel = dest:CreateTexture(nil, "ARTWORK")
  wheel:SetSize(128, 128)
  wheel:SetPoint("TOPLEFT", 24, -42)
  -- Intentionally no SetTexture: ColorSelect draws the live hue wheel here.
  wheel:Show()
  if dest.SetColorWheelTexture then
    dest:SetColorWheelTexture(wheel)
  end

  local wheelThumb = dest:CreateTexture(nil, "OVERLAY")
  wheelThumb:SetSize(10, 10)
  ApplyThumb(wheelThumb, function(tex)
    tex:SetTexCoord(0, 0.15625, 0, 0.625)
  end)
  wheelThumb:Show()
  if dest.SetColorWheelThumbTexture then
    dest:SetColorWheelThumbTexture(wheelThumb)
  end

  local value = dest:CreateTexture(nil, "ARTWORK")
  value:SetSize(32, 128)
  value:SetPoint("LEFT", wheel, "RIGHT", 10, 0)
  -- Intentionally no SetColorTexture: ColorSelect draws the value gradient.
  value:Show()
  if dest.SetColorValueTexture then
    dest:SetColorValueTexture(value)
  end

  local valueThumb = dest:CreateTexture(nil, "OVERLAY")
  valueThumb:SetSize(48, 14)
  ApplyThumb(valueThumb, function(tex)
    tex:SetTexCoord(0.25, 1, 0, 0.875)
  end)
  valueThumb:Show()
  if dest.SetColorValueThumbTexture then
    dest:SetColorValueThumbTexture(valueThumb)
  end

  dest.rakaWheelUnderlay = underlay
  dest.rakaWheel = wheel
  dest.rakaValue = value
end

local function EnsureRakaPicker()
  if rakaPicker then
    return rakaPicker
  end

  -- Exact Toxi-style layout from the print:
  -- Title
  -- Wheel + value (left) | swatches, Copy/Paste, Class, Default, Hex (right)
  -- R G B horizontal under wheel
  -- Okay | Cancel
  local f = CreateFrame("ColorSelect", "RakaModColorPicker", UIParent, template)
  f:SetSize(360, 340)
  f:SetPoint("CENTER")
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()
  if UISpecialFrames then
    UISpecialFrames[#UISpecialFrames + 1] = "RakaModColorPicker"
  end

  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.14, 0.14, 0.16, 1)
    f:SetBackdropBorderColor(0.05, 0.05, 0.05, 1)
  end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText("Color Picker")
  title:SetTextColor(ORANGE.r, ORANGE.g, ORANGE.b)

  SetupColorSelectWheel(f)

  -- Right column
  local colX = -18
  local newSwatch = f:CreateTexture(nil, "ARTWORK")
  newSwatch:SetSize(72, 18)
  newSwatch:SetPoint("TOPRIGHT", colX, -42)
  newSwatch:SetColorTexture(1, 1, 1, 1)
  local oldSwatch = f:CreateTexture(nil, "ARTWORK")
  oldSwatch:SetSize(72, 18)
  oldSwatch:SetPoint("TOPRIGHT", newSwatch, "BOTTOMRIGHT", 0, -2)
  oldSwatch:SetColorTexture(1, 1, 1, 1)
  pickerFields.newSwatch = newSwatch
  pickerFields.oldSwatch = oldSwatch

  -- Column width 146 under the swatches (Copy|Paste, Class, Default, Hex)
  local copy = MakePickerButton(f, "Copy", 70, 24)
  copy:SetPoint("TOPRIGHT", f, "TOPRIGHT", -94, -92)
  local paste = MakePickerButton(f, "Paste", 70, 24)
  paste:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -92)

  local classBtn = MakePickerButton(f, "Class", 146, 24)
  classBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -122)
  local defaultBtn = MakePickerButton(f, "Default", 146, 24)
  defaultBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -152)

  local hex = MakeRgbBox(f, 146, 6, false)
  hex:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -184)
  local hexHash = hex:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  hexHash:SetPoint("LEFT", 6, 0)
  hexHash:SetText("#")
  hexHash:SetTextColor(1, 1, 1)
  hex:SetTextInsets(18, 4, 0, 0)
  hex:SetJustifyH("LEFT")

  -- RGB under wheel, one horizontal row
  local rLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  rLabel:SetPoint("BOTTOMLEFT", 28, 56)
  rLabel:SetText("R")
  rLabel:SetTextColor(1, 1, 1)
  local rBox = MakeRgbBox(f, 40, 3, true)
  rBox:SetPoint("LEFT", rLabel, "RIGHT", 4, 0)

  local gLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  gLabel:SetPoint("LEFT", rBox, "RIGHT", 12, 0)
  gLabel:SetText("G")
  gLabel:SetTextColor(1, 1, 1)
  local gBox = MakeRgbBox(f, 40, 3, true)
  gBox:SetPoint("LEFT", gLabel, "RIGHT", 4, 0)

  local bLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  bLabel:SetPoint("LEFT", gBox, "RIGHT", 12, 0)
  bLabel:SetText("B")
  bLabel:SetTextColor(1, 1, 1)
  local bBox = MakeRgbBox(f, 40, 3, true)
  bBox:SetPoint("LEFT", bLabel, "RIGHT", 4, 0)

  local okay = MakePickerButton(f, "Okay", 150, 28)
  okay:SetPoint("BOTTOMLEFT", 24, 16)
  local cancel = MakePickerButton(f, "Cancel", 150, 28)
  cancel:SetPoint("BOTTOMRIGHT", -24, 16)

  pickerButtons.copy = copy
  pickerButtons.paste = paste
  pickerButtons.class = classBtn
  pickerButtons.default = defaultBtn
  pickerButtons.okay = okay
  pickerButtons.cancel = cancel
  pickerFields.hex = hex
  pickerFields.r = rBox
  pickerFields.g = gBox
  pickerFields.b = bBox

  copy:SetScript("OnClick", function()
    local r, g, b = f:GetColorRGB()
    colorClipboard = { r = r, g = g, b = b }
    UpdatePasteButton()
  end)
  paste:SetScript("OnClick", function()
    if type(colorClipboard) ~= "table" then
      return
    end
    SetPickerRGB(colorClipboard.r, colorClipboard.g, colorClipboard.b)
  end)
  classBtn:SetScript("OnClick", function()
    local c = PlayerClassColor()
    SetPickerRGB(c.r, c.g, c.b)
  end)
  defaultBtn:SetScript("OnClick", function()
    if not pickerSession or type(pickerSession.getDefault) ~= "function" then
      return
    end
    local c = pickerSession.getDefault()
    if type(c) ~= "table" then
      return
    end
    SetPickerRGB(c.r, c.g, c.b)
  end)

  local function BindBox(box, apply)
    box:SetScript("OnEnterPressed", function(self)
      apply()
      self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", apply)
  end
  BindBox(rBox, ApplyFromRgbFields)
  BindBox(gBox, ApplyFromRgbFields)
  BindBox(bBox, ApplyFromRgbFields)
  hex:SetScript("OnEnterPressed", function(self)
    ApplyFromHexField()
    self:ClearFocus()
  end)
  hex:SetScript("OnEditFocusLost", ApplyFromHexField)
  hex:SetScript("OnTextChanged", function(_, userInput)
    if userInput and #(hex:GetText() or ""):gsub("[^0-9a-fA-F]", "") == 6 then
      ApplyFromHexField()
    end
  end)

  f:SetScript("OnColorSelect", function(self)
    local r, g, b = self:GetColorRGB()
    if pickerSession and pickerSession.write then
      pickerSession.write(r, g, b)
    end
    UpdateRgbFields(r, g, b)
  end)

  okay:SetScript("OnClick", function()
    local r, g, b = f:GetColorRGB()
    if pickerSession and pickerSession.write then
      pickerSession.write(r, g, b)
    end
    f:Hide()
    pickerSession = nil
  end)
  cancel:SetScript("OnClick", function()
    if pickerSession and pickerSession.previous and pickerSession.write then
      local p = pickerSession.previous
      pickerSession.write(p.r, p.g, p.b)
    end
    f:Hide()
    pickerSession = nil
  end)

  f:SetScript("OnShow", function()
    if f.rakaWheelUnderlay then
      f.rakaWheelUnderlay:Show()
    end
    if f.rakaWheel then
      f.rakaWheel:Show()
    end
    if f.rakaValue then
      f.rakaValue:Show()
    end
    UpdatePasteButton()
    local hasDefault = pickerSession and type(pickerSession.getDefault) == "function"
    defaultBtn:SetEnabled(hasDefault and true or false)
    if hasDefault then
      defaultBtn:SetAlpha(1)
      defaultBtn.label:SetTextColor(ORANGE.r, ORANGE.g, ORANGE.b)
    else
      defaultBtn:SetAlpha(0.55)
      defaultBtn.label:SetTextColor(0.55, 0.55, 0.55)
    end
  end)

  rakaPicker = f
  return f
end

local function PickColor(target, onChange, opts)
  opts = opts or {}
  local previous = { r = target.r, g = target.g, b = target.b }
  local function write(r, g, b)
    target.r, target.g, target.b = r, g, b
    onChange()
  end
  pickerSession = {
    target = target,
    write = write,
    getDefault = opts.getDefault,
    previous = previous,
  }
  local f = EnsureRakaPicker()
  if pickerFields.oldSwatch then
    pickerFields.oldSwatch:SetColorTexture(previous.r, previous.g, previous.b, 1)
  end
  f:SetColorRGB(previous.r, previous.g, previous.b)
  UpdateRgbFields(previous.r, previous.g, previous.b)
  UpdatePasteButton()
  f:Show()
  f:Raise()
end

local cachedGradientDefaults
local function GradientDefaults()
  if not cachedGradientDefaults and RakaMod.Logic and RakaMod.Logic.BuildGradientDefaults then
    cachedGradientDefaults = RakaMod.Logic.BuildGradientDefaults()
  end
  return cachedGradientDefaults
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
  local page = CreateFrame("Frame", nil, pageBody)
  page:SetAllPoints()
  page:Hide()

  local scroll = CreateFrame("ScrollFrame", "RakaModSettingsScroll_" .. key, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  scroll:SetScript("OnMouseWheel", function(_, delta)
    OnMouseWheel(scroll, delta)
  end)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(560, 400)
  scroll:SetScrollChild(content)

  local y = 0
  local ctx = {
    key = key,
    page = page,
    scroll = scroll,
    content = content,
    LocalY = function() return y end,
    Advance = function(step) y = y - (step or ROW) end,
    Finish = function()
      content:SetHeight((-y) + 16)
    end,
  }
  pages[key].page = page
  pages[key].ctx = ctx
  return ctx
end

local checkSerial = 0

local function MakePillToggle(parent)
  local pill = CreateFrame("Button", nil, parent)
  pill:SetSize(PILL_W, PILL_H)
  pill:EnableMouse(true)

  local track = pill:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(0.22, 0.24, 0.28, 1)
  pill.track = track

  local knob = pill:CreateTexture(nil, "OVERLAY")
  knob:SetSize(PILL_H - 6, PILL_H - 6)
  knob:SetColorTexture(1, 1, 1, 1)
  pill.knob = knob

  local checked = false
  function pill:GetChecked()
    return checked
  end
  function pill:SetChecked(value)
    checked = value and true or false
    if checked then
      track:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
      knob:ClearAllPoints()
      knob:SetPoint("RIGHT", pill, "RIGHT", -3, 0)
    else
      track:SetColorTexture(0.22, 0.24, 0.28, 1)
      knob:ClearAllPoints()
      knob:SetPoint("LEFT", pill, "LEFT", 3, 0)
    end
  end
  pill:SetChecked(false)
  return pill
end

local function BindToggle(pill, section, key, afterChange)
  pill:SetScript("OnClick", function(self)
    local nextValue = not self:GetChecked()
    self:SetChecked(nextValue)
    local saved = RakaMod.db and RakaMod.db[section]
    if not saved then
      return
    end
    saved[key] = nextValue and true or false
    RakaMod.Core:RefreshModules()
    if afterChange then
      afterChange()
    end
  end)
end

local function AddCheck(ctx, text, section, key)
  checkSerial = checkSerial + 1
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 8, ctx.LocalY() - 4)
  label:SetText(text)
  label:SetTextColor(0.90, 0.92, 0.95)

  local pill = MakePillToggle(ctx.content)
  pill:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", CONTROL_X, ctx.LocalY() - 4)
  BindToggle(pill, section, key)
  PassWheel(ctx.scroll, pill)
  checks[#checks + 1] = { widget = pill, section = section, key = key }
  ctx.Advance()
  return pill
end

local function AddSlider(ctx, text, section, key, minValue, maxValue)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 8, ctx.LocalY() - 6)
  label:SetText(text)
  label:SetTextColor(0.90, 0.92, 0.95)

  local slider = CreateFrame("Slider", nil, ctx.content)
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", CONTROL_X, ctx.LocalY() - 6)
  slider:SetSize(180, 16)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then
    slider:SetObeyStepOnDrag(true)
  end
  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.14, 0.18, 0.26, 1)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(3)
  local fill = slider:CreateTexture(nil, "BORDER")
  fill:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.85)
  fill:SetPoint("LEFT", track, "LEFT", 0, 0)
  fill:SetHeight(3)
  fill:SetWidth(1)
  slider.fill = fill

  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(12, 12)
  thumb:SetColorTexture(0.92, 0.95, 1.0, 1)
  slider:SetThumbTexture(thumb)

  local valueBox = CreateFrame("Frame", nil, ctx.content, template)
  valueBox:SetSize(42, 20)
  valueBox:SetPoint("LEFT", slider, "RIGHT", 10, 0)
  if valueBox.SetBackdrop then
    valueBox:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    valueBox:SetBackdropColor(0.06, 0.07, 0.10, 1)
    valueBox:SetBackdropBorderColor(0.16, 0.22, 0.32, 1)
  end
  local valueText = valueBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  valueText:SetPoint("CENTER")
  valueText:SetTextColor(0.92, 0.94, 0.98)

  local function UpdateFill(value)
    local span = maxValue - minValue
    local pct = span > 0 and ((value - minValue) / span) or 0
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    fill:SetWidth(math.max(1, (slider:GetWidth() or 180) * pct))
  end

  slider:SetScript("OnValueChanged", function(self, value)
    local intValue = math.floor((value or 0) + 0.5)
    if intValue < minValue then
      intValue = minValue
    elseif intValue > maxValue then
      intValue = maxValue
    end
    valueText:SetText(tostring(intValue))
    UpdateFill(intValue)
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
    if section == "afk" and RakaMod.AFK and RakaMod.AFK.ApplyOptions then
      RakaMod.AFK:ApplyOptions()
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

local function AddColorButton(ctx, text, getTarget, onChange, getDefault)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 8, ctx.LocalY() - 6)
  label:SetText(text)
  label:SetTextColor(0.90, 0.92, 0.95)

  local swatch = CreateFrame("Button", nil, ctx.content)
  swatch:SetSize(20, 20)
  swatch:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", CONTROL_X, ctx.LocalY() - 4)
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
    end, { getDefault = getDefault })
  end)
  PassWheel(ctx.scroll, swatch)
  swatches[#swatches + 1] = { paint = paint }
  ctx.Advance()
  return swatch
end

local function AddZoneSwatch(ctx, text)
  return AddColorButton(ctx, text, function()
    return RakaMod.db and RakaMod.db.zoneText
  end, function()
    RakaMod.Core:RefreshModules()
    if RakaMod.ZoneText and RakaMod.ZoneText.Apply then
      RakaMod.ZoneText:Apply()
    end
  end, function()
    return { r = 1, g = 1, b = 1 }
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
  -- Title/description live in the shell page header (PAGE_META). Keep light top padding.
  if type(text) == "string" and text ~= "" and PAGE_META[ctx.key] and not PAGE_META[ctx.key].description then
    PAGE_META[ctx.key].description = text
  end
  ctx.Advance(4)
  return nil
end

local function AddOutlineButton(ctx)
  local outlineLabel = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  outlineLabel:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 8, ctx.LocalY() - 6)
  outlineLabel:SetText("Outline")
  outlineLabel:SetTextColor(0.90, 0.92, 0.95)

  outlineButton = CreateFrame("Button", nil, ctx.content, template)
  outlineButton:SetSize(156, 22)
  outlineButton:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", CONTROL_X, ctx.LocalY() - 3)
  if outlineButton.SetBackdrop then
    outlineButton:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    outlineButton:SetBackdropColor(0.06, 0.07, 0.10, 1)
    outlineButton:SetBackdropBorderColor(0.16, 0.22, 0.32, 1)
  else
    local outlineBg = outlineButton:CreateTexture(nil, "BACKGROUND")
    outlineBg:SetAllPoints()
    outlineBg:SetColorTexture(0.10, 0.12, 0.16, 1)
  end
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

local general = CreatePage("general")
AddDescription(general, "Addon-wide options.")
AddCheck(general, "Show minimap icon", "general", "showMinimapIcon")
general.Finish()

local reveal = CreatePage("reveal")
AddDescription(
  reveal,
  "Force-show the Ellesmere player frame while casting, while effective health is above 100% (absorbs / overshield), on mouseover, or in combat. It never hides the frame itself."
)
AddCheck(reveal, "Enabled", "reveal", "enabled")
AddCheck(reveal, "Casting", "reveal", "casting")
AddCheck(reveal, "Health above 100%", "reveal", "health")
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

local PAIR_ROW = 26
local CLASS_COL2_X = 310

local function AddSectionHeader(ctx, text)
  local header = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", 8, ctx.LocalY() - 4)
  header:SetText(text)
  header:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
  ctx.Advance()
  return header
end

local overlay = CreatePage("overlay")
AddDescription(overlay, "Escape menu overlay buttons (collections / played / professions).")
AddCheck(overlay, "Enabled", "overlay", "enabled")
AddCheck(overlay, "Collections", "overlay", "collections")
AddCheck(overlay, "Played", "overlay", "played")
AddCheck(overlay, "Professions", "overlay", "professions")
overlay.Finish()

local function AddInlineCheck(ctx, text, section, key, x)
  checkSerial = checkSerial + 1
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", x, ctx.LocalY() - 2)
  label:SetText(text)
  label:SetTextColor(0.90, 0.92, 0.95)
  local labelW = label:GetStringWidth() or 80

  local pill = MakePillToggle(ctx.content)
  pill:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", x + labelW + 8, ctx.LocalY() - 2)
  BindToggle(pill, section, key, function()
    if section == "afk" and RakaMod.AFK and RakaMod.AFK.ApplyOptions then
      RakaMod.AFK:ApplyOptions()
    end
  end)
  PassWheel(ctx.scroll, pill)
  checks[#checks + 1] = { widget = pill, section = section, key = key }
  return x + labelW + 8 + PILL_W + 16
end

local function AddCheckRow(ctx, items)
  local x = 8
  for i = 1, #items do
    local item = items[i]
    x = AddInlineCheck(ctx, item[1], item[2], item[3], x)
  end
  ctx.Advance()
  ctx.Advance(6)
end

local afk = CreatePage("afk")
afk.content:SetWidth(640)
AddDescription(afk, PAGE_META.afk.description)
AddCheckRow(afk, {
  { "Enabled", "afk", "enabled" },
  { "Play Emotes", "afk", "playEmotes" },
  { "Turn Camera", "afk", "cameraPan" },
  { "Show Changelog", "afk", "showChangelog" },
})
-- Show Tips omitted: no tips panel yet. Spec Icon Size omitted: AFK shows class icon, not a resizable spec icon.
AddSlider(afk, "Background fade", "afk", "backgroundFade", 0, 100)
afk.Finish()

local function MakeSwatch(parent, scroll, size)
  local swatch = CreateFrame("Button", nil, parent)
  swatch:SetSize(size, size)
  local edge = swatch:CreateTexture(nil, "BACKGROUND")
  edge:SetColorTexture(0, 0, 0, 1)
  edge:SetPoint("TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", 1, -1)
  local color = swatch:CreateTexture(nil, "ARTWORK")
  color:SetAllPoints()
  swatch.color = color
  PassWheel(scroll, swatch)
  return swatch
end

local function PaintSwatch(swatch, target)
  local r, g, b = 1, 1, 1
  if target then
    if type(target.r) == "number" then r = target.r end
    if type(target.g) == "number" then g = target.g end
    if type(target.b) == "number" then b = target.b end
  end
  swatch.color:SetColorTexture(r, g, b, 1)
end

local function PaintPreview(preview, left, right)
  if not preview then
    return
  end
  local lr, lg, lb = 0.5, 0.5, 0.5
  local rr, rg, rb = 0.8, 0.8, 0.8
  if left then
    if type(left.r) == "number" then lr = left.r end
    if type(left.g) == "number" then lg = left.g end
    if type(left.b) == "number" then lb = left.b end
  end
  if right then
    if type(right.r) == "number" then rr = right.r end
    if type(right.g) == "number" then rg = right.g end
    if type(right.b) == "number" then rb = right.b end
  end
  preview:SetColorTexture(1, 1, 1, 1)
  if preview.SetGradient and CreateColor then
    pcall(preview.SetGradient, preview, "HORIZONTAL", CreateColor(lr, lg, lb, 1), CreateColor(rr, rg, rb, 1))
  else
    preview:SetColorTexture((lr + rr) * 0.5, (lg + rg) * 0.5, (lb + rb) * 0.5, 1)
  end
end

local function AddPairRow(ctx, x, y, labelText, labelColor, getPair, getDefaultPair)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", x, y - 4)
  label:SetWidth(100)
  label:SetJustifyH("LEFT")
  label:SetText(labelText)
  if labelColor then
    label:SetTextColor(labelColor.r or 1, labelColor.g or 1, labelColor.b or 1)
  end

  local leftSwatch = MakeSwatch(ctx.content, ctx.scroll, 18)
  leftSwatch:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", x + 104, y - 3)
  local arrow = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  arrow:SetPoint("LEFT", leftSwatch, "RIGHT", 4, 0)
  arrow:SetText(">")
  local rightSwatch = MakeSwatch(ctx.content, ctx.scroll, 18)
  rightSwatch:SetPoint("LEFT", arrow, "RIGHT", 4, 0)

  local preview = ctx.content:CreateTexture(nil, "ARTWORK")
  preview:SetPoint("LEFT", rightSwatch, "RIGHT", 8, 0)
  preview:SetSize(88, 14)

  local function refresh()
    local pair = getPair()
    PaintSwatch(leftSwatch, pair and pair.left)
    PaintSwatch(rightSwatch, pair and pair.right)
    PaintPreview(preview, pair and pair.left, pair and pair.right)
  end

  leftSwatch:SetScript("OnClick", function()
    local pair = getPair()
    if not pair or type(pair.left) ~= "table" then
      return
    end
    PickColor(pair.left, function()
      refresh()
      if RakaMod.Gradient and RakaMod.Gradient.Apply then
        RakaMod.Gradient:Apply()
      end
    end, {
      getDefault = function()
        local defaults = getDefaultPair and getDefaultPair()
        return defaults and defaults.left
      end,
    })
  end)
  rightSwatch:SetScript("OnClick", function()
    local pair = getPair()
    if not pair or type(pair.right) ~= "table" then
      return
    end
    PickColor(pair.right, function()
      refresh()
      if RakaMod.Gradient and RakaMod.Gradient.Apply then
        RakaMod.Gradient:Apply()
      end
    end, {
      getDefault = function()
        local defaults = getDefaultPair and getDefaultPair()
        return defaults and defaults.right
      end,
    })
  end)

  swatches[#swatches + 1] = { paint = refresh }
  refresh()
end

local function ClassLabelColor(classFile)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if type(c) == "table" and type(c.r) == "number" then
    return { r = c.r, g = c.g, b = c.b }
  end
  local fallback = RakaMod.Logic and RakaMod.Logic.CLASS_FALLBACK_COLORS and RakaMod.Logic.CLASS_FALLBACK_COLORS[classFile]
  if type(fallback) == "table" then
    return fallback
  end
  return { r = 1, g = 1, b = 1 }
end

local CLASS_DISPLAY = {
  WARRIOR = "Warrior",
  PALADIN = "Paladin",
  HUNTER = "Hunter",
  ROGUE = "Rogue",
  PRIEST = "Priest",
  DEATHKNIGHT = "Death Knight",
  SHAMAN = "Shaman",
  MAGE = "Mage",
  WARLOCK = "Warlock",
  MONK = "Monk",
  DRUID = "Druid",
  DEMONHUNTER = "Demon Hunter",
  EVOKER = "Evoker",
}

local function ClassDisplayName(classFile)
  if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] then
    return LOCALIZED_CLASS_NAMES_MALE[classFile]
  end
  return CLASS_DISPLAY[classFile] or classFile
end

local gradient = CreatePage("gradient")
AddDescription(gradient, "Health bar gradients shift by class, NPC reaction, and unit state.")
AddCheck(gradient, "Enabled", "gradient", "enabled")
gradientNote = AddNote(gradient, "No Ellesmere health-bar module is installed.")
AddSectionHeader(gradient, "Class Colors")

do
  local files = RakaMod.Logic and RakaMod.Logic.CLASS_FILES or {}
  local startY = gradient.LocalY()
  local rows = math.ceil(#files / 2)
  for i = 1, #files do
    local file = files[i]
    local col = (i % 2 == 1) and 0 or 1
    local row = math.floor((i - 1) / 2)
    local x = col == 0 and 8 or CLASS_COL2_X
    local y = startY - row * PAIR_ROW
    AddPairRow(gradient, x, y, ClassDisplayName(file), ClassLabelColor(file), function()
      local g = RakaMod.db and RakaMod.db.gradient
      return g and g.classes and g.classes[file]
    end, function()
      local d = GradientDefaults()
      return d and d.classes and d.classes[file]
    end)
  end
  for _ = 1, rows do
    gradient.Advance(PAIR_ROW)
  end
end

AddSectionHeader(gradient, "NPC Colors")
do
  local npcRows = {
    { key = "friendly", label = "Friendly", color = { r = 0.35, g = 0.85, b = 0.35 } },
    { key = "enemy", label = "Enemy", color = { r = 0.95, g = 0.30, b = 0.30 } },
    { key = "neutral", label = "Neutral", color = { r = 0.95, g = 0.82, b = 0.40 } },
  }
  local startY = gradient.LocalY()
  for i = 1, #npcRows do
    local row = npcRows[i]
    AddPairRow(gradient, 8, startY - (i - 1) * PAIR_ROW, row.label, row.color, function()
      local g = RakaMod.db and RakaMod.db.gradient
      return g and g.npc and g.npc[row.key]
    end, function()
      local d = GradientDefaults()
      return d and d.npc and d.npc[row.key]
    end)
  end
  for _ = 1, #npcRows do
    gradient.Advance(PAIR_ROW)
  end
end

AddSectionHeader(gradient, "State Colors")
do
  local stateRows = {
    { key = "dead", label = "Dead" },
    { key = "offline", label = "Offline" },
    { key = "tapped", label = "Tapped" },
    { key = "disconnected", label = "Disconnected" },
  }
  local startY = gradient.LocalY()
  for i = 1, #stateRows do
    local row = stateRows[i]
    AddPairRow(gradient, 8, startY - (i - 1) * PAIR_ROW, row.label, { r = 0.85, g = 0.85, b = 0.85 }, function()
      local g = RakaMod.db and RakaMod.db.gradient
      return g and g.states and g.states[row.key]
    end, function()
      local d = GradientDefaults()
      return d and d.states and d.states[row.key]
    end)
  end
  for _ = 1, #stateRows do
    gradient.Advance(PAIR_ROW)
  end
end

gradient.Finish()

Settings:SelectPage("general")

function Settings:SyncFromDB()
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
    local hostWidth = pageBody and pageBody:GetWidth() or contentHost:GetWidth()
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
  self:SyncFromDB()
  self:SelectPage(selectedKey or "general")
  frame:Show()
  self:RefreshNotes()
  for i = 1, #navPageKeys do
    UpdateScrollChildWidth(navPageKeys[i])
  end
end

local function RegisterBlizzardCategory()
  local panel = CreateFrame("Frame")
  panel.name = "RakaMod"
  local iconPath = (RakaMod.Media and RakaMod.Media.IconPath) or "Interface\\AddOns\\RakaMod\\Media\\icon"

  local crest = panel:CreateTexture(nil, "ARTWORK")
  crest:SetSize(64, 64)
  crest:SetPoint("CENTER", panel, "CENTER", 0, 40)
  crest:SetTexture(iconPath)

  local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  btn:SetSize(200, 30)
  btn:SetPoint("TOP", crest, "BOTTOM", 0, -16)
  btn:SetText("Open RakaMod")
  btn:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() and HideUIPanel then
      HideUIPanel(SettingsPanel)
    end
    local open = function()
      RakaMod.OpenSettings()
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, open)
    else
      open()
    end
  end)

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "RakaMod")
    if type(category) == "table" then
      category.icon = iconPath
    end
    if Settings.RegisterAddOnCategory then
      Settings.RegisterAddOnCategory(category)
    end
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

RegisterBlizzardCategory()
