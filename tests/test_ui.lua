-- Behavior tests for the settings window: accent switching and live repaint, search filtering,
-- footer/header chrome and the ways of opening the window. Runs against tests/wowstub.lua.
-- Run from the repo root: lua tests/test_ui.lua

local failures = 0
local function fail(msg)
  failures = failures + 1
  io.stderr:write("FAIL " .. msg .. "\n")
end

local function eq(actual, expected, name)
  if actual ~= expected then
    fail(string.format("%s: got %s expected %s", name, tostring(actual), tostring(expected)))
  end
end

local function near(actual, expected, name)
  if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
    fail(string.format("%s: got %s expected %s", name, tostring(actual), tostring(expected)))
  end
end

local Stub = dofile("tests/wowstub.lua")
local env = Stub.install()
local files = Stub.tocFiles()
Stub.loadAddon(files, fail)
Stub.fire(env, fail, "ADDON_LOADED", "RakaMod")
Stub.fire(env, fail, "PLAYER_LOGIN")

local reloads = 0
ReloadUI = function()
  reloads = reloads + 1
end

local Logic = RakaMod.Logic
local Theme = RakaMod.Theme
local Widgets = RakaMod.Widgets
local Shell = RakaMod.Shell
local Settings = RakaMod.Settings
local shell = Settings.shell

eq(type(Theme), "table", "Theme loaded")
eq(type(Widgets), "table", "Widgets loaded")
eq(type(Shell), "table", "Shell loaded")
eq(type(RakaMod.ColorPicker), "table", "ColorPicker loaded")
eq(type(RakaMod.db), "table", "saved variables merged")
eq(RakaMod.db.general.accent.mode, "preset", "default accent mode saved")

-- Accent resolution ---------------------------------------------------------
local blue = Logic.AccentPreset("blue")
Theme.Refresh()
near(Theme.accent.r, blue.r, "default accent r")
near(Theme.accent.g, blue.g, "default accent g")
near(Theme.accent.b, blue.b, "default accent b")

Theme.SetAccentMode("preset", "gold")
local gold = Logic.AccentPreset("gold")
near(Theme.accent.r, gold.r, "gold accent r")
near(Theme.accent.b, gold.b, "gold accent b")
eq(RakaMod.db.general.accent.preset, "gold", "preset saved")
eq(Theme.accent.tr < 0.2, true, "dark text on gold")

rawset(RAID_CLASS_COLORS, "WARRIOR", { r = 0.78, g = 0.61, b = 0.43 })
rawset(RAID_CLASS_COLORS, "MAGE", { r = 0.25, g = 0.78, b = 0.92 })
Theme.SetAccentMode("class")
near(Theme.accent.r, 0.78, "class accent r")
near(Theme.accent.g, 0.61, "class accent g")
UnitClass = function()
  return "Mage", "MAGE", 8
end
Stub.fire(env, fail, "PLAYER_SPECIALIZATION_CHANGED")
near(Theme.accent.r, 0.25, "class accent follows class change")
near(Theme.accent.b, 0.92, "class accent b after change")
eq(RakaMod.db.general.accent.mode, "class", "class mode saved")

local accentSaved = RakaMod.db.general.accent
Theme.SetAccentMode("custom")
near(accentSaved.r, 0.25, "switching to custom keeps the current color")
accentSaved.r, accentSaved.g, accentSaved.b = 0.1, 0.2, 0.3
Theme.Refresh()
near(Theme.accent.r, 0.1, "custom accent r")
near(Theme.accent.g, 0.2, "custom accent g")
eq(Theme.accent.tr, 1, "white text on dark custom accent")

-- Live repaint --------------------------------------------------------------
Theme.SetAccentMode("preset", "gold")
local pill = Widgets.Toggle(UIParent)
pill:SetChecked(true)
local fr, fg = Stub.stored(pill, "BackdropColor")
near(fr, gold.r, "toggle fill follows accent r")
near(fg, gold.g, "toggle fill follows accent g")
Theme.SetAccentMode("preset", "red")
local red = Logic.AccentPreset("red")
fr, fg = Stub.stored(pill, "BackdropColor")
near(fr, red.r, "toggle repaints live r")
near(fg, red.g, "toggle repaints live g")
local br = Stub.stored(pill, "BackdropBorderColor")
near(br, red.r, "toggle border repaints live")
local lr = Stub.stored(shell.reloadButton.label, "TextColor")
near(lr, red.r, "footer button label repaints live")
Theme.SetAccentMode("class")
local cr = Stub.stored(shell.reloadButton.label, "TextColor")
near(cr, 0.25, "class color repaints existing widgets")
Theme.SetAccentMode("preset", Logic.ACCENT_DEFAULT_PRESET)

-- Fonts and icons -----------------------------------------------------------
do
  local calls = {}
  local fakeFont = {
    SetFont = function(_, path)
      calls[#calls + 1] = path
      return #calls > 1
    end,
  }
  Theme.SetFont(fakeFont, 12)
  eq(calls[1], RakaMod.Media.UIFontPath, "UI font tried first")
  eq(calls[2], STANDARD_TEXT_FONT, "falls back to the standard font")
  eq(Stub.stored(shell.title, "Font"), RakaMod.Media.UIFontPath, "header title uses the bundled font")
  eq(RakaMod.Media.NavIconPath("does-not-exist"), nil, "unknown nav icon has no path")
  local noIcon = Shell.NewNavButton(UIParent, "Text only", nil, false)
  eq(noIcon.label ~= nil, true, "nav button works without an icon")
end

-- Chrome ----------------------------------------------------------------------
eq(shell.reloadButton.label:GetText(), "Apply & Reload UI", "footer button text")
local reloadClick = Stub.script(shell.reloadButton, "OnClick")
reloadClick(shell.reloadButton)
eq(reloads, 1, "Apply & Reload UI calls ReloadUI")
eq(Stub.stored(shell.version, "Text"), "v0.0.0", "header shows the addon version")

local escRegistered = false
for i = 1, #UISpecialFrames do
  if UISpecialFrames[i] == "RakaModSettingsFrame" then
    escRegistered = true
  end
end
eq(escRegistered, true, "Esc closes the settings window")

RakaMod.OpenSettings()
eq(shell.frame:IsShown(), true, "OpenSettings shows the window")
Stub.script(shell.close, "OnClick")(shell.close)
eq(shell.frame:IsShown(), false, "close button hides the window")
SlashCmdList.RAKAMOD()
eq(shell.frame:IsShown(), true, "slash command shows the window")

-- Search ----------------------------------------------------------------------
local box = shell.searchBox
local function search(text)
  box:SetText(text)
  Stub.script(box, "OnTextChanged")(box, true)
  return Settings.Inspect()
end
local function joined(list)
  return table.concat(list, ",")
end

local all = Settings.Inspect()
eq(#all.navs, 7, "all seven pages listed with no query")

local info = search("afk")
eq(joined(info.navs), "afk", "search filters the nav by page name")
eq(info.selectedNav, "afk", "search jumps to the matching page")

info = search("minimap")
eq(joined(info.navs), "general", "search matches option labels")
eq(info.selectedTab, "general", "matching option opens its tab")
eq(joined(info.rows), "show minimap icon", "only the matching option row stays visible")

info = search("accent")
eq(joined(info.navs), "general", "accent controls are searchable")
eq(info.selectedTab, "generalColors", "search picks the tab holding the match")

info = search("window scale")
eq(info.selectedTab, "general", "window scale tab")
eq(joined(info.rows), "window scale (%)", "window scale row only")

info = search("zzzz-nothing")
eq(#info.navs, 0, "no matches hides every nav item")

info = search("")
eq(#info.navs, 7, "clearing the search restores the nav")
eq(#info.rows >= 3, true, "clearing the search restores the rows")

-- Reset Page restores the accent --------------------------------------------
Settings:SelectPage("general")
Theme.SetAccentMode("preset", "purple")
local resetClick = Stub.script(shell.resetButton, "OnClick")
resetClick(shell.resetButton)
resetClick(shell.resetButton)
eq(RakaMod.db.general.accent.preset, Logic.ACCENT_DEFAULT_PRESET, "Reset Page restores the default accent preset")
eq(RakaMod.db.general.accent.mode, "preset", "Reset Page restores the accent mode")
near(Theme.accent.r, blue.r, "Reset Page repaints the window")

if failures > 0 then
  os.exit(1)
end
print("ui ok")
