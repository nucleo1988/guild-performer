local ADDON, ns = ...
local L = ns.L
ns.Minimap = ns.Minimap or {}
local M = ns.Minimap

local BUTTON_ICON = "Interface\\Icons\\INV_Misc_GroupLooking"
local RADIUS = 80

local function updatePosition(btn, angle)
  local rad = math.rad(angle)
  btn:SetPoint("CENTER", Minimap, "CENTER", RADIUS * math.cos(rad), RADIUS * math.sin(rad))
end

local function onDragUpdate(btn)
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local px, py = GetCursorPosition()
  px, py = px / scale, py / scale
  local angle = math.deg(math.atan2(py - my, px - mx))
  ns.db.settings.minimap = ns.db.settings.minimap or {}
  ns.db.settings.minimap.angle = angle
  updatePosition(btn, angle)
end

function M:Init()
  if self.button then
    self:SetShown(not (ns.db.settings.minimap and ns.db.settings.minimap.hide))
    return
  end
  ns.db.settings.minimap = ns.db.settings.minimap or { angle = 210, hide = false }
  local db = ns.db.settings.minimap
  if db.angle == nil then db.angle = 210 end

  local btn = CreateFrame("Button", "GuildPerformerMinimapButton", Minimap)
  self.button = btn
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetMovable(true)

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture(BUTTON_ICON)
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  btn:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      ns.UI:EnsureCreated()
      ns.UI.frame:Show()
      ns.UI:ShowModule("settings")
    else
      ns.UI:Toggle()
    end
  end)
  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", onDragUpdate)
  end)
  btn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff66ccff" .. (ns.ADDON_TITLE or "Guild Performer") .. "|r")
    GameTooltip:AddLine(L["MINIMAP_DESC"] or "Guild raid roster from RaidRoster export.", 0.9, 0.9, 0.9)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffd100Left-click:|r " .. (L["OPEN"] or "open / close"))
    GameTooltip:AddLine("|cffffd100Right-click:|r " .. (L["SETTINGS"] or "Settings"))
    GameTooltip:AddLine("|cffffd100Drag:|r move")
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  updatePosition(btn, db.angle)
  if db.hide or ns.db.settings.showMinimap == false then
    btn:Hide()
  else
    btn:Show()
  end
end

function M:SetShown(show)
  if not self.button then return end
  ns.db.settings.minimap = ns.db.settings.minimap or {}
  ns.db.settings.showMinimap = show and true or false
  if show then
    self.button:Show()
    ns.db.settings.minimap.hide = false
  else
    self.button:Hide()
    ns.db.settings.minimap.hide = true
  end
end
