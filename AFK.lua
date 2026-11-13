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
local changelogPanel
local changelogPool = {}
local changelogWidth = 300
local footerText
local chat
local events
local Consider

-- Ellesmere WhatsNew palette (compact AFK clone).
local CL_ORANGE = { r = 0.863, g = 0.655, b = 0.498 }
local CL_GREEN = { r = 0.25, g = 0.72, b = 0.42 }
local CL_SECTION = { r = 0.62, g = 0.62, b = 0.62 }
local CL_TITLE = { r = 0.92, g = 0.92, b = 0.92 }
local CL_DESC = { r = 0.50, g = 0.50, b = 0.50 }
local CL_MUTED = { r = 0.55, g = 0.55, b = 0.55 }

local function CancelHandle(handle)
  if handle and handle.Cancel then
    pcall(handle.Cancel, handle)
  end
end

-- Always assign a font before any SetText (BugGrabber: "Font not set").
local function EnsureFont(fs, size, flags)
  if not fs then
    return
  end
  local path = RakaMod.Media and RakaMod.Media.FontPath
  if path and type(size) == "number" then
    local ok = pcall(fs.SetFont, fs, path, size, flags or "OUTLINE")
    if ok then
      return
    end
  end
  if GameFontNormal and fs.SetFontObject then
    if pcall(fs.SetFontObject, fs, GameFontNormal) then
      return
    end
  end
  if GameFontNormal and GameFontNormal.GetFont then
    local gPath, gSize = GameFontNormal:GetFont()
    if gPath then
      pcall(fs.SetFont, fs, gPath, size or gSize or 12, flags or "")
    end
  end
end

local function Paint(fs, size, r, g, b, a)
  EnsureFont(fs, size, "OUTLINE")
  fs:SetTextColor(r, g, b, a or 1)
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 1)
end

-- Tiny UI text (~8–9px). Avoid GameFontNormalSmall — still too large on Forever.
local SMALL_UI_SIZE = 8
local function PaintSmall(fs, r, g, b, a)
  local path
  if GameFontNormal and GameFontNormal.GetFont then
    path = GameFontNormal:GetFont()
  end
  if path then
    pcall(fs.SetFont, fs, path, SMALL_UI_SIZE, "")
  else
    EnsureFont(fs, SMALL_UI_SIZE, "")
  end
  fs:SetTextColor(r, g, b, a or 1)
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 1)
end

-- Drop the 3D figure so feet sit near the bottom of the model frame / screen.
local function PoseModelCamera()
  if not model then
    return
  end
  pcall(model.SetPortraitZoom, model, 0)
  -- Lower cam distance = larger character.
  pcall(model.SetCamDistanceScale, model, 2.1)
  -- z negative moves the unit down in the model viewport (feet toward bottom).
  pcall(model.SetPosition, model, 0, 0, -1.15)
  pcall(model.SetFacing, model, 0.2)
end

local function ScreenSize()
  -- Prefer the AFK frame / WorldFrame size (UIParent is hidden while AFK).
  local w, h = 0, 0
  if frame and frame.GetWidth then
    w = frame:GetWidth() or 0
    h = frame:GetHeight() or 0
  end
  if (not w or w <= 0) and type(GetScreenWidth) == "function" then
    w = GetScreenWidth() or 0
  end
  if (not h or h <= 0) and type(GetScreenHeight) == "function" then
    h = GetScreenHeight() or 0
  end
  if (not w or w <= 0) and UIParent and UIParent.GetWidth then
    w = UIParent:GetWidth() or 0
  end
  if (not h or h <= 0) and UIParent and UIParent.GetHeight then
    h = UIParent:GetHeight() or 0
  end
  if not w or w <= 0 then
    w = 1920
  end
  if not h or h <= 0 then
    h = 1080
  end
  return w, h
end

local function ApplyLayout()
  if not frame or not logo then
    return
  end
  local w, h = ScreenSize()
  local s = RakaMod.Logic.AfkLayoutScale(w, h)
  local pad = math.floor(24 * s + 0.5)
  local logoSize = math.floor(72 * s + 0.5)
  local logoTop = math.floor(52 * s + 0.5)
  local gapLogo = -math.floor(12 * s + 0.5)
  local gapTimer = -math.floor(14 * s + 0.5)
  local gapName = -math.floor(4 * s + 0.5)
  local classPx = math.floor(16 * s + 0.5)
  -- Changelog column: top-left, modest width so it stays left of center brand.
  local changelogW = math.min(math.floor(w * 0.24 + 0.5), math.floor(320 * s + 0.5))
  if changelogW < 200 then
    changelogW = 200
  end
  local changelogTop = math.floor(36 * s + 0.5)
  local changelogLeft = math.floor(20 * s + 0.5)
  -- Model: large frame flush to screen bottom-right; camera drops feet to the edge.
  local modelW = math.floor(math.min(w * 0.46, 640 * s) + 0.5)
  local modelH = math.floor(math.min(h * 0.88, 900 * s) + 0.5)
  local modelPad = 0
  local chatW = math.floor(math.min(w * 0.24, 300 * s) + 0.5)
  local chatH = math.floor(110 * s + 0.5)
  local timerSize = math.max(18, math.floor(26 * s + 0.5))
  local nameSize = math.max(16, math.floor(20 * s + 0.5))
  local titleSize = math.max(12, math.floor(13 * s + 0.5))
  local levelSize = math.max(12, math.floor(13 * s + 0.5))
  local footerPad = math.floor(10 * s + 0.5)

  logo:SetSize(logoSize, logoSize)
  logo:ClearAllPoints()
  logo:SetPoint("TOP", frame, "TOP", 0, -logoTop)

  timerText:ClearAllPoints()
  timerText:SetPoint("TOP", logo, "BOTTOM", 0, gapLogo)
  Paint(timerText, timerSize, TIMER_CYAN.r, TIMER_CYAN.g, TIMER_CYAN.b)

  nameText:ClearAllPoints()
  nameText:SetPoint("TOP", timerText, "BOTTOM", 0, gapTimer)
  EnsureFont(nameText, nameSize, "OUTLINE")

  titleText:ClearAllPoints()
  titleText:SetPoint("TOP", nameText, "BOTTOM", 0, gapName)
  Paint(titleText, titleSize, 0.85, 0.85, 0.85)

  classIcon:SetSize(classPx, classPx)
  classIcon:ClearAllPoints()
  if titleText:IsShown() then
    classIcon:SetPoint("TOP", titleText, "BOTTOM", 0, -math.floor(12 * s + 0.5))
  else
    classIcon:SetPoint("TOP", nameText, "BOTTOM", 0, -math.floor(12 * s + 0.5))
  end
  levelText:ClearAllPoints()
  levelText:SetPoint("RIGHT", classIcon, "LEFT", -math.floor(4 * s + 0.5), 0)
  Paint(levelText, levelSize, 1, 1, 1)
  classText:ClearAllPoints()
  classText:SetPoint("LEFT", classIcon, "RIGHT", math.floor(4 * s + 0.5), 0)
  EnsureFont(classText, levelSize, "OUTLINE")

  changelogWidth = changelogW
  if changelogPanel then
    changelogPanel:ClearAllPoints()
    changelogPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", changelogLeft, -changelogTop)
    changelogPanel:SetWidth(changelogW)
  end

  model:SetSize(modelW, modelH)
  model:ClearAllPoints()
  model:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -modelPad, modelPad)
  PoseModelCamera()

  footerText:ClearAllPoints()
  footerText:SetPoint("BOTTOM", frame, "BOTTOM", 0, footerPad)
  PaintSmall(footerText, 1, 1, 1, 0.45)

  chat:SetSize(chatW, chatH)
  chat:ClearAllPoints()
  chat:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pad, pad)
  do
    local path, size
    if GameFontNormal and GameFontNormal.GetFont then
      path, size = GameFontNormal:GetFont()
    end
    if path and size then
      pcall(chat.SetFont, chat, path, size, "")
    elseif RakaMod.Media and RakaMod.Media.FontPath then
      pcall(chat.SetFont, chat, RakaMod.Media.FontPath, 12, "OUTLINE")
    end
  end
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

local function ChangelogFont(fs, size, r, g, b, a)
  EnsureFont(fs, size, "")
  fs:SetTextColor(r, g, b, a or 1)
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 1)
end

local function HideChangelogPool()
  for i = 1, #changelogPool do
    changelogPool[i]:Hide()
  end
end

local function AcquireChangelogPiece(kind)
  for i = 1, #changelogPool do
    local piece = changelogPool[i]
    if not piece:IsShown() and piece._kind == kind then
      piece:Show()
      return piece
    end
  end
  local piece = CreateFrame("Frame", nil, changelogPanel)
  piece._kind = kind
  piece:SetFrameLevel(changelogPanel:GetFrameLevel() + 1)
  if kind == "header" then
    piece.version = piece:CreateFontString(nil, "OVERLAY")
    piece.version:SetJustifyH("LEFT")
    piece.date = piece:CreateFontString(nil, "OVERLAY")
    piece.date:SetJustifyH("LEFT")
    piece.badge = CreateFrame("Frame", nil, piece)
    piece.badgeBg = piece.badge:CreateTexture(nil, "BACKGROUND")
    piece.badgeBg:SetAllPoints()
    piece.badgeBg:SetColorTexture(CL_GREEN.r, CL_GREEN.g, CL_GREEN.b, 0.85)
    piece.badgeText = piece.badge:CreateFontString(nil, "OVERLAY")
    piece.badgeText:SetJustifyH("CENTER")
    piece.badgeText:SetPoint("CENTER", piece.badge, "CENTER", 0, 0)
  elseif kind == "section" then
    piece.icon = piece:CreateFontString(nil, "OVERLAY")
    piece.icon:SetJustifyH("LEFT")
    piece.label = piece:CreateFontString(nil, "OVERLAY")
    piece.label:SetJustifyH("LEFT")
    piece.rule = piece:CreateTexture(nil, "ARTWORK")
    piece.rule:SetColorTexture(1, 1, 1, 0.08)
  elseif kind == "row" then
    piece.primary = piece:CreateFontString(nil, "OVERLAY")
    piece.primary:SetJustifyH("LEFT")
    piece.secondary = piece:CreateFontString(nil, "OVERLAY")
    piece.secondary:SetJustifyH("LEFT")
    piece.title = piece:CreateFontString(nil, "OVERLAY")
    piece.title:SetJustifyH("LEFT")
    piece.title:SetWordWrap(false)
    piece.desc = piece:CreateFontString(nil, "OVERLAY")
    piece.desc:SetJustifyH("LEFT")
    piece.desc:SetWordWrap(true)
    piece.rule = piece:CreateTexture(nil, "ARTWORK")
    piece.rule:SetColorTexture(1, 1, 1, 0.07)
  elseif kind == "fallback" then
    piece.text = piece:CreateFontString(nil, "OVERLAY")
    piece.text:SetJustifyH("LEFT")
    piece.text:SetWordWrap(true)
  end
  changelogPool[#changelogPool + 1] = piece
  piece:Show()
  return piece
end

local function PlaceChangelogHeader(y, view, width)
  local piece = AcquireChangelogPiece("header")
  piece:ClearAllPoints()
  piece:SetPoint("TOPLEFT", changelogPanel, "TOPLEFT", 0, -y)
  piece:SetSize(width, 16)
  ChangelogFont(piece.version, 11, CL_TITLE.r, CL_TITLE.g, CL_TITLE.b, 1)
  piece.version:ClearAllPoints()
  piece.version:SetPoint("LEFT", piece, "LEFT", 0, 0)
  piece.version:SetText(view.version or "")

  local x = (piece.version:GetStringWidth() or 40) + 8
  if view.date and view.date ~= "" then
    ChangelogFont(piece.date, 8, CL_MUTED.r, CL_MUTED.g, CL_MUTED.b, 1)
    piece.date:ClearAllPoints()
    piece.date:SetPoint("LEFT", piece, "LEFT", x, 0)
    piece.date:SetText(view.date)
    piece.date:Show()
    x = x + (piece.date:GetStringWidth() or 0) + 8
  else
    piece.date:Hide()
  end

  ChangelogFont(piece.badgeText, 7, 1, 1, 1, 1)
  piece.badgeText:SetText("LATEST")
  local bw = math.max(36, (piece.badgeText:GetStringWidth() or 28) + 10)
  piece.badge:ClearAllPoints()
  piece.badge:SetPoint("LEFT", piece, "LEFT", x, 0)
  piece.badge:SetSize(bw, 12)
  piece.badge:Show()
  return y + 18
end

local function PlaceChangelogSection(y, width, iconText, label)
  local piece = AcquireChangelogPiece("section")
  piece:ClearAllPoints()
  piece:SetPoint("TOPLEFT", changelogPanel, "TOPLEFT", 0, -y)
  piece:SetSize(width, 18)
  ChangelogFont(piece.icon, 8, CL_SECTION.r, CL_SECTION.g, CL_SECTION.b, 1)
  piece.icon:ClearAllPoints()
  piece.icon:SetPoint("TOPLEFT", piece, "TOPLEFT", 0, -2)
  piece.icon:SetText(iconText)
  ChangelogFont(piece.label, 8, CL_SECTION.r, CL_SECTION.g, CL_SECTION.b, 1)
  piece.label:ClearAllPoints()
  piece.label:SetPoint("LEFT", piece.icon, "RIGHT", 4, 0)
  piece.label:SetText(label)
  piece.rule:ClearAllPoints()
  piece.rule:SetPoint("BOTTOMLEFT", piece, "BOTTOMLEFT", 0, 0)
  piece.rule:SetSize(width, 1)
  return y + 20
end

local function PlaceChangelogRow(y, width, primary, secondary, title, desc)
  local tagW = math.floor(width * 0.28 + 0.5)
  if tagW < 70 then
    tagW = 70
  end
  local rightW = width - tagW - 8
  local piece = AcquireChangelogPiece("row")
  piece:ClearAllPoints()
  piece:SetPoint("TOPLEFT", changelogPanel, "TOPLEFT", 0, -y)

  ChangelogFont(piece.primary, 7, CL_ORANGE.r, CL_ORANGE.g, CL_ORANGE.b, 1)
  piece.primary:ClearAllPoints()
  piece.primary:SetPoint("TOPLEFT", piece, "TOPLEFT", 0, -2)
  piece.primary:SetWidth(tagW)
  piece.primary:SetText(primary or "")

  local tagH = 10
  if secondary and secondary ~= "" then
    ChangelogFont(piece.secondary, 6, CL_MUTED.r, CL_MUTED.g, CL_MUTED.b, 1)
    piece.secondary:ClearAllPoints()
    piece.secondary:SetPoint("TOPLEFT", piece.primary, "BOTTOMLEFT", 0, -1)
    piece.secondary:SetWidth(tagW)
    piece.secondary:SetText(secondary)
    piece.secondary:Show()
    tagH = 18
  else
    piece.secondary:Hide()
  end

  ChangelogFont(piece.title, 8, CL_TITLE.r, CL_TITLE.g, CL_TITLE.b, 1)
  piece.title:ClearAllPoints()
  piece.title:SetPoint("TOPLEFT", piece, "TOPLEFT", tagW + 8, -2)
  piece.title:SetWidth(rightW)
  piece.title:SetText(title or "")

  local bodyH = 10
  if desc and desc ~= "" then
    ChangelogFont(piece.desc, 7, CL_DESC.r, CL_DESC.g, CL_DESC.b, 1)
    piece.desc:ClearAllPoints()
    piece.desc:SetPoint("TOPLEFT", piece.title, "BOTTOMLEFT", 0, -2)
    piece.desc:SetWidth(rightW)
    piece.desc:SetText(desc)
    piece.desc:Show()
    bodyH = 10 + math.max(10, math.ceil(piece.desc:GetStringHeight() or 10))
  else
    piece.desc:Hide()
  end

  local rowH = math.max(tagH, bodyH) + 6
  piece:SetSize(width, rowH)
  piece.rule:ClearAllPoints()
  piece.rule:SetPoint("BOTTOMLEFT", piece, "BOTTOMLEFT", 0, 0)
  piece.rule:SetSize(width, 1)
  return y + rowH
end

local function PlaceChangelogFallback(y, width, text)
  local piece = AcquireChangelogPiece("fallback")
  piece:ClearAllPoints()
  piece:SetPoint("TOPLEFT", changelogPanel, "TOPLEFT", 0, -y)
  piece:SetWidth(width)
  ChangelogFont(piece.text, 8, CL_MUTED.r, CL_MUTED.g, CL_MUTED.b, 1)
  piece.text:ClearAllPoints()
  piece.text:SetPoint("TOPLEFT", piece, "TOPLEFT", 0, 0)
  piece.text:SetWidth(width)
  piece.text:SetText(text)
  local h = math.max(14, math.ceil(piece.text:GetStringHeight() or 14))
  piece:SetHeight(h)
  return y + h
end

local function FillChangelog()
  if not changelogPanel then
    return
  end
  HideChangelogPool()
  local width = changelogWidth or 300
  local patches = EllesmerePatches()
  local isForever = RakaMod.Core and RakaMod.Core:IsForever() or false
  local view = RakaMod.Logic.BuildEllesmereChangelogView(patches, isForever, 6, 5)
  local y = 0
  if view then
    y = PlaceChangelogHeader(y, view, width)
    if #view.features > 0 then
      y = PlaceChangelogSection(y, width, "+", "SMALL FEATURES")
      for i = 1, #view.features do
        local f = view.features[i]
        y = PlaceChangelogRow(y, width, f.primary, f.secondary, f.title, f.desc)
      end
    end
    if #view.fixes > 0 then
      y = PlaceChangelogSection(y, width, "#", "BUGFIXES")
      for i = 1, #view.fixes do
        local fx = view.fixes[i]
        y = PlaceChangelogRow(y, width, fx.primary, fx.secondary, fx.text, nil)
      end
    end
    if #view.features == 0 and #view.fixes == 0 then
      y = PlaceChangelogFallback(y, width, "No entries for this client.")
    end
  else
    local msg = type(EllesmereUI) ~= "table"
      and "EllesmereUI changelog unavailable — EllesmereUI is not loaded."
      or "EllesmereUI changelog unavailable — could not read patch notes."
    y = PlaceChangelogFallback(y, width, msg)
  end
  changelogPanel:SetHeight(math.max(20, y))
  changelogPanel:Show()
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
  PoseModelCamera()
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

  ApplyLayout()

  local localized, classFile = ClassInfo()
  local cr, cg, cb = ClassColor(classFile)
  nameText:SetText(PlayerName())
  nameText:SetTextColor(cr, cg, cb, 1)

  local sw, sh = ScreenSize()
  local s = RakaMod.Logic.AfkLayoutScale(sw, sh)
  local gapClass = -math.floor(12 * s + 0.5)

  local title = PlayerTitle()
  if title then
    titleText:SetText(title)
    titleText:Show()
    classIcon:ClearAllPoints()
    classIcon:SetPoint("TOP", titleText, "BOTTOM", 0, gapClass)
  else
    titleText:SetText("")
    titleText:Hide()
    classIcon:ClearAllPoints()
    classIcon:SetPoint("TOP", nameText, "BOTTOM", 0, gapClass)
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
logo:SetPoint("TOP", frame, "TOP", 0, -52)
do
  local path = RakaMod.Media and RakaMod.Media.IconPath
  if path then
    logo:SetTexture(path)
  end
end

timerText = frame:CreateFontString(nil, "OVERLAY")
timerText:SetJustifyH("CENTER")
EnsureFont(timerText, 26, "OUTLINE")

nameText = frame:CreateFontString(nil, "OVERLAY")
nameText:SetJustifyH("CENTER")
EnsureFont(nameText, 20, "OUTLINE")

titleText = frame:CreateFontString(nil, "OVERLAY")
titleText:SetJustifyH("CENTER")
EnsureFont(titleText, 13, "OUTLINE")
titleText:Hide()

classIcon = frame:CreateTexture(nil, "ARTWORK")
classIcon:Hide()

levelText = frame:CreateFontString(nil, "OVERLAY")
levelText:SetJustifyH("RIGHT")
EnsureFont(levelText, 13, "OUTLINE")

classText = frame:CreateFontString(nil, "OVERLAY")
classText:SetJustifyH("LEFT")
EnsureFont(classText, 13, "OUTLINE")

changelogPanel = CreateFrame("Frame", nil, frame)
changelogPanel:SetSize(300, 200)
changelogPanel:SetFrameLevel(frame:GetFrameLevel() + 2)

model = CreateFrame("PlayerModel", nil, frame)
model:SetFrameLevel(frame:GetFrameLevel() + 1)
model:Hide()

footerText = frame:CreateFontString(nil, "OVERLAY")
footerText:SetJustifyH("CENTER")
EnsureFont(footerText, SMALL_UI_SIZE, "")
footerText:SetText("Press any key or move the mouse to dismiss  ·  RakaMod")

chat = CreateFrame("ScrollingMessageFrame", nil, frame)
chat:SetFrameLevel(frame:GetFrameLevel() + 2)
chat:SetJustifyH("LEFT")
chat:SetFading(false)
chat:SetMaxLines(CHAT_LIMIT)
chat:EnableMouse(true)
chat:EnableMouseWheel(true)
pcall(chat.SetShadowOffset, chat, 1, -1)
pcall(chat.SetShadowColor, chat, 0, 0, 0, 1)

ApplyLayout()
frame:SetScript("OnSizeChanged", function()
  ApplyLayout()
end)
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
