RakaMod = RakaMod or {}

-- Palette, fonts and the live accent color for the settings window.
-- Widgets register a painter with Theme.Bind; changing the accent repaints every painter at once.
local Logic = RakaMod.Logic
local Theme = {}
RakaMod.Theme = Theme

Theme.template = BackdropTemplateMixin and "BackdropTemplate" or nil

Theme.COLORS = {
  SHELL = { r = 0.060, g = 0.060, b = 0.065 },
  SIDEBAR = { r = 0.085, g = 0.085, b = 0.090 },
  CONTENT = { r = 0.115, g = 0.115, b = 0.120 },
  BODY = { r = 0.140, g = 0.140, b = 0.145 },
  GROUP = { r = 0.155, g = 0.155, b = 0.160 },
  FIELD = { r = 0.095, g = 0.095, b = 0.100 },
  RAISED = { r = 0.185, g = 0.185, b = 0.195 },
  BORDER = { r = 0.255, g = 0.255, b = 0.270 },
  BORDER_HI = { r = 0.380, g = 0.380, b = 0.400 },
  TEXT = { r = 0.92, g = 0.92, b = 0.93 },
  MUTED = { r = 0.60, g = 0.60, b = 0.63 },
  NAV_IDLE = { r = 0.74, g = 0.74, b = 0.77 },
}

-- Live accent (r, g, b) plus derived shades; always valid, even before saved variables load.
Theme.accent = { r = 0.25, g = 0.62, b = 1.00, dr = 0.09, dg = 0.23, db = 0.38, tr = 1, tg = 1, tb = 1 }

local painters = {}

function Theme.FontPath()
  local media = RakaMod.Media
  return (media and media.UiFontPathChosen and media.UiFontPathChosen())
    or (media and media.UIFontPath)
    or STANDARD_TEXT_FONT
end

-- Every font string and edit box styled through Theme.SetFont, so a font change repaints them all.
local fontEntries = setmetatable({}, { __mode = "k" })

local function applyFont(fontString, size, flags)
  local media = RakaMod.Media
  local scale = media and media.UiFontScale and media.UiFontScale()
  size = RakaMod.Logic.ScaledFontSize(size, scale)
  local ok = fontString:SetFont(Theme.FontPath(), size, flags)
  if not ok and STANDARD_TEXT_FONT then
    fontString:SetFont(STANDARD_TEXT_FONT, size, flags)
  end
end

function Theme.SetFont(fontString, size, flags)
  flags = flags or ""
  fontEntries[fontString] = { size = size, flags = flags }
  applyFont(fontString, size, flags)
end

-- Re-applies the saved settings window font everywhere.
function Theme.RefreshFonts()
  for fontString, entry in pairs(fontEntries) do
    applyFont(fontString, entry.size, entry.flags)
  end
end

-- Creates a themed FontString. color is a palette entry; nil keeps the default text color.
function Theme.Text(parent, size, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  Theme.SetFont(fs, size)
  color = color or Theme.COLORS.TEXT
  fs:SetTextColor(color.r, color.g, color.b)
  return fs
end

-- Flat 1px-bordered panel. Uses a backdrop when the client offers one, otherwise a plain fill.
function Theme.Panel(target, color, border, alpha)
  if not target.SetBackdrop then
    if not target.__fill then
      target.__fill = target:CreateTexture(nil, "BACKGROUND")
      target.__fill:SetAllPoints()
    end
    target.__fill:SetColorTexture(color.r, color.g, color.b, alpha or color.a or 1)
    return
  end
  target:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  target:SetBackdropColor(color.r, color.g, color.b, alpha or color.a or 1)
  if border then
    target:SetBackdropBorderColor(border.r, border.g, border.b, 1)
  else
    target:SetBackdropBorderColor(0, 0, 0, 0)
  end
end

function Theme.SetBorder(target, color, alpha)
  if target.SetBackdropBorderColor then
    target:SetBackdropBorderColor(color.r, color.g, color.b, alpha or 1)
  end
end

function Theme.SetFill(target, r, g, b, a)
  if target.SetBackdropColor then
    target:SetBackdropColor(r, g, b, a or 1)
  end
end

function Theme.ClassColor()
  local classFile
  if UnitClass then
    local ok, _, file = pcall(UnitClass, "player")
    if ok and type(file) == "string" then
      classFile = file
    end
  end
  if not classFile then
    return nil
  end
  local r, g, b = Logic.ClassRgb(classFile, RAID_CLASS_COLORS)
  return { r = r, g = g, b = b }
end

function Theme.SavedAccent()
  local db = RakaMod.db
  local general = type(db) == "table" and db.general
  if type(general) ~= "table" then
    return nil
  end
  if type(general.accent) ~= "table" then
    general.accent = Logic.BuildAccentDefaults()
  end
  return general.accent
end

local function repaintAll()
  local a = Theme.accent
  for i = 1, #painters do
    painters[i](a)
  end
end

-- Recomputes the accent from saved settings (and the class color) and repaints every bound widget.
function Theme.Refresh()
  local a = Theme.accent
  local r, g, b = Logic.GetAccentColor(Theme.SavedAccent(), Theme.ClassColor())
  a.r, a.g, a.b = r, g, b
  a.dr, a.dg, a.db = Logic.ShadeColor(r, g, b, 0.62)
  a.tr, a.tg, a.tb = Logic.AccentTextColor(r, g, b)
  repaintAll()
end

-- Registers fn(accent) and runs it once now.
function Theme.Bind(fn)
  painters[#painters + 1] = fn
  fn(Theme.accent)
  return fn
end

-- mode: "preset" | "custom" | "class". preset is only read for "preset".
function Theme.SetAccentMode(mode, preset)
  local saved = Theme.SavedAccent()
  if not saved then
    return
  end
  if mode == "custom" and saved.mode ~= "custom" then
    saved.r, saved.g, saved.b = Theme.accent.r, Theme.accent.g, Theme.accent.b
  end
  saved.mode = mode
  if mode == "preset" and preset then
    saved.preset = preset
  end
  Theme.Refresh()
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" }) do
  pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function()
  Theme.Refresh()
end)

return Theme
