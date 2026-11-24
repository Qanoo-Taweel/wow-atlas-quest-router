-- The Facade, driven only through slash commands, like a player would.
return function(ns, T)
    local function newRouter(state)
        local api = ns.StubGameApi.new(state or { faction = "Alliance", subzone = "Goldshire", zone = "Elwynn Forest",
                                                  bindName = "Stormwind City" })
        local router = ns.AtlasQuestRouter.new({ gameApi = api, interactionFactory = ns.HeadlessUserInteractionFactory.new() })
        return router, router.interactions.chat
    end
    return {
        { "/aqr demo + /aqr plan produces a route from the player's position", function()
            local router, chat = newRouter()
            router:runCommand("demo")
            router:runCommand("plan")
            T.ok(router.currentPlan, "plan exists")
            T.eq(router.currentPlan.meta.start, "goldshire")
            T.eq(#chat.plans, 1)
        end },
        { "/aqr next walks the plan and completes quest steps", function()
            local router = newRouter()
            router:runCommand("add Kobold Candles")
            router:runCommand("plan")
            local steps = 0
            while not router.currentPlan:isFinished() do
                local leg = router.currentPlan:currentLeg()
                if leg.kind == "step" then steps = steps + 1 end
                router:runCommand("next")
            end
            T.eq(steps, 3); T.ok(router.questLog:get(1001):isComplete())
        end },
        { "adding a quest invalidates the old plan (Observer)", function()
            local router = newRouter()
            router:runCommand("add 1001"); router:runCommand("plan")
            T.ok(router.currentPlan)
            router:runCommand("add 1003")
            T.ok(router.currentPlan == nil)
        end },
        { "/aqr from and /aqr speed change the plan inputs", function()
            local router = newRouter()
            router:runCommand("from booty")
            router:runCommand("speed 100")
            router:runCommand("add Pirate Hats Ahoy"); router:runCommand("plan")
            T.eq(router.currentPlan.meta.start, "bootybay")
            T.eq(router.settings.groundSpeed, 14)
        end },
        { "/aqr import picks known quests from the game quest log", function()
            local router = newRouter({ faction = "Horde", zone = "Durotar", questLog = { "Raptor Thieves", "Unknown Quest" } })
            T.eq(router:importQuestLog(), 1)
        end },
        { "save/load round-trips tracked quests and finished steps", function()
            local router = newRouter()
            router:runCommand("add 1001"); router.questLog:get(1001).steps[1].done = true
            local saved = router:save()
            local other = newRouter(); other:load(saved)
            T.ok(other.questLog:get(1001).steps[1].done)
        end },
        { "unknown command answers with help hint", function()
            local router, chat = newRouter()
            router:runCommand("fly-me-to-the-moon")
            T.ok(chat.messages[#chat.messages]:find("help"))
        end },
        { "GuideInteraction renders the current step, arrow and next steps with fake frames", function()
            local created, texts = 0, {}
            local function fakeObject()
                return setmetatable({}, { __index = function(_, k)
                    if k:find("^Create") then return function() created = created + 1; return fakeObject() end end
                    if k == "SetText" then return function(_, t) texts[#texts + 1] = t end end
                    return function() return nil end
                end })
            end
            local guide = ns.GuideInteraction.new({ createFrame = function() created = created + 1; return fakeObject() end,
                                                    parent = {}, getFacing = function() return 0.5 end })
            local router = newRouter(); router:runCommand("add 1001"); router:runCommand("plan")
            guide:showPlan(router.currentPlan)
            T.ok(created >= 10)
            local joined = table.concat(texts, "|")
            T.ok(joined:find("Walk to Fargodeep Mine") or joined:find("Kobold Candles"), joined)
        end },
        { "Guide compass: bearing on the map gives a readable direction", function()
            local guide = ns.GuideInteraction.new({ createFrame = function() end })
            T.eq(guide:compassName(guide:bearing("stormwind", "ironforge")), "north-east")
            T.eq(guide:compassName(guide:bearing("stormwind", "sentinelhill")), "south-west")
        end },
        { "Auto-advance: accepting the quest in game moves the guide on", function()
            local router = newRouter({ faction = "Alliance", subzone = "Goldshire", zone = "Elwynn Forest" })
            router:runCommand("add Kobold Candles"); router:runCommand("plan")
            T.eq(router.currentPlan:currentLeg().step.kind, "accept")
            router:onQuestAccepted("Kobold Candles")
            T.ok(router.questLog:get(1001).steps[1].done)
            T.eq(router.currentPlan.cursor, 2)
        end },
        { "Auto-advance: arriving at the destination skips the travel leg", function()
            local router = newRouter({ faction = "Alliance", subzone = "Goldshire", zone = "Elwynn Forest" })
            router:runCommand("add Kobold Candles"); router:runCommand("plan")
            router:onQuestAccepted("Kobold Candles")
            local leg = router.currentPlan:currentLeg()
            T.eq(leg.kind, "travel")
            router:onArrived(leg.to)
            T.eq(router.currentPlan:currentLeg().kind, "step")
        end },
        { "Auto-advance ignores events that do not match the next step", function()
            local router = newRouter()
            router:runCommand("add Kobold Candles"); router:runCommand("plan")
            router:onQuestTurnedIn("Some Other Quest"); router:onArrived("orgrimmar")
            T.eq(router.currentPlan.cursor, 1)
        end },
        { "GameEventBridge translates WoW events (accept, turn in, zone change)", function()
            local api = ns.StubGameApi.new({ faction = "Alliance", subzone = "Goldshire", zone = "Elwynn Forest",
                                             questLog = { "Kobold Candles" }, dialogTitle = "Kobold Candles" })
            local router = ns.AtlasQuestRouter.new({ gameApi = api })
            router:runCommand("add 1001"); router:runCommand("plan")
            local bridge = ns.GameEventBridge.new(router, api, router.resolver)
            bridge:handle("QUEST_ACCEPTED", 1)
            T.eq(router.currentPlan.cursor, 2)
            api.state.subzone = "Fargodeep Mine"; bridge:handle("ZONE_CHANGED")
            T.eq(router.currentPlan:currentLeg().step.kind, "objective")
            api.state.entries = { { title = "Kobold Candles", complete = true } }; bridge:handle("QUEST_LOG_UPDATE")
            api.state.subzone = "Goldshire"; bridge:handle("ZONE_CHANGED")
            bridge:handle("QUEST_COMPLETE"); bridge:handle("QUEST_TURNED_IN")
            T.ok(router.currentPlan:isFinished()); T.ok(router.questLog:get(1001):isComplete())
        end },
        { "/aqr back steps back and un-ticks the step", function()
            local router = newRouter()
            router:runCommand("add 1001"); router:runCommand("plan")
            router:runCommand("next"); router:runCommand("back")
            T.eq(router.currentPlan.cursor, 1); T.ok(not router.questLog:get(1001).steps[1].done)
        end },
    }
end
