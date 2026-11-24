--[[--------------------------------------------------------------------------
  Atlas/AtlasSolver.lua
  ATLAS "Longest Path Extension" (paper Algorithm 1) for weighted arc routing
  with precedence constraints (quest steps).

    T <- [start edge]
    while R has an available edge:
        v   <- last edge of T
        DAG <- local DAG from v (DFS, back edges removed)          LocalDag
        DP over DAG in topological order:
            pathLong[n] = pathLong[e] + value(n)                    utility
            cost[n]     = cost[e] + weight(n)                       seconds
            keep the predecessor e that maximises
            Path_Score = utility - lambda * cost                    (paper 3.4 "Cost Penalty")
        best <- argmax(Path_Score[e] + tie * score(e))              (paper line 15, eq. 1)
        backtrack comeFrom, append chain to T, mark served edges
    return T

  Optimisations from the paper that are implemented here:
    * lazy array reset (LazyArray)              * iterative DFS (LocalDag)
    * multi-heuristic tie-breaking (EdgeScorer) * adaptive weights
    * precomputed distance matrix for scoring   * safety limit 100 * |E|
  Our extension for games:
    * several DFS orderings per iteration ("multi-DAG sampling"); ATLAS keeps
      the best chain over all of them. Still one DFS + one DP per ordering,
      so the complexity stays O(k * |R| * (|V| + |E|)) with k = #orderings.
    * precedence: value(n) > 0 only when the quest step is *available*
      (accept before objectives before turn-in, quest chains).

  SOLID:
    S - this class only routes. It does not build graphs or read quests.
    O - new scoring terms / orderings plug in through the constructor.
    D - depends on the abstractions IRequirementSet, IDfsOrdering,
        IScoreComponent, never on WoW or on Domain classes.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class
local LazyArray, LocalDag = ns.LazyArray, ns.LocalDag

local IRouteSolver = Class.interface("IRouteSolver", { "solve" })

local AtlasSolver = Class.define("AtlasSolver")

AtlasSolver.DEFAULTS = {
    requiredValue = 150,     -- utility of serving one required edge (seconds-equivalent);
                             -- tuned on 12 random quest logs (see README, "Tuning")
    costPenalty = 1,         -- lambda in Path_Score = utility - lambda * cost
    tieBreakWeight = 0.001,  -- eq. 1 is used for tie-breaking, as in the paper
    safetyFactor = 100,      -- iteration limit = 100 * |E| (paper 3.4)
}

function AtlasSolver:init(options)
    options = options or {}
    for key, value in pairs(AtlasSolver.DEFAULTS) do
        self[key] = (options[key] ~= nil) and options[key] or value
    end
    self.orderings = options.orderings or { ns.DfsOrderings.CheapestFirst.new() }
    self.scorer = options.scorer           -- IScoreComponent or nil
    self.traceEnabled = options.trace or false
    -- inside a coroutine, give one frame back to the game after each iteration
    self.yieldEachIteration = options.yieldEachIteration or false
    -- lazy arrays are allocated once and reset in O(k) per iteration
    self.utility = LazyArray.new(nil)
    self.cost = LazyArray.new(nil)
    self.comeFrom = LazyArray.new(nil)
    self.token = LazyArray.new(nil)     -- consumable used on the best path (hearthstone)
end

--- One ATLAS iteration on one local DAG. Returns the best chain or nil.
function AtlasSolver:extend(graph, startLabel, requirements, ordering, ctx)
    local gate = ctx.gate
    local order, position = LocalDag.build(graph, startLabel, ordering, requirements, gate)
    local utility, cost, comeFrom, token = self.utility, self.cost, self.comeFrom, self.token
    local lambda, gainValue = self.costPenalty, self.requiredValue
    utility:reset(); cost:reset(); comeFrom:reset(); token:reset()
    utility:set(startLabel, 0)
    cost:set(startLabel, 0)

    for i = 1, #order do
        local e = order[i]
        local ue = utility:get(e)
        if ue ~= nil then
            local ce = cost:get(e)
            local succ = graph:successors(e)
            for s = 1, #succ do
                local n = succ[s]
                local pn = position[n]           -- nil when the gate closed the edge
                local tn = gate and gate:token(n)
                if pn ~= nil and pn > i          -- forward edge of the local DAG
                   and not (tn and token:get(e) == tn) then  -- a consumable once per chain
                    local nu = ue + (requirements:isAvailable(n) and gainValue or 0)
                    local nc = ce + graph:getEdge(n).weight
                    local old = utility:get(n)
                    if old == nil or (nu - lambda * nc) > (old - lambda * cost:get(n)) then
                        utility:set(n, nu)
                        cost:set(n, nc)
                        comeFrom:set(n, e)
                        token:set(n, tn or token:get(e))
                    end
                end
            end
        end
    end

    -- selection (paper line 15): the chain must END on a newly served edge,
    -- otherwise it would carry a useless trailing deadhead.
    local bestLabel, bestScore
    for i = 2, #order do
        local e = order[i]
        local u = utility:get(e)
        if u ~= nil and u > 0 and requirements:isAvailable(e) then
            local s = u - lambda * cost:get(e)
            if self.scorer then s = s + self.tieBreakWeight * self.scorer:score(e, ctx) end
            if bestScore == nil or s > bestScore then
                bestLabel, bestScore = e, s
            end
        end
    end
    if not bestLabel then return nil end

    local chain, current = {}, bestLabel
    while current ~= startLabel do
        table.insert(chain, 1, current)
        current = comeFrom:get(current)
    end
    return {
        chain = chain,
        score = bestScore,
        utility = utility:get(bestLabel),
        cost = cost:get(bestLabel),
        ordering = ordering.name,
        dagSize = #order,
    }
end

--- Solve: cover every required edge of `requirements`, starting after `startLabel`.
-- @return result { tour = {labels}, cost, iterations, unreachable = {labels}, trace }
function AtlasSolver:solve(graph, startLabel, requirements, ctx)
    ctx = ctx or {}
    ctx.graph, ctx.requirements = graph, requirements
    local tour = { startLabel }
    local totalCost, iterations = 0, 0
    local unreachable, trace = {}, {}
    local limit = self.safetyFactor * math.max(graph:edgeCount(), 1)

    while requirements:hasRemaining() and iterations < limit do
        iterations = iterations + 1
        local current = tour[#tour]
        local best
        for _, ordering in ipairs(self.orderings) do
            local candidate = self:extend(graph, current, requirements, ordering, ctx)
            if candidate and (best == nil or candidate.score > best.score) then
                best = candidate
            end
        end

        if best == nil then
            -- nothing available is reachable from here: report and drop it
            -- (its dependants are dropped too) instead of looping forever
            for _, label in ipairs(requirements:availableLabels()) do
                table.insert(unreachable, label)
                requirements:drop(label)
            end
        else
            local served = {}
            for _, label in ipairs(best.chain) do
                tour[#tour + 1] = label
                totalCost = totalCost + graph:getEdge(label).weight
                if ctx.gate then ctx.gate:onTraverse(label) end
                if requirements:isAvailable(label) then
                    requirements:markServed(label)
                    served[#served + 1] = label
                end
            end
            if self.traceEnabled then
                trace[#trace + 1] = {
                    iteration = iterations, from = current, chain = best.chain,
                    served = served, cost = best.cost, ordering = best.ordering,
                    dagSize = best.dagSize,
                }
            end
        end
        if self.yieldEachIteration and coroutine.running() then
            coroutine.yield(iterations)
        end
    end

    return {
        tour = tour,
        cost = totalCost,
        iterations = iterations,
        unreachable = unreachable,
        trace = trace,
    }
end

Class.implements(AtlasSolver, IRouteSolver)
ns.IRouteSolver = IRouteSolver
ns.AtlasSolver = AtlasSolver
