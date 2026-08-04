local ADDON, ns = ...

local VALID = { tank = true, healer = true, melee = true, ranged = true }

function ns.FindRosterPlayer(calName)
  if not calName or calName == "" then return nil end
  local bare = calName:match("^[^-]+") or calName
  local key = ns.NormalizeName(bare)
  local fullKey = ns.NormalizeName(calName)
  local players = ns.db.players or {}

  local p = players[key] or players[fullKey]
  if p then return p end

  for _, pl in pairs(players) do
    local pn = ns.NormalizeName(pl.name)
    local pbare = pn:match("^[^-]+") or pn
    if pn == key or pbare == key or pn == fullKey or pbare == ns.NormalizeName(bare) then
      return pl
    end
  end
  return nil
end

local function classToken(invitee, rosterPlayer)
  if rosterPlayer and rosterPlayer.class then
    return ns.NormalizeClass(rosterPlayer.class)
  end
  return ns.NormalizeClass(invitee.classFilename or invitee.className)
end

local function dpsSplit(token)
  if token and ns.MeleeClasses[token] then
    return "melee"
  end
  return "ranged"
end

local function classCanRole(def, role)
  if not def or not role then return false end
  if def.primary == role then return true end
  for _, r in ipairs(def.off or {}) do
    if r == role then return true end
  end
  return false
end

--- Build MAIN/OFF map from GP roster + class defaults.
-- Roster match: MAIN = primaryRole only; OFF only if roster.offRoles says so
-- (and the class can actually play that role). No class-default OFF pollution.
-- No roster: class primary MAIN + class off list as OFF.
-- Returns { tank = "MAIN"|"OFF"|nil, ... }, source, rosterPlayer
function ns.GetDefaultRoleMap(invitee)
  local roster = ns.FindRosterPlayer(invitee.name)
  local token = classToken(invitee, roster)
  local map = { tank = nil, healer = nil, melee = nil, ranged = nil }
  local def = (token and ns.ClassRoleDefaults[token]) or { primary = "melee", off = {} }

  if not roster then
    map[def.primary] = "MAIN"
    for _, r in ipairs(def.off or {}) do
      if VALID[r] and map[r] ~= "MAIN" then map[r] = "OFF" end
    end
    return map, "class", nil
  end

  local primary = string.lower(strtrim(tostring(roster.primaryRole or "")))
  local ovKey = ns.NormalizeName(roster.name or invitee.name)
  local ov = ovKey and ns.db.mainRoleOverrides and ns.db.mainRoleOverrides[ovKey]
  if ov == "tank" or ov == "healer" or ov == "melee" or ov == "ranged" then
    primary = ov
  end
  local source = "roster"

  if primary == "tank" then
    map.tank = "MAIN"
  elseif primary == "healer" then
    map.healer = "MAIN"
  elseif primary == "melee" or primary == "ranged" then
    map[primary] = "MAIN"
  elseif primary == "dps" then
    map[dpsSplit(token)] = "MAIN"
  else
    map[def.primary] = "MAIN"
    source = "class"
  end

  -- Extra columns only when roster lists that off-role AND class can play it
  for _, r in ipairs(roster.offRoles or {}) do
    r = string.lower(strtrim(tostring(r)))
    if r == "tank" and map.tank ~= "MAIN" and classCanRole(def, "tank") then
      map.tank = "OFF"
    elseif r == "healer" and map.healer ~= "MAIN" and classCanRole(def, "healer") then
      map.healer = "OFF"
    elseif r == "dps" then
      local split = dpsSplit(token)
      local other = split == "melee" and "ranged" or "melee"
      if primary == "tank" or primary == "healer" then
        -- Tank/heal with DPS off: place on class DPS lane(s)
        if map[split] ~= "MAIN" and classCanRole(def, split) then map[split] = "OFF" end
        if map[other] ~= "MAIN" and classCanRole(def, other) then map[other] = "OFF" end
      elseif map[other] ~= "MAIN" and classCanRole(def, other) then
        -- DPS primary: off-dps only means the other melee/range lane
        map[other] = "OFF"
      end
    end
  end

  return map, source, roster
end

function ns.PlayerCalKey(name)
  if not name then return nil end
  if name:find("-", 1, true) then return name end
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or "Unknown"
  realm = tostring(realm):gsub("%s", "")
  return name .. "-" .. realm
end

function ns.GetRoleOverride(playerKey)
  local db = ns.db
  db.calendarRoleOverrides = db.calendarRoleOverrides or {}
  return db.calendarRoleOverrides[playerKey]
end

function ns.SetRoleOverride(playerKey, role, state)
  if not playerKey or not VALID[role] then return end
  ns.db.calendarRoleOverrides = ns.db.calendarRoleOverrides or {}
  ns.db.calendarRoleOverrides[playerKey] = ns.db.calendarRoleOverrides[playerKey] or {}
  if state == nil then
    ns.db.calendarRoleOverrides[playerKey][role] = nil
  else
    ns.db.calendarRoleOverrides[playerKey][role] = state
  end
end

function ns.GetEffectiveCalRole(invitee, role)
  local key = ns.PlayerCalKey(invitee.name)
  local ov = ns.GetRoleOverride(key)
  if ov and ov[role] ~= nil then
    if ov[role] == "HIDDEN" then return nil end
    return ov[role]
  end
  local map = ns.GetDefaultRoleMap(invitee)
  return map[role]
end

function ns.CycleCalRole(invitee, role)
  local key = ns.PlayerCalKey(invitee.name)
  local cur = ns.GetEffectiveCalRole(invitee, role)
  if cur == "MAIN" then
    ns.SetRoleOverride(key, role, "OFF")
  elseif cur == "OFF" then
    ns.SetRoleOverride(key, role, "HIDDEN")
  else
    ns.SetRoleOverride(key, role, "MAIN")
  end
end

local OFF_SHORT = { tank = "T", healer = "H", melee = "M", ranged = "R" }

--- Off-roles the player can fill (not MAIN). For display next to MAIN only.
function ns.GetCalOffRoles(invitee)
  local offs = {}
  for _, role in ipairs(ns.CAL_ROLE_ORDER) do
    if ns.GetEffectiveCalRole(invitee, role) == "OFF" then
      offs[#offs + 1] = role
    end
  end
  return offs
end

function ns.FormatCalOffLabel(invitee)
  local offs = ns.GetCalOffRoles(invitee)
  if #offs == 0 then return "" end
  local bits = {}
  for _, r in ipairs(offs) do
    bits[#bits + 1] = OFF_SHORT[r] or r
  end
  return (ns.L["OFF"] or "OFF") .. " " .. table.concat(bits, "/")
end

--- Accepted / confirmed for section headers (not mere invites).
local function isAcceptedStatus(status)
  -- 1 Available, 3 Confirmed, 6 Signed up
  return status == 1 or status == 3 or status == 6
end
ns.IsCalAcceptedStatus = isAcceptedStatus

--- Columns = MAIN role only (one row per player). OFF is display-only beside MAIN.
-- counts = only Available / Confirmed / Signed up (not Invited / Declined / etc.).
function ns.BuildCalColumns(invitees)
  local columns = { tank = {}, healer = {}, melee = {}, ranged = {} }
  local counts = { tank = 0, healer = 0, melee = 0, ranged = 0 }
  for _, p in ipairs(invitees or {}) do
    for _, role in ipairs(ns.CAL_ROLE_ORDER) do
      if ns.GetEffectiveCalRole(p, role) == "MAIN" then
        columns[role][#columns[role] + 1] = {
          player = p,
          state = "MAIN",
          offLabel = ns.FormatCalOffLabel(p),
        }
        if isAcceptedStatus(p.inviteStatus) then
          counts[role] = counts[role] + 1
        end
        break
      end
    end
  end
  for _, role in ipairs(ns.CAL_ROLE_ORDER) do
    table.sort(columns[role], function(a, b)
      -- Accepted first, then by name
      local aa = isAcceptedStatus(a.player.inviteStatus)
      local ba = isAcceptedStatus(b.player.inviteStatus)
      if aa ~= ba then return aa end
      return (a.player.name or "") < (b.player.name or "")
    end)
  end
  return columns, counts
end

local STATUS_LABEL = {
  [0] = "Invited",
  [1] = "Accepted",
  [2] = "Declined",
  [3] = "Confirmed",
  [4] = "Out",
  [5] = "Standby",
  [6] = "Signed up",
  [7] = "Not signed",
  [8] = "Tentative",
}

local function invitedLabel()
  local L = ns.L
  return (L and L["CAL_STATUS_0"]) or STATUS_LABEL[0] or "Invited"
end

--- Normalize invite status for UI: unknown / nil → Invited (0).
function ns.NormalizeCalendarStatus(status)
  local n = tonumber(status)
  if n == nil then return 0 end
  if STATUS_LABEL[n] ~= nil then return n end
  return 0
end

function ns.CalendarStatusLabel(status)
  local L = ns.L
  local n = ns.NormalizeCalendarStatus(status)
  local key = "CAL_STATUS_" .. tostring(n)
  if L and L[key] then return L[key] end
  return STATUS_LABEL[n] or invitedLabel()
end

function ns.CalendarStatusColor(status)
  local C = ns.Colors
  local n = ns.NormalizeCalendarStatus(status)
  if n == 3 or n == 6 or n == 1 then return C.ok end
  if n == 8 then return C.warn end
  if n == 2 or n == 4 then return C.bad end
  if n == 5 then return C.subtext end
  -- Invited (0) and unknown → subtext
  return C.subtext
end
