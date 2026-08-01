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

function ns.PayloadFromImportTable(t)
  if type(t) ~= "table" or type(t.players) ~= "table" then
    return nil, L["SYNC_NO_DATA"] or "No sync data."
  end

  local players = {}
  for _, p in ipairs(t.players) do
    if type(p) == "table" and p.name and tostring(p.name) ~= "" then
      local role = string.lower(strtrim(tostring(p.primaryRole or "dps")))
      if role ~= "tank" and role ~= "healer" and role ~= "dps" then
        role = "dps"
      end
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

--- Apply GuildPerformerDB_Import written by the external syncer into GuildPerformer_Data.lua.
--- @param force boolean|nil ignore lastSyncKey short-circuit
--- @return number|nil count, string|nil err
function ns.TryApplySyncedData(force)
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

  local n = ns.ApplyImport(payload, "replace")
  if ns.db and ns.db.settings then
    ns.db.settings.lastSyncKey = key
    ns.db.settings.lastSyncAt = payload.meta.exportedAt
  end
  if ns.Print then
    ns.Print(string.format(L["SYNC_APPLIED"] or "Synced %d players from data file.", n))
  end
  return n, nil
end
