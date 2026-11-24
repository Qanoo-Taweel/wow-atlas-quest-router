-- The design patterns, tested through their observable behaviour.
return function(ns, T)
    local W = ns.WorldData
    return {
        { "Chain of Responsibility: faction rule stops the chain", function()
            local chain = ns.AccessRuleChain.default()
            local link = ns.TravelLinkFactory.new():create("zeppelin", "orgrimmar", "undercity",
                { ride = 1, interval = 1, faction = "Horde" })
            local ok, reason = chain:handle(link, { faction = "Alliance" })
            T.ok(not ok); T.eq(reason, "faction Horde")
            T.ok(chain:handle(link, { faction = "Horde" }))
        end },
        { "Chain of Responsibility: cooldown rule blocks the hearthstone", function()
            local chain = ns.AccessRuleChain.default()
            local link = ns.TravelLinkFactory.new():create("hearth", "goldshire", "stormwind", {})
            T.ok(not chain:handle(link, { faction = "Alliance", cooldowns = { hearthstone = 600 } }))
            T.ok(chain:handle(link, { faction = "Alliance", cooldowns = {} }))
        end },
        { "Chain of Responsibility: class rule for mage teleports", function()
            local chain = ns.AccessRuleChain.default()
            local link = ns.TravelLinkFactory.new():create("teleport", "goldshire", "ironforge",
                { class = "MAGE", faction = "Alliance" })
            T.ok(not chain:handle(link, { faction = "Alliance", class = "WARRIOR" }))
            T.ok(chain:handle(link, { faction = "Alliance", class = "MAGE" }))
        end },
        { "Factory Method: TravelLinkFactory returns the right subclass", function()
            local f = ns.TravelLinkFactory.new()
            T.ok(f:create("boat", "a", "b", { ride = 1, interval = 1 }):isInstanceOf(ns.TravelLinks.Boat))
            T.ok(f:create("walk", "a", "b"):isInstanceOf(ns.TravelLink))
            T.raises(function() f:create("dragon", "a", "b") end)
        end },
        { "Factory Method: scheduled link time = ride + half the interval", function()
            local link = ns.TravelLinkFactory.new():create("boat", "a", "b", { ride = 100, interval = 240 })
            T.eq(link:seconds(W, {}), 220)
        end },
        { "Factory Method: UserInteractionFactory subclasses decide the products", function()
            local headless = ns.HeadlessUserInteractionFactory.new():createInteractions({})
            T.ok(headless.chat:isInstanceOf(ns.HeadlessInteraction))
            local api = ns.StubGameApi.new()
            local wow = ns.WowUserInteractionFactory.new(api, function() error("no frames in tests") end, {})
            local chat = wow:createInteraction("chat")
            T.ok(chat:isInstanceOf(ns.ChatInteraction))
            chat:notify("hi"); T.eq(api.printed[1], "hi")
            T.raises(function() ns.UserInteractionFactory.new():createInteraction("chat") end)
        end },
        { "Command + Chain: verbs are routed, unknown verbs answered", function()
            local chain, calls = ns.CommandChain.default(), {}
            local fake = setmetatable({}, { __index = function(_, k)
                return function(_, ...) calls[#calls + 1] = { k, ... } end
            end })
            chain:handle("add", "Kobold Candles", fake)
            chain:handle("wat", "", fake)
            T.eq(calls[1][1], "addQuest"); T.eq(calls[1][2], "Kobold Candles")
            T.eq(calls[2][1], "say")
        end },
        { "CommandChain.parse splits verb and arguments", function()
            local verb, args = ns.CommandChain.parse("  ADD  Westfall Stew ")
            T.eq(verb, "add"); T.eq(args, "Westfall Stew")
        end },
        { "Adapter: WowGameApi reads a fake WoW environment", function()
            local env = {
                UnitFactionGroup = function() return "Horde" end,
                UnitClass = function() return "Mage", "MAGE" end,
                UnitLevel = function() return 20 end,
                GetBindLocation = function() return "Orgrimmar" end,
                GetNumQuestLogEntries = function() return 2 end,
                GetQuestLogTitle = function(i) if i == 1 then return "The Barrens", 0, 0, true end return "Raptor Thieves", 14, 0, false end,
            }
            local api = ns.WowGameApi.new(env)
            local p = api:playerProfile()
            T.eq(p.faction, "Horde"); T.eq(p.class, "MAGE"); T.eq(p.bindName, "Orgrimmar")
            local titles = api:questLogTitles()
            T.eq(#titles, 1); T.eq(titles[1], "Raptor Thieves")
        end },
        { "Builder: every location is reachable on foot within its landmass", function()
            local b = ns.WorldGraphBuilder.new(W):reset({ faction = "Alliance", groundSpeed = 7 })
                :addLocations():addWalkingNetwork()
            local g = b:result().graph
            local d = ns.DistanceMatrix.new(g)
            for _, a in ipairs(W.locationOrder) do
                for _, c in ipairs(W.locationOrder) do
                    if W.locations[a].landmass == W.locations[c].landmass then
                        T.ok(d:distance(a, c) < math.huge, a .. " cannot walk to " .. c)
                    end
                end
            end
        end },
    }
end
