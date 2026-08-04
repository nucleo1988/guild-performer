local ADDON, ns = ...

--- Local UI gate only (not security). Server still requires officer token for push.
--- Rank index 0 = guild master (GetGuildInfo). Officers = ranks 1..officerMaxRank (default 2).
function ns.CanEditRoster()
  if not IsInGuild or not IsInGuild() then
    return false
  end
  local _, _, rankIndex = GetGuildInfo("player")
  if rankIndex == 0 then
    return true
  end
  if IsGuildLeader and IsGuildLeader() then
    return true
  end
  if C_GuildInfo then
    if C_GuildInfo.IsGuildLeader then
      local ok, v = pcall(C_GuildInfo.IsGuildLeader)
      if ok and v then return true end
    end
    if C_GuildInfo.IsGuildOfficer then
      local ok, isOff = pcall(C_GuildInfo.IsGuildOfficer)
      if ok and isOff then return true end
    end
  end
  local maxOfficerRank = 2
  if ns.db and ns.db.settings and ns.db.settings.officerMaxRank ~= nil then
    maxOfficerRank = tonumber(ns.db.settings.officerMaxRank) or 2
  end
  if rankIndex ~= nil and rankIndex >= 0 and rankIndex <= maxOfficerRank then
    return true
  end
  return false
end

function ns.GuildEditDebugInfo()
  local inGuild = IsInGuild and IsInGuild() or false
  local gName, rankName, rankIndex = nil, nil, nil
  if inGuild and GetGuildInfo then
    gName, rankName, rankIndex = GetGuildInfo("player")
  end
  return {
    inGuild = inGuild,
    guild = gName,
    rankName = rankName,
    rankIndex = rankIndex,
    canEdit = ns.CanEditRoster and ns.CanEditRoster() or false,
  }
end

function ns.CanViewOfficerFields()
  return ns.CanEditRoster()
end

--- Members may edit their own character row; officers edit everyone.
function ns.CanEditPlayer(p)
  if ns.CanEditRoster and ns.CanEditRoster() then
    return true
  end
  if not p or not p.name then return false end
  local me = (UnitName and UnitName("player")) or ""
  return ns.NormalizeName(p.name) == ns.NormalizeName(me)
end

function ns.ClassColorText(className, text)
  local token = ns.NormalizeClass(className)
  local c = token and ns.CLASS_COLORS[token]
  if not c then return text end
  return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, text)
end

function ns.FlagLabel(flag)
  local map = {
    vacation = "Vacation",
    work = "Work",
    university = "University",
    personal = "Personal",
    uncertain = "Uncertain",
    mplus_only = "M+",
    deferred_launch = "Deferred",
    low_attendance = "Low att",
    reserve = "Reserve",
    offspec_useful = "Off-spec",
    non_raider = "Non-raider",
    alts = "Alts",
  }
  return map[flag] or flag
end

function ns.StatusLabel(status)
  local L = ns.L
  local key = "STATUS_" .. string.upper(tostring(status or ""))
  if L[key] then return L[key] end
  return status or "—"
end

function ns.LaunchLabel(launch)
  if launch == "day_one" then return ns.L["DAY_ONE"] or "Day One" end
  if launch == "deferred" then return ns.L["DEFERRED"] or "Deferred" end
  return launch ~= "" and launch or "—"
end

function ns.GetUniqueClasses()
  local seen, list = {}, {}
  for _, p in ipairs(ns.GetPlayersList()) do
    local c = p.class or ""
    if c ~= "" and not seen[c] then
      seen[c] = true
      list[#list + 1] = c
    end
  end
  table.sort(list)
  return list
end

function ns.Truncate(str, maxLen)
  str = tostring(str or "")
  if #str <= maxLen then return str end
  return str:sub(1, maxLen - 1) .. "…"
end

local CLASS_LABELS = {
  "Death Knight", "Demon Hunter", "Druid", "Evoker", "Hunter", "Mage",
  "Monk", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior",
}

function ns.ClassLabelOptions()
  local opts = {}
  for _, c in ipairs(CLASS_LABELS) do
    local token = ns.NormalizeClass(c)
    local col = token and ns.CLASS_COLORS and ns.CLASS_COLORS[token]
    local opt = { value = c, text = c }
    if col then
      opt.color = { col.r, col.g, col.b }
    end
    opts[#opts + 1] = opt
  end
  return opts
end

local function copyPlayer(p)
  local out = {}
  for k, v in pairs(p) do
    if type(v) == "table" then
      local t = {}
      for i, x in ipairs(v) do t[i] = x end
      -- also copy string keys if any
      for kk, vv in pairs(v) do
        if type(kk) ~= "number" then t[kk] = vv end
      end
      out[k] = t
    else
      out[k] = v
    end
  end
  return out
end

local function normalizeLane(role)
  role = string.lower(strtrim(tostring(role or "")))
  if role == "tank" or role == "healer" or role == "melee" or role == "ranged" or role == "dps" then
    return role
  end
  return "dps"
end

local function normalizeOffRoles(raw)
  local out, seen = {}, {}
  local list = raw
  if type(raw) == "string" then
    list = {}
    for part in string.gmatch(raw, "[^,]+") do
      list[#list + 1] = strtrim(part)
    end
  end
  if type(list) ~= "table" then return out end
  for _, r in ipairs(list) do
    r = normalizeLane(r)
    if (r == "tank" or r == "healer" or r == "melee" or r == "ranged" or r == "dps") and not seen[r] then
      seen[r] = true
      out[#out + 1] = r
    end
  end
  return out
end

local function rememberLocalEdit(key, p)
  ns.db.manualPlayers = ns.db.manualPlayers or {}
  local snap = copyPlayer(p)
  snap.localEdit = true
  ns.db.manualPlayers[key] = snap
end

--- Persist in-place row edits (status / launch / off / attendance / …).
function ns.MarkPlayerEdited(p)
  if not (ns.CanEditPlayer and ns.CanEditPlayer(p)) then return end
  if not p or not p.name then return end
  local key = ns.NormalizeName(p.name)
  if not key or key == "" then return end
  ns.db.deletedPlayers = ns.db.deletedPlayers or {}
  ns.db.deletedPlayers[key] = nil
  rememberLocalEdit(key, p)
  if ns.RequestPushPrep then ns.RequestPushPrep("roster_edit") end
end

--- Persist a manual roster entry (survives sync replace via manualPlayers).
function ns.AddManualPlayer(opts)
  if not (ns.CanEditRoster and ns.CanEditRoster()) then
    return nil, "readonly"
  end
  opts = opts or {}
  local name = strtrim(tostring(opts.name or ""))
  if name == "" then return nil, "empty_name" end
  local key = ns.NormalizeName(name)
  if ns.db.players and ns.db.players[key] then return nil, "exists" end
  local role = normalizeLane(opts.primaryRole or "dps")
  local prio = tonumber(opts.priority) or 3
  if prio < 1 or prio > 5 then prio = 3 end

  local p = {
    name = name,
    primaryRole = role,
    class = tostring(opts.class or ""),
    spec = tostring(opts.spec or ""),
    offRoles = normalizeOffRoles(opts.offRoles),
    attendance = opts.attendance,
    raidDays = {},
    mplusDays = {},
    status = tostring(opts.status or "to_evaluate"),
    launch = tostring(opts.launch or ""),
    intends = opts.intends ~= false,
    mythic = opts.mythic,
    tags = {},
    notes = tostring(opts.notes or ""),
    priority = prio,
    manual = true,
  }

  ns.db.players = ns.db.players or {}
  ns.db.manualPlayers = ns.db.manualPlayers or {}
  ns.db.deletedPlayers = ns.db.deletedPlayers or {}
  ns.db.deletedPlayers[key] = nil
  ns.db.players[key] = p
  ns.db.manualPlayers[key] = copyPlayer(p)
  ns.db.mainRoleOverrides = ns.db.mainRoleOverrides or {}
  if role == "tank" or role == "healer" or role == "melee" or role == "ranged" then
    ns.db.mainRoleOverrides[key] = role
  end
  ns.db.priorityOverrides = ns.db.priorityOverrides or {}
  ns.db.priorityOverrides[key] = prio
  if ns.RequestPushPrep then ns.RequestPushPrep("roster_add") end
  return p
end

--- Update an existing roster row (also stored as localEdit for sync survival).
function ns.UpdatePlayer(oldName, opts)
  if not (ns.CanEditRoster and ns.CanEditRoster()) then
    return nil, "readonly"
  end
  opts = opts or {}
  local oldKey = ns.NormalizeName(oldName)
  local p = ns.db.players and ns.db.players[oldKey]
  if not p then return nil, "not_found" end

  local newName = strtrim(tostring(opts.name or p.name or ""))
  if newName == "" then return nil, "empty_name" end
  local newKey = ns.NormalizeName(newName)
  if newKey ~= oldKey and ns.db.players[newKey] then return nil, "exists" end

  if newKey ~= oldKey then
    local ok, err = ns.RenamePlayer(p.name, newName)
    if not ok then return nil, err end
    p = ns.db.players[newKey]
    oldKey = newKey
  end

  local role = normalizeLane(opts.primaryRole or p.primaryRole or "dps")
  local prio = tonumber(opts.priority)
  if not prio then prio = tonumber(p.priority) or 3 end
  if prio < 1 or prio > 5 then prio = 3 end

  p.class = tostring(opts.class ~= nil and opts.class or p.class or "")
  p.primaryRole = role
  p.offRoles = normalizeOffRoles(opts.offRoles ~= nil and opts.offRoles or p.offRoles)
  p.status = tostring(opts.status ~= nil and opts.status or p.status or "to_evaluate")
  p.launch = tostring(opts.launch ~= nil and opts.launch or p.launch or "")
  if opts.attendance ~= nil then
    p.attendance = opts.attendance
  end
  if opts.notes ~= nil then
    p.notes = tostring(opts.notes)
  end
  if opts.intends ~= nil then
    p.intends = opts.intends and true or false
  else
    p.intends = p.status ~= "non_raider"
  end
  p.priority = prio

  ns.db.mainRoleOverrides = ns.db.mainRoleOverrides or {}
  if role == "tank" or role == "healer" or role == "melee" or role == "ranged" then
    ns.db.mainRoleOverrides[oldKey] = role
  end
  ns.db.priorityOverrides = ns.db.priorityOverrides or {}
  ns.db.priorityOverrides[oldKey] = prio
  ns.db.deletedPlayers = ns.db.deletedPlayers or {}
  ns.db.deletedPlayers[oldKey] = nil
  rememberLocalEdit(oldKey, p)
  if ns.RequestPushPrep then ns.RequestPushPrep("roster_update") end
  return p
end

function ns.RemovePlayer(name)
  if not (ns.CanEditRoster and ns.CanEditRoster()) then
    return false
  end
  local key = ns.NormalizeName(name)
  if not key or key == "" then return false end
  local p = ns.db.players and ns.db.players[key]
  if p then ns.db.players[key] = nil end
  if ns.db.manualPlayers then ns.db.manualPlayers[key] = nil end
  if ns.db.mainRoleOverrides then ns.db.mainRoleOverrides[key] = nil end
  if ns.db.priorityOverrides then ns.db.priorityOverrides[key] = nil end
  ns.db.deletedPlayers = ns.db.deletedPlayers or {}
  ns.db.deletedPlayers[key] = true
  if p ~= nil and ns.RequestPushPrep then ns.RequestPushPrep("roster_remove") end
  return p ~= nil
end

-- Back-compat alias
function ns.RemoveManualPlayer(name)
  return ns.RemovePlayer(name)
end

function ns.RenamePlayer(oldName, newName)
  local oldKey = ns.NormalizeName(oldName)
  local newKey = ns.NormalizeName(newName)
  newName = strtrim(tostring(newName or ""))
  if oldKey == "" or newName == "" then return false, "bad_args" end
  local p = ns.db.players and ns.db.players[oldKey]
  if not p then return false, "not_found" end
  if oldKey ~= newKey and ns.db.players[newKey] then return false, "exists" end

  p.name = newName
  if oldKey ~= newKey then
    ns.db.players[newKey] = p
    ns.db.players[oldKey] = nil
  end

  ns.db.manualPlayers = ns.db.manualPlayers or {}
  if p.manual or ns.db.manualPlayers[oldKey] then
    p.manual = true
    ns.db.manualPlayers[newKey] = copyPlayer(p)
    ns.db.manualPlayers[oldKey] = nil
  end

  local function moveMap(map)
    if not map or map[oldKey] == nil then return end
    map[newKey] = map[oldKey]
    map[oldKey] = nil
  end
  moveMap(ns.db.mainRoleOverrides)
  moveMap(ns.db.priorityOverrides)
  return true
end

function ns.RestoreManualPlayers()
  ns.db.manualPlayers = ns.db.manualPlayers or {}
  ns.db.deletedPlayers = ns.db.deletedPlayers or {}
  local n = 0
  for key, mp in pairs(ns.db.manualPlayers) do
    if type(mp) == "table" and mp.name and not ns.db.deletedPlayers[key] then
      local cur = ns.db.players[key]
      if not cur then
        ns.db.players[key] = copyPlayer(mp)
        ns.db.players[key].manual = true
        n = n + 1
      elseif mp.localEdit then
        -- Re-apply local edits over sync payload
        cur.manual = cur.manual or mp.manual
        if type(mp.offRoles) == "table" then
          local offs = {}
          for i, r in ipairs(mp.offRoles) do offs[i] = r end
          cur.offRoles = offs
        end
        if mp.notes ~= nil then cur.notes = mp.notes end
        if mp.status ~= nil then cur.status = mp.status end
        if mp.launch ~= nil then cur.launch = mp.launch end
        if mp.attendance ~= nil then cur.attendance = mp.attendance end
        if mp.class ~= nil and mp.class ~= "" then cur.class = mp.class end
        if mp.primaryRole ~= nil then cur.primaryRole = mp.primaryRole end
        if mp.priority ~= nil then cur.priority = mp.priority end
        if mp.intends ~= nil then cur.intends = mp.intends end
        n = n + 1
      else
        cur.manual = cur.manual or mp.manual
      end
    end
  end
  for key in pairs(ns.db.deletedPlayers) do
    if ns.db.players[key] then
      ns.db.players[key] = nil
      n = n + 1
    end
  end
  return n
end

--- Encode offRoles list to dropdown value (ordered lanes).
function ns.OffRolesToValue(p)
  local order = { tank = 1, healer = 2, melee = 3, ranged = 4 }
  local lanes, seen = {}, {}
  for _, r in ipairs((p and p.offRoles) or {}) do
    r = string.lower(strtrim(tostring(r)))
    if r == "dps" then
      local tok = ns.NormalizeClass(p and p.class)
      r = (tok and ns.MeleeClasses and ns.MeleeClasses[tok]) and "melee" or "ranged"
    end
    if order[r] and not seen[r] then
      seen[r] = true
      lanes[#lanes + 1] = r
    end
  end
  table.sort(lanes, function(a, b) return order[a] < order[b] end)
  return table.concat(lanes, ",")
end

function ns.OffRoleOptions()
  local labels = { tank = "Tank", healer = "Healer", melee = "Melee", ranged = "Ranged" }
  local roles = { "tank", "healer", "melee", "ranged" }
  local opts = { { value = "", text = "—" } }
  local n = #roles
  for mask = 1, (2 ^ n) - 1 do
    local vals, texts = {}, {}
    for i = 1, n do
      if math.floor(mask / (2 ^ (i - 1))) % 2 == 1 then
        vals[#vals + 1] = roles[i]
        texts[#texts + 1] = labels[roles[i]]
      end
    end
    opts[#opts + 1] = { value = table.concat(vals, ","), text = table.concat(texts, ", ") }
  end
  return opts
end
