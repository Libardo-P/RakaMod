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
  overlay = { enabled = true, collections = true, played = true, professions = true },
  gradient = { enabled = false, left = { r = 0.91, g = 0.84, b = 0.64 }, right = { r = 0.15, g = 0.14, b = 0.13 } },
  played = {},
}
local merged = Logic.MergeDefaults({ overlay = { enabled = false }, gradient = "bad", played = { a = { totalSeconds = 10 } } }, defaults)
eq(merged.overlay.enabled, false, "keep saved bool")
eq(merged.overlay.collections, true, "fill missing key")
eq(merged.gradient.enabled, false, "reset bad section")
eq(merged.played.a.totalSeconds, 10, "keep played records")
eq(defaults.overlay.enabled, true, "defaults untouched")

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
