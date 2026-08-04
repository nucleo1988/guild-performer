local ADDON, ns = ...

local defaults = {
  meta = {
    guild = "",
    realm = "",
    region = "",
    season = "",
    exportedAt = "",
    formatVersion = ns.FORMAT_VERSION,
    revision = 1,
    scope = "",
  },
  players = {},
  guildMembers = {},
  guildMeta = {
    guild = "",
    realm = "",
    region = "",
    exportedAt = "",
    isOfficer = false,
  },
  templates = {},
  pushRequestJson = nil,
  settings = {
    scale = 1.0,
    theme = "azure",
    defaultModule = "dashboard",
    lockWindow = false,
    showMinimap = true,
    pos = nil,
    minimap = { angle = 210, hide = false },
    -- Informational note for Companion setup (WoW cannot HTTP).
    syncUrl = "",
    autoApplySync = true,
    clearLocalOnSync = true,
    -- Stage companion push JSON after each roster edit (needs /reload for SV file).
    autoPushPrep = true,
    autoReloadForPush = false,
    officerMaxRank = 2,
    lastSyncKey = "",
    lastSyncAt = "",
    revision = 1,
    calMonthRange = 0, -- current month only
    calEventTypes = {
      GUILD_EVENT = true,
      PLAYER = true,
      COMMUNITY_EVENT = true,
      GUILD_ANNOUNCEMENT = false,
    },
    calStatusFilter = {
      [0] = true, [1] = true, [2] = true, [3] = true,
      [4] = true, [5] = true, [6] = true, [7] = false, [8] = true,
    },
  },
  calendarRoleOverrides = {},
  mainRoleOverrides = {},
  priorityOverrides = {},
  manualPlayers = {},
  deletedPlayers = {},
  backup = nil,
}

function ns.EnsureDB()
  if not GuildPerformerDB then
    GuildPerformerDB = CopyTable(defaults)
  else
    for k, v in pairs(defaults) do
      if GuildPerformerDB[k] == nil then
        GuildPerformerDB[k] = type(v) == "table" and CopyTable(v) or v
      end
    end
    for sk, sv in pairs(defaults.settings) do
      if GuildPerformerDB.settings[sk] == nil then
        GuildPerformerDB.settings[sk] = type(sv) == "table" and CopyTable(sv) or sv
      end
    end
    if not GuildPerformerDB.settings.minimap then
      GuildPerformerDB.settings.minimap = CopyTable(defaults.settings.minimap)
    end
    if not GuildPerformerDB.calendarRoleOverrides then
      GuildPerformerDB.calendarRoleOverrides = {}
    end
    if not GuildPerformerDB.settings.calEventTypes then
      GuildPerformerDB.settings.calEventTypes = CopyTable(defaults.settings.calEventTypes)
    end
    if not GuildPerformerDB.settings.calStatusFilter then
      GuildPerformerDB.settings.calStatusFilter = CopyTable(defaults.settings.calStatusFilter)
    end
    -- migrate legacy point
    if GuildPerformerDB.settings.point and not GuildPerformerDB.settings.pos then
      local p = GuildPerformerDB.settings.point
      GuildPerformerDB.settings.pos = { point = p[1], rel = p[2], x = p[3], y = p[4] }
    end
  end
  ns.db = GuildPerformerDB
  ns.ApplyTheme(ns.db.settings.theme or ns.UIDefaults.theme)
end

function ns.NormalizeName(name)
  name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(name)
end

function ns.GetPlayersList()
  local list = {}
  for _, p in pairs(ns.db.players or {}) do
    list[#list + 1] = p
  end
  table.sort(list, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  return list
end

function ns.BoardRole(role)
  role = string.lower(strtrim(tostring(role or "")))
  if role == "tank" or role == "healer" then return role end
  if role == "melee" or role == "ranged" or role == "dps" then return "dps" end
  return "dps"
end

function ns.CountByRole()
  local c = { tank = 0, healer = 0, dps = 0 }
  for _, p in pairs(ns.db.players or {}) do
    if p.intends ~= false and p.status ~= "non_raider" then
      local r = ns.BoardRole(p.primaryRole)
      if c[r] then c[r] = c[r] + 1 end
    end
  end
  return c
end

local function roleOf(p)
  return ns.BoardRole(p.primaryRole)
end

function ns.FilterPlayers(opts)
  opts = opts or {}
  local out = {}
  local q = string.lower(opts.search or "")
  for _, p in ipairs(ns.GetPlayersList()) do
    local ok = true
    local primary = roleOf(p)
    if opts.role and opts.role ~= "" and opts.role ~= "all" then
      if opts.primaryRoleOnly then
        ok = (primary == opts.role)
      else
        local found = primary == opts.role
        if not found then
          for _, r in ipairs(p.offRoles or {}) do
            if string.lower(tostring(r)) == opts.role then found = true break end
          end
        end
        ok = found
      end
    end
    if ok and opts.class and opts.class ~= "" and opts.class ~= "all" then
      ok = (p.class == opts.class) or (ns.NormalizeClass(p.class) == opts.class)
    end
    if ok and opts.status and opts.status ~= "" and opts.status ~= "all" then
      ok = (p.status == opts.status)
    end
    if ok and opts.launch and opts.launch ~= "" and opts.launch ~= "all" then
      ok = (p.launch == opts.launch)
    end
    if ok and opts.flag and opts.flag ~= "" then
      local flags = ns.BuildFlags(p)
      ok = flags[opts.flag] == true
    end
    if ok and opts.criticalOnly then
      local flags = ns.BuildFlags(p)
      local hasTags = p.tags and #p.tags > 0
      local hasNotes = p.notes and p.notes ~= ""
      ok = hasTags or hasNotes
        or flags.uncertain or flags.work or flags.vacation or flags.personal
        or flags.low_attendance or flags.deferred_launch or flags.mplus_only
    end
    if ok and opts.absencesOnly then
      local flags = ns.BuildFlags(p)
      ok = flags.vacation or flags.work or flags.university or flags.personal
        or flags.uncertain or (p.status == "justified_absence")
    end
    if ok and q ~= "" then
      local hay = string.lower((p.name or "") .. " " .. (p.class or "") .. " " .. (p.notes or "") .. " " .. table.concat(p.tags or {}, " "))
      ok = string.find(hay, q, 1, true) ~= nil
    end
    if ok then out[#out + 1] = p end
  end
  return out
end

function ns.BackupRoster()
  ns.db.backup = {
    meta = CopyTable(ns.db.meta or {}),
    players = CopyTable(ns.db.players or {}),
    at = time(),
  }
end

function ns.RestoreBackup()
  if not ns.db.backup then return false end
  ns.db.meta = CopyTable(ns.db.backup.meta or {})
  ns.db.players = CopyTable(ns.db.backup.players or {})
  return true
end
