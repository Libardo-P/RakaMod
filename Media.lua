RakaMod = RakaMod or {}
RakaMod.Media = {
  FontPath = "Interface\\AddOns\\RakaMod\\Media\\RakaMod.ttf",
  StatusbarPath = "Interface\\AddOns\\RakaMod\\Media\\statusbar.tga",
  -- Extensionless path (WoW resolves .tga/.blp). Used as Forever underlay fallback.
  ColorWheelPath = "Interface\\AddOns\\RakaMod\\Media\\colorwheel",
  FontName = "RakaMod",
  StatusbarName = "RakaMod Statusbar",
}

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
