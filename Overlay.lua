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

local dim
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

local function HideWidgets(list)
  if not list then
    return
  end
  for i = 1, #list do
    list[i]:Hide()
  end
end

local function ShowPlain(row, value)
  row.icon:Hide()
  row.text:ClearAllPoints()
  row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.text:SetWidth(BAR_WIDTH)
  row.text:SetText(value)
  row:Show()
end

local function ShowIcon(row, texture, value)
  local applied = false
  if texture ~= nil and (type(texture) == "string" or type(texture) == "number") then
    applied = pcall(row.icon.SetTexture, row.icon, texture)
  end
  if applied then
    row.icon:Show()
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetWidth(BAR_WIDTH - 22)
  else
    row.icon:Hide()
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.text:SetWidth(BAR_WIDTH)
  end
  row.text:SetText(value)
  row:Show()
end

local function CreateHeader(parent, text)
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetJustifyH("LEFT")
  header:SetWordWrap(false)
  header:SetWidth(BAR_WIDTH)
  header:SetText(text)
  header:SetShadowOffset(1, -1)
  header:SetShadowColor(0, 0, 0, 1)
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
  local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  text:SetWidth(BAR_WIDTH)
  text:SetShadowOffset(1, -1)
  text:SetShadowColor(0, 0, 0, 1)
  row.icon = icon
  row.text = text
  row:Hide()
  return row
end

local function CreateBar(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(BAR_WIDTH, 16)
  local track = row:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(1, 1, 1, 0.12)
  track:SetPoint("LEFT", 0, 0)
  track:SetSize(BAR_WIDTH, 10)
  local fill = row:CreateTexture(nil, "ARTWORK")
  local path = RakaMod.Media and RakaMod.Media.StatusbarPath
  if path then
    fill:SetTexture(path)
  end
  fill:SetPoint("LEFT", 0, 0)
  fill:SetHeight(10)
  fill:SetWidth(BAR_WIDTH)
  local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("LEFT", row, "LEFT", 4, 0)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  text:SetWidth(BAR_WIDTH - 8)
  text:SetShadowOffset(1, -1)
  text:SetShadowColor(0, 0, 0, 1)
  row.fill = fill
  row.text = text
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
  local shade = dim:CreateTexture(nil, "BACKGROUND")
  shade:SetAllPoints()
  shade:SetColorTexture(0, 0, 0, 0.45)
  dim:Hide()

  panel = CreateFrame("Frame", "RakaModOverlayPanel", UIParent)
  panel:SetWidth(PANEL_WIDTH)
  panel:SetHeight(1)
  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:SetFrameLevel(20)
  panel:EnableMouse(false)
  panel:Hide()

  collections = CreateBlock(panel, "Collections")
  playedBlock = CreateBlock(panel, "Played")
  playedBlock.bars = {}
  for i = 1, BAR_COUNT do
    playedBlock.bars[i] = CreateBar(panel)
  end
  professions = CreateBlock(panel, "Professions")
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
  return string.format("Mounts %d/%d", collected, #ids)
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
  return string.format("Toys %d/%d", learned, total)
end

local function PetLine()
  if not (C_PetJournal and type(C_PetJournal.GetNumPets) == "function") then
    return nil
  end
  local ok, numPets, numOwned = pcall(C_PetJournal.GetNumPets)
  if not ok or type(numPets) ~= "number" or type(numOwned) ~= "number" then
    return nil
  end
  return string.format("Pets %d/%d", numOwned, numPets)
end

local function PointLine()
  if type(GetTotalAchievementPoints) ~= "function" then
    return nil
  end
  local ok, points = pcall(GetTotalAchievementPoints)
  if not ok or type(points) ~= "number" then
    return nil
  end
  return string.format("Achievement Points %d", points)
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
    if lines[i] and count < #collections.rows then
      count = count + 1
      ShowPlain(collections.rows[count], lines[i])
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
  ShowPlain(playedBlock.rows[1], "Session " .. logic.FormatDuration(elapsed))

  local playedDB = RakaMod.db and RakaMod.db.played
  local seconds
  if type(playedDB) == "table" and type(UnitGUID) == "function" then
    local guid = UnitGUID("player")
    local record = type(guid) == "string" and playedDB[guid] or nil
    if type(record) == "table" then
      seconds = record.totalSeconds
    end
  end
  ShowPlain(playedBlock.rows[2], "Character " .. logic.FormatDuration(seconds))

  local summary = logic.PlayedSummary(playedDB)
  ShowPlain(playedBlock.rows[3], "Account " .. logic.FormatDuration(summary.account))
  playedBlock.header:Show()

  local classes = OrderedClasses(summary.byClass)
  local limit = #classes
  if limit > #playedBlock.bars then
    limit = #playedBlock.bars
  end
  for i = 1, limit do
    local classFile = classes[i]
    local classSeconds = summary.byClass[classFile]
    local bar = playedBlock.bars[i]
    local fraction = logic.ClassFraction(classSeconds, summary.account)
    bar.fill:SetWidth(260 * fraction)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if type(color) == "table" and type(color.r) == "number" and type(color.g) == "number" and type(color.b) == "number" then
      bar.fill:SetVertexColor(color.r, color.g, color.b)
    else
      bar.fill:SetVertexColor(1, 1, 1)
    end
    bar.text:SetText(ClassLabel(classFile) .. " " .. logic.FormatDuration(classSeconds))
    bar:Show()
  end
end

local function ProfessionIcon(name)
  if not (RakaMod.Core and RakaMod.Core.AddonLoaded and RakaMod.Core:AddonLoaded("EllesmereUIDataBars")) then
    return nil
  end
  local globalIcons = _G.EllesmereUIDataBars_ProfessionIcons
  if type(globalIcons) == "table" and globalIcons[name] ~= nil then
    return globalIcons[name]
  end
  if type(EllesmereUIDataBars) == "table" and type(EllesmereUIDataBars.ProfessionIcons) == "table" then
    local icon = EllesmereUIDataBars.ProfessionIcons[name]
    if icon ~= nil then
      return icon
    end
  end
  return nil
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
      local infoOk, name, icon, skillLevel, maxSkillLevel = pcall(GetProfessionInfo, index)
      if infoOk and type(name) == "string" and name ~= "" then
        local override = ProfessionIcon(name)
        local texture = override
        if type(texture) ~= "string" and type(texture) ~= "number" then
          texture = icon
        end
        lines[#lines + 1] = {
          text = string.format("%s %s/%s", name, tostring(skillLevel), tostring(maxSkillLevel)),
          texture = texture,
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
    ShowIcon(professions.rows[i], lines[i].texture, lines[i].text)
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
      y = y + 12
    end
    visible = visible + 1
    place(block.header, 20)
    for i = 1, #block.rows do
      if block.rows[i]:IsShown() then
        place(block.rows[i], 18)
      end
    end
    if includeBars then
      for i = 1, #block.bars do
        if block.bars[i]:IsShown() then
          place(block.bars[i], 16)
        end
      end
    end
  end

  placeBlock(collections, false)
  placeBlock(playedBlock, true)
  placeBlock(professions, false)
  if visible == 0 then
    panel:SetHeight(1)
  else
    panel:SetHeight(y + 12)
  end
end

local function PlacePanel()
  if not GameMenuFrame then
    return
  end
  local side = RakaMod.Logic.AnchorSide(GameMenuFrame:GetLeft() or 0, 300, 12)
  panel:ClearAllPoints()
  if side == "LEFT" then
    panel:SetPoint("RIGHT", GameMenuFrame, "LEFT", -12, 0)
  else
    panel:SetPoint("LEFT", GameMenuFrame, "RIGHT", 12, 0)
  end
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
  if type(RequestTimePlayed) ~= "function" or type(GetTime) ~= "function" then
    return
  end
  local now = GetTime()
  if not RakaMod.Core:CanRequestPlayed(now) then
    return
  end
  if pcall(RequestTimePlayed) then
    RakaMod.Core:NotePlayedRequest(now)
  end
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
  FillCollections()
  FillPlayed()
  FillProfessions()
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
  TryHookMenu()
  if not (menuShowHooked and menuHideHooked) then
    events:RegisterEvent("ADDON_LOADED")
  end
end

function Overlay:Disable()
  events:UnregisterEvent("TIME_PLAYED_MSG")
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
