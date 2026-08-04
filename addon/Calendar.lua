local ADDON, ns = ...

ns.Calendar = ns.Calendar or {}
local Cal = ns.Calendar

Cal.events = {}
Cal.currentEvent = nil
Cal.invitees = {}
Cal.standby = {}
Cal.allInvitees = {}
Cal.pendingStatuses = {} -- [inviteIndex] = Enum.CalendarStatus
Cal.scanning = false
Cal.calendarReady = false
Cal._scanToken = 0
Cal.debugLog = {}
Cal.lastError = ""

local STATUS = {
  INVITED = 0, AVAILABLE = 1, DECLINED = 2, CONFIRMED = 3,
  OUT = 4, STANDBY = 5, SIGNEDUP = 6, NOTSIGNEDUP = 7, TENTATIVE = 8,
}
ns.CalendarStatus = STATUS

--- Same choices as Blizzard calendar "Imposta lo stato" context menu (+ Invited / Standby).
ns.CalendarStatusEditOptions = {
  STATUS.INVITED,    -- Invitato
  STATUS.AVAILABLE,  -- Accettato
  STATUS.DECLINED,   -- Rifiutato
  STATUS.CONFIRMED,  -- Confermato
  STATUS.OUT,        -- Escluso
  STATUS.STANDBY,    -- In attesa
  STATUS.TENTATIVE,  -- Incerto
}

local function dbg(msg, level)
  local line = string.format("[%s] [%s] %s", date("%H:%M:%S"), level or "info", tostring(msg))
  Cal.debugLog[#Cal.debugLog + 1] = line
  while #Cal.debugLog > 300 do table.remove(Cal.debugLog, 1) end
  if level == "warn" or level == "error" then
    Cal.lastError = tostring(msg)
  end
  if ns.RefreshCalendarDebugView then
    -- throttle UI refresh while scanning floods the log
    if not Cal._dbgRefreshPending then
      Cal._dbgRefreshPending = true
      C_Timer.After(0.05, function()
        Cal._dbgRefreshPending = false
        if ns.RefreshCalendarDebugView then ns.RefreshCalendarDebugView() end
      end)
    end
  end
end
ns.CalendarDebug = dbg

local function AddonIsLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
  if IsAddOnLoaded then return IsAddOnLoaded(name) end
  return false
end

local function LoadBlizzardCalendar()
  if AddonIsLoaded("Blizzard_Calendar") then return true, "already" end
  local loaded, reason
  if C_AddOns and C_AddOns.LoadAddOn then
    loaded, reason = C_AddOns.LoadAddOn("Blizzard_Calendar")
  elseif UIParentLoadAddOn then
    loaded = UIParentLoadAddOn("Blizzard_Calendar")
  elseif LoadAddOn then
    loaded, reason = LoadAddOn("Blizzard_Calendar")
  end
  return AddonIsLoaded("Blizzard_Calendar"), reason or (loaded and "ok" or "fail")
end

local function dateKey(y, m, d)
  return string.format("%04d-%02d-%02d", y, m, d)
end

local function isPastDate(y, m, d)
  local now = C_DateAndTime.GetCurrentCalendarTime()
  if y < now.year then return true end
  if y > now.year then return false end
  if m < now.month then return true end
  if m > now.month then return false end
  return d < now.monthDay
end

-- Only player/guild/community created events (never Blizzard holidays, lockouts, system notes).
local CREATED_TYPES = {
  PLAYER = true,
  GUILD_EVENT = true,
  COMMUNITY_EVENT = true,
}

local function calendarTypeAllowed(calendarType)
  return calendarType and CREATED_TYPES[calendarType] == true
end

--- Current retail Blizzard UI uses C_Calendar.GetNumInvites() (not EventGetNumInvites).
local function GetNumInvites()
  if C_Calendar.GetNumInvites then
    local n = C_Calendar.GetNumInvites()
    if n ~= nil then return n end
  end
  -- Legacy fallback (pre-rename / older clients)
  if C_Calendar.EventGetNumInvites then
    local n = C_Calendar.EventGetNumInvites()
    if n ~= nil then return n end
  end
  return 0
end

--- Normalize EventGetInvite across API shapes (table vs multi-return).
local function GetInviteRow(i)
  local a, b, c, d, e, f, g, h = C_Calendar.EventGetInvite(i)
  if type(a) == "table" then
    local name = a.name or a.inviteeName or a.playerName
    if name and name ~= "" then
      a.name = name
      return a
    end
    return nil
  end
  if type(a) == "string" and a ~= "" then
    return {
      name = a,
      level = b,
      className = c,
      classFilename = d,
      inviteStatus = e,
      modStatus = f,
      inviteIsMine = g,
      classID = h,
    }
  end
  return nil
end

local function scheduleInviteRetries(eventRef)
  -- Invites often arrive on CALENDAR_UPDATE_INVITE_LIST after OpenEvent.
  local delays = { 0.15, 0.4, 0.8, 1.5, 2.5 }
  for _, d in ipairs(delays) do
    C_Timer.After(d, function()
      if eventRef and Cal.currentEvent ~= eventRef then return end
      if GetNumInvites() > 0 or d >= 2.5 then
        Cal:ReadInvitees()
      end
    end)
  end
end

function Cal:EnsureCalendarReady()
  local ok, how = LoadBlizzardCalendar()
  dbg(string.format("LoadAddOn Blizzard_Calendar → %s (%s)", tostring(ok), tostring(how)), ok and "info" or "warn")
  if not ok then return false end

  if self.calendarReady and CalendarFrame then return true end

  local primed = false
  pcall(function()
    if Calendar_Show and Calendar_Hide then
      local wasShown = CalendarFrame and CalendarFrame:IsShown()
      Calendar_Show()
      if not wasShown and CalendarFrame then Calendar_Hide() end
      primed = true
    elseif Calendar_Toggle and CalendarFrame then
      if not CalendarFrame:IsShown() then Calendar_Toggle(); Calendar_Toggle() end
      primed = true
    elseif CalendarFrame and ShowUIPanel then
      local wasShown = CalendarFrame:IsShown()
      ShowUIPanel(CalendarFrame)
      if not wasShown and HideUIPanel then HideUIPanel(CalendarFrame) end
      primed = true
    end
  end)
  -- Only reset month once on first prime (avoid desyncing open-event indices)
  if C_Calendar.SetMonth then pcall(C_Calendar.SetMonth, 0) end
  self.calendarReady = primed or (CalendarFrame ~= nil)
  dbg("Calendar ready=" .. tostring(self.calendarReady), "info")
  return self.calendarReady
end

function Cal:RequestScan()
  self.scanning = true
  self._scanToken = self._scanToken + 1
  local token = self._scanToken
  if ns.RefreshEventsView then ns.RefreshEventsView() end

  if not self:EnsureCalendarReady() then
    self.scanning = false
    if ns.RefreshEventsView then ns.RefreshEventsView() end
    return
  end

  dbg("OpenCalendar()", "info")
  C_Calendar.OpenCalendar()

  if self._watchdog then self._watchdog:Cancel() end
  self._watchdog = C_Timer.NewTimer(2.5, function()
    if token ~= Cal._scanToken or not Cal.scanning then return end
    dbg("WATCHDOG: forcing ScanEvents", "warn")
    Cal:ScanEvents()
  end)
end

function Cal:ScanEvents()
  if self._watchdog then self._watchdog:Cancel(); self._watchdog = nil end
  -- Only current calendar month (monthOffset = 0)
  local monthOffset = 0
  local list = {}
  local now = C_DateAndTime.GetCurrentCalendarTime()
  local raw, skipped = 0, 0
  local typeCounts = {}

  local monthInfo = C_Calendar.GetMonthInfo and C_Calendar.GetMonthInfo(monthOffset)
  local year = monthInfo and monthInfo.year or now.year
  local month = monthInfo and monthInfo.month or now.month
  local numDays = (monthInfo and monthInfo.numDays) or 31

  dbg(string.format("ScanEvents current month %04d-%02d (%d days)", year, month, numDays), "info")

  for day = 1, numDays do
    local num = C_Calendar.GetNumDayEvents(monthOffset, day) or 0
    for i = 1, num do
      local info = C_Calendar.GetDayEvent(monthOffset, day, i)
      if info then
        raw = raw + 1
        local ct = info.calendarType or "?"
        typeCounts[ct] = (typeCounts[ct] or 0) + 1
        if calendarTypeAllowed(info.calendarType) then
          local st = info.startTime or {}
          local y, m, d = st.year or year, st.month or month, st.monthDay or day
          -- Keep only events that actually fall in the current month
          if y == year and m == month then
            local hour, minute = st.hour or 0, st.minute or 0
            list[#list + 1] = {
              monthOffset = monthOffset, day = day, index = i,
              eventID = info.eventID, title = info.title or "?",
              calendarType = info.calendarType, inviteStatus = info.inviteStatus,
              startTime = st, dateStr = dateKey(y, m, d),
              timeStr = string.format("%02d:%02d", hour, minute),
              sortKey = string.format("%04d%02d%02d%02d%02d%03d", y, m, d, hour, minute, i),
              isPast = isPastDate(y, m, d), creator = info.invitedBy,
            }
          else
            skipped = skipped + 1
          end
        else
          skipped = skipped + 1
        end
      end
    end
  end

  local tp = {}
  for k, v in pairs(typeCounts) do tp[#tp + 1] = k .. "=" .. v end
  table.sort(tp)
  dbg("types: " .. (#tp > 0 and table.concat(tp, ", ") or "none"), "info")

  table.sort(list, function(a, b) return a.sortKey < b.sortKey end)
  self.events = list
  self.scanning = false
  dbg(string.format("ScanEvents raw=%d skipped=%d kept=%d (created, current month)", raw, skipped, #list), "info")
  if ns.RefreshEventsView then ns.RefreshEventsView() end
  return list
end

function Cal:CanEditCurrentEvent()
  if not C_Calendar.EventCanEdit then return false end
  local ok, can = pcall(C_Calendar.EventCanEdit)
  return ok and can and true or false
end

function Cal:ClearPendingStatuses()
  wipe(self.pendingStatuses)
end

function Cal:HasPendingStatuses()
  return next(self.pendingStatuses) ~= nil
end

function Cal:CountPendingStatuses()
  local n = 0
  for _ in pairs(self.pendingStatuses) do n = n + 1 end
  return n
end

--- Queue a local status change (applied to calendar with ApplyPendingStatuses).
function Cal:SetPendingInviteStatus(inviteIndex, status)
  inviteIndex = tonumber(inviteIndex)
  status = tonumber(status)
  if not inviteIndex or inviteIndex < 1 or status == nil then return false end
  self.pendingStatuses[inviteIndex] = status
  -- Reflect immediately in cached rows
  for _, list in ipairs({ self.allInvitees, self.invitees, self.standby }) do
    for _, row in ipairs(list or {}) do
      if row.index == inviteIndex then
        row.inviteStatus = status
        row._pending = true
      end
    end
  end
  return true
end

--- Push queued statuses to the open Blizzard calendar event.
function Cal:ApplyPendingStatuses()
  self:EnsureCalendarReady()
  if not self:HasPendingStatuses() then
    return false, "none"
  end
  if not self:CanEditCurrentEvent() then
    -- Try re-open creator event so edit mode is available
    if self.currentEvent and self.currentEvent.monthOffset ~= nil then
      local okOpen = pcall(function()
        C_Calendar.OpenEvent(self.currentEvent.monthOffset, self.currentEvent.day, self.currentEvent.index)
      end)
      dbg("ApplyPendingStatuses re-OpenEvent ok=" .. tostring(okOpen), okOpen and "info" or "warn")
    end
    if not self:CanEditCurrentEvent() then
      self.lastError = "Non puoi modificare questo evento (serve essere creatore/moderator)."
      dbg(self.lastError, "warn")
      return false, "no_edit"
    end
  end

  local setFn = C_Calendar.EventSetInviteStatus
  if not setFn then
    self.lastError = "API EventSetInviteStatus non disponibile."
    return false, "no_api"
  end

  local okN, failN = 0, 0
  for index, status in pairs(self.pendingStatuses) do
    local ok, err = pcall(setFn, index, status)
    if ok then
      okN = okN + 1
      dbg(string.format("EventSetInviteStatus idx=%d status=%d OK", index, status), "info")
    else
      failN = failN + 1
      dbg(string.format("EventSetInviteStatus idx=%d status=%d FAIL %s", index, status, tostring(err)), "warn")
    end
  end

  if C_Calendar.UpdateEvent then
    local okU, errU = pcall(C_Calendar.UpdateEvent)
    dbg(string.format("UpdateEvent ok=%s err=%s", tostring(okU), tostring(errU)), okU and "info" or "warn")
  end

  wipe(self.pendingStatuses)
  self:ReadInvitees()
  if failN > 0 and okN == 0 then
    return false, "fail"
  end
  -- Stage current roster for companion after calendar writes (autoPushPrep).
  if okN > 0 and ns.RequestPushPrep then
    ns.RequestPushPrep("calendar_apply")
  end
  return true, okN, failN
end

function Cal:OpenEvent(event)
  if not event then return end
  self:EnsureCalendarReady()
  self.currentEvent = event
  self:ClearPendingStatuses()
  dbg(string.format("OpenEvent '%s' off=%s day=%s idx=%s",
    tostring(event.title), tostring(event.monthOffset), tostring(event.day), tostring(event.index)), "info")

  local ok, ret = pcall(function()
    return C_Calendar.OpenEvent(event.monthOffset, event.day, event.index)
  end)
  dbg(string.format("OpenEvent pcall=%s ret=%s GetNumInvites=%s canEdit=%s",
    tostring(ok), tostring(ret), tostring(GetNumInvites()), tostring(self:CanEditCurrentEvent())),
    (ok and ret ~= false) and "info" or "warn")

  self:ReadInvitees()
  scheduleInviteRetries(event)

  if ns.RefreshEventsView then ns.RefreshEventsView() end
end

--- Read whatever event is currently open in Blizzard calendar UI (Modifica evento).
function Cal:ReadOpenBlizzardEvent()
  self:EnsureCalendarReady()
  local num = GetNumInvites()
  local evInfo = C_Calendar.GetEventInfo and C_Calendar.GetEventInfo()
  dbg(string.format("ReadOpenBlizzardEvent invites=%d hasInfo=%s api=GetNumInvites",
    num, tostring(evInfo ~= nil)), "info")

  if (not evInfo or not evInfo.title) and num == 0 then
    self.lastError = "Nessun evento aperto nel calendario Blizzard. Apri l'evento in gioco, poi riprova."
    dbg(self.lastError, "warn")
    if ns.Print then ns.Print(self.lastError) end
    return false
  end

  local t = evInfo and evInfo.time or {}
  self.currentEvent = {
    title = (evInfo and evInfo.title) or (self.currentEvent and self.currentEvent.title) or "Evento aperto",
    creator = evInfo and evInfo.creator,
    calendarType = evInfo and evInfo.calendarType or "PLAYER",
    dateStr = (t.year and dateKey(t.year, t.month, t.monthDay)) or (self.currentEvent and self.currentEvent.dateStr) or "",
    timeStr = t.hour and string.format("%02d:%02d", t.hour or 0, t.minute or 0) or "",
    startTime = t,
    fromOpenUI = true,
  }
  self:ReadInvitees()
  scheduleInviteRetries(self.currentEvent)
  if ns.RefreshEventsView then ns.RefreshEventsView() end
  return true
end

function Cal:ReadInvitees()
  local invitees, standby, all = {}, {}, {}
  local num = GetNumInvites()
  local evInfoPeek = C_Calendar.GetEventInfo and C_Calendar.GetEventInfo()
  local canEdit = C_Calendar.EventCanEdit and C_Calendar.EventCanEdit()
  dbg(string.format("ReadInvitees n=%s eventTitle=%s canEdit=%s api=GetNumInvites",
    tostring(num), tostring(evInfoPeek and evInfoPeek.title), tostring(canEdit)), "info")

  local skippedRows = 0
  for i = 1, num do
    local info = GetInviteRow(i)
    if info and info.name and info.name ~= "" then
      local row = {
        index = i,
        name = info.name,
        level = info.level,
        className = info.className,
        classFilename = info.classFilename,
        classID = info.classID,
        inviteStatus = info.inviteStatus,
        modStatus = info.modStatus,
        guid = info.guid,
      }
      all[#all + 1] = row
      if info.inviteStatus == STATUS.STANDBY then
        standby[#standby + 1] = row
      else
        -- Show everyone except empty; status chips filter in UI
        invitees[#invitees + 1] = row
      end
      if i <= 3 then
        local roster = ns.FindRosterPlayer and ns.FindRosterPlayer(row.name)
        dbg(string.format("  sample[%d] %s class=%s status=%s roster=%s role=%s",
          i, tostring(row.name), tostring(row.classFilename or row.className),
          tostring(row.inviteStatus),
          roster and (roster.name or "yes") or "NO",
          roster and tostring(roster.primaryRole) or "-"), "info")
      end
    else
      skippedRows = skippedRows + 1
      if skippedRows <= 5 then
        local a, b, c, d, e = C_Calendar.EventGetInvite(i)
        dbg(string.format("  skip[%d] type(a)=%s a=%s b=%s c=%s d=%s e=%s",
          i, type(a), tostring(a):sub(1, 60), tostring(b), tostring(c), tostring(d), tostring(e)), "warn")
      end
    end
  end
  if skippedRows > 0 then
    dbg("ReadInvitees skipped unparsable rows=" .. skippedRows, "warn")
  end

  table.sort(invitees, function(a, b) return (a.name or "") < (b.name or "") end)
  table.sort(standby, function(a, b) return (a.name or "") < (b.name or "") end)
  table.sort(all, function(a, b) return (a.name or "") < (b.name or "") end)

  self.invitees = invitees
  self.standby = standby
  self.allInvitees = all

  local evInfo = C_Calendar.GetEventInfo and C_Calendar.GetEventInfo()
  if evInfo and self.currentEvent then
    self.currentEvent.title = evInfo.title or self.currentEvent.title
    self.currentEvent.creator = evInfo.creator or self.currentEvent.creator
    if evInfo.time then
      local t = evInfo.time
      if t.year and t.month and t.monthDay then
        self.currentEvent.dateStr = dateKey(t.year, t.month, t.monthDay)
        self.currentEvent.timeStr = string.format("%02d:%02d", t.hour or 0, t.minute or 0)
      end
    end
  end

  if #all > 0 then self.lastError = "" end
  dbg(string.format("ReadInvitees done shown=%d standby=%d all=%d", #invitees, #standby, #all), "info")
  if ns.RefreshEventsView then ns.RefreshEventsView() end
  if ns.RefreshCalendarDebugView then ns.RefreshCalendarDebugView() end
  return invitees, standby, all
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
frame:RegisterEvent("CALENDAR_OPEN_EVENT")
frame:RegisterEvent("CALENDAR_UPDATE_INVITE_LIST")
frame:RegisterEvent("CALENDAR_UPDATE_EVENT")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "Blizzard_Calendar" then
    Cal.calendarReady = false
  elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
    dbg("CALENDAR_UPDATE_EVENT_LIST", "info")
    Cal:ScanEvents()
  elseif event == "CALENDAR_OPEN_EVENT" then
    dbg(string.format("CALENDAR_OPEN_EVENT type=%s GetNumInvites=%s",
      tostring(arg1), tostring(GetNumInvites())), "info")
    Cal:ReadInvitees()
  elseif event == "CALENDAR_UPDATE_INVITE_LIST" then
    dbg(string.format("CALENDAR_UPDATE_INVITE_LIST complete=%s GetNumInvites=%s",
      tostring(arg1), tostring(GetNumInvites())), "info")
    Cal:ReadInvitees()
  elseif event == "CALENDAR_UPDATE_EVENT" then
    dbg(string.format("CALENDAR_UPDATE_EVENT GetNumInvites=%s", tostring(GetNumInvites())), "info")
    if GetNumInvites() > 0 or (Cal.currentEvent and Cal.currentEvent.fromOpenUI) then
      Cal:ReadInvitees()
    end
  end
end)
