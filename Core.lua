local ADDON = ...
RakaMod = RakaMod or {}
local Logic = RakaMod.Logic or dofile("Logic.lua")
RakaMod.Logic = Logic

local DEFAULTS = {
  general = { showMinimapIcon = true, hide = false, minimapPos = 210 },
  overlay = { enabled = true, collections = true, played = true, professions = true },
  reveal = { enabled = true, casting = true, health = true, mouseover = true, combat = true, pet = false },
  zoneText = { enabled = true, size = 32, r = 1, g = 1, b = 1, outline = "OUTLINE" },
  afk = { enabled = true, cameraPan = true },
  gradient = (function()
    local colors = {}
    for i = 1, #Logic.CLASS_FILES do
      local file = Logic.CLASS_FILES[i]
      local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
      if type(c) == "table" and type(c.r) == "number" then
        colors[file] = { r = c.r, g = c.g, b = c.b }
      end
    end
    return Logic.BuildGradientDefaults(colors)
  end)(),
  played = {},
}

local Core = {}
RakaMod.Core = Core
local modules = {}
local loginDone = false
local missingPrinted = false
local lastPlayedRequest = nil

function Core:IsForever()
  local _, _, _, interfaceVersion = GetBuildInfo()
  return Logic.IsForever(interfaceVersion)
end

function Core:AddonLoaded(name)
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)
end

function Core:CanRequestPlayed(now)
  return Logic.CanRequestPlayed(now, lastPlayedRequest)
end

function Core:NotePlayedRequest(now)
  lastPlayedRequest = now
end

local function sectionEnabled(def)
  local section = RakaMod.db[def.dbKey]
  if type(section) ~= "table" or section.enabled ~= true then
    return false
  end
  if def.requires and not Core:AddonLoaded(def.requires) then
    return false
  end
  return true
end

function Core:ApplyModule(def)
  if sectionEnabled(def) then
    if not def._enabled and def.OnEnable then
      def._enabled = true
      def:OnEnable()
    end
  elseif def._enabled and def.OnDisable then
    def._enabled = false
    def:OnDisable()
  else
    def._enabled = false
  end
end

function Core:RegisterModule(def)
  modules[#modules + 1] = def
  if def.OnLoad then
    def:OnLoad()
  end
  if loginDone then
    self:ApplyModule(def)
  end
end

function Core:RefreshModules()
  for _, def in ipairs(modules) do
    self:ApplyModule(def)
  end
  if RakaMod.MinimapIcon and RakaMod.MinimapIcon.Apply then
    RakaMod.MinimapIcon:Apply()
  end
end

function RakaMod.OpenSettings()
  if RakaMod.Settings and RakaMod.Settings.Show then
    RakaMod.Settings:Show()
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    if not Core:AddonLoaded("EllesmereUI") then
      if not missingPrinted then
        print("RakaMod requires EllesmereUI.")
        missingPrinted = true
      end
      return
    end
    RakaModDB = Logic.MergeDefaults(RakaModDB, DEFAULTS)
    RakaMod.db = RakaModDB
  elseif event == "PLAYER_LOGIN" then
    if not RakaMod.db then
      return
    end
    RakaMod.sessionStart = GetTime()
    RakaMod.playedThisSession = false
    loginDone = true
    Core:RefreshModules()
    if Core:CanRequestPlayed(GetTime()) then
      RequestTimePlayed()
      Core:NotePlayedRequest(GetTime())
    end
  end
end)

SLASH_RAKAMOD1 = "/rakamod"
SLASH_RAKAMOD2 = "/rmod"
SLASH_RAKAMOD3 = "/rm"
SlashCmdList.RAKAMOD = function()
  RakaMod.OpenSettings()
end
