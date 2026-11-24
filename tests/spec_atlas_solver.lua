-- Weighted ATLAS (AtlasSolver): coverage, precedence, cost awareness, safety.
return function(ns, T, Loader)
    local O = ns.DfsOrderings
    local function solver(opts) return ns.AtlasSolverFactory.create(opts or "quest") end

    return {
        { "covers every edge of every test FSM", function()
            for _, name in ipairs({ "bbtas", "r_10_4_2", "r_25_4_4", "r_50_6_5" }) do
                local graph, start = Loader.loadFsm(ns, "tests/fixtures/" .. name .. ".fsm")
                local req = ns.RequirementSet.allEdges(graph)
                req:markServed(start)
                local result = solver("fast"):solve(graph, start, req, {})
                local seen = {}
                for _, l in ipairs(result.tour) do seen[l] = true end
                for label in graph:eachEdge() do T.ok(seen[label], name .. " misses edge " .. label) end
                T.eq(#result.unreachable, 0)
            end
        end },
        { "weighted ATLAS tour is a valid walk (each edge starts where the last ended)", function()
            local graph, start = Loader.loadFsm(ns, "tests/fixtures/r_25_4_4.fsm")
            local result = solver("quest"):solve(graph, start, ns.RequirementSet.allEdges(graph), {})
            for i = 2, #result.tour do
                T.eq(graph:getEdge(result.tour[i]).source, graph:getEdge(result.tour[i - 1]).destination)
            end
        end },
        { "prefers the cheap detour over the expensive one", function()
            -- start at s; required loop at t; two ways: s->t (100s) or s->m->t (5+5s)
            local g = ns.Graph.new()
            local start = g:addEdge("s", "s", 0)
            g:addEdge("s", "t", 100); g:addEdge("s", "m", 5); g:addEdge("m", "t", 5)
            local job = g:addEdge("t", "t", 1)
            local req = ns.RequirementSet.new():add(job)
            local result = solver("quest"):solve(g, start, req, {})
            T.eq(result.cost, 11)
        end },
        { "respects precedence: accept before turn-in even if turn-in is closer", function()
            local g = ns.Graph.new()
            local start = g:addEdge("home", "home", 0)
            g:addEdge("home", "far", 50); g:addEdge("far", "home", 50)
            local turnIn = g:addEdge("home", "home", 1)
            local accept = g:addEdge("far", "far", 1)
            local req = ns.RequirementSet.new():add(accept):add(turnIn, { accept })
            local result = solver("quest"):solve(g, start, req, {})
            local posA, posT
            for i, l in ipairs(result.tour) do if l == accept then posA = i end; if l == turnIn then posT = i end end
            T.ok(posA and posT and posA < posT)
        end },
        { "reports unreachable steps instead of looping", function()
            local g = ns.Graph.new()
            local start = g:addEdge("a", "a", 0)
            local island = g:addEdge("x", "x", 1)
            local req = ns.RequirementSet.new():add(island)
            local result = solver("quest"):solve(g, start, req, {})
            T.eq(#result.unreachable, 1); T.eq(result.unreachable[1], island)
        end },
        { "trace records one entry per ATLAS iteration", function()
            local graph, start = Loader.loadFsm(ns, "tests/fixtures/bbtas.fsm")
            local s = ns.AtlasSolver.new({ trace = true, orderings = { O.Insertion.new() } })
            local result = s:solve(graph, start, ns.RequirementSet.allEdges(graph), {})
            T.ok(#result.trace > 0); T.eq(#result.trace, result.iterations)
        end },
        { "factory rejects unknown profiles and accepts registered ones", function()
            T.raises(function() ns.AtlasSolverFactory.create("dijkstra") end)
            ns.AtlasSolverFactory.register("tiny", function() return ns.AtlasSolver.new({ requiredValue = 1 }) end)
            T.eq(ns.AtlasSolverFactory.create("tiny").requiredValue, 1)
        end },
        { "EdgeScorer composite sums the six paper components", function()
            local scorer = ns.EdgeScorer.paperDefault()
            T.eq(#scorer.components, 6)
            local g = ns.Graph.new(); local e = g:addEdge("a", "b", 2)
            local req = ns.RequirementSet.new():add(e)
            -- required 1000 + connectivity (0+1)*0.5 + efficiency 1/2*10 + regret 100 (dead end)
            T.eq(scorer:score(e, { graph = g, requirements = req }), 1000 + 0.5 + 5 + 100)
        end },
    }
end
