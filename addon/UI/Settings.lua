local ADDON, ns = ...
local L = ns.L
local C = ns.Colors
local W = ns.W

local ui = {}
local pending = {}

local function row(parent, y, label, desc)
  local r = W.panel(parent, C.panelAlt)
  r:SetPoint("TOPLEFT", 16, y)
  r:SetPoint("TOPRIGHT", -16, y)
  r:SetHeight(desc and 52 or 40)
  local lab = W.fs(r, "GameFontNormal", label, C.text)
  lab:SetPoint("TOPLEFT", 12, desc and -8 or -13)
  if desc then
    local d = W.fs(r, "GameFontNormalSmall", desc, C.subtext)
    d:SetPoint("TOPLEFT", 12, -26)
  end
  return r
end

function ns.BuildSettingsView(parent)
  local title = W.fs(parent, "GameFontNormalHuge", L["SETTINGS"])
  title:SetPoint("TOPLEFT", 16, -14)
  W.color(title, C.accent2)

  local y = -52

  local rScale = row(parent, y, L["SCALE"], L["SCALE_DESC"])
  ui.scale = W.stepper(rScale, 0.5, 2.0, 0.05, "%.2f")
  ui.scale:SetPoint("RIGHT", rScale, "RIGHT", -12, 0)
  ui.scale.onChange = function(v) pending.scale = v end
  y = y - 60

  local rTheme = row(parent, y, L["THEME"], L["THEME_DESC"])
  ui.theme = W.dropdown(rTheme, 190, 26)
  ui.theme:SetPoint("RIGHT", rTheme, "RIGHT", -12, 0)
  local themeOpts = {}
  for _, t in ipairs(ns.Themes) do
    themeOpts[#themeOpts + 1] = { value = t.key, text = t.name, swatch = t.colors.accent }
  end
  ui.theme:SetOptions(themeOpts)
  ui.theme.onSelect = function(v) pending.theme = v end
  y = y - 60

  local rMod = row(parent, y, L["OPEN_ON"], L["OPEN_ON_DESC"])
  ui.defaultModule = W.dropdown(rMod, 190, 26)
  ui.defaultModule:SetPoint("RIGHT", rMod, "RIGHT", -12, 0)
  ui.defaultModule:SetOptions({
    { value = "dashboard", text = L["DASHBOARD"] },
    { value = "roster", text = L["ROSTER"] },
    { value = "events", text = L["EVENTS"] or "Eventi" },
    { value = "settings", text = L["SETTINGS"] },
  })
  ui.defaultModule.onSelect = function(v) pending.defaultModule = v end
  y = y - 60

  local rMini = row(parent, y, L["SHOW_MINIMAP"], L["MINIMAP_DESC"])
  ui.minimap = W.checkbox(rMini)
  ui.minimap:SetPoint("RIGHT", rMini, "RIGHT", -16, 0)
  ui.minimap.onToggle = function(v) pending.showMinimap = v end
  y = y - 48

  local rLock = row(parent, y, L["LOCK_WINDOW"], L["LOCK_WINDOW_DESC"])
  ui.lock = W.checkbox(rLock)
  ui.lock:SetPoint("RIGHT", rLock, "RIGHT", -16, 0)
  ui.lock.onToggle = function(v) pending.lockWindow = v end
  y = y - 56

  local rSync = row(parent, y, L["SYNC_COMPANION"], L["SYNC_COMPANION_DESC"])
  rSync:SetHeight(72)
  local syncHint = W.fs(rSync, "GameFontNormalSmall", L["SYNC_COMPANION_HINT"] or "", C.subtext)
  syncHint:SetPoint("TOPLEFT", 200, -8)
  syncHint:SetPoint("RIGHT", -12, 0)
  syncHint:SetJustifyH("LEFT")
  syncHint:SetWordWrap(true)
  y = y - 80

  -- Optional note field (not used for HTTP — companion holds the token)
  local rNote = row(parent, y, L["SYNC_URL"], L["SYNC_URL_DESC"])
  rNote:SetHeight(56)
  local syncPanel = W.panel(rNote, C.panel)
  syncPanel:SetSize(280, 24)
  syncPanel:SetPoint("RIGHT", rNote, "RIGHT", -12, -6)
  ui.syncUrl = W.editBox(syncPanel, false)
  ui.syncUrl:SetAllPoints()
  ui.syncUrl:SetScript("OnTextChanged", function(self)
    pending.syncUrl = self:GetText() or ""
  end)
  y = y - 64

  local rAuto = row(parent, y, L["SYNC_AUTO"], L["SYNC_AUTO_DESC"])
  ui.autoApplySync = W.checkbox(rAuto)
  ui.autoApplySync:SetPoint("RIGHT", rAuto, "RIGHT", -16, 0)
  ui.autoApplySync.onToggle = function(v) pending.autoApplySync = v end
  y = y - 48

  ui.applySync = W.button(parent, L["SYNC_APPLY"], 160, 28, false, function()
    local n, err = ns.TryApplySyncedData(true)
    if n then
      if ui.status then ui.status:SetText("|cff33d17a" .. string.format(L["SYNC_APPLIED"] or "Synced %d.", n) .. "|r") end
    else
      if ui.status then ui.status:SetText("|cffffaa00" .. (err or "?") .. "|r") end
    end
  end)
  ui.applySync:SetPoint("TOPLEFT", 16, y)

  ui.pushPrep = W.button(parent, L["PUSH_PREP"] or "Prepara push", 140, 28, false, function()
    local n, err = ns.PreparePushForCompanion and ns.PreparePushForCompanion()
    if n then
      if ui.status then ui.status:SetText("|cff33d17a" .. string.format(L["PUSH_PREP_OK"] or "Push ready (%d).", n) .. "|r") end
    else
      if ui.status then ui.status:SetText("|cffffaa00" .. (err or "?") .. "|r") end
    end
  end)
  ui.pushPrep:SetPoint("LEFT", ui.applySync, "RIGHT", 10, 0)
  y = y - 40

  ui.save = W.button(parent, L["SAVE"], 120, 30, true, function()
    local d = ns.db.settings
    d.scale = pending.scale
    d.theme = pending.theme
    d.defaultModule = pending.defaultModule
    d.lockWindow = pending.lockWindow
    d.showMinimap = pending.showMinimap
    d.syncUrl = pending.syncUrl or ""
    d.autoApplySync = pending.autoApplySync ~= false
    d.minimap = d.minimap or {}
    d.minimap.hide = not pending.showMinimap
    ns.ApplyTheme(d.theme)
    if ns.UI and ns.UI.ApplyThemeLive then ns.UI:ApplyThemeLive() end
    if ns.Minimap then ns.Minimap:SetShown(pending.showMinimap) end
    if ui.status then ui.status:SetText("|cff33d17a" .. (L["SAVED"] or "Saved.") .. "|r") end
  end)
  ui.save:SetPoint("TOPLEFT", 16, y)

  ui.reset = W.button(parent, L["RESET_DEFAULTS"], 160, 30, false, function()
    local d = ns.db.settings
    d.scale = ns.UIDefaults.scale
    d.theme = ns.UIDefaults.theme
    d.defaultModule = ns.UIDefaults.defaultModule
    d.lockWindow = ns.UIDefaults.lockWindow
    d.showMinimap = true
    d.minimap = d.minimap or {}
    d.minimap.hide = false
    ns.RefreshSettingsView()
    ns.ApplyTheme(d.theme)
    if ns.UI and ns.UI.ApplyThemeLive then ns.UI:ApplyThemeLive() end
    if ns.Minimap then ns.Minimap:SetShown(true) end
    if ui.status then ui.status:SetText("|cff9aa0ac" .. (L["RESET_DEFAULTS"] or "Reset") .. "|r") end
  end)
  ui.reset:SetPoint("LEFT", ui.save, "RIGHT", 10, 0)

  ui.status = W.fs(parent, "GameFontNormalSmall", "", C.subtext)
  ui.status:SetPoint("LEFT", ui.reset, "RIGHT", 14, 0)

  local ver = W.fs(parent, "GameFontDisable",
    string.format("Addon %s · Format v%d · Interface 120007", ns.ADDON_VERSION, ns.FORMAT_VERSION),
    C.subtext)
  ver:SetPoint("BOTTOMLEFT", 16, 12)

  function ns.RefreshSettingsView()
    wipe(pending)
    local d = ns.db.settings
    ui.scale:SetValue(d.scale or ns.UIDefaults.scale, true)
    pending.scale = ui.scale:GetValue()
    ui.theme:SetValue(d.theme or ns.UIDefaults.theme)
    pending.theme = ui.theme:GetValue()
    ui.defaultModule:SetValue(d.defaultModule or ns.UIDefaults.defaultModule)
    pending.defaultModule = ui.defaultModule:GetValue()
    local showMini = d.showMinimap ~= false and not (d.minimap and d.minimap.hide)
    ui.minimap:SetChecked(showMini)
    pending.showMinimap = showMini
    ui.lock:SetChecked(d.lockWindow)
    pending.lockWindow = d.lockWindow
    if ui.syncUrl then
      ui.syncUrl:SetText(d.syncUrl or "")
      pending.syncUrl = d.syncUrl or ""
    end
    if ui.autoApplySync then
      ui.autoApplySync:SetChecked(d.autoApplySync ~= false)
      pending.autoApplySync = d.autoApplySync ~= false
    end
    if ui.status then ui.status:SetText("") end
  end
end

function ns.BuildBuilderView(parent)
  parent.selected = parent.selected or {}

  local title = W.fs(parent, "GameFontNormalHuge", L["BUILDER"])
  title:SetPoint("TOPLEFT", 16, -14)
  W.color(title, C.accent2)

  local summary = W.fs(parent, "GameFontHighlight", "", C.text)
  summary:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  summary:SetJustifyH("LEFT")
  parent.summary = summary

  local suggest = W.button(parent, L["AUTO_SUGGEST"], 130, 26, true, function()
    parent.selected = ns.SuggestComposition()
    ns.RefreshBuilderView()
  end)
  suggest:SetPoint("TOPRIGHT", -16, -14)

  local nameBoxPanel = W.panel(parent, C.panelAlt)
  nameBoxPanel:SetSize(160, 24)
  nameBoxPanel:SetPoint("TOPRIGHT", suggest, "BOTTOMRIGHT", 0, -8)
  local nameBox = W.editBox(nameBoxPanel, false)
  nameBox:SetAllPoints()
  nameBox:SetText("Roster principale")
  parent.nameBox = nameBox

  local saveBtn = W.button(parent, L["SAVE_TEMPLATE"], 130, 24, false, function()
    ns.SaveTemplate(nameBox:GetText(), parent.selected)
    if ns.Print then ns.Print(L["TEMPLATE_SAVED"] or "Template saved.") end
  end)
  saveBtn:SetPoint("TOPRIGHT", nameBoxPanel, "BOTTOMRIGHT", 0, -6)

  local tplDD = W.dropdown(parent, 160, 24)
  tplDD:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
  tplDD.onSelect = function(v)
    local members = ns.LoadTemplate(v)
    if members then
      parent.selected = members
      ns.RefreshBuilderView()
    end
  end
  parent.tplDD = tplDD

  local scroll, child = W.scroll(parent)
  scroll:SetPoint("TOPLEFT", 16, -100)
  scroll:SetPoint("BOTTOMRIGHT", -28, 12)
  parent.scroll = scroll
  parent.child = child

  function ns.RefreshBuilderView()
    local names = ns.ListTemplates()
    local opts = {}
    for _, n in ipairs(names) do opts[#opts + 1] = { value = n, text = n } end
    if #opts == 0 then opts[1] = { value = "", text = L["NO_TEMPLATES"] or "(no templates)" } end
    tplDD:SetOptions(opts)

    local analysis = ns.AnalyzeComposition(parent.selected)
    local lines = {
      string.format(L["COUNT_SUMMARY"], analysis.counts.tank, analysis.counts.healer, analysis.counts.dps),
    }
    if #analysis.missing > 0 then
      lines[#lines + 1] = L["MISSING_ROLE"] .. ": " .. table.concat(analysis.missing, ", ")
    end
    if #analysis.utilityGaps > 0 then
      lines[#lines + 1] = "Utility: " .. table.concat(analysis.utilityGaps, ", ")
    end
    if #analysis.uncertain > 0 then
      lines[#lines + 1] = L["UNCERTAIN"] .. ": " .. table.concat(analysis.uncertain, ", ")
    end
    summary:SetText(table.concat(lines, "\n"))

    for _, c in ipairs({ child:GetChildren() }) do
      c:Hide()
      c:SetParent(nil)
    end

    local y = -2
    local width = math.max(400, (scroll:GetWidth() or 700) - 4)
    child:SetWidth(width)
    for _, p in ipairs(ns.GetPlayersList()) do
      if p.intends ~= false and p.status ~= "non_raider" then
        local row = CreateFrame("Frame", nil, child, "BackdropTemplate")
        W.setBG(row, C.row)
        row:SetSize(width, 30)
        row:SetPoint("TOPLEFT", 0, y)
        local cb = W.checkbox(row)
        cb:SetPoint("LEFT", 8, 0)
        local key = p.name
        cb:SetChecked(parent.selected[key] ~= nil)
        cb.onToggle = function(on)
          if on then
            parent.selected[key] = p.primaryRole or "dps"
          else
            parent.selected[key] = nil
          end
          ns.RefreshBuilderView()
        end
        local fs = W.fs(row, "GameFontNormal", ns.ClassColorText(p.class, p.name))
        fs:SetPoint("LEFT", 36, 0)
        local roleCol = C[p.primaryRole] or C.subtext
        local roleFS = W.fs(row, "GameFontHighlightSmall", string.upper(p.primaryRole or "?"), roleCol)
        roleFS:SetPoint("LEFT", 220, 0)
        y = y - 34
      end
    end
    child:SetHeight(math.max(40, -y + 8))
    if scroll.Refresh then scroll:Refresh() end
  end
end
