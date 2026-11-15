-- Stateful stand-in for the WoW API, shared by the smoke and UI tests.
-- Frames, textures and font strings accept any method call; Set<Name>/Get<Name> pairs remember
-- their arguments, Show/Hide/SetShown drive IsShown, and CreateFrame records OnEvent handlers.
-- Run from the repo root.

local Stub = {}
local unpack = table.unpack or unpack

local NUMERIC_GETTERS = {
  Width = 100, Height = 20, Left = 0, Right = 100, Top = 100, Bottom = 0, Alpha = 1, Scale = 1,
  Number = 0, Value = 0, MinMaxValues = 0, FrameLevel = 1, StringWidth = 50, StringHeight = 10,
  VerticalScroll = 0, HorizontalScroll = 0, VerticalScrollRange = 0, ValueStep = 1, NumPoints = 0,
  Size = 10, ColorRGB = 1, TextColor = 1, VertexColor = 1, CursorPosition = 0, Length = 0,
}
local STRING_GETTERS = { Text = "", Name = "stub", FontObject = "stub" }

local function newStub()
  local obj = {}
  local state = {}
  rawset(obj, "__state", state)
  local mt = {}
  mt.__index = function(self, key)
    if type(key) ~= "string" then
      return nil
    end
    if key == "Show" or key == "Hide" then
      return function(frame)
        state.Shown = key == "Show"
        return frame
      end
    end
    if key == "SetShown" then
      return function(frame, value)
        state.Shown = value and true or false
        return frame
      end
    end
    if key == "IsShown" then
      return function()
        return state.Shown == true
      end
    end
    local setName = key:match("^Set(.+)$")
    if setName then
      return function(frame, ...)
        state[setName] = { n = select("#", ...), ... }
        return frame
      end
    end
    local suffix = key:match("^Get(.+)$")
    if suffix then
      return function()
        local stored = state[suffix]
        if stored then
          return unpack(stored, 1, stored.n)
        end
        if suffix == "Width" and state.Size then
          return state.Size[1]
        elseif suffix == "Height" and state.Size then
          return state.Size[2] or state.Size[1]
        end
        if STRING_GETTERS[suffix] then
          return STRING_GETTERS[suffix]
        end
        return NUMERIC_GETTERS[suffix] or 0, NUMERIC_GETTERS[suffix] or 0, NUMERIC_GETTERS[suffix] or 0, 0
      end
    end
    if key:match("^Is") or key:match("^Has") then
      return function()
        return false
      end
    end
    return function(frame)
      if key:match("^Create") then
        return newStub()
      end
      return frame
    end
  end
  mt.__call = function()
    return newStub()
  end
  setmetatable(obj, mt)
  return obj
end
Stub.newStub = newStub

-- Last value stored by Set<Name>(...) on a stub object, as multiple returns.
function Stub.stored(obj, name)
  local stored = rawget(obj, "__state")[name]
  if not stored then
    return nil
  end
  return unpack(stored, 1, stored.n)
end

function Stub.script(obj, name)
  local scripts = rawget(obj, "__scripts")
  return scripts and scripts[name]
end

-- Installs the stub globals and returns an environment with the recorded registrations.
function Stub.install()
  local env = { registeredCategories = {}, registeredMedia = {}, libs = {}, handlers = {} }

  CreateFrame = function(_, _, parent)
    local f = newStub()
    rawset(f, "__parent", parent)
    rawset(f, "__scripts", {})
    rawset(f, "SetScript", function(self, name, fn)
      env.handlers[#env.handlers + 1] = { frame = self, name = name, fn = fn }
      rawget(self, "__scripts")[name] = fn
      return self
    end)
    rawset(f, "HookScript", function(self)
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
      env.registeredCategories[#env.registeredCategories + 1] = category
      return category
    end,
    RegisterAddOnCategory = function(category)
      category.added = true
    end,
  }
  env.libs["LibSharedMedia-3.0"] = {
    MediaType = { FONT = "font", STATUSBAR = "statusbar", BACKGROUND = "background" },
    Register = function(_, mediaType, name, path)
      env.registeredMedia[#env.registeredMedia + 1] = { type = mediaType, name = name, path = path }
      return true
    end,
  }
  LibStub = function(name)
    local lib = env.libs[name]
    if not lib then
      lib = newStub()
      env.libs[name] = lib
    end
    return lib
  end
  return env
end

-- Parses the TOC and returns its file list (forward slashes).
function Stub.tocFiles()
  local toc = assert(io.open("RakaMod.toc", "rb"))
  local files = {}
  for line in toc:lines() do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then
      files[#files + 1] = (line:gsub("\\", "/"))
    end
  end
  toc:close()
  return files
end

-- Loads every non-library Lua file in TOC order. Failures are reported through fail(message).
function Stub.loadAddon(files, fail)
  for _, path in ipairs(files) do
    if path:match("%.lua$") and not path:match("^Libs/") then
      local chunk, err = loadfile(path)
      if not chunk then
        fail("parse " .. path .. ": " .. tostring(err))
      else
        local ok, runErr = pcall(chunk, "RakaMod", {})
        if not ok then
          fail("load " .. path .. ": " .. tostring(runErr))
        end
      end
    end
  end
end

function Stub.fire(env, fail, event, ...)
  for _, h in ipairs(env.handlers) do
    if h.name == "OnEvent" then
      local ok, err = pcall(h.fn, h.frame, event, ...)
      if not ok then
        fail("event " .. event .. ": " .. tostring(err))
      end
    end
  end
end

return Stub
