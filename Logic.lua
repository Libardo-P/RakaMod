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

function Logic.IsForever(interfaceVersion)
  return interfaceVersion == 16001
end

function Logic.HealthBelow(current, maxHealth, percent, secret)
  if secret then
    return false
  end
  if type(current) ~= "number" or type(maxHealth) ~= "number" or maxHealth <= 0 then
    return false
  end
  return (current / maxHealth) * 100 < percent
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

local function rgb(r, g, b)
  return { r = clamp01(r), g = clamp01(g), b = clamp01(b) }
end

local function pair(left, right)
  return { left = left, right = right }
end

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
    local c = (type(classColors) == "table" and classColors[file]) or Logic.CLASS_FALLBACK_COLORS[file]
    if type(c) ~= "table" then
      c = { r = 0.5, g = 0.5, b = 0.5 }
    end
    classes[file] = Logic.ClassPairFromRgb(c.r, c.g, c.b)
  end
  return {
    enabled = false,
    classes = classes,
    npc = {
      friendly = pair(rgb(0.20, 0.45, 0.20), rgb(0.35, 0.85, 0.35)),
      enemy = pair(rgb(0.55, 0.12, 0.12), rgb(0.95, 0.30, 0.30)),
      neutral = pair(rgb(0.55, 0.45, 0.20), rgb(0.95, 0.82, 0.40)),
    },
    states = {
      dead = pair(rgb(0.35, 0.35, 0.35), rgb(0.55, 0.55, 0.55)),
      offline = pair(rgb(0.25, 0.25, 0.30), rgb(0.45, 0.45, 0.55)),
      tapped = pair(rgb(0.40, 0.40, 0.40), rgb(0.65, 0.65, 0.65)),
      disconnected = pair(rgb(0.30, 0.20, 0.20), rgb(0.55, 0.35, 0.35)),
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
  if info.disconnected and type(states) == "table" and type(states.disconnected) == "table" then
    return states.disconnected
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
