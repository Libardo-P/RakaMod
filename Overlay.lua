RakaMod = RakaMod or {}

local Overlay = {}
RakaMod.Overlay = Overlay

local CLASS_ORDER = {
  "WARRIOR",
  "PALADIN",
  "HUNTER",
  "ROGUE",
  "PRIEST",
  "DEATHKNIGHT",
  "SHAMAN",
  "MAGE",
  "WARLOCK",
  "MONK",
  "DRUID",
  "DEMONHUNTER",
  "EVOKER",
}

local ROW_COUNT = 6
local BAR_COUNT = 13
local PANEL_WIDTH = 300
local BAR_WIDTH = 260
local PAD_X = 20
local SECTION_GAP = 24
local HEADER_STEP = 22
local ROW_STEP = 20
local BAR_STEP = 20
local HEADER_BLUE = { r = 0.20, g = 0.55, b = 1.00 }
local ROW_TEXT = { r = 0.90, g = 0.92, b = 0.95 }

local dim
local shade
local grain
local panel
local events
local menuShowHooked = false
local menuHideHooked = false
local savedStrata
local savedLevel
local collections
local playedBlock
local professions

local function SectionOn(key)
  local overlay = RakaMod.db and RakaMod.db.overlay
  return type(overlay) == "table" and overlay[key] ~= false
end

local function OverlayOn()
  local overlay = RakaMod.db and RakaMod.db.overlay
  return type(overlay) == "table" and overlay.enabled == true
end

function Overlay:ApplyDimAlpha()
  if not shade then
    return
  end
  local fade = RakaMod.db and RakaMod.db.features and RakaMod.db.features.backgroundFade
  shade:SetColorTexture(0, 0, 0, RakaMod.Logic.FadeShadeAlpha(fade))
  if grain and RakaMod.Media and RakaMod.Media.ApplyFadeGrain then
    RakaMod.Media.ApplyFadeGrain(grain, dim)
  end
end

local function HideWidgets(list)
  if not list then
    return
  end
  for i = 1, #list do
    list[i]:Hide()
  end
end

local function ShowRow(row, label, value)
  row.icon:Hide()
  row.label:SetText(label or "")
  row.value:SetText(value or "")
  row:Show()
end

local function CreateHeader(parent, text)
  local header = CreateFrame("Frame", nil, parent)
  header:SetSize(BAR_WIDTH, 18)
  local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, 0)
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  title:SetWidth(BAR_WIDTH)
  title:SetText(string.upper(text))
  title:SetTextColor(HEADER_BLUE.r, HEADER_BLUE.g, HEADER_BLUE.b)
  title:SetShadowOffset(1, -1)
  title:SetShadowColor(0, 0, 0, 1)
  local rule = header:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(HEADER_BLUE.r, HEADER_BLUE.g, HEADER_BLUE.b, 1)
  rule:SetPoint("BOTTOMLEFT", 0, 0)
  rule:SetPoint("BOTTOMRIGHT", 0, 0)
  rule:SetHeight(1)
  header.title = title
  header.rule = rule
  header:Hide()
  return header
end

local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(BAR_WIDTH, 18)
  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(16, 16)
  icon:SetPoint("LEFT", 0, 0)
  icon:Hide()
  local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", 0, 0)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  label:SetWidth(BAR_WIDTH * 0.55)
  label:SetTextColor(ROW_TEXT.r, ROW_TEXT.g, ROW_TEXT.b)
  label:SetShadowOffset(1, -1)
  label:SetShadowColor(0, 0, 0, 1)
  local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  value:SetPoint("RIGHT", 0, 0)
  value:SetJustifyH("RIGHT")
  value:SetWordWrap(false)
  value:SetWidth(BAR_WIDTH * 0.42)
  value:SetTextColor(ROW_TEXT.r, ROW_TEXT.g, ROW_TEXT.b)
  value:SetShadowOffset(1, -1)
  value:SetShadowColor(0, 0, 0, 1)
  row.icon = icon
  row.label = label
  row.value = value
  row:Hide()
  return row
end

local function CreateBar(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(BAR_WIDTH, 18)
  local fill = row:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(1, 1, 1, 0.18)
  local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("LEFT", 6, 0)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  label:SetWidth(BAR_WIDTH * 0.55)
  label:SetTextColor(ROW_TEXT.r, ROW_TEXT.g, ROW_TEXT.b)
  label:SetShadowOffset(1, -1)
  label:SetShadowColor(0, 0, 0, 1)
  local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  value:SetPoint("RIGHT", -6, 0)
  value:SetJustifyH("RIGHT")
  value:SetWordWrap(false)
  value:SetWidth(BAR_WIDTH * 0.40)
  value:SetTextColor(ROW_TEXT.r, ROW_TEXT.g, ROW_TEXT.b)
  value:SetShadowOffset(1, -1)
  value:SetShadowColor(0, 0, 0, 1)
  row.fill = fill
  row.label = label
  row.value = value
  row:Hide()
  return row
end

local function CreateBlock(parent, title)
  local block = { header = CreateHeader(parent, title), rows = {} }
  for i = 1, ROW_COUNT do
    block.rows[i] = CreateRow(parent)
  end
  return block
end

local function CreateFrames()
  dim = CreateFrame("Frame", "RakaModOverlayDim", UIParent)
  dim:SetAllPoints()
  dim:SetFrameStrata("FULLSCREEN_DIALOG")
  dim:SetFrameLevel(1)
  dim:EnableMouse(false)
  shade = dim:CreateTexture(nil, "BACKGROUND")
  shade:SetAllPoints()
  grain = dim:CreateTexture(nil, "BORDER")
  grain:SetAllPoints()
  Overlay:ApplyDimAlpha()
  dim:Hide()

  panel = CreateFrame("Frame", "RakaModOverlayPanel", UIParent)
  panel:SetWidth(PANEL_WIDTH)
  panel:SetHeight(1)
  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:SetFrameLevel(20)
  panel:EnableMouse(false)
  panel:Hide()

  professions = CreateBlock(panel, "Professions")
  collections = CreateBlock(panel, "Collections")
  playedBlock = CreateBlock(panel, "Played")
  playedBlock.bars = {}
  for i = 1, BAR_COUNT do
    playedBlock.bars[i] = CreateBar(panel)
  end
end

local function MountLine()
  if not (C_MountJournal and type(C_MountJournal.GetMountIDs) == "function" and type(C_MountJournal.GetMountInfoByID) == "function") then
    return nil
  end
  local ok, ids = pcall(C_MountJournal.GetMountIDs)
  if not ok or type(ids) ~= "table" then
    return nil
  end
  local collected = 0
  local function collectedFlag(id)
    return select(11, C_MountJournal.GetMountInfoByID(id))
  end
  for i = 1, #ids do
    local infoOk, isCollected = pcall(collectedFlag, ids[i])
    if infoOk and isCollected then
      collected = collected + 1
    end
  end
  return { label = "Mounts", value = string.format("%d/%d", collected, #ids) }
end

local function ToyLine()
  if not (C_ToyBox and type(C_ToyBox.GetNumLearnedToys) == "function" and type(C_ToyBox.GetNumToys) == "function") then
    return nil
  end
  local learnedOk, learned = pcall(C_ToyBox.GetNumLearnedToys)
  local totalOk, total = pcall(C_ToyBox.GetNumToys)
  if not learnedOk or not totalOk or type(learned) ~= "number" or type(total) ~= "number" then
    return nil
  end
  return { label = "Toys", value = string.format("%d/%d", learned, total) }
end

local function PetLine()
  if not (C_PetJournal and type(C_PetJournal.GetNumPets) == "function") then
    return nil
  end
  local ok, numPets, numOwned = pcall(C_PetJournal.GetNumPets)
  if not ok or type(numPets) ~= "number" or type(numOwned) ~= "number" then
    return nil
  end
  return { label = "Pets", value = string.format("%d/%d", numOwned, numPets) }
end

local function PointLine()
  if type(GetTotalAchievementPoints) ~= "function" then
    return nil
  end
  local ok, points = pcall(GetTotalAchievementPoints)
  if not ok or type(points) ~= "number" then
    return nil
  end
  return { label = "Achievement Points", value = tostring(points) }
end

local function FillCollections()
  HideWidgets(collections.rows)
  if not SectionOn("collections") then
    collections.header:Hide()
    return
  end
  local lines = { MountLine(), ToyLine(), PetLine(), PointLine() }
  local count = 0
  for i = 1, #lines do
    local line = lines[i]
    if line and count < #collections.rows then
      count = count + 1
      ShowRow(collections.rows[count], line.label, line.value)
    end
  end
  if count > 0 then
    collections.header:Show()
  else
    collections.header:Hide()
  end
end

local function ClassLabel(classFile)
  local names = LOCALIZED_CLASS_NAMES_MALE
  local pretty = type(names) == "table" and names[classFile] or nil
  if type(pretty) ~= "string" or pretty == "" then
    return classFile
  end
  return pretty
end

local function PlayerClassFile()
  if type(UnitClass) ~= "function" then
    return nil
  end
  local ok, _, classFile = pcall(UnitClass, "player")
  if ok and type(classFile) == "string" then
    return classFile
  end
  return nil
end

local function OrderedClasses(byClass)
  local list = {}
  local seen = {}
  if type(byClass) ~= "table" then
    return list
  end
  for i = 1, #CLASS_ORDER do
    local classFile = CLASS_ORDER[i]
    seen[classFile] = true
    local seconds = byClass[classFile]
    if type(seconds) == "number" and seconds > 0 then
      list[#list + 1] = classFile
    end
  end
  local extras = {}
  for classFile, seconds in pairs(byClass) do
    if not seen[classFile] and type(classFile) == "string" and type(seconds) == "number" and seconds > 0 then
      extras[#extras + 1] = classFile
    end
  end
  table.sort(extras)
  for i = 1, #extras do
    list[#list + 1] = extras[i]
  end
  return list
end

local function FillPlayed()
  HideWidgets(playedBlock.rows)
  HideWidgets(playedBlock.bars)
  if not SectionOn("played") then
    playedBlock.header:Hide()
    return
  end
  local logic = RakaMod.Logic
  local elapsed
  if type(RakaMod.sessionStart) == "number" and type(GetTime) == "function" then
    elapsed = GetTime() - RakaMod.sessionStart
  end
  ShowRow(playedBlock.rows[1], "Session", logic.FormatDuration(elapsed))

  local playedDB = RakaMod.db and RakaMod.db.played
  local seconds
  if type(playedDB) == "table" and type(UnitGUID) == "function" then
    local guid = UnitGUID("player")
    local record = type(guid) == "string" and playedDB[guid] or nil
    if type(record) == "table" then
      seconds = record.totalSeconds
    end
  end
  ShowRow(playedBlock.rows[2], "This Character", logic.FormatDuration(seconds))

  local summary = logic.PlayedSummary(playedDB)
  ShowRow(playedBlock.rows[3], "Account", logic.FormatDuration(summary.account))
  playedBlock.header:Show()

  local playerClass = PlayerClassFile()
  local classes = OrderedClasses(summary.byClass)
  local limit = #classes
  if limit > #playedBlock.bars then
    limit = #playedBlock.bars
  end
  for i = 1, limit do
    local classFile = classes[i]
    local classSeconds = summary.byClass[classFile]
    local bar = playedBlock.bars[i]
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    local r, g, b = 0.55, 0.55, 0.55
    if type(color) == "table" and type(color.r) == "number" then
      r, g, b = color.r, color.g, color.b
    end
    local alpha = (playerClass == classFile) and 0.45 or 0.22
    bar.fill:SetColorTexture(r, g, b, alpha)
    bar.label:SetText(ClassLabel(classFile))
    bar.value:SetText(logic.FormatDuration(classSeconds))
    bar:Show()
  end
end

local function ProfessionLines()
  if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
    return nil
  end
  local ok, first, second, archaeology, fishing, cooking, firstAid = pcall(GetProfessions)
  if not ok then
    return nil
  end
  local slots = { first, second, archaeology, fishing, cooking, firstAid }
  local lines = {}
  for i = 1, #slots do
    local index = slots[i]
    if index ~= nil and #lines < ROW_COUNT then
      local infoOk, name, _, skillLevel, maxSkillLevel = pcall(GetProfessionInfo, index)
      if infoOk and type(name) == "string" and name ~= "" then
        lines[#lines + 1] = {
          label = name,
          value = string.format("%s/%s", tostring(skillLevel), tostring(maxSkillLevel)),
        }
      end
    end
  end
  return lines
end

local function FillProfessions()
  HideWidgets(professions.rows)
  if not SectionOn("professions") then
    professions.header:Hide()
    return
  end
  local lines = ProfessionLines()
  if not lines or #lines == 0 then
    professions.header:Hide()
    return
  end
  for i = 1, #lines do
    ShowRow(professions.rows[i], lines[i].label, lines[i].value)
  end
  professions.header:Show()
end

local function Layout()
  local y = 16
  local visible = 0

  local function place(widget, step)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_X, -y)
    y = y + step
  end

  local function placeBlock(block, includeBars)
    if not block.header:IsShown() then
      return
    end
    if visible > 0 then
      y = y + SECTION_GAP
    end
    visible = visible + 1
    place(block.header, HEADER_STEP)
    y = y + 4
    for i = 1, #block.rows do
      if block.rows[i]:IsShown() then
        place(block.rows[i], ROW_STEP)
      end
    end
    if includeBars then
      for i = 1, #block.bars do
        if block.bars[i]:IsShown() then
          place(block.bars[i], BAR_STEP)
        end
      end
    end
  end

  placeBlock(professions, false)
  placeBlock(collections, false)
  placeBlock(playedBlock, true)
  if visible == 0 then
    panel:SetHeight(1)
  else
    panel:SetHeight(y + 12)
  end
end

local BASE_PAD = 40

local function ScreenSize()
  local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
  local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
  return width, height
end

local function LayoutScale()
  local logic = RakaMod.Logic
  if logic and logic.AfkLayoutScale then
    local width, height = ScreenSize()
    return logic.AfkLayoutScale(width, height)
  end
  return 1
end

local function PlacePanel()
  if not panel then
    return
  end
  -- Top-left of the screen; scale with resolution (same clamp as AFK layout).
  local scale = LayoutScale()
  panel:SetScale(scale)
  local pad = math.floor(BASE_PAD * scale + 0.5)
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pad, -pad)
end

local function RaiseMenu()
  if not GameMenuFrame or savedStrata then
    return
  end
  savedStrata = GameMenuFrame:GetFrameStrata()
  savedLevel = GameMenuFrame:GetFrameLevel()
  pcall(GameMenuFrame.SetFrameStrata, GameMenuFrame, "FULLSCREEN_DIALOG")
  pcall(GameMenuFrame.SetFrameLevel, GameMenuFrame, 100)
end

local function RestoreMenu()
  if not GameMenuFrame or not savedStrata then
    return
  end
  local strata = savedStrata
  local level = savedLevel
  savedStrata = nil
  savedLevel = nil
  pcall(GameMenuFrame.SetFrameStrata, GameMenuFrame, strata)
  if type(level) == "number" then
    pcall(GameMenuFrame.SetFrameLevel, GameMenuFrame, level)
  end
end

local function MaybeRequestPlayed()
  if RakaMod.playedThisSession ~= false then
    return
  end
  RakaMod.Core:RequestPlayed(true)
end

local function StorePlayed(totalSeconds)
  local playedDB = RakaMod.db and RakaMod.db.played
  if type(playedDB) ~= "table" or type(UnitGUID) ~= "function" then
    return
  end
  local guid = UnitGUID("player")
  if type(guid) ~= "string" then
    return
  end
  local _, classFile = UnitClass("player")
  playedDB[guid] = {
    name = UnitName("player"),
    realm = GetRealmName(),
    classFile = classFile,
    totalSeconds = totalSeconds,
    lastUpdated = time(),
  }
  RakaMod.playedThisSession = true
  if panel and panel:IsShown() then
    Overlay:Refresh()
  end
end

function Overlay:Refresh()
  if not panel or not RakaMod.Logic then
    return
  end
  FillProfessions()
  FillCollections()
  FillPlayed()
  Layout()
  PlacePanel()
end

local placeWaiter

local function DeferPlace()
  if not placeWaiter then
    placeWaiter = CreateFrame("Frame")
  end
  placeWaiter:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    if panel and panel:IsShown() and GameMenuFrame then
      PlacePanel()
    end
  end)
end

local function OnMenuShow()
  if not OverlayOn() or not dim or not panel then
    return
  end
  MaybeRequestPlayed()
  Overlay:Refresh()
  Overlay:ApplyDimAlpha()
  dim:Show()
  panel:Show()
  RaiseMenu()
  DeferPlace()
end

local function OnMenuHide()
  if dim then
    dim:Hide()
  end
  if panel then
    panel:Hide()
  end
  RestoreMenu()
end

local function Hook(frame, script, handler)
  if type(frame.HookScript) == "function" then
    frame:HookScript(script, handler)
    return true
  end
  if type(frame.GetScript) ~= "function" or type(frame.SetScript) ~= "function" then
    return false
  end
  local original = frame:GetScript(script)
  frame:SetScript(script, function(...)
    if original then
      original(...)
    end
    handler(...)
  end)
  return true
end

local function TryHookMenu()
  if not GameMenuFrame then
    return
  end
  if not menuShowHooked then
    menuShowHooked = Hook(GameMenuFrame, "OnShow", OnMenuShow)
  end
  if not menuHideHooked then
    menuHideHooked = Hook(GameMenuFrame, "OnHide", OnMenuHide)
  end
  if menuShowHooked and menuHideHooked then
    events:UnregisterEvent("ADDON_LOADED")
    if GameMenuFrame:IsShown() then
      OnMenuShow()
    end
  end
end

function Overlay:Enable()
  if not dim then
    CreateFrames()
  end
  events:RegisterEvent("TIME_PLAYED_MSG")
  events:RegisterEvent("DISPLAY_SIZE_CHANGED")
  events:RegisterEvent("UI_SCALE_CHANGED")
  TryHookMenu()
  if not (menuShowHooked and menuHideHooked) then
    events:RegisterEvent("ADDON_LOADED")
  end
end

function Overlay:Disable()
  events:UnregisterEvent("TIME_PLAYED_MSG")
  events:UnregisterEvent("DISPLAY_SIZE_CHANGED")
  events:UnregisterEvent("UI_SCALE_CHANGED")
  if dim then
    dim:Hide()
  end
  if panel then
    panel:Hide()
  end
  RestoreMenu()
end

events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    TryHookMenu()
  elseif event == "TIME_PLAYED_MSG" then
    StorePlayed(arg1)
  elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
    if dim and dim:IsShown() then
      Overlay:ApplyDimAlpha()
    end
    if panel and panel:IsShown() then
      PlacePanel()
    end
  end
end)

RakaMod.Core:RegisterModule({
  name = "Overlay",
  dbKey = "overlay",
  requires = nil,
  OnLoad = function(self) end,
  OnEnable = function(self) RakaMod.Overlay:Enable() end,
  OnDisable = function(self) RakaMod.Overlay:Disable() end,
})
