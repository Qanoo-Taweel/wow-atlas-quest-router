--[[--------------------------------------------------------------------------
  Routing/QuestRoutePlanner.lua
  Application service: quests + player -> RoutePlan, using ATLAS.

  Steps (each one a separate collaborator, injected through the constructor,
  so the planner can be unit-tested with fakes = Dependency Inversion):
    1. WorldGraphBuilder builds the player's graph      (Builder)
    2. DistanceMatrix feeds the ATLAS scoring terms      (paper 3.4)
    3. AtlasSolverFactory gives the ATLAS solver         (Factory Method)
    4. AtlasSolver covers every quest-step edge          (ATLAS, Algorithm 1)
    5. The tour is turned into human-readable legs       (RoutePlan)
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local QuestRoutePlanner = Class.define("QuestRoutePlanner")

function QuestRoutePlanner:init(world, builder, solverFactory)
    self.world = world
    self.builder = builder or ns.WorldGraphBuilder.new(world)
    self.solverFactory = solverFactory or ns.AtlasSolverFactory
end

--- @param profile { faction, class, level, groundSpeed, bindLocation, cooldowns }
--- @param quests  array of Quest
--- @param start   location id
--- @param options { profile = "quest" | "fast" | "paper", trace = bool }
function QuestRoutePlanner:plan(profile, quests, start, options)
    options = options or {}
    local model = self.builder:reset(profile)
        :addLocations()
        :addWalkingNetwork()
        :addFlightNetwork()
        :addTransports()
        :addTeleports()
        :addHearthstone()
        :addQuestSteps(quests)
        :setStart(start)
        :result()

    local solver = self.solverFactory.create(options.profile or "quest")
    solver.traceEnabled = options.trace or false
    solver.yieldEachIteration = options.yield or false
    local distances = ns.DistanceMatrix.new(model.graph)
    if solver.scorer and solver.scorer.adaptTo then solver.scorer:adaptTo(model.graph) end

    local ctx = {
        gate = ns.EdgeGate.new(model.graph),
        distances = distances,
        depot = start,
        maxDepotDistance = distances:maxDistanceTo(start),
    }
    local clock = os and os.clock or function() return 0 end
    local t0 = clock()
    local result = solver:solve(model.graph, model.startLabel, model.requirements, ctx)
    local elapsedMs = (clock() - t0) * 1000

    local legs, totalSeconds = self:toLegs(model, result.tour)
    local unreachable = {}
    for _, label in ipairs(model.requirements:pendingLabels()) do
        unreachable[#unreachable + 1] = model.stepByLabel[label]
    end
    return ns.RoutePlan.new(legs, totalSeconds, {
        start = start,
        iterations = result.iterations,
        unreachable = unreachable,
        elapsedMs = elapsedMs,
        edges = model.graph:edgeCount(),
        nodes = model.graph:nodeCount(),
        requiredEdges = #model.requirements.order,
        trace = result.trace,
        tour = result.tour,
        graph = model.graph,
    })
end

--- Tour (edge labels) -> legs. Consecutive walking edges are merged into one leg.
function QuestRoutePlanner:toLegs(model, tour)
    local legs, total = {}, 0
    local graph = model.graph
    for i = 2, #tour do
        local edge = graph:getEdge(tour[i])
        local p = edge.payload
        local seconds = p.seconds or edge.weight   -- real time, without planning penalties
        total = total + seconds
        if p.kind == "step" then
            legs[#legs + 1] = { kind = "step", step = p.step, location = p.location, seconds = seconds }
        elseif p.kind == "travel" then
            local last = legs[#legs]
            if last and last.kind == "travel" and last.mode == p.mode and (p.mode == "walk" or p.mode == "flight") then
                last.to = edge.destination
                last.seconds = last.seconds + seconds
                last.via[#last.via + 1] = edge.source
            else
                legs[#legs + 1] = { kind = "travel", mode = p.mode, from = edge.source, to = edge.destination,
                                    seconds = seconds, via = {} }
            end
        end
    end
    return legs, total
end

--- One line per leg, for chat output and tests.
function QuestRoutePlanner:describe(plan)
    local lines = {}
    local locs = self.world.locations
    for i, leg in ipairs(plan.legs) do
        local text
        if leg.kind == "step" then
            text = ("%s  @ %s"):format(leg.step:describe(), locs[leg.location].name)
        else
            text = ("%s: %s -> %s"):format(self.world.modeLabels[leg.mode] or leg.mode,
                locs[leg.from].name, locs[leg.to].name)
        end
        lines[i] = ("%2d. %s  (%s)"):format(i, text, ns.RoutePlan.formatSeconds(leg.seconds))
    end
    return lines
end

ns.QuestRoutePlanner = QuestRoutePlanner
