--[[--------------------------------------------------------------------------
  Atlas/DfsOrderings.lua
  PATTERN: Strategy. The order in which the depth-first search visits
  successor edges decides which edges become "back edges" and are left out of
  the local DAG (paper section 3.1). Each ordering is a swappable strategy.

  * JavaHashSetOrdering  - reproduces java.util.HashSet<Integer> iteration, so
                           AtlasClassic gives byte-identical output to Atlas.java
  * CheapestFirstOrdering, RequiredFirstOrdering, InsertionOrdering,
    ExpensiveFirstOrdering - used by the weighted solver; each one yields a
    different local DAG and ATLAS keeps the best chain (multi-DAG sampling).
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local IDfsOrdering = Class.interface("IDfsOrdering", { "order" })

local function copy(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    return out
end

local InsertionOrdering = Class.define("InsertionOrdering")
InsertionOrdering.name = "insertion"
function InsertionOrdering:order(labels) return labels end

local CheapestFirstOrdering = Class.define("CheapestFirstOrdering")
CheapestFirstOrdering.name = "cheapest-first"
function CheapestFirstOrdering:order(labels, graph)
    local out = copy(labels)
    table.sort(out, function(a, b)
        local wa, wb = graph:getEdge(a).weight, graph:getEdge(b).weight
        if wa ~= wb then return wa < wb end
        return a < b
    end)
    return out
end

local ExpensiveFirstOrdering = Class.define("ExpensiveFirstOrdering")
ExpensiveFirstOrdering.name = "expensive-first"
function ExpensiveFirstOrdering:order(labels, graph)
    local out = copy(labels)
    table.sort(out, function(a, b)
        local wa, wb = graph:getEdge(a).weight, graph:getEdge(b).weight
        if wa ~= wb then return wa > wb end
        return a < b
    end)
    return out
end

local RequiredFirstOrdering = Class.define("RequiredFirstOrdering")
RequiredFirstOrdering.name = "required-first"
function RequiredFirstOrdering:order(labels, graph, requirements)
    local out = copy(labels)
    table.sort(out, function(a, b)
        local ra = requirements and requirements:isAvailable(a) and 1 or 0
        local rb = requirements and requirements:isAvailable(b) and 1 or 0
        if ra ~= rb then return ra > rb end
        local wa, wb = graph:getEdge(a).weight, graph:getEdge(b).weight
        if wa ~= wb then return wa < wb end
        return a < b
    end)
    return out
end

--- java.util.HashSet<Integer> iterates by bucket = hash & (capacity - 1),
-- Integer.hashCode() = value (spread: h ^ (h >>> 16), a no-op below 65536),
-- capacity starts at 16 and doubles when size > 0.75 * capacity; colliding
-- entries keep insertion order.
local JavaHashSetOrdering = Class.define("JavaHashSetOrdering")
JavaHashSetOrdering.name = "java-hashset"
function JavaHashSetOrdering:order(labels)
    local capacity = 16
    while #labels > capacity * 0.75 do capacity = capacity * 2 end
    local keyed = {}
    for i = 1, #labels do
        -- labels stay far below 65536 here, where Java's hash spread is a no-op
        keyed[i] = { label = labels[i], bucket = labels[i] % capacity, seq = i }
    end
    table.sort(keyed, function(a, b)
        if a.bucket ~= b.bucket then return a.bucket < b.bucket end
        return a.seq < b.seq
    end)
    local out = {}
    for i = 1, #keyed do out[i] = keyed[i].label end
    return out
end

for _, cls in ipairs({ InsertionOrdering, CheapestFirstOrdering, ExpensiveFirstOrdering,
                       RequiredFirstOrdering, JavaHashSetOrdering }) do
    Class.implements(cls, IDfsOrdering)
end

ns.IDfsOrdering = IDfsOrdering
ns.DfsOrderings = {
    Insertion = InsertionOrdering,
    CheapestFirst = CheapestFirstOrdering,
    ExpensiveFirst = ExpensiveFirstOrdering,
    RequiredFirst = RequiredFirstOrdering,
    JavaHashSet = JavaHashSetOrdering,
}
