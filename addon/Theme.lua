local ADDON, ns = ...

ns.ADDON_TITLE = "Guild Performer"

-- Dark UI palette (inspired by modern WoW suite UIs; original values).
ns.Colors = {
  bg       = { 0.04, 0.035, 0.03, 0.96 },
  panel    = { 0.08, 0.07, 0.05, 1 },
  panelAlt = { 0.11, 0.10, 0.07, 1 },
  row      = { 0.13, 0.12, 0.08, 1 },
  rowHover = { 0.20, 0.17, 0.10, 1 },
  accent   = { 0.45, 0.72, 0.92, 1 },
  accent2  = { 0.35, 0.55, 0.78, 1 },
  text     = { 0.92, 0.90, 0.85, 1 },
  subtext  = { 0.66, 0.62, 0.54, 1 },
  border   = { 0.22, 0.28, 0.36, 1 },
  tank     = { 0.44, 0.66, 1.00, 1 },
  healer   = { 0.30, 0.90, 0.55, 1 },
  dps      = { 1.00, 0.42, 0.42, 1 },
  ok       = { 0.20, 0.82, 0.48, 1 },
  warn     = { 1.00, 0.76, 0.24, 1 },
  bad      = { 1.00, 0.35, 0.35, 1 },
}

ns.Themes = {
  { key = "azure", name = "Azure", colors = {
    bg = { 0.04, 0.05, 0.07, 0.96 }, panel = { 0.07, 0.09, 0.12 }, panelAlt = { 0.10, 0.12, 0.16 },
    row = { 0.12, 0.14, 0.19 }, rowHover = { 0.15, 0.19, 0.27 },
    accent = { 0.45, 0.72, 0.92 }, accent2 = { 0.35, 0.55, 0.78 },
    text = { 0.90, 0.90, 0.92 }, subtext = { 0.60, 0.60, 0.65 }, border = { 0.20, 0.25, 0.33 } } },
  { key = "gold", name = "Black & Gold", colors = {
    bg = { 0.04, 0.035, 0.03, 0.96 }, panel = { 0.08, 0.07, 0.05 }, panelAlt = { 0.11, 0.10, 0.07 },
    row = { 0.13, 0.12, 0.08 }, rowHover = { 0.20, 0.17, 0.10 },
    accent = { 0.80, 0.66, 0.36 }, accent2 = { 0.66, 0.52, 0.30 },
    text = { 0.92, 0.90, 0.85 }, subtext = { 0.66, 0.62, 0.54 }, border = { 0.30, 0.25, 0.15 } } },
  { key = "amethyst", name = "Amethyst", colors = {
    bg = { 0.05, 0.045, 0.06, 0.96 }, panel = { 0.09, 0.08, 0.11 }, panelAlt = { 0.12, 0.11, 0.15 },
    row = { 0.14, 0.13, 0.18 }, rowHover = { 0.19, 0.16, 0.24 },
    accent = { 0.62, 0.48, 0.80 }, accent2 = { 0.72, 0.52, 0.68 },
    text = { 0.90, 0.90, 0.92 }, subtext = { 0.60, 0.60, 0.65 }, border = { 0.24, 0.21, 0.30 } } },
  { key = "emerald", name = "Emerald", colors = {
    bg = { 0.04, 0.06, 0.05, 0.96 }, panel = { 0.07, 0.10, 0.08 }, panelAlt = { 0.09, 0.13, 0.11 },
    row = { 0.11, 0.16, 0.13 }, rowHover = { 0.14, 0.22, 0.17 },
    accent = { 0.40, 0.70, 0.52 }, accent2 = { 0.58, 0.72, 0.46 },
    text = { 0.90, 0.90, 0.92 }, subtext = { 0.60, 0.60, 0.65 }, border = { 0.19, 0.28, 0.22 } } },
  { key = "ember", name = "Ember", colors = {
    bg = { 0.06, 0.05, 0.04, 0.96 }, panel = { 0.10, 0.08, 0.06 }, panelAlt = { 0.14, 0.11, 0.08 },
    row = { 0.16, 0.13, 0.10 }, rowHover = { 0.24, 0.18, 0.12 },
    accent = { 0.84, 0.58, 0.34 }, accent2 = { 0.78, 0.42, 0.34 },
    text = { 0.90, 0.90, 0.92 }, subtext = { 0.60, 0.60, 0.65 }, border = { 0.30, 0.23, 0.16 } } },
  { key = "slate", name = "Slate Teal", colors = {
    bg = { 0.04, 0.06, 0.06, 0.96 }, panel = { 0.07, 0.10, 0.10 }, panelAlt = { 0.10, 0.13, 0.13 },
    row = { 0.12, 0.15, 0.15 }, rowHover = { 0.15, 0.21, 0.21 },
    accent = { 0.44, 0.68, 0.68 }, accent2 = { 0.56, 0.70, 0.66 },
    text = { 0.90, 0.90, 0.92 }, subtext = { 0.60, 0.60, 0.65 }, border = { 0.20, 0.27, 0.27 } } },
}

ns.ThemeByKey = {}
for _, t in ipairs(ns.Themes) do ns.ThemeByKey[t.key] = t end

ns.UIDefaults = {
  scale = 1.0,
  theme = "azure",
  defaultModule = "dashboard",
  lockWindow = false,
  showMinimap = true,
}

function ns.ApplyTheme(key)
  local t = ns.ThemeByKey[key] or ns.ThemeByKey[ns.UIDefaults.theme]
  if not t then return end
  for k, v in pairs(t.colors) do
    local dest = ns.Colors[k]
    if dest then
      for i = 1, #v do dest[i] = v[i] end
      if v[4] then dest[4] = v[4] end
    end
  end
end
