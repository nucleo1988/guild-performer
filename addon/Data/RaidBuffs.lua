local ADDON, ns = ...

ns.RaidBuffs = {
  buffs = {
    { id = "stamina",      label = "Stamina",            classes = { PRIEST = true } },
    { id = "attack_power", label = "Attack Power",       classes = { WARRIOR = true } },
    { id = "intellect",    label = "Intellect",          classes = { MAGE = true } },
    { id = "physical",     label = "Physical Damage",    classes = { MONK = true }, critical = true },
    { id = "magical",      label = "Magical Damage",     classes = { DEMONHUNTER = true }, critical = true },
    { id = "versatility",  label = "Versatility",        classes = { DRUID = true } },
    { id = "skyfury",      label = "Mastery (Skyfury)",  classes = { SHAMAN = true } },
    { id = "bronze",       label = "Movement CDR",       classes = { EVOKER = true } },
    { id = "hunters_mark", label = "Damage Taken",       classes = { HUNTER = true } },
  },
  utilities = {
    { id = "bloodlust",   label = "Bloodlust",      classes = { MAGE = true, SHAMAN = true, EVOKER = true } },
    { id = "movement",    label = "Movement Speed", classes = { DRUID = true, WARRIOR = true, EVOKER = true } },
    { id = "healthstone", label = "Healthstone",    classes = { WARLOCK = true } },
    { id = "gateway",     label = "Gateway",        classes = { WARLOCK = true } },
    { id = "battleres",   label = "Battle Res",     classes = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true, PALADIN = true } },
  },
  cooldowns = {
    { id = "immunity", label = "Personal Immunities", classes = { PALADIN = true, MAGE = true, HUNTER = true, ROGUE = true } },
    { id = "raid_dr",  label = "Damage Reduction", classes = {
      PRIEST = true, WARRIOR = true, DEMONHUNTER = true, PALADIN = true, EVOKER = true, ROGUE = true,
    } },
  },
}

function ns.ComputeBuffCoverage(invitees, onlyMain)
  local classCounts = {}
  for _, p in ipairs(invitees or {}) do
    local include = true
    if onlyMain then
      include = false
      for _, role in ipairs(ns.CAL_ROLE_ORDER or {}) do
        if ns.GetEffectiveCalRole(p, role) == "MAIN" then
          include = true
          break
        end
      end
    end
    if include then
      local token = ns.NormalizeClass(p.classFilename or p.className)
      if not token then
        local roster = ns.FindRosterPlayer and ns.FindRosterPlayer(p.name)
        token = roster and ns.NormalizeClass(roster.class)
      end
      if token then
        classCounts[token] = (classCounts[token] or 0) + 1
      end
    end
  end

  local function mapSection(section)
    local out = {}
    for _, entry in ipairs(section or {}) do
      local n = 0
      for className in pairs(entry.classes or {}) do
        n = n + (classCounts[className] or 0)
      end
      out[#out + 1] = {
        id = entry.id,
        label = entry.label,
        count = n,
        critical = entry.critical,
        missing = n == 0,
      }
    end
    return out
  end

  return {
    buffs = mapSection(ns.RaidBuffs.buffs),
    utilities = mapSection(ns.RaidBuffs.utilities),
    cooldowns = mapSection(ns.RaidBuffs.cooldowns),
    classCounts = classCounts,
  }
end
