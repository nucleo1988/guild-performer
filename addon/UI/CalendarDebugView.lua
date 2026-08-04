local ADDON, ns = ...
local L = ns.L
local C = ns.Colors
local W = ns.W

local ui = {}

local function rosterCount()
  local n = 0
  for _ in pairs(ns.db.players or {}) do n = n + 1 end
  return n
end

local function mainRoleFromMap(map)
  for _, role in ipairs(ns.CAL_ROLE_ORDER or { "tank", "healer", "melee", "ranged" }) do
    if map[role] == "MAIN" then return role end
  end
  return "?"
end

local function dumpApiLines()
  local lines = {}
  local function add(fmt, ...)
    lines[#lines + 1] = string.format(fmt, ...)
  end

  local okCal = false
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    okCal = C_AddOns.IsAddOnLoaded("Blizzard_Calendar")
  elseif IsAddOnLoaded then
    okCal = IsAddOnLoaded("Blizzard_Calendar")
  end

  add("--- API snapshot ---")
  add("Blizzard_Calendar loaded=%s  CalendarFrame=%s shown=%s",
    tostring(okCal),
    tostring(CalendarFrame ~= nil),
    tostring(CalendarFrame and CalendarFrame:IsShown()))
  add("calendarReady=%s scanning=%s lastError=%s",
    tostring(ns.Calendar.calendarReady), tostring(ns.Calendar.scanning), tostring(ns.Calendar.lastError or ""))

  local now = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
  if now then
    add("now=%04d-%02d-%02d", now.year or 0, now.month or 0, now.monthDay or 0)
  end

  local mi = C_Calendar and C_Calendar.GetMonthInfo and C_Calendar.GetMonthInfo(0)
  if mi then
    add("monthInfo(0)=%04d-%02d days=%s", mi.year or 0, mi.month or 0, tostring(mi.numDays))
  else
    add("monthInfo(0)=nil")
  end

  local numGet = C_Calendar and C_Calendar.GetNumInvites and C_Calendar.GetNumInvites()
  local numLegacy = C_Calendar and C_Calendar.EventGetNumInvites and C_Calendar.EventGetNumInvites()
  local num = numGet or numLegacy or 0
  add("GetNumInvites()=%s  EventGetNumInvites()=%s  (use GetNumInvites)",
    tostring(numGet), tostring(numLegacy))
  add("has GetNumInvites=%s  has EventGetNumInvites=%s",
    tostring(C_Calendar and C_Calendar.GetNumInvites ~= nil),
    tostring(C_Calendar and C_Calendar.EventGetNumInvites ~= nil))

  local evInfo = C_Calendar and C_Calendar.GetEventInfo and C_Calendar.GetEventInfo()
  if type(evInfo) == "table" then
    add("GetEventInfo title=%s type=%s creator=%s canEdit=%s",
      tostring(evInfo.title), tostring(evInfo.calendarType), tostring(evInfo.creator),
      tostring(C_Calendar.EventCanEdit and C_Calendar.EventCanEdit()))
  else
    add("GetEventInfo=%s", tostring(evInfo))
  end

  local sample = math.min(num, 8)
  for i = 1, sample do
    local a, b, c, d, e, f, g, h = C_Calendar.EventGetInvite(i)
    if type(a) == "table" then
      add("invite[%d] TABLE name=%s class=%s/%s status=%s",
        i, tostring(a.name), tostring(a.className), tostring(a.classFilename), tostring(a.inviteStatus))
    else
      add("invite[%d] MULTI a=%s(%s) b=%s c=%s d=%s e=%s f=%s g=%s h=%s",
        i, tostring(a), type(a), tostring(b), tostring(c), tostring(d), tostring(e), tostring(f), tostring(g), tostring(h))
    end
  end

  local ev = ns.Calendar.currentEvent
  if ev then
    add("currentEvent title=%s day=%s idx=%s off=%s fromOpen=%s",
      tostring(ev.title), tostring(ev.day), tostring(ev.index), tostring(ev.monthOffset), tostring(ev.fromOpenUI))
  else
    add("currentEvent=nil")
  end
  add("events=%d invitees=%d all=%d standby=%d rosterPlayers=%d",
    #(ns.Calendar.events or {}), #(ns.Calendar.invitees or {}), #(ns.Calendar.allInvitees or {}),
    #(ns.Calendar.standby or {}), rosterCount())
  add("--- end snapshot ---")
  return lines
end

function ns.BuildCalendarDebugView(parent)
  local title = W.fs(parent, "GameFontNormalHuge", L["CAL_DEBUG"] or "Debug Calendario")
  title:SetPoint("TOPLEFT", 16, -12)
  W.color(title, C.accent2)

  local hint = W.fs(parent, "GameFontNormalSmall",
    L["CAL_DEBUG_HINT"] or "Usa i comandi per vedere scan eventi, invite raw e match ruoli col roster.",
    C.subtext)
  hint:SetPoint("LEFT", title, "RIGHT", 12, 0)
  hint:SetPoint("RIGHT", -16, 0)
  hint:SetJustifyH("LEFT")

  local bar = CreateFrame("Frame", nil, parent)
  bar:SetPoint("TOPLEFT", 16, -42)
  bar:SetPoint("TOPRIGHT", -16, -42)
  bar:SetHeight(26)

  local x = 0
  local function addBtn(label, w, primary, fn)
    local b = W.button(bar, label, w, 24, primary, fn)
    b:SetPoint("LEFT", x, 0)
    x = x + w + 6
    return b
  end

  addBtn(L["CAL_DBG_SCAN"] or "Scan eventi", 110, true, function()
    ns.CalendarDebug("UI: RequestScan()", "info")
    ns.Calendar:RequestScan()
    ns.RefreshCalendarDebugView()
  end)
  addBtn(L["CAL_DBG_FORCE"] or "Force ScanEvents", 130, false, function()
    ns.CalendarDebug("UI: ScanEvents()", "info")
    ns.Calendar:ScanEvents()
    ns.RefreshCalendarDebugView()
  end)
  addBtn(L["CAL_READ_OPEN"] or "Leggi aperto", 120, false, function()
    ns.CalendarDebug("UI: ReadOpenBlizzardEvent()", "info")
    ns.Calendar:ReadOpenBlizzardEvent()
    ns.RefreshCalendarDebugView()
  end)
  addBtn(L["CAL_DBG_INVITES"] or "ReadInvitees", 110, false, function()
    ns.CalendarDebug("UI: ReadInvitees()", "info")
    ns.Calendar:ReadInvitees()
    ns.RefreshCalendarDebugView()
  end)
  addBtn(L["CAL_DBG_DUMP"] or "Dump API", 90, false, function()
    for _, line in ipairs(dumpApiLines()) do
      ns.CalendarDebug(line, "info")
    end
    ns.RefreshCalendarDebugView()
  end)
  addBtn(L["CAL_DBG_CLEAR"] or "Clear log", 90, false, function()
    wipe(ns.Calendar.debugLog)
    ns.Calendar.lastError = ""
    ns.RefreshCalendarDebugView()
  end)
  addBtn(L["CAL_DBG_PUSH"] or "Push prep", 90, true, function()
    ns.EnsureDB()
    if ns.RequestPushPrep then
      ns.RequestPushPrep("debug_manual", true)
    elseif ns.PreparePushForCompanion then
      local n, err = ns.PreparePushForCompanion()
      ns.CalendarDebug(n and ("pushprep OK n=" .. n) or ("pushprep FAIL " .. tostring(err)), n and "info" or "warn")
    end
    ns.RefreshCalendarDebugView()
  end)
  addBtn(L["CAL_DBG_PRINT"] or "→ Chat", 70, false, function()
    local log = ns.Calendar.debugLog or {}
    local start = math.max(1, #log - 40)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[GP CalDebug]|r ultime righe:")
    for i = start, #log do
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa" .. log[i] .. "|r")
    end
  end)

  -- Second row: auto push / reload (kept visible, not clipped by button overflow)
  local optBar = CreateFrame("Frame", nil, parent)
  optBar:SetPoint("TOPLEFT", 16, -70)
  optBar:SetPoint("TOPRIGHT", -16, -70)
  optBar:SetHeight(22)

  ns.EnsureDB()
  local autoCb = W.checkbox(optBar, L["CAL_DBG_AUTO_PUSH"] or "Auto push")
  autoCb:SetPoint("LEFT", 0, 0)
  autoCb:SetChecked(ns.db.settings.autoPushPrep ~= false)
  autoCb.onToggle = function(v)
    ns.EnsureDB()
    ns.db.settings.autoPushPrep = v and true or false
    ns.CalendarDebug("autoPushPrep=" .. tostring(v), "info")
    ns.RefreshCalendarDebugView()
  end
  ui.autoPushCb = autoCb

  local reloadCb = W.checkbox(optBar, L["CAL_DBG_AUTO_RELOAD"] or "Reload")
  reloadCb:SetPoint("LEFT", autoCb, "RIGHT", 100, 0)
  reloadCb:SetChecked(ns.db.settings.autoReloadForPush == true)
  reloadCb.onToggle = function(v)
    ns.EnsureDB()
    ns.db.settings.autoReloadForPush = v and true or false
    ns.CalendarDebug("autoReloadForPush=" .. tostring(v), "info")
    ns.RefreshCalendarDebugView()
  end
  ui.autoReloadCb = reloadCb

  ui.status = W.fs(parent, "GameFontNormalSmall", "", C.text)
  ui.status:SetPoint("TOPLEFT", 16, -96)
  ui.status:SetPoint("TOPRIGHT", -16, -96)
  ui.status:SetJustifyH("LEFT")

  -- Invitees / match panel
  local invHead = W.fs(parent, "GameFontNormal", L["CAL_DEBUG_MATCH"] or "Partecipanti → match roster / ruolo", C.accent)
  invHead:SetPoint("TOPLEFT", 16, -118)

  local invPanel = W.panel(parent, C.panelAlt)
  invPanel:SetPoint("TOPLEFT", 16, -138)
  invPanel:SetPoint("TOPRIGHT", -16, -138)
  invPanel:SetHeight(200)
  ui.invPanel = invPanel

  local invScroll, invChild = W.scroll(invPanel)
  invScroll:SetPoint("TOPLEFT", 6, -6)
  invScroll:SetPoint("BOTTOMRIGHT", -18, 6)
  ui.invScroll = invScroll
  ui.invChild = invChild or invScroll.child
  ui.invRows = {}

  -- Log panel
  local logHead = W.fs(parent, "GameFontNormal", L["CAL_DEBUG_LOG"] or "Log comandi calendario", C.accent)
  logHead:SetPoint("TOPLEFT", 16, -346)

  local logPanel = W.panel(parent, C.panelAlt)
  logPanel:SetPoint("TOPLEFT", 16, -366)
  logPanel:SetPoint("BOTTOMRIGHT", -16, 12)
  ui.logPanel = logPanel

  local logScroll, logChild = W.scroll(logPanel)
  logScroll:SetPoint("TOPLEFT", 6, -6)
  logScroll:SetPoint("BOTTOMRIGHT", -18, 6)
  ui.logScroll = logScroll
  ui.logChild = logChild or logScroll.child
  ui.logFS = W.fs(ui.logChild, "GameFontHighlightSmall", "", C.subtext)
  ui.logFS:SetPoint("TOPLEFT", 4, -2)
  ui.logFS:SetJustifyH("LEFT")
  ui.logFS:SetJustifyV("TOP")
  ui.logFS:SetNonSpaceWrap(true)

  parent._calDebugBuilt = true
end

local function ensureInvRow(i)
  local row = ui.invRows[i]
  if row then return row end
  row = CreateFrame("Frame", nil, ui.invChild, "BackdropTemplate")
  row:SetHeight(22)
  W.setBG(row, (i % 2 == 0) and C.row or C.panelAlt)
  row.fs = W.fs(row, "GameFontHighlightSmall", "", C.text)
  row.fs:SetPoint("LEFT", 6, 0)
  row.fs:SetPoint("RIGHT", -6, 0)
  row.fs:SetJustifyH("LEFT")
  row.fs:SetWordWrap(false)
  ui.invRows[i] = row
  return row
end

function ns.RefreshCalendarDebugView()
  local page = ns.panels and ns.panels.caldebug
  if not page or not page:IsShown() or not page._calDebugBuilt then return end
  if not ui.status then return end

  local Cal = ns.Calendar
  local ev = Cal.currentEvent
  local evLabel = ev and string.format("%s (%s %s)", ev.title or "?", ev.dateStr or "", ev.timeStr or "") or "—"
  local ginfo = ns.GuildEditDebugInfo and ns.GuildEditDebugInfo() or {}
  local canEditCal = Cal.CanEditCurrentEvent and Cal:CanEditCurrentEvent()
  local pushReady = ns.db and type(ns.db.pushRequestJson) == "string" and ns.db.pushRequestJson ~= ""
  local autoPush = not (ns.db and ns.db.settings and ns.db.settings.autoPushPrep == false)
  local autoReload = ns.db and ns.db.settings and ns.db.settings.autoReloadForPush == true
  if ui.autoPushCb then ui.autoPushCb:SetChecked(autoPush) end
  if ui.autoReloadCb then ui.autoReloadCb:SetChecked(autoReload) end
  ui.status:SetText(string.format(
    "ready=%s  scanning=%s  events=%d  invites(all)=%d  shown=%d  standby=%d  roster=%d  |  canEditCal=%s  canEditRoster=%s rank=%s  autoPush=%s pushReady=%s  |  current: %s",
    tostring(Cal.calendarReady), tostring(Cal.scanning),
    #(Cal.events or {}), #(Cal.allInvitees or {}), #(Cal.invitees or {}), #(Cal.standby or {}),
    rosterCount(),
    tostring(canEditCal), tostring(ginfo.canEdit), tostring(ginfo.rankIndex),
    tostring(autoPush), tostring(pushReady),
    evLabel
  ))

  local list = Cal.allInvitees or {}
  if #list == 0 then list = Cal.invitees or {} end

  local y = 0
  local width = math.max((ui.invScroll:GetWidth() or 800) - 8, 400)
  if #list == 0 then
    local row = ensureInvRow(1)
    row:SetWidth(width)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, 0)
    row:Show()
    local err = Cal.lastError ~= "" and (" |cffff8888" .. Cal.lastError .. "|r") or ""
    row.fs:SetText((L["CAL_NO_INVITES"] or "Nessun partecipante.") .. err
      .. "  |cff888888→ Dump API / Leggi evento aperto|r")
    for i = 2, #ui.invRows do ui.invRows[i]:Hide() end
    ui.invChild:SetHeight(24)
  else
    for i, p in ipairs(list) do
      local row = ensureInvRow(i)
      row:SetWidth(width)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, y)
      row:Show()

      local map, source, roster = ns.GetDefaultRoleMap(p)
      local main = mainRoleFromMap(map)
      local rosterBit
      if roster then
        rosterBit = string.format("|cff66ff66ROSTER|r %s/%s",
          string.upper(tostring(roster.primaryRole or "?")),
          tostring(roster.class or "?"))
      else
        rosterBit = "|cffff6666NO ROSTER|r"
      end
      local st = ns.CalendarStatusLabel(p.inviteStatus)
      local class = p.classFilename or p.className or "?"
      local nameCol = ns.ClassColorText and ns.ClassColorText(class, p.name) or (p.name or "?")
      row.fs:SetText(string.format("%s  |  %s  |  %s  |  %s  |  MAIN=%s  src=%s",
        nameCol, st, class, rosterBit, string.upper(main), tostring(source)))
      y = y - 22
    end
    for i = #list + 1, #ui.invRows do ui.invRows[i]:Hide() end
    ui.invChild:SetHeight(math.max(22, #list * 22))
  end
  if ui.invScroll.Refresh then ui.invScroll:Refresh() end

  local log = Cal.debugLog or {}
  local text
  if #log == 0 then
    text = "|cff888888(log vuoto — premi Scan / Dump API)|r"
  else
    local start = math.max(1, #log - 120)
    local bits = {}
    for i = start, #log do
      bits[#bits + 1] = log[i]
    end
    text = table.concat(bits, "\n")
  end
  ui.logFS:SetText(text)
  local logW = math.max((ui.logScroll:GetWidth() or 800) - 20, 200)
  ui.logFS:SetWidth(logW)
  local h = ui.logFS:GetStringHeight() or 40
  ui.logChild:SetWidth(logW)
  ui.logChild:SetHeight(math.max(h + 8, 40))
  if ui.logScroll.Refresh then ui.logScroll:Refresh() end
end
