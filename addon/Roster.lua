local ADDON, ns = ...

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
