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

if failures > 0 then
  os.exit(1)
end
print("ok")
