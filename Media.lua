RakaMod = RakaMod or {}
RakaMod.Media = {
  FontPath = "Interface\\AddOns\\RakaMod\\Media\\RakaMod.ttf",
  StatusbarPath = "Interface\\AddOns\\RakaMod\\Media\\statusbar.tga",
  -- Extensionless paths (WoW resolves .tga/.blp). Safer on Forever.
  ColorWheelPath = "Interface\\AddOns\\RakaMod\\Media\\colorwheel",
  IconPath = "Interface\\AddOns\\RakaMod\\Media\\icon",
  GrainPath = "Interface\\AddOns\\RakaMod\\Media\\grain",
  FontName = "RakaMod",
  StatusbarName = "RakaMod Statusbar",
}

-- Apply shared fade grain onto an existing texture parented to host.
-- On/off via features.fadeGrain; look is fixed (strength 40, scale 1).
function RakaMod.Media.ApplyFadeGrain(texture, host)
  if not texture or not host then
    return
  end
  local Logic = RakaMod.Logic
  if not Logic then
    return
  end
  local features = RakaMod.db and RakaMod.db.features
  if not (features and features.fadeGrain == true) then
    texture:Hide()
    return
  end
  local alpha = Logic.GrainAlpha(Logic.FADE_GRAIN_STRENGTH)
  local tile = Logic.GrainTileSize(Logic.FADE_GRAIN_SCALE)
  -- Same tile math for Escape + AFK (UIParent size), so grain matches.
  local ref = UIParent or host
  local w = ref.GetWidth and ref:GetWidth() or 0
  local h = ref.GetHeight and ref:GetHeight() or 0
  if type(w) ~= "number" or w <= 0 then
    w = 1920
  end
  if type(h) ~= "number" or h <= 0 then
    h = 1080
  end
  local path = RakaMod.Media.GrainPath
  texture:SetTexture(path, "REPEAT", "REPEAT")
  texture:SetAllPoints(host)
  -- BLEND + dark TGA (no ADD) so flecks stay charcoal, not white.
  texture:SetBlendMode("BLEND")
  texture:SetVertexColor(1, 1, 1, alpha)
  texture:SetTexCoord(0, w / tile, 0, h / tile)
  texture:Show()
end

local function Register()
  local libStub = LibStub
  if not libStub then
    return
  end
  local ok, lsm = pcall(libStub, "LibSharedMedia-3.0")
  if not ok or not lsm then
    return
  end
  lsm:Register(lsm.MediaType.FONT, RakaMod.Media.FontName, RakaMod.Media.FontPath)
  lsm:Register(lsm.MediaType.STATUSBAR, RakaMod.Media.StatusbarName, RakaMod.Media.StatusbarPath)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", Register)
