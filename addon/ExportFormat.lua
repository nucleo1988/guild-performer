local ADDON, ns = ...

ns.FORMAT_VERSION = 2
ns.ADDON_VERSION = "1.3.0"

ns.CLASS_COLORS = {
  WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
  PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
  HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
  ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
  PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
  DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
  SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
  MAGE = { r = 0.25, g = 0.78, b = 0.92 },
  WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
  MONK = { r = 0.00, g = 1.00, b = 0.59 },
  DRUID = { r = 1.00, g = 0.49, b = 0.04 },
  DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
  EVOKER = { r = 0.20, g = 0.58, b = 0.50 },
}

ns.CLASS_TOKEN = {
  Warrior = "WARRIOR", Guerriero = "WARRIOR",
  Paladin = "PALADIN", Paladino = "PALADIN", Pally = "PALADIN", Pala = "PALADIN",
  Hunter = "HUNTER", Cacciatore = "HUNTER",
  Rogue = "ROGUE", Ladro = "ROGUE",
  Priest = "PRIEST", Prete = "PRIEST",
  ["Death Knight"] = "DEATHKNIGHT", DK = "DEATHKNIGHT",
  Shaman = "SHAMAN", Shamano = "SHAMAN", Sciamano = "SHAMAN",
  Mage = "MAGE", Mago = "MAGE",
  Warlock = "WARLOCK", Lokko = "WARLOCK", Stregone = "WARLOCK",
  Monk = "MONK", Monaco = "MONK",
  Druid = "DRUID", Dudu = "DRUID", Druido = "DRUID",
  ["Demon Hunter"] = "DEMONHUNTER", DH = "DEMONHUNTER",
  Evoker = "EVOKER",
}

function ns.NormalizeClass(className)
  if not className or className == "" then return nil end
  local token = ns.CLASS_TOKEN[className]
  if token then return token end
  local upper = string.upper((className:gsub("%s+", "")))
  if ns.CLASS_COLORS[upper] then return upper end
  return nil
end

function ns.EscapeField(value)
  value = tostring(value or "")
  value = value:gsub("\\", "\\\\")
  -- Never use raw "|" in paste strings: WoW EditBox eats |t / |h / |c / |r …
  value = value:gsub("|", "<<PIPE>>")
  value = value:gsub("%^", "<<CARET>>")
  value = value:gsub(";", "\\;")
  value = value:gsub("\r\n", "\\n"):gsub("\n", "\\n"):gsub("\r", "\\n")
  return value
end

function ns.UnescapeField(value)
  value = tostring(value or "")
  value = value:gsub("<<PIPE>>", "|")
  value = value:gsub("<<CARET>>", "^")
  local out, i = {}, 1
  while i <= #value do
    local c = value:sub(i, i)
    if c == "\\" and i < #value then
      local n = value:sub(i + 1, i + 1)
      if n == "n" then out[#out + 1] = "\n"; i = i + 2
      elseif n == ";" or n == "\\" or n == "|" then out[#out + 1] = n; i = i + 2
      else out[#out + 1] = n; i = i + 2 end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

function ns.SplitPlayerFields(row, sep)
  -- Default "^" (WoW-safe). Legacy "|" still accepted but tank/healer break in EditBox.
  sep = sep or "^"
  if sep == "caret" then sep = "^" end
  if sep == "pipe" then sep = "|" end

  local fields, buf, i = {}, {}, 1
  while i <= #row do
    local c = row:sub(i, i)
    if c == "\\" and i < #row then
      buf[#buf + 1] = c
      buf[#buf + 1] = row:sub(i + 1, i + 1)
      i = i + 2
    elseif c == sep then
      fields[#fields + 1] = table.concat(buf)
      buf = {}
      i = i + 1
    else
      buf[#buf + 1] = c
      i = i + 1
    end
  end
  fields[#fields + 1] = table.concat(buf)
  return fields
end

function ns.ParseHeader(header)
  local meta = {}
  for part in string.gmatch(header .. ";", "([^;]*);") do
    if part ~= "" then
      local k, v = part:match("^([^=]+)=(.*)$")
      if k then meta[k] = v end
    end
  end
  return meta
end

function ns.BuildFlags(player)
  local flags = {}
  local tags = player.tags or {}
  for _, tag in ipairs(tags) do
    flags[tag] = true
  end
  if player.launch == "deferred" then flags.deferred_launch = true end
  if player.intends == false then flags.non_raider = true end
  if (tonumber(player.attendance) or 99) <= 1 then flags.low_attendance = true end
  if player.status == "backup" then flags.reserve = true end
  if player.offRoles and #player.offRoles > 1 then flags.offspec_useful = true end
  if flags.work or flags.university or flags.personal then
    flags.vacation = flags.vacation or true
  end
  return flags
end
