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
    end
    Print((L["LOADED"] or "loaded.") .. " |cffffff00/gp|r")
  end
end)

SLASH_GUILDPERFORMER1 = "/guildperformer"
SLASH_GUILDPERFORMER2 = "/gp"
SlashCmdList.GUILDPERFORMER = function(msg)
  msg = string.lower(strtrim(msg or ""))
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
  if not ns.UI then
    Print("UI not ready.")
    return
  end
  local map = {
    import = "import",
    roster = "roster",
    settings = "settings",
    builder = "builder",
    dashboard = "dashboard",
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
