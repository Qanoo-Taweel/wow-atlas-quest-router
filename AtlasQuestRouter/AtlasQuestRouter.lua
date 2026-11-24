--[[--------------------------------------------------------------------------
  AtlasQuestRouter.lua
  PATTERN: Facade.

  The ONE object the rest of the world talks to. Slash commands, the guide
  buttons, game events and the tests call simple methods such as
  addQuest(), plan(), nextLeg(). Behind it sit ~15 classes (QuestLog,
  WorldGraphBuilder, AtlasSolver, DistanceMatrix, TravelLinkFactory, access
  chain, scheduler, interactions...). Callers never see them.

  Why a facade: the subsystem is large and changes often; the callers are
  many (commands, buttons, events, tests). The facade keeps those callers
  stable and short, and gives the professor one class to start reading from.

  At the bottom: bootstrap code that only runs inside World of Warcraft.
----------------------------------------------------------------------------]]
local ADDON_NAME, ns = ...
local Class = ns.Class

local AtlasQuestRouter = Class.define("AtlasQuestRouter")

AtlasQuestRouter.RIDING = { foot = 7, ["0"] = 7, ["60"] = 11.2, ["100"] = 14 }
AtlasQuestRouter.DEMO = {
    Alliance = { 1001, 1002, 1003, 1004, 1005, 1006 },
    Horde = { 3001, 3002, 3003, 3005, 3012 },
}

--- All collaborators are injected (Dependency Inversion); defaults are real ones.
-- @param deps { gameApi, interactionFactory, scheduler, world, questData, settings }
function AtlasQuestRouter:init(deps)
    self.gameApi = deps.gameApi
    self.world = deps.world or ns.WorldData
    self.bus = deps.bus or ns.EventBus.new()
    self.questLog = ns.QuestLog.new(self.bus, (deps.questData or ns.QuestData).catalog)
    self.planner = deps.planner or ns.QuestRoutePlanner.new(self.world)
    self.resolver = ns.LocationResolver.new(self.world)
    self.scheduler = deps.scheduler or ns.ImmediateScheduler.new()
    self.commands = ns.CommandChain.default()
    self.settings = deps.settings or {}
    self.settings.groundSpeed = self.settings.groundSpeed or 7
    self.interactions = (deps.interactionFactory or ns.HeadlessUserInteractionFactory.new())
        :createInteractions({
            onNext = function() self:nextLeg() end,
            onBack = function() self:previousLeg() end,
            onReplan = function() self:plan() end,
        })
    -- Observer: any change of the quest log invalidates the current plan
    local invalidate = function() self.currentPlan = nil end
    local E = ns.QuestLog.EVENTS
    for _, event in ipairs({ E.ADDED, E.REMOVED, E.CLEARED }) do self.bus:subscribe(event, invalidate) end
end

-- output -----------------------------------------------------------------
function AtlasQuestRouter:say(message)
    for _, interaction in pairs(self.interactions) do interaction:notify(message) end
end

-- quest log --------------------------------------------------------------
function AtlasQuestRouter:addQuest(idOrName)
    local quest, err = self.questLog:add(idOrName)
    if quest and not err then self:say(("Tracking [%d] %s"):format(quest.id, quest.name))
    elseif quest then self:say(quest.name .. " is " .. err)
    else self:say(err) end
    return quest
end

function AtlasQuestRouter:removeQuest(id)
    if self.questLog:remove(tonumber(id)) then self:say("Removed quest " .. id)
    else self:say("Not tracked: " .. tostring(id)) end
end

function AtlasQuestRouter:listQuests()
    if self.questLog:count() == 0 then return self:say("No quests tracked. Try /aqr demo or /aqr import") end
    for _, quest in ipairs(self.questLog:all()) do
        local nextStep = quest:nextStep()
        self:say(("[%d] %s - %s"):format(quest.id, quest.name, nextStep and nextStep:describe() or "complete"))
    end
end

function AtlasQuestRouter:clearQuests()
    self.questLog:clear()
    self:say("Quest log cleared")
end

function AtlasQuestRouter:importQuestLog()
    local added = 0
    for _, title in ipairs(self.gameApi:questLogTitles()) do
        local def = self.questLog:findDefinition(title)
        if def and def.name:lower() == title:lower() and not self.questLog:get(def.id) then
            self.questLog:add(def.id)
            added = added + 1
        end
    end
    self:say(("Imported %d quest(s) from your quest log"):format(added))
    return added
end

function AtlasQuestRouter:demo()
    local faction = self:profile().faction
    for _, id in ipairs(AtlasQuestRouter.DEMO[faction] or AtlasQuestRouter.DEMO.Alliance) do
        self.questLog:add(id)
    end
    self:say(("Tracking %d demo quests. Now type /aqr plan"):format(self.questLog:count()))
end

-- player -----------------------------------------------------------------
function AtlasQuestRouter:profile()
    local p = self.gameApi:playerProfile()
    p.groundSpeed = self.settings.groundSpeed
    p.bindLocation = self.settings.bind or (p.bindName and self.resolver:byText(p.bindName))
    return p
end

function AtlasQuestRouter:currentLocation()
    if self.settings.startOverride then return self.settings.startOverride end
    local sub, zone = self.gameApi:currentLocationName()
    return self.resolver:fromGame(sub, zone)
end

function AtlasQuestRouter:setStartOverride(text)
    if text == "" or text == "here" then
        self.settings.startOverride = nil
        return self:say("Planning from your current position")
    end
    local id = self.resolver:byText(text)
    if not id then return self:say("Unknown place: " .. text) end
    self.settings.startOverride = id
    self:say("Planning from " .. self.world.locations[id].name)
end

function AtlasQuestRouter:setBind(text)
    local id = self.resolver:byText(text)
    if not id then return self:say("Unknown place: " .. tostring(text)) end
    self.settings.bind = id
    self:say("Hearthstone set to " .. self.world.locations[id].name)
end

function AtlasQuestRouter:setRiding(text)
    local speed = AtlasQuestRouter.RIDING[text]
    if not speed then return self:say("Use: /aqr speed foot | 60 | 100") end
    self.settings.groundSpeed = speed
    self:say(("Ground speed set to %.1f yards/s"):format(speed))
end

-- routing ----------------------------------------------------------------
--- Plan with ATLAS. Runs through the scheduler (one ATLAS iteration per frame in game).
function AtlasQuestRouter:plan(onDone)
    if self.questLog:count() == 0 then return self:say("No quests tracked. Try /aqr demo") end
    local start = self:currentLocation()
    if not start then return self:say("Could not tell where you are. Use /aqr from <place>") end
    local profile, quests = self:profile(), self.questLog:all()
    self:say("ATLAS is planning...")
    return self.scheduler:run(function()
        return self.planner:plan(profile, quests, start, { yield = true })
    end, function(plan)
        self.currentPlan = plan
        self.currentLines = self.planner:describe(plan)
        for _, interaction in pairs(self.interactions) do interaction:showPlan(plan, self.currentLines) end
        if #plan.meta.unreachable > 0 then
            self:say(("%d step(s) are unreachable for your character"):format(#plan.meta.unreachable))
        end
        if onDone then onDone(plan) end
    end)
end

--- Mark the current leg done; quest steps are completed in the quest log too.
function AtlasQuestRouter:nextLeg()
    local plan = self.currentPlan
    if not plan then return self:say("No route yet. Type /aqr plan") end
    local leg = plan:currentLeg()
    if leg and leg.kind == "step" then self.questLog:markStepDone(leg.step) end
    plan:advance()
    for _, interaction in pairs(self.interactions) do interaction:showProgress(plan, self.currentLines) end
    return plan:currentLeg()
end

function AtlasQuestRouter:previousLeg()
    local plan = self.currentPlan
    if not plan then return self:say("No route yet. Type /aqr plan") end
    local leg = plan:back()
    if leg and leg.kind == "step" then leg.step.done = false end
    for _, interaction in pairs(self.interactions) do interaction:showProgress(plan, self.currentLines) end
    return leg
end

-- guide auto-advance --------------------------------------------------------
-- Called by Platform/GameEventBridge.lua when something happens in the game.
-- The guide only moves when the event matches the current step, or a step that
-- is reached through travel legs only (the player took a shortcut).

local function sameTitle(a, b) return a and b and a:lower() == b:lower() end

--- Index of the first leg from the cursor matching `predicate`, if only travel legs lie before it.
function AtlasQuestRouter:findAhead(predicate)
    local plan = self.currentPlan
    if not plan then return nil end
    for i = plan.cursor, #plan.legs do
        local leg = plan.legs[i]
        if predicate(leg) then return i end
        if leg.kind == "step" then return nil end
    end
end

function AtlasQuestRouter:jumpPast(index)
    local plan = self.currentPlan
    plan.cursor = index
    return self:nextLeg()
end

function AtlasQuestRouter:completeStep(kind, title)
    local index = self:findAhead(function(leg)
        return leg.kind == "step" and leg.step.kind == kind and sameTitle(leg.step.quest.name, title)
    end)
    if index then return self:jumpPast(index) end
    -- not next in the guide: still remember it, so a re-plan skips it
    for _, quest in ipairs(self.questLog:all()) do
        if sameTitle(quest.name, title) then
            for _, step in ipairs(quest.steps) do
                if step.kind == kind and not step.done then self.questLog:markStepDone(step); break end
            end
        end
    end
end

function AtlasQuestRouter:onQuestAccepted(title) return self:completeStep("accept", title) end
function AtlasQuestRouter:onQuestTurnedIn(title) return self:completeStep("turnin", title) end
function AtlasQuestRouter:onObjectivesComplete(title)
    local index = self:findAhead(function(leg)
        return leg.kind == "step" and leg.step.kind == "objective" and sameTitle(leg.step.quest.name, title)
    end)
    if index then return self:jumpPast(index) end
end

function AtlasQuestRouter:onArrived(place)
    local index = self:findAhead(function(leg) return leg.kind == "travel" and leg.to == place end)
    if index then return self:jumpPast(index) end
end

function AtlasQuestRouter:setGuideVisible(visible)
    if self.interactions.guide then self.interactions.guide:setVisible(visible) end
end

function AtlasQuestRouter:runCommand(input)
    local verb, args = ns.CommandChain.parse(input)
    return self.commands:handle(verb, args, self)
end

-- persistence ------------------------------------------------------------
function AtlasQuestRouter:save()
    return { quests = self.questLog:serialize(), settings = self.settings }
end

function AtlasQuestRouter:load(saved)
    if not saved then return end
    for k, v in pairs(saved.settings or {}) do self.settings[k] = v end
    self.questLog:restore(saved.quests)
end

ns.AtlasQuestRouter = AtlasQuestRouter

---------------------------------------------------------------------------
-- Bootstrap: only inside the WoW client (CreateFrame exists there).
---------------------------------------------------------------------------
if type(CreateFrame) == "function" and type(SlashCmdList) == "table" then
    local gameApi = ns.WowGameApi.new(_G)
    local router = AtlasQuestRouter.new({
        gameApi = gameApi,
        interactionFactory = ns.WowUserInteractionFactory.new(gameApi, CreateFrame, UIParent, ns.WorldData),
        scheduler = ns.FrameScheduler.new(CreateFrame),
    })
    ns.router = router
    local bridge = ns.GameEventBridge.new(router, gameApi, router.resolver)

    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_LOGOUT")
    bridge:attach(events)
    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
            router:load(_G.AtlasQuestRouterDB)
            gameApi:print("loaded. Type /aqr help")
        elseif event == "PLAYER_LOGOUT" then
            _G.AtlasQuestRouterDB = router:save()
        elseif router.currentPlan then
            bridge:handle(event, arg1)
        end
    end)

    _G.SLASH_ATLASQUESTROUTER1 = "/aqr"
    _G.SLASH_ATLASQUESTROUTER2 = "/atlasroute"
    SlashCmdList.ATLASQUESTROUTER = function(input) router:runCommand(input) end
end
