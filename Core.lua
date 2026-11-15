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
  fonts = { afk = Logic.DEFAULT_AFK_FONT, ui = Logic.DEFAULT_UI_FONT },
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
local PLAYED_LOGIN_GRACE_SECONDS = 3
local playedMuted = nil
local playedSeen = false

-- Hands TIME_PLAYED_MSG back to every chat frame we took it from. Safe to call twice.
local function RestorePlayedChat()
  local chats = playedMuted
  if not chats then
    return
  end
  playedMuted = nil
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
    playedSeen = false
    frame:RegisterEvent("TIME_PLAYED_MSG")
    -- Other addons (and the client) often ask for /played at login. If a reply shows up
    -- during the grace period we do not ask again, otherwise chat prints the lines twice.
    if C_Timer and C_Timer.After then
      C_Timer.After(PLAYED_LOGIN_GRACE_SECONDS, function()
        if not playedSeen then
          Core:RequestPlayed(false)
        end
      end)
    else
      Core:RequestPlayed(false)
    end
  elseif event == "TIME_PLAYED_MSG" then
    playedSeen = true
    RestorePlayedChat()
  end
end)

-- Talent/spec functions this client may have (Retail, MoP+, Cata+ and classic talent trees).
-- Each falls back to the C_SpecializationInfo copy when the global is missing.
local SPEC_API_NAMES = {
  "GetSpecialization", "GetSpecializationInfo", "GetSpecializationInfoByID",
  "GetSpecializationNameForSpecID", "GetSpecializationInfoForSpecID",
  "GetSpecializationInfoForClassID", "GetNumSpecializationsForClassID",
  "GetInspectSpecialization", "GetNumSpecializations", "GetSpecializationRole",
}

function Core:SpecApi()
  local c = type(C_SpecializationInfo) == "table" and C_SpecializationInfo or {}
  local api = {
    GetPrimaryTalentTree = GetPrimaryTalentTree,
    GetNumTalentTabs = GetNumTalentTabs,
    GetTalentTabInfo = GetTalentTabInfo,
  }
  for _, name in ipairs(SPEC_API_NAMES) do
    api[name] = _G[name] or c[name]
  end
  return api
end

local function ProbeLine(text)
  print("|cff33ccffRakaMod spec:|r " .. text)
end

local function JoinResults(results, first, last)
  local parts = {}
  for i = first, last do
    parts[#parts + 1] = tostring(results[i])
  end
  return table.concat(parts, ", ")
end

local function Pack(...)
  return { n = select("#", ...), ... }
end

local function ProbeCall(label, fn, ...)
  if type(fn) ~= "function" then
    ProbeLine(label .. " = missing")
    return
  end
  local results = Pack(pcall(fn, ...))
  if not results[1] then
    ProbeLine(label .. " -> error: " .. tostring(results[2]))
  elseif results.n < 2 then
    ProbeLine(label .. " -> (no values)")
  else
    ProbeLine(label .. " -> " .. JoinResults(results, 2, math.min(results.n, 9)))
  end
end

local function ProbeNames(label, pattern, source)
  local found = {}
  for key, value in pairs(source) do
    if type(key) == "string" and type(value) == "function" and key:find(pattern) then
      found[#found + 1] = key
    end
  end
  table.sort(found)
  ProbeLine(label .. " (" .. #found .. "): " .. table.concat(found, " ", 1, math.min(#found, 40)))
end

-- /rakamod spec: prints which talent APIs exist, their raw returns, and the resolved spec.
function Core:PrintSpecProbe()
  local api = self:SpecApi()
  local localized, classFile, classId = UnitClass("player")
  local _, _, _, build = GetBuildInfo()
  ProbeLine("interface " .. tostring(build) .. ", class " .. tostring(localized) .. " (" .. tostring(classFile) .. ", id " .. tostring(classId) .. ")")
  for _, name in ipairs({ "GetNumSpecializations", "GetActiveSpecGroup", "GetActiveTalentGroup", "GetNumTalents", "GetNumTalentGroups" }) do
    ProbeCall(name .. "()", _G[name])
  end
  ProbeCall("GetSpecialization()", api.GetSpecialization)
  local okIndex, index = pcall(api.GetSpecialization or function() end)
  index = (okIndex and type(index) == "number" and index > 0) and index or 1
  ProbeCall("GetSpecializationInfo(" .. index .. ")", api.GetSpecializationInfo, index)
  local okInfo, specId = pcall(api.GetSpecializationInfo or function() end, index)
  if not (okInfo and type(specId) == "number") then
    specId = nil
  end
  ProbeCall("GetSpecializationRole(" .. index .. ")", api.GetSpecializationRole, index)
  if specId then
    ProbeCall("GetSpecializationInfoByID(" .. specId .. ")", api.GetSpecializationInfoByID, specId)
    ProbeCall("GetSpecializationNameForSpecID(" .. specId .. ")", api.GetSpecializationNameForSpecID, specId)
    ProbeCall("GetSpecializationInfoForSpecID(" .. specId .. ")", api.GetSpecializationInfoForSpecID, specId)
  end
  ProbeCall("GetInspectSpecialization(\"player\")", api.GetInspectSpecialization, "player")
  ProbeCall("GetNumSpecializationsForClassID(" .. tostring(classId) .. ")", api.GetNumSpecializationsForClassID, classId)
  for i = 1, 4 do
    ProbeCall("GetSpecializationInfoForClassID(" .. tostring(classId) .. ", " .. i .. ")", api.GetSpecializationInfoForClassID, classId, i)
  end
  if type(PlayerUtil) == "table" then
    ProbeCall("PlayerUtil.GetCurrentSpecID()", PlayerUtil.GetCurrentSpecID)
    ProbeCall("PlayerUtil.GetSpecName()", PlayerUtil.GetSpecName)
  else
    ProbeLine("PlayerUtil = missing")
  end
  ProbeCall("GetPrimaryTalentTree()", api.GetPrimaryTalentTree)
  ProbeCall("GetPrimaryTalentTree(false, false, 1)", api.GetPrimaryTalentTree, false, false, 1)
  ProbeCall("GetNumTalentTabs()", api.GetNumTalentTabs)
  local okTabs, tabs = pcall(api.GetNumTalentTabs or function() end)
  tabs = (okTabs and type(tabs) == "number") and tabs or 3
  for tab = 1, math.min(tabs, 4) do
    ProbeCall("GetTalentTabInfo(" .. tab .. ")", api.GetTalentTabInfo, tab)
  end
  ProbeNames("globals matching Spec", "Spec", _G)
  ProbeNames("globals matching Talent", "Talent", _G)
  if type(C_SpecializationInfo) == "table" then
    ProbeNames("C_SpecializationInfo functions", ".", C_SpecializationInfo)
  else
    ProbeLine("C_SpecializationInfo = missing")
  end
  for _, ns in ipairs({ "C_ClassTalents", "C_Traits" }) do
    if type(_G[ns]) == "table" then
      ProbeNames(ns .. " functions", ".", _G[ns])
    else
      ProbeLine(ns .. " = missing")
    end
  end
  local name, source = Logic.ResolveSpecName(api, localized, classId)
  ProbeLine("resolved spec: " .. tostring(name) .. " via " .. tostring(source))
  if not name then
    ProbeLine("no usable name API on this client")
  end
end

SLASH_RAKAMOD1 = "/rakamod"
SLASH_RAKAMOD2 = "/rmod"
SLASH_RAKAMOD3 = "/rm"
SlashCmdList.RAKAMOD = function(msg)
  local command = type(msg) == "string" and msg:lower():match("^%s*(%S+)") or nil
  if command == "spec" then
    Core:PrintSpecProbe()
    return
  end
  RakaMod.OpenSettings()
end
