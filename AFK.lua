RakaMod = RakaMod or {}

local AFK = {}
RakaMod.AFK = AFK

local CHAT_EVENTS = {
  "CHAT_MSG_WHISPER",
  "CHAT_MSG_BN_WHISPER",
  "CHAT_MSG_GUILD",
}
local CHAT_LIMIT = 500
local DANCE_ANIM = 69
local INPUT_GRACE = 0.6
local TIMER_CYAN = { r = 0.0, g = 0.95, b = 1.0 }

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
local lastCursorX
local lastCursorY
local inputArmed = false

local frame
local model
local logo
local nameText
local titleText
local timerText
local levelText
local classIcon
local classText
local changelogHeader
local changelogBody
local footerText
local chat
local events
local Consider

local function CancelHandle(handle)
  if handle and handle.Cancel then
    pcall(handle.Cancel, handle)
  end
end

local function Paint(fs, size, r, g, b, a)
  local path = RakaMod.Media and RakaMod.Media.FontPath
  if path then
    pcall(fs.SetFont, fs, path, size, "OUTLINE")
  end
  fs:SetTextColor(r, g, b, a or 1)
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

local function PlayerName()
  return UnitName("player") or ""
end

local function PlayerTitle()
  if type(GetCurrentTitle) ~= "function" or type(GetTitleName) ~= "function" then
    return nil
  end
  local ok, titleId = pcall(GetCurrentTitle)
  if not ok or type(titleId) ~= "number" or titleId <= 0 then
    return nil
  end
  local okName, title = pcall(GetTitleName, titleId)
  if okName and type(title) == "string" and title ~= "" then
    return title
  end
  return nil
end

local function ClassInfo()
  local localized, classFile = UnitClass("player")
  return localized or "", classFile or "WARRIOR"
end

local function ClassColor(classFile)
  return RakaMod.Logic.ClassRgb(classFile, RAID_CLASS_COLORS)
end

local function ApplyClassIcon(classFile)
  local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
  if type(coords) ~= "table" then
    classIcon:Hide()
    return
  end
  classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
  classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  classIcon:Show()
end

local function EllesmerePatches()
  if EllesmereUI and type(EllesmereUI._WHATSNEW_PATCHES) == "table" then
    return EllesmereUI._WHATSNEW_PATCHES
  end
  -- WhatsNew lives in EllesmereUIOptions; load it if present but not yet loaded.
  if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "EllesmereUIOptions")
  elseif type(LoadAddOn) == "function" then
    pcall(LoadAddOn, "EllesmereUIOptions")
  end
  if EllesmereUI and type(EllesmereUI._WHATSNEW_PATCHES) == "table" then
    return EllesmereUI._WHATSNEW_PATCHES
  end
  return nil
end

local function FillChangelog()
  local patches = EllesmerePatches()
  local isForever = RakaMod.Core and RakaMod.Core:IsForever() or false
  local header, body = RakaMod.Logic.FormatEllesmereChangelog(patches, isForever, 8, 8)
  if header and body then
    changelogHeader:SetText(header)
    changelogBody:SetText(body)
    changelogHeader:Show()
    changelogBody:Show()
    return
  end
  if type(EllesmereUI) ~= "table" then
    changelogHeader:SetText("EllesmereUI changelog unavailable")
    changelogBody:SetText("EllesmereUI is not loaded.")
  else
    changelogHeader:SetText("EllesmereUI changelog unavailable")
    changelogBody:SetText("Could not read patch notes from EllesmereUI.")
  end
  changelogHeader:Show()
  changelogBody:Show()
end

local function PoseModel()
  CancelHandle(modelTimer)
  modelTimer = nil
  model:SetScript("OnAnimFinished", nil)

  local posed = pcall(model.SetUnit, model, "player")
  if not posed then
    model:Hide()
    return
  end

  model:Show()
  pcall(model.SetCamDistanceScale, model, 3.2)
  pcall(model.SetPosition, model, 0, 0, -0.15)
  pcall(model.SetFacing, model, 0.35)
  pcall(model.SetAnimation, model, DANCE_ANIM)
  model:SetScript("OnAnimFinished", function(self)
    pcall(self.SetAnimation, self, DANCE_ANIM)
  end)
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

local function ArmInputWatch()
  inputArmed = false
  lastCursorX, lastCursorY = nil, nil
  C_Timer.After(INPUT_GRACE, function()
    if not active then
      return
    end
    inputArmed = true
    local x, y = GetCursorPosition()
    lastCursorX, lastCursorY = x, y
  end)
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
  if frame.EnableKeyboard then
    frame:EnableKeyboard(true)
  end
  if frame.SetPropagateKeyboardInput then
    pcall(frame.SetPropagateKeyboardInput, frame, false)
  end

  local localized, classFile = ClassInfo()
  local cr, cg, cb = ClassColor(classFile)
  nameText:SetText(PlayerName())
  nameText:SetTextColor(cr, cg, cb, 1)

  local title = PlayerTitle()
  if title then
    titleText:SetText(title)
    titleText:Show()
    classIcon:ClearAllPoints()
    classIcon:SetPoint("TOP", titleText, "BOTTOM", 0, -18)
  else
    titleText:SetText("")
    titleText:Hide()
    classIcon:ClearAllPoints()
    classIcon:SetPoint("TOP", nameText, "BOTTOM", 0, -18)
  end

  levelText:SetText("Lv " .. tostring(UnitLevel("player") or "?"))
  classText:SetText(localized)
  classText:SetTextColor(cr, cg, cb, 1)
  ApplyClassIcon(classFile)

  local iconPath = RakaMod.Media and RakaMod.Media.IconPath
  if iconPath then
    logo:SetTexture(iconPath)
  end

  timerText:SetText(RakaMod.Logic.FormatClock(0))
  FillChangelog()
  PoseModel()
  ArmInputWatch()

  CancelHandle(ticker)
  ticker = C_Timer.NewTicker(0.25, function()
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

function AFK:Leave(fromKey)
  if not active then
    RestoreParent()
    return
  end

  CancelHandle(ticker)
  ticker = nil
  CancelHandle(modelTimer)
  modelTimer = nil
  inputArmed = false
  lastCursorX, lastCursorY = nil, nil

  if model then
    model:SetScript("OnAnimFinished", nil)
  end

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

-------------------------------------------------------------------------------
-- Frames (ToxiUI-style: left changelog, center brand, right model)
-------------------------------------------------------------------------------

frame = CreateFrame("Frame", "RakaModAFK", WorldFrame)
frame:SetAllPoints(WorldFrame)
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetFrameLevel(100)
frame:EnableMouse(true)
frame:EnableKeyboard(true)
frame:Hide()

local shade = frame:CreateTexture(nil, "BACKGROUND")
shade:SetAllPoints()
shade:SetColorTexture(0, 0, 0, 0.72)

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

frame:SetScript("OnMouseDown", function()
  if active then
    AFK:Leave(true)
  end
end)

frame:SetScript("OnUpdate", function()
  if not active or not inputArmed then
    return
  end
  local x, y = GetCursorPosition()
  if lastCursorX and lastCursorY then
    if math.abs(x - lastCursorX) > 4 or math.abs(y - lastCursorY) > 4 then
      AFK:Leave(true)
      return
    end
  end
  lastCursorX, lastCursorY = x, y
end)

logo = frame:CreateTexture(nil, "ARTWORK")
logo:SetSize(112, 112)
logo:SetPoint("TOP", frame, "TOP", 0, -96)
do
  local path = RakaMod.Media and RakaMod.Media.IconPath
  if path then
    logo:SetTexture(path)
  end
end

timerText = frame:CreateFontString(nil, "OVERLAY")
timerText:SetPoint("TOP", logo, "BOTTOM", 0, -18)
timerText:SetJustifyH("CENTER")
Paint(timerText, 36, TIMER_CYAN.r, TIMER_CYAN.g, TIMER_CYAN.b)

nameText = frame:CreateFontString(nil, "OVERLAY")
nameText:SetPoint("TOP", timerText, "BOTTOM", 0, -22)
nameText:SetJustifyH("CENTER")
Paint(nameText, 28, 1, 1, 1)

titleText = frame:CreateFontString(nil, "OVERLAY")
titleText:SetPoint("TOP", nameText, "BOTTOM", 0, -6)
titleText:SetJustifyH("CENTER")
Paint(titleText, 16, 0.85, 0.85, 0.85)
titleText:Hide()

classIcon = frame:CreateTexture(nil, "ARTWORK")
classIcon:SetSize(22, 22)
classIcon:SetPoint("TOP", nameText, "BOTTOM", 0, -18)
classIcon:Hide()

levelText = frame:CreateFontString(nil, "OVERLAY")
levelText:SetPoint("RIGHT", classIcon, "LEFT", -6, 0)
levelText:SetJustifyH("RIGHT")
Paint(levelText, 18, 1, 1, 1)

classText = frame:CreateFontString(nil, "OVERLAY")
classText:SetPoint("LEFT", classIcon, "RIGHT", 6, 0)
classText:SetJustifyH("LEFT")
Paint(classText, 18, 1, 1, 1)

changelogHeader = frame:CreateFontString(nil, "OVERLAY")
changelogHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 48, -100)
changelogHeader:SetJustifyH("LEFT")
changelogHeader:SetWidth(460)
Paint(changelogHeader, 20, 1, 1, 1, 0.9)

changelogBody = frame:CreateFontString(nil, "OVERLAY")
changelogBody:SetPoint("TOPLEFT", changelogHeader, "BOTTOMLEFT", 0, -14)
changelogBody:SetJustifyH("LEFT")
changelogBody:SetJustifyV("TOP")
changelogBody:SetWidth(460)
changelogBody:SetWordWrap(true)
Paint(changelogBody, 13, 1, 1, 1, 0.82)

model = CreateFrame("PlayerModel", nil, frame)
model:SetSize(560, 680)
model:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 36)
model:SetFrameLevel(frame:GetFrameLevel() + 1)
model:Hide()

footerText = frame:CreateFontString(nil, "OVERLAY")
footerText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 22)
footerText:SetJustifyH("CENTER")
Paint(footerText, 12, 1, 1, 1, 0.45)
footerText:SetText("Press any key or move the mouse to dismiss  ·  RakaMod")

chat = CreateFrame("ScrollingMessageFrame", nil, frame)
chat:SetSize(420, 160)
chat:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 48, 48)
chat:SetFrameLevel(frame:GetFrameLevel() + 2)
chat:SetJustifyH("LEFT")
chat:SetFading(false)
chat:SetMaxLines(CHAT_LIMIT)
chat:EnableMouse(true)
chat:EnableMouseWheel(true)
do
  local path = RakaMod.Media and RakaMod.Media.FontPath
  if path then
    pcall(chat.SetFont, chat, path, 13, "OUTLINE")
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
