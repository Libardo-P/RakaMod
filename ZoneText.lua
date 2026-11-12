RakaMod = RakaMod or {}

local ZoneText = {}
RakaMod.ZoneText = ZoneText

local STRINGS = {
  "ZoneTextString",
  "SubZoneTextString",
  "PVPInfoTextString",
  "PvPObjectiveTextString",
}

local events

function ZoneText:Apply()
  if RakaMod.db.zoneText.enabled ~= true then
    return
  end
  local db = RakaMod.db and RakaMod.db.zoneText
  if type(db) ~= "table" then
    return
  end
  local font = RakaMod.Media and RakaMod.Media.FontPath
  local outline = db.outline
  if outline == "NONE" or outline == nil then
    outline = ""
  end
  for i = 1, #STRINGS do
    local fontString = _G[STRINGS[i]]
    if fontString then
      pcall(fontString.SetFont, fontString, font, db.size, outline)
      pcall(fontString.SetTextColor, fontString, db.r, db.g, db.b)
    end
  end
end

function ZoneText:Enable()
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  self:Apply()
end

function ZoneText:Disable()
  events:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
end

events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
  if event == "ZONE_CHANGED_NEW_AREA" then
    ZoneText:Apply()
  end
end)

RakaMod.Core:RegisterModule({
  name = "ZoneText",
  dbKey = "zoneText",
  requires = nil,
  OnLoad = function(self) end,
  OnEnable = function(self) RakaMod.ZoneText:Enable() end,
  OnDisable = function(self) RakaMod.ZoneText:Disable() end,
})
