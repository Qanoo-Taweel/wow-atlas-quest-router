--[[--------------------------------------------------------------------------
  Atlas/EdgeScorer.lua
  PATTERN: Composite. EdgeScorer is itself an IScoreComponent made of
  IScoreComponents; ATLAS asks one object for score(e) and never knows how
  many heuristics are inside.

  Also implements _compute_adaptive_weights() from the paper (section 3.3):
  sparse "rural" graphs boost Regret and Savings, dense "urban" graphs boost
  Connectivity.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class
local C = ns.ScoreComponents

local EdgeScorer = Class.define("EdgeScorer")

function EdgeScorer:init(components)
    self.components = components or {}
end

--- The six components with the paper's coefficients.
function EdgeScorer.paperDefault()
    return EdgeScorer.new({
        C.Required.new(), C.Connectivity.new(), C.Efficiency.new(),
        C.Savings.new(), C.Regret.new(), C.Proximity.new(),
    })
end

function EdgeScorer:add(component)
    table.insert(self.components, component)
    return self
end

--- Adapt coefficients to graph density (paper: _compute_adaptive_weights).
function EdgeScorer:adaptTo(graph)
    local v = math.max(graph:nodeCount(), 1)
    local density = graph:edgeCount() / (v * math.max(v - 1, 1))
    for _, component in ipairs(self.components) do
        local base = component.defaultWeight or component.weight
        if density < 0.1 then
            if component:isInstanceOf(C.Regret) then component.weight = base * 1.5
            elseif component:isInstanceOf(C.Savings) then component.weight = base * 1.2
            else component.weight = base end
        else
            if component:isInstanceOf(C.Connectivity) then component.weight = base * 2
            else component.weight = base end
        end
    end
    self.density = density
    return self
end

function EdgeScorer:score(label, ctx)
    local total = 0
    for _, component in ipairs(self.components) do
        total = total + component.weight * component:score(label, ctx)
    end
    return total
end

Class.implements(EdgeScorer, ns.IScoreComponent)
ns.EdgeScorer = EdgeScorer
