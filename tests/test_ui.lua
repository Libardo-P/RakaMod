-- Behavior tests for the settings window: accent switching and live repaint, search filtering,
-- footer/header chrome and the ways of opening the window. Runs against tests/wowstub.lua.
-- Run from the repo root: lua tests/test_ui.lua

local unpack = table.unpack or unpack
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

-- Color picker: wheel canvases are widgets, left blank, with Media art underneath ---------------
do
  local changes = 0
  local target = { r = 0.2, g = 0.3, b = 0.4 }
  RakaMod.ColorPicker.Pick(target, function()
    changes = changes + 1
  end)
  local picker = RakaMod.ColorPicker.Frame()
  local select = picker and picker.select
  eq(select ~= nil, true, "picker builds its ColorSelect")
  eq(picker:IsShown(), true, "picker opens")
  for _, name in ipairs({ "ColorWheelTexture", "ColorWheelThumbTexture", "ColorValueTexture", "ColorValueThumbTexture" }) do
    eq(type(Stub.stored(select, name)), "table", name .. " is given a Texture widget, not a path")
  end
  local wheel = Stub.stored(select, "ColorWheelTexture")
  local value = Stub.stored(select, "ColorValueTexture")
  eq(Stub.stored(wheel, "Texture"), nil, "wheel canvas stays blank for the engine")
  eq(Stub.stored(wheel, "ColorTexture"), nil, "wheel canvas has no solid fill")
  eq(Stub.stored(value, "Texture"), nil, "value canvas stays blank for the engine")
  eq(Stub.stored(value, "ColorTexture"), nil, "value canvas has no solid fill")
  eq(select.rakaValueFallback ~= nil, true, "value bar has a fallback gradient")
  eq(Stub.stored(Stub.stored(select, "ColorWheelThumbTexture"), "Texture"), "Interface\\Buttons\\UI-ColorPicker-Buttons", "wheel thumb art")

  picker:SetColorRGB(0.5, 0.25, 0.75)
  Stub.script(select, "OnColorSelect")(select)
  near(target.r, 0.5, "picking writes r to the bound color")
  near(target.g, 0.25, "picking writes g to the bound color")
  near(target.b, 0.75, "picking writes b to the bound color")
  eq(changes > 0, true, "picking notifies the owner")

  Stub.script(picker.buttons.cancel, "OnClick")(picker.buttons.cancel)
  near(target.r, 0.2, "Cancel restores the previous color")
  eq(picker:IsShown(), false, "Cancel closes the picker")

  RakaMod.ColorPicker.Pick(target, function() end)
  picker:SetColorRGB(0.9, 0.8, 0.7)
  Stub.script(select, "OnColorSelect")(select)
  Stub.script(picker.buttons.okay, "OnClick")(picker.buttons.okay)
  near(target.r, 0.9, "Okay keeps the picked color")
  eq(picker:IsShown(), false, "Okay closes the picker")
end

do
  local function chatFrame(listening)
    local f = { listening = listening, registers = 0 }
    f.IsEventRegistered = function(self) return self.listening end
    f.UnregisterEvent = function(self) self.listening = false end
    f.RegisterEvent = function(self) self.listening = true; self.registers = self.registers + 1 end
    return f
  end
  local now = 1000
  local requests = 0
  local timers = {}
  GetTime = function() return now end
  RequestTimePlayed = function() requests = requests + 1 end
  local timerApi = _G.C_Timer
  timerApi.After = function(_, fn) timers[#timers + 1] = fn end
  NUM_CHAT_WINDOWS = 3
  local chat1, chat2, chat3 = chatFrame(true), chatFrame(false), chatFrame(true)
  _G.ChatFrame1, _G.ChatFrame2, _G.ChatFrame3 = chat1, chat2, chat3
  local Core = RakaMod.Core

  now = now + 100
  eq(Core:RequestPlayed(false), true, "login played request is sent")
  eq(requests, 1, "login request reaches the server")
  eq(chat1.listening, true, "login request leaves chat frame 1 listening")
  eq(chat3.listening, true, "login request leaves chat frame 3 listening")
  eq(Core:RequestPlayed(false), false, "second request inside the cooldown is refused")

  now = now + 100
  eq(Core:RequestPlayed(true), true, "silent request is sent")
  eq(chat1.listening, false, "silent request mutes a listening frame")
  eq(chat3.listening, false, "silent request mutes the other listening frame")
  Stub.fire(env, fail, "TIME_PLAYED_MSG", 100, 50)
  eq(chat1.listening, true, "reply restores frame 1")
  eq(chat3.listening, true, "reply restores frame 3")
  eq(chat2.listening, false, "a frame that never listened is not subscribed")
  eq(chat1.registers, 1, "frame 1 restored exactly once")
  timers[#timers]()
  eq(chat1.registers, 1, "late timer does not restore twice")

  now = now + 100
  eq(Core:RequestPlayed(true), true, "second silent request is sent")
  eq(chat1.listening, false, "second silent request mutes again")
  timers[#timers]()
  eq(chat1.listening, true, "timer restores when no reply arrives")
  eq(chat3.listening, true, "timer restores frame 3 when no reply arrives")

  -- Login grace: another addon's reply suppresses our own request, silence requests once.
  now = now + 1000
  timers = {}
  requests = 0
  Stub.fire(env, fail, "PLAYER_LOGIN")
  eq(requests, 0, "login waits for a reply before asking")
  eq(#timers, 1, "login schedules one grace check")
  Stub.fire(env, fail, "TIME_PLAYED_MSG", 100, 50)
  timers[1]()
  eq(requests, 0, "no second request when someone else already asked")

  now = now + 1000
  timers = {}
  Stub.fire(env, fail, "PLAYER_LOGIN")
  timers[1]()
  eq(requests, 1, "login asks once when nobody replied")
  eq(chat1.listening, true, "login request is not muted")
end

-- AFK center stack: Fabled class art, class-colored name, spec and class lines -----------
do
  local afk = RakaMod.AFK
  eq(type(afk.Enter), "function", "AFK module loaded")
  local ui = afk.ui
  local savedUnitClass = UnitClass
  UnitClass = function() return "Warrior", "WARRIOR", 1 end
  local function enter(specName)
    rawset(_G, "GetSpecialization", specName and function() return 2 end or nil)
    rawset(_G, "GetSpecializationInfo", specName and function() return 72, specName end or nil)
    local ok, err = pcall(afk.Enter, afk)
    eq(ok, true, "AFK:Enter runs: " .. tostring(err))
    return ok
  end

  if enter("Fury") then
    eq(Stub.stored(ui.classArt, "Texture"), RakaMod.Media.FabledClassPath, "center icon uses the Fabled class sheet")
    local l, r, t, b = Stub.stored(ui.classArt, "TexCoord")
    near(l, 0.125, "warrior icon left")
    near(r, 0.25, "warrior icon right")
    near(t, 0, "warrior icon top")
    near(b, 0.125, "warrior icon bottom")
    eq(ui.classArt:IsShown(), true, "class art shown")
    eq(Stub.stored(ui.nameText, "Text"), "Tester", "name line")
    local fontSize = function(fs) return select(2, Stub.stored(fs, "Font")) end
    eq(fontSize(ui.timerText) < fontSize(ui.nameText), true, "timer is smaller than the name")
    eq(Stub.stored(ui.specText, "Text"), "Fury", "spec line")
    eq(ui.specText:IsShown(), true, "spec line shown")
    eq(Stub.stored(ui.classText, "Text"), "Warrior", "class line")
    afk:Leave(false)
  end

  if enter("Warrior") then
    eq(ui.specText:IsShown(), false, "spec line hidden when the spec API only returns the class name")
    afk:Leave(false)
  end

  if enter(nil) then
    eq(ui.specText:IsShown(), false, "spec line hidden when the client has no specs")
    eq(Stub.stored(ui.classText, "Text"), "Warrior", "class line still shown without a spec")
    afk:Leave(false)
  end
  rawset(_G, "GetSpecialization", nil)
  rawset(_G, "GetSpecializationInfo", nil)
  UnitClass = savedUnitClass
end

-- /rakamod spec prints the probe and does not open the settings window ------------------
do
  local printed = {}
  local savedPrint = print
  print = function(text) printed[#printed + 1] = tostring(text) end
  local opened = 0
  local savedOpen = RakaMod.OpenSettings
  RakaMod.OpenSettings = function() opened = opened + 1 end
  rawset(_G, "GetNumTalentTabs", function() return 3 end)
  rawset(_G, "GetTalentTabInfo", function(tab)
    local tabs = { { "Elemental", "i", 0 }, { "Enhancement", "i", 41 }, { "Restoration", "i", 5 } }
    return unpack(tabs[tab])
  end)
  local handler = SlashCmdList.RAKAMOD
  handler("spec")
  eq(opened, 0, "/rakamod spec does not open settings")
  eq(#printed > 0, true, "/rakamod spec prints the probe")
  local joined = table.concat(printed, "\n")
  eq(joined:find("GetTalentTabInfo(2)", 1, true) ~= nil, true, "probe lists the talent tabs")
  eq(joined:find("resolved spec: Enhancement via GetTalentTabInfo", 1, true) ~= nil, true, "probe resolves Enhancement")
  handler("  SPEC  ")
  eq(opened, 0, "/rm spec is case and space tolerant")
  rawset(_G, "GetNumTalentTabs", nil)
  rawset(_G, "GetTalentTabInfo", nil)
  rawset(_G, "GetSpecialization", function() return 1 end)
  rawset(_G, "GetSpecializationInfo", function() return 1489, (UnitClass("player")), "", 626006, "DAMAGER" end)
  printed = {}
  handler("spec")
  joined = table.concat(printed, "\n")
  eq(joined:find("GetSpecializationInfo(1) -> 1489, " .. (UnitClass("player")), 1, true) ~= nil, true, "probe prints the spec info returns")
  eq(joined:find("GetSpecializationInfoByID(1489) = missing", 1, true) ~= nil, true, "probe reports the by-id lookup")
  eq(joined:find("no usable name API", 1, true) ~= nil, true, "probe says when no API gives a name")
  rawset(_G, "GetSpecialization", nil)
  rawset(_G, "GetSpecializationInfo", nil)
  printed = {}
  handler("")
  eq(opened, 1, "bare slash command still opens settings")
  handler(nil)
  eq(opened, 2, "slash command without text still opens settings")
  eq(#printed, 0, "bare command printed no probe")
  rawset(_G, "GetNumTalentTabs", nil)
  rawset(_G, "GetTalentTabInfo", nil)
  RakaMod.OpenSettings = savedOpen
  print = savedPrint
end

if failures > 0 then
  os.exit(1)
end
print("ui ok")
