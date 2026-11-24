--[[--------------------------------------------------------------------------
  Domain/RequirementSet.lua
  The set R of required edges ATLAS must cover, with precedence.

  An edge is AVAILABLE when it is required, not yet served, not dropped and
  all of its prerequisites are served. For quests this encodes:
    accept  ->  every objective  ->  turn in      (inside one quest)
    turn in of quest A  ->  accept of quest B     (quest chains)

  Implements IRequirementSet, the only thing AtlasSolver knows about quests.
  SOLID: Interface Segregation. The solver sees six small methods, not the
  whole quest model.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local IRequirementSet = Class.interface("IRequirementSet",
    { "isAvailable", "markServed", "hasRemaining", "availableLabels", "drop" })

local RequirementSet = Class.define("RequirementSet")

function RequirementSet:init()
    self.order = {}          -- required labels in insertion order
    self.required = {}       -- label -> true
    self.prereqs = {}        -- label -> { label, ... }
    self.served = {}         -- label -> true
    self.dropped = {}        -- label -> true
end

function RequirementSet:add(label, prerequisites)
    if not self.required[label] then
        table.insert(self.order, label)
        self.required[label] = true
    end
    self.prereqs[label] = prerequisites or {}
    return self
end

--- Convenience: every edge of a graph is required (classic arc routing).
function RequirementSet.allEdges(graph)
    local set = RequirementSet.new()
    for label in graph:eachEdge() do set:add(label) end
    return set
end

function RequirementSet:isRequired(label) return self.required[label] == true end
function RequirementSet:isServed(label) return self.served[label] == true end

function RequirementSet:isAvailable(label)
    if not self.required[label] or self.served[label] or self.dropped[label] then
        return false
    end
    for _, p in ipairs(self.prereqs[label]) do
        if not self.served[p] then return false end
    end
    return true
end

function RequirementSet:markServed(label)
    self.served[label] = true
end

function RequirementSet:hasRemaining()
    for _, label in ipairs(self.order) do
        if self:isAvailable(label) then return true end
    end
    return false
end

function RequirementSet:availableLabels()
    local out = {}
    for _, label in ipairs(self.order) do
        if self:isAvailable(label) then out[#out + 1] = label end
    end
    return out
end

--- Mark unreachable; everything that depends on it becomes unreachable too.
function RequirementSet:drop(label)
    if self.dropped[label] then return end
    self.dropped[label] = true
    for _, other in ipairs(self.order) do
        for _, p in ipairs(self.prereqs[other]) do
            if p == label then self:drop(other) end
        end
    end
end

function RequirementSet:pendingLabels()
    local out = {}
    for _, label in ipairs(self.order) do
        if not self.served[label] then out[#out + 1] = label end
    end
    return out
end

Class.implements(RequirementSet, IRequirementSet)
ns.IRequirementSet = IRequirementSet
ns.RequirementSet = RequirementSet
