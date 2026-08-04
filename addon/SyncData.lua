local ADDON, ns = ...
local L = ns.L

local function copyList(src)
  local out = {}
  if type(src) ~= "table" then return out end
  for i, v in ipairs(src) do
    out[i] = v
  end
  return out
end

local function jsonEscape(s)
  s = tostring(s or "")
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\r", "\\r")
  s = s:gsub("\n", "\\n")
  s = s:gsub("\t", "\\t")
  return s
end

local function jsonBool(v)
  if v == nil then return "null" end
  return v and "true" or "false"
end

local function jsonNumOrNull(v)
  if v == nil or v == "" then return "null" end
  local n = tonumber(v)
  if not n then return "null" end
  return tostring(n)
end

local function jsonStringList(list)
  local bits = {}
  for _, v in ipairs(list or {}) do
    bits[#bits + 1] = '"' .. jsonEscape(v) .. '"'
  end
  return "[" .. table.concat(bits, ",") .. "]"
end

local function jsonNumberList(list)
  local bits = {}
  for _, v in ipairs(list or {}) do
    bits[#bits + 1] = tostring(tonumber(v) or 0)
  end
  return "[" .. table.concat(bits, ",") .. "]"
end

function ns.PayloadFromImportTable(t)
  if type(t) ~= "table" or type(t.players) ~= "table" then
    return nil, L["SYNC_NO_DATA"] or "No sync data."
  end

  local players = {}
  for _, p in ipairs(t.players) do
    if type(p) == "table" and p.name and tostring(p.name) ~= "" then
      local role = string.lower(strtrim(tostring(p.primaryRole or "dps")))
      if role ~= "tank" and role ~= "healer" and role ~= "dps"
        and role ~= "melee" and role ~= "ranged" then
        role = "dps"
      end
      local prio = tonumber(p.priority)
      if prio and (prio < 1 or prio > 5) then prio = nil end
      players[#players + 1] = {
        name = tostring(p.name),
        primaryRole = role,
        class = tostring(p.class or ""),
        spec = tostring(p.spec or ""),
        offRoles = copyList(p.offRoles),
        attendance = p.attendance,
        raidDays = copyList(p.raidDays),
        mplusDays = copyList(p.mplusDays),
        status = tostring(p.status or ""),
        launch = tostring(p.launch or ""),
        priority = prio,
        intends = p.intends,
        mythic = p.mythic,
        tags = copyList(p.tags),
        notes = tostring(p.notes or ""),
      }
    end
  end

  if #players == 0 then
    return nil, L["SYNC_NO_DATA"] or "No sync data."
  end

  return {
    meta = {
      formatVersion = tonumber(t.formatVersion) or ns.FORMAT_VERSION,
      exportedAt = tostring(t.exportedAt or ""),
      guild = tostring(t.guild or ""),
      realm = tostring(t.realm or ""),
      region = tostring(t.region or ""),
      season = tostring(t.season or ""),
      revision = tonumber(t.revision) or 1,
      scope = tostring(t.scope or ""),
      count = #players,
    },
    players = players,
    warnings = {},
  }, nil
end

function ns.SyncDataKey(t)
  if type(t) ~= "table" then return "" end
  return table.concat({
    tostring(t.exportedAt or ""),
    tostring(t.guild or ""),
    tostring(t.season or ""),
    tostring(t.revision or ""),
    tostring(type(t.players) == "table" and #t.players or 0),
  }, "|")
end

function ns.GuildNameMismatchWarning(metaGuild)
  local inGuild = GetGuildInfo and GetGuildInfo("player")
  if not inGuild or inGuild == "" or not metaGuild or metaGuild == "" then
    return nil
  end
  if string.lower(inGuild) ~= string.lower(metaGuild) then
    return string.format(L["SYNC_GUILD_MISMATCH"] or "Sync guild %s ≠ your guild %s", metaGuild, inGuild)
  end
  return nil
end

function ns.ClearLocalEdits()
  if not ns.db then return end
  ns.db.manualPlayers = {}
  ns.db.mainRoleOverrides = {}
  ns.db.priorityOverrides = {}
  ns.db.deletedPlayers = {}
  ns.db.pushRequestJson = nil
end

--- Build JSON push body for companion (officer edits → site).
function ns.BuildPushPayload()
  local players = {}
  local list = ns.GetPlayersList and ns.GetPlayersList() or {}
  for _, p in ipairs(list) do
    if type(p) == "table" and p.name and tostring(p.name) ~= "" then
      players[#players + 1] = {
        name = tostring(p.name),
        primaryRole = tostring(p.primaryRole or "dps"),
        class = tostring(p.class or ""),
        spec = tostring(p.spec or ""),
        offRoles = copyList(p.offRoles),
        attendance = p.attendance,
        raidDays = copyList(p.raidDays),
        mplusDays = copyList(p.mplusDays),
        status = tostring(p.status or "to_evaluate"),
        launch = tostring(p.launch or ""),
        priority = tonumber(p.priority),
        intends = p.intends,
        mythic = p.mythic,
        tags = copyList(p.tags),
        notes = tostring(p.notes or ""),
      }
    end
  end
  local meta = (ns.db and ns.db.meta) or {}
  local unit = (UnitName and UnitName("player")) or "officer"
  return {
    base_revision = tonumber(meta.revision) or 1,
    guild = tostring(meta.guild or ""),
    realm = tostring(meta.realm or ""),
    updated_by = tostring(unit),
    players = players,
  }
end

function ns.EncodePushPayloadJson(payload)
  payload = payload or ns.BuildPushPayload()
  local playerBits = {}
  for _, p in ipairs(payload.players or {}) do
    playerBits[#playerBits + 1] = table.concat({
      "{",
      '"name":"', jsonEscape(p.name), '",',
      '"primaryRole":"', jsonEscape(p.primaryRole), '",',
      '"class":"', jsonEscape(p.class), '",',
      '"spec":"', jsonEscape(p.spec), '",',
      '"offRoles":', jsonStringList(p.offRoles), ',',
      '"attendance":', jsonNumOrNull(p.attendance), ',',
      '"raidDays":', jsonNumberList(p.raidDays), ',',
      '"mplusDays":', jsonNumberList(p.mplusDays), ',',
      '"status":"', jsonEscape(p.status), '",',
      '"launch":"', jsonEscape(p.launch), '",',
      '"priority":', jsonNumOrNull(p.priority), ',',
      '"intends":', jsonBool(p.intends), ',',
      '"mythic":', jsonBool(p.mythic), ',',
      '"tags":', jsonStringList(p.tags), ',',
      '"notes":"', jsonEscape(p.notes), '"',
      "}",
    })
  end
  return table.concat({
    "{",
    '"base_revision":', tostring(tonumber(payload.base_revision) or 1), ",",
    '"guild":"', jsonEscape(payload.guild), '",',
    '"realm":"', jsonEscape(payload.realm), '",',
    '"updated_by":"', jsonEscape(payload.updated_by), '",',
    '"players":[', table.concat(playerBits, ","), "]",
    "}",
  })
end

function ns.BuildPushPayloadSelf()
  local full = ns.BuildPushPayload()
  local me = (UnitName and UnitName("player")) or ""
  local meKey = ns.NormalizeName(me)
  local mine = {}
  for _, p in ipairs(full.players or {}) do
    if ns.NormalizeName(p.name) == meKey then
      mine[#mine + 1] = p
    end
  end
  full.players = mine
  full.updated_by = me
  return full
end

--- Stage push JSON into SavedVariables for the desktop companion.
--- Officers: full roster. Members: only the logged-in character.
--- @return number|nil playerCount, string|nil err
function ns.PreparePushForCompanion()
  ns.EnsureDB()
  local payload
  if ns.CanEditRoster and ns.CanEditRoster() then
    payload = ns.BuildPushPayload()
  else
    payload = ns.BuildPushPayloadSelf()
    if #(payload.players or {}) == 0 then
      return nil, L["SYNC_NO_DATA"] or "No personal roster row to push."
    end
  end
  local json = ns.EncodePushPayloadJson(payload)
  ns.db.pushRequestJson = json
  ns.db.pushRequestAt = time()
  return #(payload.players or {}), nil
end

function ns.ApplyGuildImportTable(t)
  if type(t) ~= "table" or type(t.members) ~= "table" then
    return 0
  end
  ns.EnsureDB()
  ns.db.guildMeta = {
    guild = tostring(t.guild or ""),
    realm = tostring(t.realm or ""),
    region = tostring(t.region or ""),
    exportedAt = tostring(t.exportedAt or ""),
    isOfficer = t.isOfficer and true or false,
  }
  local members = {}
  for _, m in ipairs(t.members) do
    if type(m) == "table" and m.name and tostring(m.name) ~= "" then
      local profs = {}
      if type(m.professions) == "table" then
        for _, p in ipairs(m.professions) do
          profs[#profs + 1] = tostring(p)
        end
      end
      members[#members + 1] = {
        name = tostring(m.name),
        realm = tostring(m.realm or ""),
        class = tostring(m.class or ""),
        spec = tostring(m.spec or ""),
        role = tostring(m.role or ""),
        rank = m.rank,
        itemLevel = m.itemLevel,
        avgItemLevel = m.avgItemLevel,
        rioScore = m.rioScore,
        professions = profs,
      }
    end
  end
  ns.db.guildMembers = members
  if ns.RefreshGuildView then ns.RefreshGuildView() end
  return #members
end

local pushPrepPending = false
local pushPrepReason = nil

--- Debounced auto-stage of push JSON after local edits (Companion Watch picks it up after /reload).
--- @param reason string|nil
--- @param force boolean|nil ignore autoPushPrep setting
function ns.RequestPushPrep(reason, force)
  ns.EnsureDB()
  if not force and ns.db.settings.autoPushPrep == false then
    return
  end
  pushPrepReason = reason or pushPrepReason or "edit"
  if pushPrepPending then return end
  pushPrepPending = true
  C_Timer.After(0.35, function()
    pushPrepPending = false
    local why = pushPrepReason or "edit"
    pushPrepReason = nil
    if not ns.PreparePushForCompanion then return end
    local n, err = ns.PreparePushForCompanion()
    if n then
      if ns.CalendarDebug then
        ns.CalendarDebug(string.format("pushprep OK n=%d reason=%s", n, tostring(why)), "info")
      end
      if ns.db.settings.autoReloadForPush then
        if ns.CalendarDebug then
          ns.CalendarDebug("autoReloadForPush → ReloadUI()", "info")
        end
        C_Timer.After(0.15, function()
          ReloadUI()
        end)
      elseif DEFAULT_CHAT_FRAME and ns.db.settings.autoPushPrep ~= false then
        -- Soft hint once per session burst (avoid spam): only when forced or debug-ish
        if force then
          DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff66ccff[GP]|r %s",
            string.format(L["PUSH_PREP_OK"] or "Push ready (%d). Companion push, then /reload.", n)
          ))
        end
      end
      if ns.RefreshCalendarDebugView then
        ns.RefreshCalendarDebugView()
      end
    else
      if ns.CalendarDebug then
        ns.CalendarDebug("pushprep FAIL " .. tostring(err or "?") .. " reason=" .. tostring(why), "warn")
      end
    end
  end)
end

--- Apply GuildPerformerDB_Import written by the external companion into GuildPerformer_Data.lua.
--- @param force boolean|nil ignore lastSyncKey short-circuit
--- @return number|nil count, string|nil err
function ns.TryApplySyncedData(force)
  if type(GuildPerformerDB_Guild) == "table" and ns.ApplyGuildImportTable then
    ns.ApplyGuildImportTable(GuildPerformerDB_Guild)
  end

  local t = GuildPerformerDB_Import
  if type(t) ~= "table" then
    return nil, L["SYNC_NO_DATA"] or "No sync data."
  end

  local key = ns.SyncDataKey(t)
  if not force and ns.db and ns.db.settings and ns.db.settings.lastSyncKey == key then
    return nil, L["SYNC_UNCHANGED"] or "Sync data unchanged."
  end

  local payload, err = ns.PayloadFromImportTable(t)
  if not payload then
    return nil, err
  end

  local warn = ns.GuildNameMismatchWarning(payload.meta.guild)
  if warn and ns.Print then
    ns.Print("|cffffaa00" .. warn .. "|r")
  end

  -- After a successful companion pull, server wins over stale localEdit shadows.
  if force or (ns.db and ns.db.settings and ns.db.settings.clearLocalOnSync) then
    ns.ClearLocalEdits()
  end

  local n = ns.ApplyImport(payload, "replace")
  if ns.db and ns.db.settings then
    ns.db.settings.lastSyncKey = key
    ns.db.settings.lastSyncAt = payload.meta.exportedAt
  end
  if ns.db and ns.db.meta then
    ns.db.meta.revision = payload.meta.revision
  end
  if ns.Print then
    ns.Print(string.format(L["SYNC_APPLIED"] or "Synced %d players from data file.", n))
  end
  return n, nil
end
