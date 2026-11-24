--[[--------------------------------------------------------------------------
  Atlas/ScoreComponents.lua
  The six terms of the ATLAS multi-heuristic edge score (paper eq. 1):

    score(e) = 1[e in R]*1000 + (deg+ + deg-)*0.5 + value(e)/weight(e)*10
             + SCW(e)*50 + R(e)*100 + P(e)*20

  PATTERN: Strategy (each term is an interchangeable IScoreComponent).
  SOLID:
    S - one heuristic per class
    O - add a new heuristic by adding a class, EdgeScorer is not edited
    L - every component can replace any other inside EdgeScorer
    I - IScoreComponent has a single method: score(label, ctx)
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local IScoreComponent = Class.interface("IScoreComponent", { "score" })

local ScoreComponent = Class.define("ScoreComponent")
function ScoreComponent:init(weight) self.weight = weight or self.defaultWeight or 1 end
ScoreComponent.score = Class.abstract("ScoreComponent", "score")

-- 1[e in R] * 1000 : absolute priority for unserviced required edges
local RequiredComponent = Class.define("RequiredComponent", ScoreComponent)
RequiredComponent.defaultWeight = 1000
function RequiredComponent:score(label, ctx)
    return ctx.requirements:isAvailable(label) and 1 or 0
end

-- (deg+ + deg-) * 0.5 : favour hubs with more routing options
local ConnectivityComponent = Class.define("ConnectivityComponent", ScoreComponent)
ConnectivityComponent.defaultWeight = 0.5
function ConnectivityComponent:score(label, ctx)
    local dst = ctx.graph:getEdge(label).destination
    return ctx.graph:outDegree(dst) + ctx.graph:inDegree(dst)
end

-- value(e) / weight(e) * 10 : value per unit cost
local EfficiencyComponent = Class.define("EfficiencyComponent", ScoreComponent)
EfficiencyComponent.defaultWeight = 10
function EfficiencyComponent:score(label, ctx)
    local edge = ctx.graph:getEdge(label)
    local value = ctx.requirements:isAvailable(label) and 1 or 0
    return value / math.max(edge.weight, 1)
end

-- Clarke-Wright savings (eq. 2): (d(depot,src) + d(dst,depot) - w(e)) / max d
local SavingsComponent = Class.define("SavingsComponent", ScoreComponent)
SavingsComponent.defaultWeight = 50
function SavingsComponent:score(label, ctx)
    if not ctx.distances then return 0 end
    local edge = ctx.graph:getEdge(label)
    local d = ctx.distances
    local a = d:distance(ctx.depot, edge.source)
    local b = d:distance(edge.destination, ctx.depot)
    if a == d.INF or b == d.INF then return 0 end
    return (a + b - edge.weight) / ctx.maxDepotDistance
end

-- Regret: 1 if the edge ends in a dead end (deg+(dst) <= 1). Do it now or pay later.
local RegretComponent = Class.define("RegretComponent", ScoreComponent)
RegretComponent.defaultWeight = 100
function RegretComponent:score(label, ctx)
    local dst = ctx.graph:getEdge(label).destination
    return (ctx.graph:outDegree(dst) <= 1) and 1 or 0
end

-- Depot proximity (eq. 3): 1 - d(dst, depot) / max d
local ProximityComponent = Class.define("ProximityComponent", ScoreComponent)
ProximityComponent.defaultWeight = 20
function ProximityComponent:score(label, ctx)
    if not ctx.distances then return 0 end
    local d = ctx.distances:distance(ctx.graph:getEdge(label).destination, ctx.depot)
    if d == ctx.distances.INF then return 0 end
    return 1 - d / ctx.maxDepotDistance
end

for _, cls in ipairs({ RequiredComponent, ConnectivityComponent, EfficiencyComponent,
                       SavingsComponent, RegretComponent, ProximityComponent }) do
    Class.implements(cls, IScoreComponent)
end

ns.IScoreComponent = IScoreComponent
ns.ScoreComponent = ScoreComponent
ns.ScoreComponents = {
    Required = RequiredComponent,
    Connectivity = ConnectivityComponent,
    Efficiency = EfficiencyComponent,
    Savings = SavingsComponent,
    Regret = RegretComponent,
    Proximity = ProximityComponent,
}
