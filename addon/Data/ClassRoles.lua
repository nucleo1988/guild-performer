local ADDON, ns = ...

-- Calendar has class, not spec. Defaults for Tank / Healer / Melee / Range.
ns.ClassRoleDefaults = {
  WARRIOR     = { primary = "melee",  off = { "tank" } },
  PALADIN     = { primary = "melee",  off = { "tank", "healer" } },
  HUNTER      = { primary = "ranged", off = {} },
  ROGUE       = { primary = "melee",  off = {} },
  PRIEST      = { primary = "healer", off = { "ranged" } },
  DEATHKNIGHT = { primary = "melee",  off = { "tank" } },
  SHAMAN      = { primary = "ranged", off = { "healer", "melee" } },
  MAGE        = { primary = "ranged", off = {} },
  WARLOCK     = { primary = "ranged", off = {} },
  MONK        = { primary = "melee",  off = { "tank", "healer" } },
  DRUID       = { primary = "ranged", off = { "tank", "healer", "melee" } },
  DEMONHUNTER = { primary = "melee",  off = { "tank" } },
  EVOKER      = { primary = "ranged", off = { "healer" } },
}

ns.CAL_ROLE_ORDER = { "tank", "healer", "melee", "ranged" }

-- Classes that are melee when GP says primaryRole = dps
ns.MeleeClasses = {
  WARRIOR = true, ROGUE = true, DEATHKNIGHT = true, MONK = true,
  DEMONHUNTER = true, PALADIN = true,
}
