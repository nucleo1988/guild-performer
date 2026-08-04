-- Shared UI building blocks for Guild Performer (original implementation).
local ADDON, ns = ...
local C = ns.Colors
ns.W = ns.W or {}
local W = ns.W

W.BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8x8",
  edgeFile = "Interface\\Buttons\\WHITE8x8",
  edgeSize = 1,
}

W._skins = { bg = {}, btn = {}, text = {}, tex = {} }

function W.color(fsObj, col)
  fsObj:SetTextColor(col[1], col[2], col[3])
  W._skins.text[fsObj] = col
end

function W.setBG(frame, col)
  if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
  frame:SetBackdrop(W.BACKDROP)
  frame:SetBackdropColor(col[1], col[2], col[3], col[4] or 1)
  frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  frame.__bgCol = col
  W._skins.bg[frame] = true
end

function W.Reskin()
  for frame in pairs(W._skins.bg) do
    if frame:GetParent() then
      local col = frame.__bgCol
      frame:SetBackdropColor(col[1], col[2], col[3], col[4] or 1)
      if not frame.forcedBorderColors then
        frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
      end
    else
      W._skins.bg[frame] = nil
    end
  end
  for b in pairs(W._skins.btn) do
    if b.ApplyTheme then b:ApplyTheme() end
  end
  for fsObj, col in pairs(W._skins.text) do
    if fsObj:GetParent() then
      fsObj:SetTextColor(col[1], col[2], col[3])
    else
      W._skins.text[fsObj] = nil
    end
  end
  for tex, info in pairs(W._skins.tex) do
    if tex:GetParent() then
      local col = info.col
      if info.mode == "vertex" then
        tex:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
      else
        tex:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
      end
    else
      W._skins.tex[tex] = nil
    end
  end
end

function W.panel(parent, col)
  local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  W.setBG(p, col)
  return p
end

-- Same approach as ElvUI Skins: centered ArrowUp.tga + SetRotation (radians).
-- Source texture points UP by default. See ElvUI Game/Shared/Modules/Skins/Skins.lua
W.ArrowRotation = { up = 0, down = 3.14, left = 1.57, right = -1.57 }
W.ARROW_TEX = "Interface\\AddOns\\GuildPerformer\\Media\\ArrowUp"

--- Shared combo/nav arrow. direction: "down" | "up" | "left" | "right"
function W.ApplyArrow(tex, direction, size)
  size = size or 14
  tex:SetTexture(W.ARROW_TEX)
  tex:SetTexCoord(0, 1, 0, 1)
  tex:SetSize(size, size)
  tex:SetRotation(W.ArrowRotation[direction or "down"] or 0)
  local a = C.accent
  tex:SetVertexColor(a[1], a[2], a[3], 1)
  W._skins.tex[tex] = { col = C.accent, mode = "vertex" }
  return tex
end

--- Square button with centered arrow (e.g. back to event list).
function W.arrowButton(parent, direction, size, onClick)
  size = size or 26
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(size, size)
  b:SetBackdrop(W.BACKDROP)
  b:SetBackdropColor(0.13, 0.13, 0.17, 1)
  b:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  local arrow = b:CreateTexture(nil, "OVERLAY")
  W.ApplyArrow(arrow, direction, math.floor(size * 0.55))
  arrow:SetPoint("CENTER", 0, 0)
  b.arrow = arrow
  b:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(C.accent2[1], C.accent2[2], C.accent2[3], 1)
  end)
  b:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  end)
  if onClick then b:SetScript("OnClick", onClick) end
  W._skins.bg[b] = true
  b.__bgCol = { 0.13, 0.13, 0.17, 1 }
  return b
end

function W.fs(parent, template, text, r, g, b)
  local f = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
  f:SetText(text or "")
  if type(r) == "table" then
    W.color(f, r)
  elseif r then
    f:SetTextColor(r, g, b)
  end
  return f
end

function W.button(parent, label, w, h, primary, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  b:SetBackdrop(W.BACKDROP)

  local col = {}
  local function recompute()
    local a = C.accent
    col.normalBg = primary and { a[1] * 0.62, a[2] * 0.62, a[3] * 0.62 } or { 0.13, 0.13, 0.17 }
    col.hoverBg  = primary and { a[1] * 0.82, a[2] * 0.82, a[3] * 0.82 } or { C.rowHover[1], C.rowHover[2], C.rowHover[3] }
    col.downBg   = primary and { a[1] * 0.48, a[2] * 0.48, a[3] * 0.48 } or { 0.10, 0.10, 0.14 }
    col.normalBd = primary and { a[1], a[2], a[3] } or C.border
    col.hoverBd  = C.accent2
  end
  recompute()

  local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("CENTER")
  t:SetText(label)
  t:SetTextColor(1, 1, 1)
  b.text = t

  local function paint(bg, bd)
    b:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    b:SetBackdropBorderColor(bd[1], bd[2], bd[3], 1)
  end
  b.paintNormal = function() paint(col.normalBg, col.normalBd) end
  b.paintActive = function() paint(col.hoverBg, col.hoverBd) end
  paint(col.normalBg, col.normalBd)

  b:SetScript("OnEnter", function(self) if self:IsEnabled() then paint(col.hoverBg, col.hoverBd) end end)
  b:SetScript("OnLeave", function(self)
    if self:IsEnabled() and not self.forceActive then paint(col.normalBg, col.normalBd) end
  end)
  b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then paint(col.downBg, col.hoverBd) end end)
  b:SetScript("OnMouseUp", function(self)
    if self:IsEnabled() then
      local active = self:IsMouseOver() or self.forceActive
      paint(active and col.hoverBg or col.normalBg, active and col.hoverBd or col.normalBd)
    end
  end)
  function b:SetActive(on)
    self.forceActive = on and true or false
    if on then self.paintActive() else self.paintNormal() end
  end
  function b:ApplyTheme()
    recompute()
    if self.forceActive then self.paintActive() else self.paintNormal() end
  end
  W._skins.btn[b] = true
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end

function W.closeButton(parent, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(26, 26)
  b:SetBackdrop(W.BACKDROP)
  local normalBg = { 0.20, 0.13, 0.18, 1 }
  b:SetBackdropColor(normalBg[1], normalBg[2], normalBg[3], normalBg[4])
  b:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  local x = b:CreateTexture(nil, "OVERLAY")
  x:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  x:SetSize(16, 16)
  x:SetPoint("CENTER")
  x:SetDesaturated(true)
  x:SetVertexColor(0.85, 0.85, 0.9)
  b:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.85, 0.20, 0.26, 1)
    self:SetBackdropBorderColor(1, 0.45, 0.5, 1)
    x:SetVertexColor(1, 1, 1)
  end)
  b:SetScript("OnLeave", function(self)
    self:SetBackdropColor(normalBg[1], normalBg[2], normalBg[3], normalBg[4])
    self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    x:SetVertexColor(0.85, 0.85, 0.9)
  end)
  b:SetScript("OnClick", onClick)
  return b
end

function W.scroll(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(10, 10)
  sf:SetScrollChild(content)

  local track = CreateFrame("Frame", nil, sf, "BackdropTemplate")
  track:SetWidth(10)
  track:SetPoint("TOPLEFT", sf, "TOPRIGHT", 6, -14)
  track:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 6, 14)
  track:SetBackdrop(W.BACKDROP)
  track:SetBackdropColor(0.05, 0.05, 0.08, 0.9)
  track:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

  local slider = CreateFrame("Slider", nil, track)
  slider:SetOrientation("VERTICAL")
  slider:SetPoint("TOPLEFT", 1, -1)
  slider:SetPoint("BOTTOMRIGHT", -1, 1)
  slider:SetMinMaxValues(0, 0)
  slider:SetValue(0)
  slider:SetValueStep(1)
  slider:SetObeyStepOnDrag(true)

  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
  W._skins.tex[thumb] = { col = C.accent, mode = "color" }
  thumb:SetSize(8, 40)
  slider:SetThumbTexture(thumb)

  local function navBtn(down)
    local b = CreateFrame("Button", nil, sf, "BackdropTemplate")
    b:SetSize(14, 14)
    b:SetBackdrop(W.BACKDROP)
    b:SetBackdropColor(0.13, 0.13, 0.17, 1)
    b:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    local a = b:CreateTexture(nil, "OVERLAY")
    W.ApplyArrow(a, down and "down" or "up", 10)
    a:SetPoint("CENTER", 0, 0)
    b:SetScript("OnClick", function()
      local mn, mx = slider:GetMinMaxValues()
      slider:SetValue(math.max(mn, math.min(mx, slider:GetValue() + (down and 40 or -40))))
    end)
    return b
  end
  local up = navBtn(false); up:SetPoint("BOTTOM", track, "TOP", 0, 2)
  local down = navBtn(true); down:SetPoint("TOP", track, "BOTTOM", 0, -2)

  slider:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)

  local function refresh()
    local vh = sf:GetHeight()
    local ch = content:GetHeight()
    local range = math.max(0, ch - vh)
    slider:SetMinMaxValues(0, range)
    local v = math.min(slider:GetValue(), range)
    slider:SetValue(v)
    local show = range > 0.5
    track:SetShown(show); up:SetShown(show); down:SetShown(show)
    if show and ch > 0 then
      thumb:SetHeight(math.max(24, math.min(track:GetHeight(), (vh / ch) * track:GetHeight())))
    end
  end
  sf:HookScript("OnSizeChanged", refresh)
  content:HookScript("OnSizeChanged", refresh)
  sf:SetScript("OnMouseWheel", function(_, delta)
    local mn, mx = slider:GetMinMaxValues()
    slider:SetValue(math.max(mn, math.min(mx, slider:GetValue() - delta * 40)))
  end)
  sf.Refresh = refresh
  sf.child = content
  return sf, content
end

function W.dropdown(parent, width, height)
  local dd = CreateFrame("Button", nil, parent, "BackdropTemplate")
  dd:SetSize(width, height or 24)
  dd:SetBackdrop(W.BACKDROP)
  dd:SetBackdropColor(0.11, 0.11, 0.15, 1)
  dd:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

  local sw = dd:CreateTexture(nil, "ARTWORK")
  sw:SetSize(12, 12)
  sw:SetPoint("LEFT", 8, 0)
  sw:Hide()
  dd.swatch = sw

  local text = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("LEFT", 8, 0)
  text:SetPoint("RIGHT", -22, 0)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  dd.text = text

  local arrow = dd:CreateTexture(nil, "ARTWORK")
  W.ApplyArrow(arrow, "down", 14)
  -- ElvUI-style: RIGHT of the combo, optically centered texture
  arrow:ClearAllPoints()
  arrow:SetPoint("RIGHT", dd, "RIGHT", -4, 0)
  dd.arrow = arrow

  dd:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(C.accent2[1], C.accent2[2], C.accent2[3], 1)
  end)
  dd:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  end)

  local menu = CreateFrame("Frame", nil, dd, "BackdropTemplate")
  menu:SetFrameStrata("TOOLTIP")
  menu:EnableMouse(true)
  W.setBG(menu, C.panelAlt)
  menu:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
  menu:SetPoint("TOPRIGHT", dd, "BOTTOMRIGHT", 0, -2)
  menu:Hide()
  dd.menu = menu
  menu:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
  menu:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
  menu:SetScript("OnEvent", function(self)
    if not (dd:IsMouseOver() or self:IsMouseOver()) then self:Hide() end
  end)

  dd.rows = {}
  dd.options = {}

  local function setTextInset(fsObj, hasSwatch)
    fsObj:ClearAllPoints()
    fsObj:SetPoint("LEFT", hasSwatch and 26 or 8, 0)
    fsObj:SetPoint("RIGHT", -22, 0)
  end

  local function applyOptColor(fs, opt)
    if opt and opt.color then
      fs:SetTextColor(opt.color[1], opt.color[2], opt.color[3], 1)
    else
      fs:SetTextColor(1, 1, 1, 1)
    end
  end

  function dd:SetValue(v)
    self.value = v
    local vn = tonumber(v)
    for _, opt in ipairs(self.options) do
      if opt.value == v or (vn ~= nil and tonumber(opt.value) == vn) then
        self.text:SetText(opt.text)
        applyOptColor(self.text, opt)
        if opt.swatch then
          self.swatch:Show()
          self.swatch:SetColorTexture(opt.swatch[1], opt.swatch[2], opt.swatch[3])
          setTextInset(self.text, true)
        else
          self.swatch:Hide()
          setTextInset(self.text, false)
        end
        return
      end
    end
    -- Fallback: prefer a resolved label over a raw number (e.g. calendar invite status)
    local label
    if self.valueLabel then
      label = self.valueLabel(v)
    elseif ns.CalendarStatusLabel then
      label = ns.CalendarStatusLabel(v)
    end
    self.text:SetText(label or tostring(v))
    self.text:SetTextColor(1, 1, 1, 1)
  end
  function dd:GetValue() return self.value end

  function dd:SetEnabled(enabled)
    self._disabled = not enabled
    if enabled then
      self:Enable()
      self:SetAlpha(1)
    else
      self:Disable()
      self:SetAlpha(0.45)
      if self.menu then self.menu:Hide() end
    end
  end

  function dd:SetOptions(options)
    self.options = options or {}
    for _, r in ipairs(self.rows) do r:Hide() end
    local y = -3
    for i, opt in ipairs(self.options) do
      local row = self.rows[i]
      if not row then
        row = CreateFrame("Button", nil, menu)
        row:SetHeight(22)
        row.hl = row:CreateTexture(nil, "BACKGROUND")
        row.hl:SetAllPoints()
        row.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.25)
        row.hl:Hide()
        row.sw = row:CreateTexture(nil, "ARTWORK")
        row.sw:SetSize(12, 12)
        row.sw:SetPoint("LEFT", 8, 0)
        row.sw:Hide()
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetPoint("RIGHT", -8, 0)
        row.text:SetJustifyH("LEFT")
        row:SetScript("OnEnter", function(s) s.hl:Show() end)
        row:SetScript("OnLeave", function(s) s.hl:Hide() end)
        self.rows[i] = row
      end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 3, y)
      row:SetPoint("TOPRIGHT", -3, y)
      if opt.swatch then
        row.sw:Show()
        row.sw:SetColorTexture(opt.swatch[1], opt.swatch[2], opt.swatch[3])
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", 26, 0)
        row.text:SetPoint("RIGHT", -8, 0)
      else
        row.sw:Hide()
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetPoint("RIGHT", -8, 0)
      end
      row.text:SetText(opt.text)
      applyOptColor(row.text, opt)
      row.value = opt.value
      row:SetScript("OnClick", function(s)
        menu:Hide()
        dd:SetValue(s.value)
        if dd.onSelect then dd.onSelect(s.value) end
      end)
      row:Show()
      y = y - 22
    end
    menu:SetHeight(#self.options * 22 + 6)
  end

  dd:SetScript("OnClick", function(self)
    if self._disabled then return end
    if menu:IsShown() then menu:Hide() else menu:Show(); menu:Raise() end
  end)
  return dd
end

function W.checkbox(parent, label)
  local cb = CreateFrame("Button", nil, parent, "BackdropTemplate")
  cb:SetSize(20, 20)
  cb:SetBackdrop(W.BACKDROP)
  cb:SetBackdropColor(0.10, 0.10, 0.14, 1)
  cb:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  local check = cb:CreateTexture(nil, "OVERLAY")
  check:SetPoint("TOPLEFT", 3, -3)
  check:SetPoint("BOTTOMRIGHT", -3, 3)
  check:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
  W._skins.tex[check] = { col = C.accent, mode = "color" }
  check:Hide()
  cb.checked = false
  function cb:SetChecked(v) self.checked = v and true or false; check:SetShown(self.checked) end
  function cb:GetChecked() return self.checked end
  cb:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(C.accent2[1], C.accent2[2], C.accent2[3], 1)
  end)
  cb:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
  end)
  cb:SetScript("OnClick", function(self)
    self:SetChecked(not self.checked)
    if self.onToggle then self.onToggle(self.checked) end
  end)
  if label then
    local lab = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lab:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    lab:SetText(label)
    W.color(lab, C.text)
    cb.labelFS = lab
  end
  return cb
end

function W.stepper(parent, minV, maxV, step, fmt)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(124, 24)
  fmt = fmt or "%.2f"
  local minus = W.button(f, "-", 24, 24, false)
  minus:SetPoint("LEFT", 0, 0)
  local box = W.panel(f, C.panel)
  box:SetSize(64, 24)
  box:SetPoint("LEFT", minus, "RIGHT", 4, 0)
  local val = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  val:SetPoint("CENTER")
  W.color(val, C.accent)
  local plus = W.button(f, "+", 24, 24, false)
  plus:SetPoint("LEFT", box, "RIGHT", 4, 0)
  f.value = minV
  function f:SetValue(v, silent)
    v = math.max(minV, math.min(maxV, v))
    v = math.floor(v / step + 0.5) * step
    self.value = v
    val:SetText(fmt:format(v))
    if not silent and self.onChange then self.onChange(v) end
  end
  function f:GetValue() return self.value end
  minus:SetScript("OnClick", function() f:SetValue(f.value - step) end)
  plus:SetScript("OnClick", function() f:SetValue(f.value + step) end)
  return f
end

function W.editBox(parent, multi)
  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  W.setBG(box, { 0.06, 0.06, 0.08, 1 })
  box:SetAutoFocus(false)
  box:SetFontObject(ChatFontNormal)
  box:SetTextInsets(8, 8, 6, 6)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  if multi then
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
  end
  return box
end

--- Multiline edit inside a scroll frame (notes / paste areas).
function W.scrollEdit(parent, width, height)
  local wrap = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  W.setBG(wrap, { 0.06, 0.06, 0.08, 1 })
  wrap:SetSize(width, height)

  local sf = CreateFrame("ScrollFrame", nil, wrap)
  sf:SetPoint("TOPLEFT", 4, -4)
  sf:SetPoint("BOTTOMRIGHT", -16, 4)

  local edit = CreateFrame("EditBox", nil, sf)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(math.max(40, width - 28))
  edit:SetAutoFocus(false)
  edit:SetTextInsets(4, 4, 2, 2)
  edit:SetMaxLetters(0)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  sf:SetScrollChild(edit)

  local slider = CreateFrame("Slider", nil, wrap)
  slider:SetOrientation("VERTICAL")
  slider:SetPoint("TOPRIGHT", -2, -4)
  slider:SetPoint("BOTTOMRIGHT", -2, 4)
  slider:SetWidth(10)
  slider:SetMinMaxValues(0, 0)
  slider:SetValue(0)
  slider:SetValueStep(1)
  slider:SetObeyStepOnDrag(true)
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
  thumb:SetSize(8, 24)
  slider:SetThumbTexture(thumb)

  local function refresh()
    local ch = edit:GetHeight() or 0
    local vh = sf:GetHeight() or 1
    local range = math.max(0, ch - vh)
    slider:SetMinMaxValues(0, range)
    local v = math.min(slider:GetValue(), range)
    slider:SetValue(v)
    slider:SetShown(range > 1)
  end

  slider:SetScript("OnValueChanged", function(_, v)
    sf:SetVerticalScroll(v)
  end)
  sf:SetScript("OnMouseWheel", function(_, delta)
    local mn, mx = slider:GetMinMaxValues()
    slider:SetValue(math.max(mn, math.min(mx, slider:GetValue() - delta * 24)))
  end)
  edit:SetScript("OnCursorChanged", function()
    -- Grow scroll child with content
    local fontHeight = 14
    local lineCount = select(2, edit:GetText():gsub("\n", "\n")) + 1
    local h = math.max(sf:GetHeight() or height, lineCount * fontHeight + 12)
    edit:SetHeight(h)
    refresh()
  end)
  edit:SetScript("OnTextChanged", function()
    local fontHeight = 14
    local text = edit:GetText() or ""
    local lineCount = select(2, text:gsub("\n", "\n")) + 1
    -- Approximate wrap: ~chars per line
    local cpl = math.max(20, math.floor((edit:GetWidth() or 200) / 7))
    local wrapped = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
      wrapped = wrapped + math.max(1, math.ceil(math.max(1, #line) / cpl))
    end
    local h = math.max(sf:GetHeight() or height, math.max(lineCount, wrapped) * fontHeight + 12)
    edit:SetHeight(h)
    refresh()
  end)
  wrap:HookScript("OnSizeChanged", function()
    edit:SetWidth(math.max(40, wrap:GetWidth() - 28))
    refresh()
  end)

  wrap.edit = edit
  wrap.scroll = sf
  function wrap:GetText() return edit:GetText() end
  function wrap:SetText(t)
    edit:SetText(t or "")
    edit:SetCursorPosition(0)
    if edit:GetScript("OnTextChanged") then edit:GetScript("OnTextChanged")(edit) end
  end
  function wrap:SetFocus() edit:SetFocus() end
  return wrap, edit
end
