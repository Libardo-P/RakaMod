RakaMod = RakaMod or {}

-- Window chrome for the settings window: sidebar (brand, search, nav), header, tab row,
-- body panel and footer. Page content and navigation state live in Settings.lua.
local Theme = RakaMod.Theme
local Widgets = RakaMod.Widgets
local Shell = {}
RakaMod.Shell = Shell

local C = Theme.COLORS
local template = Theme.template

Shell.WIDTH, Shell.HEIGHT = 1000, 700
Shell.SIDEBAR_WIDTH = 228
Shell.NAV_HEIGHT = 34
Shell.NAV_GAP = 3
Shell.NAV_PAD = 12
Shell.HEADER_HEIGHT = 84
Shell.TAB_HEIGHT = 32
Shell.FOOTER_HEIGHT = 58
Shell.BODY_MARGIN = 16

local BRAND_HEIGHT = 70
local SEARCH_HEIGHT = 30

-- Nav button: icon (optional) + label, filled with the accent while selected.
function Shell.NewNavButton(parent, label, iconPath, hasStatus)
  local button = CreateFrame("Button", nil, parent)
  button:SetHeight(Shell.NAV_HEIGHT)
  button.selected = false
  button.hover = false
  button.statusOn = false

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0)

  local icon
  if iconPath then
    icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 12, 0)
    icon:SetTexture(iconPath)
  end

  local text = Theme.Text(button, 16, C.NAV_IDLE)
  if icon then
    text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
  else
    text:SetPoint("LEFT", 14, 0)
  end
  text:SetJustifyH("LEFT")
  text:SetText(label)
  button.label = text

  local dot = button:CreateTexture(nil, "ARTWORK")
  dot:SetSize(8, 8)
  dot:SetPoint("RIGHT", -12, 0)
  dot:SetShown(hasStatus and true or false)

  function button:Paint(a)
    a = a or Theme.accent
    local r, g, b
    if self.selected then
      bg:SetColorTexture(a.r, a.g, a.b, 1)
      r, g, b = a.tr, a.tg, a.tb
    elseif self.hover then
      bg:SetColorTexture(1, 1, 1, 0.06)
      r, g, b = 1, 1, 1
    else
      bg:SetColorTexture(0, 0, 0, 0)
      r, g, b = C.NAV_IDLE.r, C.NAV_IDLE.g, C.NAV_IDLE.b
    end
    text:SetTextColor(r, g, b)
    if icon then
      icon:SetVertexColor(r, g, b)
    end
    if self.statusOn then
      if self.selected then
        dot:SetColorTexture(a.tr, a.tg, a.tb, 1)
      else
        dot:SetColorTexture(a.r, a.g, a.b, 1)
      end
    else
      dot:SetColorTexture(C.MUTED.r, C.MUTED.g, C.MUTED.b, 0.5)
    end
  end
  function button:SetSelected(value)
    self.selected = value and true or false
    self:Paint()
  end
  function button:SetStatus(on)
    self.statusOn = on and true or false
    self:Paint()
  end
  button:SetScript("OnEnter", function(self)
    self.hover = true
    self:Paint()
  end)
  button:SetScript("OnLeave", function(self)
    self.hover = false
    self:Paint()
  end)
  Theme.Bind(function(a)
    button:Paint(a)
  end)
  return button
end

-- Tab button: dark when idle, body-colored with accent text and underline when selected.
function Shell.NewTabButton(parent, label)
  local button = CreateFrame("Button", nil, parent, template)
  button:SetHeight(Shell.TAB_HEIGHT)
  Theme.Panel(button, C.FIELD, C.BORDER)
  button.selected = false
  button.hover = false

  local text = Theme.Text(button, 16, C.MUTED)
  text:SetPoint("CENTER", 0, 1)
  text:SetText(label)
  button.label = text

  local underline = button:CreateTexture(nil, "OVERLAY")
  underline:SetHeight(2)
  underline:SetPoint("BOTTOMLEFT", 6, 3)
  underline:SetPoint("BOTTOMRIGHT", -6, 3)

  function button:Paint(a)
    a = a or Theme.accent
    if self.selected then
      Theme.SetFill(self, C.BODY.r, C.BODY.g, C.BODY.b, 1)
      Theme.SetBorder(self, C.BORDER)
      text:SetTextColor(a.r, a.g, a.b)
      underline:SetColorTexture(a.r, a.g, a.b, 1)
      underline:Show()
    else
      Theme.SetFill(self, C.FIELD.r, C.FIELD.g, C.FIELD.b, 1)
      Theme.SetBorder(self, C.BORDER)
      underline:Hide()
      if self.hover then
        text:SetTextColor(C.TEXT.r, C.TEXT.g, C.TEXT.b)
      else
        text:SetTextColor(C.MUTED.r, C.MUTED.g, C.MUTED.b)
      end
    end
  end
  function button:SetSelected(value)
    self.selected = value and true or false
    self:Paint()
  end
  function button:SetLabel(value)
    text:SetText(value)
    self:SetWidth(math.max(92, (text:GetStringWidth() or 50) + 36))
  end
  button:SetScript("OnEnter", function(self)
    self.hover = true
    self:Paint()
  end)
  button:SetScript("OnLeave", function(self)
    self.hover = false
    self:Paint()
  end)
  Theme.Bind(function(a)
    button:Paint(a)
  end)
  return button
end

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
  return nil
end
Shell.AddonVersion = AddonVersion

function Shell.Create()
  local shell = {}

  local frame = CreateFrame("Frame", "RakaModSettingsFrame", UIParent, template)
  frame:SetSize(Shell.WIDTH, Shell.HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:Hide()
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  Theme.Panel(frame, C.SHELL, C.BORDER, 0.98)
  if UISpecialFrames then
    UISpecialFrames[#UISpecialFrames + 1] = "RakaModSettingsFrame"
  end
  shell.frame = frame

  -- Sidebar -----------------------------------------------------------------
  local sidebar = CreateFrame("Frame", nil, frame, template)
  sidebar:SetPoint("TOPLEFT", 0, 0)
  sidebar:SetPoint("BOTTOMLEFT", 0, 0)
  sidebar:SetWidth(Shell.SIDEBAR_WIDTH)
  Theme.Panel(sidebar, C.SIDEBAR)
  shell.sidebar = sidebar

  local logo = sidebar:CreateTexture(nil, "ARTWORK")
  logo:SetSize(34, 34)
  logo:SetPoint("TOPLEFT", 18, -18)
  logo:SetTexture((RakaMod.Media and RakaMod.Media.IconPath) or "Interface\\AddOns\\RakaMod\\Media\\icon")

  local brand = Theme.Text(sidebar, 24, C.TEXT)
  brand:SetPoint("LEFT", logo, "RIGHT", 10, 0)
  brand:SetText("RakaMod")

  local brandRule = sidebar:CreateTexture(nil, "ARTWORK")
  brandRule:SetColorTexture(C.BORDER.r, C.BORDER.g, C.BORDER.b, 1)
  brandRule:SetHeight(1)
  brandRule:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 18, -BRAND_HEIGHT)
  brandRule:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -18, -BRAND_HEIGHT)

  local searchTop = BRAND_HEIGHT + 16
  local searchBox = CreateFrame("EditBox", nil, sidebar, template)
  searchBox:SetHeight(SEARCH_HEIGHT)
  searchBox:SetPoint("TOPLEFT", sidebar, "TOPLEFT", Shell.NAV_PAD, -searchTop)
  searchBox:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -Shell.NAV_PAD, -searchTop)
  searchBox:SetAutoFocus(false)
  searchBox:SetMaxLetters(40)
  searchBox:SetFont(Theme.FontPath(), 14, "")
  searchBox:SetTextInsets(10, 8, 0, 0)
  searchBox:SetTextColor(C.TEXT.r, C.TEXT.g, C.TEXT.b)
  Theme.Panel(searchBox, C.FIELD, C.BORDER)
  shell.searchBox = searchBox

  local hint = Theme.Text(searchBox, 14, C.MUTED)
  hint:SetPoint("LEFT", 10, 0)
  hint:SetText("Search Features...")
  shell.searchHint = hint

  shell.navTop = searchTop + SEARCH_HEIGHT + 14

  local noResults = Theme.Text(sidebar, 14, C.MUTED)
  noResults:SetPoint("TOPLEFT", sidebar, "TOPLEFT", Shell.NAV_PAD + 6, -(shell.navTop + 6))
  noResults:SetText("No matching options")
  noResults:Hide()
  shell.noResults = noResults

  -- Content column ----------------------------------------------------------
  local content = CreateFrame("Frame", nil, frame, template)
  content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
  content:SetPoint("BOTTOMRIGHT", 0, 0)
  Theme.Panel(content, C.CONTENT)
  shell.content = content

  local title = Theme.Text(content, 30, C.TEXT)
  title:SetPoint("TOPLEFT", 22, -16)
  title:SetText("RakaMod Settings")
  shell.title = title

  local version = Theme.Text(content, 15, C.MUTED)
  version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  version:SetText(AddonVersion() or "")
  shell.version = version

  local close = Widgets.Button(content, "X", 32, 32)
  close:SetPoint("TOPRIGHT", -16, -16)
  close:SetScript("OnClick", function()
    frame:Hide()
  end)
  close:SetFrameLevel((content:GetFrameLevel() or 1) + 20)
  frame.Close = close
  shell.close = close

  -- Footer ------------------------------------------------------------------
  local footer = CreateFrame("Frame", nil, content, template)
  footer:SetPoint("BOTTOMLEFT", 0, 0)
  footer:SetPoint("BOTTOMRIGHT", 0, 0)
  footer:SetHeight(Shell.FOOTER_HEIGHT)
  Theme.Panel(footer, C.SIDEBAR)
  local footerRule = footer:CreateTexture(nil, "ARTWORK")
  footerRule:SetColorTexture(C.BORDER.r, C.BORDER.g, C.BORDER.b, 1)
  footerRule:SetPoint("TOPLEFT", 0, 0)
  footerRule:SetPoint("TOPRIGHT", 0, 0)
  footerRule:SetHeight(1)
  shell.footer = footer

  local reload = Widgets.Button(footer, "Apply & Reload UI", 170, 32)
  reload:SetPoint("RIGHT", -Shell.BODY_MARGIN, 0)
  reload:SetScript("OnClick", function()
    ReloadUI()
  end)
  shell.reloadButton = reload

  -- Tab row, toolbar and body ----------------------------------------------
  local tabRow = CreateFrame("Frame", nil, content)
  tabRow:SetPoint("TOPLEFT", content, "TOPLEFT", Shell.BODY_MARGIN, -Shell.HEADER_HEIGHT)
  tabRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -Shell.BODY_MARGIN, -Shell.HEADER_HEIGHT)
  tabRow:SetHeight(Shell.TAB_HEIGHT)
  -- Above the body so the selected tab overlaps its top border.
  tabRow:SetFrameLevel((content:GetFrameLevel() or 1) + 6)
  shell.tabRow = tabRow

  local toolbar = CreateFrame("Frame", nil, tabRow)
  toolbar:SetPoint("BOTTOMRIGHT", tabRow, "BOTTOMRIGHT", 0, 2)
  toolbar:SetSize(460, 28)
  shell.toolbar = toolbar

  local body = CreateFrame("Frame", nil, content, template)
  body:SetPoint("TOPLEFT", tabRow, "BOTTOMLEFT", 0, 1)
  body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -Shell.BODY_MARGIN, 12)
  Theme.Panel(body, C.BODY, C.BORDER)
  shell.body = body

  local desc = Theme.Text(body, 14, C.MUTED)
  desc:SetPoint("TOPLEFT", body, "TOPLEFT", 18, -12)
  desc:SetPoint("TOPRIGHT", body, "TOPRIGHT", -18, -12)
  desc:SetJustifyH("LEFT")
  desc:SetJustifyV("TOP")
  desc:SetWordWrap(true)
  shell.desc = desc

  local pageHost = CreateFrame("Frame", nil, body)
  pageHost:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -54)
  pageHost:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -12, 12)
  shell.pageHost = pageHost

  return shell
end

return Shell
