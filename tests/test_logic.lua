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

eq(Logic.HealthBelow(50, 100, 90, false), true, "hurt")
eq(Logic.HealthBelow(90, 100, 90, false), false, "exact threshold")
eq(Logic.HealthBelow(10, 100, 90, true), false, "secret health")

eq(Logic.HealthAboveFull(100, 100, 0, false), false, "full no absorb")
eq(Logic.HealthAboveFull(100, 100, 10, false), true, "absorb over 100")
eq(Logic.HealthAboveFull(110, 100, 0, false), true, "current above max")
eq(Logic.HealthAboveFull(90, 100, 5, false), false, "injured with small absorb")
eq(Logic.HealthAboveFull(100, 100, 10, true), false, "secret above full")

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
eq(Logic.FadeShadeAlpha(50), 0.50, "shared fade mid")
eq(Logic.FadeShadeAlpha(nil), 0.50, "shared fade nil default")
eq(Logic.FadeShadeAlpha(0), 0, "shared fade min")
eq(Logic.FadeShadeAlpha(100), 1, "shared fade max")
eq(Logic.FadeShadeAlpha(150), 1, "shared fade clamp high")
eq(Logic.AfkShadeAlpha(nil), 0.50, "afk alias uses shared default")
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

if failures > 0 then
  os.exit(1)
end
print("ok")

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
