local ADDON, ns = ...
local L = ns.L
local C = ns.Colors
local W = ns.W

ns.UI = ns.UI or {}
local UI = ns.UI

local MODULES = {
  { key = "dashboard", labelKey = "DASHBOARD", width = 96 },
  { key = "roster", labelKey = "ROSTER", width = 72 },
  { key = "guild", labelKey = "GUILD_TAB", width = 72 },
  { key = "events", labelKey = "EVENTS", width = 72 },
  { key = "caldebug", labelKey = "CAL_DEBUG", width = 110 },
  { key = "settings", labelKey = "SETTINGS", width = 96 },
}

function UI:EnsureCreated()
  if self.frame then return self.frame end

  local f = CreateFrame("Frame", "GuildPerformerFrame", UIParent, "BackdropTemplate")
  f:SetSize(960, 640)
  local pos = ns.db.settings.pos
  if pos then
    f:SetPoint(pos.point, UIParent, pos.rel, pos.x, pos.y)
  else
    f:SetPoint("CENTER")
  end
  W.setBG(f, C.bg)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetResizable(true)
  f:SetResizeBounds(720, 480, 1400, 900)
  f:SetClampedToScreen(true)
  f:Hide()
  tinsert(UISpecialFrames, "GuildPerformerFrame")
  f:SetScale(ns.db.settings.scale or 1)

  -- Title bar
  local bar = W.panel(f, C.panelAlt)
  bar:SetPoint("TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", 0, 0)
  bar:SetHeight(46)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function()
    if not ns.db.settings.lockWindow then f:StartMoving() end
  end)
  bar:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, rel, x, y = f:GetPoint(1)
    ns.db.settings.pos = { point = point, rel = rel, x = x, y = y }
  end)

  local logo = W.fs(bar, "GameFontNormalHuge", "GUILD")
  logo:SetPoint("LEFT", 16, 0)
  W.color(logo, C.accent2)
  local sub = W.fs(bar, "GameFontNormalHuge", "PERFORMER")
  sub:SetPoint("LEFT", logo, "RIGHT", 6, 0)
  W.color(sub, C.accent)
  f.seasonFS = W.fs(bar, "GameFontNormalSmall", "", C.subtext)
  f.seasonFS:SetPoint("LEFT", sub, "RIGHT", 14, 0)

  local close = W.closeButton(bar, function() f:Hide() end)
  close:SetPoint("RIGHT", -10, 0)

  -- Module menu (single horizontal scrollable row)
  local menu = W.panel(f, C.panelAlt)
  menu:SetPoint("TOPLEFT", 0, -46)
  menu:SetPoint("TOPRIGHT", 0, -46)
  menu:SetHeight(36)

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", 8, -88)
  content:SetPoint("BOTTOMRIGHT", -8, 8)
  f.content = content
  ns.content = content
  ns.panels = {}
  f.pages = {}

  local function addPage(withBg)
    local p = CreateFrame("Frame", nil, content, "BackdropTemplate")
    p:SetAllPoints(content)
    if withBg then W.setBG(p, C.panel) end
    p:Hide()
    return p
  end

  f.pages.dashboard = addPage(true)
  f.pages.roster = addPage(true)
  f.pages.guild = addPage(true)
  f.pages.events = addPage(true)
  f.pages.caldebug = addPage(true)
  f.pages.settings = addPage(true)

  ns.panels.dashboard = f.pages.dashboard
  ns.panels.roster = f.pages.roster
  ns.panels.guild = f.pages.guild
  ns.panels.events = f.pages.events
  ns.panels.caldebug = f.pages.caldebug
  ns.panels.settings = f.pages.settings

  if ns.BuildDashboard then ns.BuildDashboard(f.pages.dashboard) end
  if ns.BuildRosterView then ns.BuildRosterView(f.pages.roster) end
  if ns.BuildGuildView then ns.BuildGuildView(f.pages.guild) end
  if ns.BuildEventsView then ns.BuildEventsView(f.pages.events) end
  if ns.BuildCalendarDebugView then ns.BuildCalendarDebugView(f.pages.caldebug) end
  if ns.BuildSettingsView then ns.BuildSettingsView(f.pages.settings) end
  -- keep filter widgets reachable from dashboard deep-links
  ns.panels.roster = f.pages.roster

  local menuScroll = CreateFrame("ScrollFrame", nil, menu)
  menuScroll:SetPoint("TOPLEFT", 4, 0)
  menuScroll:SetPoint("BOTTOMRIGHT", -4, 0)
  menuScroll:EnableMouseWheel(true)
  local menuChild = CreateFrame("Frame", nil, menuScroll)
  menuChild:SetHeight(36)
  menuScroll:SetScrollChild(menuChild)
  f.menuScroll = menuScroll
  f.menuChild = menuChild

  f.moduleButtons = {}
  local mx = 4
  for _, m in ipairs(MODULES) do
    local moduleKey = m.key
    local b = W.button(menuChild, L[m.labelKey] or moduleKey, m.width, 24, false, (function(k)
      return function() UI:ShowModule(k) end
    end)(moduleKey))
    b:SetPoint("LEFT", mx, 0)
    f.moduleButtons[moduleKey] = b
    mx = mx + m.width + 6
  end
  menuChild:SetWidth(math.max(mx + 4, 100))

  local function clampMenuScroll()
    local maxScroll = math.max(0, menuChild:GetWidth() - menuScroll:GetWidth())
    local cur = menuScroll:GetHorizontalScroll() or 0
    if cur > maxScroll then menuScroll:SetHorizontalScroll(maxScroll) end
    if cur < 0 then menuScroll:SetHorizontalScroll(0) end
  end
  menuScroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = math.max(0, menuChild:GetWidth() - self:GetWidth())
    local next = math.min(maxScroll, math.max(0, (self:GetHorizontalScroll() or 0) - delta * 48))
    self:SetHorizontalScroll(next)
  end)
  menuScroll:HookScript("OnSizeChanged", clampMenuScroll)
  menu:EnableMouseWheel(true)
  menu:SetScript("OnMouseWheel", function(_, delta)
    menuScroll:GetScript("OnMouseWheel")(menuScroll, delta)
  end)

  local resize = CreateFrame("Button", nil, f)
  resize:SetSize(16, 16)
  resize:SetPoint("BOTTOMRIGHT", -4, 4)
  resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  resize:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  resize:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

  self.frame = f
  ns.mainFrame = f
  return f
end

function UI:ShowModule(key)
  self:EnsureCreated()
  local f = self.frame

  local pageKey = key
  if key == "tank" or key == "healer" or key == "dps" then
    -- Primary-role boards (NOT off-spec). This was the source of "I only see DPS".
    ns.rosterViewMode = key
    ns.rosterRolePreset = key
    ns.rosterCriticalOnly = nil
    ns.rosterAbsencesOnly = nil
    pageKey = "roster"
  elseif key == "roster" then
    -- Keep filters set by OpenRosterFiltered / dashboard cards.
    if not ns.pendingLaunchFilter and not ns.rosterRolePreset and not ns.rosterCriticalOnly and not ns.rosterAbsencesOnly then
      ns.rosterViewMode = "all"
      ns.rosterRolePreset = nil
      ns.rosterCriticalOnly = nil
      ns.rosterAbsencesOnly = nil
    end
    pageKey = "roster"
  end

  for id, page in pairs(f.pages) do
    page:SetShown(id == pageKey)
  end
  for id, btn in pairs(f.moduleButtons) do
    btn:SetActive(id == key)
  end
  ns.activeTab = pageKey
  self.activeModule = key

  local m = ns.db.meta or {}
  f.seasonFS:SetText(string.format("%s  |  %s-%s  |  %s",
    m.season ~= "" and m.season or "—",
    m.realm ~= "" and m.realm or "?",
    m.region ~= "" and m.region or "?",
    m.guild ~= "" and m.guild or "—"))

  if pageKey == "roster" and ns.pendingLaunchFilter and f.pages.roster and f.pages.roster.availDD then
    f.pages.roster.availDD:SetValue(ns.pendingLaunchFilter)
    ns.pendingLaunchFilter = nil
  end

  if pageKey == "dashboard" and ns.RefreshDashboard then ns.RefreshDashboard() end
  if pageKey == "roster" and ns.RefreshRosterView then ns.RefreshRosterView() end
  if pageKey == "guild" and ns.RefreshGuildView then ns.RefreshGuildView() end
  if pageKey == "events" then
    if #(ns.Calendar.events or {}) == 0 then
      ns.Calendar:RequestScan()
    elseif ns.RefreshEventsView then
      ns.RefreshEventsView()
    end
  end
  if pageKey == "caldebug" and ns.RefreshCalendarDebugView then
    ns.RefreshCalendarDebugView()
  end
  if pageKey == "settings" and ns.RefreshSettingsView then ns.RefreshSettingsView() end
  ns.keepRosterFilters = nil
end

function UI:Toggle()
  self:EnsureCreated()
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self.frame:Show()
    local mod = ns.db.settings.defaultModule or "dashboard"
    if mod == "builder" or mod == "import" or mod == "summary"
        or mod == "notes" or mod == "absences"
        or not self.frame.moduleButtons[mod] then
      mod = "dashboard"
    end
    self:ShowModule(mod)
  end
end

function UI:ApplyThemeLive()
  if ns.W and ns.W.Reskin then ns.W.Reskin() end
  if self.frame then
    self.frame:SetScale(ns.db.settings.scale or 1)
  end
  if self.activeModule then
    self:ShowModule(self.activeModule)
  end
end

function ns.RefreshActiveTab()
  if UI.activeModule then UI:ShowModule(UI.activeModule) end
end
