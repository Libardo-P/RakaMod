-- Loads every file in TOC order against a permissive WoW API stub, fires the load events and
-- checks for load-time errors, leaked globals and the Esc > Options category registration (B1).
-- Run from the repo root: lua tests/smoke_load.lua

local failures = 0
local function fail(msg)
  failures = failures + 1
  io.stderr:write("FAIL " .. msg .. "\n")
end

local before = {}
for k in pairs(_G) do
  before[k] = true
end

local Stub = {}
local NUMERIC_GETTERS = {
  Width = 100, Height = 20, Left = 0, Right = 100, Top = 100, Bottom = 0, Alpha = 1, Scale = 1,
  Number = 0, Value = 0, MinMaxValues = 0, FrameLevel = 1, StringWidth = 50, StringHeight = 10,
  VerticalScroll = 0, HorizontalScroll = 0, VerticalScrollRange = 0, ValueStep = 1, NumPoints = 0,
  Size = 10, ColorRGB = 1, TextColor = 1, VertexColor = 1, CursorPosition = 0, Length = 0,
}
local STRING_GETTERS = { Text = "", Name = "stub", FontObject = "stub" }

local function newStub()
  local obj = {}
  local mt = {}
  mt.__index = function(_, key)
    if type(key) ~= "string" then
      return nil
    end
    local suffix = key:match("^Get(.+)$")
    if suffix then
      if STRING_GETTERS[suffix] then
        return function()
          return STRING_GETTERS[suffix]
        end
      end
      return function()
        return NUMERIC_GETTERS[suffix] or 0, NUMERIC_GETTERS[suffix] or 0, NUMERIC_GETTERS[suffix] or 0, 0
      end
    end
    if key:match("^Is") or key:match("^Has") then
      return function()
        return false
      end
    end
    return function(self)
      if key:match("^Create") then
        return newStub()
      end
      return self
    end
  end
  mt.__call = function()
    return newStub()
  end
  setmetatable(obj, mt)
  return obj
end

local registeredCategories = {}
local libs = {}
local handlers = {}

CreateFrame = function(_, _, parent)
  local f = newStub()
  rawset(f, "__parent", parent)
  rawset(f, "SetScript", function(self, name, fn)
    handlers[#handlers + 1] = { frame = self, name = name, fn = fn }
    return self
  end)
  rawset(f, "RegisterEvent", function(self)
    return self
  end)
  return f
end
UIParent = newStub()
UISpecialFrames = {}
BackdropTemplateMixin = {}
SlashCmdList = {}
C_AddOns = {
  IsAddOnLoaded = function()
    return true
  end,
  LoadAddOn = function() end,
  GetAddOnMetadata = function()
    return "0.0.0"
  end,
}
C_Timer = { After = function() end, NewTicker = function() return newStub() end }
GetAddOnMetadata = C_AddOns.GetAddOnMetadata
GetBuildInfo = function()
  return "1.0", "1", "Jan 1 2026", 16001
end
GetTime = function()
  return 100
end
InCombatLockdown = function()
  return false
end
RequestTimePlayed = function() end
hooksecurefunc = function() end
UnitClass = function()
  return "Warrior", "WARRIOR", 1
end
UnitName = function()
  return "Tester"
end
UnitLevel = function()
  return 80
end
UnitRace = function()
  return "Human", "Human"
end
UnitExists = function()
  return false
end
UnitIsAFK = function()
  return false
end
UnitCastingInfo = function() end
UnitChannelInfo = function() end
RAID_CLASS_COLORS = setmetatable({}, {
  __index = function()
    return { r = 1, g = 1, b = 1 }
  end,
})
GameTooltip = newStub()
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
Settings = {
  RegisterCanvasLayoutCategory = function(panel, name)
    local category = { panel = panel, name = name }
    registeredCategories[#registeredCategories + 1] = category
    return category
  end,
  RegisterAddOnCategory = function(category)
    category.added = true
  end,
}
local registeredMedia = {}
libs["LibSharedMedia-3.0"] = {
  MediaType = { FONT = "font", STATUSBAR = "statusbar", BACKGROUND = "background" },
  Register = function(_, mediaType, name, path)
    registeredMedia[#registeredMedia + 1] = { type = mediaType, name = name, path = path }
    return true
  end,
}
LibStub = function(name)
  local lib = libs[name]
  if not lib then
    lib = newStub()
    libs[name] = lib
  end
  return lib
end

local toc = assert(io.open("RakaMod.toc", "rb"))
local files = {}
for line in toc:lines() do
  line = line:gsub("\r", "")
  if line ~= "" and not line:match("^#") then
    files[#files + 1] = (line:gsub("\\", "/"))
  end
end
toc:close()

local addonName = "RakaMod"
for _, path in ipairs(files) do
  if path:match("%.lua$") and not path:match("^Libs/") then
    local chunk, err = loadfile(path)
    if not chunk then
      fail("parse " .. path .. ": " .. tostring(err))
    else
      local ok, runErr = pcall(chunk, addonName, {})
      if not ok then
        fail("load " .. path .. ": " .. tostring(runErr))
      end
    end
  end
end

local function fire(event, ...)
  for _, h in ipairs(handlers) do
    if h.name == "OnEvent" then
      local ok, err = pcall(h.fn, h.frame, event, ...)
      if not ok then
        fail("event " .. event .. ": " .. tostring(err))
      end
    end
  end
end
fire("ADDON_LOADED", addonName)
fire("PLAYER_LOGIN")

if #registeredCategories ~= 1 then
  fail("Esc > Options category registered " .. #registeredCategories .. " times (expected 1)")
elseif registeredCategories[1].name ~= "RakaMod" or not registeredCategories[1].added then
  fail("Esc > Options category not added for RakaMod")
end

local PREFIX = "Rk "
local ROOT = "Interface\\AddOns\\RakaMod\\"
if #registeredMedia == 0 then
  fail("no media registered")
end
local seen = {}
for _, entry in ipairs(registeredMedia) do
  if entry.name:sub(1, #PREFIX) ~= PREFIX then
    fail("media name without Rk prefix: " .. entry.name)
  end
  if seen[entry.type .. entry.name] then
    fail("duplicate media name: " .. entry.name)
  end
  seen[entry.type .. entry.name] = true
  local rel = entry.path:sub(#ROOT + 1):gsub("\\", "/")
  local f = io.open(rel, "rb")
  if f then
    f:close()
  else
    fail("registered media file missing: " .. rel)
  end
end

local allowed = {
  RakaMod = true, RakaModDB = true, SLASH_RAKAMOD1 = true, SLASH_RAKAMOD2 = true, SLASH_RAKAMOD3 = true,
  CreateFrame = true, UIParent = true, UISpecialFrames = true, BackdropTemplateMixin = true, SlashCmdList = true,
  C_AddOns = true, C_Timer = true, GetAddOnMetadata = true, GetBuildInfo = true, GetTime = true,
  InCombatLockdown = true, RequestTimePlayed = true, hooksecurefunc = true, UnitClass = true, UnitName = true,
  UnitLevel = true, UnitRace = true, UnitExists = true, UnitIsAFK = true, UnitCastingInfo = true, UnitChannelInfo = true, RAID_CLASS_COLORS = true, GameTooltip = true,
  STANDARD_TEXT_FONT = true, Settings = true, LibStub = true,
}
for k in pairs(_G) do
  if not before[k] and not allowed[k] then
    fail("leaked global " .. tostring(k))
  end
end

if failures > 0 then
  os.exit(1)
end
print("smoke ok")
