local ADDON, ns = ...
local L = ns.L
local C = ns.Colors
local W = ns.W

local function clearChildren(frame)
  local kids = { frame:GetChildren() }
  for i = 1, #kids do
    kids[i]:Hide()
    kids[i]:SetParent(nil)
  end
end

local function normalizeRole(role)
  role = string.lower(strtrim(tostring(role or "")))
  if role == "tank" or role == "healer" or role == "dps" then return role end
  return "dps"
end

function ns.BuildRosterView(parent)
  local title = W.fs(parent, "GameFontNormalHuge", L["ROSTER"])
  title:SetPoint("TOPLEFT", 16, -12)
  W.color(title, C.accent2)
  parent.title = title

  local countFS = W.fs(parent, "GameFontNormalSmall", "", C.subtext)
  countFS:SetPoint("LEFT", title, "RIGHT", 12, 0)
  parent.countFS = countFS

  local filterBar = CreateFrame("Frame", nil, parent)
  filterBar:SetPoint("TOPLEFT", 16, -42)
  filterBar:SetPoint("TOPRIGHT", -16, -42)
  filterBar:SetHeight(28)

  local roleDD = W.dropdown(filterBar, 120, 26)
  roleDD:SetPoint("LEFT", 0, 0)
  roleDD:SetOptions({
    { value = "all", text = L["FILTER_ROLE"] .. ": " .. L["ALL"] },
    { value = "tank", text = "Tank" },
    { value = "healer", text = "Healer" },
    { value = "dps", text = "DPS" },
  })
  roleDD:SetValue("all")
  parent.roleDD = roleDD

  local includeOff = W.checkbox(filterBar, L["INCLUDE_OFFSPEC"] or "Incl. off-spec")
  includeOff:SetPoint("LEFT", roleDD, "RIGHT", 10, 0)
  includeOff:SetChecked(false)
  parent.includeOff = includeOff

  local classDD = W.dropdown(filterBar, 130, 26)
  classDD:SetPoint("LEFT", includeOff.labelFS or includeOff, "RIGHT", 12, 0)
  -- checkbox label may extend; place classDD further right
  classDD:ClearAllPoints()
  classDD:SetPoint("LEFT", roleDD, "RIGHT", 150, 0)
  classDD:SetOptions({ { value = "all", text = L["FILTER_CLASS"] .. ": " .. L["ALL"] } })
  classDD:SetValue("all")
  parent.classDD = classDD

  local statusDD = W.dropdown(filterBar, 130, 26)
  statusDD:SetPoint("LEFT", classDD, "RIGHT", 8, 0)
  statusDD:SetOptions({
    { value = "all", text = L["FILTER_STATUS"] .. ": " .. L["ALL"] },
    { value = "confirmed", text = L["STATUS_CONFIRMED"] },
    { value = "backup", text = L["STATUS_BACKUP"] },
    { value = "to_evaluate", text = L["STATUS_TO_EVALUATE"] },
    { value = "trial", text = L["STATUS_TRIAL"] },
    { value = "unavailable", text = L["STATUS_UNAVAILABLE"] },
    { value = "justified_absence", text = L["STATUS_JUSTIFIED_ABSENCE"] },
    { value = "suspended", text = L["STATUS_SUSPENDED"] },
    { value = "non_raider", text = L["STATUS_NON_RAIDER"] },
  })
  statusDD:SetValue("all")
  parent.statusDD = statusDD

  local availDD = W.dropdown(filterBar, 120, 26)
  availDD:SetPoint("LEFT", statusDD, "RIGHT", 8, 0)
  availDD:SetOptions({
    { value = "all", text = L["FILTER_AVAIL"] .. ": " .. L["ALL"] },
    { value = "day_one", text = L["DAY_ONE"] },
    { value = "deferred", text = L["DEFERRED"] },
    { value = "uncertain", text = L["UNCERTAIN"] },
  })
  availDD:SetValue("all")
  parent.availDD = availDD

  local searchPanel = W.panel(filterBar, C.panelAlt)
  searchPanel:SetSize(140, 26)
  searchPanel:SetPoint("RIGHT", 0, 0)
  local search = W.editBox(searchPanel, false)
  search:SetAllPoints()
  search:SetTextInsets(8, 8, 0, 0)
  parent.search = search

  local function bump()
    ns.RefreshRosterView()
  end
  roleDD.onSelect = function(v)
    -- Manual dropdown choice drives the role filter; leave tab mode if user overrides.
    if ns.rosterViewMode == "tank" or ns.rosterViewMode == "healer" or ns.rosterViewMode == "dps" then
      if v ~= ns.rosterViewMode then
        ns.rosterViewMode = "all"
      end
    end
    bump()
  end
  includeOff.onToggle = bump
  classDD.onSelect = bump
  statusDD.onSelect = bump
  availDD.onSelect = bump
  search:SetScript("OnTextChanged", bump)

  local clearBtn = W.button(filterBar, L["CLEAR_FILTERS"] or "Reset", 64, 26, false, function()
    ns.rosterViewMode = "all"
    ns.rosterFilterFlag = nil
    ns.rosterCriticalOnly = nil
    ns.rosterAbsencesOnly = nil
    ns.rosterRolePreset = nil
    roleDD:SetValue("all")
    classDD:SetValue("all")
    statusDD:SetValue("all")
    availDD:SetValue("all")
    includeOff:SetChecked(false)
    search:SetText("")
    bump()
  end)
  clearBtn:SetPoint("RIGHT", searchPanel, "LEFT", -8, 0)

  local header = W.panel(parent, C.panelAlt)
  header:SetPoint("TOPLEFT", 16, -78)
  header:SetPoint("TOPRIGHT", -28, -78)
  header:SetHeight(22)
  local cols = {
    { L["COL_NAME"], 10 },
    { L["COL_ROLE"], 170 },
    { L["COL_CLASS"], 280 },
    { L["COL_STATUS"], 400 },
    { L["COL_LAUNCH"], 520 },
    { L["COL_ATT"], 620 },
    { L["COL_NOTES"], 680 },
  }
  for _, col in ipairs(cols) do
    local fs = W.fs(header, "GameFontNormalSmall", col[1], C.subtext)
    fs:SetPoint("LEFT", col[2], 0)
  end

  local scroll, child = W.scroll(parent)
  scroll:SetPoint("TOPLEFT", 16, -104)
  scroll:SetPoint("BOTTOMRIGHT", -28, 12)
  parent.scroll = scroll
  parent.child = child

  local function addSectionHeader(text, color, y, width)
    local bar = CreateFrame("Frame", nil, child, "BackdropTemplate")
    W.setBG(bar, C.panelAlt)
    bar:SetSize(width, 24)
    bar:SetPoint("TOPLEFT", 0, y)
    local fs = W.fs(bar, "GameFontNormal", text, color)
    fs:SetPoint("LEFT", 10, 0)
    return y - 28
  end

  local function addPlayerRow(p, i, y, width)
    local row = CreateFrame("Button", nil, child, "BackdropTemplate")
    W.setBG(row, (i % 2 == 0) and C.row or C.panelAlt)
    row:SetSize(width, 40)
    row:SetPoint("TOPLEFT", 0, y)

    local primary = normalizeRole(p.primaryRole)
    local nameFS = W.fs(row, "GameFontNormal", ns.ClassColorText(p.class, p.name))
    nameFS:SetPoint("LEFT", 10, 0)
    nameFS:SetWidth(155)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)

    local roleCol = C[primary] or C.subtext
    local offs = {}
    for _, r in ipairs(p.offRoles or {}) do
      r = normalizeRole(r)
      if r ~= primary then offs[#offs + 1] = r end
    end
    local roleText = string.upper(primary)
    if #offs > 0 then
      roleText = roleText .. " |cff888888[" .. table.concat(offs, ",") .. "]|r"
    end
    local roleFS = W.fs(row, "GameFontHighlightSmall", roleText, roleCol)
    roleFS:SetPoint("LEFT", 170, 0)
    roleFS:SetWidth(100)

    W.fs(row, "GameFontHighlightSmall", p.class or "—", C.text):SetPoint("LEFT", 280, 0)
    W.fs(row, "GameFontHighlightSmall", ns.StatusLabel(p.status), C.text):SetPoint("LEFT", 400, 0)

    local launchCol = (p.launch == "deferred" and C.warn) or (p.launch == "day_one" and C.ok) or C.subtext
    local launchFS = W.fs(row, "GameFontHighlightSmall", ns.LaunchLabel(p.launch), launchCol)
    launchFS:SetPoint("LEFT", 520, 0)

    W.fs(row, "GameFontHighlightSmall", p.attendance ~= nil and tostring(p.attendance) or "—", C.text):SetPoint("LEFT", 620, 0)

    local tagBits = {}
    for _, t in ipairs(p.tags or {}) do tagBits[#tagBits + 1] = ns.FlagLabel(t) end
    local notePreview = table.concat(tagBits, ", ")
    if p.notes and p.notes ~= "" then
      if notePreview ~= "" then notePreview = notePreview .. " · " end
      notePreview = notePreview .. ns.Truncate(p.notes:gsub("\n", " "), 42)
    end
    local noteCol = (#tagBits > 0 or (p.notes and p.notes ~= "")) and C.warn or C.subtext
    local noteFS = W.fs(row, "GameFontDisableSmall", notePreview ~= "" and notePreview or "—", noteCol)
    noteFS:SetPoint("LEFT", 680, 0)
    noteFS:SetPoint("RIGHT", -8, 0)
    noteFS:SetJustifyH("LEFT")
    noteFS:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
      self:SetBackdropColor(C.rowHover[1], C.rowHover[2], C.rowHover[3], 1)
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:ClearLines()
      GameTooltip:AddLine(p.name, 1, 1, 1)
      GameTooltip:AddLine((p.class or "?") .. ((p.spec and p.spec ~= "") and (" · " .. p.spec) or ""), 0.75, 0.75, 0.8)
      GameTooltip:AddDoubleLine(L["COL_ROLE"] .. " (main)", string.upper(primary), 0.6, 0.6, 0.6, roleCol[1], roleCol[2], roleCol[3])
      if #offs > 0 then
        GameTooltip:AddDoubleLine(L["OFFSPEC"], table.concat(offs, ", "), 0.6, 0.6, 0.6, 1, 0.82, 0.4)
      end
      GameTooltip:AddDoubleLine(L["COL_STATUS"], ns.StatusLabel(p.status), 0.6, 0.6, 0.6, 1, 1, 1)
      GameTooltip:AddDoubleLine(L["COL_LAUNCH"], ns.LaunchLabel(p.launch), 0.6, 0.6, 0.6, 1, 1, 1)
      if p.tags and #p.tags > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(table.concat(p.tags, ", "), 1, 0.75, 0.3)
      end
      if p.notes and p.notes ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(p.notes, 1, 0.9, 0.5, true)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
      local col = (i % 2 == 0) and C.row or C.panelAlt
      self:SetBackdropColor(col[1], col[2], col[3], col[4] or 1)
      GameTooltip:Hide()
    end)

    return y - 42
  end

  function ns.OpenRosterFiltered(opts)
    opts = opts or {}
    if opts.role then
      ns.rosterViewMode = opts.role
      ns.rosterRolePreset = opts.role
    elseif opts.criticalOnly then
      ns.rosterViewMode = "notes"
    elseif opts.absencesOnly then
      ns.rosterViewMode = "absences"
    else
      ns.rosterViewMode = "all"
    end
    ns.rosterCriticalOnly = opts.criticalOnly
    ns.rosterAbsencesOnly = opts.absencesOnly
    if ns.UI then ns.UI:ShowModule(opts.module or "roster") end
  end

  function ns.RefreshRosterView()
    local classOpts = { { value = "all", text = L["FILTER_CLASS"] .. ": " .. L["ALL"] } }
    for _, c in ipairs(ns.GetUniqueClasses()) do
      classOpts[#classOpts + 1] = { value = c, text = c }
    end
    local prevClass = classDD:GetValue() or "all"
    classDD:SetOptions(classOpts)
    classDD:SetValue(prevClass)

    local mode = ns.rosterViewMode or "all"
    -- Tab Tank/Healer/DPS => always primary-only for that role
    local role = "all"
    local primaryOnly = true
    if mode == "tank" or mode == "healer" or mode == "dps" then
      role = mode
      primaryOnly = true
      roleDD:SetValue(mode)
      includeOff:SetChecked(false)
    elseif mode == "notes" or mode == "absences" then
      role = roleDD:GetValue() or "all"
      primaryOnly = not includeOff:GetChecked()
    else
      role = roleDD:GetValue() or "all"
      -- Dropdown role filter: primary by default; off-spec only if checkbox on
      primaryOnly = not includeOff:GetChecked()
    end

    local launch = availDD:GetValue() or "all"
    local flag = nil
    if launch == "uncertain" then
      flag = "uncertain"
      launch = "all"
    end

    local opts = {
      role = role,
      primaryRoleOnly = primaryOnly,
      class = classDD:GetValue(),
      status = statusDD:GetValue(),
      launch = launch,
      flag = flag,
      criticalOnly = (mode == "notes") or ns.rosterCriticalOnly,
      absencesOnly = (mode == "absences") or ns.rosterAbsencesOnly,
      search = search:GetText(),
    }

    if mode == "absences" then
      title:SetText(L["ABSENCES"])
    elseif mode == "notes" then
      title:SetText(L["NOTES"])
    elseif mode == "tank" then
      title:SetText(L["TANKS"] .. " (" .. (L["PRIMARY_ONLY"] or "main") .. ")")
    elseif mode == "healer" then
      title:SetText(L["HEALERS"] .. " (" .. (L["PRIMARY_ONLY"] or "main") .. ")")
    elseif mode == "dps" then
      title:SetText(L["DPS"] .. " (" .. (L["PRIMARY_ONLY"] or "main") .. ")")
    else
      title:SetText(L["ROSTER"])
    end

    clearChildren(child)
    local players = ns.FilterPlayers(opts)
    local counts = ns.CountByRole()
    countFS:SetText(string.format("(%d)  T:%d H:%d D:%d", #players, counts.tank, counts.healer, counts.dps))

    local y = -2
    local width = math.max(700, (scroll:GetWidth() or 700) - 4)
    child:SetWidth(width)

    if #players == 0 then
      local empty = W.fs(child, "GameFontHighlight",
        (L["NO_MATCH"] or "Nessun giocatore con questo filtro.") .. "\n" .. (L["NO_DATA"] or ""),
        C.subtext)
      empty:SetPoint("TOPLEFT", 8, -8)
      empty:SetJustifyH("LEFT")
      child:SetHeight(60)
      if scroll.Refresh then scroll:Refresh() end
      return
    end

    -- Full roster: group by primary role like the website role boards
    local grouped = mode == "all" and role == "all" and not opts.criticalOnly and not opts.absencesOnly
    if grouped then
      local buckets = { tank = {}, healer = {}, dps = {} }
      for _, p in ipairs(players) do
        local r = normalizeRole(p.primaryRole)
        buckets[r] = buckets[r] or {}
        buckets[r][#buckets[r] + 1] = p
      end
      local order = {
        { "tank", L["TANKS"], C.tank },
        { "healer", L["HEALERS"], C.healer },
        { "dps", L["DPS"], C.dps },
      }
      local idx = 0
      for _, sec in ipairs(order) do
        local list = buckets[sec[1]] or {}
        y = addSectionHeader(string.format("%s  (%d)", sec[2], #list), sec[3], y, width)
        if #list == 0 then
          local none = W.fs(child, "GameFontDisableSmall", "—", C.subtext)
          none:SetPoint("TOPLEFT", 16, y)
          y = y - 18
        else
          for _, p in ipairs(list) do
            idx = idx + 1
            y = addPlayerRow(p, idx, y, width)
          end
        end
        y = y - 6
      end
    else
      for i, p in ipairs(players) do
        y = addPlayerRow(p, i, y, width)
      end
    end

    child:SetHeight(math.max(40, -y + 8))
    if scroll.Refresh then scroll:Refresh() end
  end
end
