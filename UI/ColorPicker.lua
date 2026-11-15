RakaMod = RakaMod or {}

-- Color picker popup (wheel, value bar, hex and RGB fields) shared by every swatch in the settings window.
local template = BackdropTemplateMixin and "BackdropTemplate" or nil

local colorClipboard = nil
local pickerSession = nil
local pickerAccepted = false
local rakaPicker
local pickerButtons = {}
local pickerFields = {}
local editingRgb = false
-- The color picker keeps its own fixed palette; it does not follow the window accent.
local ORANGE = { r = 0.25, g = 0.62, b = 1.00 }

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

-- ColorSelect setters take Texture widgets, not file paths. The wheel and value canvases must stay
-- blank so the engine can paint the live hue wheel and brightness gradient onto them (setting a file
-- or SetColorTexture on them blocks that). Some clients (WoW Forever) never paint them, so shipped
-- Media art sits underneath as a visible fallback; clicks and drags are still hit-tested by ColorSelect
-- against the canvas rectangles.
local THUMB_PATH = "Interface\\Buttons\\UI-ColorPicker-Buttons"
local WHEEL_SIZE = 128
local VALUE_WIDTH = 16

local function WheelArtPath()
  if RakaMod.Media and type(RakaMod.Media.ColorWheelPath) == "string" then
    return RakaMod.Media.ColorWheelPath
  end
  return "Interface\\AddOns\\RakaMod\\Media\\colorwheel"
end

-- Vertical gradient from black (bottom) to the given color (top), for the value-bar fallback.
local function PaintGradient(tex, r, g, b)
  tex:SetColorTexture(1, 1, 1, 1)
  if not tex.SetGradient then
    tex:SetColorTexture(r, g, b, 1)
    return
  end
  local ok = false
  if CreateColor then
    ok = pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(0, 0, 0, 1), CreateColor(r, g, b, 1))
  end
  if not ok then
    ok = pcall(tex.SetGradient, tex, "VERTICAL", 0, 0, 0, r, g, b)
  end
  if not ok then
    tex:SetColorTexture(r * 0.5, g * 0.5, b * 0.5, 1)
  end
end

-- Top of the value bar: the current hue/saturation at full brightness.
local function UpdateValueFallback(select, r, g, b)
  local fallback = select and select.rakaValueFallback
  if not fallback then
    return
  end
  local top = math.max(r or 0, g or 0, b or 0)
  if top <= 0 then
    PaintGradient(fallback, 1, 1, 1)
  else
    PaintGradient(fallback, r / top, g / top, b / top)
  end
end

local function SetupColorSelectTextures(select)
  local wheelArt = select:CreateTexture(nil, "BORDER")
  wheelArt:SetSize(WHEEL_SIZE, WHEEL_SIZE)
  wheelArt:SetPoint("TOPLEFT", select, "TOPLEFT", 0, 0)
  wheelArt:SetTexture(WheelArtPath())

  local wheel = select:CreateTexture(nil, "ARTWORK")
  wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
  wheel:SetPoint("TOPLEFT", select, "TOPLEFT", 0, 0)
  select:SetColorWheelTexture(wheel)

  local wheelThumb = select:CreateTexture(nil, "OVERLAY")
  wheelThumb:SetSize(10, 10)
  wheelThumb:SetTexture(THUMB_PATH)
  wheelThumb:SetTexCoord(0, 0.15625, 0, 0.625)
  select:SetColorWheelThumbTexture(wheelThumb)

  local valueFallback = select:CreateTexture(nil, "BORDER")
  valueFallback:SetSize(VALUE_WIDTH, WHEEL_SIZE)
  valueFallback:SetPoint("TOPLEFT", wheel, "TOPRIGHT", 10, 0)
  select.rakaValueFallback = valueFallback
  PaintGradient(valueFallback, 1, 1, 1)

  local value = select:CreateTexture(nil, "ARTWORK")
  value:SetSize(VALUE_WIDTH, WHEEL_SIZE)
  value:SetPoint("TOPLEFT", wheel, "TOPRIGHT", 10, 0)
  select:SetColorValueTexture(value)

  local valueThumb = select:CreateTexture(nil, "OVERLAY")
  valueThumb:SetSize(VALUE_WIDTH, 8)
  valueThumb:SetTexture(THUMB_PATH)
  valueThumb:SetTexCoord(0.25, 1, 0, 0.875)
  select:SetColorValueThumbTexture(valueThumb)
end

local function EnsureRakaPicker()
  if rakaPicker then
    return rakaPicker
  end

  -- Shell frame (Toxi print) + nested ColorSelect for wheel/value only.
  local f = CreateFrame("Frame", "RakaModColorPicker", UIParent, template)
  f:SetSize(360, 320)
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
    f:SetBackdropColor(0.12, 0.12, 0.14, 1)
    f:SetBackdropBorderColor(0.05, 0.05, 0.05, 1)
  end

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Color Picker")
  title:SetTextColor(ORANGE.r, ORANGE.g, ORANGE.b)

  local select = CreateFrame("ColorSelect", "RakaModColorSelect", f)
  select:SetSize(160, 128)
  select:SetPoint("TOPLEFT", 18, -40)
  SetupColorSelectTextures(select)
  f.select = select
  f.buttons = pickerButtons

  -- Right column: swatches → Copy|Paste → Class → Default → Hex
  local newSwatch = f:CreateTexture(nil, "ARTWORK")
  newSwatch:SetSize(90, 18)
  newSwatch:SetPoint("TOPRIGHT", -18, -40)
  newSwatch:SetColorTexture(1, 1, 1, 1)
  local oldSwatch = f:CreateTexture(nil, "ARTWORK")
  oldSwatch:SetSize(90, 18)
  oldSwatch:SetPoint("TOPRIGHT", newSwatch, "BOTTOMRIGHT", 0, -2)
  oldSwatch:SetColorTexture(1, 1, 1, 1)
  pickerFields.newSwatch = newSwatch
  pickerFields.oldSwatch = oldSwatch

  local copy = MakePickerButton(f, "Copy", 70, 24)
  copy:SetPoint("TOPRIGHT", -94, -86)
  local paste = MakePickerButton(f, "Paste", 70, 24)
  paste:SetPoint("TOPRIGHT", -18, -86)

  local classBtn = MakePickerButton(f, "Class", 146, 24)
  classBtn:SetPoint("TOPRIGHT", -18, -116)
  local defaultBtn = MakePickerButton(f, "Default", 146, 24)
  defaultBtn:SetPoint("TOPRIGHT", -18, -146)

  local hex = MakeRgbBox(f, 146, 7, false)
  hex:SetPoint("TOPRIGHT", -18, -178)
  local hexHash = hex:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  hexHash:SetPoint("LEFT", 6, 0)
  hexHash:SetText("#")
  hexHash:SetTextColor(1, 1, 1)
  hex:SetTextInsets(18, 4, 0, 0)
  hex:SetJustifyH("LEFT")

  -- RGB under wheel, one horizontal row
  local rLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  rLabel:SetPoint("TOPLEFT", select, "BOTTOMLEFT", 0, -14)
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
  okay:SetPoint("BOTTOMLEFT", 18, 14)
  local cancel = MakePickerButton(f, "Cancel", 150, 28)
  cancel:SetPoint("BOTTOMRIGHT", -18, 14)

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

  local function ReadSelectRGB()
    return select:GetColorRGB()
  end

  copy:SetScript("OnClick", function()
    local r, g, b = ReadSelectRGB()
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

  select:SetScript("OnColorSelect", function(self)
    local r, g, b = self:GetColorRGB()
    UpdateValueFallback(self, r, g, b)
    if pickerSession and pickerSession.write then
      pickerSession.write(r, g, b)
    end
    UpdateRgbFields(r, g, b)
  end)

  okay:SetScript("OnClick", function()
    local r, g, b = ReadSelectRGB()
    if pickerSession and pickerSession.write then
      pickerSession.write(r, g, b)
    end
    pickerAccepted = true
    f:Hide()
  end)
  cancel:SetScript("OnClick", function()
    if pickerSession and pickerSession.previous and pickerSession.write then
      local p = pickerSession.previous
      pickerSession.write(p.r, p.g, p.b)
    end
    pickerAccepted = true
    f:Hide()
  end)

  f:SetScript("OnHide", function()
    -- Esc (UISpecialFrames) must act as Cancel: restore the color from when the picker opened.
    if not pickerAccepted and pickerSession and pickerSession.previous and pickerSession.write then
      local p = pickerSession.previous
      pickerSession.write(p.r, p.g, p.b)
    end
    pickerSession = nil
    pickerAccepted = false
  end)

  f:SetScript("OnShow", function()
    pickerAccepted = false
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

  -- API shims used by SetPickerRGB / PickColor
  function f:GetColorRGB()
    return select:GetColorRGB()
  end
  function f:SetColorRGB(r, g, b)
    select:SetColorRGB(r, g, b)
  end

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

RakaMod.ColorPicker = {
  Pick = PickColor,
  Frame = function()
    return rakaPicker
  end,
}
