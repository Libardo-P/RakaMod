local Logic = {}

function Logic.CopyTable(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for key, child in pairs(value) do
    out[key] = Logic.CopyTable(child)
  end
  return out
end

function Logic.MergeDefaults(saved, defaults)
  if type(saved) ~= "table" then
    saved = {}
  end
  local out = {}
  for key, defaultValue in pairs(defaults) do
    local current = saved[key]
    if type(defaultValue) == "table" then
      if key == "played" and type(current) == "table" then
        out[key] = current
      elseif type(current) ~= "table" then
        out[key] = Logic.CopyTable(defaultValue)
      else
        out[key] = Logic.MergeDefaults(current, defaultValue)
      end
    elseif current == nil then
      out[key] = defaultValue
    else
      out[key] = current
    end
  end
  return out
end

Logic.MEDIA_PREFIX = "Rk "
Logic.MEDIA_MIGRATION_VERSION = 1

-- "Doris PP" -> "Rk Doris PP". Idempotent: already-prefixed names are returned as is.
function Logic.PrefixMediaName(name)
  if type(name) ~= "string" or name == "" then
    return name
  end
  if name == "Rk" then
    return Logic.MEDIA_PREFIX .. "RakaMod"
  end
  if name:sub(1, #Logic.MEDIA_PREFIX) == Logic.MEDIA_PREFIX then
    return name
  end
  return Logic.MEDIA_PREFIX .. name
end

-- Builds { oldName = newName } for every registered name (list of names or { name, path } pairs).
function Logic.BuildLegacyMediaNames(...)
  local map = { Rk = Logic.MEDIA_PREFIX .. "RakaMod" }
  for i = 1, select("#", ...) do
    local list = select(i, ...)
    for _, entry in ipairs(list or {}) do
      local name = type(entry) == "table" and entry[1] or entry
      if type(name) == "string" and name:sub(1, #Logic.MEDIA_PREFIX) == Logic.MEDIA_PREFIX then
        map[name:sub(#Logic.MEDIA_PREFIX + 1)] = name
      end
    end
  end
  return map
end

local function migrateNames(node, legacy, depth)
  if type(node) ~= "table" or depth > 6 then
    return
  end
  for key, value in pairs(node) do
    if type(value) == "string" then
      if legacy[value] then
        node[key] = legacy[value]
      end
    elseif type(value) == "table" then
      migrateNames(value, legacy, depth + 1)
    end
  end
end

-- One-time rewrite of saved media names (fonts, statusbars, backgrounds) to their "Rk " names.
-- Runs on the raw saved table before MergeDefaults; the played records are skipped.
function Logic.MigrateMediaNames(saved, legacy)
  if type(saved) ~= "table" then
    return saved
  end
  local done = saved.mediaMigration
  if type(done) == "number" and done >= Logic.MEDIA_MIGRATION_VERSION then
    return saved
  end
  for key, value in pairs(saved) do
    if key ~= "played" then
      if type(value) == "string" then
        if legacy[value] then
          saved[key] = legacy[value]
        end
      elseif type(value) == "table" then
        migrateNames(value, legacy, 1)
      end
    end
  end
  saved.mediaMigration = Logic.MEDIA_MIGRATION_VERSION
  return saved
end

function Logic.IsForever(interfaceVersion)
  return interfaceVersion == 16001
end

-- True when current health is below max (under 100%). Absorbs do not count towards health.
function Logic.HealthBelowFull(current, maxHealth, secret)
  if secret then
    return false
  end
  if type(current) ~= "number" or type(maxHealth) ~= "number" or maxHealth <= 0 then
    return false
  end
  return current < maxHealth
end

function Logic.IsHealthBarKey(key)
  if type(key) ~= "string" then
    return false
  end
  local lower = string.lower(key)
  if not string.find(lower, "health", 1, true) then
    return false
  end
  if string.find(lower, "power", 1, true) or string.find(lower, "cast", 1, true) or string.find(lower, "absorb", 1, true) then
    return false
  end
  return true
end

local BAR_KIND_SKIP = { "absorb", "prediction", "shield", "incoming", "overlay", "background" }
local RESOURCE_KEY_PARTS = { "classpower", "classresource", "resource", "combo", "rune", "holypower", "soulshard", "shadoworb" }
local RESOURCE_KEY_EXACT = { chi = true, chibar = true, chis = true, orbs = true }

-- Kind of Ellesmere status bar a Lua field name stands for: "health", "power", "castbar",
-- "resource" (class resources) or nil when the field is none of them (absorb and the like).
function Logic.BarKindFromKey(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end
  local lower = string.lower(key)
  for i = 1, #BAR_KIND_SKIP do
    if string.find(lower, BAR_KIND_SKIP[i], 1, true) then
      return nil
    end
  end
  if string.find(lower, "cast", 1, true) or string.find(lower, "channel", 1, true) then
    return "castbar"
  end
  if RESOURCE_KEY_EXACT[lower] then
    return "resource"
  end
  for i = 1, #RESOURCE_KEY_PARTS do
    if string.find(lower, RESOURCE_KEY_PARTS[i], 1, true) then
      return "resource"
    end
  end
  if string.find(lower, "power", 1, true) or string.find(lower, "mana", 1, true) then
    return "power"
  end
  if Logic.IsHealthBarKey(key) then
    return "health"
  end
  return nil
end

local POWER_TOKEN_KEYS = {
  MANA = "mana",
  RAGE = "rage",
  FOCUS = "focus",
  ENERGY = "energy",
  RUNIC_POWER = "runicPower",
  ALTERNATE = "altPower",
  ALT_POWER = "altPower",
}
local POWER_ID_KEYS = { [0] = "mana", [1] = "rage", [2] = "focus", [3] = "energy", [6] = "runicPower", [10] = "altPower" }

-- Key of gradient.power for a unit's power type (token such as "MANA", id such as 0), or nil
-- for types without a configured gradient so Ellesmere keeps its own color.
function Logic.PowerKey(token, id)
  if type(token) == "string" and POWER_TOKEN_KEYS[token] then
    return POWER_TOKEN_KEYS[token]
  end
  if type(id) == "number" then
    return POWER_ID_KEYS[id]
  end
  return nil
end

local RUNE_SPEC_KEYS = { "bloodRunes", "frostRunes", "unholyRunes" }

-- Key of gradient.classResources for one pip of the player's class resource bar. index is the
-- pip number (combo points 1-5), spec the specialization index (death knight runes).
function Logic.ResourceKey(classFile, index, spec)
  if classFile == "ROGUE" or classFile == "DRUID" then
    if type(index) == "number" and index >= 1 and index <= 5 then
      return "comboPoint" .. index
    end
    return nil
  end
  if classFile == "PALADIN" then
    return "holyPower"
  elseif classFile == "MONK" then
    return "chi"
  elseif classFile == "WARLOCK" then
    return "soulShards"
  elseif classFile == "PRIEST" then
    return "shadowOrbs"
  elseif classFile == "DEATHKNIGHT" then
    return RUNE_SPEC_KEYS[spec] or "deathRunes"
  end
  return nil
end

-- Key of gradient.nameplateThreat for a hostile nameplate, from Blizzard's threat status
-- (nil = not on the threat table, 0 = lower than the tank, 1 = higher but not tanking,
-- 2 = insecurely tanking, 3 = securely tanking). otherTank is true when another tank holds it.
function Logic.ThreatKey(status, isTank, grouped, otherTank)
  if type(status) ~= "number" then
    return nil
  end
  if not grouped then
    return "solo"
  end
  if isTank then
    if status >= 3 then
      return "good"
    elseif status == 2 then
      return "goodTransition"
    elseif otherTank then
      if status == 1 then
        return "offTankBad"
      end
      return "offTank"
    end
    return "bad"
  end
  if status >= 3 then
    return "bad"
  elseif status >= 1 then
    return "badTransition"
  elseif otherTank then
    return "offTankGood"
  end
  return "good"
end

-- Key of gradient.nameplateClassification for a non-player unit, or nil for ordinary mobs.
function Logic.ClassificationKey(classification, level, isBoss, classFile)
  if type(classification) ~= "string" then
    return nil
  end
  if classification == "worldboss" then
    return "worldBoss"
  elseif classification == "rareelite" then
    return "rareElite"
  elseif classification == "rare" then
    return "rare"
  elseif classification == "elite" then
    if isBoss or level == -1 then
      return "eliteBoss"
    end
    return "eliteMini"
  elseif (classification == "normal" or classification == "minus" or classification == "trivial") and classFile == "MAGE" then
    return "caster"
  end
  return nil
end

-- Nameplate health pair: dead / offline / tapped first, then threat, classification, then the
-- same class / NPC / state choice as unit frames.
function Logic.PickNameplatePair(gradient, info)
  if type(gradient) ~= "table" or type(info) ~= "table" then
    return nil
  end
  if not (info.dead or info.offline or info.tapped) then
    local threat = gradient.nameplateThreat
    if type(info.threatKey) == "string" and type(threat) == "table" and type(threat[info.threatKey]) == "table" then
      return threat[info.threatKey]
    end
    local classification = gradient.nameplateClassification
    if type(info.classificationKey) == "string" and type(classification) == "table"
      and type(classification[info.classificationKey]) == "table" then
      return classification[info.classificationKey]
    end
  end
  return Logic.PickGradientPair(gradient, info)
end

-- Pair for a power, castbar or class resource bar. info: powerKey, nonInterruptible, resourceKey.
function Logic.PickBarPair(gradient, kind, info)
  if type(gradient) ~= "table" or type(info) ~= "table" then
    return nil
  end
  local group, key
  if kind == "power" then
    group, key = gradient.power, info.powerKey
  elseif kind == "castbar" then
    group, key = gradient.castbar, info.nonInterruptible and "nonInterruptible" or "regular"
  elseif kind == "resource" then
    group, key = gradient.classResources, info.resourceKey
  end
  if type(group) == "table" and type(key) == "string" and type(group[key]) == "table" then
    return group[key]
  end
  return nil
end

-- Left and right color of a horizontal gradient; direction "LEFT" fades toward the left edge.
function Logic.OrientPair(pairColors, direction)
  if direction == "LEFT" then
    return pairColors.right, pairColors.left
  end
  return pairColors.left, pairColors.right
end

function Logic.PlayedSummary(records)
  local account = 0
  local byClass = {}
  if type(records) ~= "table" then
    return { account = 0, byClass = byClass }
  end
  for _, record in pairs(records) do
    if type(record) == "table" and type(record.totalSeconds) == "number" and type(record.classFile) == "string" then
      account = account + record.totalSeconds
      byClass[record.classFile] = (byClass[record.classFile] or 0) + record.totalSeconds
    end
  end
  return { account = account, byClass = byClass }
end

function Logic.ClassFraction(classSeconds, accountTotal)
  if type(classSeconds) ~= "number" or type(accountTotal) ~= "number" or accountTotal <= 0 then
    return 0
  end
  return classSeconds / accountTotal
end

function Logic.FormatDuration(seconds)
  if type(seconds) ~= "number" then
    return "\226\128\148"
  end
  local whole = math.floor(seconds)
  local hours = math.floor(whole / 3600)
  local minutes = math.floor((whole % 3600) / 60)
  if hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  end
  return string.format("%dm", minutes)
end

function Logic.FormatClock(elapsed)
  if type(elapsed) ~= "number" or elapsed < 0 then
    elapsed = 0
  end
  local whole = math.floor(elapsed)
  return string.format("%02d:%02d", math.floor(whole / 60), whole % 60)
end

function Logic.AnchorSide(menuLeft, panelWidth, gap)
  gap = gap or 12
  if menuLeft < panelWidth + gap then
    return "RIGHT"
  end
  return "LEFT"
end

function Logic.CanRequestPlayed(now, lastRequest)
  if lastRequest == nil then
    return true
  end
  return (now - lastRequest) >= 60
end

function Logic.AfkBlocked(state)
  if not state.enabled or not state.isAFK then
    return true
  end
  if state.locked or state.cinematic or state.movie or state.casting then
    return true
  end
  return false
end

function Logic.AfkSuppressed(now, suppressUntil)
  return type(suppressUntil) == "number" and now < suppressUntil
end

-- Shade alpha from a 0–100 fade setting (AFK / Escape overlay).
function Logic.ShadeAlpha(fade, defaultFade)
  if type(defaultFade) ~= "number" then
    defaultFade = 72
  end
  if type(fade) ~= "number" then
    fade = defaultFade
  end
  if fade < 0 then
    fade = 0
  elseif fade > 100 then
    fade = 100
  end
  return fade / 100
end

-- Shared Escape/AFK fade default (features.backgroundFade).
Logic.FADE_BACKGROUND_DEFAULT = 50

function Logic.FadeShadeAlpha(fade)
  return Logic.ShadeAlpha(fade, Logic.FADE_BACKGROUND_DEFAULT)
end

-- Fixed fade-grain look when features.fadeGrain is on.
Logic.FADE_GRAIN_STRENGTH = 40
Logic.FADE_GRAIN_SCALE = 1

-- Grain overlay alpha from strength (0–100). Default matches fade grain.
function Logic.GrainAlpha(strength)
  if type(strength) ~= "number" then
    strength = Logic.FADE_GRAIN_STRENGTH
  end
  if strength < 0 then
    strength = 0
  elseif strength > 100 then
    strength = 100
  end
  return strength / 100
end

-- Pixel tile size from scale (1–10). Higher = coarser grain.
function Logic.GrainTileSize(scale)
  if type(scale) ~= "number" then
    scale = Logic.FADE_GRAIN_SCALE
  end
  if scale < 1 then
    scale = 1
  elseif scale > 10 then
    scale = 10
  end
  return 32 + (scale - 1) * 16
end

-- UI scale for AFK overlay vs 1920x1080 baseline. Clamped so 1080p stays compact
-- and ultrawide/4K do not explode fixed-pixel widgets.
function Logic.AfkLayoutScale(width, height)
  if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
    return 1
  end
  local scale = math.min(width / 1920, height / 1080)
  if scale < 0.7 then
    return 0.7
  end
  if scale > 1.15 then
    return 1.15
  end
  return scale
end

-- True when a WhatsNew entry should show for this client (Forever vs Retail flags).
function Logic.EllesmereEntryVisible(entry, isForever)
  if type(entry) ~= "table" then
    return false
  end
  if entry.forever == true and not isForever then
    return false
  end
  if entry.retail == true and isForever then
    return false
  end
  return true
end

-- Left-column tags for a WhatsNew entry (Ellesmere-style: client tag + module).
function Logic.EllesmereEntryTags(entry)
  if type(entry) ~= "table" then
    return "", ""
  end
  local module = ""
  if type(entry.module) == "string" and entry.module ~= "" then
    module = string.upper(entry.module)
  end
  if entry.forever == true then
    return "WOW FOREVER", module
  end
  if entry.retail == true then
    return "RETAIL", module
  end
  if type(entry.patch) == "string" and entry.patch ~= "" then
    return entry.patch, module
  end
  return module, ""
end

-- Structured view of newest patch for the AFK WhatsNew panel. Nil when unavailable.
function Logic.BuildEllesmereChangelogView(patches, isForever, maxFeatures, maxFixes)
  maxFeatures = maxFeatures or 6
  maxFixes = maxFixes or 6
  if type(patches) ~= "table" or type(patches[1]) ~= "table" then
    return nil
  end
  local patch = patches[1]
  local version = tostring(patch.version or "")
  if version == "" then
    return nil
  end

  local features = {}
  if type(patch.features) == "table" then
    for i = 1, #patch.features do
      local entry = patch.features[i]
      if Logic.EllesmereEntryVisible(entry, isForever) then
        local title = type(entry.title) == "string" and entry.title or ""
        local desc = type(entry.desc) == "string" and entry.desc or ""
        if title ~= "" or desc ~= "" then
          local primary, secondary = Logic.EllesmereEntryTags(entry)
          features[#features + 1] = {
            primary = primary,
            secondary = secondary,
            title = title,
            desc = desc,
          }
          if #features >= maxFeatures then
            break
          end
        end
      end
    end
  end

  local fixes = {}
  if type(patch.fixes) == "table" then
    for i = 1, #patch.fixes do
      local entry = patch.fixes[i]
      if Logic.EllesmereEntryVisible(entry, isForever) then
        local text = type(entry.text) == "string" and entry.text or ""
        if text ~= "" then
          local primary, secondary = Logic.EllesmereEntryTags(entry)
          fixes[#fixes + 1] = {
            primary = primary,
            secondary = secondary,
            text = text,
          }
          if #fixes >= maxFixes then
            break
          end
        end
      end
    end
  end

  return {
    version = version,
    date = type(patch.date) == "string" and patch.date or nil,
    features = features,
    fixes = fixes,
  }
end

-- Legacy plain-text formatter (tests / fallbacks).
function Logic.FormatEllesmereChangelog(patches, isForever, maxFeatures, maxFixes)
  local view = Logic.BuildEllesmereChangelogView(patches, isForever, maxFeatures, maxFixes)
  if not view then
    return nil, nil
  end
  if #view.features == 0 and #view.fixes == 0 then
    return "Latest changelog for " .. view.version, "No entries for this client."
  end
  local parts = {}
  if #view.features > 0 then
    parts[#parts + 1] = "|cff3dff7aNEW FEATURES|r"
    for i = 1, #view.features do
      local f = view.features[i]
      if f.title ~= "" and f.desc ~= "" then
        parts[#parts + 1] = "• " .. f.title .. " — " .. f.desc
      elseif f.title ~= "" then
        parts[#parts + 1] = "• " .. f.title
      else
        parts[#parts + 1] = "• " .. f.desc
      end
    end
  end
  if #view.fixes > 0 then
    if #parts > 0 then
      parts[#parts + 1] = ""
    end
    parts[#parts + 1] = "|cffff66aaBUG FIXES|r"
    for i = 1, #view.fixes do
      parts[#parts + 1] = "• " .. view.fixes[i].text
    end
  end
  return "Latest changelog for " .. view.version, table.concat(parts, "\n")
end

Logic.CLASS_FILES = {
  "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
  "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
}

-- Classic / retail RAID_CLASS_COLORS-ish fallbacks for out-of-game defaults.
Logic.CLASS_FALLBACK_COLORS = {
  WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
  PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
  HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
  ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
  PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
  DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
  SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
  MAGE = { r = 0.25, g = 0.78, b = 0.92 },
  WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
  MONK = { r = 0.00, g = 1.00, b = 0.60 },
  DRUID = { r = 1.00, g = 0.49, b = 0.04 },
  DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
  EVOKER = { r = 0.20, g = 0.58, b = 0.50 },
}

local function clamp01(value)
  if type(value) ~= "number" then
    return 0
  end
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

function Logic.ClassRgb(classFile, classColors)
  if type(classFile) == "string" and type(classColors) == "table" then
    local c = classColors[classFile]
    if type(c) == "table" and type(c.r) == "number" then
      return clamp01(c.r), clamp01(c.g), clamp01(c.b)
    end
  end
  local fallback = Logic.CLASS_FALLBACK_COLORS[classFile]
  if type(fallback) == "table" then
    return fallback.r, fallback.g, fallback.b
  end
  return 1, 1, 1
end

-- Media/class/fabledclass.tga: 2048x2048, 256px cells (8x8 grid), icons laid out left to right,
-- top to bottom in rows of 5 / 4 / 4. Cell = { column, row }, both zero-based.
Logic.FABLED_CLASS_GRID = 8
Logic.FABLED_CLASS_CELLS = {
  MAGE = { 0, 0 }, WARRIOR = { 1, 0 }, ROGUE = { 2, 0 }, DRUID = { 3, 0 }, EVOKER = { 4, 0 },
  HUNTER = { 0, 1 }, SHAMAN = { 1, 1 }, PRIEST = { 2, 1 }, WARLOCK = { 3, 1 },
  PALADIN = { 0, 2 }, DEATHKNIGHT = { 1, 2 }, MONK = { 2, 2 }, DEMONHUNTER = { 3, 2 },
}

-- Texture coordinates (left, right, top, bottom) of a class icon on the Fabled class sheet,
-- or nil for an unknown class.
function Logic.FabledClassTexCoords(classFile)
  local cell = Logic.FABLED_CLASS_CELLS[classFile]
  if type(cell) ~= "table" then
    return nil
  end
  local step = 1 / Logic.FABLED_CLASS_GRID
  return cell[1] * step, (cell[1] + 1) * step, cell[2] * step, (cell[2] + 1) * step
end

-- First and last name for the AFK name line. WoW has no surname API: UnitName returns
-- (name, realm). A realm suffix is dropped; when the client hands back a spaced name
-- ("First Last") the first and last words are kept, otherwise just the single name.
function Logic.DisplayName(name)
  if type(name) ~= "string" then
    return ""
  end
  name = name:gsub("%-.*$", "")
  local words = {}
  for word in name:gmatch("%S+") do
    words[#words + 1] = word
  end
  if #words == 0 then
    return ""
  end
  if #words == 1 then
    return words[1]
  end
  return words[1] .. " " .. words[#words]
end

-- Default font choices (names registered in Media.lua / LibSharedMedia).
Logic.DEFAULT_AFK_FONT = "Rk RakaMod"
Logic.DEFAULT_UI_FONT = "Rk Roboto Condensed"
-- Escape overlay panel text keeps the game's own font until a font is picked.
Logic.DEFAULT_OVERLAY_FONT = "Game Default"
-- General Font Size: point size of the settings window's option labels (the body text).
-- Every other size of the window keeps its ratio to that body size.
Logic.DEFAULT_UI_FONT_SIZE = 15
Logic.UI_FONT_SIZE_MIN = 6
Logic.UI_FONT_SIZE_MAX = 24

-- Point size of a built-in window text size once the body size is uiSize; never below 6.
function Logic.ScaledFontSize(size, uiSize)
  if type(size) ~= "number" then
    return size
  end
  if type(uiSize) ~= "number" then
    uiSize = Logic.DEFAULT_UI_FONT_SIZE
  end
  uiSize = math.max(Logic.UI_FONT_SIZE_MIN, math.min(Logic.UI_FONT_SIZE_MAX, uiSize))
  return math.max(Logic.UI_FONT_SIZE_MIN, math.floor(size * uiSize / Logic.DEFAULT_UI_FONT_SIZE + 0.5))
end

-- AFK identity line: "Lv 80 - Enhancement - Shaman", or "Lv 80 - Shaman" without a spec.
function Logic.AfkIdentityLine(level, spec, className)
  local parts = {}
  if type(level) == "number" and level > 0 then
    parts[#parts + 1] = "Lv " .. level
  end
  if type(spec) == "string" and spec ~= "" then
    parts[#parts + 1] = spec
  end
  if type(className) == "string" and className ~= "" then
    parts[#parts + 1] = className
  end
  return table.concat(parts, " - ")
end

-- Current specialization name from whichever talent API the client has, or nil.
-- `api` maps API names to functions (any may be missing). Names equal to the class name are
-- rejected so the spec line never repeats the class line. Order: the talent tree with the most
-- points spent (classic trees), the primary talent tree (Cata+), then the spec index (Retail, MoP+)
-- and, when that only yields the class name, the spec id looked up through the by-id APIs.
function Logic.ResolveSpecName(api, className, classId)
  if type(api) ~= "table" then
    return nil, nil
  end
  local function call(fn, ...)
    if type(fn) ~= "function" then
      return nil
    end
    local r = { pcall(fn, ...) }
    if r[1] then
      return r[2], r[3], r[4], r[5], r[6]
    end
    return nil
  end
  local classLower = type(className) == "string" and className:lower() or nil
  local function usable(name)
    return type(name) == "string" and name ~= "" and name:lower() ~= classLower
  end

  local function tabInfo(tab)
    local first, second, third, _, fifth = call(api.GetTalentTabInfo, tab)
    if type(first) == "number" then
      return second, fifth
    end
    return first, third
  end

  local tabs = call(api.GetNumTalentTabs)
  if type(tabs) == "number" and tabs > 0 then
    local bestName, bestPoints = nil, 0
    for tab = 1, tabs do
      local name, points = tabInfo(tab)
      if usable(name) and type(points) == "number" and points > bestPoints then
        bestName, bestPoints = name, points
      end
    end
    if bestName then
      return bestName, "GetTalentTabInfo"
    end
  end

  local primary = call(api.GetPrimaryTalentTree)
  if type(primary) == "number" and primary > 0 then
    local name = tabInfo(primary)
    if usable(name) then
      return name, "GetPrimaryTalentTree"
    end
  end

  -- A spec id can be turned into a name by several APIs; some clients only fill in one.
  local function nameForSpecId(specId)
    if type(specId) ~= "number" or specId <= 0 then
      return nil
    end
    local _, byId = call(api.GetSpecializationInfoByID, specId)
    if usable(byId) then
      return byId, "GetSpecializationInfoByID"
    end
    local direct = call(api.GetSpecializationNameForSpecID, specId)
    if usable(direct) then
      return direct, "GetSpecializationNameForSpecID"
    end
    local _, forSpec = call(api.GetSpecializationInfoForSpecID, specId)
    if usable(forSpec) then
      return forSpec, "GetSpecializationInfoForSpecID"
    end
    if type(classId) == "number" then
      local count = call(api.GetNumSpecializationsForClassID, classId)
      for i = 1, (type(count) == "number" and count > 0) and count or 4 do
        local id, name = call(api.GetSpecializationInfoForClassID, classId, i)
        if id == specId and usable(name) then
          return name, "GetSpecializationInfoForClassID"
        end
      end
    end
    return nil
  end

  local index = call(api.GetSpecialization)
  if type(index) == "number" and index > 0 then
    local specId, name = call(api.GetSpecializationInfo, index)
    if usable(name) then
      return name, "GetSpecializationInfo"
    end
    local byId, source = nameForSpecId(specId)
    if byId then
      return byId, source
    end
  end

  local inspectId = call(api.GetInspectSpecialization, "player")
  local inspectName, inspectSource = nameForSpecId(inspectId)
  if inspectName then
    return inspectName, inspectSource
  end
  return nil, nil
end

-- Settings window accent: a preset, a custom color or the player's class color.
Logic.ACCENT_MODES = { "preset", "custom", "class" }
Logic.ACCENT_PRESETS = {
  { key = "gold", label = "Gold", r = 0.94, g = 0.77, b = 0.16 },
  { key = "blue", label = "Blue", r = 0.25, g = 0.62, b = 1.00 },
  { key = "green", label = "Green", r = 0.30, g = 0.80, b = 0.40 },
  { key = "red", label = "Red", r = 0.90, g = 0.30, b = 0.30 },
  { key = "purple", label = "Purple", r = 0.65, g = 0.42, b = 0.95 },
  { key = "cyan", label = "Cyan", r = 0.20, g = 0.82, b = 0.85 },
  { key = "white", label = "White", r = 0.92, g = 0.92, b = 0.94 },
}
Logic.ACCENT_DEFAULT_PRESET = "blue"

function Logic.AccentPreset(key)
  for i = 1, #Logic.ACCENT_PRESETS do
    local preset = Logic.ACCENT_PRESETS[i]
    if preset.key == key then
      return preset
    end
  end
  return nil
end

function Logic.BuildAccentDefaults()
  local preset = Logic.AccentPreset(Logic.ACCENT_DEFAULT_PRESET)
  return { mode = "preset", preset = preset.key, r = preset.r, g = preset.g, b = preset.b }
end

local function validAccentMode(mode)
  for i = 1, #Logic.ACCENT_MODES do
    if Logic.ACCENT_MODES[i] == mode then
      return true
    end
  end
  return false
end

-- Returns r, g, b for the saved accent table. Never errors on bad or missing data.
-- classRgb is { r, g, b } (or nil) for the player's class; class mode without it falls back to the default preset.
function Logic.GetAccentColor(accent, classRgb)
  local default = Logic.AccentPreset(Logic.ACCENT_DEFAULT_PRESET)
  if type(accent) ~= "table" then
    return default.r, default.g, default.b
  end
  local mode = accent.mode
  if not validAccentMode(mode) then
    mode = "preset"
  end
  if mode == "class" then
    if type(classRgb) == "table" and type(classRgb.r) == "number" and type(classRgb.g) == "number" and type(classRgb.b) == "number" then
      return clamp01(classRgb.r), clamp01(classRgb.g), clamp01(classRgb.b)
    end
    return default.r, default.g, default.b
  end
  if mode == "custom" then
    if type(accent.r) == "number" and type(accent.g) == "number" and type(accent.b) == "number" then
      return clamp01(accent.r), clamp01(accent.g), clamp01(accent.b)
    end
    return default.r, default.g, default.b
  end
  local preset = Logic.AccentPreset(accent.preset) or default
  return preset.r, preset.g, preset.b
end

-- Perceived brightness 0..1 (Rec. 601 weights).
function Logic.Luminance(r, g, b)
  return 0.299 * clamp01(r) + 0.587 * clamp01(g) + 0.114 * clamp01(b)
end

-- Text color readable on a filled accent surface: near-black on light accents, white on dark ones.
function Logic.AccentTextColor(r, g, b)
  if Logic.Luminance(r, g, b) >= 0.45 then
    return 0.07, 0.07, 0.08
  end
  return 1, 1, 1
end

-- Blend the accent toward black (amount 0..1) for dim fills and borders.
function Logic.ShadeColor(r, g, b, amount)
  local keep = 1 - clamp01(amount)
  return clamp01(r) * keep, clamp01(g) * keep, clamp01(b) * keep
end

local function rgb(r, g, b)
  return { r = clamp01(r), g = clamp01(g), b = clamp01(b) }
end

local function pair(left, right)
  return { left = left, right = right }
end

local function hexRgb(hex)
  hex = tostring(hex or ""):gsub("^#", "")
  local r = tonumber(hex:sub(1, 2), 16) or 0
  local g = tonumber(hex:sub(3, 4), 16) or 0
  local b = tonumber(hex:sub(5, 6), 16) or 0
  return rgb(r / 255, g / 255, b / 255)
end

local function hexPair(leftHex, rightHex)
  return pair(hexRgb(leftHex), hexRgb(rightHex))
end

-- Fixed left > right class gradient defaults (Toxi palette).
Logic.CLASS_GRADIENT_DEFAULTS = {
  DEATHKNIGHT = hexPair("911622", "ff2855"),
  WARRIOR = hexPair("946837", "dfaa73"),
  PALADIN = hexPair("d960a4", "ff95d8"),
  MAGE = hexPair("0080d7", "00d8ff"),
  PRIEST = hexPair("b9bddb", "f2f4ff"),
  ROGUE = hexPair("e7b200", "f5ee5a"),
  SHAMAN = hexPair("0030b0", "0070ec"),
  WARLOCK = hexPair("562fbd", "9946ff"),
  DEMONHUNTER = hexPair("8200a9", "e500d1"),
  MONK = hexPair("009463", "00ff8c"),
  DRUID = hexPair("e76200", "ffa900"),
  EVOKER = hexPair("33706f", "32fedc"),
  HUNTER = hexPair("00910d", "82eb3b"),
}

function Logic.ClassPairFromRgb(r, g, b)
  r, g, b = clamp01(r), clamp01(g), clamp01(b)
  return pair(
    rgb(r * 0.55, g * 0.55, b * 0.55),
    rgb(r + (1 - r) * 0.35, g + (1 - g) * 0.35, b + (1 - b) * 0.35)
  )
end

function Logic.BuildGradientDefaults(classColors)
  local classes = {}
  for i = 1, #Logic.CLASS_FILES do
    local file = Logic.CLASS_FILES[i]
    local fixed = Logic.CLASS_GRADIENT_DEFAULTS[file]
    if type(fixed) == "table" and type(fixed.left) == "table" and type(fixed.right) == "table" then
      classes[file] = pair(
        rgb(fixed.left.r, fixed.left.g, fixed.left.b),
        rgb(fixed.right.r, fixed.right.g, fixed.right.b)
      )
    else
      local c = (type(classColors) == "table" and classColors[file]) or Logic.CLASS_FALLBACK_COLORS[file]
      if type(c) ~= "table" then
        c = { r = 0.5, g = 0.5, b = 0.5 }
      end
      classes[file] = Logic.ClassPairFromRgb(c.r, c.g, c.b)
    end
  end
  return {
    enabled = false,
    powerEnabled = false,
    castbarEnabled = false,
    resourcesEnabled = false,
    classes = classes,
    npc = {
      friendly = hexPair("2F9607", "84D92B"),
      enemy = hexPair("C82122", "D9413F"),
      neutral = hexPair("D09046", "DEC249"),
    },
    states = {
      dead = pair(rgb(0.35, 0.35, 0.35), rgb(0.55, 0.55, 0.55)),
      offline = pair(rgb(0.25, 0.25, 0.30), rgb(0.45, 0.45, 0.55)),
      tapped = pair(rgb(0.40, 0.40, 0.40), rgb(0.65, 0.65, 0.65)),
    },
    power = {
      altPower = hexPair("1E4BB8", "3D7AE8"),
      focus = hexPair("B84A18", "D97134"),
      rage = hexPair("A81816", "E82F2D"),
      energy = hexPair("C45E12", "FFDF6E"),
      mana = hexPair("1A3F9E", "4A90E8"),
      runicPower = hexPair("0E7DB8", "37A3FB"),
    },
    castbar = {
      regular = hexPair("E8A000", "FFB200"),
      nonInterruptible = hexPair("72716F", "8E8D8B"),
    },
    classResources = {
      comboPoint1 = hexPair("863737", "BF4F4F"),
      comboPoint2 = hexPair("8B6437", "C78F4F"),
      comboPoint3 = hexPair("919137", "CFCF4F"),
      comboPoint4 = hexPair("648B37", "8FC74F"),
      comboPoint5 = hexPair("4D8837", "6EC24F"),
      holyPower = hexPair("D4A017", "FFE36B"),
      chi = hexPair("00A37A", "2DFFB3"),
      soulShards = hexPair("6A1FB8", "B061FF"),
      shadowOrbs = hexPair("5B0AB8", "A050FF"),
      bloodRunes = hexPair("8A0A26", "E51A46"),
      frostRunes = hexPair("005F99", "00ACFF"),
      unholyRunes = hexPair("04733A", "09D858"),
      deathRunes = hexPair("5A2A8F", "A35BFF"),
    },
    nameplatesEnabled = false,
    nameplateFadeDirection = "RIGHT",
    nameplateThreat = {
      good = hexPair("1F9E1F", "4BE04B"),
      goodTransition = hexPair("D9A300", "FFE14D"),
      offTank = hexPair("8F1F8F", "D65CD6"),
      offTankBad = hexPair("421F8F", "7F4DE0"),
      bad = hexPair("B31D1D", "FF4545"),
      badTransition = hexPair("CC5C00", "FFA04D"),
      offTankGood = hexPair("1F3F8F", "4D7FE0"),
      solo = hexPair("1F9E6B", "4BE0A6"),
    },
    nameplateClassification = {
      worldBoss = hexPair("A37A00", "E6C400"),
      rare = hexPair("2E7D00", "5CD11A"),
      eliteMini = hexPair("55248F", "8F5CD6"),
      rareElite = hexPair("008A6E", "00D6B0"),
      eliteBoss = hexPair("A1237A", "E65CBF"),
      caster = hexPair("005C8F", "1A9AE0"),
    },
  }
end

function Logic.ReactionKey(reaction)
  if type(reaction) ~= "number" then
    return "neutral"
  end
  if reaction >= 5 then
    return "friendly"
  end
  if reaction <= 3 then
    return "enemy"
  end
  return "neutral"
end

function Logic.PickGradientPair(gradient, info)
  if type(gradient) ~= "table" or type(info) ~= "table" then
    return nil
  end
  local states = gradient.states
  if info.dead and type(states) == "table" and type(states.dead) == "table" then
    return states.dead
  end
  if info.offline and type(states) == "table" and type(states.offline) == "table" then
    return states.offline
  end
  if info.tapped and type(states) == "table" and type(states.tapped) == "table" then
    return states.tapped
  end
  if info.isPlayer and type(info.classFile) == "string" then
    local classes = gradient.classes
    local classPair = type(classes) == "table" and classes[info.classFile]
    if type(classPair) == "table" then
      return classPair
    end
  end
  local npc = gradient.npc
  if type(npc) ~= "table" then
    return nil
  end
  local key = info.reactionKey
  if type(key) ~= "string" then
    key = "neutral"
  end
  if type(npc[key]) == "table" then
    return npc[key]
  end
  return npc.neutral
end

RakaMod = RakaMod or {}
RakaMod.Logic = Logic
return Logic
