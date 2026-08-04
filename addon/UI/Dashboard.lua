local ADDON, ns = ...
local L = ns.L
local C = ns.Colors
local W = ns.W

local THRESH = { tank = 2, healer = 4, dps = 14 }

local CLASS_ORDER = {
  "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
  "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
}

local CLASS_DISPLAY = {
  WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue",
  PRIEST = "Priest", DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage",
  WARLOCK = "Warlock", MONK = "Monk", DRUID = "Druid", DEMONHUNTER = "Demon Hunter",
  EVOKER = "Evoker",
}

local function isActiveRaider(p)
  if p.intends == false then return false end
  local s = p.status
  if s == "non_raider" or s == "suspended" or s == "unavailable" then return false end
  return true
end

local function canRole(p, role)
  local primary = ns.BoardRole and ns.BoardRole(p.primaryRole) or string.lower(strtrim(tostring(p.primaryRole or "")))
  if primary == role then return true end
  for _, r in ipairs(p.offRoles or {}) do
    if string.lower(tostring(r)) == role then return true end
  end
  return false
end

local function setCardBorder(card, col)
  card:SetBackdropBorderColor(col[1], col[2], col[3], 1)
  card.forcedBorderColors = true
end

function ns.BuildDashboard(parent)
  local scroll, child = W.scroll(parent)
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -24, 8)
  parent.scroll = scroll
  parent.scrollChild = child or scroll.child
  child = parent.scrollChild
  child:SetWidth(900)

  local title = W.fs(child, "GameFontNormalHuge", L["DASHBOARD"])
  title:SetPoint("TOPLEFT", 8, -6)
  W.color(title, C.accent2)

  local meta = W.fs(child, "GameFontNormalSmall", "", C.subtext)
  meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  meta:SetJustifyH("LEFT")

  -- KPI row
  local cardsWrap = CreateFrame("Frame", nil, child)
  cardsWrap:SetPoint("TOPLEFT", 8, -52)
  cardsWrap:SetSize(880, 88)

  local kpiDefs = {
    { key = "active",  label = L["KPI_ACTIVE"] or "RAIDER ATTIVI", color = C.text, minKey = nil },
    { key = "tank",    label = L["KPI_TANK"] or "TANK (MAIN)", color = C.tank, minKey = "tank" },
    { key = "healer",  label = L["KPI_HEALER"] or "HEALER (MAIN)", color = C.healer, minKey = "healer" },
    { key = "dps",     label = L["KPI_DPS"] or "DPS (MAIN)", color = C.dps, minKey = "dps" },
    { key = "review",  label = L["KPI_REVIEW"] or "DA VERIFICARE", color = C.warn, minKey = nil },
    { key = "notes",   label = L["KPI_NOTES"] or "NOTE CRITICHE", color = C.warn, minKey = nil },
  }

  local cards = {}
  local cardW, gap = 138, 8
  for i, def in ipairs(kpiDefs) do
    local card = CreateFrame("Button", nil, cardsWrap, "BackdropTemplate")
    W.setBG(card, C.panelAlt)
    card:SetSize(cardW, 78)
    card:SetPoint("LEFT", (i - 1) * (cardW + gap), 0)
    card.lab = W.fs(card, "GameFontNormalSmall", def.label, C.subtext)
    card.lab:SetPoint("TOPLEFT", 10, -8)
    card.lab:SetPoint("TOPRIGHT", -8, -8)
    card.lab:SetJustifyH("LEFT")
    card.val = W.fs(card, "GameFontNormalHuge", "0")
    card.val:SetPoint("LEFT", 10, -4)
    W.color(card.val, def.color)
    card.sub = W.fs(card, "GameFontDisableSmall", "", C.subtext)
    card.sub:SetPoint("BOTTOMLEFT", 10, 8)
    cards[def.key] = card
    card.def = def

    card:SetScript("OnEnter", function(self)
      self:SetBackdropColor(C.rowHover[1], C.rowHover[2], C.rowHover[3], 1)
    end)
    card:SetScript("OnLeave", function(self)
      self:SetBackdropColor(C.panelAlt[1], C.panelAlt[2], C.panelAlt[3], 1)
    end)
  end

  cards.active:SetScript("OnClick", function()
    ns.OpenRosterFiltered({ module = "roster" })
  end)
  cards.tank:SetScript("OnClick", function()
    ns.OpenRosterFiltered({ role = "tank", module = "roster", primaryRoleOnly = true })
  end)
  cards.healer:SetScript("OnClick", function()
    ns.OpenRosterFiltered({ role = "healer", module = "roster", primaryRoleOnly = true })
  end)
  cards.dps:SetScript("OnClick", function()
    ns.OpenRosterFiltered({ role = "dps", module = "roster", primaryRoleOnly = true })
  end)
  cards.review:SetScript("OnClick", function()
    ns.OpenRosterFiltered({ status = "to_evaluate", module = "roster" })
  end)
  cards.notes:SetScript("OnClick", function()
    ns.OpenRosterFiltered({ criticalOnly = true, module = "roster" })
  end)

  -- Next steps banner
  local banner = W.panel(child, C.panelAlt)
  banner:SetPoint("TOPLEFT", 8, -150)
  banner:SetSize(880, 52)
  banner.title = W.fs(banner, "GameFontNormal", L["NEXT_STEPS"] or "Prossimi passi", C.accent2)
  banner.title:SetPoint("TOPLEFT", 12, -8)
  banner.body = W.fs(banner, "GameFontNormalSmall", "", C.subtext)
  banner.body:SetPoint("TOPLEFT", 12, -26)
  banner.body:SetPoint("RIGHT", -220, 0)
  banner.body:SetJustifyH("LEFT")

  local btnReview = W.button(banner, L["BTN_VERIFY"] or "Verifica dati", 110, 24, false, function()
    ns.OpenRosterFiltered({ status = "to_evaluate", module = "roster" })
  end)
  btnReview:SetPoint("RIGHT", -12, 0)

  local btnNotes = W.button(banner, L["BTN_ALERTS"] or "Vedi note", 100, 24, false, function()
    ns.OpenRosterFiltered({ criticalOnly = true, module = "roster" })
  end)
  btnNotes:SetPoint("RIGHT", btnReview, "LEFT", -6, 0)

  local btnEvents = W.button(banner, L["BTN_EVENTS"] or "Apri eventi", 100, 24, true, function()
    if ns.UI then ns.UI:ShowModule("events") end
  end)
  btnEvents:SetPoint("RIGHT", btnNotes, "LEFT", -6, 0)

  -- Section labels
  local secLabel = W.fs(child, "GameFontNormalSmall", L["OTHER_METRICS"] or "Altre metriche", C.subtext)
  secLabel:SetPoint("TOPLEFT", 8, -214)

  -- Class distribution panel
  local classPanel = W.panel(child, C.panelAlt)
  classPanel:SetPoint("TOPLEFT", 8, -234)
  classPanel:SetSize(430, 280)
  local classTitle = W.fs(classPanel, "GameFontNormal", L["CLASS_DIST"] or "Distribuzione classi", C.accent2)
  classTitle:SetPoint("TOPLEFT", 12, -10)
  classPanel.rows = {}
  for i = 1, 13 do
    local row = CreateFrame("Frame", nil, classPanel)
    row:SetSize(400, 18)
    row:SetPoint("TOPLEFT", 12, -32 - (i - 1) * 18)
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(8, 8)
    row.dot:SetPoint("LEFT", 0, 0)
    row.dot:SetColorTexture(1, 1, 1, 1)
    row.name = W.fs(row, "GameFontNormalSmall", "", C.text)
    row.name:SetPoint("LEFT", 14, 0)
    row.name:SetWidth(100)
    row.name:SetJustifyH("LEFT")
    row.barBg = row:CreateTexture(nil, "BACKGROUND")
    row.barBg:SetPoint("LEFT", 120, 0)
    row.barBg:SetSize(220, 8)
    row.barBg:SetColorTexture(0.12, 0.12, 0.16, 1)
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("LEFT", row.barBg, "LEFT", 0, 0)
    row.bar:SetHeight(8)
    row.bar:SetWidth(1)
    row.count = W.fs(row, "GameFontNormalSmall", "", C.subtext)
    row.count:SetPoint("LEFT", row.barBg, "RIGHT", 8, 0)
    row:Hide()
    classPanel.rows[i] = row
  end

  -- Role capacity panel
  local rolePanel = W.panel(child, C.panelAlt)
  rolePanel:SetPoint("TOPLEFT", 454, -234)
  rolePanel:SetSize(430, 280)
  local roleTitle = W.fs(rolePanel, "GameFontNormal", L["MAIN_ROLES"] or "Ruoli principali", C.accent2)
  roleTitle:SetPoint("TOPLEFT", 12, -10)

  -- Simple stacked visual: three big role blocks
  rolePanel.blocks = {}
  local roleKeys = {
    { key = "tank", label = "Tank", color = C.tank },
    { key = "healer", label = "Healer", color = C.healer },
    { key = "dps", label = "DPS", color = C.dps },
  }
  for i, rk in ipairs(roleKeys) do
    local block = CreateFrame("Frame", nil, rolePanel, "BackdropTemplate")
    W.setBG(block, C.panel)
    block:SetSize(120, 120)
    block:SetPoint("TOPLEFT", 24 + (i - 1) * 130, -50)
    setCardBorder(block, rk.color)
    block.val = W.fs(block, "GameFontNormalHuge", "0")
    block.val:SetPoint("CENTER", 0, 10)
    W.color(block.val, rk.color)
    block.lab = W.fs(block, "GameFontNormalSmall", rk.label, C.subtext)
    block.lab:SetPoint("CENTER", 0, -22)
    rolePanel.blocks[rk.key] = block
  end

  rolePanel.capTank = W.fs(rolePanel, "GameFontNormal", "", C.tank)
  rolePanel.capTank:SetPoint("BOTTOMLEFT", 24, 48)
  rolePanel.capHeal = W.fs(rolePanel, "GameFontNormal", "", C.healer)
  rolePanel.capHeal:SetPoint("BOTTOMLEFT", 24, 28)
  rolePanel.capDps = W.fs(rolePanel, "GameFontNormal", "", C.dps)
  rolePanel.capDps:SetPoint("BOTTOMLEFT", 24, 8)

  local emptyHint = W.fs(child, "GameFontNormal", L["NO_DATA"], C.subtext)
  emptyHint:SetPoint("TOPLEFT", 8, -160)
  emptyHint:Hide()

  child:SetHeight(530)

  function ns.RefreshDashboard()
    local m = ns.db.meta or {}
    meta:SetText(string.format("%s @ %s-%s  ·  %s  ·  export %s",
      m.guild ~= "" and m.guild or "—",
      m.realm ~= "" and m.realm or "?",
      m.region ~= "" and m.region or "?",
      m.season ~= "" and m.season or "—",
      m.exportedAt ~= "" and m.exportedAt or "—"))

    local list = ns.GetPlayersList()
    emptyHint:SetShown(#list == 0)
    banner:SetShown(#list > 0)
    classPanel:SetShown(#list > 0)
    rolePanel:SetShown(#list > 0)
    cardsWrap:SetShown(#list > 0)
    secLabel:SetShown(#list > 0)

    local active, review, critical = 0, 0, 0
    local main = { tank = 0, healer = 0, dps = 0 }
    local capable = { tank = 0, healer = 0, dps = 0 }
    local classCounts = {}

    for _, p in ipairs(list) do
      if isActiveRaider(p) then
        active = active + 1
        local r = ns.BoardRole and ns.BoardRole(p.primaryRole) or string.lower(strtrim(tostring(p.primaryRole or "")))
        if main[r] then main[r] = main[r] + 1 end
        for _, role in ipairs({ "tank", "healer", "dps" }) do
          if canRole(p, role) then capable[role] = capable[role] + 1 end
        end
        local token = ns.NormalizeClass(p.class)
        if token then classCounts[token] = (classCounts[token] or 0) + 1 end
      end
      if p.status == "to_evaluate" then review = review + 1 end
      local flags = ns.BuildFlags(p)
      if (p.notes and p.notes ~= "") or (p.tags and #p.tags > 0)
        or flags.uncertain or flags.work or flags.vacation
        or flags.low_attendance or flags.deferred_launch then
        critical = critical + 1
      end
    end

    local function paintKpi(key, value, minv, color)
      local card = cards[key]
      card.val:SetText(tostring(value))
      W.color(card.val, color)
      if minv then
        card.sub:SetText(string.format((L["KPI_MIN"] or "min %d"), minv))
        if value < minv then
          setCardBorder(card, C.bad)
          W.color(card.val, C.bad)
        else
          setCardBorder(card, C.border)
        end
      else
        card.sub:SetText("")
        setCardBorder(card, C.border)
      end
    end

    paintKpi("active", active, nil, C.text)
    paintKpi("tank", main.tank, THRESH.tank, C.tank)
    paintKpi("healer", main.healer, THRESH.healer, C.healer)
    paintKpi("dps", main.dps, THRESH.dps, C.dps)
    paintKpi("review", review, nil, C.warn)
    paintKpi("notes", critical, nil, C.warn)

    -- Banner message
    local issues = {}
    if main.tank < THRESH.tank then issues[#issues + 1] = string.format("Tank %d/%d", main.tank, THRESH.tank) end
    if main.healer < THRESH.healer then issues[#issues + 1] = string.format("Healer %d/%d", main.healer, THRESH.healer) end
    if main.dps < THRESH.dps then issues[#issues + 1] = string.format("DPS %d/%d", main.dps, THRESH.dps) end
    if review > 0 then issues[#issues + 1] = string.format((L["KPI_REVIEW"] or "Da verificare") .. " %d", review) end
    if #issues > 0 then
      banner.body:SetText((L["NEXT_STEPS_BODY"] or "Ci sono record da verificare o carenze di ruolo.") .. "  ·  " .. table.concat(issues, " · "))
    else
      banner.body:SetText(L["NEXT_STEPS_OK"] or "Roster in buono stato. Controlla Eventi per la serata.")
    end

    -- Class bars
    local maxC = 1
    local sorted = {}
    for _, token in ipairs(CLASS_ORDER) do
      local n = classCounts[token] or 0
      if n > 0 then
        sorted[#sorted + 1] = { token = token, n = n }
        if n > maxC then maxC = n end
      end
    end
    table.sort(sorted, function(a, b) return a.n > b.n end)
    for i, row in ipairs(classPanel.rows) do
      local item = sorted[i]
      if item then
        local col = ns.CLASS_COLORS[item.token] or { r = 0.7, g = 0.7, b = 0.7 }
        row.dot:SetColorTexture(col.r, col.g, col.b, 1)
        row.name:SetText(CLASS_DISPLAY[item.token] or item.token)
        row.bar:SetColorTexture(col.r, col.g, col.b, 0.85)
        row.bar:SetWidth(math.max(4, (item.n / maxC) * 220))
        row.count:SetText(tostring(item.n))
        row:Show()
      else
        row:Hide()
      end
    end

    -- Role blocks = MAIN counts; captions = capable
    rolePanel.blocks.tank.val:SetText(tostring(main.tank))
    rolePanel.blocks.healer.val:SetText(tostring(main.healer))
    rolePanel.blocks.dps.val:SetText(tostring(main.dps))
    rolePanel.capTank:SetText(string.format((L["CAPABLE_TANK"] or "Capaci Tank %d"), capable.tank))
    rolePanel.capHeal:SetText(string.format((L["CAPABLE_HEAL"] or "Capaci Heal %d"), capable.healer))
    rolePanel.capDps:SetText(string.format((L["CAPABLE_DPS"] or "Capaci DPS %d"), capable.dps))

    if parent.scroll.Refresh then parent.scroll:Refresh() end
  end
end
