RakaMod = RakaMod or {}

-- Blizzard's global Settings API (Esc > Options) must be captured before the local table below shadows it.
local BlizzardSettings = _G.Settings
local Settings = {}
RakaMod.Settings = Settings

-- Palette: neutral charcoal with a blue accent.
local ACCENT = { r = 0.25, g = 0.62, b = 1.00 }
local ACCENT_DIM = { r = 0.11, g = 0.22, b = 0.38 }
local ACCENT_FILL = { r = 0.14, g = 0.42, b = 0.82 } -- behind white text
local SHELL = { r = 0.055, g = 0.055, b = 0.060 }
local SIDEBAR_BG = { r = 0.070, g = 0.070, b = 0.075 }
local CONTENT_BG = { r = 0.095, g = 0.095, b = 0.100 }
local CARD_BG = { r = 0.125, g = 0.125, b = 0.135 }
local FIELD_BG = { r = 0.072, g = 0.072, b = 0.078 }
local MUTED = { r = 0.58, g = 0.58, b = 0.62 }
local BORDER = { r = 0.22, g = 0.22, b = 0.24 }
local TEXT = { r = 0.90, g = 0.90, b = 0.92 }

local SIDEBAR_WIDTH = 210
local NAV_HEIGHT = 32
local NAV_GAP = 2
local NAV_PAD = 12
local HEADER_HEIGHT = 18
local HEADER_GAP = 12
local BRAND_HEIGHT = 56
local SEARCH_HEIGHT = 28
local FOOTER_HEIGHT = 52
local TAB_HEIGHT = 28
local CARD_GAP = 12
local CARD_PAD = 14
local CARD_TITLE_H = 40
local PILL_W, PILL_H = 46, 22
local PAIR_ROW = 26
local PAIR_COL2_X = 350
local frameWidth, frameHeight = 980, 660

local checks = {}
local sliders = {}
local swatches = {}
local dropdowns = {}
local applying = false
local skinned = false
local pages = {}
local navs = {}
local pageNav = {}
local lastTab = {}
local resets = {}
local selectedNav = "general"
local selectedTab = "general"
local revealNote
local gradientNote
local pageTitle
local pageDesc
local pageBody
local tabRow
local tabButtons = {}

local template = BackdropTemplateMixin and "BackdropTemplate" or nil

-- Description shown under the page title, keyed by tab (page) key.
local PAGE_META = {
  general = "Addon-wide options.",
  generalAbout = "About this addon and how to open these settings.",
  features = "Shared background fade for Escape and AFK. Grain is optional.",
  overlay = "Left Escape overlay: professions, collections, and played time beside the game menu.",
  afk = "Full-screen AFK overlay with RakaMod branding, timer, character model, and Ellesmere patch notes. Dismiss with any key or click.",
  reveal = "Force-show the Ellesmere player frame while casting, while effective health is above 100% (absorbs / overshield), on mouseover, or in combat. It never hides the frame itself.",
  zoneText = "Custom zone change text appearance.",
  gradient = "Health bar gradients shift by class, NPC reaction, and unit state.",
  gradientBars = "Power and castbar gradient shifts. Colors are saved now; painting comes later.",
  gradientResources = "Class resource gradient shifts. Colors are saved now; painting comes later.",
  gradientNameplates = "Nameplate threat and classification gradients. Colors are saved now; painting comes later.",
}

-- Category headers are non-clickable labels; items open a page with a top tab row.
local ICON_DIR = "Interface\\Icons\\"
local NAV = {
  { header = "CORE" },
  {
    key = "general",
    label = "General",
    icon = ICON_DIR .. "INV_Misc_Gear_01",
    tabs = {
      { key = "general", label = "General" },
      { key = "generalAbout", label = "About" },
    },
  },
  { header = "FEATURES" },
  {
    key = "features",
    label = "Features",
    icon = ICON_DIR .. "INV_Misc_Wrench_01",
    tabs = { { key = "features", label = "Background" } },
  },
  {
    key = "overlay",
    label = "Game Menu",
    icon = ICON_DIR .. "INV_Misc_Book_09",
    master = { section = "overlay", key = "enabled", label = "Enabled" },
    tabs = { { key = "overlay", label = "Panels" } },
  },
  {
    key = "afk",
    label = "AFK",
    icon = ICON_DIR .. "INV_Misc_PocketWatch_01",
    master = { section = "afk", key = "enabled", label = "Enabled" },
    tabs = { { key = "afk", label = "Behavior" } },
  },
  { header = "APPEARANCE" },
  {
    key = "reveal",
    label = "Player Frame",
    icon = ICON_DIR .. "Spell_Holy_PowerWordShield",
    master = { section = "reveal", key = "enabled", label = "Enabled" },
    tabs = { { key = "reveal", label = "Triggers" } },
  },
  {
    key = "zoneText",
    label = "Zone Text",
    icon = ICON_DIR .. "INV_Misc_Map_01",
    master = { section = "zoneText", key = "enabled", label = "Enabled" },
    tabs = { { key = "zoneText", label = "Style" } },
  },
  {
    key = "gradient",
    label = "Gradient Mode",
    icon = ICON_DIR .. "INV_Misc_Gem_Sapphire_01",
    -- Master switch shown in the page header, above every tab of this page.
    master = { section = "gradient", key = "enabled", label = "Enabled" },
    tabs = { { key = "gradient", label = "Health" } },
  },
}

-- Bars, Resources and Nameplates store colors, but Gradient.lua does not paint them yet.
-- Keep them hidden until it does, then flip this flag.
local SHOW_UNPAINTED_GRADIENT_TABS = false
if SHOW_UNPAINTED_GRADIENT_TABS then
  local gradientTabs = NAV[#NAV].tabs
  gradientTabs[#gradientTabs + 1] = { key = "gradientBars", label = "Bars" }
  gradientTabs[#gradientTabs + 1] = { key = "gradientResources", label = "Resources" }
  gradientTabs[#gradientTabs + 1] = { key = "gradientNameplates", label = "Nameplates" }
end

local function ApplyPanel(target, color, border, borderAlpha)
  if not target.SetBackdrop then
    local fill = target:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(color.r, color.g, color.b, color.a or 1)
    return
  end
  target:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  target:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
  if border then
    target:SetBackdropBorderColor(border.r, border.g, border.b, borderAlpha or 1)
  else
    target:SetBackdropBorderColor(0, 0, 0, 0)
  end
end

local function MakeButton(parent, text, width, primary)
  local button = CreateFrame("Button", nil, parent, template)
  button:SetSize(width, 28)
  local function paint(hover)
    if not button.SetBackdropColor then
      return
    end
    if primary then
      local k = hover and 1.15 or 1
      button:SetBackdropColor(math.min(1, ACCENT_FILL.r * k), math.min(1, ACCENT_FILL.g * k), math.min(1, ACCENT_FILL.b * k), 1)
      button:SetBackdropBorderColor(ACCENT.r * 0.7, ACCENT.g * 0.7, ACCENT.b * 0.7, 1)
    else
      button:SetBackdropColor(hover and 0.18 or FIELD_BG.r, hover and 0.18 or FIELD_BG.g, hover and 0.19 or FIELD_BG.b, 1)
      if hover then
        button:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
      else
        button:SetBackdropBorderColor(BORDER.r, BORDER.g, BORDER.b, 1)
      end
    end
  end
  ApplyPanel(button, FIELD_BG, BORDER)
  paint(false)
  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("CENTER")
  label:SetText(text)
  if primary then
    label:SetTextColor(1, 1, 1)
  else
    label:SetTextColor(TEXT.r, TEXT.g, TEXT.b)
  end
  button.label = label
  button:SetScript("OnEnter", function()
    paint(true)
  end)
  button:SetScript("OnLeave", function()
    paint(false)
  end)
  return button
end

local frame = CreateFrame("Frame", "RakaModSettingsFrame", UIParent, template)
frame:SetSize(frameWidth, frameHeight)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
ApplyPanel(frame, { r = SHELL.r, g = SHELL.g, b = SHELL.b, a = 0.98 }, BORDER)

if UISpecialFrames then
  UISpecialFrames[#UISpecialFrames + 1] = "RakaModSettingsFrame"
end

---------------------------------------------------------------------------
-- Sidebar: brand, search, icon nav
---------------------------------------------------------------------------
local sidebar = CreateFrame("Frame", nil, frame, template)
sidebar:SetPoint("TOPLEFT", 0, 0)
sidebar:SetPoint("BOTTOMLEFT", 0, 0)
sidebar:SetWidth(SIDEBAR_WIDTH)
ApplyPanel(sidebar, SIDEBAR_BG)

local brand = CreateFrame("Frame", nil, sidebar)
brand:SetPoint("TOPLEFT", 0, 0)
brand:SetPoint("TOPRIGHT", 0, 0)
brand:SetHeight(BRAND_HEIGHT)

local titleIconPath = (RakaMod.Media and RakaMod.Media.IconPath) or "Interface\\AddOns\\RakaMod\\Media\\icon"
local titleIcon = brand:CreateTexture(nil, "ARTWORK")
titleIcon:SetSize(28, 28)
titleIcon:SetPoint("LEFT", 16, 0)
titleIcon:SetTexture(titleIconPath)

local brandTitle = brand:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
brandTitle:SetPoint("LEFT", titleIcon, "RIGHT", 10, 0)
brandTitle:SetText("RakaMod")
brandTitle:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)

local searchTop = BRAND_HEIGHT + 8
local searchBox = CreateFrame("EditBox", nil, sidebar, template)
searchBox:SetHeight(SEARCH_HEIGHT)
searchBox:SetPoint("TOPLEFT", sidebar, "TOPLEFT", NAV_PAD, -searchTop)
searchBox:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -NAV_PAD, -searchTop)
searchBox:SetAutoFocus(false)
searchBox:SetMaxLetters(40)
searchBox:SetFontObject(GameFontHighlightSmall)
searchBox:SetTextInsets(28, 8, 0, 0)
searchBox:SetTextColor(TEXT.r, TEXT.g, TEXT.b)
ApplyPanel(searchBox, FIELD_BG, BORDER)

local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
searchIcon:SetSize(14, 14)
searchIcon:SetPoint("LEFT", 9, 0)
searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
searchIcon:SetVertexColor(MUTED.r, MUTED.g, MUTED.b)

local searchHint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
searchHint:SetPoint("LEFT", 28, 0)
searchHint:SetText("Search options...")
searchHint:SetTextColor(MUTED.r, MUTED.g, MUTED.b)

local navItems = {}
local noResults = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
noResults:SetPoint("TOPLEFT", sidebar, "TOPLEFT", NAV_PAD + 4, -(searchTop + SEARCH_HEIGHT + 18))
noResults:SetText("No matching options")
noResults:SetTextColor(MUTED.r, MUTED.g, MUTED.b)
noResults:Hide()

local function PaintNav(button, selected, hover)
  button.selected = selected and true or false
  if button.selected then
    button.bg:SetColorTexture(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.55)
    button.bar:Show()
    button.label:SetTextColor(1, 1, 1)
    button.icon:SetDesaturated(false)
    button.icon:SetAlpha(1)
  else
    if hover then
      button.bg:SetColorTexture(1, 1, 1, 0.05)
    else
      button.bg:SetColorTexture(0, 0, 0, 0)
    end
    button.bar:Hide()
    button.label:SetTextColor(hover and 0.95 or 0.70, hover and 0.95 or 0.70, hover and 0.97 or 0.74)
    button.icon:SetDesaturated(true)
    button.icon:SetAlpha(hover and 0.95 or 0.65)
  end
end

local function LayoutNav()
  local query = string.lower(searchBox:GetText() or "")
  query = query:gsub("^%s+", ""):gsub("%s+$", "")
  local yOff = -(searchTop + SEARCH_HEIGHT + 16)
  local shown = 0
  local pending
  for i = 1, #navItems do
    local item = navItems[i]
    if item.header then
      item.header:Hide()
      pending = item
    else
      local nav = navs[item.key]
      local match = query == "" or (nav.search and string.find(nav.search, query, 1, true))
      if match then
        if pending then
          if shown > 0 then
            yOff = yOff - HEADER_GAP
          end
          pending.header:ClearAllPoints()
          pending.header:SetPoint("TOPLEFT", sidebar, "TOPLEFT", NAV_PAD + 4, yOff)
          pending.header:Show()
          yOff = yOff - HEADER_HEIGHT
          pending = nil
        end
        item.button:ClearAllPoints()
        item.button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", NAV_PAD, yOff)
        item.button:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -NAV_PAD, yOff)
        item.button:Show()
        yOff = yOff - (NAV_HEIGHT + NAV_GAP)
        shown = shown + 1
      else
        item.button:Hide()
      end
    end
  end
  noResults:SetShown(shown == 0)
  return shown
end

do
  for i = 1, #NAV do
    local nav = NAV[i]
    if nav.header then
      local header = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      header:SetJustifyH("LEFT")
      header:SetText(nav.header)
      header:SetTextColor(MUTED.r, MUTED.g, MUTED.b)
      navItems[#navItems + 1] = { header = header }
    elseif nav.key then
      local button = CreateFrame("Button", nil, sidebar)
      button:SetHeight(NAV_HEIGHT)

      local bg = button:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0, 0, 0, 0)
      button.bg = bg

      local bar = button:CreateTexture(nil, "ARTWORK")
      bar:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
      bar:SetPoint("TOPLEFT", 0, 0)
      bar:SetPoint("BOTTOMLEFT", 0, 0)
      bar:SetWidth(3)
      bar:Hide()
      button.bar = bar

      local icon = button:CreateTexture(nil, "ARTWORK")
      icon:SetSize(18, 18)
      icon:SetPoint("LEFT", 12, 0)
      icon:SetTexture(nav.icon)
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      button.icon = icon

      -- Status dot for pages with a master switch (blue = on, grey = off).
      local dot = button:CreateTexture(nil, "ARTWORK")
      dot:SetSize(8, 8)
      dot:SetPoint("RIGHT", -12, 0)
      dot:SetColorTexture(MUTED.r, MUTED.g, MUTED.b, 0.5)
      dot:SetShown(nav.master ~= nil)
      button.dot = dot

      local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      label:SetPoint("LEFT", icon, "RIGHT", 10, 0)
      label:SetJustifyH("LEFT")
      label:SetText(nav.label)
      button.label = label

      button:SetScript("OnClick", function()
        Settings:SelectPage(nav.key)
      end)
      button:SetScript("OnEnter", function(self)
        PaintNav(self, self.selected, true)
      end)
      button:SetScript("OnLeave", function(self)
        PaintNav(self, self.selected, false)
      end)

      local search = string.lower(nav.label)
      for t = 1, #nav.tabs do
        search = search .. " " .. string.lower(nav.tabs[t].label)
        pageNav[nav.tabs[t].key] = nav.key
      end
      navs[nav.key] = { button = button, label = nav.label, tabs = nav.tabs, search = search, master = nav.master }
      navItems[#navItems + 1] = { key = nav.key, button = button }
      PaintNav(button, false, false)
    end
  end
  LayoutNav()
end

local function RefreshSearchHint()
  if (searchBox:GetText() or "") == "" and not searchBox:HasFocus() then
    searchHint:Show()
  else
    searchHint:Hide()
  end
end

searchBox:SetScript("OnTextChanged", function()
  RefreshSearchHint()
  LayoutNav()
end)
searchBox:SetScript("OnEditFocusGained", function(self)
  searchHint:Hide()
  self:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
end)
searchBox:SetScript("OnEditFocusLost", function(self)
  self:SetBackdropBorderColor(BORDER.r, BORDER.g, BORDER.b, 1)
  RefreshSearchHint()
end)
searchBox:SetScript("OnEscapePressed", function(self)
  if (self:GetText() or "") ~= "" then
    self:SetText("")
  end
  self:ClearFocus()
end)
searchBox:SetScript("OnEnterPressed", function(self)
  for i = 1, #navItems do
    local item = navItems[i]
    if item.key and item.button:IsShown() then
      Settings:SelectPage(item.key)
      break
    end
  end
  self:ClearFocus()
end)

---------------------------------------------------------------------------
-- Content: header, top tab row, page body, footer
---------------------------------------------------------------------------
local contentHost = CreateFrame("Frame", nil, frame, template)
contentHost:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
contentHost:SetPoint("BOTTOMRIGHT", 0, 0)
ApplyPanel(contentHost, CONTENT_BG)

local close = CreateFrame("Button", nil, contentHost, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
close:SetScript("OnClick", function()
  frame:Hide()
end)
frame.Close = close

local footer = CreateFrame("Frame", nil, contentHost, template)
footer:SetPoint("BOTTOMLEFT", 0, 0)
footer:SetPoint("BOTTOMRIGHT", 0, 0)
footer:SetHeight(FOOTER_HEIGHT)
ApplyPanel(footer, SIDEBAR_BG)

local footerRule = footer:CreateTexture(nil, "ARTWORK")
footerRule:SetColorTexture(BORDER.r, BORDER.g, BORDER.b, 1)
footerRule:SetPoint("TOPLEFT", 0, 0)
footerRule:SetPoint("TOPRIGHT", 0, 0)
footerRule:SetHeight(1)

local pageHeader = CreateFrame("Frame", nil, contentHost)
pageHeader:SetPoint("TOPLEFT", 22, -18)
pageHeader:SetPoint("TOPRIGHT", -44, -18)
pageHeader:SetHeight(60)

pageTitle = pageHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
pageTitle:SetPoint("TOPLEFT", 0, 0)
pageTitle:SetJustifyH("LEFT")
pageTitle:SetTextColor(1, 1, 1)

pageDesc = pageHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pageDesc:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -6)
pageDesc:SetPoint("TOPRIGHT", pageHeader, "TOPRIGHT", 0, -28)
pageDesc:SetJustifyH("LEFT")
pageDesc:SetJustifyV("TOP")
pageDesc:SetWordWrap(true)
pageDesc:SetTextColor(MUTED.r, MUTED.g, MUTED.b)

tabRow = CreateFrame("Frame", nil, contentHost)
tabRow:SetPoint("TOPLEFT", pageHeader, "BOTTOMLEFT", 0, -14)
tabRow:SetPoint("TOPRIGHT", pageHeader, "BOTTOMRIGHT", 0, -14)
tabRow:SetHeight(TAB_HEIGHT)

local tabRule = tabRow:CreateTexture(nil, "ARTWORK")
tabRule:SetColorTexture(BORDER.r, BORDER.g, BORDER.b, 1)
tabRule:SetPoint("BOTTOMLEFT", 0, 0)
tabRule:SetPoint("BOTTOMRIGHT", 0, 0)
tabRule:SetHeight(1)

pageBody = CreateFrame("Frame", nil, contentHost)
pageBody:SetPoint("TOPLEFT", tabRow, "BOTTOMLEFT", 0, -14)
pageBody:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -14, 12)

close:SetFrameLevel((contentHost:GetFrameLevel() or 1) + 20)

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

local versionText = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
versionText:SetPoint("LEFT", 22, 0)
versionText:SetText("RakaMod " .. (AddonVersion() or ""))
versionText:SetTextColor(MUTED.r, MUTED.g, MUTED.b)

local reloadBtn = MakeButton(footer, "Apply & Reload", 130, true)
reloadBtn:SetPoint("RIGHT", -22, 0)
reloadBtn:SetScript("OnClick", function()
  ReloadUI()
end)

local RESET_TEXT = "Reset Page"
local resetBtn = MakeButton(footer, RESET_TEXT, 110, false)
resetBtn:SetPoint("RIGHT", reloadBtn, "LEFT", -10, 0)
local resetToken = 0
local resetArmed = false

local function DisarmReset()
  resetToken = resetToken + 1
  resetArmed = false
  resetBtn.label:SetText(RESET_TEXT)
end

---------------------------------------------------------------------------
-- Page selection
---------------------------------------------------------------------------
local function PaintTab(button, selected)
  button.selected = selected and true or false
  if not button.SetBackdropColor then
    return
  end
  if button.selected then
    button:SetBackdropColor(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.7)
    button:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
    button.label:SetTextColor(1, 1, 1)
  else
    button:SetBackdropColor(FIELD_BG.r, FIELD_BG.g, FIELD_BG.b, 1)
    button:SetBackdropBorderColor(BORDER.r, BORDER.g, BORDER.b, 1)
    button.label:SetTextColor(0.72, 0.72, 0.76)
  end
end

local function BuildTabRow(navKey, activeTab)
  local nav = navs[navKey]
  if not nav then
    return
  end
  local x = 0
  for i = 1, #nav.tabs do
    local tab = nav.tabs[i]
    local button = tabButtons[i]
    if not button then
      button = CreateFrame("Button", nil, tabRow, template)
      button:SetHeight(TAB_HEIGHT)
      ApplyPanel(button, FIELD_BG, BORDER)
      local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      label:SetPoint("CENTER")
      button.label = label
      button:SetScript("OnEnter", function(self)
        if not self.selected and self.SetBackdropBorderColor then
          self:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.6)
        end
      end)
      button:SetScript("OnLeave", function(self)
        PaintTab(self, self.selected)
      end)
      tabButtons[i] = button
    end
    button.label:SetText(tab.label)
    button:SetWidth(math.max(84, (button.label:GetStringWidth() or 40) + 32))
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", tabRow, "BOTTOMLEFT", x, 0)
    button:SetScript("OnClick", function()
      Settings:SelectPage(tab.key, true)
    end)
    PaintTab(button, tab.key == activeTab)
    button:Show()
    x = x + button:GetWidth() + 6
  end
  for i = #nav.tabs + 1, #tabButtons do
    tabButtons[i]:Hide()
  end
end

-- Header master switches (one per nav page that has one, created with the controls
-- below). Only the selected page's switch is visible; the tabs dim while it is off.
local masters = {}

local function UpdateMaster()
  for navKey, entry in pairs(navs) do
    local m = masters[navKey]
    if m then
      local visible = navKey == selectedNav
      local on = m.pill:GetChecked()
      m.label:SetShown(visible)
      m.pill:SetShown(visible)
      m.note:SetShown(visible and m.noteWanted)
      if entry.button.dot then
        if on then
          entry.button.dot:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
        else
          entry.button.dot:SetColorTexture(MUTED.r, MUTED.g, MUTED.b, 0.5)
        end
      end
      for i = 1, #entry.tabs do
        local page = pages[entry.tabs[i].key]
        if page and page.page then
          page.page:SetAlpha(on and 1 or 0.45)
        end
      end
    end
  end
end
local function UpdatePageHeader()
  local nav = navs[selectedNav]
  if pageTitle then
    pageTitle:SetText((nav and nav.label) or "")
  end
  if pageDesc then
    pageDesc:SetText(PAGE_META[selectedTab] or "")
  end
end

-- exactTab: key is a tab key (a tab can share its nav's key, e.g. "general").
function Settings:SelectPage(key, exactTab)
  local navKey, tabKey
  if navs[key] and not (exactTab and pageNav[key]) then
    navKey = key
    tabKey = lastTab[key] or navs[key].tabs[1].key
  elseif pageNav[key] then
    navKey = pageNav[key]
    tabKey = key
  else
    return
  end
  if not pages[tabKey] or not pages[tabKey].page then
    return
  end
  selectedNav, selectedTab = navKey, tabKey
  lastTab[navKey] = tabKey
  UpdatePageHeader()
  for pageKey, entry in pairs(pages) do
    if entry.page then
      if pageKey == tabKey then
        entry.page:Show()
      else
        entry.page:Hide()
      end
    end
  end
  for key2, nav in pairs(navs) do
    PaintNav(nav.button, key2 == navKey, false)
  end
  BuildTabRow(navKey, tabKey)
  UpdateMaster()
  DisarmReset()
end

local function OnMouseWheel(scroll, delta)
  local step = delta > 0 and -40 or 40
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
local pickerAccepted = false
local rakaPicker
local pickerButtons = {}
local pickerFields = {}
local editingRgb = false
local ORANGE = { r = ACCENT.r, g = ACCENT.g, b = ACCENT.b }

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

local function SetupColorSelectTextures(dest)
  if dest.SetColorWheelTexture then
    pcall(dest.SetColorWheelTexture, dest, "Interface\\Buttons\\UI-ColorPicker-Wheel")
  end
  if dest.SetColorWheelThumbTexture then
    pcall(dest.SetColorWheelThumbTexture, dest, "Interface\\Buttons\\UI-ColorPicker-Buttons")
  end
  if dest.SetColorValueTexture then
    pcall(dest.SetColorValueTexture, dest, "Interface\\Buttons\\WHITE8x8")
  end
  if dest.SetColorValueThumbTexture then
    pcall(dest.SetColorValueThumbTexture, dest, "Interface\\Buttons\\UI-ColorPicker-Buttons")
  end
  if not ColorPickerFrame then
    return
  end
  local function copy(getter, setter)
    if not getter or not setter then
      return
    end
    local ok, tex = pcall(getter, ColorPickerFrame)
    if ok and tex then
      pcall(setter, dest, tex)
    end
  end
  copy(ColorPickerFrame.GetColorWheelTexture, dest.SetColorWheelTexture)
  copy(ColorPickerFrame.GetColorWheelThumbTexture, dest.SetColorWheelThumbTexture)
  copy(ColorPickerFrame.GetColorValueTexture, dest.SetColorValueTexture)
  copy(ColorPickerFrame.GetColorValueThumbTexture, dest.SetColorValueThumbTexture)
end

local function LayoutColorSelect(select)
  if not select then
    return
  end
  local wheel = select.GetColorWheelTexture and select:GetColorWheelTexture()
  local wheelThumb = select.GetColorWheelThumbTexture and select:GetColorWheelThumbTexture()
  local value = select.GetColorValueTexture and select:GetColorValueTexture()
  local valueThumb = select.GetColorValueThumbTexture and select:GetColorValueThumbTexture()
  if wheel then
    wheel:ClearAllPoints()
    wheel:SetSize(128, 128)
    wheel:SetPoint("TOPLEFT", select, "TOPLEFT", 0, 0)
  end
  if wheelThumb then
    wheelThumb:SetSize(10, 10)
  end
  if value then
    value:ClearAllPoints()
    value:SetSize(16, 128)
    if wheel then
      value:SetPoint("TOPLEFT", wheel, "TOPRIGHT", 10, 0)
    else
      value:SetPoint("TOPLEFT", select, "TOPLEFT", 138, 0)
    end
  end
  if valueThumb then
    valueThumb:SetSize(16, 8)
  end
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
  LayoutColorSelect(select)
  f.select = select

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
    SetupColorSelectTextures(select)
    LayoutColorSelect(select)
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

local cachedGradientDefaults
local function GradientDefaults()
  if not cachedGradientDefaults and RakaMod.Logic and RakaMod.Logic.BuildGradientDefaults then
    cachedGradientDefaults = RakaMod.Logic.BuildGradientDefaults()
  end
  return cachedGradientDefaults
end

local function DefaultValue(section, key)
  local defaults = RakaMod.Core and RakaMod.Core.DEFAULTS
  local saved = defaults and defaults[section]
  return saved and saved[key]
end

---------------------------------------------------------------------------
-- Page + card layout
---------------------------------------------------------------------------
local function IndexLabel(ctx, text)
  local nav = navs[ctx.navKey]
  if nav and type(text) == "string" then
    nav.search = (nav.search or "") .. " " .. string.lower(text)
  end
end

local function RegisterReset(ctx, fn)
  local list = resets[ctx.navKey]
  if not list then
    list = {}
    resets[ctx.navKey] = list
  end
  list[#list + 1] = fn
end

local function ResetKey(section, key)
  local saved = RakaMod.db and RakaMod.db[section]
  if saved then
    saved[key] = DefaultValue(section, key)
  end
end

local function CreatePage(pageKey, navKey)
  local page = CreateFrame("Frame", nil, pageBody)
  page:SetAllPoints()
  page:Hide()

  local scroll = CreateFrame("ScrollFrame", "RakaModSettingsScroll_" .. pageKey, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  scroll:SetScript("OnMouseWheel", function(_, delta)
    OnMouseWheel(scroll, delta)
  end)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(640, 400)
  scroll:SetScrollChild(content)

  local colY = { 0, 0 }
  local ctx = {
    key = pageKey,
    navKey = navKey,
    page = page,
    scroll = scroll,
    content = content,
  }

  -- col: 1 or 2 for a half-width column, nil for a full-width card.
  function ctx.Card(title, col)
    local top
    if col == 1 or col == 2 then
      top = colY[col]
    else
      top = math.min(colY[1], colY[2])
    end

    local box = CreateFrame("Frame", nil, content, template)
    if col == 1 then
      box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
      box:SetPoint("TOPRIGHT", content, "TOP", -CARD_GAP / 2, top)
    elseif col == 2 then
      box:SetPoint("TOPLEFT", content, "TOP", CARD_GAP / 2, top)
      box:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, top)
    else
      box:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
      box:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, top)
    end
    box:SetHeight(CARD_TITLE_H + 20)
    ApplyPanel(box, CARD_BG, BORDER)

    local heading = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", CARD_PAD, -12)
    heading:SetText(title)
    heading:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)

    local rule = box:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(BORDER.r, BORDER.g, BORDER.b, 1)
    rule:SetPoint("TOPLEFT", CARD_PAD, -34)
    rule:SetPoint("TOPRIGHT", -CARD_PAD, -34)
    rule:SetHeight(1)

    local y = -CARD_TITLE_H
    local card = {
      key = pageKey,
      navKey = navKey,
      scroll = scroll,
      content = box,
      padX = CARD_PAD,
      hintWidth = (col and 296) or 640,
      LocalY = function()
        return y
      end,
      Advance = function(step)
        y = y - (step or 30)
      end,
    }
    function card.Done()
      local height = (-y) + 12
      box:SetHeight(height)
      local nextTop = top - height - CARD_GAP
      if col == 1 or col == 2 then
        colY[col] = nextTop
      else
        colY[1] = nextTop
        colY[2] = nextTop
      end
    end
    return card
  end

  function ctx.Finish()
    local depth = math.min(colY[1], colY[2])
    content:SetHeight((-depth) + 8)
  end

  pages[pageKey] = pages[pageKey] or {}
  pages[pageKey].page = page
  pages[pageKey].ctx = ctx
  return ctx
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
local function MakeCheckbox(parent)
  local box = CreateFrame("Button", nil, parent, template)
  box:SetSize(18, 18)
  box:EnableMouse(true)
  ApplyPanel(box, FIELD_BG, BORDER)

  local mark = box:CreateTexture(nil, "OVERLAY")
  mark:SetPoint("TOPLEFT", 4, -4)
  mark:SetPoint("BOTTOMRIGHT", -4, 4)
  mark:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
  mark:Hide()

  local checked = false
  function box:GetChecked()
    return checked
  end
  function box:SetChecked(value)
    checked = value and true or false
    if checked then
      mark:Show()
      if box.SetBackdropBorderColor then
        box:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
      end
    else
      mark:Hide()
      if box.SetBackdropBorderColor then
        box:SetBackdropBorderColor(BORDER.r, BORDER.g, BORDER.b, 1)
      end
    end
  end
  box:SetChecked(false)
  return box
end

local function MakePillToggle(parent)
  local pill = CreateFrame("Button", nil, parent, template)
  pill:SetSize(PILL_W, PILL_H)
  pill:EnableMouse(true)
  ApplyPanel(pill, FIELD_BG, BORDER)

  local label = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("CENTER")
  pill.label = label

  local checked = false
  function pill:GetChecked()
    return checked
  end
  function pill:SetChecked(value)
    checked = value and true or false
    if checked then
      pill:SetBackdropColor(ACCENT_FILL.r, ACCENT_FILL.g, ACCENT_FILL.b, 1)
      pill:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
      label:SetText("ON")
      label:SetTextColor(1, 1, 1)
    else
      pill:SetBackdropColor(FIELD_BG.r, FIELD_BG.g, FIELD_BG.b, 1)
      pill:SetBackdropBorderColor(BORDER.r, BORDER.g, BORDER.b, 1)
      label:SetText("OFF")
      label:SetTextColor(MUTED.r, MUTED.g, MUTED.b)
    end
  end
  pill:SetChecked(false)
  return pill
end

local function BindToggle(control, section, key, afterChange)
  control:SetScript("OnClick", function(self)
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

-- style "toggle" = labeled ON/OFF button on the right; default = checkbox + label.
local function AddCheck(ctx, text, section, key, afterChange, style)
  IndexLabel(ctx, text)
  local control
  if style == "toggle" then
    local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", ctx.padX, ctx.LocalY() - 6)
    label:SetText(text)
    label:SetTextColor(TEXT.r, TEXT.g, TEXT.b)
    control = MakePillToggle(ctx.content)
    control:SetPoint("TOPRIGHT", ctx.content, "TOPRIGHT", -ctx.padX, ctx.LocalY() - 3)
    ctx.Advance(32)
  else
    control = MakeCheckbox(ctx.content)
    control:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", ctx.padX, ctx.LocalY() - 3)
    local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", control, "RIGHT", 10, 0)
    label:SetText(text)
    label:SetTextColor(TEXT.r, TEXT.g, TEXT.b)
    control:SetHitRectInsets(0, -((label:GetStringWidth() or 80) + 14), 0, 0)
    ctx.Advance(28)
  end
  BindToggle(control, section, key, afterChange)
  PassWheel(ctx.scroll, control)
  checks[#checks + 1] = { widget = control, section = section, key = key }
  RegisterReset(ctx, function()
    ResetKey(section, key)
  end)
  return control
end

local function AddSlider(ctx, text, section, key, minValue, maxValue)
  IndexLabel(ctx, text)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", ctx.padX, ctx.LocalY() - 5)
  label:SetText(text)
  label:SetTextColor(TEXT.r, TEXT.g, TEXT.b)

  -- Editable value box: click, type a number, Enter (or click away) to apply.
  local valueText = CreateFrame("EditBox", nil, ctx.content, template)
  valueText:SetSize(52, 22)
  valueText:SetPoint("TOPRIGHT", ctx.content, "TOPRIGHT", -ctx.padX, ctx.LocalY() - 2)
  valueText:SetAutoFocus(false)
  valueText:SetMaxLetters(3)
  valueText:SetNumeric(true)
  valueText:SetJustifyH("CENTER")
  valueText:SetFontObject(GameFontHighlightSmall)
  valueText:SetTextColor(1, 1, 1)
  valueText:SetTextInsets(4, 4, 0, 0)
  ApplyPanel(valueText, FIELD_BG, BORDER)

  local slider = CreateFrame("Slider", nil, ctx.content)
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", ctx.padX, ctx.LocalY() - 32)
  slider:SetPoint("TOPRIGHT", ctx.content, "TOPRIGHT", -ctx.padX, ctx.LocalY() - 32)
  slider:SetHeight(16)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then
    slider:SetObeyStepOnDrag(true)
  end

  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(FIELD_BG.r, FIELD_BG.g, FIELD_BG.b, 1)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(6)
  local trackEdge = slider:CreateTexture(nil, "BACKGROUND", nil, -1)
  trackEdge:SetColorTexture(BORDER.r, BORDER.g, BORDER.b, 1)
  trackEdge:SetPoint("TOPLEFT", track, "TOPLEFT", -1, 1)
  trackEdge:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 1, -1)

  local fill = slider:CreateTexture(nil, "BORDER")
  fill:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
  fill:SetPoint("LEFT", track, "LEFT", 0, 0)
  fill:SetHeight(6)
  fill:SetWidth(1)

  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(10, 16)
  thumb:SetColorTexture(1, 1, 1, 1)
  slider:SetThumbTexture(thumb)

  local current = minValue
  local function UpdateFill(value)
    current = value
    local span = maxValue - minValue
    local pct = span > 0 and ((value - minValue) / span) or 0
    if pct < 0 then
      pct = 0
    elseif pct > 1 then
      pct = 1
    end
    fill:SetWidth(math.max(1, (slider:GetWidth() or 200) * pct))
  end
  slider:SetScript("OnSizeChanged", function()
    UpdateFill(current)
  end)

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
    if section == "general" and key == "windowScale" and not self.dragging then
      Settings:ApplyScale()
    end
    if section == "features" and key == "backgroundFade" then
      if RakaMod.Overlay and RakaMod.Overlay.ApplyDimAlpha then
        RakaMod.Overlay:ApplyDimAlpha()
      end
      if RakaMod.AFK and RakaMod.AFK.ApplyOptions then
        RakaMod.AFK:ApplyOptions()
      end
    end
  end)
  PassWheel(ctx.scroll, slider)
  PassWheel(ctx.scroll, valueText)

  -- Window scale resizes the slider itself, so apply it on release, not while dragging.
  slider:SetScript("OnMouseDown", function(self)
    self.dragging = true
  end)
  slider:SetScript("OnMouseUp", function(self)
    self.dragging = false
    if section == "general" and key == "windowScale" then
      Settings:ApplyScale()
    end
  end)

  local function CommitTyped()
    local typed = tonumber(valueText:GetText())
    if typed then
      if typed < minValue then
        typed = minValue
      elseif typed > maxValue then
        typed = maxValue
      end
      slider:SetValue(typed)
    end
    valueText:SetText(tostring(math.floor((slider:GetValue() or minValue) + 0.5)))
  end
  valueText:SetScript("OnEnterPressed", function(self)
    CommitTyped()
    self:ClearFocus()
  end)
  valueText:SetScript("OnEscapePressed", function(self)
    self:SetText(tostring(math.floor((slider:GetValue() or minValue) + 0.5)))
    self:ClearFocus()
  end)
  valueText:SetScript("OnEditFocusGained", function(self)
    self:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
    self:HighlightText()
  end)
  valueText:SetScript("OnEditFocusLost", function(self)
    self:SetBackdropBorderColor(BORDER.r, BORDER.g, BORDER.b, 1)
    self:HighlightText(0, 0)
    CommitTyped()
  end)

  sliders[#sliders + 1] = {
    widget = slider,
    valueText = valueText,
    section = section,
    key = key,
    minValue = minValue,
    updateFill = UpdateFill,
  }
  RegisterReset(ctx, function()
    ResetKey(section, key)
  end)
  ctx.Advance(54)
  return slider
end

-- Dropdown select ---------------------------------------------------------
local dropdownMenu

local function CloseDropdown()
  if dropdownMenu then
    dropdownMenu:Hide()
    dropdownMenu.catcher:Hide()
    dropdownMenu.owner = nil
  end
end

local function EnsureDropdownMenu()
  if dropdownMenu then
    return dropdownMenu
  end
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG")
  catcher:Hide()
  catcher:SetScript("OnClick", CloseDropdown)

  local menu = CreateFrame("Frame", nil, UIParent, template)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
  menu:EnableMouse(true)
  ApplyPanel(menu, FIELD_BG, ACCENT)
  menu:Hide()
  menu.catcher = catcher
  menu.items = {}
  dropdownMenu = menu
  return menu
end

local MENU_ITEM_H = 22

local function MenuItem(menu, index)
  local item = menu.items[index]
  if item then
    return item
  end
  item = CreateFrame("Button", nil, menu)
  item:SetHeight(MENU_ITEM_H)
  local hl = item:CreateTexture(nil, "BACKGROUND")
  hl:SetAllPoints()
  hl:SetColorTexture(0, 0, 0, 0)
  item.hl = hl
  local label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", 10, 0)
  item.label = label
  item:SetScript("OnEnter", function(self)
    self.hl:SetColorTexture(ACCENT_DIM.r, ACCENT_DIM.g, ACCENT_DIM.b, 0.8)
  end)
  item:SetScript("OnLeave", function(self)
    self.hl:SetColorTexture(0, 0, 0, 0)
  end)
  menu.items[index] = item
  return item
end

local function OpenDropdown(owner)
  local menu = EnsureDropdownMenu()
  if menu.owner == owner and menu:IsShown() then
    CloseDropdown()
    return
  end
  menu.owner = owner
  local count = #owner.options
  for i = 1, count do
    local option = owner.options[i]
    local item = MenuItem(menu, i)
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * MENU_ITEM_H)
    item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - (i - 1) * MENU_ITEM_H)
    item.label:SetText(option)
    if option == owner.value then
      item.label:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
    else
      item.label:SetTextColor(TEXT.r, TEXT.g, TEXT.b)
    end
    item:SetScript("OnClick", function()
      owner:SetValue(option)
      CloseDropdown()
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

frame:HookScript("OnHide", CloseDropdown)

local function MakeDropdown(parent, width, options, onSelect)
  local button = CreateFrame("Button", nil, parent, template)
  button:SetSize(width, 24)
  ApplyPanel(button, FIELD_BG, BORDER)

  local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("LEFT", 10, 0)
  text:SetPoint("RIGHT", -26, 0)
  text:SetJustifyH("LEFT")
  text:SetTextColor(TEXT.r, TEXT.g, TEXT.b)

  local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  arrow:SetPoint("RIGHT", -10, 1)
  arrow:SetText("v")
  arrow:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)

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
    self:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
  end)
  button:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(BORDER.r, BORDER.g, BORDER.b, 1)
  end)
  return button
end

local function AddDropdown(ctx, text, section, key, options, fallback, afterChange)
  IndexLabel(ctx, text)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", ctx.padX, ctx.LocalY() - 8)
  label:SetText(text)
  label:SetTextColor(TEXT.r, TEXT.g, TEXT.b)

  local dropdown = MakeDropdown(ctx.content, 150, options, function(value)
    local saved = RakaMod.db and RakaMod.db[section]
    if not saved then
      return
    end
    saved[key] = value
    RakaMod.Core:RefreshModules()
    if afterChange then
      afterChange()
    end
  end)
  dropdown:SetPoint("TOPRIGHT", ctx.content, "TOPRIGHT", -ctx.padX, ctx.LocalY() - 3)
  dropdown:SetValue(fallback)
  PassWheel(ctx.scroll, dropdown)

  dropdowns[#dropdowns + 1] = { widget = dropdown, section = section, key = key, fallback = fallback }
  RegisterReset(ctx, function()
    local saved = RakaMod.db and RakaMod.db[section]
    if saved then
      local default = DefaultValue(section, key)
      if default == nil then
        default = fallback
      end
      saved[key] = default
    end
  end)
  ctx.Advance(34)
  return dropdown
end

local function AddColorButton(ctx, text, getTarget, onChange, getDefault)
  IndexLabel(ctx, text)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", ctx.padX, ctx.LocalY() - 6)
  label:SetText(text)
  label:SetTextColor(TEXT.r, TEXT.g, TEXT.b)

  local swatch = CreateFrame("Button", nil, ctx.content)
  swatch:SetSize(22, 22)
  swatch:SetPoint("TOPRIGHT", ctx.content, "TOPRIGHT", -ctx.padX, ctx.LocalY() - 3)
  local edge = swatch:CreateTexture(nil, "BACKGROUND")
  edge:SetColorTexture(BORDER.r, BORDER.g, BORDER.b, 1)
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
  RegisterReset(ctx, function()
    local target = getTarget()
    local default = getDefault and getDefault()
    if target and default then
      target.r, target.g, target.b = default.r, default.g, default.b
    end
  end)
  ctx.Advance(32)
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

local function AddText(ctx, text, color, gapBelow)
  local fs = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", ctx.padX, ctx.LocalY() - 2)
  fs:SetWidth(ctx.hintWidth)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(true)
  fs:SetText(text)
  fs:SetTextColor(color.r, color.g, color.b)
  local height = fs:GetStringHeight() or 14
  if height < 14 then
    height = 14
  end
  ctx.Advance(height + (gapBelow or 8))
  return fs
end

local function AddHint(ctx, text)
  return AddText(ctx, text, MUTED)
end

local function AddNote(ctx, text)
  return AddText(ctx, text, { r = 0.55, g = 0.75, b = 1.0 })
end

local function AddInfo(ctx, labelText, valueText)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", ctx.padX, ctx.LocalY() - 4)
  label:SetText(labelText)
  label:SetTextColor(MUTED.r, MUTED.g, MUTED.b)
  local value = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  value:SetPoint("TOPRIGHT", ctx.content, "TOPRIGHT", -ctx.padX, ctx.LocalY() - 4)
  value:SetText(valueText)
  value:SetTextColor(TEXT.r, TEXT.g, TEXT.b)
  ctx.Advance(24)
end

---------------------------------------------------------------------------
-- Gradient color pairs
---------------------------------------------------------------------------
local function MakeSwatch(parent, scroll, size)
  local swatch = CreateFrame("Button", nil, parent)
  swatch:SetSize(size, size)
  local edge = swatch:CreateTexture(nil, "BACKGROUND")
  edge:SetColorTexture(BORDER.r, BORDER.g, BORDER.b, 1)
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
  IndexLabel(ctx, labelText)
  local label = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", x, y - 4)
  label:SetWidth(118)
  label:SetJustifyH("LEFT")
  label:SetText(labelText)
  if labelColor then
    label:SetTextColor(labelColor.r or 1, labelColor.g or 1, labelColor.b or 1)
  end

  local leftSwatch = MakeSwatch(ctx.content, ctx.scroll, 18)
  leftSwatch:SetPoint("TOPLEFT", ctx.content, "TOPLEFT", x + 122, y - 3)
  local arrow = ctx.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  arrow:SetPoint("LEFT", leftSwatch, "RIGHT", 4, 0)
  arrow:SetText(">")
  arrow:SetTextColor(MUTED.r, MUTED.g, MUTED.b)
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

  local function pick(side)
    local pair = getPair()
    if not pair or type(pair[side]) ~= "table" then
      return
    end
    PickColor(pair[side], function()
      refresh()
      if RakaMod.Gradient and RakaMod.Gradient.Apply then
        RakaMod.Gradient:Apply()
      end
    end, {
      getDefault = function()
        local defaults = getDefaultPair and getDefaultPair()
        return defaults and defaults[side]
      end,
    })
  end
  leftSwatch:SetScript("OnClick", function()
    pick("left")
  end)
  rightSwatch:SetScript("OnClick", function()
    pick("right")
  end)

  swatches[#swatches + 1] = { paint = refresh }
  RegisterReset(ctx, function()
    local pair = getPair()
    local defaults = getDefaultPair and getDefaultPair()
    if not pair or not defaults then
      return
    end
    for _, side in ipairs({ "left", "right" }) do
      if type(pair[side]) == "table" and type(defaults[side]) == "table" then
        pair[side].r, pair[side].g, pair[side].b = defaults[side].r, defaults[side].g, defaults[side].b
      end
    end
  end)
  refresh()
end

-- rows: { key, label, color }; group is the table name under db.gradient.
local function AddPairGroup(ctx, group, rows, columns)
  local startY = ctx.LocalY()
  for i = 1, #rows do
    local row = rows[i]
    local col, rowIndex = 0, i - 1
    if columns == 2 then
      col = (i % 2 == 1) and 0 or 1
      rowIndex = math.floor((i - 1) / 2)
    end
    local x = col == 0 and ctx.padX or PAIR_COL2_X
    AddPairRow(ctx, x, startY - rowIndex * PAIR_ROW, row.label, row.color, function()
      local g = RakaMod.db and RakaMod.db.gradient
      local section = g and g[group]
      return section and section[row.key]
    end, function()
      local d = GradientDefaults()
      local section = d and d[group]
      return section and section[row.key]
    end)
  end
  local count = columns == 2 and math.ceil(#rows / 2) or #rows
  ctx.Advance(count * PAIR_ROW + 4)
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

---------------------------------------------------------------------------
-- Shared refresh helpers
---------------------------------------------------------------------------
local function RefreshSharedFades()
  if RakaMod.Overlay and RakaMod.Overlay.ApplyDimAlpha then
    RakaMod.Overlay:ApplyDimAlpha()
  end
  if RakaMod.AFK and RakaMod.AFK.ApplyOptions then
    RakaMod.AFK:ApplyOptions()
  end
end

local function RefreshAfk()
  if RakaMod.AFK and RakaMod.AFK.ApplyOptions then
    RakaMod.AFK:ApplyOptions()
  end
end

local function RefreshGradient()
  if RakaMod.Gradient and RakaMod.Gradient.Apply then
    RakaMod.Gradient:Apply()
  end
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
-- General
do
  local page = CreatePage("general", "general")
  local card = page.Card("Interface", 1)
  AddCheck(card, "Show minimap icon", "general", "showMinimapIcon")
  AddHint(card, "Toggles the RakaMod button on the minimap.")
  card.Done()
  local window = page.Card("Window", 2)
  AddSlider(window, "Window scale (%)", "general", "windowScale", 70, 130)
  AddHint(window, "Resizes this settings window. Applied when you release the slider.")
  window.Done()
  page.Finish()
end

do
  local page = CreatePage("generalAbout", "general")
  local card = page.Card("RakaMod")
  AddInfo(card, "Version", AddonVersion() or "unknown")
  AddInfo(card, "Open settings", "/rakamod   /rmod   /rm")
  AddInfo(card, "Requires", "EllesmereUI")
  card.Done()
  page.Finish()
end

-- Features
do
  local page = CreatePage("features", "features")
  local fade = page.Card("Background Fade", 1)
  AddSlider(fade, "Background fade", "features", "backgroundFade", 0, 100)
  AddHint(fade, "Dims the screen behind the Escape menu and AFK mode.")
  fade.Done()
  local grain = page.Card("Grain", 2)
  AddCheck(grain, "Grain Background", "features", "fadeGrain", RefreshSharedFades, "toggle")
  AddHint(grain, "Adds a dark film-grain texture over the fade. Off gives a clean fade.")
  grain.Done()
  page.Finish()
end

-- Header master switch (label + ON/OFF), shown above the tabs of one nav page.
-- Returns a small object RefreshNotes can Show/Hide for a "missing addon" note.
local function AddMaster(navKey, afterChange, noteText)
  local def = navs[navKey].master
  local label = pageHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetText(def.label)
  label:SetTextColor(TEXT.r, TEXT.g, TEXT.b)
  local pill = MakePillToggle(pageHeader)
  pill:SetPoint("TOPRIGHT", pageHeader, "TOPRIGHT", 0, -2)
  label:SetPoint("RIGHT", pill, "LEFT", -10, 0)
  local note = pageHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("RIGHT", label, "LEFT", -18, 0)
  note:SetText(noteText or "")
  note:SetTextColor(0.55, 0.75, 1.0)
  local m = { label = label, pill = pill, note = note, noteWanted = false }
  masters[navKey] = m
  BindToggle(pill, def.section, def.key, function()
    if afterChange then
      afterChange()
    end
    UpdateMaster()
  end)
  PassWheel(pages[navKey] and pages[navKey].ctx and pages[navKey].ctx.scroll or pageBody, pill)
  checks[#checks + 1] = { widget = pill, section = def.section, key = def.key }
  RegisterReset({ navKey = navKey }, function()
    ResetKey(def.section, def.key)
  end)
  label:Hide()
  pill:Hide()
  note:Hide()
  return {
    Show = function()
      m.noteWanted = true
      UpdateMaster()
    end,
    Hide = function()
      m.noteWanted = false
      UpdateMaster()
    end,
  }
end

-- Game Menu
do
  local page = CreatePage("overlay", "overlay")
  AddMaster("overlay")
  local panels = page.Card("Panels", 1)
  AddHint(panels, "Extra panels shown beside the game menu.")
  AddCheck(panels, "Collections", "overlay", "collections")
  AddCheck(panels, "Played", "overlay", "played")
  AddCheck(panels, "Professions", "overlay", "professions")
  panels.Done()
  page.Finish()
end

-- AFK
do
  local page = CreatePage("afk", "afk")
  AddMaster("afk", RefreshAfk)
  local behavior = page.Card("Behavior", 1)
  AddHint(behavior, "Full-screen overlay while you are away.")
  AddCheck(behavior, "Play Emotes", "afk", "playEmotes", RefreshAfk)
  AddCheck(behavior, "Turn Camera", "afk", "cameraPan", RefreshAfk)
  AddCheck(behavior, "Show Changelog", "afk", "showChangelog", RefreshAfk)
  behavior.Done()
  -- Show Tips omitted: no tips panel yet. Spec Icon Size omitted: AFK shows class icon, not a resizable spec icon.
  page.Finish()
end

-- Player Frame
do
  local page = CreatePage("reveal", "reveal")
  revealNote = AddMaster("reveal", nil, "EllesmereUI Unit Frames is not installed.")
  local triggers = page.Card("Show When", 1)
  AddCheck(triggers, "Casting", "reveal", "casting")
  AddCheck(triggers, "Health above 100%", "reveal", "health")
  AddCheck(triggers, "Mouseover", "reveal", "mouseover")
  AddCheck(triggers, "Combat", "reveal", "combat")
  AddCheck(triggers, "Pet", "reveal", "pet")
  triggers.Done()
  page.Finish()
end

-- Zone Text
do
  local OUTLINES = { "NONE", "OUTLINE", "THICKOUTLINE" }
  local page = CreatePage("zoneText", "zoneText")
  AddMaster("zoneText")
  local main = page.Card("Text", 1)
  AddSlider(main, "Size", "zoneText", "size", 8, 64)
  main.Done()
  local look = page.Card("Appearance", 2)
  AddDropdown(look, "Outline", "zoneText", "outline", OUTLINES, "OUTLINE", function()
    if RakaMod.ZoneText and RakaMod.ZoneText.Apply then
      RakaMod.ZoneText:Apply()
    end
  end)
  AddZoneSwatch(look, "Color")
  look.Done()
  page.Finish()
end

-- Gradient: master switch above all gradient tabs
gradientNote = AddMaster("gradient", RefreshGradient, "No Ellesmere health-bar module is installed.")
-- Gradient: Health
do
  local page = CreatePage("gradient", "gradient")
  local classes = page.Card("Class Colors")
  do
    local files = RakaMod.Logic and RakaMod.Logic.CLASS_FILES or {}
    local rows = {}
    for i = 1, #files do
      rows[i] = { key = files[i], label = ClassDisplayName(files[i]), color = ClassLabelColor(files[i]) }
    end
    AddPairGroup(classes, "classes", rows, 2)
  end
  classes.Done()

  local npc = page.Card("NPC Colors", 1)
  AddPairGroup(npc, "npc", {
    { key = "friendly", label = "Friendly", color = { r = 0.52, g = 0.85, b = 0.17 } },
    { key = "enemy", label = "Enemy", color = { r = 0.85, g = 0.25, b = 0.25 } },
    { key = "neutral", label = "Neutral", color = { r = 0.87, g = 0.76, b = 0.29 } },
  })
  npc.Done()

  local states = page.Card("State Colors", 2)
  local stateColor = { r = 0.85, g = 0.85, b = 0.85 }
  AddPairGroup(states, "states", {
    { key = "dead", label = "Dead", color = stateColor },
    { key = "offline", label = "Offline", color = stateColor },
    { key = "tapped", label = "Tapped", color = stateColor },
  })
  states.Done()
  page.Finish()
end

-- Gradient: Bars
if SHOW_UNPAINTED_GRADIENT_TABS then
  local page = CreatePage("gradientBars", "gradient")
  local power = page.Card("Power Colors", 1)
  AddHint(power, "Gradient shifts for power types.")
  AddPairGroup(power, "power", {
    { key = "altPower", label = "Alt Power", color = { r = 0.24, g = 0.48, b = 0.91 } },
    { key = "focus", label = "Focus", color = { r = 0.85, g = 0.44, b = 0.20 } },
    { key = "rage", label = "Rage", color = { r = 0.91, g = 0.18, b = 0.18 } },
    { key = "energy", label = "Energy", color = { r = 1.00, g = 0.87, b = 0.43 } },
    { key = "mana", label = "Mana", color = { r = 0.29, g = 0.56, b = 0.91 } },
    { key = "runicPower", label = "Runic Power", color = { r = 0.22, g = 0.64, b = 0.98 } },
  })
  power.Done()
  local cast = page.Card("Castbar Colors", 2)
  AddHint(cast, "Gradient shifts for cast bars.")
  AddPairGroup(cast, "castbar", {
    { key = "regular", label = "Regular", color = { r = 1.00, g = 0.70, b = 0.00 } },
    { key = "nonInterruptible", label = "Non-interruptible", color = { r = 0.56, g = 0.55, b = 0.55 } },
  })
  cast.Done()
  page.Finish()
end

-- Gradient: Resources
if SHOW_UNPAINTED_GRADIENT_TABS then
  local page = CreatePage("gradientResources", "gradient")
  local card = page.Card("Class Resources")
  AddHint(card, "Gradient shifts for class resource bars.")
  AddPairGroup(card, "classResources", {
    { key = "comboPoint1", label = "Combo Point 1", color = { r = 0.75, g = 0.31, b = 0.31 } },
    { key = "comboPoint2", label = "Combo Point 2", color = { r = 0.78, g = 0.56, b = 0.31 } },
    { key = "comboPoint3", label = "Combo Point 3", color = { r = 0.81, g = 0.81, b = 0.31 } },
    { key = "comboPoint4", label = "Combo Point 4", color = { r = 0.56, g = 0.78, b = 0.31 } },
    { key = "comboPoint5", label = "Combo Point 5", color = { r = 0.43, g = 0.76, b = 0.31 } },
    { key = "holyPower", label = "Holy Power", color = { r = 1.00, g = 0.89, b = 0.42 } },
    { key = "chi", label = "Chi", color = { r = 0.18, g = 1.00, b = 0.70 } },
    { key = "soulShards", label = "Soul Shards", color = { r = 0.69, g = 0.38, b = 1.00 } },
    { key = "shadowOrbs", label = "Shadow Orbs", color = { r = 0.63, g = 0.31, b = 1.00 } },
    { key = "bloodRunes", label = "Blood Runes", color = { r = 0.90, g = 0.10, b = 0.27 } },
    { key = "frostRunes", label = "Frost Runes", color = { r = 0.00, g = 0.67, b = 1.00 } },
    { key = "unholyRunes", label = "Unholy Runes", color = { r = 0.04, g = 0.85, b = 0.35 } },
    { key = "deathRunes", label = "Death Runes", color = { r = 0.64, g = 0.36, b = 1.00 } },
  }, 2)
  card.Done()
  page.Finish()
end

-- Gradient: Nameplates
if SHOW_UNPAINTED_GRADIENT_TABS then
  local page = CreatePage("gradientNameplates", "gradient")
  local main = page.Card("Nameplates")
  AddDropdown(main, "Fade Direction", "gradient", "nameplateFadeDirection", { "LEFT", "RIGHT" }, "RIGHT", RefreshGradient)
  AddHint(main, "Class, NPC, and State colors are shared with unit frames. Threat and classification colors below are nameplate-specific.")
  main.Done()
  local threat = page.Card("Threat Colors")
  AddHint(threat, "Used when nameplate threat coloring is enabled.")
  AddPairGroup(threat, "nameplateThreat", {
    { key = "good", label = "Good", color = { r = 0.12, g = 0.62, b = 0.12 } },
    { key = "bad", label = "Bad", color = { r = 1.00, g = 0.27, b = 0.27 } },
    { key = "goodTransition", label = "Good Transition", color = { r = 1.00, g = 0.88, b = 0.30 } },
    { key = "badTransition", label = "Bad Transition", color = { r = 1.00, g = 0.63, b = 0.30 } },
    { key = "offTank", label = "Off Tank", color = { r = 0.84, g = 0.36, b = 0.84 } },
    { key = "offTankGood", label = "Off Tank Good", color = { r = 0.30, g = 0.50, b = 0.88 } },
    { key = "offTankBad", label = "Off Tank Bad", color = { r = 0.50, g = 0.30, b = 0.88 } },
    { key = "solo", label = "Solo", color = { r = 0.29, g = 0.88, b = 0.65 } },
  }, 2)
  threat.Done()

  local class = page.Card("Classification Colors")
  AddHint(class, "Used when nameplate classification coloring is enabled.")
  AddPairGroup(class, "nameplateClassification", {
    { key = "worldBoss", label = "World Boss", color = { r = 0.90, g = 0.77, b = 0.00 } },
    { key = "rareElite", label = "Rare Elite", color = { r = 0.00, g = 0.84, b = 0.69 } },
    { key = "rare", label = "Rare", color = { r = 0.36, g = 0.82, b = 0.10 } },
    { key = "eliteBoss", label = "Elite Boss", color = { r = 0.90, g = 0.36, b = 0.75 } },
    { key = "eliteMini", label = "Elite Mini", color = { r = 0.56, g = 0.36, b = 0.84 } },
    { key = "caster", label = "Caster", color = { r = 0.10, g = 0.60, b = 0.88 } },
  }, 2)
  class.Done()
  page.Finish()
end

---------------------------------------------------------------------------
-- Footer actions, sync, show
---------------------------------------------------------------------------
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
    entry.updateFill(value)
  end
  for i = 1, #dropdowns do
    local entry = dropdowns[i]
    local section = db[entry.section]
    local value = section and section[entry.key]
    entry.widget:SetValue(value or entry.fallback)
  end
  for i = 1, #swatches do
    swatches[i].paint()
  end
  applying = false
  UpdateMaster()
end

function Settings:ApplyScale()
  local saved = RakaMod.db and RakaMod.db.general
  local percent = saved and tonumber(saved.windowScale) or 100
  if percent < 70 then
    percent = 70
  elseif percent > 130 then
    percent = 130
  end
  frame:SetScale(percent / 100)
end

function Settings:ResetCurrentPage()
  local list = resets[selectedNav]
  if type(RakaMod.db) ~= "table" or not list then
    return
  end
  for i = 1, #list do
    list[i]()
  end
  RakaMod.Core:RefreshModules()
  if RakaMod.ZoneText and RakaMod.ZoneText.Apply then
    RakaMod.ZoneText:Apply()
  end
  RefreshSharedFades()
  RefreshGradient()
  self:ApplyScale()
  self:SyncFromDB()
end

resetBtn:SetScript("OnClick", function()
  if not resetArmed then
    resetArmed = true
    resetToken = resetToken + 1
    local token = resetToken
    resetBtn.label:SetText("Click to confirm")
    if C_Timer and C_Timer.After then
      C_Timer.After(3, function()
        if resetToken == token and resetArmed then
          DisarmReset()
        end
      end)
    end
    return
  end
  DisarmReset()
  Settings:ResetCurrentPage()
end)

Settings:SelectPage("general")

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
      width = hostWidth - 24
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
  self:ApplyScale()
  self:SelectPage(selectedNav or "general")
  frame:Show()
  self:RefreshNotes()
  for key in pairs(pages) do
    UpdateScrollChildWidth(key)
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

  if BlizzardSettings and BlizzardSettings.RegisterCanvasLayoutCategory then
    local category = BlizzardSettings.RegisterCanvasLayoutCategory(panel, "RakaMod")
    if type(category) == "table" then
      category.icon = iconPath
    end
    if BlizzardSettings.RegisterAddOnCategory then
      BlizzardSettings.RegisterAddOnCategory(category)
    end
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

RegisterBlizzardCategory()
