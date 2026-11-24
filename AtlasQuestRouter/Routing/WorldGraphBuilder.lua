--[[--------------------------------------------------------------------------
  Routing/WorldGraphBuilder.lua
  PATTERN: Builder. Builds the routing graph for ONE player in clear steps:

      builder:reset(profile)
             :addLocations()
             :addWalkingNetwork()
             :addFlightNetwork()
             :addTransports()
             :addTeleports()
             :addHearthstone()
             :addQuestSteps(quests)
             :setStart(location)
             :result()

  Every travel link goes through the TravelLinkFactory (Factory Method) and
  the AccessRule chain (Chain of Responsibility) before it becomes an edge.

  Quest steps become *required self-loop edges* at their location, which is
  how a node task is expressed in arc routing (ATLAS covers edges).
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local WorldGraphBuilder = Class.define("WorldGraphBuilder")

WorldGraphBuilder.WALK_NEIGHBOURS = 3

function WorldGraphBuilder:init(world, linkFactory, accessChain)
    self.world = world
    self.linkFactory = linkFactory or ns.TravelLinkFactory.new()
    self.accessChain = accessChain or ns.AccessRuleChain.default()
end

function WorldGraphBuilder:reset(profile)
    self.profile = profile
    self.graph = ns.Graph.new()
    self.requirements = ns.RequirementSet.new()
    self.stepByLabel = {}
    self.labelByStep = {}
    self.rejected = {}
    self.startLabel = nil
    return self
end

function WorldGraphBuilder:addLocations()
    for _, id in ipairs(self.world.locationOrder) do
        self.graph:addNode(id, self.world.locations[id])
    end
    return self
end

--- Factory + chain, then one directed edge.
function WorldGraphBuilder:addLink(mode, from, to, spec)
    local link = self.linkFactory:create(mode, from, to, spec)
    local ok, reason = self.accessChain:handle(link, self.profile)
    if not ok then
        table.insert(self.rejected, { mode = mode, from = from, to = to, reason = reason })
        return nil
    end
    local seconds = link:seconds(self.world, self.profile)
    local payload = link:payload(self.world, self.profile)
    payload.seconds = seconds
    -- edge weight = real seconds + optional planning penalty (hearthstone reserve)
    return self.graph:addEdge(from, to, seconds + (payload.penalty or 0), payload)
end

function WorldGraphBuilder:addBoth(mode, a, b, spec)
    self:addLink(mode, a, b, spec)
    self:addLink(mode, b, a, spec)
end

function WorldGraphBuilder:addWalkingNetwork()
    local world, seen = self.world, {}
    local function key(a, b) if a < b then return a .. "|" .. b end return b .. "|" .. a end
    local function connect(a, b)
        local k = key(a, b)
        if not seen[k] then
            seen[k] = true
            self:addBoth("walk", a, b)
        end
    end
    for _, id in ipairs(world.locationOrder) do
        local here = world.locations[id]
        local near = {}
        for _, other in ipairs(world.locationOrder) do
            local there = world.locations[other]
            if other ~= id and there.landmass == here.landmass then
                near[#near + 1] = { id = other, d = ns.distanceUnits(world, id, other) }
            end
        end
        table.sort(near, function(x, y) if x.d ~= y.d then return x.d < y.d end return x.id < y.id end)
        for i = 1, math.min(WorldGraphBuilder.WALK_NEIGHBOURS, #near) do connect(id, near[i].id) end
    end
    for _, road in ipairs(world.roads) do connect(road[1], road[2]) end
    return self
end

function WorldGraphBuilder:addFlightNetwork()
    for _, faction in ipairs({ "Alliance", "Horde" }) do   -- fixed order = reproducible labels
        for _, p in ipairs(self.world.flights[faction] or {}) do
            self:addBoth("flight", p[1], p[2], { faction = faction })
        end
    end
    return self
end

function WorldGraphBuilder:addTransports()
    for _, t in ipairs(self.world.transports) do
        self:addBoth(t[1], t[2], t[3], { ride = t[4], interval = t[5], faction = t[6] })
    end
    return self
end

--- Class teleports work from anywhere: one edge from every location.
function WorldGraphBuilder:addTeleports()
    for _, t in ipairs(self.world.teleports) do
        local class, destination, faction = t[1], t[2], t[3]
        if self.profile.class == class then
            for _, id in ipairs(self.world.locationOrder) do
                if id ~= destination then
                    self:addLink("teleport", id, destination, { class = class, faction = faction })
                end
            end
        end
    end
    return self
end

function WorldGraphBuilder:addHearthstone()
    local bind = self.profile.bindLocation
    if bind and self.world.locations[bind] then
        for _, id in ipairs(self.world.locationOrder) do
            if id ~= bind then self:addLink("hearth", id, bind, {}) end
        end
    end
    return self
end

--- Quest steps -> required self-loops with precedence.
function WorldGraphBuilder:addQuestSteps(quests)
    local turnInLabel = {}
    -- pass 1: edges
    for _, quest in ipairs(quests) do
        for _, step in ipairs(quest.steps) do
            if not step.done then
                if not self.world.locations[step.location] then
                    error(("Quest %d step %d: unknown location '%s'"):format(quest.id, step.index, step.location))
                end
                local label = self.graph:addEdge(step.location, step.location, step.seconds,
                    { kind = "step", step = step, location = step.location, seconds = step.seconds })
                self.stepByLabel[label] = step
                self.labelByStep[step] = label
                if step.kind == "turnin" then turnInLabel[quest.id] = label end
            end
        end
    end
    -- pass 2: precedence  accept -> objectives -> turn in ; quest chains
    for _, quest in ipairs(quests) do
        local acceptLabel, objectiveLabels = nil, {}
        for _, step in ipairs(quest.steps) do
            local label = self.labelByStep[step]
            if label then
                local prereqs = {}
                if step.kind == "accept" then
                    for _, requiredId in ipairs(quest.requires) do
                        if turnInLabel[requiredId] then prereqs[#prereqs + 1] = turnInLabel[requiredId] end
                    end
                    acceptLabel = label
                elseif step.kind == "objective" then
                    if acceptLabel then prereqs[#prereqs + 1] = acceptLabel end
                    objectiveLabels[#objectiveLabels + 1] = label
                else -- turn in
                    if acceptLabel then prereqs[#prereqs + 1] = acceptLabel end
                    for _, o in ipairs(objectiveLabels) do prereqs[#prereqs + 1] = o end
                end
                self.requirements:add(label, prereqs)
            end
        end
    end
    return self
end

function WorldGraphBuilder:setStart(location)
    assert(self.world.locations[location], "unknown start location " .. tostring(location))
    self.startLocation = location
    self.startLabel = self.graph:addEdge(location, location, 0, { kind = "start", location = location, seconds = 0 })
    return self
end

function WorldGraphBuilder:result()
    return {
        graph = self.graph,
        requirements = self.requirements,
        startLabel = self.startLabel,
        startLocation = self.startLocation,
        stepByLabel = self.stepByLabel,
        rejected = self.rejected,
    }
end

ns.WorldGraphBuilder = WorldGraphBuilder
