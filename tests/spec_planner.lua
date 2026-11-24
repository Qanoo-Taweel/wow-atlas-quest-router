-- End-to-end planning on the World of Warcraft Forever map.
return function(ns, T)
    local W, Q = ns.WorldData, ns.QuestData
    local function questsFor(ids)
        local log = ns.QuestLog.new(ns.EventBus.new(), Q.catalog)
        for _, id in ipairs(ids) do log:add(id) end
        return log:all()
    end
    local function stepOrderValid(plan)
        local doneAt = {}
        for i, leg in ipairs(plan.legs) do if leg.kind == "step" then doneAt[leg.step] = i end end
        for step, i in pairs(doneAt) do
            for _, other in ipairs(step.quest.steps) do
                if other.index < step.index and other.kind == "accept" and doneAt[other] and doneAt[other] > i then
                    return false
                end
            end
        end
        return true
    end
    local planner = ns.QuestRoutePlanner.new(W)
    local alliance = { faction = "Alliance", class = "WARRIOR", groundSpeed = 7, bindLocation = "stormwind", cooldowns = {} }
    local horde = { faction = "Horde", class = "SHAMAN", groundSpeed = 7, bindLocation = "orgrimmar", cooldowns = {} }

    return {
        { "every quest location exists in the world data", function()
            for _, def in ipairs(Q.list) do
                for _, s in ipairs(def.steps) do T.ok(W.locations[s.at], def.name .. " -> " .. s.at) end
            end
        end },
        { "Alliance plan covers every step, in a valid order", function()
            local plan = planner:plan(alliance, questsFor({ 1001, 1002, 1003, 1004, 1005, 1006 }), "stormwind")
            T.eq(#plan:stepLegs(), 18); T.eq(#plan.meta.unreachable, 0)
            T.ok(stepOrderValid(plan))
        end },
        { "Horde plan with a quest chain (3001 -> 3012)", function()
            local plan = planner:plan(horde, questsFor({ 3012, 3001, 3002 }), "orgrimmar")
            local turnIn3001, accept3012
            for i, leg in ipairs(plan.legs) do
                if leg.kind == "step" and leg.step.quest.id == 3001 and leg.step.kind == "turnin" then turnIn3001 = i end
                if leg.kind == "step" and leg.step.quest.id == 3012 and leg.step.kind == "accept" then accept3012 = i end
            end
            T.ok(turnIn3001 < accept3012, "chain order")
        end },
        { "Horde cannot reach Teldrassil: steps reported unreachable", function()
            local plan = planner:plan(horde, questsFor({ 1010, 3001 }), "orgrimmar")
            T.eq(#plan.meta.unreachable, 3)
        end },
        { "legs form a continuous journey", function()
            local plan = planner:plan(alliance, questsFor({ 1003, 1007, 1012, 2003 }), "ironforge")
            local here = "ironforge"
            for _, leg in ipairs(plan.legs) do
                if leg.kind == "travel" then T.eq(leg.from, here); here = leg.to else T.eq(leg.location, here) end
            end
        end },
        { "hearthstone is used at most once per plan", function()
            local plan = planner:plan(alliance, questsFor({ 1001, 1003, 1005, 1006, 1007, 1009, 1012, 2003 }), "stormwind")
            local hearths = 0
            for _, leg in ipairs(plan.legs) do if leg.mode == "hearth" then hearths = hearths + 1 end end
            T.ok(hearths <= 1)
        end },
        { "mage plans may teleport, warriors never do", function()
            local mage = { faction = "Alliance", class = "MAGE", groundSpeed = 7, bindLocation = "stormwind", cooldowns = {} }
            local warrior = planner:plan(alliance, questsFor({ 1010, 1007 }), "sentinelhill")
            for _, leg in ipairs(warrior.legs) do T.ok(leg.mode ~= "teleport") end
            local mplan = planner:plan(mage, questsFor({ 1010, 1007 }), "sentinelhill")
            T.ok(mplan.totalSeconds <= warrior.totalSeconds)
        end },
        { "planning is fast enough for the game (< 2 s in plain Lua 5.1)", function()
            local plan = planner:plan(alliance, questsFor({ 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008 }), "stormwind")
            T.ok(plan.meta.elapsedMs < 2000, ("took %.0f ms"):format(plan.meta.elapsedMs))
        end },
    }
end
