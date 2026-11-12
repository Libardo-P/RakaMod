RakaMod = RakaMod or {}

local AFK = {}
RakaMod.AFK = AFK

local CHAT_EVENTS = {
  "CHAT_MSG_WHISPER",
  "CHAT_MSG_BN_WHISPER",
  "CHAT_MSG_GUILD",
}
local CHAT_LIMIT = 500

local active = false
local suppressUntil
local startedAt
local castRetry = false
local cameraOn = false
local enteredByKey = false
local holdUntilFlag = false
local pendingShowParent = false
local enabled = false
local ticker
local modelTimer
local chatLines = {}

local frame
local model
local nameText
local guildText
local timerText
local chat
local events
local Consider

local function CancelHandle(handle)
  if handle and handle.Cancel then
    pcall(handle.Cancel, handle)
  end
end

local function Paint(fs, size, r, g, b)
  local path = RakaMod.Media and RakaMod.Media.FontPath
  if path then
    pcall(fs.SetFont, fs, path, size, "OUTLINE")
  end
  fs:SetTextColor(r, g, b)
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 1)
end

local function ClearChat()
  for i = #chatLines, 1, -1 do
    chatLines[i] = nil
  end
  if chat then
    chat:Clear()
  end
end

local function ShowChat()
  chat:Clear()
  for i = 1, #chatLines do
    chat:AddMessage(chatLines[i], 0.86, 0.84, 0.78)
  end
end

local function AddChat(sender, message)
  chatLines[#chatLines + 1] = tostring(sender or "") .. ": " .. tostring(message or "")
  while #chatLines > CHAT_LIMIT do
    table.remove(chatLines, 1)
  end
  ShowChat()
end

local function RegisterChat()
  for i = 1, #CHAT_EVENTS do
    chat:RegisterEvent(CHAT_EVENTS[i])
  end
end

local function UnregisterChat()
  for i = 1, #CHAT_EVENTS do
    chat:UnregisterEvent(CHAT_EVENTS[i])
  end
  ClearChat()
end

local function NameLine()
  local name = UnitName("player") or ""
  local realm = GetRealmName() or ""
  if realm ~= "" then
    return name .. " - " .. realm
  end
  return name
end

local function GuildLine()
  local guildName, guildRank = GetGuildInfo("player")
  if type(guildName) == "string" and guildName ~= "" then
    if type(guildRank) == "string" and guildRank ~= "" then
      return guildName .. "-" .. guildRank
    end
    return guildName
  end
  return "No Guild"
end

local function CastIsTheBlock()
  if RakaMod.db.afk.enabled ~= true or not UnitIsAFK("player") then
    return false
  end
  if InCombatLockdown() then
    return false
  end
  if CinematicFrame and CinematicFrame:IsShown() then
    return false
  end
  if MovieFrame and MovieFrame:IsShown() then
    return false
  end
  return UnitCastingInfo("player") or UnitChannelInfo("player")
end

function AFK:Enter()
  if active then
    return
  end
  active = true
  startedAt = GetTime()
  enteredByKey = false
  holdUntilFlag = false

  pcall(CloseAllWindows)
  UIParent:Hide()
  frame:Show()

  nameText:SetText(NameLine())
  guildText:SetText(GuildLine())
  timerText:SetText(RakaMod.Logic.FormatClock(0))

  CancelHandle(modelTimer)
  modelTimer = nil
  local posed = pcall(model.SetUnit, model, "player")
  if posed then
    model:Show()
    pcall(model.SetAnimation, model, 67)
    modelTimer = C_Timer.After(2.3, function() if model then pcall(model.SetAnimation, model, 0) end end)
  else
    model:Hide()
  end

  CancelHandle(ticker)
  ticker = C_Timer.NewTicker(1, function()
    if not active or not startedAt then
      return
    end
    timerText:SetText(RakaMod.Logic.FormatClock(GetTime() - startedAt))
  end)

  RegisterChat()

  local afkDb = RakaMod.db and RakaMod.db.afk
  if afkDb and afkDb.cameraPan == true then
    cameraOn = pcall(MoveViewLeftStart, 0.03)
  else
    cameraOn = false
  end
end

local function ShowParent()
  local inCombat = type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
  local ok = pcall(UIParent.Show, UIParent)
  pendingShowParent = (not ok) or inCombat
end

local function RestoreParent()
  if pendingShowParent then
    ShowParent()
  end
end

function AFK:Leave(fromKey)
  if not active then
    RestoreParent()
    return
  end

  CancelHandle(ticker)
  ticker = nil
  CancelHandle(modelTimer)
  modelTimer = nil

  if cameraOn then
    pcall(MoveViewLeftStop)
    cameraOn = false
  end

  UnregisterChat()
  frame:Hide()

  active = false
  enteredByKey = fromKey == true
  if fromKey then
    suppressUntil = GetTime() + 60
    holdUntilFlag = false
    C_Timer.After(60, Consider)
  else
    suppressUntil = nil
    holdUntilFlag = true
  end

  ShowParent()
end

Consider = function()
  if holdUntilFlag and UnitIsAFK("player") then
    return
  end

  local blocked = RakaMod.Logic.AfkBlocked({
    enabled = RakaMod.db.afk.enabled,
    isAFK = UnitIsAFK("player"),
    locked = InCombatLockdown(),
    cinematic = CinematicFrame and CinematicFrame:IsShown(),
    movie = MovieFrame and MovieFrame:IsShown(),
    casting = UnitCastingInfo("player") or UnitChannelInfo("player"),
  })
  local suppressed = RakaMod.Logic.AfkSuppressed(GetTime(), suppressUntil)

  if blocked and CastIsTheBlock() then
    if castRetry == false then
      C_Timer.After(30, Consider)
      castRetry = true
    end
  end

  if not blocked and not suppressed and not active then
    AFK:Enter()
  end
  if not UnitIsAFK("player") and active then
    AFK:Leave(false)
  end
  if not UnitIsAFK("player") then
    holdUntilFlag = false
    castRetry = false
    if enteredByKey then
      enteredByKey = false
    end
  end
end

function AFK:Enable()
  enabled = true
  events:RegisterEvent("PLAYER_FLAGS_CHANGED")
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  events:RegisterEvent("LFG_PROPOSAL_SHOW")
  events:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
  holdUntilFlag = false
  castRetry = false
  RestoreParent()
  Consider()
end

function AFK:Disable()
  enabled = false
  events:UnregisterEvent("PLAYER_FLAGS_CHANGED")
  events:UnregisterEvent("PLAYER_REGEN_DISABLED")
  events:UnregisterEvent("LFG_PROPOSAL_SHOW")
  events:UnregisterEvent("UPDATE_BATTLEFIELD_STATUS")
  if active then
    self:Leave(false)
  else
    RestoreParent()
  end
  if not pendingShowParent then
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
end

frame = CreateFrame("Frame", "RakaModAFK", WorldFrame)
frame:SetAllPoints(WorldFrame)
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetFrameLevel(100)
frame:EnableMouse(true)
frame:EnableKeyboard(true)
frame:Hide()

local shade = frame:CreateTexture(nil, "BACKGROUND")
shade:SetAllPoints()
shade:SetColorTexture(0, 0, 0, 0.28)

frame:SetScript("OnKeyDown", function(self, key)
  if self.SetPropagateKeyboardInput then
    self:SetPropagateKeyboardInput(false)
  end
  if key == "PRINTSCREEN" then
    Screenshot()
    return
  end
  AFK:Leave(true)
end)

model = CreateFrame("PlayerModel", nil, frame)
model:SetSize(520, 640)
model:SetPoint("LEFT", frame, "LEFT", 72, -16)
model:SetFrameLevel(frame:GetFrameLevel() + 1)
model:Hide()

nameText = frame:CreateFontString(nil, "OVERLAY")
nameText:SetPoint("TOPLEFT", frame, "CENTER", 36, 88)
nameText:SetJustifyH("LEFT")
nameText:SetWordWrap(false)
nameText:SetWidth(480)
Paint(nameText, 40, 1, 1, 1)

guildText = frame:CreateFontString(nil, "OVERLAY")
guildText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -10)
guildText:SetJustifyH("LEFT")
guildText:SetWordWrap(false)
guildText:SetWidth(480)
Paint(guildText, 18, 0.91, 0.84, 0.64)

timerText = frame:CreateFontString(nil, "OVERLAY")
timerText:SetPoint("TOPLEFT", guildText, "BOTTOMLEFT", 0, -18)
timerText:SetJustifyH("LEFT")
timerText:SetWidth(480)
Paint(timerText, 32, 1, 1, 1)

chat = CreateFrame("ScrollingMessageFrame", nil, frame)
chat:SetSize(520, 220)
chat:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -64, 48)
chat:SetFrameLevel(frame:GetFrameLevel() + 2)
chat:SetJustifyH("LEFT")
chat:SetFading(false)
chat:SetMaxLines(CHAT_LIMIT)
chat:EnableMouse(true)
chat:EnableMouseWheel(true)
do
  local path = RakaMod.Media and RakaMod.Media.FontPath
  if path then
    pcall(chat.SetFont, chat, path, 14, "OUTLINE")
  end
end
pcall(chat.SetShadowOffset, chat, 1, -1)
pcall(chat.SetShadowColor, chat, 0, 0, 0, 1)
chat:SetScript("OnMouseWheel", function(self, delta)
  if delta > 0 then
    self:ScrollUp()
  else
    self:ScrollDown()
  end
end)
chat:SetScript("OnEvent", function(_, event, message, sender)
  if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_GUILD" then
    AddChat(sender, message)
  end
end)

events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
  if event == "PLAYER_REGEN_ENABLED" then
    RestoreParent()
    if not enabled and not pendingShowParent then
      events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
    return
  end
  if event == "PLAYER_FLAGS_CHANGED" then
    if arg1 == "player" then
      Consider()
    end
    return
  end
  if not active then
    return
  end
  if event == "PLAYER_REGEN_DISABLED" or event == "LFG_PROPOSAL_SHOW" then
    AFK:Leave(false)
  elseif event == "UPDATE_BATTLEFIELD_STATUS" and GetBattlefieldStatus(arg1) == "confirm" then
    AFK:Leave(false)
  end
end)

RakaMod.Core:RegisterModule({
  name = "AFK",
  dbKey = "afk",
  requires = nil,
  OnLoad = function(self) end,
  OnEnable = function(self) RakaMod.AFK:Enable() end,
  OnDisable = function(self) RakaMod.AFK:Disable() end,
})
