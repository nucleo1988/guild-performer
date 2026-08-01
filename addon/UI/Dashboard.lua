local ADDON, ns = ...
local L = ns.L
local C = ns.Colors
local W = ns.W

function ns.BuildDashboard(parent)
  local title = W.fs(parent, "GameFontNormalHuge", L["DASHBOARD"])
  title:SetPoint("TOPLEFT", 16, -14)
  W.color(title, C.accent2)

  local meta = W.fs(parent, "GameFontHighlight", "", C.text)
  meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  meta:SetJustifyH("LEFT")

  local cardsWrap = CreateFrame("Frame", nil, parent)
  cardsWrap:SetPoint("TOPLEFT", 16, -80)
  cardsWrap:SetPoint("TOPRIGHT", -16, -80)
  cardsWrap:SetHeight(120)

  local cards = {}
  local labels = {
    { key = "players", label = L["PLAYERS"], color = C.accent, click = function()
      ns.OpenRosterFiltered({ module = "roster" })
    end },
    { key = "tank", label = L["TANKS"], color = C.tank, click = function()
      ns.OpenRosterFiltered({ role = "tank", module = "tank" })
    end },
    { key = "healer", label = L["HEALERS"], color = C.healer, click = function()
      ns.OpenRosterFiltered({ role = "healer", module = "healer" })
    end },
    { key = "dps", label = L["DPS"], color = C.dps, click = function()
      ns.OpenRosterFiltered({ role = "dps", module = "dps" })
    end },
    { key = "dayone", label = L["DAY_ONE"], color = C.ok, click = function()
      if ns.UI then
        ns.rosterRolePreset = nil
        ns.rosterFilterFlag = nil
        ns.rosterCriticalOnly = nil
        ns.rosterAbsencesOnly = nil
        ns.UI:EnsureCreated()
        if ns.UI.frame.pages.roster and ns.UI.frame.pages.roster.availDD then
          ns.UI.frame.pages.roster.availDD:SetValue("day_one")
        end
        -- store pending launch filter
        ns.pendingLaunchFilter = "day_one"
        ns.UI:ShowModule("roster")
      end
    end },
    { key = "notes", label = L["NOTES"], color = C.warn, click = function()
      ns.OpenRosterFiltered({ criticalOnly = true, module = "notes" })
    end },
  }

  for i, info in ipairs(labels) do
    local card = CreateFrame("Button", nil, cardsWrap, "BackdropTemplate")
    W.setBG(card, C.panelAlt)
    card:SetSize(140, 70)
    card:SetPoint("LEFT", (i - 1) * 150, 0)
    local lab = W.fs(card, "GameFontNormalSmall", info.label, C.subtext)
    lab:SetPoint("TOPLEFT", 10, -10)
    local val = W.fs(card, "GameFontNormalHuge", "0")
    val:SetPoint("BOTTOMLEFT", 10, 12)
    W.color(val, info.color)
    cards[info.key] = val
    card:SetScript("OnEnter", function(self)
      self:SetBackdropColor(C.rowHover[1], C.rowHover[2], C.rowHover[3], 1)
    end)
    card:SetScript("OnLeave", function(self)
      self:SetBackdropColor(C.panelAlt[1], C.panelAlt[2], C.panelAlt[3], C.panelAlt[4] or 1)
    end)
    card:SetScript("OnClick", info.click)
  end

  local legend = W.fs(parent, "GameFontDisableSmall",
    L["LEGEND"] .. ": " .. (L["DASH_HINT"] or "Click a card to open the filtered roster."),
    C.subtext)
  legend:SetPoint("BOTTOMLEFT", 16, 14)

  local hint = W.fs(parent, "GameFontNormal", L["NO_DATA"], C.subtext)
  hint:SetPoint("TOPLEFT", cardsWrap, "BOTTOMLEFT", 0, -24)

  function ns.RefreshDashboard()
    local m = ns.db.meta or {}
    meta:SetText(string.format("%s @ %s-%s\n%s · export %s · format v%s",
      m.guild ~= "" and m.guild or "—",
      m.realm ~= "" and m.realm or "?",
      m.region ~= "" and m.region or "?",
      m.season ~= "" and m.season or "—",
      m.exportedAt ~= "" and m.exportedAt or "—",
      tostring(m.formatVersion or ns.FORMAT_VERSION)))

    local list = ns.GetPlayersList()
    local counts = ns.CountByRole()
    local dayOne, critical = 0, 0
    for _, p in ipairs(list) do
      if p.launch == "day_one" then dayOne = dayOne + 1 end
      local flags = ns.BuildFlags(p)
      if (p.notes and p.notes ~= "") or (p.tags and #p.tags > 0)
        or flags.uncertain or flags.work or flags.vacation or flags.low_attendance or flags.deferred_launch then
        critical = critical + 1
      end
    end
    cards.players:SetText(tostring(#list))
    cards.tank:SetText(tostring(counts.tank))
    cards.healer:SetText(tostring(counts.healer))
    cards.dps:SetText(tostring(counts.dps))
    cards.dayone:SetText(tostring(dayOne))
    cards.notes:SetText(tostring(critical))
    hint:SetShown(#list == 0)
  end
end
