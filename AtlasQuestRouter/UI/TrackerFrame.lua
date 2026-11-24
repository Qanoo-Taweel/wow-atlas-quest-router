--[[--------------------------------------------------------------------------
  UI/TrackerFrame.lua
  TrackerInteraction: the movable "ATLAS Route" window shown in game.

      +--------------------------------------+
      | ATLAS Route            1h 12m   [x]  |
      | > Flight: Stormwind -> Sentinel Hill |  <- current leg (gold)
      |   Accept "Westfall Stew"             |
      |   Walk: Sentinel Hill -> Moonbrook   |
      |   ...                                |
      | [ Next ]  [ Re-plan ]   12 / 40      |
      +--------------------------------------+

  Only this file creates WoW frames. It receives the frame API through the
  constructor (CreateFrame, UIParent), so it can also be smoke-tested with a
  fake frame library.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local TrackerInteraction = Class.define("TrackerInteraction", ns.UserInteraction)

TrackerInteraction.MAX_LINES = 10
TrackerInteraction.MODE_COLORS = {
    walk = "ffd8c9a3", flight = "ff7fd4ff", boat = "ff5aa9e6", zeppelin = "ffe0a050",
    tram = "ffb0b0b0", teleport = "ffc58cff", hearth = "ff8fe388", step = "ffffd100",
}

function TrackerInteraction:init(createFrame, parent, callbacks)
    self.createFrame, self.parent = createFrame, parent
    self.callbacks = callbacks or {}
    self.frame = nil
end

function TrackerInteraction:build()
    if self.frame then return self.frame end
    local template = (_G and _G.BackdropTemplateMixin) and "BackdropTemplate" or nil
    local f = self.createFrame("Frame", "AtlasQuestRouterTracker", self.parent, template)
    f:SetSize(320, 64 + TrackerInteraction.MAX_LINES * 16)
    f:SetPoint("RIGHT", self.parent, "RIGHT", -40, 40)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                        tile = true, tileSize = 16, edgeSize = 14,
                        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.05, 0.06, 0.09, 0.88)
    end

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.title:SetText("ATLAS Route")
    f.total = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.total:SetPoint("TOPRIGHT", -30, -10)

    local close = self.createFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    f.lines = {}
    for i = 1, TrackerInteraction.MAX_LINES do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 12, -12 - i * 16)
        fs:SetWidth(296); fs:SetJustifyH("LEFT")
        f.lines[i] = fs
    end

    local nextButton = self.createFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextButton:SetSize(70, 20); nextButton:SetPoint("BOTTOMLEFT", 10, 8); nextButton:SetText("Next")
    nextButton:SetScript("OnClick", function() if self.callbacks.onNext then self.callbacks.onNext() end end)

    local planButton = self.createFrame("Button", nil, f, "UIPanelButtonTemplate")
    planButton:SetSize(80, 20); planButton:SetPoint("LEFT", nextButton, "RIGHT", 6, 0); planButton:SetText("Re-plan")
    planButton:SetScript("OnClick", function() if self.callbacks.onReplan then self.callbacks.onReplan() end end)

    f.progress = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.progress:SetPoint("BOTTOMRIGHT", -12, 12)
    self.frame = f
    return f
end

function TrackerInteraction:notify() end  -- chat handles messages

function TrackerInteraction:render(plan, lines)
    local f = self:build()
    f.total:SetText(ns.RoutePlan.formatSeconds(plan.totalSeconds))
    for i = 1, TrackerInteraction.MAX_LINES do
        local index = plan.cursor + i - 1
        local leg, text = plan.legs[index], lines[index]
        local fs = f.lines[i]
        if leg and text then
            local color = TrackerInteraction.MODE_COLORS[leg.kind == "step" and "step" or leg.mode] or "ffffffff"
            local marker = (i == 1) and "> " or "   "
            fs:SetText(("|c%s%s%s|r"):format(color, marker, text:gsub("^%s*%d+%.%s*", "")))
        else
            fs:SetText("")
        end
    end
    f.progress:SetText(("%d / %d"):format(math.min(plan.cursor, #plan.legs), #plan.legs))
    f:Show()
end

function TrackerInteraction:showPlan(plan, lines) self:render(plan, lines) end
function TrackerInteraction:showProgress(plan, lines) self:render(plan, lines) end
function TrackerInteraction:setVisible(visible)
    local f = self:build()
    if visible then f:Show() else f:Hide() end
end

Class.implements(TrackerInteraction, ns.IUserInteraction)
ns.TrackerInteraction = TrackerInteraction
