--[[--------------------------------------------------------------------------
  Atlas/DistanceMatrix.lua
  "APSP precomputation" from the ATLAS paper (section 3.4).

  The paper precomputes a node-to-node distance matrix once (for graphs with
  |V| < 5000) so the scoring terms d(depot, x) used by Savings (eq. 2) and
  Proximity (eq. 3) become O(1) lookups. We do exactly that, once per plan,
  on ~70 world locations (a few milliseconds).

  NOTE: this matrix is only an input to the ATLAS *scoring function*. It never
  chooses the route. Every route the addon prints is built by AtlasSolver.
----------------------------------------------------------------------------]]
local _, ns = ...
local Class = ns.Class

local INF = math.huge
local DistanceMatrix = Class.define("DistanceMatrix")

function DistanceMatrix:init(graph)
    local nodes = graph:nodes()
    local n = #nodes
    local index = {}
    for i = 1, n do index[nodes[i]] = i end

    local dist = {}
    for i = 1, n do
        local row = {}
        for j = 1, n do row[j] = (i == j) and 0 or INF end
        dist[i] = row
    end
    for _, edge in graph:eachEdge() do
        local i, j = index[edge.source], index[edge.destination]
        if edge.weight < dist[i][j] then dist[i][j] = edge.weight end
    end
    -- one-time all-pairs relaxation (cold start cost, excluded from routing time)
    for k = 1, n do
        local rowK = dist[k]
        for i = 1, n do
            local rowI = dist[i]
            local dik = rowI[k]
            if dik < INF then
                for j = 1, n do
                    local candidate = dik + rowK[j]
                    if candidate < rowI[j] then rowI[j] = candidate end
                end
            end
        end
    end
    self.index, self.dist, self.nodes = index, dist, nodes
end

function DistanceMatrix:distance(fromNode, toNode)
    local i, j = self.index[fromNode], self.index[toNode]
    if not i or not j then return INF end
    return self.dist[i][j]
end

--- max over v of d(v, node) (finite values only); used to normalise eq. 2 and 3
function DistanceMatrix:maxDistanceTo(node)
    local j = self.index[node]
    local best = 0
    if not j then return 1 end
    for i = 1, #self.nodes do
        local d = self.dist[i][j]
        if d < INF and d > best then best = d end
        d = self.dist[j][i]
        if d < INF and d > best then best = d end
    end
    return (best > 0) and best or 1
end

DistanceMatrix.INF = INF
ns.DistanceMatrix = DistanceMatrix
