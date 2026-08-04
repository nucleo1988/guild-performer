local ADDON, ns = ...
local L = ns.L

local function splitRecords(body)
  local rows = {}
  local buf, i = {}, 1
  while i <= #body do
    local c = body:sub(i, i)
    if c == "\\" and i < #body then
      buf[#buf + 1] = c
      buf[#buf + 1] = body:sub(i + 1, i + 1)
      i = i + 2
    elseif c == ";" and body:sub(i, i + 1) == ";;" then
      local row = table.concat(buf)
      if row ~= "" then rows[#rows + 1] = row end
      buf = {}
      i = i + 2
    else
      buf[#buf + 1] = c
      i = i + 1
    end
  end
  local last = table.concat(buf)
  if last ~= "" then rows[#rows + 1] = last end
  return rows
end

local function parsePlayerRow(row, sep)
  local f = ns.SplitPlayerFields(row, sep)
  local function csv(s)
    local t = {}
    s = ns.UnescapeField(s or "")
    if s == "" then return t end
    for part in string.gmatch(s .. ",", "([^,]*),") do
      if part ~= "" then t[#t + 1] = part end
    end
    return t
  end
  local function normRole(r)
    r = string.lower(strtrim(tostring(r or "")))
    if r == "tank" or r == "healer" or r == "dps" then return r end
    return nil
  end

  local intends = f[11]
  local mythic = f[12]
  local primary = normRole(f[2]) or "dps"
  local off = csv(f[5])
  local offNorm = {}
  for _, r in ipairs(off) do
    local nr = normRole(r)
    if nr then offNorm[#offNorm + 1] = nr end
  end

  local prio = tonumber(f[15])
  if prio and (prio < 1 or prio > 5) then prio = nil end

  local player = {
    name = ns.UnescapeField(f[1] or ""),
    primaryRole = primary,
    class = ns.UnescapeField(f[3] or ""),
    spec = ns.UnescapeField(f[4] or ""),
    offRoles = offNorm,
    attendance = tonumber(f[6]),
    raidDays = csv(f[7]),
    mplusDays = csv(f[8]),
    status = f[9] or "to_evaluate",
    launch = f[10] or "",
    intends = (intends == "" and nil) or (intends == "1") or (intends == "0" and false) or nil,
    mythic = (mythic == "" and nil) or (mythic == "1") or (mythic == "0" and false) or nil,
    tags = csv(f[13]),
    notes = ns.UnescapeField(f[14] or ""),
    priority = prio,
  }
  if player.name == "" then return nil, "missing name" end
  if #player.offRoles == 0 then player.offRoles = { player.primaryRole } end
  return player
end

function ns.ParseExportString(raw)
  raw = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if raw == "" then return nil, L["INVALID_FORMAT"] end

  -- Allow multiline paste: collapse newlines outside notes by treating as continuous string
  raw = raw:gsub("\r\n", ""):gsub("\n", ""):gsub("\r", "")

  local prefix = raw:match("^(GPv%d+);")
  if not prefix or (prefix ~= "GPv1" and prefix ~= "GPv2") then
    return nil, L["INVALID_FORMAT"]
  end

  local rest = raw:sub(#prefix + 2) -- after GPvN;
  local playersMarker = rest:find(";PLAYERS;", 1, true)
  if not playersMarker then
    return nil, L["INVALID_FORMAT"]
  end

  local header = rest:sub(1, playersMarker - 1)
  local body = rest:sub(playersMarker + 9)
  local meta = ns.ParseHeader(header)
  local fv = tonumber(meta.fv or (prefix == "GPv2" and "2" or "1")) or 1
  if fv > ns.FORMAT_VERSION then
    return nil, string.format(L["VERSION_MISMATCH"], tostring(fv), tostring(ns.FORMAT_VERSION))
  end

  -- Prefer caret separator (WoW EditBox safe). Auto-detect if header omits sep=.
  local sep = meta.sep
  if not sep or sep == "" then
    if body:find("%^", 1, false) then
      sep = "^"
    else
      sep = "|"
    end
  end

  local players, errors = {}, {}
  for _, row in ipairs(splitRecords(body)) do
    local p, err = parsePlayerRow(row, sep)
    if p then
      players[#players + 1] = p
    else
      errors[#errors + 1] = err or "bad row"
    end
  end

  if #players == 0 then
    return nil, L["INVALID_FORMAT"]
  end

  return {
    meta = {
      formatVersion = fv,
      exportedAt = meta.at or "",
      guild = meta.guild or "",
      realm = meta.realm or "",
      region = meta.region or "",
      season = meta.season or "",
      revision = tonumber(meta.rev) or 1,
      count = tonumber(meta.count) or #players,
    },
    players = players,
    warnings = errors,
  }, nil
end

function ns.ApplyImport(payload, mode)
  mode = mode or "replace"
  ns.BackupRoster()
  if mode == "replace" then
    ns.db.players = {}
  end
  ns.db.meta = payload.meta
  local upserted = 0
  local byRole = { tank = 0, healer = 0, dps = 0 }
  for _, p in ipairs(payload.players) do
    local key = ns.NormalizeName(p.name)
    if mode == "merge" and ns.db.players[key] then
      local existing = ns.db.players[key]
      for k, v in pairs(p) do existing[k] = v end
    else
      ns.db.players[key] = p
    end
    local board = ns.BoardRole and ns.BoardRole(p.primaryRole) or p.primaryRole
    if byRole[board] then byRole[board] = byRole[board] + 1 end
    upserted = upserted + 1
  end
  -- Re-apply local Main / Priority edits after sync/replace
  for key, lane in pairs(ns.db.mainRoleOverrides or {}) do
    local pl = ns.db.players[key]
    if pl and (lane == "tank" or lane == "healer" or lane == "melee" or lane == "ranged") then
      pl.primaryRole = lane
    end
  end
  for key, prio in pairs(ns.db.priorityOverrides or {}) do
    local pl = ns.db.players[key]
    local n = tonumber(prio)
    if pl and n and n >= 1 and n <= 5 then
      pl.priority = n
    end
  end
  -- Keep players added manually in-game (not present in sync file)
  local restored = 0
  if ns.RestoreManualPlayers then
    restored = ns.RestoreManualPlayers() or 0
  end
  if ns.Print then
    ns.Print(string.format("Import %d → Tank %d · Healer %d · DPS %d%s",
      upserted, byRole.tank, byRole.healer, byRole.dps,
      restored > 0 and (" · manual +" .. restored) or ""))
  end
  return upserted
end
