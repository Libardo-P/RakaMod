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

local Stub = dofile("tests/wowstub.lua")
local env = Stub.install()
local registeredCategories, registeredMedia = env.registeredCategories, env.registeredMedia

local files = Stub.tocFiles()

local ldbIndex, dbIconIndex
for i, path in ipairs(files) do
  local handle = io.open(path, "rb")
  if handle then
    handle:close()
  else
    fail("TOC lists a missing file: " .. path)
  end
  if path:match("LibDataBroker%-1%.1%.lua$") then
    ldbIndex = i
  elseif path:match("LibDBIcon%-1%.0%.lua$") then
    dbIconIndex = i
  end
end
if not ldbIndex or not dbIconIndex or ldbIndex > dbIconIndex then
  fail("LibDataBroker-1.1 must be vendored and loaded before LibDBIcon-1.0")
end

Stub.loadAddon(files, fail)

local function fire(event, ...)
  Stub.fire(env, fail, event, ...)
end
fire("ADDON_LOADED", "RakaMod")
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

-- New UI files load in dependency order and the media they reference ships with the addon.
do
  local order = {}
  for i, path in ipairs(files) do
    order[path] = i
  end
  local chain = { "Logic.lua", "Media.lua", "UI/Theme.lua", "UI/Widgets.lua", "UI/ColorPicker.lua", "UI/Shell.lua", "Settings.lua" }
  for i = 1, #chain do
    if not order[chain[i]] then
      fail("TOC is missing " .. chain[i])
    elseif i > 1 and order[chain[i - 1]] and order[chain[i]] < order[chain[i - 1]] then
      fail(chain[i] .. " must load after " .. chain[i - 1])
    end
  end
  for _, name in ipairs({ "Theme", "Widgets", "Shell", "ColorPicker", "Settings" }) do
    if type(RakaMod[name]) ~= "table" then
      fail("RakaMod." .. name .. " was not created")
    end
  end
  local function exists(path)
    local handle = io.open(path, "rb")
    if handle then
      handle:close()
      return true
    end
    return false
  end
  local mediaRoot = "Interface\\AddOns\\RakaMod\\Media\\"
  local function onDisk(path, ext)
    local rel = path:sub(#mediaRoot + 1):gsub("\\", "/")
    return exists("Media/" .. rel .. (ext or ""))
  end
  if not onDisk(RakaMod.Media.UIFontPath) then
    fail("UI font missing: " .. tostring(RakaMod.Media.UIFontPath))
  end
  local count = 0
  for navKey in pairs(RakaMod.Media.NavIcons) do
    count = count + 1
    local path = RakaMod.Media.NavIconPath(navKey)
    if not path or not onDisk(path, ".tga") then
      fail("nav icon missing for " .. navKey)
    end
  end
  if count == 0 then
    fail("no nav icons configured")
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
