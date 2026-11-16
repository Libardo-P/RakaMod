local unpack = table.unpack or unpack
local Logic = dofile("Logic.lua")
local failures = 0

local function eq(actual, expected, name)
  if actual ~= expected then
    failures = failures + 1
    io.stderr:write(string.format("FAIL %s: got %s expected %s\n", name, tostring(actual), tostring(expected)))
  end
end

eq(Logic.IsForever(16001), true, "forever")
eq(Logic.IsForever(120105), false, "retail")

local defaults = {
  general = { showMinimapIcon = true, hide = false, minimapPos = 210 },
  overlay = { enabled = true, collections = true, played = true, professions = true },
  gradient = Logic.BuildGradientDefaults(),
  played = {},
}
local merged = Logic.MergeDefaults({
  general = { showMinimapIcon = false, hide = true },
  overlay = { enabled = false },
  gradient = "bad",
  played = { a = { totalSeconds = 10 } },
}, defaults)
eq(merged.general.showMinimapIcon, false, "keep general bool")
eq(merged.general.hide, true, "keep libdbicon hide")
eq(merged.general.minimapPos, 210, "fill minimapPos")
eq(merged.overlay.enabled, false, "keep saved bool")
eq(merged.overlay.collections, true, "fill missing key")
eq(merged.gradient.enabled, false, "reset bad section")
eq(type(merged.gradient.classes.MAGE), "table", "gradient classes seeded")
eq(merged.played.a.totalSeconds, 10, "keep played records")
eq(defaults.overlay.enabled, true, "defaults untouched")
eq(defaults.general.showMinimapIcon, true, "general defaults untouched")

local magePair = Logic.ClassPairFromRgb(0.25, 0.78, 0.92)
eq(magePair.left.r < magePair.right.r, true, "class pair darkens left")
eq(Logic.ReactionKey(8), "friendly", "reaction friendly")
eq(Logic.ReactionKey(2), "enemy", "reaction enemy")
eq(Logic.ReactionKey(4), "neutral", "reaction neutral")

local g = Logic.BuildGradientDefaults()
eq(math.floor(g.classes.MAGE.left.r * 255 + 0.5), 0, "mage left r")
eq(math.floor(g.classes.MAGE.left.g * 255 + 0.5), 128, "mage left g")
eq(math.floor(g.classes.MAGE.left.b * 255 + 0.5), 215, "mage left b")
eq(math.floor(g.classes.EVOKER.right.r * 255 + 0.5), 50, "evoker right r")
eq(math.floor(g.classes.EVOKER.right.g * 255 + 0.5), 254, "evoker right g")
eq(math.floor(g.classes.EVOKER.right.b * 255 + 0.5), 220, "evoker right b")
eq(math.floor(g.npc.friendly.left.r * 255 + 0.5), 47, "friendly left r")
eq(math.floor(g.npc.friendly.right.g * 255 + 0.5), 217, "friendly right g")
eq(math.floor(g.npc.enemy.left.r * 255 + 0.5), 200, "enemy left r")
eq(math.floor(g.npc.neutral.right.b * 255 + 0.5), 73, "neutral right b")
eq(math.floor(g.power.mana.left.r * 255 + 0.5), 26, "mana left r")
eq(math.floor(g.power.runicPower.right.b * 255 + 0.5), 251, "runic right b")
eq(math.floor(g.castbar.regular.right.g * 255 + 0.5), 178, "cast regular right g")
eq(math.floor(g.castbar.nonInterruptible.right.r * 255 + 0.5), 142, "cast nonint right r")
eq(math.floor(g.classResources.comboPoint1.left.r * 255 + 0.5), 134, "cp1 left r")
eq(math.floor(g.classResources.chi.right.g * 255 + 0.5), 255, "chi right g")
eq(math.floor(g.classResources.deathRunes.right.b * 255 + 0.5), 255, "death runes right b")
eq(g.nameplatesEnabled, false, "nameplates disabled by default")
eq(g.nameplateFadeDirection, "RIGHT", "nameplate fade default")
eq(math.floor(g.nameplateThreat.good.left.g * 255 + 0.5), 158, "threat good left g")
eq(math.floor(g.nameplateClassification.caster.right.b * 255 + 0.5), 224, "caster right b")
local pickedDead = Logic.PickGradientPair(g, { dead = true, isPlayer = true, classFile = "MAGE" })
eq(pickedDead, g.states.dead, "dead beats class")
local pickedMage = Logic.PickGradientPair(g, { isPlayer = true, classFile = "MAGE" })
eq(pickedMage, g.classes.MAGE, "player class pair")
local pickedEnemy = Logic.PickGradientPair(g, { isPlayer = false, reactionKey = "enemy" })
eq(pickedEnemy, g.npc.enemy, "npc enemy pair")
local pickedFallback = Logic.PickGradientPair(g, { isPlayer = false })
eq(pickedFallback, g.npc.neutral, "npc neutral fallback")


eq(Logic.HealthBelowFull(100, 100, false), false, "full health does not reveal")
eq(Logic.HealthBelowFull(99, 100, false), true, "just under full reveals")
eq(Logic.HealthBelowFull(50, 100, false), true, "injured reveals")
eq(Logic.HealthBelowFull(110, 100, false), false, "above max does not reveal")
eq(Logic.HealthBelowFull(50, 100, true), false, "secret values never reveal")
eq(Logic.HealthBelowFull(50, 0, false), false, "zero max health never reveals")
eq(Logic.HealthBelowFull(nil, 100, false), false, "missing health never reveals")

eq(Logic.IsHealthBarKey("Health"), true, "health key")
eq(Logic.IsHealthBarKey("_health"), true, "raid health key")
eq(Logic.IsHealthBarKey("healthBar"), true, "healthBar key")
eq(Logic.IsHealthBarKey("powerBar"), false, "power excluded")
eq(Logic.IsHealthBarKey("castBar"), false, "cast excluded")
eq(Logic.IsHealthBarKey("absorbBar"), false, "absorb excluded")

local summary = Logic.PlayedSummary({
  a = { classFile = "MAGE", totalSeconds = 30 },
  b = { classFile = "MAGE", totalSeconds = 10 },
  c = { classFile = "WARRIOR", totalSeconds = 60 },
})
eq(summary.account, 100, "account total")
eq(summary.byClass.MAGE, 40, "mage total")
eq(Logic.ClassFraction(40, 100), 0.4, "class fraction")
eq(Logic.ClassFraction(40, 0), 0, "empty account")

eq(Logic.FormatDuration(nil), "\226\128\148", "missing duration")
eq(Logic.FormatDuration(90), "1m", "minutes")
eq(Logic.FormatDuration(3700), "1h 1m", "hours")
eq(Logic.FormatClock(65), "01:05", "clock")

eq(Logic.AnchorSide(400, 280, 12), "LEFT", "room on the left")
eq(Logic.AnchorSide(100, 280, 12), "RIGHT", "no room on the left")
eq(Logic.CanRequestPlayed(100, nil), true, "first request")
eq(Logic.CanRequestPlayed(100, 50), false, "too soon")
eq(Logic.CanRequestPlayed(110, 50), true, "sixty seconds elapsed")

eq(Logic.AfkBlocked({ enabled = true, isAFK = true, locked = false, cinematic = false, movie = false, casting = false }), false, "enter afk")
eq(Logic.AfkBlocked({ enabled = true, isAFK = true, locked = true, cinematic = false, movie = false, casting = false }), true, "combat blocks afk")
eq(Logic.AfkBlocked({ enabled = true, isAFK = true, locked = false, cinematic = false, movie = false, casting = true }), true, "cast blocks afk")
eq(Logic.AfkSuppressed(10, 70), true, "inside suppress window")
eq(Logic.AfkSuppressed(70, 70), false, "suppress expired")

eq(Logic.AfkLayoutScale(1920, 1080), 1, "1080p baseline")
eq(Logic.AfkLayoutScale(1280, 720), 0.7, "720p clamps to floor")
eq(Logic.AfkLayoutScale(3840, 2160), 1.15, "4k clamps to ceiling")

do
  local seen = {}
  local count = 0
  for classFile in pairs(Logic.FABLED_CLASS_CELLS) do
    local l, r, t, b = Logic.FabledClassTexCoords(classFile)
    count = count + 1
    eq(type(l) == "number" and l >= 0 and r <= 1 and t >= 0 and b <= 1 and l < r and t < b, true, "fabled coords in range " .. classFile)
    local key = string.format("%.4f,%.4f", l, t)
    eq(seen[key], nil, "fabled cell unique " .. classFile)
    seen[key] = true
  end
  eq(count, 13, "fabled sheet covers all 13 classes")
  local l, r, t, b = Logic.FabledClassTexCoords("WARRIOR")
  eq(l, 0.125, "warrior left")
  eq(r, 0.25, "warrior right")
  eq(t, 0, "warrior top")
  eq(b, 0.125, "warrior bottom")
  eq(Logic.FabledClassTexCoords("NOPE"), nil, "unknown class has no icon")
  eq(Logic.FabledClassTexCoords(nil), nil, "nil class has no icon")
end

do
  eq(Logic.AfkIdentityLine(80, "Enhancement", "Shaman"), "Lv 80 - Enhancement - Shaman", "identity line with spec")
  eq(Logic.AfkIdentityLine(80, nil, "Shaman"), "Lv 80 - Shaman", "identity line without spec")
  eq(Logic.AfkIdentityLine(80, "", "Shaman"), "Lv 80 - Shaman", "empty spec skipped")
  eq(Logic.AfkIdentityLine(nil, nil, "Shaman"), "Shaman", "missing level skipped")
  eq(Logic.DisplayName("Tester"), "Tester", "single name")
  eq(Logic.DisplayName("Tester-Nebuchadnezzar"), "Tester", "realm suffix dropped")
  eq(Logic.DisplayName("  Ada   Lovelace "), "Ada Lovelace", "first and last name")
  eq(Logic.DisplayName("Ada Byron Lovelace"), "Ada Lovelace", "middle words dropped")
  eq(Logic.DisplayName(nil), "", "nil name")

  local function names(name) return function() return nil, name end end
  -- Retail / MoP+: spec index
  eq(Logic.ResolveSpecName({ GetSpecialization = function() return 2 end, GetSpecializationInfo = function() return 263, "Enhancement" end }, "Shaman"), "Enhancement", "spec index path")
  -- Spec info that just repeats the class is rejected, then the talent trees decide
  local classic = {
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = names("Shaman"),
    GetNumTalentTabs = function() return 3 end,
    GetTalentTabInfo = function(tab)
      local tabs = { { "Elemental", "i", 3 }, { "Enhancement", "i", 31 }, { "Restoration", "i", 0 } }
      return unpack(tabs[tab])
    end,
  }
  local name, source = Logic.ResolveSpecName(classic, "Shaman")
  eq(name, "Enhancement", "classic tree with most points")
  eq(source, "GetTalentTabInfo", "classic source")
  -- Cata+ shape: id, name, description, icon, pointsSpent
  eq(Logic.ResolveSpecName({
    GetPrimaryTalentTree = function() return 3 end,
    GetTalentTabInfo = function(tab) return 100 + tab, "Tree" .. tab, "d", "i", 0 end,
  }, "Shaman"), "Tree3", "primary talent tree path")
  eq(Logic.ResolveSpecName({
    GetNumTalentTabs = function() return 2 end,
    GetTalentTabInfo = function(tab) return 100 + tab, "Tree" .. tab, "d", "i", tab == 2 and 5 or 1 end,
  }, "Shaman"), "Tree2", "cata-shaped tabs pick the most points")
  -- Nothing usable: no spec rather than the class name
  eq(Logic.ResolveSpecName({ GetSpecialization = function() return 1 end, GetSpecializationInfo = names("Shaman") }, "Shaman"), nil, "class name is not a spec")
  eq(Logic.ResolveSpecName({ GetSpecialization = function() return 0 end }, "Shaman"), nil, "no spec chosen")
  eq(Logic.ResolveSpecName({ GetSpecialization = function() error("boom") end }, "Shaman"), nil, "erroring API is ignored")
  -- A wrong Retail-style answer loses to the talent tree with the points
  eq(Logic.ResolveSpecName({
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function() return 262, "Elemental" end,
    GetNumTalentTabs = function() return 3 end,
    GetTalentTabInfo = function(tab)
      local tabs = { { "Elemental", "i", 0 }, { "Enhancement", "i", 41 }, { "Restoration", "i", 5 } }
      return unpack(tabs[tab])
    end,
  }, "Shaman"), "Enhancement", "talent points beat a wrong spec index")
  -- Forever shape: the spec index only yields the class name, the id may resolve elsewhere
  local forever = {
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function() return 1489, "Shaman", "", 626006, "DAMAGER" end,
  }
  eq(Logic.ResolveSpecName(forever, "Shaman", 7), nil, "forever class-name-only spec stays hidden")
  forever.GetSpecializationInfoByID = function(id) return id, id == 1489 and "Enhancement" or "Shaman" end
  local name, source = Logic.ResolveSpecName(forever, "Shaman", 7)
  eq(name, "Enhancement", "spec id resolved through GetSpecializationInfoByID")
  eq(source, "GetSpecializationInfoByID", "by-id source")
  forever.GetSpecializationInfoByID = nil
  forever.GetSpecializationNameForSpecID = function() return "Enhancement" end
  eq(Logic.ResolveSpecName(forever, "Shaman", 7), "Enhancement", "spec id resolved through GetSpecializationNameForSpecID")
  forever.GetSpecializationNameForSpecID = nil
  forever.GetNumSpecializationsForClassID = function() return 3 end
  forever.GetSpecializationInfoForClassID = function(classId, i)
    local list = { { 1488, "Elemental" }, { 1489, "Enhancement" }, { 1490, "Restoration" } }
    return list[i][1], list[i][2]
  end
  name, source = Logic.ResolveSpecName(forever, "Shaman", 7)
  eq(name, "Enhancement", "spec id matched in the class spec list")
  eq(source, "GetSpecializationInfoForClassID", "class list source")
  forever.GetSpecializationInfoForClassID = function() return nil end
  forever.GetInspectSpecialization = function() return 1489 end
  forever.GetSpecializationInfoByID = function() return 1489, "Enhancement" end
  eq(Logic.ResolveSpecName({ GetInspectSpecialization = forever.GetInspectSpecialization, GetSpecializationInfoByID = forever.GetSpecializationInfoByID }, "Shaman", 7), "Enhancement", "inspect spec id path")
  eq(Logic.ResolveSpecName({}, "Shaman"), nil, "no talent API")
  eq(Logic.ResolveSpecName({ GetNumTalentTabs = function() return 3 end, GetTalentTabInfo = function(t) return "Tree" .. t, "i", 0 end }, "Shaman"), nil, "no points spent")
end
eq(Logic.FadeShadeAlpha(50), 0.50, "shared fade mid")
eq(Logic.FadeShadeAlpha(nil), 0.50, "shared fade nil default")
eq(Logic.FadeShadeAlpha(0), 0, "shared fade min")
eq(Logic.FadeShadeAlpha(100), 1, "shared fade max")
eq(Logic.FadeShadeAlpha(150), 1, "shared fade clamp high")
eq(Logic.FadeShadeAlpha(nil), 0.50, "shared default fade")
eq(Logic.ShadeAlpha(-10, 50), 0, "shade clamp low")
eq(Logic.FADE_BACKGROUND_DEFAULT, 50, "shared fade default constant")
eq(Logic.GrainAlpha(40), 0.40, "grain strength fixed look")
eq(Logic.GrainAlpha(nil), 0.40, "grain strength nil uses fixed")
eq(Logic.GrainAlpha(0), 0, "grain strength off")
eq(Logic.GrainAlpha(150), 1, "grain strength clamp")
eq(Logic.GrainTileSize(1), 32, "grain tile fixed look")
eq(Logic.GrainTileSize(nil), 32, "grain tile nil uses fixed")
eq(Logic.GrainTileSize(10), 176, "grain tile max")
eq(Logic.FADE_GRAIN_STRENGTH, 40, "fade grain strength constant")
eq(Logic.FADE_GRAIN_SCALE, 1, "fade grain scale constant")

eq(Logic.AfkLayoutScale(0, 1080), 1, "bad width defaults")
assert(math.abs(Logic.AfkLayoutScale(1600, 900) - (1600 / 1920)) < 1e-9, "900p proportional")

eq(Logic.EllesmereEntryVisible({ forever = true }, true), true, "forever entry on forever")
eq(Logic.EllesmereEntryVisible({ forever = true }, false), false, "forever entry on retail")
eq(Logic.EllesmereEntryVisible({ retail = true }, true), false, "retail entry on forever")
eq(Logic.EllesmereEntryVisible({ retail = true }, false), true, "retail entry on retail")
eq(Logic.EllesmereEntryVisible({ title = "x" }, true), true, "shared entry")

local hNil, bNil = Logic.FormatEllesmereChangelog(nil, true)
eq(hNil, nil, "missing patches header")
eq(bNil, nil, "missing patches body")

local sample = {
  {
    version = "9.8.4",
    features = {
      { forever = true, title = "Divine Spirit", desc = "Priest raid buff reminder" },
      { retail = true, title = "Group Notes", desc = "Show notes" },
      { title = "Pins", desc = "Per character pins" },
    },
    fixes = {
      { text = "Bags categories work" },
      { forever = true, text = "Friends ruleset label" },
      { retail = true, text = "Premade portal menu" },
    },
  },
}
local hF, bF = Logic.FormatEllesmereChangelog(sample, true, 8, 8)
eq(hF, "Latest changelog for 9.8.4", "forever header")
assert(type(bF) == "string" and bF:find("Divine Spirit", 1, true), "forever feature kept")
assert(type(bF) == "string" and bF:find("Pins", 1, true), "shared feature kept")
assert(type(bF) == "string" and not bF:find("Group Notes", 1, true), "retail feature dropped on forever")
assert(type(bF) == "string" and bF:find("Friends ruleset", 1, true), "forever fix kept")
assert(type(bF) == "string" and not bF:find("Premade portal", 1, true), "retail fix dropped on forever")
assert(type(bF) == "string" and bF:find("NEW FEATURES", 1, true), "features category")
assert(type(bF) == "string" and bF:find("BUG FIXES", 1, true), "fixes category")

local viewF = Logic.BuildEllesmereChangelogView(sample, true, 8, 8)
eq(viewF.version, "9.8.4", "view version")
eq(#viewF.features, 2, "forever features count")
eq(viewF.features[1].primary, "WOW FOREVER", "forever tag")
eq(viewF.features[1].title, "Divine Spirit", "feature title")
eq(#viewF.fixes, 2, "forever fixes count")

local p, s = Logic.EllesmereEntryTags({ forever = true, module = "Bags" })
eq(p, "WOW FOREVER", "tag primary")
eq(s, "BAGS", "tag secondary")

local hR, bR = Logic.FormatEllesmereChangelog(sample, false, 8, 8)
assert(type(bR) == "string" and bR:find("Group Notes", 1, true), "retail feature kept")
assert(type(bR) == "string" and not bR:find("Divine Spirit", 1, true), "forever feature dropped on retail")

local r, g, b = Logic.ClassRgb("SHAMAN", nil)
eq(r, 0.00, "shaman r")
eq(g, 0.44, "shaman g")
eq(b, 0.87, "shaman b")


-- Accent color logic (settings window)
do
  local d = Logic.BuildAccentDefaults()
  eq(d.mode, "preset", "accent default mode")
  eq(d.preset, Logic.ACCENT_DEFAULT_PRESET, "accent default preset")
  local br, bg, bb = Logic.GetAccentColor(d, nil)
  eq(br, Logic.AccentPreset("blue").r, "default accent is blue r")
  eq(bg, 0.62, "default accent is blue g")
  eq(bb, 1.0, "default accent is blue b")

  local pr, pg, pb = Logic.GetAccentColor({ mode = "preset", preset = "gold" }, nil)
  eq(pr, 0.94, "preset gold r")
  eq(pg, 0.77, "preset gold g")
  eq(pb, 0.16, "preset gold b")
  local ur = Logic.GetAccentColor({ mode = "preset", preset = "nope" }, nil)
  eq(ur, Logic.AccentPreset("blue").r, "unknown preset falls back")

  local cr, cg, cb = Logic.GetAccentColor({ mode = "custom", r = 0.1, g = 0.2, b = 0.3 }, nil)
  eq(cr, 0.1, "custom r")
  eq(cg, 0.2, "custom g")
  eq(cb, 0.3, "custom b")
  local clr, clg, clb = Logic.GetAccentColor({ mode = "custom", r = 5, g = -1, b = 0.5 }, nil)
  eq(clr, 1, "custom clamps high")
  eq(clg, 0, "custom clamps low")
  eq(clb, 0.5, "custom keeps mid")
  eq(Logic.GetAccentColor({ mode = "custom", r = "x" }, nil), Logic.AccentPreset("blue").r, "custom bad data falls back")

  local kr, kg, kb = Logic.GetAccentColor({ mode = "class", preset = "gold" }, { r = 0.78, g = 0.61, b = 0.43 })
  eq(kr, 0.78, "class mode uses class r")
  eq(kg, 0.61, "class mode uses class g")
  eq(kb, 0.43, "class mode uses class b")
  eq(Logic.GetAccentColor({ mode = "class" }, nil), Logic.AccentPreset("blue").r, "class mode without class falls back")
  eq(Logic.GetAccentColor({ mode = "bogus", preset = "gold" }, nil), 0.94, "unknown mode acts as preset")
  eq(Logic.GetAccentColor(nil, nil), Logic.AccentPreset("blue").r, "nil accent falls back")
  eq(Logic.GetAccentColor("bad", nil), Logic.AccentPreset("blue").r, "non-table accent falls back")

  eq(#Logic.ACCENT_PRESETS, 7, "seven accent presets")
  local seenKey = {}
  for i = 1, #Logic.ACCENT_PRESETS do
    local preset = Logic.ACCENT_PRESETS[i]
    eq(seenKey[preset.key], nil, "unique preset " .. preset.key)
    seenKey[preset.key] = true
  end

  local tr = Logic.AccentTextColor(0.94, 0.77, 0.16)
  eq(tr < 0.2, true, "dark text on gold")
  eq(Logic.AccentTextColor(0.25, 0.30, 0.9), 1, "white text on dark blue")
  local sr, sg, sb = Logic.ShadeColor(0.8, 0.4, 0.2, 0.5)
  eq(math.abs(sr - 0.4) < 1e-9, true, "shade r")
  eq(math.abs(sg - 0.2) < 1e-9, true, "shade g")
  eq(math.abs(sb - 0.1) < 1e-9, true, "shade b")

  local merged = Logic.MergeDefaults({ general = { accent = { mode = "class" } } }, { general = { accent = d } })
  eq(merged.general.accent.mode, "class", "saved accent mode kept")
  eq(merged.general.accent.preset, "blue", "missing accent keys filled")
  local fresh = Logic.MergeDefaults({}, { general = { accent = d } })
  eq(fresh.general.accent.mode, "preset", "fresh install gets default accent")
end

eq(Logic.PrefixMediaName("Doris PP"), "Rk Doris PP", "prefix adds Rk")
eq(Logic.PrefixMediaName("Rk Doris PP"), "Rk Doris PP", "prefix idempotent")
eq(Logic.PrefixMediaName("Rk"), "Rk RakaMod", "bare Rk becomes Rk RakaMod")
do
  local legacy = Logic.BuildLegacyMediaNames({ { "Rk Doris PP", "x" }, { "Rk ToxiUI Clean", "y" } })
  eq(legacy["Doris PP"], "Rk Doris PP", "legacy map builds")
  local saved = { font = "Doris PP", nested = { bar = "ToxiUI Clean", keep = "Other" }, played = { ["Doris PP"] = "x" } }
  Logic.MigrateMediaNames(saved, legacy)
  eq(saved.font, "Rk Doris PP", "migrate top-level name")
  eq(saved.nested.bar, "Rk ToxiUI Clean", "migrate nested name")
  eq(saved.nested.keep, "Other", "migrate leaves unknown")
  eq(saved.played["Doris PP"], "x", "migrate skips played")
  eq(saved.mediaMigration, Logic.MEDIA_MIGRATION_VERSION, "migration flag set")
  saved.font = "Doris PP"
  Logic.MigrateMediaNames(saved, legacy)
  eq(saved.font, "Doris PP", "migration runs once")
end

-- Bar kinds, power, resource, threat and classification keys ----------------------------
do
  local L = Logic
  eq(L.BarKindFromKey("healthBar"), "health", "health field")
  eq(L.BarKindFromKey("health"), "health", "plain health field")
  eq(L.BarKindFromKey("powerBar"), "power", "power field")
  eq(L.BarKindFromKey("manaBar"), "power", "mana field")
  eq(L.BarKindFromKey("castBar"), "castbar", "cast field")
  eq(L.BarKindFromKey("channelBar"), "castbar", "channel field")
  eq(L.BarKindFromKey("classPower"), "resource", "class power is a resource, not a power bar")
  eq(L.BarKindFromKey("holyPowerBar"), "resource", "holy power is a resource")
  eq(L.BarKindFromKey("runes"), "resource", "runes are a resource")
  eq(L.BarKindFromKey("chi"), "resource", "chi is a resource")
  eq(L.BarKindFromKey("healAbsorbBar"), nil, "absorb bars are never painted")
  eq(L.BarKindFromKey("healthPrediction"), nil, "prediction bars are never painted")
  eq(L.BarKindFromKey("castBarBackground"), nil, "backgrounds are never painted")
  eq(L.BarKindFromKey("name"), nil, "unrelated field")
  eq(L.BarKindFromKey(3), nil, "numeric field")

  eq(L.PowerKey("MANA", 0), "mana", "mana token")
  eq(L.PowerKey("RUNIC_POWER"), "runicPower", "runic power token")
  eq(L.PowerKey(nil, 3), "energy", "energy by id")
  eq(L.PowerKey("FURY", 17), nil, "unconfigured power type")

  eq(L.ResourceKey("ROGUE", 3), "comboPoint3", "rogue combo point pip")
  eq(L.ResourceKey("DRUID", 6), nil, "combo point pip out of range")
  eq(L.ResourceKey("PALADIN", 2), "holyPower", "holy power")
  eq(L.ResourceKey("MONK", 1), "chi", "chi")
  eq(L.ResourceKey("WARLOCK", 1), "soulShards", "soul shards")
  eq(L.ResourceKey("DEATHKNIGHT", 1, 2), "frostRunes", "frost rune spec")
  eq(L.ResourceKey("DEATHKNIGHT", 1, nil), "deathRunes", "death knight without a spec")
  eq(L.ResourceKey("MAGE", 1), nil, "classes without a resource bar")

  eq(L.ThreatKey(nil, true, true, false), nil, "no threat information")
  eq(L.ThreatKey(3, false, false, false), "solo", "ungrouped is solo")
  eq(L.ThreatKey(3, true, true, false), "good", "tank holding aggro")
  eq(L.ThreatKey(2, true, true, false), "goodTransition", "tank losing aggro")
  eq(L.ThreatKey(0, true, true, true), "offTank", "another tank holds it")
  eq(L.ThreatKey(1, true, true, true), "offTankBad", "tank about to pull from the off tank")
  eq(L.ThreatKey(0, true, true, false), "bad", "tank lost aggro to a non-tank")
  eq(L.ThreatKey(3, false, true, false), "bad", "non-tank with aggro")
  eq(L.ThreatKey(1, false, true, false), "badTransition", "non-tank about to pull")
  eq(L.ThreatKey(0, false, true, true), "offTankGood", "non-tank, off tank holds it")
  eq(L.ThreatKey(0, false, true, false), "good", "non-tank, nothing wrong")

  eq(L.ClassificationKey("worldboss", 80, false, nil), "worldBoss", "world boss")
  eq(L.ClassificationKey("rareelite", 80, false, nil), "rareElite", "rare elite")
  eq(L.ClassificationKey("rare", 80, false, nil), "rare", "rare")
  eq(L.ClassificationKey("elite", -1, false, nil), "eliteBoss", "skull level elite is a boss")
  eq(L.ClassificationKey("elite", 80, true, nil), "eliteBoss", "boss unit")
  eq(L.ClassificationKey("elite", 80, false, nil), "eliteMini", "plain elite")
  eq(L.ClassificationKey("normal", 80, false, "MAGE"), "caster", "caster mob")
  eq(L.ClassificationKey("normal", 80, false, "WARRIOR"), nil, "ordinary mob")
  eq(L.ClassificationKey(nil, 80, false, nil), nil, "unknown classification")

  local d = L.BuildGradientDefaults()
  eq(d.powerEnabled, false, "power painting is off by default")
  eq(d.castbarEnabled, false, "cast bar painting is off by default")
  eq(d.resourcesEnabled, false, "resource painting is off by default")

  eq(L.PickNameplatePair(d, { threatKey = "bad", isPlayer = false, reactionKey = "enemy" }), d.nameplateThreat.bad, "threat wins on nameplates")
  eq(L.PickNameplatePair(d, { classificationKey = "rare", isPlayer = false, reactionKey = "enemy" }), d.nameplateClassification.rare, "classification is next")
  eq(L.PickNameplatePair(d, { dead = true, threatKey = "bad", isPlayer = false }), d.states.dead, "state colors beat threat")
  eq(L.PickNameplatePair(d, { isPlayer = false, reactionKey = "enemy" }), d.npc.enemy, "nameplates fall back to the unit frame choice")

  eq(L.PickBarPair(d, "power", { powerKey = "rage" }), d.power.rage, "power pair")
  eq(L.PickBarPair(d, "power", { powerKey = nil }), nil, "no power pair without a key")
  eq(L.PickBarPair(d, "castbar", { nonInterruptible = false }), d.castbar.regular, "regular cast pair")
  eq(L.PickBarPair(d, "castbar", { nonInterruptible = true }), d.castbar.nonInterruptible, "non-interruptible cast pair")
  eq(L.PickBarPair(d, "resource", { resourceKey = "chi" }), d.classResources.chi, "resource pair")

  local a, b = L.OrientPair({ left = "L", right = "R" }, "RIGHT")
  eq(a .. b, "LR", "RIGHT keeps the pair order")
  a, b = L.OrientPair({ left = "L", right = "R" }, "LEFT")
  eq(a .. b, "RL", "LEFT swaps the pair")
end

-- General font size ---------------------------------------------------------------------
do
  local L = Logic
  eq(L.DEFAULT_UI_FONT_SIZE, 15, "default body size is the window's label size")
  eq(L.ScaledFontSize(14, 15), 14, "the default keeps the size")
  eq(L.ScaledFontSize(15, 24), 24, "the body size follows the setting")
  eq(L.ScaledFontSize(30, 12), 24, "other sizes keep their ratio")
  eq(L.ScaledFontSize(15, 6), 6, "6 is the smallest body size")
  eq(L.ScaledFontSize(12, 6), 6, "never below 6 points")
  eq(L.ScaledFontSize(15, 100), 24, "size is clamped to the maximum")
  eq(L.ScaledFontSize(15, 1), 6, "size is clamped to the minimum")
  eq(L.ScaledFontSize(14, nil), 14, "missing size means the default")
  eq(L.ScaledFontSize(nil, 15), nil, "non-numeric sizes pass through")
end

if failures > 0 then
  os.exit(1)
end
print("ok")
