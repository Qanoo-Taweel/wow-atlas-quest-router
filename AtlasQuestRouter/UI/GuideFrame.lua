--[[--------------------------------------------------------------------------
  UI/GuideFrame.lua
  GuideInteraction: the step-by-step guide window shown in game, in the style
  of leveling guide addons. It always shows ONE thing to do now, an arrow that
  points to where it happens, and what comes next.

      +-------------------------------------------+
      | ATLAS Guide                  1h 12m left  |
      |  [icon]  Fly to Sentinel Hill             |  <- current step (large)
      |          Flight master, about 1m 16s      |
      |   (arrow)  Sentinel Hill - south-west     |  <- direction arrow
      |  ======================------  12 / 40    |  <- progress bar
      |  Next:  Accept "Westfall Stew"            |
      |         Walk to Moonbrook                 |
      |         Westfall Stew: Gather ingredients |
      |  [ Back ]  [ Skip ]  [ Re-plan ]          |
      +-------------------------------------------+

  Steps advance by themselves (see AtlasQuestRouter:onGameEvent): accepting or
  turning in the quest, finishing its objectives, or arriving at the
  destination. Skip / Back are there when you want to do it by hand.

  Only this file creates WoW frames. The frame API (CreateFrame, UIParent) and
  the player's facing are injected, so it is smoke-tested with fake frames.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local GuideInteraction = Class.define("GuideInteraction", ns.UserInteraction)

GuideInteraction.UPCOMING = 4
GuideInteraction.WIDTH = 340
GuideInteraction.ICONS = {
    walk = "Interface\\Icons\\Ability_Tracking",
    flight = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    boat = "Interface\\Icons\\INV_Misc_Anchor",
    zeppelin = "Interface\\Icons\\INV_Misc_Bomb_06",
    tram = "Interface\\Icons\\INV_Misc_Gear_01",
    teleport = "Interface\\Icons\\Spell_Arcane_TeleportStormWind",
    hearth = "Interface\\Icons\\INV_Misc_Rune_01",
    accept = "Interface\\GossipFrame\\AvailableQuestIcon",
    objective = "Interface\\Icons\\Ability_DualWield",
    turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
}
GuideInteraction.VERBS = {
    walk = "Walk to", flight = "Fly to", boat = "Take the boat to", zeppelin = "Take the zeppelin to",
    tram = "Take the tram to", teleport = "Teleport to", hearth = "Use your Hearthstone to",
}
GuideInteraction.COMPASS = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }

--- @param deps { createFrame, parent, world, callbacks, getFacing }
function GuideInteraction:init(deps)
    self.createFrame, self.parent = deps.createFrame, deps.parent
    self.world = deps.world or ns.WorldData
    self.callbacks = deps.callbacks or {}
    self.getFacing = deps.getFacing or function() return nil end
    self.frame, self.plan = nil, nil
end

--- Text for one leg, as an instruction ("Fly to Sentinel Hill").
function GuideInteraction:instruction(leg)
    local locs = self.world.locations
    if leg.kind == "step" then
        return leg.step:describe(), ("at %s, %s"):format(locs[leg.location].name, locs[leg.location].zone)
    end
    local via = ""
    if leg.via and #leg.via > 0 then via = (" (%d stops)"):format(#leg.via) end
    return ("%s %s"):format(GuideInteraction.VERBS[leg.mode] or "Go to", locs[leg.to].name),
           ("from %s%s, about %s"):format(locs[leg.from].name, via, ns.RoutePlan.formatSeconds(leg.seconds))
end

--- Where the current leg happens, and where the player is assumed to be.
function GuideInteraction:targetOf(plan)
    local leg = plan:currentLeg()
    if not leg then return nil end
    if leg.kind == "step" then return leg.location, leg.location end
    return leg.to, leg.from
end

--- Compass bearing on the overview map, clockwise from north, in radians.
function GuideInteraction:bearing(fromId, toId)
    local a, b = self.world.locations[fromId], self.world.locations[toId]
    if not a or not b or fromId == toId then return nil end
    return math.atan2(b.x - a.x, -(b.y - a.y))
end

function GuideInteraction:compassName(radians)
    local sector = math.floor(((radians / (2 * math.pi)) * 8 + 0.5)) % 8
    return GuideInteraction.COMPASS[sector + 1]
end

function GuideInteraction:build()
    if self.frame then return self.frame end
    local CF, W = self.createFrame, GuideInteraction.WIDTH
    local template = (_G and _G.BackdropTemplateMixin) and "BackdropTemplate" or nil
    local f = CF("Frame", "AtlasQuestRouterGuide", self.parent, template)
    f:SetSize(W, 250)
    f:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", -220, -220)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                        tile = true, tileSize = 16, edgeSize = 14,
                        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.04, 0.05, 0.08, 0.92)
        f:SetBackdropBorderColor(0.9, 0.72, 0.3, 1)
    end

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10); f.title:SetText("ATLAS Guide")
    f.remaining = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.remaining:SetPoint("TOPRIGHT", -32, -12)
    local close = CF("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    -- current step
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(36, 36); f.icon:SetPoint("TOPLEFT", 12, -34)
    f.step = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.step:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, 0); f.step:SetWidth(W - 70); f.step:SetJustifyH("LEFT")
    f.detail = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.detail:SetPoint("TOPLEFT", f.step, "BOTTOMLEFT", 0, -3); f.detail:SetWidth(W - 70); f.detail:SetJustifyH("LEFT")

    -- direction arrow
    f.arrow = f:CreateTexture(nil, "ARTWORK")
    f.arrow:SetSize(30, 30); f.arrow:SetPoint("TOPLEFT", 16, -82)
    f.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    f.direction = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.direction:SetPoint("LEFT", f.arrow, "RIGHT", 12, 0)

    -- progress
    f.bar = CF("StatusBar", nil, f)
    f.bar:SetSize(W - 90, 10); f.bar:SetPoint("TOPLEFT", 14, -122)
    f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    f.bar:SetStatusBarColor(0.9, 0.72, 0.3)
    f.progress = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.progress:SetPoint("LEFT", f.bar, "RIGHT", 8, 0)

    -- upcoming
    f.nextLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.nextLabel:SetPoint("TOPLEFT", 14, -142); f.nextLabel:SetText("Next:")
    f.upcoming = {}
    for i = 1, GuideInteraction.UPCOMING do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", 52, -142 - (i - 1) * 15); fs:SetWidth(W - 66); fs:SetJustifyH("LEFT")
        f.upcoming[i] = fs
    end

    -- buttons
    local function button(text, x, width, callback)
        local b = CF("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(width, 22); b:SetPoint("BOTTOMLEFT", x, 10); b:SetText(text)
        b:SetScript("OnClick", function() if self.callbacks[callback] then self.callbacks[callback]() end end)
        return b
    end
    button("Back", 12, 70, "onBack")
    button("Skip", 88, 70, "onNext")
    button("Re-plan", 164, 90, "onReplan")

    -- keep the arrow pointing while the player turns (throttled to 10 per second)
    local elapsedSince = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        elapsedSince = elapsedSince + (elapsed or 0)
        if elapsedSince > 0.1 then elapsedSince = 0; self:updateArrow() end
    end)
    self.frame = f
    return f
end

--- Rotate the arrow: target bearing (clockwise) relative to where the player looks.
-- GetPlayerFacing() is counter-clockwise from north; SetRotation is counter-clockwise.
function GuideInteraction:updateArrow()
    local f, plan = self.frame, self.plan
    if not f or not plan then return end
    local target, from = self:targetOf(plan)
    if not target then f.arrow:Hide(); f.direction:SetText(""); return end
    local bearing = self:bearing(from, target)
    if not bearing then
        f.arrow:Hide()
        f.direction:SetText(("You are there: %s"):format(self.world.locations[target].name))
        return
    end
    f.arrow:Show()
    local facing = self.getFacing()
    if facing and f.arrow.SetRotation then f.arrow:SetRotation(-(bearing + facing)) end
    f.direction:SetText(("%s, to the %s"):format(self.world.locations[target].name, self:compassName(bearing)))
end

function GuideInteraction:notify() end  -- messages go to chat

function GuideInteraction:render(plan)
    self.plan = plan
    local f = self:build()
    local remaining = 0
    for i = plan.cursor, #plan.legs do remaining = remaining + plan.legs[i].seconds end
    f.remaining:SetText(ns.RoutePlan.formatSeconds(remaining) .. " left")
    local leg = plan:currentLeg()
    if leg then
        local main, detail = self:instruction(leg)
        local iconKey = leg.kind == "step" and leg.step.kind or leg.mode
        f.icon:SetTexture(GuideInteraction.ICONS[iconKey])
        f.step:SetText(main); f.detail:SetText(detail)
    else
        f.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
        f.step:SetText("Route complete!"); f.detail:SetText("Track more quests and press Re-plan.")
    end
    f.bar:SetMinMaxValues(0, math.max(#plan.legs, 1))
    f.bar:SetValue(math.min(plan.cursor - 1, #plan.legs))
    f.progress:SetText(("%d / %d"):format(math.min(plan.cursor, #plan.legs), #plan.legs))
    for i = 1, GuideInteraction.UPCOMING do
        local nextLeg = plan.legs[plan.cursor + i]
        f.upcoming[i]:SetText(nextLeg and (self:instruction(nextLeg)) or "")
    end
    self:updateArrow()
    f:Show()
end

function GuideInteraction:showPlan(plan) self:render(plan) end
function GuideInteraction:showProgress(plan) self:render(plan) end
function GuideInteraction:setVisible(visible)
    local f = self:build()
    if visible then f:Show() else f:Hide() end
end

Class.implements(GuideInteraction, ns.IUserInteraction)
ns.GuideInteraction = GuideInteraction
