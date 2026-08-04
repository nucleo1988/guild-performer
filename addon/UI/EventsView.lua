local ADDON, ns = ...
local L = ns.L
local C = ns.Colors
local W = ns.W

local ROLE_LABEL = {
  tank = "Tank", healer = "Healer", melee = "Melee", ranged = "Range",
}

local function shortName(raw)
  if not raw or raw == "" then return "?" end
  if Ambiguate then return Ambiguate(raw, "short") end
  return (raw:match("^[^-]+") or raw)
end

local function syncColumnContentWidth(col)
  local w = col.scroll and col.scroll:GetWidth()
  if w and w > 20 then
    col.scrollChild:SetWidth(w)
  end
end

local INVITE_STATUS_OPTS
local OFF_COL_W = 48
local STATUS_COL_W = 96

local function statusOpt(sid)
  sid = ns.NormalizeCalendarStatus and ns.NormalizeCalendarStatus(sid) or (tonumber(sid) or 0)
  local col = ns.CalendarStatusColor(sid)
  return {
    value = sid,
    text = ns.CalendarStatusLabel(sid),
    color = col and { col[1], col[2], col[3] } or nil,
  }
end

local function getInviteStatusOpts()
  local opts = {}
  local defaults = { 0, 1, 2, 3, 4, 5, 8 }
  for _, sid in ipairs(ns.CalendarStatusEditOptions or defaults) do
    opts[#opts + 1] = statusOpt(sid)
  end
  return opts
end

--- Edit choices + current status if outside the set-status list (e.g. Signed up=6).
local function statusOptsFor(current)
  current = ns.NormalizeCalendarStatus and ns.NormalizeCalendarStatus(current) or (tonumber(current) or 0)
  local base = getInviteStatusOpts()
  for _, o in ipairs(base) do
    if tonumber(o.value) == current then return base end
  end
  local opts = { statusOpt(current) }
  for _, o in ipairs(base) do
    opts[#opts + 1] = o
  end
  return opts
end

local function ensureRow(col, i)
  local row = col.rows[i]
  if row and row._gpLayout ~= 7 then
    row:Hide()
    col.rows[i] = nil
    row = nil
  end
  if row then return row end

  row = CreateFrame("Frame", nil, col.scrollChild)
  row:SetHeight(28)
  row._gpLayout = 7

  row.stripe = row:CreateTexture(nil, "ARTWORK")
  row.stripe:SetWidth(3)
  row.stripe:SetPoint("TOPLEFT", 0, -1)
  row.stripe:SetPoint("BOTTOMLEFT", 0, 1)
  row.stripe:SetColorTexture(0.5, 0.5, 0.55, 1)

  -- Fixed OFF column (keeps status column aligned even when empty)
  row.offFS = W.fs(row, "GameFontDisableSmall", "", C.subtext)
  row.offFS:SetPoint("RIGHT", -2, 0)
  row.offFS:SetJustifyH("RIGHT")
  row.offFS:SetWidth(OFF_COL_W)
  row.offFS:SetWordWrap(false)

  -- Status combo (editable when can edit calendar event)
  row.statusDD = W.dropdown(row, STATUS_COL_W, 22)
  row.statusDD:SetPoint("RIGHT", -2 - OFF_COL_W - 4, 0)
  row.statusDD:SetFrameLevel(row:GetFrameLevel() + 5)
  row.statusDD:SetOptions(getInviteStatusOpts())

  -- Read-only status fallback (same slot as combo)
  row.statusFS = W.fs(row, "GameFontNormalSmall", "", C.subtext)
  row.statusFS:SetPoint("RIGHT", -2 - OFF_COL_W - 4, 0)
  row.statusFS:SetJustifyH("RIGHT")
  row.statusFS:SetWidth(STATUS_COL_W)
  row.statusFS:SetWordWrap(false)
  row.statusFS:Hide()

  row.name = W.fs(row, "GameFontHighlightSmall", "")
  row.name:SetPoint("LEFT", 8, 0)
  row.name:SetPoint("RIGHT", row.statusDD, "LEFT", -4, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)

  col.rows[i] = row
  return row
end

function ns.BuildEventsView(parent)
  -- LIST MODE
  local list = CreateFrame("Frame", nil, parent)
  list:SetAllPoints()
  parent.listMode = list

  local title = W.fs(list, "GameFontNormalHuge", L["EVENTS"] or "Eventi")
  title:SetPoint("TOPLEFT", 16, -12)
  W.color(title, C.accent2)
  list.title = title

  list.countFS = W.fs(list, "GameFontNormalSmall", "", C.subtext)
  list.countFS:SetPoint("LEFT", title, "RIGHT", 12, 0)

  local refresh = W.button(list, L["REFRESH"] or "Aggiorna", 100, 26, true, function()
    ns.Calendar:RequestScan()
  end)
  refresh:SetPoint("TOPRIGHT", -16, -12)
  list.refresh = refresh

  local readOpen = W.button(list, L["CAL_READ_OPEN"] or "Leggi evento aperto", 160, 26, false, function()
    if ns.Calendar:ReadOpenBlizzardEvent() then
      ns.ShowEventsDetail()
    end
  end)
  readOpen:SetPoint("TOPRIGHT", refresh, "TOPLEFT", -6, 0)
  list.readOpen = readOpen

  local hint = W.fs(list, "GameFontNormalSmall", L["EVENTS_HINT"] or "Clicca un evento, oppure apri l'evento nel calendario Blizzard e premi «Leggi evento aperto».", C.subtext)
  hint:SetPoint("TOPLEFT", 16, -42)
  hint:SetPoint("TOPRIGHT", -180, -42)
  hint:SetJustifyH("LEFT")
  list.hint = hint

  list.emptyFS = W.fs(list, "GameFontNormal", "", C.warn)
  list.emptyFS:SetPoint("CENTER", 0, 20)
  list.emptyFS:Hide()

  local scroll, scrollChild = W.scroll(list)
  scroll:SetPoint("TOPLEFT", 16, -64)
  scroll:SetPoint("BOTTOMRIGHT", -28, 16)
  list.scroll = scroll
  list.scrollChild = scrollChild or scroll.child
  list.rows = {}
  scroll:HookScript("OnSizeChanged", function()
    if ns.RefreshEventsList and list:IsShown() then
      ns.RefreshEventsList()
    end
  end)

  -- DETAIL MODE
  local detail = CreateFrame("Frame", nil, parent)
  detail:SetAllPoints()
  detail:Hide()
  parent.detailMode = detail

  local back = W.arrowButton(detail, "left", 26, function()
    ns.ShowEventsList()
  end)
  back:SetPoint("TOPLEFT", 16, -12)
  back:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(C.accent2[1], C.accent2[2], C.accent2[3], 1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["BACK"] or "← Eventi")
    GameTooltip:Show()
  end)
  back:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    GameTooltip:Hide()
  end)
  detail.back = back

  detail.title = W.fs(detail, "GameFontNormalHuge", "")
  detail.title:SetPoint("LEFT", back, "RIGHT", 10, 0)
  W.color(detail.title, C.accent2)

  detail.meta = W.fs(detail, "GameFontNormalSmall", "", C.subtext)
  detail.meta:SetPoint("TOPLEFT", 16, -42)

  detail.statusFS = W.fs(detail, "GameFontNormalSmall", "", C.text)
  detail.statusFS:SetPoint("TOPLEFT", 16, -60)

  local reload = W.button(detail, L["REFRESH"] or "Aggiorna", 90, 26, false, function()
    if ns.Calendar.ClearPendingStatuses then ns.Calendar:ClearPendingStatuses() end
    if ns.Calendar.currentEvent then
      if ns.Calendar.currentEvent.fromOpenUI then
        ns.Calendar:ReadOpenBlizzardEvent()
      else
        ns.Calendar:OpenEvent(ns.Calendar.currentEvent)
      end
    end
  end)
  reload:SetPoint("TOPRIGHT", -16, -12)
  detail.reload = reload

  local applyBtn = W.button(detail, L["CAL_APPLY_STATUS"] or "Salva in calendario", 150, 26, true, function()
    local ok, a, b = ns.Calendar:ApplyPendingStatuses()
    if ok then
      local n = tonumber(a) or 0
      if ns.Print then
        ns.Print(string.format(L["CAL_APPLY_OK"] or "Stati aggiornati sul calendario (%d).", n))
      end
    else
      local err = a
      local msg = L["CAL_APPLY_FAIL"] or "Impossibile aggiornare il calendario."
      if err == "none" then msg = L["CAL_APPLY_NONE"] or "Nessuna modifica da salvare." end
      if err == "no_edit" then msg = L["CAL_APPLY_NO_EDIT"] or "Non puoi modificare questo evento." end
      if ns.Print then ns.Print(msg) end
    end
    if detail.syncApplyLabel then
      local pending = ns.Calendar:CountPendingStatuses()
      detail.syncApplyLabel:SetText(pending > 0
        and string.format(L["CAL_PENDING"] or "%d modifiche da salvare", pending)
        or "")
    end
    ns.RefreshEventsDetail()
  end)
  applyBtn:SetPoint("TOPRIGHT", reload, "TOPLEFT", -6, 0)
  detail.applyBtn = applyBtn

  detail.syncApplyLabel = W.fs(detail, "GameFontNormalSmall", "", C.warn)
  detail.syncApplyLabel:SetPoint("RIGHT", applyBtn, "LEFT", -10, 0)

  -- Role columns: more height (no role-count line / status filter chips)
  local cols = CreateFrame("Frame", nil, detail)
  cols:SetPoint("TOPLEFT", 12, -78)
  cols:SetPoint("BOTTOMRIGHT", -12, 118)
  detail.cols = cols
  detail.columns = {}

  for _, role in ipairs(ns.CAL_ROLE_ORDER) do
    local col = W.panel(cols, C.panelAlt)
    col.role = role
    col.header = W.fs(col, "GameFontNormal", ROLE_LABEL[role])
    col.header:SetPoint("TOPLEFT", 10, -10)
    W.color(col.header, C[role] or C.accent)
    local sc, scChild = W.scroll(col)
    sc:SetPoint("TOPLEFT", 4, -30)
    sc:SetPoint("BOTTOMRIGHT", -16, 6)
    col.scroll = sc
    col.scrollChild = scChild or sc.child
    col.rows = {}
    sc:HookScript("OnSizeChanged", function()
      syncColumnContentWidth(col)
    end)
    detail.columns[role] = col
  end

  cols:SetScript("OnSizeChanged", function(self, w)
    local gap, n = 8, 4
    local cw = (w - gap * (n - 1)) / n
    for i, role in ipairs(ns.CAL_ROLE_ORDER) do
      local col = detail.columns[role]
      col:ClearAllPoints()
      col:SetWidth(cw)
      col:SetPoint("TOPLEFT", (i - 1) * (cw + gap), 0)
      col:SetPoint("BOTTOMLEFT", (i - 1) * (cw + gap), 0)
      syncColumnContentWidth(col)
    end
  end)

  -- Buff / Utilities / Cooldowns footer
  local footer = W.panel(detail, C.panelAlt)
  footer:SetPoint("BOTTOMLEFT", 12, 10)
  footer:SetPoint("BOTTOMRIGHT", -12, 10)
  footer:SetHeight(110)
  detail.footer = footer
  detail.buffSections = {}

  local sectionDefs = {
    { key = "buffs", label = L["BUFFS"] or "BUFF" },
    { key = "utilities", label = L["UTILITIES"] or "UTILITIES" },
    { key = "cooldowns", label = L["COOLDOWNS"] or "COOLDOWNS" },
  }
  for i, def in ipairs(sectionDefs) do
    local s = CreateFrame("Frame", nil, footer)
    s:SetPoint("TOPLEFT", 12 + (i - 1) * 300, -10)
    s:SetSize(290, 92)
    s.title = W.fs(s, "GameFontNormalSmall", def.label, C.subtext)
    s.title:SetPoint("TOPLEFT", 0, 0)
    s.body = W.fs(s, "GameFontHighlightSmall", "", C.text)
    s.body:SetPoint("TOPLEFT", 0, -18)
    s.body:SetPoint("BOTTOMRIGHT", 0, 0)
    s.body:SetJustifyH("LEFT")
    s.body:SetJustifyV("TOP")
    s.body:SetWordWrap(true)
    detail.buffSections[def.key] = s
  end

  parent.detail = detail
  ns.ShowEventsList()
end

function ns.ShowEventsList()
  local page = ns.panels and ns.panels.events
  if not page then return end
  page.listMode:Show()
  page.detailMode:Hide()
  ns.RefreshEventsList()
end

function ns.ShowEventsDetail()
  local page = ns.panels and ns.panels.events
  if not page then return end
  page.listMode:Hide()
  page.detailMode:Show()
  ns.RefreshEventsDetail()
end

function ns.RefreshEventsList()
  local page = ns.panels and ns.panels.events
  if not page or not page.listMode then return end
  local list = page.listMode
  local events = ns.Calendar.events or {}
  local content = list.scrollChild
  local scrollW = (list.scroll and list.scroll:GetWidth()) or 700
  local rowW = math.max(200, scrollW - 4)
  content:SetWidth(rowW)

  for _, r in ipairs(list.rows) do r:Hide() end

  local y = 0
  for i, ev in ipairs(events) do
    local row = list.rows[i]
    if not row or row._gpEventRow ~= 3 then
      if row then row:Hide(); row:SetParent(nil) end
      row = CreateFrame("Button", nil, content, "BackdropTemplate")
      row:SetHeight(48)
      row._gpEventRow = 3
      row:EnableMouse(true)
      row:RegisterForClicks("LeftButtonUp")
      W.setBG(row, C.row)
      row.title = W.fs(row, "GameFontNormal", "", C.text)
      row.title:SetJustifyH("LEFT")
      row.title:SetWordWrap(false)
      row.meta = W.fs(row, "GameFontNormalSmall", "", C.subtext)
      row.meta:SetJustifyH("LEFT")
      row.meta:SetWordWrap(false)
      list.rows[i] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -y)
    row:SetSize(rowW, 48)
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", 12, -10)
    row.title:SetPoint("TOPRIGHT", -12, -10)
    row.meta:ClearAllPoints()
    row.meta:SetPoint("BOTTOMLEFT", 12, 10)
    row.meta:SetPoint("BOTTOMRIGHT", -12, 10)
    row.title:SetText(ev.title or "?")
    W.color(row.title, C.text)
    row.meta:SetText(string.format("%s  %s  ·  %s", ev.dateStr or "", ev.timeStr or "", ev.calendarType or ""))
    row:SetScript("OnEnter", function(self)
      self:SetBackdropColor(C.rowHover[1], C.rowHover[2], C.rowHover[3], 1)
    end)
    row:SetScript("OnLeave", function(self)
      self:SetBackdropColor(C.row[1], C.row[2], C.row[3], 1)
    end)
    row:SetScript("OnClick", function()
      ns.ShowEventsDetail()
      ns.Calendar:OpenEvent(ev)
    end)
    row:Show()
    y = y + 54
  end
  content:SetHeight(math.max(y, 1))
  if list.scroll.Refresh then list.scroll:Refresh() end

  if ns.Calendar.scanning then
    list.countFS:SetText(L["SCANNING"] or "Scansione…")
    list.emptyFS:Hide()
  else
    list.countFS:SetText(string.format("(%d)", #events))
    if #events == 0 then
      local err = ns.Calendar.lastError or ""
      list.emptyFS:SetText((L["EVENTS_EMPTY"] or "Nessun evento in lista.")
        .. "\n" .. (L["CAL_READ_OPEN_HINT"] or "Apri l'evento nel calendario WoW e clicca «Leggi evento aperto».")
        .. (err ~= "" and ("\n|cffff8888" .. err .. "|r") or ""))
      list.emptyFS:Show()
    else
      list.emptyFS:Hide()
    end
  end
end

local function allInvitees()
  local src = ns.Calendar.allInvitees
  if not src or #src == 0 then src = ns.Calendar.invitees or {} end
  return src
end

function ns.RefreshEventsDetail()
  local page = ns.panels and ns.panels.events
  if not page or not page.detailMode or not page.detailMode:IsShown() then
    -- still refresh list counts when scanning
    if page and page.listMode and page.listMode:IsShown() then
      ns.RefreshEventsList()
    end
    return
  end
  local detail = page.detailMode
  local ev = ns.Calendar.currentEvent
  if not ev then
    detail.title:SetText(L["NO_EVENT"] or "Nessun evento")
    detail.meta:SetText(L["CAL_READ_OPEN_HINT"] or "")
    detail.statusFS:SetText("")
    return
  end

  detail.title:SetText(ev.title or "?")
  detail.meta:SetText(string.format("%s  %s  ·  %s  ·  %s",
    ev.dateStr or "", ev.timeStr or "", ev.calendarType or "",
    ev.creator or ""))

  -- Compact status summary (no role totals / no filter chips)
  local all = ns.Calendar.allInvitees or {}
  local countsStatus = {}
  for _, p in ipairs(all) do
    local s = p.inviteStatus or -1
    countsStatus[s] = (countsStatus[s] or 0) + 1
  end
  local parts = {}
  for _, sid in ipairs({ 1, 2, 3, 4, 8, 0, 5, 6, 7 }) do
    if countsStatus[sid] then
      parts[#parts + 1] = string.format("%s %d", ns.CalendarStatusLabel(sid), countsStatus[sid])
    end
  end
  if #all == 0 then
    detail.statusFS:SetText(L["CAL_NO_INVITES"] or "Nessun partecipante letto. Usa «Leggi evento aperto» con il calendario Blizzard aperto.")
  else
    detail.statusFS:SetText(table.concat(parts, "  ·  "))
  end

  local invitees = allInvitees()
  local columns, counts = ns.BuildCalColumns(invitees)
  -- Calendar invite status is gated by Blizzard EventCanEdit (creator/moderator).
  -- Roster ACL (CanEditRoster) still gates roster tab / companion pushprep.
  local canEdit = ns.Calendar.CanEditCurrentEvent and ns.Calendar:CanEditCurrentEvent()
  local pendingN = ns.Calendar.CountPendingStatuses and ns.Calendar:CountPendingStatuses() or 0
  if detail.syncApplyLabel then
    detail.syncApplyLabel:SetText(pendingN > 0
      and string.format(L["CAL_PENDING"] or "%d modifiche da salvare", pendingN)
      or (canEdit and "" or (L["CAL_READONLY"] or "Solo lettura")))
  end
  if detail.applyBtn then
    detail.applyBtn:SetEnabled(canEdit and pendingN > 0)
  end

  for _, role in ipairs(ns.CAL_ROLE_ORDER) do
    local col = detail.columns[role]
    local list = columns[role] or {}
    col.header:SetText(string.format("%s (%d)", ROLE_LABEL[role], counts[role] or 0))
    syncColumnContentWidth(col)
    for _, r in ipairs(col.rows) do r:Hide() end
    local y = 0
    local rowW = math.max((col.scrollChild:GetWidth() or 0) - 2, 80)
    for i, entry in ipairs(list) do
      local p = entry.player
      local row = ensureRow(col, i)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -y)
      row:SetWidth(rowW)

      local roster = ns.FindRosterPlayer(p.name)
      local classTok = p.classFilename or (roster and roster.class) or p.className
      local shown = shortName(p.name)
      row.name:SetText(ns.ClassColorText(classTok, shown) or shown)

      local statusVal = tonumber(p.inviteStatus)
      if ns.Calendar.pendingStatuses and p.index and ns.Calendar.pendingStatuses[p.index] ~= nil then
        statusVal = tonumber(ns.Calendar.pendingStatuses[p.index])
      end
      statusVal = ns.NormalizeCalendarStatus and ns.NormalizeCalendarStatus(statusVal) or (statusVal or 0)
      local st = ns.CalendarStatusLabel(statusVal)
      local sc = ns.CalendarStatusColor(statusVal)

      local offLabel = entry.offLabel or ns.FormatCalOffLabel(p) or ""
      row.offFS:SetWidth(OFF_COL_W)
      row.offFS:SetText(offLabel)
      W.color(row.offFS, C.subtext)

      if canEdit and p.index then
        row.statusDD:Show()
        row.statusFS:Hide()
        row.statusDD:ClearAllPoints()
        row.statusDD:SetPoint("RIGHT", -2 - OFF_COL_W - 4, 0)
        row.statusDD:SetOptions(statusOptsFor(statusVal))
        row.statusDD:SetValue(statusVal)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", 8, 0)
        row.name:SetPoint("RIGHT", row.statusDD, "LEFT", -4, 0)
        row.statusDD.onSelect = function(v)
          ns.Calendar:SetPendingInviteStatus(p.index, v)
          local pending = ns.Calendar:CountPendingStatuses()
          if detail.syncApplyLabel then
            detail.syncApplyLabel:SetText(pending > 0
              and string.format(L["CAL_PENDING"] or "%d modifiche da salvare", pending)
              or "")
          end
          if detail.applyBtn then detail.applyBtn:SetEnabled(pending > 0) end
          -- light refresh of counts / columns (status may move standby etc.)
          ns.RefreshEventsDetail()
        end
      else
        row.statusDD:Hide()
        row.statusFS:Show()
        row.statusFS:ClearAllPoints()
        row.statusFS:SetPoint("RIGHT", -2 - OFF_COL_W - 4, 0)
        row.statusFS:SetWidth(STATUS_COL_W)
        row.statusFS:SetText(st)
        W.color(row.statusFS, sc)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", 8, 0)
        row.name:SetPoint("RIGHT", row.statusFS, "LEFT", -4, 0)
      end

      local cc = ns.NormalizeClass and ns.NormalizeClass(classTok)
      local colClass = cc and ns.CLASS_COLORS and ns.CLASS_COLORS[cc]
      if colClass then
        row.stripe:SetColorTexture(colClass.r, colClass.g, colClass.b, 1)
      else
        row.stripe:SetColorTexture(sc[1], sc[2], sc[3], 1)
      end

      row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(p.name or shown, 1, 1, 1)
        GameTooltip:AddLine((p.className or p.classFilename or ""), 0.75, 0.75, 0.8)
        GameTooltip:AddLine(st, sc[1], sc[2], sc[3])
        if canEdit then
          GameTooltip:AddLine(L["CAL_STATUS_HINT"] or "Cambia stato qui, poi «Salva in calendario».", 0.7, 0.7, 0.75, true)
        end
        GameTooltip:AddLine((ROLE_LABEL[role] or role), 0.4, 0.9, 0.55)
        if offLabel ~= "" then
          GameTooltip:AddLine(offLabel, 0.65, 0.65, 0.7)
        end
        local _, source = ns.GetDefaultRoleMap(p)
        GameTooltip:AddLine((L["ROLE_SOURCE"] or "Ruolo da") .. ": " .. tostring(source), 0.7, 0.7, 0.7)
        if roster then
          GameTooltip:AddLine((L["ROSTER"] or "Roster") .. ": " .. (roster.primaryRole or "?"), 0.6, 0.8, 1)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)

      row:Show()
      y = y + 30
    end
    col.scrollChild:SetHeight(math.max(y, 1))
    if col.scroll.Refresh then col.scroll:Refresh() end
  end

  -- Buff coverage from accepted/confirmed (fallback: full list)
  local forBuffs = {}
  for _, p in ipairs(invitees) do
    local st = p.inviteStatus
    if st == 1 or st == 3 or st == 6 or st == 8 then
      forBuffs[#forBuffs + 1] = p
    end
  end
  if #forBuffs == 0 then forBuffs = invitees end
  local coverage = ns.ComputeBuffCoverage and ns.ComputeBuffCoverage(forBuffs, true)
    or { buffs = {}, utilities = {}, cooldowns = {} }
  local function fillBuff(key, items)
    local s = detail.buffSections and detail.buffSections[key]
    if not s then return end
    local lines = {}
    for _, item in ipairs(items or {}) do
      local color = item.missing and "|cffff6b6b" or "|cffcccccc"
      lines[#lines + 1] = string.format("%s%s  %d|r", color, item.label, item.count)
    end
    s.body:SetText(table.concat(lines, "\n"))
  end
  fillBuff("buffs", coverage.buffs)
  fillBuff("utilities", coverage.utilities)
  fillBuff("cooldowns", coverage.cooldowns)
end

function ns.RefreshEventsView()
  local page = ns.panels and ns.panels.events
  if not page then return end
  if page.detailMode and page.detailMode:IsShown() then
    ns.RefreshEventsDetail()
  else
    ns.RefreshEventsList()
  end
end
