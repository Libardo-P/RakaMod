RakaMod = RakaMod or {}

-- Themed controls for the settings window. Every accent-colored part registers with Theme.Bind,
-- so switching the accent repaints open controls without a reload.
local Theme = RakaMod.Theme
local Widgets = {}
RakaMod.Widgets = Widgets

local C = Theme.COLORS
local template = Theme.template

---------------------------------------------------------------------------
-- Button: dark face, accent label, accent border on hover
---------------------------------------------------------------------------
function Widgets.Button(parent, text, width, height)
  local button = CreateFrame("Button", nil, parent, template)
  button:SetSize(width, height or 30)
  Theme.Panel(button, C.RAISED, C.BORDER_HI)
  button.label = Theme.Text(button, 14, C.TEXT)
  button.label:SetPoint("CENTER", 0, 0)
  button.label:SetText(text)
  button.hover = false

  local function paint(a)
    button.label:SetTextColor(a.r, a.g, a.b)
    if button.hover then
      Theme.SetBorder(button, a)
      Theme.SetFill(button, 0.23, 0.23, 0.24, 1)
    else
      Theme.SetBorder(button, C.BORDER_HI)
      Theme.SetFill(button, C.RAISED.r, C.RAISED.g, C.RAISED.b, 1)
    end
  end
  Theme.Bind(paint)
  button:SetScript("OnEnter", function(self)
    self.hover = true
    paint(Theme.accent)
  end)
  button:SetScript("OnLeave", function(self)
    self.hover = false
    paint(Theme.accent)
  end)
  return button
end

---------------------------------------------------------------------------
-- Checkbox: dark box, accent check mark
---------------------------------------------------------------------------
function Widgets.Checkbox(parent)
  local box = CreateFrame("Button", nil, parent, template)
  box:SetSize(20, 20)
  box:EnableMouse(true)
  Theme.Panel(box, C.FIELD, C.BORDER_HI)

  local mark = box:CreateTexture(nil, "OVERLAY")
  mark:SetPoint("TOPLEFT", -3, 3)
  mark:SetPoint("BOTTOMRIGHT", 3, -3)
  mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  mark:SetDesaturated(true)
  mark:Hide()

  local checked = false
  Theme.Bind(function(a)
    mark:SetVertexColor(a.r, a.g, a.b)
  end)
  function box:GetChecked()
    return checked
  end
  function box:SetChecked(value)
    checked = value and true or false
    mark:SetShown(checked)
  end
  box:SetScript("OnEnter", function(self)
    Theme.SetBorder(self, Theme.accent)
  end)
  box:SetScript("OnLeave", function(self)
    Theme.SetBorder(self, C.BORDER_HI)
  end)
  box:SetChecked(false)
  return box
end

---------------------------------------------------------------------------
-- Toggle pill: ON (accent fill, dark text) / OFF (dark, muted text)
---------------------------------------------------------------------------
function Widgets.Toggle(parent)
  local pill = CreateFrame("Button", nil, parent, template)
  pill:SetSize(56, 24)
  pill:EnableMouse(true)
  Theme.Panel(pill, C.FIELD, C.BORDER_HI)
  pill.label = Theme.Text(pill, 13, C.MUTED)
  pill.label:SetPoint("CENTER", 0, 0)

  local checked = false
  local function paint(a)
    if checked then
      Theme.SetFill(pill, a.r, a.g, a.b, 1)
      Theme.SetBorder(pill, a)
      pill.label:SetText("ON")
      pill.label:SetTextColor(a.tr, a.tg, a.tb)
    else
      Theme.SetFill(pill, C.FIELD.r, C.FIELD.g, C.FIELD.b, 1)
      Theme.SetBorder(pill, C.BORDER_HI)
      pill.label:SetText("OFF")
      pill.label:SetTextColor(C.MUTED.r, C.MUTED.g, C.MUTED.b)
    end
  end
  Theme.Bind(paint)
  function pill:GetChecked()
    return checked
  end
  function pill:SetChecked(value)
    checked = value and true or false
    paint(Theme.accent)
  end
  pill:SetChecked(false)
  return pill
end

---------------------------------------------------------------------------
-- Dropdown with a shared popup menu
---------------------------------------------------------------------------
local MENU_ITEM_H = 24
local dropdownMenu

function Widgets.CloseDropdown()
  if dropdownMenu then
    dropdownMenu:Hide()
    dropdownMenu.catcher:Hide()
    dropdownMenu.owner = nil
  end
end

local function EnsureMenu()
  if dropdownMenu then
    return dropdownMenu
  end
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG")
  catcher:Hide()
  catcher:SetScript("OnClick", Widgets.CloseDropdown)

  local menu = CreateFrame("Frame", nil, UIParent, template)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
  menu:EnableMouse(true)
  Theme.Panel(menu, C.FIELD, C.BORDER_HI)
  Theme.Bind(function(a)
    Theme.SetBorder(menu, a)
  end)
  menu:Hide()
  menu.catcher = catcher
  menu.items = {}
  dropdownMenu = menu
  return menu
end

local function MenuItem(menu, index)
  local item = menu.items[index]
  if item then
    return item
  end
  item = CreateFrame("Button", nil, menu)
  item:SetHeight(MENU_ITEM_H)
  item.hl = item:CreateTexture(nil, "BACKGROUND")
  item.hl:SetAllPoints()
  item.hl:SetColorTexture(0, 0, 0, 0)
  item.label = Theme.Text(item, 13, C.TEXT)
  item.label:SetPoint("LEFT", 10, 0)
  item:SetScript("OnEnter", function(self)
    local a = Theme.accent
    self.hl:SetColorTexture(a.dr, a.dg, a.db, 0.9)
  end)
  item:SetScript("OnLeave", function(self)
    self.hl:SetColorTexture(0, 0, 0, 0)
  end)
  menu.items[index] = item
  return item
end

local function OpenDropdown(owner)
  local menu = EnsureMenu()
  if menu.owner == owner and menu:IsShown() then
    Widgets.CloseDropdown()
    return
  end
  menu.owner = owner
  local count = #owner.options
  local a = Theme.accent
  for i = 1, count do
    local option = owner.options[i]
    local item = MenuItem(menu, i)
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * MENU_ITEM_H)
    item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - (i - 1) * MENU_ITEM_H)
    item.label:SetText(option)
    if option == owner.value then
      item.label:SetTextColor(a.r, a.g, a.b)
    else
      item.label:SetTextColor(C.TEXT.r, C.TEXT.g, C.TEXT.b)
    end
    item:SetScript("OnClick", function()
      owner:SetValue(option)
      Widgets.CloseDropdown()
      if owner.onSelect then
        owner.onSelect(option)
      end
    end)
    item:Show()
  end
  for i = count + 1, #menu.items do
    menu.items[i]:Hide()
  end
  menu:SetSize(owner:GetWidth(), count * MENU_ITEM_H + 4)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
  menu.catcher:Show()
  menu:Show()
end

function Widgets.Dropdown(parent, width, options, onSelect)
  local button = CreateFrame("Button", nil, parent, template)
  button:SetSize(width, 26)
  Theme.Panel(button, C.FIELD, C.BORDER_HI)

  local text = Theme.Text(button, 14, C.TEXT)
  text:SetPoint("LEFT", 10, 0)
  text:SetPoint("RIGHT", -26, 0)
  text:SetJustifyH("LEFT")

  local arrow = Theme.Text(button, 12, C.TEXT)
  arrow:SetPoint("RIGHT", -10, 0)
  arrow:SetText("v")
  Theme.Bind(function(a)
    arrow:SetTextColor(a.r, a.g, a.b)
  end)

  button.options = options
  button.onSelect = onSelect
  function button:SetValue(value)
    self.value = value
    text:SetText(value or "")
  end
  button:SetScript("OnClick", function(self)
    OpenDropdown(self)
  end)
  button:SetScript("OnEnter", function(self)
    Theme.SetBorder(self, Theme.accent)
  end)
  button:SetScript("OnLeave", function(self)
    Theme.SetBorder(self, C.BORDER_HI)
  end)
  return button
end

---------------------------------------------------------------------------
-- Slider with accent fill and an editable value box
---------------------------------------------------------------------------
-- Returns { slider, box, SetSilently(value) }. The caller anchors slider and box.
-- onChange(value, dragging) fires for user changes only; onRelease() when the mouse is let go.
function Widgets.Slider(parent, minValue, maxValue, onChange, onRelease)
  local obj = { silent = false }

  local box = CreateFrame("EditBox", nil, parent, template)
  box:SetSize(46, 24)
  box:SetAutoFocus(false)
  box:SetMaxLetters(3)
  box:SetNumeric(true)
  box:SetJustifyH("CENTER")
  box:SetFont(Theme.FontPath(), 14, "")
  box:SetTextColor(C.TEXT.r, C.TEXT.g, C.TEXT.b)
  box:SetTextInsets(4, 4, 0, 0)
  Theme.Panel(box, C.FIELD, C.BORDER_HI)
  obj.box = box

  local slider = CreateFrame("Slider", nil, parent)
  slider:SetOrientation("HORIZONTAL")
  slider:SetHeight(18)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then
    slider:SetObeyStepOnDrag(true)
  end
  obj.slider = slider

  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(C.FIELD.r, C.FIELD.g, C.FIELD.b, 1)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(6)
  local trackEdge = slider:CreateTexture(nil, "BACKGROUND", nil, -1)
  trackEdge:SetColorTexture(C.BORDER_HI.r, C.BORDER_HI.g, C.BORDER_HI.b, 1)
  trackEdge:SetPoint("TOPLEFT", track, "TOPLEFT", -1, 1)
  trackEdge:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 1, -1)

  local fill = slider:CreateTexture(nil, "BORDER")
  fill:SetPoint("LEFT", track, "LEFT", 0, 0)
  fill:SetHeight(6)
  fill:SetWidth(1)

  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(9, 18)
  slider:SetThumbTexture(thumb)

  Theme.Bind(function(a)
    fill:SetColorTexture(a.r, a.g, a.b, 1)
    thumb:SetColorTexture(a.r, a.g, a.b, 1)
  end)

  local current = minValue
  local function updateFill(value)
    current = value
    local span = maxValue - minValue
    local pct = span > 0 and ((value - minValue) / span) or 0
    if pct < 0 then
      pct = 0
    elseif pct > 1 then
      pct = 1
    end
    fill:SetWidth(math.max(1, (slider:GetWidth() or 120) * pct))
  end
  obj.UpdateFill = updateFill
  slider:SetScript("OnSizeChanged", function()
    updateFill(current)
  end)

  slider:SetScript("OnValueChanged", function(self, value)
    local intValue = math.floor((value or 0) + 0.5)
    if intValue < minValue then
      intValue = minValue
    elseif intValue > maxValue then
      intValue = maxValue
    end
    box:SetText(tostring(intValue))
    updateFill(intValue)
    if obj.silent then
      return
    end
    if value ~= intValue then
      obj.silent = true
      self:SetValue(intValue)
      obj.silent = false
    end
    if onChange then
      onChange(intValue, obj.dragging)
    end
  end)

  slider:SetScript("OnMouseDown", function()
    obj.dragging = true
  end)
  slider:SetScript("OnMouseUp", function()
    obj.dragging = false
    if onRelease then
      onRelease()
    end
  end)

  local function commitTyped()
    local typed = tonumber(box:GetText())
    if typed then
      if typed < minValue then
        typed = minValue
      elseif typed > maxValue then
        typed = maxValue
      end
      slider:SetValue(typed)
    end
    box:SetText(tostring(math.floor((slider:GetValue() or minValue) + 0.5)))
  end
  box:SetScript("OnEnterPressed", function(self)
    commitTyped()
    self:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(math.floor((slider:GetValue() or minValue) + 0.5)))
    self:ClearFocus()
  end)
  box:SetScript("OnEditFocusGained", function(self)
    Theme.SetBorder(self, Theme.accent)
    self:HighlightText()
  end)
  box:SetScript("OnEditFocusLost", function(self)
    Theme.SetBorder(self, C.BORDER_HI)
    self:HighlightText(0, 0)
    commitTyped()
  end)

  function obj.SetSilently(value)
    obj.silent = true
    slider:SetValue(value)
    obj.silent = false
    box:SetText(tostring(math.floor(value + 0.5)))
    updateFill(value)
  end
  return obj
end

---------------------------------------------------------------------------
-- Color swatch (selectable ring for accent presets)
---------------------------------------------------------------------------
function Widgets.Swatch(parent, size)
  local swatch = CreateFrame("Button", nil, parent)
  swatch:SetSize(size, size)
  local edge = swatch:CreateTexture(nil, "BACKGROUND")
  edge:SetPoint("TOPLEFT", -1, 1)
  edge:SetPoint("BOTTOMRIGHT", 1, -1)
  local color = swatch:CreateTexture(nil, "ARTWORK")
  color:SetPoint("TOPLEFT", 1, -1)
  color:SetPoint("BOTTOMRIGHT", -1, 1)
  swatch.color = color
  swatch.selected = false

  local function paintEdge(a)
    if swatch.selected then
      edge:SetColorTexture(1, 1, 1, 1)
    elseif swatch.hover then
      edge:SetColorTexture(a.r, a.g, a.b, 1)
    else
      edge:SetColorTexture(C.BORDER_HI.r, C.BORDER_HI.g, C.BORDER_HI.b, 1)
    end
  end
  Theme.Bind(paintEdge)
  function swatch:SetSelected(value)
    self.selected = value and true or false
    paintEdge(Theme.accent)
  end
  swatch:SetScript("OnEnter", function(self)
    self.hover = true
    paintEdge(Theme.accent)
  end)
  swatch:SetScript("OnLeave", function(self)
    self.hover = false
    paintEdge(Theme.accent)
  end)
  return swatch
end

---------------------------------------------------------------------------
-- Group box: bordered panel with an accent title and underline
---------------------------------------------------------------------------
Widgets.GROUP_TITLE_H = 46

function Widgets.Group(parent, title)
  local box = CreateFrame("Frame", nil, parent, template)
  Theme.Panel(box, C.GROUP, C.BORDER)

  local heading = Theme.Text(box, 18, C.TEXT)
  heading:SetPoint("TOPLEFT", 14, -12)
  heading:SetText(title)

  local underline = box:CreateTexture(nil, "ARTWORK")
  underline:SetHeight(2)
  underline:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -3)
  underline:SetWidth((heading:GetStringWidth() or 60) + 8)

  Theme.Bind(function(a)
    heading:SetTextColor(a.r, a.g, a.b)
    underline:SetColorTexture(a.r, a.g, a.b, 1)
  end)
  return box, heading
end

return Widgets
