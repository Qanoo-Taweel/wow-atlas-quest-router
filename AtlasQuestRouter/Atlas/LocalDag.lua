--[[--------------------------------------------------------------------------
  Atlas/LocalDag.lua
  "Iterative Local DAG" (paper section 3.1) + "iterative topological sort with
  an explicit stack instead of recursion" (paper section 3.2).

  From the current edge we run a depth-first search over successor edges.
  The reverse post-order of that search is a topological order of the local
  DAG: every tree / forward / cross edge points forward in it, and the back
  edges (the ones that close a cycle) point backwards, so ATLAS simply skips
  any successor whose position is not greater than the current one.
----------------------------------------------------------------------------]]
local _, ns = ...

local LocalDag = {}

--- Returns `order` (array of edge labels, order[1] == startLabel) and
-- `position` (label -> index in order).
-- @param ordering IDfsOrdering deciding the visiting order of successors
-- @param gate     optional EdgeGate; closed edges are not part of the DAG
function LocalDag.build(graph, startLabel, ordering, requirements, gate)
    local visited = { [startLabel] = true }
    local function children(label)
        local succ = graph:successors(label)
        if gate then
            local open = {}
            for i = 1, #succ do
                if gate:allows(succ[i]) then open[#open + 1] = succ[i] end
            end
            succ = open
        end
        return ordering:order(succ, graph, requirements)
    end
    local postOrder = {}
    local stack = {
        { label = startLabel, children = children(startLabel), i = 0 },
    }
    while #stack > 0 do
        local frame = stack[#stack]
        frame.i = frame.i + 1
        local child = frame.children[frame.i]
        if child == nil then
            postOrder[#postOrder + 1] = frame.label
            stack[#stack] = nil
        elseif not visited[child] then
            visited[child] = true
            stack[#stack + 1] = {
                label = child,
                children = children(child),
                i = 0,
            }
        end
    end
    local order, position = {}, {}
    local n = #postOrder
    for i = 1, n do
        local label = postOrder[n - i + 1]
        order[i] = label
        position[label] = i
    end
    return order, position
end

ns.LocalDag = LocalDag
