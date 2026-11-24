-- Core building blocks: Class, EventBus, Graph, LazyArray, RequirementSet
return function(ns, T)
    return {
        { "Class: inheritance and isInstanceOf", function()
            local A = ns.Class.define("A"); function A:init(x) self.x = x end; function A:hello() return "A" end
            local B = ns.Class.define("B", A)
            local b = B.new(5)
            T.eq(b.x, 5); T.eq(b:hello(), "A"); T.ok(b:isInstanceOf(A)); T.ok(b:isInstanceOf(B))
        end },
        { "Class: implements fails fast on a missing method", function()
            local I = ns.Class.interface("IThing", { "doIt" })
            local C = ns.Class.define("C")
            T.raises(function() ns.Class.implements(C, I) end)
        end },
        { "Class: abstract method raises when not overridden", function()
            T.raises(function() ns.UserInteraction.new():notify("x") end)
        end },
        { "EventBus: publish reaches subscribers, unsubscribe works", function()
            local bus, got = ns.EventBus.new(), {}
            local off = bus:subscribe("E", function(v) got[#got + 1] = v end)
            bus:publish("E", 1); off(); bus:publish("E", 2)
            T.eq(#got, 1); T.eq(got[1], 1)
        end },
        { "Graph: degrees and successors", function()
            local g = ns.Graph.new()
            local e1 = g:addEdge("a", "b", 3); local e2 = g:addEdge("b", "c", 4); g:addEdge("b", "a", 1)
            T.eq(g:outDegree("b"), 2); T.eq(g:inDegree("a"), 1)
            T.eq(g:successors(e1)[1], e2); T.eq(g:edgeCount(), 3)
        end },
        { "LazyArray: reset clears only touched entries in O(k)", function()
            local a = ns.LazyArray.new(0)
            a:set(5, 9); a:set(7, 1); a:set(5, 3)
            T.eq(a.touchedCount, 2); T.eq(a:get(5), 3)
            a:reset(); T.eq(a:get(5), 0); T.eq(a.touchedCount, 0)
        end },
        { "RequirementSet: precedence and transitive drop", function()
            local r = ns.RequirementSet.new()
            r:add(1); r:add(2, { 1 }); r:add(3, { 2 })
            T.ok(r:isAvailable(1)); T.ok(not r:isAvailable(2))
            r:markServed(1); T.ok(r:isAvailable(2))
            r:drop(2); T.ok(not r:isAvailable(3)); T.ok(not r:hasRemaining())
        end },
        { "DistanceMatrix: all-pairs distances used by the scoring terms", function()
            local g = ns.Graph.new()
            g:addEdge("a", "b", 2); g:addEdge("b", "c", 2); g:addEdge("a", "c", 10)
            local d = ns.DistanceMatrix.new(g)
            T.eq(d:distance("a", "c"), 4); T.eq(d:distance("c", "a"), math.huge)
        end },
    }
end
