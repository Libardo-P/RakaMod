RakaMod = RakaMod or {}

-- Blizzard's global Settings API (Esc > Options) must be captured before the local table below shadows it.
local BlizzardSettings = _G.Settings
local Settings = {}
RakaMod.Settings = Settings

local Logic = RakaMod.Logic
local Theme = RakaMod.Theme
local Widgets = RakaMod.Widgets
local Shell = RakaMod.Shell
local PickColor = RakaMod.ColorPicker.Pick

local C = Theme.COLORS
local CARD_GAP = 14
local CARD_PAD = 16
local PAIR_ROW = 30
local LABEL_FONT = 15
local SLIDER_LABEL_W = 128

local checks = {}
local sliders = {}
local swatches = {}
local dropdowns = {}
local pages = {}
local navs = {}
local pageNav = {}
local lastTab = {}
local resets = {}
local selectedNav = "general"
local selectedTab = "general"
local query = ""
local revealNote
local gradientNote
local tabButtons = {}

local shell = Shell.Create()
Settings.shell = shell
local frame = shell.frame
local pageHost = shell.pageHost

local function AddonVersion()
  return Shell.AddonVersion()
end

-- Description shown at the top of the page body, keyed by tab (page) key.
local PAGE_META = {
  general = "Addon-wide options.",
  generalColors = "Accent color of this window: a preset, a custom color, or your class color. Applied instantly.",
  generalAbout = "About this addon and how to open these settings.",
  features = "Shared background fade for Escape and AFK. Grain is optional.",
  overlay = "Left Escape overlay: professions, collections, and played time beside the game menu.",
  afk = "Full-screen AFK overlay with RakaMod branding, timer, character model, and Ellesmere patch notes. Dismiss with any key or click.",
  reveal = "Force-show the Ellesmere player frame while casting, while effective health is above 100% (absorbs / overshield), on mouseover, or in combat. It never hides the frame itself.",
  fonts = "Fonts used by AFK mode, this settings window and the Game Menu overlay panels. Turn Enabled off to leave every font to the game or Ellesmere.",
  gradient = "Health bar gradients shift by class, NPC reaction, and unit state.",
  gradientBars = "Power and castbar gradient shifts. Colors are saved now; painting comes later.",
  gradientResources = "Class resource gradient shifts. Colors are saved now; painting comes later.",
  gradientNameplates = "Nameplate threat and classification gradients. Colors are saved now; painting comes later.",
}

local NAV = {
  {
    key = "general",
    label = "General",
    tabs = {
      { key = "general", label = "General" },
      { key = "generalColors", label = "Colors" },
      { key = "generalAbout", label = "About" },
    },
  },
  {
    key = "features",
    label = "Features",
    tabs = { { key = "features", label = "Background" } },
  },
  {
    key = "overlay",
    label = "Game Menu",
    master = { section = "overlay", key = "enabled", label = "Enabled" },
    tabs = { { key = "overlay", label = "Panels" } },
  },
  {
    key = "afk",
    label = "AFK",
    master = { section = "afk", key = "enabled", label = "Enabled" },
    tabs = { { key = "afk", label = "Behavior" } },
  },
  {
    key = "reveal",
    label = "Player Frame",
    master = { section = "reveal", key = "enabled", label = "Enabled" },
    tabs = { { key = "reveal", label = "Triggers" } },
  },
  {
    key = "fonts",
    label = "Fonts",
    master = { section = "fonts", key = "enabled", label = "Enabled" },
    tabs = { { key = "fonts", label = "Fonts" } },
  },
  {
    key = "gradient",
    label = "Gradient Mode",
    -- Master switch shown in the toolbar, above every tab of this page.
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

---------------------------------------------------------------------------
-- Search
---------------------------------------------------------------------------
local function NormalizeQuery(text)
  text = string.lower(text or "")
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Contains(haystack, needle)
  return type(haystack) == "string" and string.find(haystack, needle, 1, true) ~= nil
end

local function NavMatches(navKey)
  if query == "" then
    return true
  end
  local nav = navs[navKey]
  return nav ~= nil and Contains(nav.search, query)
end

-- A tab matches on its own labels or on any option inside it.
local function PageMatches(tabKey)
  if query == "" then
    return true
  end
  local entry = pages[tabKey]
  return entry ~= nil and entry.ctx ~= nil and Contains(entry.ctx.search, query)
end

---------------------------------------------------------------------------
-- Sidebar nav
---------------------------------------------------------------------------
local searchBox = shell.searchBox
local searchHint = shell.searchHint
local navItems = {}

local function LayoutNav()
  local yOff = -shell.navTop
  local shown = 0
  for i = 1, #navItems do
    local item = navItems[i]
    if NavMatches(item.key) then
      item.button:ClearAllPoints()
      item.button:SetPoint("TOPLEFT", shell.sidebar, "TOPLEFT", Shell.NAV_PAD, yOff)
      item.button:SetPoint("TOPRIGHT", shell.sidebar, "TOPRIGHT", -Shell.NAV_PAD, yOff)
      item.button:Show()
      yOff = yOff - (Shell.NAV_HEIGHT + Shell.NAV_GAP)
      shown = shown + 1
    else
      item.button:Hide()
    end
  end
  shell.noResults:SetShown(shown == 0)
  return shown
end

do
  for i = 1, #NAV do
    local nav = NAV[i]
    local icon = RakaMod.Media and RakaMod.Media.NavIconPath and RakaMod.Media.NavIconPath(nav.key)
    local button = Shell.NewNavButton(shell.sidebar, nav.label, icon, nav.master ~= nil)
    button:SetScript("OnClick", function()
      Settings:SelectPage(nav.key)
    end)
    local search = string.lower(nav.label)
    for t = 1, #nav.tabs do
      search = search .. " " .. string.lower(nav.tabs[t].label)
      pageNav[nav.tabs[t].key] = nav.key
    end
    navs[nav.key] = { button = button, label = nav.label, tabs = nav.tabs, search = search, master = nav.master }
    navItems[#navItems + 1] = { key = nav.key, button = button }
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

searchBox:SetScript("OnTextChanged", function(self)
  RefreshSearchHint()
  query = NormalizeQuery(self:GetText())
  local shown = LayoutNav()
  if shown > 0 then
    -- Jump to the first match when the open page dropped out of the results; otherwise just refilter it.
    local target = selectedNav
    if not NavMatches(target) then
      for i = 1, #navItems do
        if NavMatches(navItems[i].key) then
          target = navItems[i].key
          break
        end
      end
    end
    Settings:SelectPage(target)
  end
end)
searchBox:SetScript("OnEditFocusGained", function(self)
  searchHint:Hide()
  Theme.SetBorder(self, Theme.accent)
end)
searchBox:SetScript("OnEditFocusLost", function(self)
  Theme.SetBorder(self, C.BORDER)
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
    if item.button:IsShown() then
      Settings:SelectPage(item.key)
      break
    end
  end
  self:ClearFocus()
end)

---------------------------------------------------------------------------
-- Toolbar (right of the tab row): master switch and Reset Page
---------------------------------------------------------------------------
local toolbar = shell.toolbar
local RESET_TEXT = "Reset Page"
local resetBtn = Widgets.Button(toolbar, RESET_TEXT, 112, 26)
shell.resetButton = resetBtn
resetBtn:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
local resetToken = 0
local resetArmed = false

local function DisarmReset()
  resetToken = resetToken + 1
  resetArmed = false
  resetBtn.label:SetText(RESET_TEXT)
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
      entry.button:SetStatus(on)
      for i = 1, #entry.tabs do
        local page = pages[entry.tabs[i].key]
        if page and page.page then
          page.page:SetAlpha(on and 1 or 0.45)
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Page selection
---------------------------------------------------------------------------
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
      button = Shell.NewTabButton(shell.tabRow, tab.label)
      tabButtons[i] = button
    end
    button:SetLabel(tab.label)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", shell.tabRow, "BOTTOMLEFT", x, 0)
    button:SetScript("OnClick", function()
      Settings:SelectPage(tab.key, true)
    end)
    button:SetSelected(tab.key == activeTab)
    button:Show()
    x = x + button:GetWidth() + 4
  end
  for i = #nav.tabs + 1, #tabButtons do
    tabButtons[i]:Hide()
  end
end

local function UpdatePageHeader()
  shell.desc:SetText(PAGE_META[selectedTab] or "")
end

-- exactTab: key is a tab key (a tab can share its nav's key, e.g. "general").
function Settings:SelectPage(key, exactTab)
  local navKey, tabKey
  if navs[key] and not (exactTab and pageNav[key]) then
    navKey = key
    tabKey = lastTab[key] or navs[key].tabs[1].key
    if query ~= "" and not PageMatches(tabKey) then
      for i = 1, #navs[key].tabs do
        if PageMatches(navs[key].tabs[i].key) then
          tabKey = navs[key].tabs[i].key
          break
        end
      end
    end
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
    nav.button:SetSelected(key2 == navKey)
  end
  BuildTabRow(navKey, tabKey)
  UpdateMaster()
  DisarmReset()
  if pages[tabKey].ctx and pages[tabKey].ctx.Layout then
    pages[tabKey].ctx.Layout()
  end
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
-- Page + group layout
---------------------------------------------------------------------------
local function IndexLabel(card, text)
  if type(text) ~= "string" then
    return
  end
  local lower = string.lower(text)
  local nav = navs[card.navKey]
  if nav then
    nav.search = (nav.search or "") .. " " .. lower
  end
  local entry = pages[card.key]
  if entry and entry.ctx then
    entry.ctx.search = entry.ctx.search .. " " .. lower
  end
end

local function RegisterReset(card, fn)
  local list = resets[card.navKey]
  if not list then
    list = {}
    resets[card.navKey] = list
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
  local page = CreateFrame("Frame", nil, pageHost)
  page:SetAllPoints()
  page:Hide()

  local scroll = CreateFrame("ScrollFrame", "RakaModSettingsScroll_" .. pageKey, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  scroll:SetScript("OnMouseWheel", function(_, delta)
    OnMouseWheel(scroll, delta)
  end)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(660, 400)
  scroll:SetScrollChild(content)

  local emptyText = Theme.Text(page, 15, C.MUTED)
  emptyText:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -8)
  emptyText:SetText("No options match your search.")
  emptyText:Hide()

  local cards = {}
  local ctx = {
    key = pageKey,
    navKey = navKey,
    page = page,
    scroll = scroll,
    content = content,
    search = "",
  }

  -- col: 1 or 2 for a half-width column, nil for a full-width group.
  function ctx.Card(title, col)
    local box = Widgets.Group(content, title)
    local card = {
      key = pageKey,
      navKey = navKey,
      scroll = scroll,
      content = box,
      padX = CARD_PAD,
      hintWidth = (col and 300) or 660,
      title = string.lower(title),
      col = col,
      grid = 1,
      rows = {},
    }
    -- A row is a fixed-height strip; Layout stacks the visible ones, so search can hide rows.
    function card.Row(height, searchText, isHint)
      local row = CreateFrame("Frame", nil, box)
      row:SetHeight(height)
      row.height = height
      row.search = type(searchText) == "string" and string.lower(searchText) or nil
      row.hint = isHint and true or false
      card.rows[#card.rows + 1] = row
      return row
    end
    function card.Done() end
    cards[#cards + 1] = card
    IndexLabel(card, title)
    return card
  end

  function ctx.Layout()
    local nav = navs[navKey]
    local labels = ""
    if nav then
      labels = string.lower(nav.label)
      for t = 1, #nav.tabs do
        if nav.tabs[t].key == pageKey then
          labels = labels .. " " .. string.lower(nav.tabs[t].label)
        end
      end
    end
    local filtering = query ~= ""
    ctx.visibleRows = {}
    local showAll = not filtering or Contains(labels, query)
    local colY = { 0, 0 }
    local anyShown = false
    for c = 1, #cards do
      local card = cards[c]
      local showCard = showAll or Contains(card.title, query)
      local visible = {}
      for r = 1, #card.rows do
        local row = card.rows[r]
        if showCard or (not row.hint and Contains(row.search, query)) then
          visible[#visible + 1] = row
        else
          row:Hide()
        end
      end
      local box = card.content
      if #visible == 0 then
        box:Hide()
      else
        anyShown = true
        -- While filtering, half-width groups fill the shorter column so a lone match sits at the left.
        local col = card.col
        if filtering and col then
          col = (colY[1] >= colY[2]) and 1 or 2
        end
        local top
        if col == 1 or col == 2 then
          top = colY[col]
        else
          top = math.min(colY[1], colY[2])
        end
        box:ClearAllPoints()
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
        local y = -Widgets.GROUP_TITLE_H
        local lineHeight = 0
        for i = 1, #visible do
          local row = visible[i]
          row:ClearAllPoints()
          if card.grid == 2 then
            local rightSide = i % 2 == 0
            if rightSide then
              row:SetPoint("TOPLEFT", box, "TOP", 8, y)
              row:SetPoint("TOPRIGHT", box, "TOPRIGHT", -card.padX, y)
            else
              row:SetPoint("TOPLEFT", box, "TOPLEFT", card.padX, y)
              row:SetPoint("TOPRIGHT", box, "TOP", -8, y)
            end
            lineHeight = math.max(lineHeight, row.height)
            if rightSide or i == #visible then
              y = y - lineHeight
              lineHeight = 0
            end
          else
            row:SetPoint("TOPLEFT", box, "TOPLEFT", card.padX, y)
            row:SetPoint("TOPRIGHT", box, "TOPRIGHT", -card.padX, y)
            y = y - row.height
          end
          row:Show()
          if row.search then
            ctx.visibleRows[#ctx.visibleRows + 1] = row.search
          end
        end
        local height = (-y) + 14
        box:SetHeight(height)
        box:Show()
        local nextTop = top - height - CARD_GAP
        if col == 1 or col == 2 then
          colY[col] = nextTop
        else
          colY[1] = nextTop
          colY[2] = nextTop
        end
      end
    end
    emptyText:SetShown(not anyShown)
    content:SetHeight((-math.min(colY[1], colY[2])) + 8)
    scroll:SetVerticalScroll(0)
    if scroll.UpdateScrollChildRect then
      scroll:UpdateScrollChildRect()
    end
  end

  function ctx.Finish()
    ctx.Layout()
  end

  pages[pageKey] = pages[pageKey] or {}
  pages[pageKey].page = page
  pages[pageKey].ctx = ctx
  return ctx
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
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
local function AddCheck(card, text, section, key, afterChange, style)
  IndexLabel(card, text)
  local row = card.Row(style == "toggle" and 36 or 32, text)
  local control
  local label = Theme.Text(row, LABEL_FONT, C.TEXT)
  label:SetText(text)
  if style == "toggle" then
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    control = Widgets.Toggle(row)
    control:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  else
    control = Widgets.Checkbox(row)
    control:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetPoint("LEFT", control, "RIGHT", 10, 0)
    control:SetHitRectInsets(0, -((label:GetStringWidth() or 80) + 14), 0, 0)
  end
  BindToggle(control, section, key, afterChange)
  PassWheel(card.scroll, control)
  checks[#checks + 1] = { widget = control, section = section, key = key }
  RegisterReset(card, function()
    ResetKey(section, key)
  end)
  return control
end

local function AddSlider(card, text, section, key, minValue, maxValue)
  IndexLabel(card, text)
  local row = card.Row(40, text)
  local label = Theme.Text(row, LABEL_FONT, C.TEXT)
  label:SetPoint("LEFT", row, "LEFT", 0, 0)
  label:SetText(text)

  local obj = Widgets.Slider(row, minValue, maxValue, function(intValue, dragging)
    local saved = RakaMod.db and RakaMod.db[section]
    if not saved then
      return
    end
    saved[key] = intValue
    RakaMod.Core:RefreshModules()
    if section == "afk" and RakaMod.AFK and RakaMod.AFK.ApplyOptions then
      RakaMod.AFK:ApplyOptions()
    end
    -- Window scale resizes the slider itself, so apply it on release, not while dragging.
    if section == "general" and key == "windowScale" and not dragging then
      Settings:ApplyScale()
    end
    if section == "fonts" and key == "uiSize" then
      Theme.RefreshFonts()
    end
    if section == "features" and key == "backgroundFade" then
      if RakaMod.Overlay and RakaMod.Overlay.ApplyDimAlpha then
        RakaMod.Overlay:ApplyDimAlpha()
      end
      if RakaMod.AFK and RakaMod.AFK.ApplyOptions then
        RakaMod.AFK:ApplyOptions()
      end
    end
  end, function()
    if section == "general" and key == "windowScale" then
      Settings:ApplyScale()
    end
  end)
  obj.box:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  obj.slider:SetPoint("LEFT", row, "LEFT", SLIDER_LABEL_W, 0)
  obj.slider:SetPoint("RIGHT", obj.box, "LEFT", -12, 0)
  PassWheel(card.scroll, obj.slider)
  PassWheel(card.scroll, obj.box)

  sliders[#sliders + 1] = { obj = obj, section = section, key = key, minValue = minValue }
  RegisterReset(card, function()
    ResetKey(section, key)
  end)
  return obj.slider
end

local function AddDropdown(card, text, section, key, options, fallback, afterChange, width)
  IndexLabel(card, text)
  local row = card.Row(38, text)
  local label = Theme.Text(row, LABEL_FONT, C.TEXT)
  label:SetPoint("LEFT", row, "LEFT", 0, 0)
  label:SetText(text)

  local dropdown = Widgets.Dropdown(row, width or 156, options, function(value)
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
  dropdown:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  dropdown:SetValue(fallback)
  PassWheel(card.scroll, dropdown)

  dropdowns[#dropdowns + 1] = { widget = dropdown, section = section, key = key, fallback = fallback }
  RegisterReset(card, function()
    local saved = RakaMod.db and RakaMod.db[section]
    if saved then
      local default = DefaultValue(section, key)
      if default == nil then
        default = fallback
      end
      saved[key] = default
    end
  end)
  return dropdown
end

local function AddText(card, text, color, gapBelow)
  local row = card.Row(14, nil, true)
  local fs = Theme.Text(row, 14, color)
  fs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
  fs:SetWidth(card.hintWidth)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(true)
  fs:SetText(text)
  local height = fs:GetStringHeight() or 14
  if height < 14 then
    height = 14
  end
  row.height = height + (gapBelow or 8)
  row:SetHeight(row.height)
  return fs
end

local function AddHint(card, text)
  return AddText(card, text, C.MUTED)
end

local function AddInfo(card, labelText, valueText)
  IndexLabel(card, labelText)
  local row = card.Row(28, labelText .. " " .. valueText)
  local label = Theme.Text(row, LABEL_FONT, C.MUTED)
  label:SetPoint("LEFT", row, "LEFT", 0, 0)
  label:SetText(labelText)
  local value = Theme.Text(row, LABEL_FONT, C.TEXT)
  value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  value:SetText(valueText)
end

---------------------------------------------------------------------------
-- Gradient color pairs
---------------------------------------------------------------------------
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

local function AddPairRow(card, labelText, labelColor, getPair, getDefaultPair)
  IndexLabel(card, labelText)
  local row = card.Row(PAIR_ROW, labelText)
  local label = Theme.Text(row, LABEL_FONT, labelColor or C.TEXT)
  label:SetPoint("LEFT", row, "LEFT", 0, 0)
  label:SetWidth(112)
  label:SetJustifyH("LEFT")
  label:SetText(labelText)

  local leftSwatch = Widgets.Swatch(row, 20)
  leftSwatch:SetPoint("LEFT", row, "LEFT", 118, 0)
  local arrow = Theme.Text(row, 13, C.MUTED)
  arrow:SetPoint("LEFT", leftSwatch, "RIGHT", 4, 0)
  arrow:SetText(">")
  local rightSwatch = Widgets.Swatch(row, 20)
  rightSwatch:SetPoint("LEFT", arrow, "RIGHT", 4, 0)

  local preview = row:CreateTexture(nil, "ARTWORK")
  preview:SetPoint("LEFT", rightSwatch, "RIGHT", 10, 0)
  preview:SetSize(84, 14)

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
  PassWheel(card.scroll, leftSwatch)
  PassWheel(card.scroll, rightSwatch)

  swatches[#swatches + 1] = { paint = refresh }
  RegisterReset(card, function()
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
local function AddPairGroup(card, group, rows, columns)
  if columns == 2 then
    card.grid = 2
  end
  for i = 1, #rows do
    local row = rows[i]
    AddPairRow(card, row.label, row.color, function()
      local g = RakaMod.db and RakaMod.db.gradient
      local section = g and g[group]
      return section and section[row.key]
    end, function()
      local d = GradientDefaults()
      local section = d and d[group]
      return section and section[row.key]
    end)
  end
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

local function RefreshOverlayFont()
  if RakaMod.Overlay and RakaMod.Overlay.ApplyFont then
    RakaMod.Overlay:ApplyFont()
  end
end

local function RefreshAllFonts()
  Theme.RefreshFonts()
  RefreshOverlayFont()
  RefreshAfk()
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
  local window = page.Card("Window", 2)
  AddSlider(window, "Window scale (%)", "general", "windowScale", 70, 130)
  AddHint(window, "Resizes this settings window. Applied when you release the slider.")
  page.Finish()
end

-- General: Colors (accent)
do
  local page = CreatePage("generalColors", "general")
  local card = page.Card("Accent Color", 1)
  local MODE_LABELS = { preset = "Preset", custom = "Custom", class = "Class color" }
  local MODE_KEYS = { ["Preset"] = "preset", ["Custom"] = "custom", ["Class color"] = "class" }
  local presetButtons = {}
  local customSwatch
  local modeDropdown

  local function SyncAccentControls()
    local saved = Theme.SavedAccent()
    if not saved then
      return
    end
    modeDropdown:SetValue(MODE_LABELS[saved.mode] or MODE_LABELS.preset)
    for i = 1, #presetButtons do
      presetButtons[i].button:SetSelected(saved.mode == "preset" and saved.preset == presetButtons[i].key)
    end
    PaintSwatch(customSwatch, saved)
    customSwatch:SetSelected(saved.mode == "custom")
  end

  IndexLabel(card, "Accent mode preset custom class color")
  local modeRow = card.Row(38, "Accent mode class color")
  local modeLabel = Theme.Text(modeRow, LABEL_FONT, C.TEXT)
  modeLabel:SetPoint("LEFT", modeRow, "LEFT", 0, 0)
  modeLabel:SetText("Accent mode")
  modeDropdown = Widgets.Dropdown(modeRow, 156, { "Preset", "Custom", "Class color" }, function(label)
    local mode = MODE_KEYS[label] or "preset"
    local saved = Theme.SavedAccent()
    Theme.SetAccentMode(mode, saved and saved.preset)
    SyncAccentControls()
  end)
  modeDropdown:SetPoint("RIGHT", modeRow, "RIGHT", 0, 0)
  PassWheel(card.scroll, modeDropdown)

  local presetNames = {}
  for i = 1, #Logic.ACCENT_PRESETS do
    presetNames[#presetNames + 1] = Logic.ACCENT_PRESETS[i].label
  end
  local presetRow = card.Row(40, "Presets " .. string.lower(table.concat(presetNames, " ")))
  for i = 1, #Logic.ACCENT_PRESETS do
    local preset = Logic.ACCENT_PRESETS[i]
    local button = Widgets.Swatch(presetRow, 26)
    button:SetPoint("LEFT", presetRow, "LEFT", 2 + (i - 1) * 40, 0)
    button.color:SetColorTexture(preset.r, preset.g, preset.b, 1)
    button:SetScript("OnClick", function()
      Theme.SetAccentMode("preset", preset.key)
      SyncAccentControls()
    end)
    PassWheel(card.scroll, button)
    presetButtons[#presetButtons + 1] = { key = preset.key, button = button }
  end
  IndexLabel(card, "Presets " .. table.concat(presetNames, " "))

  IndexLabel(card, "Custom color")
  local customRow = card.Row(36, "Custom color")
  local customLabel = Theme.Text(customRow, LABEL_FONT, C.TEXT)
  customLabel:SetPoint("LEFT", customRow, "LEFT", 0, 0)
  customLabel:SetText("Custom color")
  customSwatch = Widgets.Swatch(customRow, 24)
  customSwatch:SetPoint("RIGHT", customRow, "RIGHT", 0, 0)
  customSwatch:SetScript("OnClick", function()
    local saved = Theme.SavedAccent()
    if not saved then
      return
    end
    local startMode = saved.mode
    if startMode ~= "custom" then
      saved.r, saved.g, saved.b = Theme.accent.r, Theme.accent.g, Theme.accent.b
    end
    local sr, sg, sb = saved.r, saved.g, saved.b
    PickColor(saved, function()
      local same = math.abs(saved.r - sr) < 0.0005 and math.abs(saved.g - sg) < 0.0005 and math.abs(saved.b - sb) < 0.0005
      saved.mode = same and startMode or "custom"
      Theme.Refresh()
      SyncAccentControls()
    end, {
      getDefault = function()
        return Logic.AccentPreset(Logic.ACCENT_DEFAULT_PRESET)
      end,
    })
  end)
  PassWheel(card.scroll, customSwatch)

  AddHint(card, "Class color follows your current character. The window recolors as soon as you pick.")

  swatches[#swatches + 1] = { paint = SyncAccentControls }
  RegisterReset(card, function()
    local saved = Theme.SavedAccent()
    if saved then
      local defaults = Logic.BuildAccentDefaults()
      for k, v in pairs(defaults) do
        saved[k] = v
      end
    end
  end)
  page.Finish()
end

do
  local page = CreatePage("generalAbout", "general")
  local card = page.Card("RakaMod")
  AddInfo(card, "Version", AddonVersion() or "unknown")
  AddInfo(card, "Open settings", "/rakamod   /rmod   /rm")
  AddInfo(card, "Requires", "EllesmereUI")
  page.Finish()
end

-- Features
do
  local page = CreatePage("features", "features")
  local fade = page.Card("Background Fade", 1)
  AddSlider(fade, "Background fade", "features", "backgroundFade", 0, 100)
  AddHint(fade, "Dims the screen behind the Escape menu and AFK mode.")
  local grain = page.Card("Grain", 2)
  AddCheck(grain, "Grain Background", "features", "fadeGrain", RefreshSharedFades, "toggle")
  AddHint(grain, "Adds a dark film-grain texture over the fade. Off gives a clean fade.")
  page.Finish()
end

-- Master switch (label + ON/OFF) in the toolbar of one nav page.
-- Returns a small object RefreshNotes can Show/Hide for a "missing addon" note.
local function AddMaster(navKey, afterChange, noteText)
  local def = navs[navKey].master
  local pill = Widgets.Toggle(toolbar)
  pill:SetPoint("RIGHT", resetBtn, "LEFT", -20, 0)
  local label = Theme.Text(toolbar, LABEL_FONT, C.TEXT)
  label:SetText(def.label)
  label:SetPoint("RIGHT", pill, "LEFT", -10, 0)
  local note = Theme.Text(toolbar, 13, C.MUTED)
  note:SetPoint("RIGHT", label, "LEFT", -18, 0)
  note:SetText(noteText or "")
  Theme.Bind(function(a)
    note:SetTextColor(a.r, a.g, a.b)
  end)
  local m = { label = label, pill = pill, note = note, noteWanted = false }
  masters[navKey] = m
  BindToggle(pill, def.section, def.key, function()
    if afterChange then
      afterChange()
    end
    UpdateMaster()
  end)
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

-- Fonts
do
  local page = CreatePage("fonts", "fonts")
  AddMaster("fonts", RefreshAllFonts)
  local choices = RakaMod.Media.FontChoices()
  local general = page.Card("General Fonts")
  AddDropdown(general, "General Font", "fonts", "ui", choices, RakaMod.Logic.DEFAULT_UI_FONT, Theme.RefreshFonts, 220)
  AddHint(general, "Text of this settings window and its menus. Applied immediately.")
  AddSlider(general, "General font size", "fonts", "uiSize", RakaMod.Logic.UI_FONT_SIZE_MIN, RakaMod.Logic.UI_FONT_SIZE_MAX)
  AddHint(general, "Point size of the option text in this settings window (6 to 24, default 15). Headings and small text scale along with it.")
  general.Done()
  local afk = page.Card("AFK Mode")
  AddDropdown(afk, "AFK Font", "fonts", "afk", choices, RakaMod.Logic.DEFAULT_AFK_FONT, RefreshAfk, 220)
  AddHint(afk, "Name, timer, identity line, changelog and footer in AFK mode. Applies the next time AFK mode starts.")
  afk.Done()
  local overlayChoices = { RakaMod.Logic.DEFAULT_OVERLAY_FONT }
  for i = 1, #choices do
    overlayChoices[#overlayChoices + 1] = choices[i]
  end
  local overlay = page.Card("Game Menu Overlay")
  AddDropdown(overlay, "Game Menu Overlay Font", "fonts", "overlay", overlayChoices, RakaMod.Logic.DEFAULT_OVERLAY_FONT, RefreshOverlayFont, 220)
  AddHint(overlay, "Text of the RakaMod panels shown beside the Escape menu: Played, and later Professions and Collections. The Blizzard menu itself is not restyled. Applied immediately; Game Default keeps the game's own font.")
  overlay.Done()
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
-- Reset, sync, show
---------------------------------------------------------------------------
-- Read-only snapshot of navigation and search state (used by tests/test_ui.lua).
function Settings.Inspect()
  local info = { selectedNav = selectedNav, selectedTab = selectedTab, query = query, navs = {}, rows = {}, tabs = {} }
  for i = 1, #NAV do
    if navs[NAV[i].key].button:IsShown() then
      info.navs[#info.navs + 1] = NAV[i].key
    end
  end
  local entry = pages[selectedTab]
  if entry and entry.ctx and entry.ctx.visibleRows then
    for i = 1, #entry.ctx.visibleRows do
      info.rows[i] = entry.ctx.visibleRows[i]
    end
  end
  for i = 1, #navs[selectedNav].tabs do
    info.tabs[i] = navs[selectedNav].tabs[i].key
  end
  return info
end

function Settings:SyncFromDB()
  local db = RakaMod.db
  if type(db) ~= "table" then
    return
  end
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
    entry.obj.SetSilently(value)
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
  RefreshSharedFades()
  RefreshGradient()
  RefreshOverlayFont()
  self:ApplyScale()
  Theme.Refresh()
  Theme.RefreshFonts()
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

frame:HookScript("OnHide", Widgets.CloseDropdown)

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
    local hostWidth = pageHost:GetWidth()
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
  Theme.Refresh()
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
