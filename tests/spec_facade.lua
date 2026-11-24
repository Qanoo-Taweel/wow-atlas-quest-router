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
        { "TrackerInteraction renders with a fake frame API", function()
            local created = {}
            local function fakeObject()
                return setmetatable({}, { __index = function(t, k)
                    if k == "CreateFontString" then return function() return fakeObject() end end
                    return function() return nil end
                end })
            end
            local createFrame = function(...) local o = fakeObject(); created[#created + 1] = { ... }; return o end
            local tracker = ns.TrackerInteraction.new(createFrame, {}, {})
            local router = newRouter(); router:runCommand("add 1001"); router:runCommand("plan")
            tracker:showPlan(router.currentPlan, router.currentLines)
            T.ok(#created >= 3)
        end },
    }
end
