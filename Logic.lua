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

RakaMod = RakaMod or {}
RakaMod.Logic = Logic
return Logic
