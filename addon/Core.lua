local ADDON, ns = ...
local L = ns.L

local function Print(msg)
  print("|cff66ccff" .. (ns.ADDON_TITLE or "Guild Performer") .. "|r: " .. msg)
end
ns.Print = Print

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    ns.EnsureDB()
  elseif event == "PLAYER_LOGIN" then
    ns.EnsureDB()
    if ns.Minimap and ns.Minimap.Init then ns.Minimap:Init() end
    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
      AddonCompartmentFrame:RegisterAddon({
        text = ns.ADDON_TITLE,
        icon = "Interface\\Icons\\INV_Misc_GroupLooking",
        notCheckable = true,
        func = function()
          if ns.UI then ns.UI:Toggle() end
        end,
      })
    end
    if ns.db.settings.autoApplySync ~= false and ns.TryApplySyncedData then
      ns.TryApplySyncedData(false)
    elseif type(GuildPerformerDB_Guild) == "table" and ns.ApplyGuildImportTable then
      ns.ApplyGuildImportTable(GuildPerformerDB_Guild)
    end
    Print((L["LOADED"] or "loaded.") .. " |cffffff00/gp|r")
  end
end)

SLASH_GUILDPERFORMER1 = "/guildperformer"
SLASH_GUILDPERFORMER2 = "/gp"
SlashCmdList.GUILDPERFORMER = function(msg)
  local raw = strtrim(msg or "")
  msg = string.lower(raw)
  if msg == "reset" then
    ns.db.settings.pos = nil
    ns.db.settings.minimap = { angle = 210, hide = false }
    Print(L["RESET_OK"] or "Position reset. /reload to apply minimap.")
    if ns.UI and ns.UI.frame then
      ns.UI.frame:ClearAllPoints()
      ns.UI.frame:SetPoint("CENTER")
    end
    return
  end
  if msg == "minimap" then
    if ns.Minimap and ns.Minimap.button then
      ns.Minimap:SetShown(not ns.Minimap.button:IsShown())
    end
    return
  end
  if msg == "sync" then
    if not ns.TryApplySyncedData then
      Print("Sync unavailable.")
      return
    end
    local n, err = ns.TryApplySyncedData(true)
    if n then
      Print(string.format(L["SYNC_APPLIED"] or "Synced %d players.", n))
    else
      Print(err or (L["SYNC_NO_DATA"] or "No sync data."))
    end
    return
  end

  if msg == "pushprep" or msg == "push" then
    if not ns.PreparePushForCompanion then
      Print("Push prep unavailable.")
      return
    end
    local n, err = ns.PreparePushForCompanion()
    if n then
      Print(string.format(L["PUSH_PREP_OK"] or "Push pronto (%d PG). Companion: push, poi /reload.", n))
    else
      Print(err or (L["ROSTER_READONLY"] or "Officer/GM only."))
    end
    return
  end

  -- /gp add Nome [Classe] [tank|healer|melee|ranged]  (preserve name casing)
  local addName, addRest = raw:match("^[Aa][Dd][Dd]%s+(%S+)%s*(.*)$")
  if addName then
    if not ns.CanEditRoster or not ns.CanEditRoster() then
      Print(L["ROSTER_READONLY"] or "Solo GM/officer possono modificare il roster.")
      return
    end
    local class, role = addRest:match("^(%S+)%s*(%S*)$")
    local roleLow = role and string.lower(role) or ""
    local classLow = class and string.lower(class) or ""
    if classLow == "tank" or classLow == "healer" or classLow == "melee" or classLow == "ranged" or classLow == "dps" then
      roleLow, class = classLow, nil
    end
    local p, err = ns.AddManualPlayer({
      name = addName,
      class = class or "",
      primaryRole = (roleLow ~= "" and roleLow) or "ranged",
    })
    if p then
      Print(string.format(L["ADD_OK"] or "Aggiunto %s (manuale).", p.name))
      if ns.RefreshRosterView then ns.RefreshRosterView() end
    else
      Print(err or "?")
    end
    return
  end

  -- /gp remove Nome
  local remName = raw:match("^[Rr][Ee][Mm][Oo][Vv][Ee]%s+(.+)$") or raw:match("^[Dd][Ee][Ll]%s+(.+)$")
  if remName then
    if not ns.CanEditRoster or not ns.CanEditRoster() then
      Print(L["ROSTER_READONLY"] or "Solo GM/officer possono modificare il roster.")
      return
    end
    if ns.RemoveManualPlayer(remName) then
      Print(string.format(L["REMOVE_OK"] or "Rimosso %s.", remName))
      if ns.RefreshRosterView then ns.RefreshRosterView() end
    else
      Print(L["REMOVE_FAIL"] or "PG non trovato.")
    end
    return
  end

  -- /gp rename Vecchio Nuovo
  local oldN, newN = raw:match("^[Rr][Ee][Nn][Aa][Mm][Ee]%s+(%S+)%s+(%S+)$")
  if oldN and newN then
    if not ns.CanEditRoster or not ns.CanEditRoster() then
      Print(L["ROSTER_READONLY"] or "Solo GM/officer possono modificare il roster.")
      return
    end
    local ok, err = ns.RenamePlayer(oldN, newN)
    if ok then
      Print(string.format(L["RENAME_OK"] or "Rinominato %s → %s.", oldN, newN))
      if ns.RefreshRosterView then ns.RefreshRosterView() end
    else
      Print(tostring(err or "fail"))
    end
    return
  end

  if not ns.UI then
    Print("UI not ready.")
    return
  end
  local map = {
    roster = "roster",
    settings = "settings",
    dashboard = "dashboard",
    events = "events",
    event = "events",
    calendario = "events",
    caldebug = "caldebug",
    debug = "caldebug",
    cal = "caldebug",
  }
  local mod = map[msg]
  if mod then
    ns.UI:EnsureCreated()
    ns.UI.frame:Show()
    ns.UI:ShowModule(mod)
    return
  end
  ns.UI:Toggle()
end

-- Back-compat helpers used by older call sites
function ns.ToggleMainWindow()
  if ns.UI then ns.UI:Toggle() end
end
function ns.CreateMainWindow()
  if ns.UI then ns.UI:EnsureCreated() end
  return ns.UI and ns.UI.frame
end
function ns.ShowTab(name)
  if ns.UI then ns.UI:ShowModule(name) end
end
function ns.UpdateMinimap()
  if ns.Minimap then
    ns.Minimap:SetShown(ns.db.settings.showMinimap ~= false and not (ns.db.settings.minimap and ns.db.settings.minimap.hide))
  end
end
