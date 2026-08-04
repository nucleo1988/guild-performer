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
  return ns.BoardRole and ns.BoardRole(role) or "dps"
end

--- Display / edit lane: tank | healer | melee | ranged (legacy dps → class split)
local function getMainLane(p)
  local key = p and p.name and ns.NormalizeName(p.name)
  local ov = key and ns.db and ns.db.mainRoleOverrides and ns.db.mainRoleOverrides[key]
  if ov == "tank" or ov == "healer" or ov == "melee" or ov == "ranged" then return ov end
  local r = string.lower(strtrim(tostring(p and p.primaryRole or "")))
  if r == "tank" or r == "healer" or r == "melee" or r == "ranged" then return r end
  if r == "dps" then
    local tok = ns.NormalizeClass(p and p.class)
    if tok and ns.MeleeClasses and ns.MeleeClasses[tok] then return "melee" end
    return "ranged"
  end
  return "ranged"
end

local function formatOffDisplay(p, mainLane)
  local bits, seen = {}, {}
  local mainBoard = normalizeRole(mainLane)
  for _, r in ipairs((p and p.offRoles) or {}) do
    r = string.lower(strtrim(tostring(r)))
    local label, key
    if r == "tank" and mainLane ~= "tank" then
      label, key = "Tank", "tank"
    elseif r == "healer" and mainLane ~= "healer" then
      label, key = "Healer", "healer"
    elseif r == "melee" and mainLane ~= "melee" then
      label, key = "Melee", "melee"
    elseif r == "ranged" and mainLane ~= "ranged" then
      label, key = "Ranged", "ranged"
    elseif r == "dps" and mainBoard ~= "dps" then
      local tok = ns.NormalizeClass(p.class)
      label = (tok and ns.MeleeClasses and ns.MeleeClasses[tok]) and "Melee" or "Ranged"
      key = label
    end
    if label and not seen[key] then
      seen[key] = true
      bits[#bits + 1] = label
    end
  end
  return #bits > 0 and table.concat(bits, ", ") or "—"
end

local MAIN_ROLE_OPTS
local PRIORITY_OPTS

local function getPriority(p)
  local key = p and p.name and ns.NormalizeName(p.name)
  local ov = key and ns.db and ns.db.priorityOverrides and ns.db.priorityOverrides[key]
  local n = tonumber(ov) or tonumber(p and p.priority)
  if n and n >= 1 and n <= 5 then return n end
  return 3
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
  searchPanel:SetSize(120, 26)
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

  MAIN_ROLE_OPTS = {
    { value = "tank", text = "Tank", swatch = C.tank },
    { value = "healer", text = "Healer", swatch = C.healer },
    { value = "melee", text = "Melee", swatch = C.dps },
    { value = "ranged", text = "Ranged", swatch = C.dps },
  }
  PRIORITY_OPTS = {
    { value = 1, text = "1" },
    { value = 2, text = "2" },
    { value = 3, text = "3" },
    { value = 4, text = "4" },
    { value = 5, text = "5" },
  }
  local OFF_ROLE_OPTS = ns.OffRoleOptions and ns.OffRoleOptions() or { { value = "", text = "—" } }
  local STATUS_OPTS = {
    { value = "to_evaluate", text = L["STATUS_TO_EVALUATE"] },
    { value = "confirmed", text = L["STATUS_CONFIRMED"] },
    { value = "backup", text = L["STATUS_BACKUP"] },
    { value = "trial", text = L["STATUS_TRIAL"] },
    { value = "unavailable", text = L["STATUS_UNAVAILABLE"] },
    { value = "justified_absence", text = L["STATUS_JUSTIFIED_ABSENCE"] },
    { value = "suspended", text = L["STATUS_SUSPENDED"] },
    { value = "non_raider", text = L["STATUS_NON_RAIDER"] },
  }
  local LAUNCH_OPTS = {
    { value = "", text = "—" },
    { value = "day_one", text = L["DAY_ONE"] or "Day One" },
    { value = "deferred", text = L["DEFERRED"] or "Lancio differito" },
  }
  local ATT_OPTS = {
    { value = "", text = "—" },
    { value = 0, text = "0" },
    { value = 1, text = "1" },
    { value = 2, text = "2" },
    { value = 3, text = "3" },
  }

  -- Manual add / edit dialog
  local addDlg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  W.setBG(addDlg, C.panel)
  addDlg:SetSize(420, 520)
  addDlg:SetPoint("CENTER")
  addDlg:SetFrameStrata("DIALOG")
  addDlg:EnableMouse(true)
  addDlg:Hide()
  addDlg.mode = "add"
  addDlg.editName = nil
  parent.addDlg = addDlg

  local addTitle = W.fs(addDlg, "GameFontNormal", L["ADD_PLAYER"] or "Aggiungi PG", C.accent2)
  addTitle:SetPoint("TOPLEFT", 14, -12)

  local function addRow(label, y)
    local lab = W.fs(addDlg, "GameFontNormalSmall", label, C.subtext)
    lab:SetPoint("TOPLEFT", 14, y)
    lab:SetWidth(76)
    lab:SetJustifyH("LEFT")
    return lab
  end

  addRow(L["COL_NAME"] or "Nome", -40)
  local namePanel = W.panel(addDlg, C.panelAlt)
  namePanel:SetSize(290, 24)
  namePanel:SetPoint("TOPLEFT", 100, -36)
  local nameBox = W.editBox(namePanel, false)
  nameBox:SetAllPoints()
  nameBox:SetTextInsets(6, 6, 0, 0)

  addRow(L["COL_CLASS"] or "Classe", -74)
  local addClassDD = W.dropdown(addDlg, 290, 24)
  addClassDD:SetPoint("TOPLEFT", 100, -70)
  addClassDD:SetOptions(ns.ClassLabelOptions and ns.ClassLabelOptions() or {})
  addClassDD:SetValue("Warlock")

  addRow(L["COL_MAIN"] or "Main", -108)
  local addRoleDD = W.dropdown(addDlg, 140, 24)
  addRoleDD:SetPoint("TOPLEFT", 100, -104)
  addRoleDD:SetOptions(MAIN_ROLE_OPTS)

  local prioLab = W.fs(addDlg, "GameFontNormalSmall", L["COL_PRIORITY"] or "Prio", C.subtext)
  prioLab:SetPoint("LEFT", addRoleDD, "RIGHT", 12, 0)
  local addPrioDD = W.dropdown(addDlg, 60, 24)
  addPrioDD:SetPoint("LEFT", prioLab, "RIGHT", 6, 0)
  addPrioDD:SetOptions(PRIORITY_OPTS)

  addRow(L["COL_OFF"] or "Off", -142)
  local addOffDD = W.dropdown(addDlg, 290, 24)
  addOffDD:SetPoint("TOPLEFT", 100, -138)
  addOffDD:SetOptions(OFF_ROLE_OPTS)
  addOffDD:SetValue("")

  addRow(L["COL_STATUS"] or "Stato", -176)
  local addStatusDD = W.dropdown(addDlg, 290, 24)
  addStatusDD:SetPoint("TOPLEFT", 100, -172)
  addStatusDD:SetOptions(STATUS_OPTS)
  addStatusDD:SetValue("to_evaluate")

  addRow(L["COL_LAUNCH"] or "Lancio", -210)
  local addLaunchDD = W.dropdown(addDlg, 290, 24)
  addLaunchDD:SetPoint("TOPLEFT", 100, -206)
  addLaunchDD:SetOptions(LAUNCH_OPTS)
  addLaunchDD:SetValue("")

  addRow(L["COL_ATT"] or "Pres.", -244)
  local addAttDD = W.dropdown(addDlg, 100, 24)
  addAttDD:SetPoint("TOPLEFT", 100, -240)
  addAttDD:SetOptions(ATT_OPTS)
  addAttDD:SetValue("")

  addRow(L["PLAYER_NOTES"] or "Note", -278)
  local notesWrap = W.scrollEdit(addDlg, 290, 120)
  notesWrap:SetPoint("TOPLEFT", 100, -274)

  local addErr = W.fs(addDlg, "GameFontNormalSmall", "", C.warn)
  addErr:SetPoint("BOTTOMLEFT", 14, 42)
  addErr:SetWidth(280)
  addErr:SetJustifyH("LEFT")

  local function collectForm()
    local attVal = addAttDD:GetValue()
    local att = (attVal == "" or attVal == nil) and nil or tonumber(attVal)
    return {
      name = nameBox:GetText(),
      class = addClassDD:GetValue(),
      primaryRole = addRoleDD:GetValue(),
      offRoles = addOffDD:GetValue() or "",
      priority = addPrioDD:GetValue(),
      status = addStatusDD:GetValue(),
      launch = addLaunchDD:GetValue() or "",
      attendance = att,
      notes = notesWrap:GetText() or "",
      intends = addStatusDD:GetValue() ~= "non_raider",
    }
  end

  local function formError(err)
    if err == "empty_name" then return L["ADD_NEED_NAME"] or "Inserisci un nome." end
    if err == "exists" then return L["ADD_EXISTS"] or "Questo PG è già nel roster." end
    if err == "not_found" then return L["REMOVE_FAIL"] or "PG non trovato." end
    return tostring(err or "?")
  end

  local addConfirm = W.button(addDlg, L["ADD"] or "Aggiungi", 100, 26, true, function()
    local data = collectForm()
    local p, err
    if addDlg.mode == "edit" then
      p, err = ns.UpdatePlayer(addDlg.editName, data)
    else
      p, err = ns.AddManualPlayer(data)
    end
    if not p then
      addErr:SetText(formError(err))
      return
    end
    addDlg:Hide()
    nameBox:SetText("")
    notesWrap:SetText("")
    addErr:SetText("")
    if ns.Print then
      if addDlg.mode == "edit" then
        ns.Print(string.format(L["EDIT_OK"] or "Aggiornato %s.", p.name))
      else
        ns.Print(string.format(L["ADD_OK"] or "Aggiunto %s (manuale).", p.name))
      end
    end
    bump()
  end)
  addConfirm:SetPoint("BOTTOMRIGHT", -14, 12)

  local addCancel = W.button(addDlg, L["CANCEL"] or "Annulla", 90, 26, false, function()
    addDlg:Hide()
  end)
  addCancel:SetPoint("RIGHT", addConfirm, "LEFT", -8, 0)

  local function openPlayerDialog(mode, player)
    if not ns.CanEditRoster or not ns.CanEditRoster() then
      if ns.Print then ns.Print(L["ROSTER_READONLY"] or "Solo GM/officer possono modificare il roster.") end
      return
    end
    addDlg.mode = mode or "add"
    addDlg.editName = player and player.name or nil
    addRoleDD:SetOptions(MAIN_ROLE_OPTS)
    addPrioDD:SetOptions(PRIORITY_OPTS)
    addOffDD:SetOptions(OFF_ROLE_OPTS)
    addStatusDD:SetOptions(STATUS_OPTS)
    addLaunchDD:SetOptions(LAUNCH_OPTS)
    addAttDD:SetOptions(ATT_OPTS)
    addErr:SetText("")
    local showOfficer = ns.CanViewOfficerFields and ns.CanViewOfficerFields()
    if prioLab then prioLab:SetShown(showOfficer) end
    addPrioDD:SetShown(showOfficer)
    notesWrap:SetShown(showOfficer)
    if not showOfficer then notesWrap:SetText("") end

    if mode == "edit" and player then
      addTitle:SetText(L["EDIT_PLAYER"] or "Modifica PG")
      addConfirm.text:SetText(L["SAVE"] or "Salva")
      nameBox:SetText(player.name or "")
      addClassDD:SetValue(player.class ~= "" and player.class or "Warlock")
      addRoleDD:SetValue(getMainLane(player))
      addPrioDD:SetValue(getPriority(player))
      addOffDD:SetValue(ns.OffRolesToValue and ns.OffRolesToValue(player) or "")
      addStatusDD:SetValue(player.status or "to_evaluate")
      addLaunchDD:SetValue(player.launch or "")
      addAttDD:SetValue(player.attendance ~= nil and player.attendance or "")
      notesWrap:SetText(player.notes or "")
    else
      addTitle:SetText(L["ADD_PLAYER"] or "Aggiungi PG")
      addConfirm.text:SetText(L["ADD"] or "Aggiungi")
      nameBox:SetText("")
      addClassDD:SetValue("Warlock")
      addRoleDD:SetValue("ranged")
      addPrioDD:SetValue(3)
      addOffDD:SetValue("")
      addStatusDD:SetValue("to_evaluate")
      addLaunchDD:SetValue("")
      addAttDD:SetValue("")
      notesWrap:SetText("")
    end

    addDlg:Show()
    addDlg:Raise()
    nameBox:SetFocus()
  end
  parent.openPlayerDialog = openPlayerDialog

  if not StaticPopupDialogs["GUILDPERFORMER_DELETE"] then
    StaticPopupDialogs["GUILDPERFORMER_DELETE"] = {
      text = "%s",
      button1 = YES,
      button2 = NO,
      OnAccept = function(self)
        local name = self.data
        if name and ns.RemovePlayer(name) then
          if ns.Print then
            ns.Print(string.format(L["REMOVE_OK"] or "Rimosso %s.", name))
          end
          if ns.RefreshRosterView then ns.RefreshRosterView() end
          if ns.RefreshDashboard then ns.RefreshDashboard() end
        elseif ns.Print then
          ns.Print(L["REMOVE_FAIL"] or "PG non trovato.")
        end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
  end

  local addBtn = W.button(filterBar, "+", 26, 26, true, function()
    openPlayerDialog("add")
  end)
  addBtn:SetPoint("RIGHT", clearBtn, "LEFT", -8, 0)
  addBtn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(L["ADD_PLAYER"] or "Aggiungi PG")
    GameTooltip:Show()
  end)
  addBtn:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  parent.addBtn = addBtn

  local header = W.panel(parent, C.panelAlt)
  header:SetPoint("TOPLEFT", 16, -78)
  header:SetPoint("TOPRIGHT", -28, -78)
  header:SetHeight(22)
  parent.headerPrioFS = nil
  local cols = {
    { L["COL_NAME"], 10, nil },
    { L["COL_MAIN"] or "Main", 155, nil },
    { L["COL_OFF"] or L["OFFSPEC"] or "Off", 258, nil },
    { L["COL_PRIORITY"] or "Priorità", 378, "prio" },
    { L["COL_STATUS"], 438, nil },
    { L["COL_LAUNCH"], 568, nil },
    { L["COL_ATT"], 688, nil },
  }
  for _, col in ipairs(cols) do
    local fs = W.fs(header, "GameFontNormalSmall", col[1], C.subtext)
    fs:SetPoint("LEFT", col[2], 0)
    if col[3] == "prio" then parent.headerPrioFS = fs end
  end
  local actFS = W.fs(header, "GameFontNormalSmall", L["COL_ACTIONS"] or "", C.subtext)
  actFS:SetPoint("RIGHT", -8, 0)
  parent.headerActFS = actFS

  local scroll, child = W.scroll(parent)
  scroll:SetPoint("TOPLEFT", 16, -104)
  scroll:SetPoint("BOTTOMRIGHT", -28, 12)
  parent.scroll = scroll
  parent.child = child

  local function addSectionHeader(text, color, y, width)
    local bar = CreateFrame("Frame", nil, child, "BackdropTemplate")
    -- Distinct from player rows: deeper tint + role-colored left stripe
    local bg = {
      math.min(1, (color[1] or 0.3) * 0.22 + 0.06),
      math.min(1, (color[2] or 0.3) * 0.22 + 0.07),
      math.min(1, (color[3] or 0.3) * 0.22 + 0.09),
      1,
    }
    W.setBG(bar, bg)
    bar:SetBackdropBorderColor((color[1] or 0.4) * 0.55, (color[2] or 0.4) * 0.55, (color[3] or 0.4) * 0.55, 1)
    bar.forcedBorderColors = true
    bar:SetSize(width, 26)
    bar:SetPoint("TOPLEFT", 0, y)

    local stripe = bar:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 0, 0)
    stripe:SetPoint("BOTTOMLEFT", 0, 0)
    stripe:SetWidth(4)
    stripe:SetColorTexture(color[1], color[2], color[3], 1)

    local fs = W.fs(bar, "GameFontNormal", text, color)
    fs:SetPoint("LEFT", 14, 0)
    return y - 30
  end

  local function addPlayerRow(p, i, y, width)
    local canEdit = ns.CanEditPlayer and ns.CanEditPlayer(p)
    local isOfficer = ns.CanEditRoster and ns.CanEditRoster()
    local showOfficer = ns.CanViewOfficerFields and ns.CanViewOfficerFields()
    -- Frame (not Button) so the Main dropdown receives clicks
    local row = CreateFrame("Frame", nil, child, "BackdropTemplate")
    W.setBG(row, (i % 2 == 0) and C.row or C.panelAlt)
    row:SetSize(width, 40)
    row:SetPoint("TOPLEFT", 0, y)
    row:EnableMouse(true)

    local mainLane = getMainLane(p)
    local board = normalizeRole(mainLane)
    local roleCol = C[board] or C.subtext
    local offText = formatOffDisplay(p, mainLane)

    local nameFS = W.fs(row, "GameFontNormal", ns.ClassColorText(p.class, p.name))
    nameFS:SetPoint("LEFT", 10, 0)
    nameFS:SetWidth(150)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)

    local fl = row:GetFrameLevel() + 5

    local mainDD = W.dropdown(row, 96, 24)
    mainDD:SetPoint("LEFT", 155, 0)
    mainDD:SetFrameLevel(fl)
    mainDD:SetOptions(MAIN_ROLE_OPTS)
    mainDD:SetValue(mainLane)
    mainDD:SetEnabled(canEdit)
    mainDD.onSelect = function(v)
      if not (ns.CanEditPlayer and ns.CanEditPlayer(p)) then return end
      p.primaryRole = v
      ns.db.mainRoleOverrides = ns.db.mainRoleOverrides or {}
      ns.db.mainRoleOverrides[ns.NormalizeName(p.name)] = v
      if ns.MarkPlayerEdited then ns.MarkPlayerEdited(p) end
      ns.RefreshRosterView()
    end

    local offDD = W.dropdown(row, 112, 24)
    offDD:SetPoint("LEFT", 258, 0)
    offDD:SetFrameLevel(fl)
    offDD:SetOptions(OFF_ROLE_OPTS)
    offDD:SetValue(ns.OffRolesToValue and ns.OffRolesToValue(p) or "")
    offDD:SetEnabled(canEdit)
    offDD.onSelect = function(v)
      if not (ns.CanEditPlayer and ns.CanEditPlayer(p)) then return end
      local roles = {}
      if type(v) == "string" and v ~= "" then
        for part in string.gmatch(v, "[^,]+") do
          roles[#roles + 1] = strtrim(part)
        end
      end
      p.offRoles = roles
      if ns.MarkPlayerEdited then ns.MarkPlayerEdited(p) end
      ns.RefreshRosterView()
    end

    local prio = getPriority(p)
    local prioDD = W.dropdown(row, 52, 24)
    prioDD:SetPoint("LEFT", 378, 0)
    prioDD:SetFrameLevel(fl)
    prioDD:SetOptions(PRIORITY_OPTS)
    prioDD:SetValue(prio)
    prioDD:SetShown(showOfficer)
    prioDD:SetEnabled(isOfficer)
    prioDD.onSelect = function(v)
      if not (ns.CanEditRoster and ns.CanEditRoster()) then return end
      local n = tonumber(v) or 3
      p.priority = n
      ns.db.priorityOverrides = ns.db.priorityOverrides or {}
      ns.db.priorityOverrides[ns.NormalizeName(p.name)] = n
      if ns.MarkPlayerEdited then ns.MarkPlayerEdited(p) end
    end

    local statusDD = W.dropdown(row, 122, 24)
    statusDD:SetPoint("LEFT", 438, 0)
    statusDD:SetFrameLevel(fl)
    statusDD:SetOptions(STATUS_OPTS)
    statusDD:SetValue(p.status or "to_evaluate")
    statusDD:SetEnabled(canEdit)
    statusDD.onSelect = function(v)
      if not (ns.CanEditPlayer and ns.CanEditPlayer(p)) then return end
      p.status = v
      p.intends = v ~= "non_raider"
      if ns.MarkPlayerEdited then ns.MarkPlayerEdited(p) end
      ns.RefreshRosterView()
    end

    local launchDD = W.dropdown(row, 112, 24)
    launchDD:SetPoint("LEFT", 568, 0)
    launchDD:SetFrameLevel(fl)
    launchDD:SetOptions(LAUNCH_OPTS)
    launchDD:SetValue(p.launch or "")
    launchDD:SetEnabled(canEdit)
    launchDD.onSelect = function(v)
      if not (ns.CanEditPlayer and ns.CanEditPlayer(p)) then return end
      p.launch = v or ""
      if ns.MarkPlayerEdited then ns.MarkPlayerEdited(p) end
      ns.RefreshRosterView()
    end

    local attDD = W.dropdown(row, 52, 24)
    attDD:SetPoint("LEFT", 688, 0)
    attDD:SetFrameLevel(fl)
    attDD:SetOptions(ATT_OPTS)
    attDD:SetValue(p.attendance ~= nil and p.attendance or "")
    attDD:SetEnabled(canEdit)
    attDD.onSelect = function(v)
      if not (ns.CanEditPlayer and ns.CanEditPlayer(p)) then return end
      if v == "" or v == nil then
        p.attendance = nil
      else
        p.attendance = tonumber(v)
      end
      if ns.MarkPlayerEdited then ns.MarkPlayerEdited(p) end
    end

    local delBtn = W.button(row, "×", 24, 24, false, function()
      if not (ns.CanEditRoster and ns.CanEditRoster()) then return end
      StaticPopup_Show(
        "GUILDPERFORMER_DELETE",
        string.format(L["DELETE_CONFIRM"] or "Eliminare %s dal roster?", p.name),
        nil,
        p.name
      )
    end)
    delBtn:SetPoint("RIGHT", -6, 0)
    delBtn:SetFrameLevel(row:GetFrameLevel() + 5)
    delBtn:SetShown(isOfficer)
    delBtn:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText(L["DELETE"] or "Elimina")
      GameTooltip:Show()
    end)
    delBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local editBtn = W.button(row, "✎", 24, 24, false, function()
      openPlayerDialog("edit", p)
    end)
    editBtn:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
    editBtn:SetFrameLevel(row:GetFrameLevel() + 5)
    editBtn:SetShown(canEdit)
    editBtn:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText(L["EDIT"] or "Modifica")
      GameTooltip:Show()
    end)
    editBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    row:SetScript("OnEnter", function(self)
      self:SetBackdropColor(C.rowHover[1], C.rowHover[2], C.rowHover[3], 1)
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:ClearLines()
      GameTooltip:AddLine(p.name, 1, 1, 1)
      GameTooltip:AddLine((p.class or "?") .. ((p.spec and p.spec ~= "") and (" · " .. p.spec) or ""), 0.75, 0.75, 0.8)
      GameTooltip:AddDoubleLine(L["COL_MAIN"] or "Main", string.upper(mainLane), 0.6, 0.6, 0.6, roleCol[1], roleCol[2], roleCol[3])
      GameTooltip:AddDoubleLine(L["OFFSPEC"] or "Off", offText, 0.6, 0.6, 0.6, 1, 0.82, 0.4)
      if showOfficer then
        GameTooltip:AddDoubleLine(L["COL_PRIORITY"] or "Priorità", tostring(getPriority(p)), 0.6, 0.6, 0.6, 1, 1, 1)
      end
      GameTooltip:AddDoubleLine(L["COL_STATUS"], ns.StatusLabel(p.status), 0.6, 0.6, 0.6, 1, 1, 1)
      GameTooltip:AddDoubleLine(L["COL_LAUNCH"], ns.LaunchLabel(p.launch), 0.6, 0.6, 0.6, 1, 1, 1)
      if p.attendance ~= nil then
        GameTooltip:AddDoubleLine(L["COL_ATT"] or "Pres.", tostring(p.attendance), 0.6, 0.6, 0.6, 1, 1, 1)
      end
      if showOfficer and p.tags and #p.tags > 0 then
        local tagBits = {}
        for _, t in ipairs(p.tags) do tagBits[#tagBits + 1] = ns.FlagLabel(t) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine((L["COL_NOTES"] or "Tag") .. ": " .. table.concat(tagBits, ", "), 1, 0.75, 0.3, true)
      end
      if showOfficer and p.notes and p.notes ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine((L["NOTES"] or "Note") .. ":", 0.85, 0.85, 0.7)
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
    if opts.status and statusDD then
      statusDD:SetValue(opts.status)
    elseif not opts.criticalOnly and not opts.absencesOnly and statusDD then
      statusDD:SetValue("all")
    end
    if ns.UI then ns.UI:ShowModule(opts.module or "roster") end
  end

  function ns.RefreshRosterView()
    local canEdit = ns.CanEditRoster and ns.CanEditRoster()
    local showOfficer = ns.CanViewOfficerFields and ns.CanViewOfficerFields()
    if addBtn then
      addBtn:SetShown(canEdit)
      if addBtn.SetEnabled then addBtn:SetEnabled(canEdit) end
    end
    if parent.headerPrioFS then parent.headerPrioFS:SetShown(showOfficer) end
    if parent.headerActFS then parent.headerActFS:SetShown(canEdit) end

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
