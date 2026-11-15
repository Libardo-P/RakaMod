RakaMod = RakaMod or {}

local ROOT = "Interface\\AddOns\\RakaMod\\Media\\"

RakaMod.Media = {
  FontPath = ROOT .. "font\\RakaMod.ttf",
  StatusbarPath = ROOT .. "statusbar\\ToxiUI-clean.tga",
  -- Extensionless paths (WoW resolves .tga/.blp). Safer on Forever.
  ColorWheelPath = ROOT .. "colorwheel",
  IconPath = ROOT .. "icon",
  GrainPath = ROOT .. "background\\grain",
  FontName = "Rk RakaMod",
  StatusbarName = "Rk ToxiUI Clean",
}

-- Catalogs relative to Media/. icon/colorwheel stay RakaMod-only (not LSM).
local FONTS = {
  { "Rk RakaMod", "font\\RakaMod.ttf" },
  { "Rk BigNoodleToo", "font\\BigNoodleToo.ttf" },
  { "Rk Doris PP", "font\\Doris PP.ttf" },
  { "Rk Montserrat Black", "font\\Montserrat-Black.ttf" },
  { "Rk Montserrat Bold", "font\\Montserrat-Bold.ttf" },
  { "Rk Montserrat Medium", "font\\Montserrat-Medium.ttf" },
  { "Rk Roboto Condensed", "font\\Roboto Condensed.ttf" },
  { "Rk ToxiUI", "font\\ToxiUI.ttf" },
  { "Rk ToxiUI Icons", "font\\ToxiUIIcons.ttf" },
}

local STATUSBARS = {
  { "Rk Arrow", "statusbar\\Arrow.tga" },
  { "Rk Bui One Pixel", "statusbar\\BuiOnePixel.tga" },
  { "Rk KMT47", "statusbar\\KMT47.tga" },
  { "Rk Resting", "statusbar\\Resting.tga" },
  { "Rk Rupture", "statusbar\\Rupture.tga" },
  { "Rk ToxiUI Clean", "statusbar\\ToxiUI-clean.tga" },
  { "Rk ToxiUI Dark", "statusbar\\ToxiUI-dark.tga" },
  { "Rk ToxiUI Fade", "statusbar\\ToxiUI-fade.blp" },
  { "Rk ToxiUI G1", "statusbar\\ToxiUI-g1.tga" },
  { "Rk ToxiUI G2", "statusbar\\ToxiUI-g2.tga" },
  { "Rk ToxiUI Grad", "statusbar\\ToxiUI-grad.tga" },
  { "Rk ToxiUI Half", "statusbar\\ToxiUI-half.tga" },
  { "Rk ToxiUI Half Transparent", "statusbar\\ToxiUI-half-transparent.blp" },
  { "Rk ToxiUI Half Transparent Stroke", "statusbar\\ToxiUI-half-transparent-stroke.blp" },
  { "Rk TX WorldState Score", "statusbar\\TX-WorldState-Score.blp" },
}

local BACKGROUNDS = {
  { "Rk Grain", "background\\grain.tga" },
  { "Rk Class Fabled", "class\\fabled.tga" },
  { "Rk Class Fabled Class", "class\\fabledclass.tga" },
  { "Rk Class Fabled Core", "class\\fabledcore.tga" },
  { "Rk Class Fabled Dimension", "class\\fableddimension.tga" },
  { "Rk Class Fabled Myth", "class\\fabledmyth.tga" },
  { "Rk Class Fabled Pixels", "class\\fabledpixels.tga" },
  { "Rk Class Fabled Pixels V2", "class\\fabledpixelsv2.tga" },
  { "Rk Class Fabled Realm", "class\\fabledrealm.tga" },
  { "Rk Class Fabled Realm V2", "class\\fabledrealmv2.tga" },
  { "Rk Class Fabled Regalia", "class\\fabledregalia.tga" },
  { "Rk Class Into The Void", "class\\intothevoid.tga" },
}

local PORTRAIT_FILES = {
  "circle", "circle-32", "circle-64", "circle-128", "circle-256", "circle-512",
  "circle-mask", "circle-mask-32", "circle-mask-64", "circle-mask-128", "circle-mask-256", "circle-mask-512",
  "circle-thin", "circle-thin-32", "circle-thin-64", "circle-thin-128", "circle-thin-256", "circle-thin-512",
  "circle-thin-mask", "circle-thin-mask-32", "circle-thin-mask-64", "circle-thin-mask-128", "circle-thin-mask-256", "circle-thin-mask-512",
  "droplet", "droplet-32", "droplet-64", "droplet-128", "droplet-256", "droplet-512",
  "droplet-mask", "droplet-mask-32", "droplet-mask-64", "droplet-mask-128", "droplet-mask-256", "droplet-mask-512",
  "droplet-thin", "droplet-thin-32", "droplet-thin-64", "droplet-thin-128", "droplet-thin-256", "droplet-thin-512",
  "droplet-thin-mask", "droplet-thin-mask-32", "droplet-thin-mask-64", "droplet-thin-mask-128", "droplet-thin-mask-256", "droplet-thin-mask-512",
  "droplet-left-mask", "droplet-left-mask-32", "droplet-left-mask-64", "droplet-left-mask-128", "droplet-left-mask-256", "droplet-left-mask-512",
  "droplet-left-thin-mask", "droplet-left-thin-mask-32", "droplet-left-thin-mask-64", "droplet-left-thin-mask-128", "droplet-left-thin-mask-256", "droplet-left-thin-mask-512",
}

local function MediaPath(relative)
  return ROOT .. relative
end

function RakaMod.Media.Path(relative)
  if type(relative) ~= "string" or relative == "" then
    return nil
  end
  return MediaPath(relative)
end

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

RakaMod.Media.LegacyNames = RakaMod.Logic.BuildLegacyMediaNames(FONTS, STATUSBARS, BACKGROUNDS)

local registered = false

local function RegisterList(lsm, mediaType, list)
  for i = 1, #list do
    local entry = list[i]
    lsm:Register(mediaType, entry[1], MediaPath(entry[2]))
  end
end

-- Register into RakaMod-vendored LibSharedMedia (works with or without Ellesmere/ElvUI).
local function Register()
  if registered then
    return
  end
  local libStub = LibStub
  if not libStub then
    return
  end
  local ok, lsm = pcall(libStub, "LibSharedMedia-3.0")
  if not ok or not lsm then
    return
  end

  RegisterList(lsm, lsm.MediaType.FONT, FONTS)
  RegisterList(lsm, lsm.MediaType.STATUSBAR, STATUSBARS)
  RegisterList(lsm, lsm.MediaType.BACKGROUND, BACKGROUNDS)

  for i = 1, #PORTRAIT_FILES do
    local file = PORTRAIT_FILES[i]
    lsm:Register(lsm.MediaType.BACKGROUND, "Rk Portrait " .. file, MediaPath("portraits\\" .. file .. ".tga"))
  end

  registered = true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 ~= "RakaMod" then
    return
  end
  Register()
end)
