local ADDON, ns = ...
local L = ns.L
local C = ns.Colors
local W = ns.W

local function estimateEditHeight(edit, minH)
  local text = edit:GetText() or ""
  local width = edit:GetWidth()
  if width < 50 then width = 700 end

  -- Prefer real font-string metrics when available.
  if edit.GetFontString then
    local fs = edit:GetFontString()
    if fs then
      fs:SetWidth(width)
      local h = fs:GetStringHeight()
      if h and h > 0 then
        return math.max(minH, h + 24)
      end
    end
  end

  local _, fontSize = edit:GetFont()
  fontSize = fontSize or 12
  local lineH = fontSize + 4
  local charsPerLine = math.max(20, math.floor(width / math.max(6, fontSize * 0.55)))
  local lines = 1
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local len = strlenutf8 and strlenutf8(line) or #line
    lines = lines + math.max(1, math.ceil(len / charsPerLine))
  end
  if text == "" then lines = 1 end
  return math.max(minH, lines * lineH + 20)
end

function ns.BuildImportView(parent)
  local title = W.fs(parent, "GameFontNormalHuge", L["IMPORT"])
  title:SetPoint("TOPLEFT", 16, -14)
  W.color(title, C.accent2)

  local hint = W.fs(parent, "GameFontHighlightSmall", L["IMPORT_HINT"], C.subtext)
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

  local boxPanel = W.panel(parent, C.panelAlt)
  boxPanel:SetPoint("TOPLEFT", 16, -60)
  boxPanel:SetPoint("TOPRIGHT", -28, -60)
  boxPanel:SetPoint("BOTTOM", parent, "BOTTOM", 0, 90)

  local scroll, content = W.scroll(boxPanel)
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -8, 8)

  local edit = CreateFrame("EditBox", "GuildPerformerImportEdit", content)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetTextInsets(6, 6, 6, 6)
  edit:SetMaxLetters(0)
  edit:EnableMouse(true)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  edit:SetPoint("TOPLEFT", 0, 0)
  edit:SetTextColor(C.text[1], C.text[2], C.text[3])

  local function syncEditSize()
    local viewW = math.max(100, (scroll:GetWidth() or 700) - 4)
    edit:SetWidth(viewW)
    content:SetWidth(viewW)
    local minH = math.max(120, scroll:GetHeight() or 120)
    local h = estimateEditHeight(edit, minH)
    edit:SetHeight(h)
    content:SetHeight(h)
    if scroll.Refresh then scroll:Refresh() end
  end

  edit:SetScript("OnTextChanged", function()
    syncEditSize()
  end)
  edit:SetScript("OnCursorChanged", function(self, x, y, _, cursorHeight)
    -- Keep caret visible while typing / pasting.
    if not y then return end
    local offset = scroll:GetVerticalScroll() or 0
    local viewH = scroll:GetHeight() or 0
    local cursorTop = -y
    local cursorBottom = cursorTop + (cursorHeight or 14)
    if cursorTop < offset then
      scroll:SetVerticalScroll(cursorTop)
    elseif cursorBottom > offset + viewH then
      scroll:SetVerticalScroll(cursorBottom - viewH)
    end
    if scroll.Refresh then scroll:Refresh() end
  end)

  scroll:HookScript("OnSizeChanged", syncEditSize)
  boxPanel:HookScript("OnSizeChanged", syncEditSize)
  parent:HookScript("OnShow", syncEditSize)

  -- Mouse wheel over the edit box should scroll the frame.
  edit:SetScript("OnMouseWheel", function(_, delta)
    local script = scroll:GetScript("OnMouseWheel")
    if script then script(scroll, delta) end
  end)

  parent.edit = edit
  parent.importScroll = scroll

  local status = W.fs(parent, "GameFontNormal", "", C.text)
  status:SetPoint("TOPLEFT", boxPanel, "BOTTOMLEFT", 0, -10)
  status:SetJustifyH("LEFT")
  status:SetPoint("RIGHT", boxPanel, "RIGHT", 0, 0)

  local previewPayload = nil

  local function setStatus(text, col)
    status:SetText(text or "")
    if col then W.color(status, col) end
  end

  local function doPreview()
    local payload, err = ns.ParseExportString(edit:GetText())
    if not payload then
      previewPayload = nil
      setStatus(string.format(L["IMPORT_FAIL"], err or "?"), C.bad)
      return nil
    end
    previewPayload = payload
    setStatus(string.format("Preview OK: %d players · %s · format v%d",
      #payload.players, payload.meta.guild or "?", payload.meta.formatVersion or 1), C.ok)
    return payload
  end

  local btnPreview = W.button(parent, L["PREVIEW"], 110, 28, false, doPreview)
  btnPreview:SetPoint("BOTTOMLEFT", 16, 16)

  local function afterImport(n)
    setStatus(string.format(L["IMPORT_OK"], n) .. " · " .. L["BACKUP_SAVED"], C.ok)
    if ns.UI then
      ns.UI:ShowModule("roster")
    else
      ns.RefreshActiveTab()
    end
  end

  local btnReplace = W.button(parent, L["APPLY_REPLACE"], 140, 28, true, function()
    if not previewPayload then doPreview() end
    if not previewPayload then return end
    afterImport(ns.ApplyImport(previewPayload, "replace"))
  end)
  btnReplace:SetPoint("LEFT", btnPreview, "RIGHT", 8, 0)

  local btnMerge = W.button(parent, L["APPLY_MERGE"], 100, 28, false, function()
    if not previewPayload then doPreview() end
    if not previewPayload then return end
    afterImport(ns.ApplyImport(previewPayload, "merge"))
  end)
  btnMerge:SetPoint("LEFT", btnReplace, "RIGHT", 8, 0)

  local btnUndo = W.button(parent, L["UNDO_IMPORT"], 150, 28, false, function()
    if ns.RestoreBackup() then
      setStatus(L["UNDO_OK"], C.ok)
      ns.RefreshActiveTab()
    else
      setStatus(L["UNDO_NONE"], C.warn)
    end
  end)
  btnUndo:SetPoint("LEFT", btnMerge, "RIGHT", 8, 0)

  local btnClear = W.button(parent, L["CLEAR"] or "Clear", 80, 28, false, function()
    edit:SetText("")
    previewPayload = nil
    setStatus("", C.subtext)
    syncEditSize()
  end)
  btnClear:SetPoint("LEFT", btnUndo, "RIGHT", 8, 0)

  local btnSync = W.button(parent, L["SYNC_APPLY"], 130, 28, false, function()
    local n, err = ns.TryApplySyncedData(true)
    if n then
      afterImport(n)
    else
      setStatus(err or (L["SYNC_NO_DATA"] or "No sync data."), C.warn)
    end
  end)
  btnSync:SetPoint("LEFT", btnClear, "RIGHT", 8, 0)

  function ns.RefreshImportView()
    syncEditSize()
  end
end
