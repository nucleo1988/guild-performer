local ADDON, ns = ...
local L = ns.L
local C = ns.Colors
local W = ns.W

local ui = {}

local function memberList()
  local list = {}
  local guild = ns.db and ns.db.guildMembers
  if type(guild) ~= "table" then return list end
  for _, m in ipairs(guild) do
    if type(m) == "table" and m.name then
      list[#list + 1] = m
    end
  end
  table.sort(list, function(a, b)
    local ra, rb = tonumber(a.rank) or 99, tonumber(b.rank) or 99
    if ra ~= rb then return ra < rb end
    local ia, ib = tonumber(a.itemLevel) or 0, tonumber(b.itemLevel) or 0
    if ia ~= ib then return ia > ib end
    return tostring(a.name) < tostring(b.name)
  end)
  return list
end

local function fmtProfessions(m)
  local p = m.professions
  if type(p) ~= "table" or #p == 0 then
    return "—"
  end
  return table.concat(p, ", ")
end

function ns.BuildGuildView(parent)
  local title = W.fs(parent, "GameFontNormalHuge", L["GUILD_TAB"] or "Gilda")
  title:SetPoint("TOPLEFT", 16, -12)
  W.color(title, C.accent2)

  ui.meta = W.fs(parent, "GameFontNormalSmall", "", C.subtext)
  ui.meta:SetPoint("LEFT", title, "RIGHT", 12, 0)
  ui.meta:SetPoint("RIGHT", -16, 0)
  ui.meta:SetJustifyH("LEFT")

  local hint = W.fs(parent, "GameFontNormalSmall",
    L["GUILD_HINT"] or "Dati da Companion (Battle.net + Raider.IO). Fai Pull → /reload.",
    C.subtext)
  hint:SetPoint("TOPLEFT", 16, -40)
  hint:SetPoint("RIGHT", -16, 0)
  hint:SetJustifyH("LEFT")

  local head = W.fs(parent, "GameFontNormal",
    string.format("%-16s  %-10s  %-8s  %4s  %6s  %6s  %s",
      "Name", "Class", "Role", "Rank", "iLvl", "R.IO", "Professions"),
    C.accent)
  head:SetPoint("TOPLEFT", 20, -68)

  local panel = W.panel(parent, C.panelAlt)
  panel:SetPoint("TOPLEFT", 16, -90)
  panel:SetPoint("BOTTOMRIGHT", -16, 16)
  ui.panel = panel

  local scroll, child = W.scroll(panel)
  scroll:SetPoint("TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", -18, 6)
  ui.scroll = scroll
  ui.child = child or scroll.child
  ui.rows = {}

  parent._guildBuilt = true
end

local function ensureRow(i)
  local row = ui.rows[i]
  if row then return row end
  row = CreateFrame("Frame", nil, ui.child)
  row:SetHeight(22)
  row.fs = W.fs(row, "GameFontHighlightSmall", "", C.text)
  row.fs:SetPoint("LEFT", 2, 0)
  row.fs:SetPoint("RIGHT", -2, 0)
  row.fs:SetJustifyH("LEFT")
  ui.rows[i] = row
  return row
end

function ns.RefreshGuildView()
  local page = ns.panels and ns.panels.guild
  if not page or not page:IsShown() or not page._guildBuilt then return end
  if not ui.meta then return end

  local meta = (ns.db and ns.db.guildMeta) or {}
  local list = memberList()
  ui.meta:SetText(string.format("%s — %s  ·  %d members  ·  %s",
    tostring(meta.guild or (ns.db.meta and ns.db.meta.guild) or "?"),
    tostring(meta.realm or (ns.db.meta and ns.db.meta.realm) or "?"),
    #list,
    meta.exportedAt and ("sync " .. tostring(meta.exportedAt)) or "no guild sync yet"))

  local y = 0
  local width = math.max((ui.scroll:GetWidth() or 800) - 8, 400)
  if #list == 0 then
    local row = ensureRow(1)
    row:SetWidth(width)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, 0)
    row:Show()
    row.fs:SetText(L["GUILD_EMPTY"] or "Nessun membro. Companion: Login → Sync Battle.net → Pull → /reload.")
    for i = 2, #ui.rows do ui.rows[i]:Hide() end
    ui.child:SetHeight(24)
  else
    for i, m in ipairs(list) do
      local row = ensureRow(i)
      row:SetWidth(width)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, y)
      row:Show()
      local name = m.name or "?"
      if ns.ClassColorText then
        name = ns.ClassColorText(m.class, name)
      end
      local ilvl = m.itemLevel and tostring(m.itemLevel) or "—"
      local rio = m.rioScore and string.format("%.0f", tonumber(m.rioScore) or 0) or "—"
      local rank = m.rank ~= nil and tostring(m.rank) or "—"
      row.fs:SetText(string.format("%s  |  %s  |  %s  |  rank %s  |  iLvl %s  |  R.IO %s  |  %s",
        name,
        tostring(m.class or "?"),
        tostring(m.role ~= "" and m.role or "—"),
        rank, ilvl, rio,
        fmtProfessions(m)))
      y = y - 22
    end
    for i = #list + 1, #ui.rows do ui.rows[i]:Hide() end
    ui.child:SetHeight(math.max(22, #list * 22))
  end
  if ui.scroll.Refresh then ui.scroll:Refresh() end
end
