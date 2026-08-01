local ADDON, ns = ...

function ns.AnalyzeComposition(selected)
  -- selected: map name -> assignedRole
  local counts = { tank = 0, healer = 0, dps = 0 }
  local uncertain, deferred, reserves = {}, {}, {}
  for name, role in pairs(selected or {}) do
    local p = ns.db.players[ns.NormalizeName(name)]
    if p and counts[role] then
      counts[role] = counts[role] + 1
      local flags = ns.BuildFlags(p)
      if flags.uncertain or flags.low_attendance then uncertain[#uncertain + 1] = p.name end
      if flags.deferred_launch then deferred[#deferred + 1] = p.name end
      if p.status == "backup" then reserves[#reserves + 1] = p.name end
    end
  end
  local missing = {}
  if counts.tank < 2 then missing[#missing + 1] = "tank" end
  if counts.healer < 4 then missing[#missing + 1] = "healer" end
  if counts.dps < 14 then missing[#missing + 1] = "dps" end

  local classSet = {}
  for name, _ in pairs(selected or {}) do
    local p = ns.db.players[ns.NormalizeName(name)]
    if p then
      local token = ns.NormalizeClass(p.class)
      if token then classSet[token] = true end
    end
  end
  local utilityGaps = {}
  if not classSet.SHAMAN and not classSet.MAGE and not classSet.EVOKER and not classSet.HUNTER then
    utilityGaps[#utilityGaps + 1] = "Bloodlust / Heroism"
  end
  if not classSet.DRUID and not classSet.DEATHKNIGHT and not classSet.WARLOCK and not classSet.PALADIN then
    utilityGaps[#utilityGaps + 1] = "Battle Res"
  end

  return {
    counts = counts,
    missing = missing,
    uncertain = uncertain,
    deferred = deferred,
    reserves = reserves,
    utilityGaps = utilityGaps,
  }
end

function ns.SuggestComposition(targets)
  targets = targets or { tank = 2, healer = 4, dps = 14 }
  local pool = {}
  for _, p in ipairs(ns.GetPlayersList()) do
    if p.intends ~= false and p.status ~= "non_raider" and p.status ~= "suspended" and p.status ~= "unavailable" then
      pool[#pool + 1] = p
    end
  end
  table.sort(pool, function(a, b)
    local sa = (a.status == "confirmed" and 3) or (a.status == "trial" and 2) or (a.status == "backup" and 1) or 0
    local sb = (b.status == "confirmed" and 3) or (b.status == "trial" and 2) or (b.status == "backup" and 1) or 0
    if sa ~= sb then return sa > sb end
    return (tonumber(a.attendance) or 0) > (tonumber(b.attendance) or 0)
  end)

  local selected, used = {}, {}
  local function pick(role, need)
    local n = 0
    for _, p in ipairs(pool) do
      if n >= need then break end
      local key = ns.NormalizeName(p.name)
      if not used[key] then
        local can = p.primaryRole == role
        if not can then
          for _, r in ipairs(p.offRoles or {}) do if r == role then can = true break end end
        end
        if can then
          selected[p.name] = role
          used[key] = true
          n = n + 1
        end
      end
    end
  end
  pick("tank", targets.tank or 2)
  pick("healer", targets.healer or 4)
  pick("dps", targets.dps or 14)
  return selected, ns.AnalyzeComposition(selected)
end

function ns.SaveTemplate(name, selected)
  if not name or name == "" then return false end
  ns.db.templates[name] = {
    members = CopyTable(selected or {}),
    savedAt = time(),
  }
  return true
end

function ns.LoadTemplate(name)
  local t = ns.db.templates[name]
  if not t then return nil end
  return CopyTable(t.members or {})
end

function ns.ListTemplates()
  local names = {}
  for name in pairs(ns.db.templates or {}) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end
