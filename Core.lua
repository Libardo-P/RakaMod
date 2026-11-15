local ADDON = ...
RakaMod = RakaMod or {}
local Logic = RakaMod.Logic or dofile("Logic.lua")
RakaMod.Logic = Logic

local DEFAULTS = {
  general = {
    showMinimapIcon = true,
    hide = false,
    minimapPos = 210,
    windowScale = 100,
    accent = Logic.BuildAccentDefaults(),
  },
  features = { fadeGrain = true, backgroundFade = 50 },
  overlay = {
    enabled = true,
    collections = true,
    played = true,
    professions = true,
  },
  reveal = { enabled = true, casting = true, health = true, mouseover = true, combat = true, pet = false },
  zoneText = { enabled = true, size = 32, r = 1, g = 1, b = 1, outline = "OUTLINE" },
  afk = {
    enabled = true,
    playEmotes = true,
    cameraPan = true,
    showChangelog = true,
  },
  gradient = Logic.BuildGradientDefaults(),
  mediaMigration = Logic.MEDIA_MIGRATION_VERSION,
  played = {},
}

local Core = {}
Core.DEFAULTS = DEFAULTS
RakaMod.Core = Core
local modules = {}
local loginDone = false
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

local PLAYED_MUTE_MAX_SECONDS = 10
local playedMuted = nil

-- Hands TIME_PLAYED_MSG back to every chat frame we took it from. Safe to call twice.
local function RestorePlayedChat()
  local chats = playedMuted
  if not chats then
    return
  end
  playedMuted = nil
  frame:UnregisterEvent("TIME_PLAYED_MSG")
  for i = 1, #chats do
    pcall(chats[i].RegisterEvent, chats[i], "TIME_PLAYED_MSG")
  end
end

-- Silences the chat lines of one /played reply. Only frames that actually listen are
-- touched, and the event comes back as soon as the reply arrives (or after a hard cap).
-- Without a timer there is no guaranteed restore, so nothing is muted at all.
local function MutePlayedChat()
  if playedMuted or not (C_Timer and C_Timer.After) then
    return
  end
  local chats = {}
  local windows = tonumber(NUM_CHAT_WINDOWS) or 10
  for i = 1, windows do
    local chat = _G["ChatFrame" .. i]
    if chat and chat.IsEventRegistered and chat.UnregisterEvent
      and chat:IsEventRegistered("TIME_PLAYED_MSG")
      and pcall(chat.UnregisterEvent, chat, "TIME_PLAYED_MSG") then
      chats[#chats + 1] = chat
    end
  end
  if #chats == 0 then
    return
  end
  playedMuted = chats
  frame:RegisterEvent("TIME_PLAYED_MSG")
  C_Timer.After(PLAYED_MUTE_MAX_SECONDS, RestorePlayedChat)
end

-- Asks the server for /played. The login request prints normally; automatic follow-up
-- requests (silent = true) swallow their chat lines so the player is not spammed.
function Core:RequestPlayed(silent)
  if type(RequestTimePlayed) ~= "function" or type(GetTime) ~= "function" then
    return false
  end
  local now = GetTime()
  if not self:CanRequestPlayed(now) then
    return false
  end
  if silent then
    MutePlayedChat()
  end
  if not pcall(RequestTimePlayed) then
    RestorePlayedChat()
    return false
  end
  self:NotePlayedRequest(now)
  return true
end

frame:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    if not Core:AddonLoaded("EllesmereUI") then
      return
    end
    if RakaMod.Media and RakaMod.Media.LegacyNames then
      Logic.MigrateMediaNames(RakaModDB, RakaMod.Media.LegacyNames)
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
    Core:RequestPlayed(false)
  elseif event == "TIME_PLAYED_MSG" then
    RestorePlayedChat()
  end
end)

SLASH_RAKAMOD1 = "/rakamod"
SLASH_RAKAMOD2 = "/rmod"
SLASH_RAKAMOD3 = "/rm"
SlashCmdList.RAKAMOD = function()
  RakaMod.OpenSettings()
end
